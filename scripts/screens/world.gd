class_name World
extends Node3D
## The 3D world: classic RO presentation (2D sprites on a lit 3D map, fixed three-quarter camera)
## with RO M / Origin phone controls (joystick, attack + skill arc, auto, context Act button).
## Maps (GDD v0.3 world model): "eden" and "city" are the Way (solo, with traces of other pilgrims);
## "palace" is the first House (shared hub, simulated in this offline demo); "lions" is a party Muster.

const SPEED := 4.6
const PICK_PX := 70.0

var map_id := "eden"
const MAPS := {
	"eden": {"name": "Eden Isle", "sub": "Prologue · The Garden", "code": "eden_isle", "combat": false, "layer": "The Way", "mini": Color("8cc062"), "start": Vector3(-14, 0, 6),
		"bg": Color("2e4a2a"), "amb": Color("e8eef8"), "amb_e": 0.42, "tint": Color(1.03, 1.0, 0.93), "sun_e": 0.78, "sun_c": Color("fff3dc"), "post": [1.06, 1.05, Vector3(1.04, 1.01, 0.94)]},
	"city": {"name": "City of Destruction", "sub": "Chapter 1 · Flee from the wrath to come", "code": "destruction", "combat": true, "layer": "The Way", "mini": Color("9c9484"), "start": Vector3(-12, 0, 3),
		"bg": Color("2a2832"), "amb": Color("a8a4c0"), "amb_e": 0.38, "tint": Color(0.86, 0.87, 0.98), "sun_e": 0.55, "sun_c": Color("c8c4d8"), "post": [0.72, 1.08, Vector3(0.93, 0.95, 1.05)]},
	"palace": {"name": "Palace Beautiful", "sub": "House · where pilgrims meet (online preview)", "code": "palace_beautiful", "combat": false, "layer": "House", "mini": Color("a8c48a"), "start": Vector3(0, 0, 11),
		"bg": Color("3a4a30"), "amb": Color("f2eaf8"), "amb_e": 0.46, "tint": Color(1.04, 1.0, 0.94), "sun_e": 0.82, "sun_c": Color("ffeacc"), "post": [1.1, 1.05, Vector3(1.06, 1.0, 0.92)]},
	"lions": {"name": "The Lions' Gate", "sub": "Muster · Party · Normal", "code": "lions_gate", "combat": true, "layer": "Muster", "mini": Color("b0a080"), "start": Vector3(0, 0, 10),
		"bg": Color("342c24"), "amb": Color("dcc4ac"), "amb_e": 0.40, "tint": Color(1.0, 0.93, 0.87), "sun_e": 0.62, "sun_c": Color("ffc890"), "post": [0.92, 1.1, Vector3(1.06, 0.96, 0.88)]}}
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
var ending := false
var post: ShaderMaterial
var trauma := 0.0
var step_t := 0.0
var sun: DirectionalLight3D
var env: Environment
## Systems (each owns its state; see scripts/systems and scripts/world).
var kit: MapKit
var combat: Combat
var quests: Quests
var lessons: Lessons
var scene: Cutscene
var folk: Folk
var map                          # the current map's script (scripts/maps/<id>.gd)

func _ready() -> void:
	map_id = get_meta("data").get("map", "eden")
	G.base_cap = 5 if map_id == "eden" else 10
	if not MAPS.has(map_id):
		map_id = "eden"
	kit = MapKit.new(self); combat = Combat.new(self); quests = Quests.new(self)
	lessons = Lessons.new(self); scene = Cutscene.new(self); folk = Folk.new(self)
	_build_env()
	_build_player()
	if map_id == "lions":
		cam_dist = 20.0
	_build_camera()
	map = load("res://scripts/maps/%s.gd" % map_id).new(self)
	map.build()
	hud = load("res://scripts/ui/hud.gd").new()
	hud.world = self
	add_child(hud)
	G.level_up.connect(kit._on_level_up)
	quests._update_quest()
	hud.banner(info("name"), info("sub"))
	if G.weary:
		get_tree().create_timer(15.0).timeout.connect(combat._weary_end)
	match map_id:
		"eden":
			G.say("Welcome to Eden Isle, the Dreamer's vision of the garden.", G.INFO)
			get_tree().create_timer(1.6).timeout.connect(lessons._eden_intro)
		"city":
			G.burden = true
			G.say("A great burden weighs upon your back.", G.WARN)
			if get_meta("data").get("wake", false):
				scene._wake_scene()
			else:
				get_tree().create_timer(1.0).timeout.connect(lessons._city_lessons)
		"palace":
			G.burden = false
			G.say("The House Beautiful. Pilgrims who walked the Way alone meet here.", G.INFO)
			G.say("Online preview: the other pilgrims here are simulated in this offline demo.", G.SYS)
		"lions":
			G.burden = false
			G.say("Your company is mustered. Giant Grim backs the lions; drive him from the way.", G.WARN)
			get_tree().create_timer(1.6).timeout.connect(func(): G.say("Step out of red circles. The big slam fills a wide ring around the Giant.", G.SYS))
	hud.refresh()

