class_name World
extends Node3D
## The 3D world: classic RO presentation (2D sprites on a lit 3D map, fixed three-quarter camera)
## with RO M / Origin phone controls (joystick, attack + skill arc, auto, context Act button).
## This script owns the loop, input and camera. Everything else lives in a system:
## kit (geometry and feedback), combat, quests, lessons (coach), scene (story scenes), folk (other pilgrims).
## A map is data (data/maps/<id>.json) plus, for hand-built places, a script in scripts/maps.

const SPEED := 4.6
const WEARY_SPEED := 0.8
const PICK_PX := 70.0
const HITSTOP_SCALE := 0.03
const ACT_RANGE := 2.6
const ARRIVE_RANGE := 2.4
const MELEE_RANGE := 1.8
const AUTO_SEEK_RANGE := 14.0
const AUTO_HEAL_BELOW := 0.45
const SIT_REGEN := 3.0
const STEP_DUST_S := 0.34
const WEARY_ON_ENTER_S := 15.0
const LANDSCAPE_FOV := 30.0
const PORTRAIT_FOV := 36.0
const PLAYER_HEIGHT := 2.0          # world units for a full 96 px sheet cell (48 px per unit)
const MAP_SCRIPT := "res://scripts/maps/%s.gd"

var map_id := "eden"
var kind := "story"              # this map's kind in the world graph: story, town, field, danger, instance
var def: Dictionary = {}          # this map's definition from data/maps/<id>.json
var hud: Node
var cam_rig: Node3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_yaw_target := 0.0
var cam_dist := 17.0
var zoom_presets := [13.0, 17.0, 22.0]
var player: CharacterBody3D
var pact: SpriteActor
var move_target = null          # Vector3 or null
var pending = null              # entity dict to interact with on arrival
var auto_on := false
var sitting := false
var cam_focus = null             # Vector3 the camera looks at during story scenes (null = the player)
var cinema := false              # story scene playing: input and the HUD step aside
var ents: Array = []             # interactables: {id, name, pos, node, act, icon, fn, hidden}
var bounds := Rect2(-26, -18, 52, 36)
var snapshot_unlocked := false
var t := 0.0
var regen_t := 0.0
var zone_t := 0.0
var ending := false
var post: ShaderMaterial
var trauma := 0.0
var step_t := 0.0
var sun: DirectionalLight3D
var env: Environment
var kit: MapKit
var combat: Combat
var quests: Quests
var lessons: Lessons
var scene: Cutscene
var folk: Folk
var portals: Portals
var map                          # hand-built map script (scripts/maps/<id>.gd) or the DataMap builder

## Map data stores ground positions as [x, z].
static func v3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	return Vector3(a[0], 0, a[1]) if a.size() == 2 else Vector3(a[0], a[1], a[2])

func _ready() -> void:
	map_id = get_meta("data").get("map", "eden")
	def = G.data("maps/" + map_id)
	G.cur_map = map_id; G.cur_act = def.act
	var at: Variant = get_meta("data").get("at")      # where a portal sets the pilgrim down
	G.cur_at = at if at != null else []
	if not map_id in G.visited:
		G.visited.append(map_id)
	kind = String(Portals.node(map_id).get("kind", "story"))
	add_to_group("world")
	if kind == "town":
		G.last_town = map_id
		if not map_id in G.milestones:
			G.milestones.append(map_id)
	G.base_cap = G.cap_for(int(def.get("base_cap", G.PROG["pilgrim_base_cap"])))
	if def.has("burden"):
		G.burden = def.burden and not G.flags.has("burden_gone")
	kit = MapKit.new(self); combat = Combat.new(self); quests = Quests.new(self)
	lessons = Lessons.new(self); scene = Cutscene.new(self); folk = Folk.new(self); portals = Portals.new(self)
	cam_dist = float(def.get("cam_dist", cam_dist))
	_build_env()
	_build_player()
	_build_camera()
	var builder := DataMap.new(self)
	map = load(MAP_SCRIPT % map_id).new(self) if ResourceLoader.exists(MAP_SCRIPT % map_id) else builder
	map.build()
	builder.populate()
	quests.load_map(def)
	combat.spawn_group("")
	hud = load("res://scripts/ui/hud.gd").new()
	hud.world = self
	add_child(hud)
	G.level_up.connect(kit._on_level_up)
	hud.banner(info("name"), info("sub"))
	if G.weary:
		get_tree().create_timer(WEARY_ON_ENTER_S).timeout.connect(combat._weary_end)
	if not G.flags.has("done_" + map_id):   # the chapter's opening lines belong to its first telling
		for line in def.get("enter_say", []):
			G.say(line, G.INFO)
	G.audio.music(String(def.get("music", "")))
	G.save_game()   # chapter boundary: Continue returns to the start of this map (or its saved objective)
	quests.begin()
	portals.build()
	combat.lair_ready()
	hud.refresh()