func info(k: String) -> Variant:
	return MAPS[map_id][k]

func is_combat() -> bool:
	return MAPS[map_id].combat

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
	sun.shadow_enabled = true
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
	pact.setup({"tex": sheet, "hframes": 10, "vframes": 5, "pixel": 0.042, "rows": true,
		"anims": {"idle": [0], "walk": [1, 2, 3, 4], "attack": [5, 6], "sit": [7], "rest": [8], "cast": [9]},
		"fps": {"walk": 9.0, "attack": 6.0}}, G.pname, Color.WHITE)
	player.position = info("start")

func _build_camera() -> void:
	cam_rig = Node3D.new(); add_child(cam_rig)
	cam = Camera3D.new(); cam.fov = 30.0; cam.far = 200.0
	cam_rig.add_child(cam)
	_place_camera(true)

func _place_camera(snap: bool = false) -> void:
	var pitch := deg_to_rad(52.0)
	var center: Vector3 = cam_focus if cam_focus != null else player.position
	cam_rig.position = cam_rig.position.lerp(center, 1.0 if snap else (0.04 if cinema else 0.15))
	var d := cam_dist * (0.94 if (is_combat() and combat.in_combat()) else 1.0)
	_cur_dist = lerpf(_cur_dist if _cur_dist > 0.0 else d, d, 0.05)
	cam.position = Vector3(0, sin(pitch) * _cur_dist, cos(pitch) * _cur_dist)
	cam_rig.rotation.y = cam_yaw
	cam.look_at(cam_rig.global_position + Vector3(0, 0.9, 0), Vector3.UP)
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
	Engine.time_scale = 0.03
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

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
		if e.hidden or e.fn == null:
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
		n.fn.call()

func nearest_ent() -> Variant:
	var best = null; var bd := 2.6
	for e in ents:
		if e.hidden or e.fn == null or e.get("kind", "") == "guide":
			continue
		var d := Vector2(player.position.x - e.pos.x, player.position.z - e.pos.z).length()
		if d < bd:
			bd = d; best = e
	return best