func info(k: String) -> Variant:
	if def.has(k):
		return v3(def[k]) if k == "start" else def[k]
	var v: Variant = def.look[k]
	match k:
		"bg", "amb", "sun_c", "mini": return Color(String(v))
		"tint": return Color(v[0], v[1], v[2])
		"post": return [v[0], v[1], Vector3(v[2][0], v[2][1], v[2][2])]
	return v

func is_combat() -> bool:
	return def.combat

## The Calling changes the robe; swap the sheet on the player's sprite.
func refresh_player_sheet() -> void:
	pact.sprite.texture = G.player_sheet
	pact.set_name_text("%s · %s" % [G.pname, G.job_name()])

# ------------------------------------------------------------------ environment
func _build_env() -> void:
	var env := Environment.new()
	Fx.quality_high = G.settings.fx_high
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.background_color = info("bg")
	env.ambient_light_color = info("amb"); env.ambient_light_energy = info("amb_e")
	env.glow_enabled = false  # Compatibility renderer glow is unreliable; bloom is faked with additive halo cards
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	self.env = env
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	G.sprite_tint = info("tint")
	_build_post()
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = info("sun_e")
	sun.light_color = info("sun_c")
	sun.shadow_enabled = false   # the art bible's one shadow is the blob under each sprite
	add_child(sun)

# ------------------------------------------------------------------ player and camera
func _build_player() -> void:
	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.6
	cs.shape = cap; cs.position.y = 0.8; player.add_child(cs)
	add_child(player)
	pact = SpriteActor.new()
	player.add_child(pact)
	var sheet: Texture2D = G.player_sheet if G.player_sheet else G.build_player_sheet()
	pact.setup({"tex": sheet, "hframes": 10, "vframes": 5, "pixel": PLAYER_HEIGHT / G.PLAYER_CELL.y, "rows": true,
		"anims": {"idle": [0], "walk": [1, 2, 3, 4], "attack": [5, 6], "sit": [7], "rest": [8], "cast": [9]}}, G.pname if G.job_id == G.PILGRIM else "%s · %s" % [G.pname, G.job_name()], Color.WHITE)
	player.position = v3(G.cur_at) if G.cur_at.size() >= 2 else info("start")

func _build_camera() -> void:
	cam_rig = Node3D.new(); add_child(cam_rig)
	cam = Camera3D.new(); cam.fov = 30.0; cam.far = 200.0
	cam_rig.add_child(cam)
	_place_camera(true)

## The camera eases toward the pilgrim at a rate per second (not per frame), so it moves the same on
## a 60 Hz and a 120 Hz screen, and it leans a little toward where the pilgrim is walking.
const CAM_FOLLOW := 8.0          # 1/s while playing
const CAM_FOLLOW_CINEMA := 2.4   # 1/s in staged scenes
const CAM_LEAD := 0.9            # world units of view ahead of a walking pilgrim
const CAM_LEAD_RATE := 2.2
const CAM_ZOOM_RATE := 3.0
const CAM_TURN_RATE := 7.5
var _lead := Vector3.ZERO

static func ease_rate(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)