func use_item(item: String) -> void:
	if not G.bag_take(item):
		G.say("You have no %s." % item, G.WARN); return
	var h := minf(G.hp_max - G.hp, 40.0 if item == "Bread of Provision" else 20.0)
	G.hp += h
	kit._float_text(player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
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

func _finish() -> void:
	if ending:
		return
	ending = true
	match map_id:
		"city": G.goto("story", {"id": "onward"})
		_: G.goto("end")

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	t += delta
	combat.gcd = maxf(0.0, combat.gcd - delta)
	for k in combat.cd.keys():
		combat.cd[k] = maxf(0.0, combat.cd[k] - delta)
	if combat.dead or cinema or (hud and (hud.overlay_open() or hud.coach.blocking())):
		player.velocity = Vector3.ZERO
		if not combat.dead and pact.anim == "walk":
			pact.play("idle")
		_place_camera()
		return
	var v := Vector3.ZERO
	var jv: Vector2 = hud.joy_vec() if hud else Vector2.ZERO
	var basis_y := Basis(Vector3.UP, cam_yaw)
	if jv.length() > 0.0:
		v = basis_y * Vector3(jv.x, 0, jv.y)
		move_target = null; pending = null
		if combat.target != null and auto_on == false:
			combat.target = null
	elif combat.target != null and combat.target.alive:
		var to: Vector3 = combat.target.actor.position - player.position; to.y = 0
		if to.length() > 1.8:
			v = to.normalized()
		else:
			pact.facing = to.normalized()
			if t > combat.next_atk and combat.gcd <= 0.0:
				# basic attack from attributes: Fortitude (damage), Diligence (speed), Sobriety (misses), Hope (crits)
				combat.next_atk = t + float(G.d.interval)
				pact.play_once("attack", 0.32)
				var crit := randf() < float(G.d.crit)
				var dmg := int(G.d.atk) + randi_range(-2, 2)
				combat.hit_mob(combat.target, dmg * (2 if crit else 1), crit, randf() < float(G.d.miss))
	elif move_target != null:
		var to2: Vector3 = move_target - player.position; to2.y = 0
		if to2.length() > 0.25:
			v = to2.normalized()
		else:
			move_target = null
	if v.length() > 0.0:
		var spd := SPEED * (0.8 if G.weary else 1.0)
		var frac := minf(1.0, maxf(v.length(), 0.35))
		player.velocity = v.normalized() * spd * frac
		pact.facing = v.normalized()
		pact.play("walk")
		pact.speed_mul = frac * (0.8 if G.weary else 1.0)   # no foot sliding
		step_t += delta * frac
		if step_t > 0.34:
			step_t = 0.0
			Fx.dust(self, player.position, Color(0.85, 0.82, 0.72, 0.45) if map_id == "eden" else Color(0.7, 0.68, 0.66, 0.45), 2)
	else:
		player.velocity = Vector3.ZERO
		if not sitting and pact.anim == "walk":
			pact.play("idle")
	player.move_and_slide()
	player.position.y = 0.0
	# arrive at an interactable
	if pending != null and Vector2(player.position.x - pending.pos.x, player.position.z - pending.pos.z).length() < 2.4:
		var pe: Dictionary = pending; pending = null; move_target = null
		pact.facing = (pe.pos - player.position).normalized()
		if not pe.hidden:
			pe.fn.call()
	# zone objectives
	if quests.obj_idx < quests.objectives.size() and quests.objectives[quests.obj_idx].has("zone"):
		var z: Vector3 = quests.objectives[quests.obj_idx].zone
		if Vector2(player.position.x - z.x, player.position.z - z.z).length() < 1.6:
			if quests.cur_obj() in ["light", "return"]:
				_finish()
			else:
				quests.complete()
	# auto battle (within the Tier 1 auto scope: auto-attack and the auto-skill slots)
	if auto_on and is_combat():
		if combat.target == null or not combat.target.alive:
			combat.target = combat._nearest_mob(14.0)
		if G.has_skill("steps") and combat.target != null and combat.cd.steps <= 0.0 and G.zeal >= 10 and combat.target.actor.position.distance_to(player.position) < 2.2 and combat.gcd <= 0.0:
			combat.skill("steps")
		if G.has_skill("refuge") and G.hp < G.hp_max * 0.45 and combat.cd.refuge <= 0.0 and G.zeal >= 15:
			combat.skill("refuge")
	if is_combat():
		combat._mob_tick(delta)
	if combat.boss != null:
		combat._boss_tick(delta)
	combat._allies_tick(delta)
	folk._others_tick(delta)
	quests._glint_tick()
	if map.has_method("tick"):
		map.tick(delta)
	lessons._city_tips_tick()
	kit._drop_tick()
	# regeneration (faster while sitting)
	regen_t += delta
	if regen_t >= 1.0:
		regen_t = 0.0
		var mult := 3.0 if sitting else 1.0
		G.zeal = minf(G.zeal_max, G.zeal + float(G.d.regen) * mult)
		if not (is_combat() and combat._any_aggro()):
			G.hp = minf(G.hp_max, G.hp + 1.0 * mult)
		G.stats_changed.emit()
	if combat.queued_skill != "" and combat.gcd <= 0.0:
		var qs := combat.queued_skill; combat.queued_skill = ""
		combat.skill(qs)
	kit._ambient_tick(delta)
	# camera
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, 0.12)
	trauma = maxf(0.0, trauma - delta * 1.6)
	_place_camera()
	# warp spin
	var w := ent("warp")
	if not w.is_empty() and w.node.has_meta("spin"):
		w.node.get_meta("spin").rotation.y += delta * 1.5

func _process(_d: float) -> void:
	for f in kit._followers:
		if is_instance_valid(f[0]):
			f[0].global_position = player.global_position + f[1]