func _place_camera(snap: bool = false, delta: float = 1.0 / 60.0) -> void:
	var pitch := deg_to_rad(52.0)
	var center: Vector3 = cam_focus if cam_focus != null else player.position
	var ahead := Vector3.ZERO
	if cam_focus == null and not cinema and not G.settings.reduce_motion and player.velocity.length() > 0.5:
		ahead = player.velocity.normalized() * CAM_LEAD
	_lead = Vector3.ZERO if snap else _lead.lerp(ahead, ease_rate(CAM_LEAD_RATE, delta))
	cam_rig.position = cam_rig.position.lerp(center + _lead, 1.0 if snap else ease_rate(CAM_FOLLOW_CINEMA if cinema else CAM_FOLLOW, delta))
	var d := cam_dist * (0.94 if (is_combat() and combat.in_combat()) else 1.0)
	_cur_dist = lerpf(_cur_dist if _cur_dist > 0.0 else d, d, ease_rate(CAM_ZOOM_RATE, delta))
	cam.position = Vector3(0, sin(pitch) * _cur_dist, cos(pitch) * _cur_dist)
	cam_rig.rotation.y = cam_yaw
	cam.look_at(cam_rig.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	# held upright, the view is fitted by its width so the road ahead is not cropped to a sliver
	cam.keep_aspect = Camera3D.KEEP_WIDTH if G.portrait else Camera3D.KEEP_HEIGHT
	cam.fov = PORTRAIT_FOV if G.portrait else LANDSCAPE_FOV
	# trauma-based shake (strength = trauma^2), off with Reduce Motion
	if trauma > 0.0 and not G.settings.reduce_motion:
		var k := trauma * trauma
		var tt := Time.get_ticks_msec() * 0.001
		cam.h_offset = k * 0.35 * sin(tt * 47.0) * cos(tt * 13.0)
		cam.v_offset = k * 0.28 * sin(tt * 53.0 + 1.7)
	else:
		cam.h_offset = 0.0; cam.v_offset = 0.0

var _cur_dist := 0.0

func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

## Hit-stop: freeze attacker and target together for a few frames (real-time timer).
func hitstop(dur: float) -> void:
	if G.settings.reduce_motion:
		dur *= 0.5
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = G.time_scale

func _build_post() -> void:
	var layer := CanvasLayer.new(); layer.layer = 5; add_child(layer)
	var r := ColorRect.new(); r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float vignette = 0.3;
uniform float tilt = 0.0;
uniform float danger = 0.0;
uniform vec3 danger_col = vec3(0.85, 0.08, 0.06);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	if (tilt > 0.0) {
		float m = smoothstep(0.24, 0.0, uv.y) + smoothstep(0.80, 1.0, uv.y);
		if (m > 0.02) {
			vec2 px = SCREEN_PIXEL_SIZE * (1.0 + 3.0 * m) * tilt;
			vec3 b = c * 0.2;
			b += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb * 0.1;
			b += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb * 0.1;
			b += texture(screen_tex, uv + vec2(0.0, px.y)).rgb * 0.1;
			b += texture(screen_tex, uv - vec2(0.0, px.y)).rgb * 0.1;
			b += texture(screen_tex, uv + px * 1.5).rgb * 0.1;
			b += texture(screen_tex, uv - px * 1.5).rgb * 0.1;
			b += texture(screen_tex, uv + vec2(px.x, -px.y) * 1.5).rgb * 0.1;
			b += texture(screen_tex, uv + vec2(-px.x, px.y) * 1.5).rgb * 0.1;
			c = mix(c, b, clamp(m, 0.0, 1.0));
		}
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	vec2 d = uv - 0.5;
	float v = smoothstep(0.85, 0.25, length(d * vec2(1.25, 1.0)));
	c *= mix(1.0 - vignette, 1.0, v);
	float edge = 1.0 - smoothstep(0.32, 0.75, length(d * vec2(1.0, 1.3)));
	c = mix(c, danger_col, danger * (1.0 - edge) * 0.55);
	COLOR = vec4(c, 1.0);
}"""
	post = ShaderMaterial.new(); post.shader = sh
	var pp: Array = info("post")
	post.set_shader_parameter("saturation", pp[0]); post.set_shader_parameter("contrast", pp[1]); post.set_shader_parameter("tint", pp[2])
	post.set_shader_parameter("vignette", 0.32)
	post.set_shader_parameter("tilt", 1.0 if G.settings.fx_high else 0.0)
	r.material = post
	layer.add_child(r)

func rotate_cam(steps: int) -> void:
	cam_yaw_target += steps * PI / 4.0

func zoom(dir: int) -> void:
	var i := zoom_presets.find(cam_dist)
	if i == -1:
		i = 1
	cam_dist = zoom_presets[clampi(i + dir, 0, 2)]

func zoom_by(factor: float) -> void:
	cam_dist = clampf(cam_dist * factor, 11.0, 24.0)

# ------------------------------------------------------------------ entities
func _add_ent(id: String, ename: String, pos: Vector3, node: Node3D, act: String, icon: String, fn: Callable, hidden: bool = false) -> Dictionary:
	var e := {"id": id, "name": ename, "pos": pos, "node": node, "act": act, "icon": icon, "fn": fn, "hidden": hidden}
	if node:
		node.visible = not hidden
	ents.append(e)
	return e

func ent(id: String) -> Dictionary:
	for e in ents:
		if e.id == id:
			return e
	return {}

# ------------------------------------------------------------------ the save file
## The journey is written down when a map is entered, when an objective is done, every AUTOSAVE_S
## while walking, and when the app goes to the background or closes. Continue returns the pilgrim
## to the very spot.
const AUTOSAVE_S := 30.0
var _next_autosave := AUTOSAVE_S

func autosave() -> void:
	if ending:
		return
	# keep the spot only where the map itself is kept (Eden and the side maps begin again from their start)
	if def.get("resumable", false) and not (combat.dead or cinema or quests.busy):
		G.cur_at = [snappedf(player.position.x, 0.01), snappedf(player.position.z, 0.01)]
	G.save_game()
	_next_autosave = t + AUTOSAVE_S

## A gate the story has opened stops being a wall (the Wicket Gate, once Goodwill has let the pilgrim in).
var gates: Array = []
func open_gates() -> void:
	for cs in gates:
		(cs as CollisionShape3D).set_deferred("disabled", true)

func show_ent(id: String, on: bool) -> void:
	var e := ent(id)
	if e.is_empty():
		return
	e.hidden = not on
	if e.node:
		e.node.visible = on

func _approach_point(p: Vector3) -> Vector3:
	var dir := (player.position - p); dir.y = 0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	return p + dir.normalized() * 1.6

# ------------------------------------------------------------------ input from HUD
func joystick(v: Vector2) -> void:
	if v.length() > 0.0:
		move_target = null; pending = null
		if sitting:
			_stand()

func tap(screen_pos: Vector2) -> void:
	if combat.dead:
		return
	# 1) entities and mobs under the finger
	var best = null; var best_d := PICK_PX
	for m in combat.mobs:
		if not m.alive:
			continue
		var sp := cam.unproject_position(m.actor.position + Vector3(0, 0.7, 0))
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d; best = {"mob": m}
	for e in ents:
		if e.hidden:
			continue
		var sp2 := cam.unproject_position(e.pos + Vector3(0, 1.0, 0))
		var d2 := sp2.distance_to(screen_pos)
		if d2 < best_d:
			best_d = d2; best = {"ent": e}
	for dr in kit.drops:
		var sp3 := cam.unproject_position(dr.pos)
		if sp3.distance_to(screen_pos) < best_d:
			best_d = sp3.distance_to(screen_pos); best = {"drop": dr}
	if sitting:
		_stand()
	if best != null:
		if best.has("mob"):
			combat.target = best.mob; pending = null; move_target = null
			return
		if best.has("ent"):
			pending = best.ent; combat.target = null; move_target = _approach_point(best.ent.pos)
			return
		if best.has("drop"):
			move_target = best.drop.pos; pending = null; combat.target = null
			return
	# 2) ground
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return
	var k := -from.y / dir.y
	var hit := from + dir * k
	hit.x = clampf(hit.x, bounds.position.x, bounds.end.x); hit.z = clampf(hit.z, bounds.position.y, bounds.end.y)
	move_target = hit; pending = null; combat.target = null
	hud.ground_marker(screen_pos)

func act_pressed() -> void:
	var n = nearest_ent()
	if n != null:
		use(n)

## Use an interactable: objectives and data dialogue come first, then the entity's own action.
func use(e: Dictionary) -> void:
	if quests.use_ent(e):
		return
	var fn: Callable = e.fn
	if fn.is_valid():
		fn.call()

func nearest_ent() -> Variant:
	var best = null; var bd := ACT_RANGE
	for e in ents:
		if e.hidden or e.get("kind", "") == "guide":
			continue
		var d := Vector2(player.position.x - e.pos.x, player.position.z - e.pos.z).length()
		if d < bd:
			bd = d; best = e
	return best

func use_item(item: String) -> void:
	if not G.bag_take(item):
		G.say("You have no %s." % item, G.WARN); return
	var c: Dictionary = G.data("items").consumables.get(item, {"heal": 20})
	var h := minf(G.hp_max - G.hp, float(c.get("heal", 0)))
	G.hp += h; G.zeal = minf(G.zeal_max, G.zeal + float(c.get("zeal", 0)))
	kit._float_text(player.position + Vector3(0, 2.2, 0), "+%d" % int(h if h > 0 else float(c.get("zeal", 0))), Color("7cff7c") if h > 0 else Color("8ac8ff"))
	G.say("Used %s." % item, G.SYS)
	G.stats_changed.emit()

func toggle_sit() -> void:
	if sitting:
		_stand()
	else:
		sitting = true; move_target = null; pending = null; combat.target = null
		pact.play("sit"); G.say("You sit and rest. (Faster recovery)", G.SYS)

func _stand() -> void:
	sitting = false; pact.play("idle")

func set_auto(on: bool) -> void:
	auto_on = on
	G.say("Auto battle %s." % ("on" if on else "off"), G.SYS)

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	t += delta
	combat.tick_cooldowns(delta)
	if combat.dead or cinema or (hud and (hud.overlay_open() or hud.coach.blocking())):
		player.velocity = Vector3.ZERO
		if not combat.dead and pact.anim == "walk":
			pact.play("idle")
		_place_camera(false, delta)
		return
	_move(_wanted_direction(), delta)
	_arrive()
	quests.tick(delta)
	portals.tick()
	if t >= _next_autosave:
		autosave()
	_auto_battle()
	if is_combat():
		combat._mob_tick(delta)
	combat.lair_tick()
	if combat.boss != null:
		combat._boss_tick(delta)
	combat._allies_tick(delta)
	folk._others_tick(delta)
	folk.followers_tick(delta)
	quests._glint_tick()
	if map.has_method("tick"):
		map.tick(delta)
	kit._drop_tick()
	_regen(delta)
	combat.fire_queued()
	kit._ambient_tick(delta)
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, ease_rate(CAM_TURN_RATE, delta))
	trauma = maxf(0.0, trauma - delta * 1.6)
	_place_camera(false, delta)

## Joystick wins, then chasing the target, then tap-to-walk.
func _wanted_direction() -> Vector3:
	var jv: Vector2 = hud.joy_vec() if hud else Vector2.ZERO
	if jv.length() > 0.0:
		move_target = null; pending = null
		if combat.target != null and not auto_on:
			combat.target = null
		return Basis(Vector3.UP, cam_yaw) * Vector3(jv.x, 0, jv.y)
	if combat.target != null and combat.target.alive:
		var to: Vector3 = combat.target.actor.position - player.position; to.y = 0
		if to.length() > MELEE_RANGE:
			return to.normalized()
		pact.facing = to.normalized()
		combat.basic_attack()
	elif move_target != null:
		var to2: Vector3 = move_target - player.position; to2.y = 0
		if to2.length() > 0.25:
			return to2.normalized()
		move_target = null
	return Vector3.ZERO

func _move(v: Vector3, delta: float) -> void:
	if v.length() > 0.0:
		var slow := speed_factor()
		var frac := minf(1.0, maxf(v.length(), 0.35))
		player.velocity = v.normalized() * SPEED * slow * frac
		pact.facing = v.normalized()
		pact.play("walk")
		pact.speed_mul = frac * slow   # no foot sliding
		step_t += delta * frac
		if step_t > STEP_DUST_S:
			step_t = 0.0
			Fx.dust(self, player.position, Color(0.78, 0.75, 0.69, 0.45), 2); G.sfx("step")
	else:
		player.velocity = Vector3.ZERO
		if not sitting and pact.anim == "walk":
			pact.play("idle")
	player.move_and_slide()
	player.position.y = 0.0
	_zones(delta)

## Weariness, the burden and bad ground (a map's "zones") all slow the pilgrim.
func speed_factor() -> float:
	var f := WEARY_SPEED if G.weary else 1.0
	if G.burden:
		f *= float(G.PROG["burden_slow"])
	if combat.has_status("slow"):
		f *= float(G.PROG["status"].slow.factor)
	var z := _zone_here()
	return f * float(z.get("slow", 1.0))

func _zone_here() -> Dictionary:
	var p := Vector2(player.position.x, player.position.z)
	for z in def.get("zones", []):
		var a: Array = z.area
		if not Rect2(a[0], a[1], a[2], a[3]).has_point(p):
			continue
		for sp in z.get("safe", []):   # firm footing inside bad ground (the stepping stones)
			if p.distance_to(Vector2(sp[0], sp[1])) < float(z.safe_r):
				return {}
		return z
	return {}

## Once a second, bad ground drains or hurts.
func _zones(delta: float) -> void:
	zone_t += delta
	if zone_t < 1.0:
		return
	zone_t = 0.0
	var z := _zone_here()
	if z.has("hurt"):
		combat._hurt_player(int(z.hurt))
		G.say("You strayed into %s! Keep to the midst of the path." % z.name, G.WARN)
	elif z.has("drain") and G.hp > G.hp_max * 0.3:   # the mire wears a pilgrim down but never fells one
		G.hp -= float(z.drain); G.stats_changed.emit()

func _arrive() -> void:
	if pending == null or Vector2(player.position.x - pending.pos.x, player.position.z - pending.pos.z).length() >= ARRIVE_RANGE:
		return
	var pe: Dictionary = pending; pending = null; move_target = null
	pact.facing = (pe.pos - player.position).normalized()
	if not pe.hidden:
		use(pe)

## Auto battle stays within the Tier 1 scope: auto-attack and the first two Pilgrim skills, in fields only.
func _auto_battle() -> void:
	if not (auto_on and is_combat()):
		return
	if combat.target == null or not combat.target.alive:
		combat.target = combat._nearest_mob(AUTO_SEEK_RANGE)
	if combat.target != null and combat.ready("steps") and combat.target.actor.position.distance_to(player.position) < 2.2:
		combat.skill("steps")
	if G.hp < G.hp_max * AUTO_HEAL_BELOW and combat.ready("refuge"):
		combat.skill("refuge")

func _regen(delta: float) -> void:
	regen_t += delta
	if regen_t < 1.0:
		return
	regen_t = 0.0
	var mult := SIT_REGEN if sitting else 1.0
	G.zeal = minf(G.zeal_max, G.zeal + float(G.d.regen) * mult + combat.zeal_regen_bonus())
	if not (is_combat() and combat._any_aggro()):
		G.hp = minf(G.hp_max, G.hp + 1.0 * mult)
	G.stats_changed.emit()

func _process(_d: float) -> void:
	for f in kit._followers:
		if is_instance_valid(f[0]):
			f[0].global_position = player.global_position + f[1]
