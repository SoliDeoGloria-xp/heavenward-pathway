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
var others: Array = []           # other pilgrims: {actor, path, i, speed, ghost, fade, chat_t, kind}
var allies: Array = []           # Muster party: {actor, name, role, ai, next, slot}
var boss = null                  # Muster boss mob dict
var boss_atk_t := 0.0
var boss_count := 0
var boss_enraged := false
var secret_ids: Array = []
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
var target = null               # mob dict being attacked
var auto_on := false
var sitting := false
var dead := false
var next_atk := 0.0
var cd := {"steps": 0.0, "refuge": 0.0, "tend": 0.0}
var cam_focus = null             # Vector3 the camera looks at during story scenes (null = the player)
var cinema := false              # story scene playing: input and the HUD step aside
var dreamer: SpriteActor         # the guide who walks beside you in Eden
var lilies: Array = []           # {actor, pos, bloomed}
var lilies_done := 0
var used_steps := false
var _serpent: SpriteActor
var _cherub_nodes: Array = []
var gcd := 0.0
var ents: Array = []             # interactables: {id, name, pos, node, act, icon, fn, hidden}
var mobs: Array = []             # {node, actor, hp, max, alive, pos, next, aggro, home, bar, respawn}
var drops: Array = []
var objectives: Array = []
var obj_idx := 0
var quest_mark: Label3D
var zone_fx: Node3D
var bounds := Rect2(-26, -18, 52, 36)
var slain := 0
var snapshot_unlocked := false
var t := 0.0
var regen_t := 0.0
var ending := false
var _vine_leaves: Array = []
var post: ShaderMaterial
var trauma := 0.0
var lamps: Array = []
var sways: Array = []
var holy_lights: Array = []
var queued_skill := ""
var step_t := 0.0
var target_ring: Sprite3D
var last_target = null
var low_hp_pulse := 0.0
var sun: DirectionalLight3D
var env: Environment
var burden_fx: CPUParticles3D
var weary_fx: CPUParticles3D
var _lamb_actor: SpriteActor

func _ready() -> void:
	map_id = get_meta("data").get("map", "eden")
	if not MAPS.has(map_id):
		map_id = "eden"
	_build_env()
	_build_player()
	if map_id == "lions":
		cam_dist = 20.0
	_build_camera()
	match map_id:
		"eden": _build_eden()
		"city": _build_city()
		"palace": _build_palace()
		"lions": _build_lions()
	hud = load("res://scripts/ui/hud.gd").new()
	hud.world = self
	add_child(hud)
	G.level_up.connect(_on_level_up)
	_update_quest()
	hud.banner(info("name"), info("sub"))
	if G.weary:
		get_tree().create_timer(15.0).timeout.connect(_weary_end)
	match map_id:
		"eden":
			G.say("Welcome to Eden Isle, the Dreamer's vision of the garden.", G.INFO)
			get_tree().create_timer(1.6).timeout.connect(_eden_intro)
		"city":
			G.burden = true
			G.say("A great burden weighs upon your back.", G.WARN)
			if get_meta("data").get("wake", false):
				_wake_scene()
			else:
				get_tree().create_timer(1.0).timeout.connect(_city_lessons)
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

func _mat(path: String, scale: Vector2 = Vector2.ONE, triplanar: bool = false, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = G.tex(path)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if triplanar:
		m.uv1_triplanar = true; m.uv1_scale = Vector3(scale.x, scale.y, scale.x)
	else:
		m.uv1_scale = Vector3(scale.x, scale.y, 1)
	m.roughness = 1.0
	return m

func _plane(size: Vector2, mat: Material, pos: Vector3, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = size
	mi.mesh = pm; mi.material_override = mat; mi.position = pos; mi.rotation.y = rot_y
	add_child(mi)
	return mi

func _box(size: Vector3, mat: Material, pos: Vector3, solid: bool = true, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos; mi.rotation.y = rot_y
	add_child(mi)
	if solid:
		_solid_box(size, pos, rot_y)
	return mi

func _solid_box(size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; sb.add_child(cs); sb.position = pos; sb.rotation.y = rot_y; add_child(sb)

func _solid_cyl(r: float, pos: Vector3) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = r; sh.height = 3.0
	cs.shape = sh; sb.add_child(cs); sb.position = pos + Vector3(0, 1.5, 0); add_child(sb)

func _sphere(r: float, mat: Material, pos: Vector3, squash: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0 * squash; sm.radial_segments = 10; sm.rings = 6
	mi.mesh = sm; mi.material_override = mat; mi.position = pos
	add_child(mi)
	return mi

func _tree(pos: Vector3, s: float = 1.0, leaf_tint: Color = Color.WHITE, fruit: Color = Color(0, 0, 0, 0), solid: bool = true) -> Node3D:
	var root := Node3D.new(); root.position = pos; add_child(root)
	var trunk := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.22 * s; cm.bottom_radius = 0.32 * s; cm.height = 2.0 * s; cm.radial_segments = 8
	trunk.mesh = cm; trunk.material_override = _mat("res://assets/tiles/bark.png", Vector2(1, 2)); trunk.position.y = s
	root.add_child(trunk)
	var lm := _mat("res://assets/tiles/leaves.png", Vector2(2, 2), true, leaf_tint)
	for off in [Vector3(0, 2.6, 0), Vector3(-0.8, 2.1, 0.3), Vector3(0.8, 2.15, -0.2), Vector3(0.1, 2.0, 0.8)]:
		var sp := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.1 * s; sm.height = 1.9 * s; sm.radial_segments = 10; sm.rings = 6
		sp.mesh = sm; sp.material_override = lm; sp.position = off * s
		root.add_child(sp)
	if fruit.a > 0.0:
		var fm := StandardMaterial3D.new(); fm.albedo_color = fruit; fm.roughness = 0.5
		for i in 7:
			var a := i * TAU / 7.0
			var f := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.16 * s; fs.height = 0.32 * s
			f.mesh = fs; f.material_override = fm
			f.position = Vector3(cos(a) * 1.2, 2.0 + (i % 3) * 0.35, sin(a) * 1.2) * s
			root.add_child(f)
	if solid:
		_solid_cyl(0.45 * s, pos)
	sways.append([root, randf() * TAU])
	return root

func _walls() -> void:
	var h := 3.0
	_solid_box(Vector3(bounds.size.x + 2, h, 1), Vector3(bounds.get_center().x, h / 2, bounds.position.y - 0.5))
	_solid_box(Vector3(bounds.size.x + 2, h, 1), Vector3(bounds.get_center().x, h / 2, bounds.end.y + 0.5))
	_solid_box(Vector3(1, h, bounds.size.y + 2), Vector3(bounds.position.x - 0.5, h / 2, bounds.get_center().y))
	_solid_box(Vector3(1, h, bounds.size.y + 2), Vector3(bounds.end.x + 0.5, h / 2, bounds.get_center().y))

func _water(size: Vector2, pos: Vector3) -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform vec2 scale = vec2(8.0, 2.0);
void fragment(){
	vec2 uv = UV * scale;
	vec3 a = texture(tex, uv + vec2(TIME * 0.05, TIME * 0.02)).rgb;
	vec3 b = texture(tex, uv * 1.3 - vec2(TIME * 0.03, 0.0)).rgb;
	vec2 cell = floor(uv * 7.0);
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float glint = step(0.93, fract(rnd + TIME * 0.35)) * step(0.6, fract(uv.x * 7.0)) * 0.35;
	ALBEDO = mix(a, b, 0.5) * vec3(0.95, 1.0, 1.05) + vec3(glint);
}"""
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("tex", G.tex("res://assets/tiles/water.png"))
	m.set_shader_parameter("scale", Vector2(size.x / 4.0, size.y / 4.0))
	_plane(size, m, pos)

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
	var d := cam_dist * (0.94 if (is_combat() and in_combat()) else 1.0)
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

func _label3d(text: String, pos: Vector3, color: Color = Color.WHITE, size: int = 34) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font = G.font_ui_bold; l.font_size = size; l.outline_size = 10
	l.modulate = color; l.outline_modulate = Color(0.06, 0.05, 0.1); l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.render_priority = 5
	l.position = pos; add_child(l)
	return l

func _sprite_npc(tex_path: String, hframes: int, vframes: int, rows: bool, pos: Vector3, nm: String, color: Color, pixel: float = 0.042, flip_inv := false) -> SpriteActor:
	var a := SpriteActor.new()
	add_child(a)
	a.position = pos
	var idle := [0, 1] if hframes >= 2 else [0]
	a.setup({"tex": G.tex(tex_path), "hframes": hframes, "vframes": vframes, "pixel": pixel, "rows": rows,
		"anims": {"idle": idle}, "fps": {"idle": 1.6}, "flip_inverted": flip_inv}, nm, color)
	return a

# ------------------------------------------------------------------ Eden Isle
func _build_eden() -> void:
	bounds = Rect2(-26, -16, 52, 34)
	_plane(Vector2(120, 100), _mat("res://assets/tiles/grass.png", Vector2(60, 50), false, Color(0.86, 0.9, 0.78)), Vector3(0, 0, 0))
	_plane(Vector2(52, 3.2), _mat("res://assets/tiles/dirt.png", Vector2(26, 1.6), false, Color(0.86, 0.8, 0.7)), Vector3(0, 0.01, 7), 0.0)
	_plane(Vector2(3.2, 20), _mat("res://assets/tiles/dirt.png", Vector2(1.6, 10), false, Color(0.86, 0.8, 0.7)), Vector3(4, 0.012, -1))
	_water(Vector2(80, 6), Vector3(0, 0.03, -19))
	_box(Vector3(80, 0.6, 1.0), _mat("res://assets/tiles/dirt.png", Vector2(40, 1), true, Color("e8dcb0")), Vector3(0, 0.0, -15.6), false)
	# raised plateaus with cliffs (real height)
	for p in [[Vector3(-21, 0.7, -10), Vector3(10, 1.4, 9)], [Vector3(20, 0.9, 13), Vector3(14, 1.8, 8)], [Vector3(21, 0.6, -9), Vector3(10, 1.2, 8)]]:
		_box(p[1], _mat("res://assets/tiles/dirt.png", Vector2(0.5, 0.5), true, Color("c8a878")), p[0])
		_box(Vector3(p[1].x + 0.2, 0.18, p[1].z + 0.2), _mat("res://assets/tiles/grass.png", Vector2(0.5, 0.5), true), p[0] + Vector3(0, p[1].y * 0.5 + 0.08, 0), false)
		for k in 3:
			_tree(p[0] + Vector3(-p[1].x * 0.3 + k * p[1].x * 0.3, p[1].y * 0.5, randf_range(-1.5, 1.5)), randf_range(0.9, 1.2), Color(randf_range(0.9, 1.1), 1, randf_range(0.85, 1.0)), Color(0, 0, 0, 0), false)
	# border trees
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in 26:
		var side := i % 4
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(-26, 26), 0, 17.5)
			1: p = Vector3(-26.5, 0, rng.randf_range(-14, 17))
			2: p = Vector3(26.5, 0, rng.randf_range(-14, 17))
			3: p = Vector3(rng.randf_range(-12, 12), 0, -14.6)
		if side == 3 and absf(p.x) < 6:
			continue
		_tree(p, rng.randf_range(0.9, 1.3), Color(rng.randf_range(0.85, 1.1), 1, rng.randf_range(0.8, 1.0)))
	for i in 18:
		var bp := Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-12, 16))
		_sphere(0.55, _mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(0.9, 1.05, 0.85)), bp + Vector3(0, 0.35, 0), 0.7)
		var fl := StandardMaterial3D.new(); fl.albedo_color = [Color("f7e36a"), Color("f08ab8"), Color.WHITE][i % 3]; fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for k in 4:
			_sphere(0.08, fl, bp + Vector3(rng.randf_range(-0.9, 0.9), 0.08, rng.randf_range(-0.9, 0.9)))
	_walls()
	# vine trellis
	var vine := Node3D.new(); vine.position = Vector3(-4, 0, 3); add_child(vine)
	var wood := _mat("res://assets/tiles/bark.png", Vector2(1, 1), true)
	for x in [-1.0, 1.0]:
		var post := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.14, 1.6, 0.14); post.mesh = b; post.material_override = wood; post.position = Vector3(x, 0.8, 0); vine.add_child(post)
	var bar := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(2.3, 0.12, 0.12); bar.mesh = bb; bar.material_override = wood; bar.position.y = 1.55; vine.add_child(bar)
	var vleaf := _mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(0.8, 0.9, 0.7))
	var grapes := StandardMaterial3D.new(); grapes.albedo_color = Color("6a4c8c")
	var vine_leaves: Array = []
	for i in 5:
		var lf := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.5; lf.mesh = sm; lf.material_override = vleaf
		lf.position = Vector3(-0.9 + i * 0.45, 1.45 + (i % 2) * 0.1, 0.05); vine.add_child(lf); vine_leaves.append(lf)
		var gr := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.11; gs.height = 0.22; gr.mesh = gs; gr.material_override = grapes
		gr.position = Vector3(-0.8 + i * 0.4, 1.15, 0.15); vine.add_child(gr)
	_solid_box(Vector3(2.3, 2, 0.3), vine.position + Vector3(0, 1, 0))
	_vine_leaves = vine_leaves
	_add_ent("vine", "Young Vine", vine.position, vine, "Tend", "hand", _act_vine)
	# fig tree
	var fig := _tree(Vector3(6, 0, -2), 1.25, Color(0.95, 1.1, 0.9), Color("8c4a7a"))
	_add_ent("fig", "Fig Tree", fig.position, fig, "Gather", "hand", _act_fig)
	# lamb
	var lamb := _sprite_npc("res://assets/sprites/npc_lamb.png", 2, 1, false, Vector3(9, 0, 8), "Lamb", Color.WHITE, 0.04, true)
	_lamb_actor = lamb
	_add_ent("lamb", "Lamb", lamb.position, lamb, "Name", "tag", _act_lamb)
	# stone tablet
	var stone := Node3D.new(); stone.position = Vector3(-10, 0, -4); add_child(stone)
	var sm2 := MeshInstance3D.new(); var sbm := BoxMesh.new(); sbm.size = Vector3(1.2, 1.7, 0.35); sm2.mesh = sbm
	sm2.material_override = _mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.8, 0.8, 0.82)); sm2.position.y = 0.85; stone.add_child(sm2)
	_solid_box(Vector3(1.2, 2, 0.4), stone.position + Vector3(0, 1, 0))
	_add_ent("stone", "Stone Tablet", stone.position, stone, "Read", "library", _act_stone)
	# the two trees (shown after reading)
	var trees := Node3D.new(); trees.position = Vector3(16, 0, 0); add_child(trees)
	var life := _tree(Vector3(14.6, 0, 0), 1.35, Color(2.2, 1.9, 0.9), Color(0, 0, 0, 0), false)
	life.reparent(trees)
	var glow := OmniLight3D.new(); glow.light_color = Color("ffe9a0"); glow.light_energy = 2.0; glow.omni_range = 6.0; glow.position = Vector3(-1.4, 3, 0); trees.add_child(glow)
	holy_lights.append(glow)
	var lhalo := Sprite3D.new(); lhalo.texture = G.tex("res://assets/fx/glow.png"); lhalo.pixel_size = 0.12; lhalo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lhalo.shaded = false; lhalo.modulate = Color(1, 0.95, 0.7, 0.55); lhalo.position = Vector3(-1.4, 3.0, 0); trees.add_child(lhalo)
	holy_lights.append(lhalo)
	var know := _tree(Vector3(18, 0, 0.4), 1.3, Color(0.8, 0.95, 0.75), Color("d8342a"), false)
	know.reparent(trees)
	_add_ent("trees", "The Two Trees", Vector3(16, 0, 1.6), trees, "Behold", "eye", _act_trees, true)
	for sp in [Vector3(-12, 0, -6), Vector3(-2, 0, 0), Vector3(8, 0, -6), Vector3(3, 0, 9)]:
		Fx.shaft(self, sp, 10.0, 2.4, 0.18)
	_weather_petals()
	_edge_fade(Color("2e4a2a"))
	# Way traces and secrets (GDD v0.3): solo world, but never quite alone
	_add_secret("dreamer_note", Vector3(24.0, 0, 2.5), "The Dreamer's Note", "Written in a careful hand: \"Mark well the garden, for you will not walk here again.\"", {"xp": 20})
	_add_secret("lily", Vector3(-23.0, 0, -12.0), "A Lily Among Thorns", "A white lily grows alone by the water. [BSB: Song of Songs 2:2]  You take a cutting: Lily Hairpin (cosmetic headgear).", {"item": "Lily Hairpin"})
	_add_waymark(Vector3(-9.5, 0, 9.0), "Look up: the vine needs tending", "Wren", 18)
	_add_waymark(Vector3(-12.0, 0, -2.0), "Read slowly [BSB: Psalm 119:105]", "Psalter", 57)
	_add_passerby([Vector3(-24, 0, 4), Vector3(-6, 0, 8), Vector3(10, 0, 7), Vector3(24, 0, 5)], "Marigold", "walking in the garden", [1, 2, 2], true)
	_build_eden_guides()
	objectives = [
		{"id": "walk", "text": "Walk to the glowing circle by the Dreamer's lamp", "zone": Vector3(-8, 0, 7)},
		{"id": "tend", "text": "Tend the Young Vine (tap Act when close)", "ent": "vine"},
		{"id": "stats", "text": "Spend your attribute points (More → Status)"},
		{"id": "gather", "text": "Gather figs from the Fig Tree", "ent": "fig"},
		{"id": "learn", "text": "Learn Tend and Keep (More → Skills)"},
		{"id": "lilies", "text": "Tend the drooping lilies with your skill (0/3)"},
		{"id": "name", "text": "Give the Lamb a name", "ent": "lamb"},
		{"id": "read", "text": "Read the Stone Tablet (Word Study)", "ent": "stone"},
		{"id": "trees", "text": "Behold the two trees in the midst of the garden", "ent": "trees"}]

# ------------------------------------------------------------------ City of Destruction
func _build_city() -> void:
	bounds = Rect2(-24, -14, 48, 28)
	_plane(Vector2(120, 100), _mat("res://assets/tiles/cobble.png", Vector2(60, 50), false, Color(0.92, 0.9, 0.92)), Vector3.ZERO)
	_plane(Vector2(48, 4), _mat("res://assets/tiles/dirt.png", Vector2(24, 2), false, Color(0.75, 0.72, 0.7)), Vector3(0, 0.01, 0))
	var wall := _mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(0.8, 0.76, 0.74))
	var roof := _mat("res://assets/tiles/roof.png", Vector2(0.6, 0.6), true, Color(0.75, 0.7, 0.72))
	var houses := [Vector3(-18, 0, -11), Vector3(-9, 0, -12), Vector3(0, 0, -11.5), Vector3(9, 0, -12), Vector3(18, 0, -11)]
	var fence := _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.55, 0.45, 0.4))
	for i in 12:
		var fx := -22.0 + i * 4.0
		_box(Vector3(3.6, 0.12, 0.12), fence, Vector3(fx, 0.8, 12.8), false)
		_box(Vector3(3.6, 0.12, 0.12), fence, Vector3(fx, 0.45, 12.8), false)
		_box(Vector3(0.16, 1.0, 0.16), fence, Vector3(fx - 1.8, 0.5, 12.8), false)
	_solid_box(Vector3(48, 2, 0.4), Vector3(0, 1, 12.8))
	for cp in [Vector3(-8, 0, 10.5), Vector3(-7, 0, 11), Vector3(5, 0, 10.8), Vector3(16, 0, 10.2)]:
		_box(Vector3(1.0, 0.9, 1.0), _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.75, 0.62, 0.48)), cp + Vector3(0, 0.45, 0))
	for hp in houses:
		var w := randf_range(6.0, 7.5)
		_box(Vector3(w, 3.6, 5), wall, hp + Vector3(0, 1.8, 0))
		var pr := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(w + 0.8, 2.2, 5.6); pr.mesh = pm; pr.material_override = roof
		pr.position = hp + Vector3(0, 4.7, 0); add_child(pr)
		var win := StandardMaterial3D.new(); win.albedo_color = Color("e8b048"); win.emission_enabled = true; win.emission = Color("e8a040"); win.emission_energy_multiplier = 0.8
		var zf := 2.52 if hp.z < 0 else -2.52
		_box(Vector3(0.9, 0.8, 0.05), win, hp + Vector3(-w * 0.25, 2.2, zf), false)
		_box(Vector3(1.0, 1.8, 0.06), _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.5, 0.4, 0.35)), hp + Vector3(w * 0.15, 0.9, zf), false)
		_smoke(hp + Vector3(w * 0.3, 5.6, 0))
	for lp in [Vector3(-12, 0, -3), Vector3(0, 0, 3.2), Vector3(12, 0, -3)]:
		_box(Vector3(0.15, 3, 0.15), _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.3, 0.3, 0.32)), lp + Vector3(0, 1.5, 0))
		var lamp := OmniLight3D.new(); lamp.light_color = Color("ffb060"); lamp.light_energy = 1.6; lamp.omni_range = 5.5; lamp.position = lp + Vector3(0, 3.0, 0); add_child(lamp)
		lamps.append(lamp)
		var halo := Sprite3D.new(); halo.texture = G.tex("res://assets/fx/glow.png"); halo.pixel_size = 0.03; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.shaded = false; halo.modulate = Color(1, 0.75, 0.4, 0.7); halo.position = lp + Vector3(0, 3.05, 0); add_child(halo)
		var lm := StandardMaterial3D.new(); lm.albedo_color = Color("ffd38a"); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sphere(0.2, lm, lp + Vector3(0, 3.05, 0))
	for bp in [Vector3(-14, 0, 5), Vector3(-13.2, 0, 5.4), Vector3(10, 0, -6), Vector3(14, 0, 6)]:
		var bm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.42; cm.bottom_radius = 0.42; cm.height = 1.0
		bm.mesh = cm; bm.material_override = _mat("res://assets/tiles/bark.png", Vector2(1, 1), true); bm.position = bp + Vector3(0, 0.5, 0); add_child(bm)
		_solid_cyl(0.45, bp)
	_walls()
	var ev := _sprite_npc("res://assets/sprites/npc_evangelist.png", 2, 5, true, Vector3(2, 0, 2), "Evangelist", Color("9fd8ff"))
	_add_ent("evangelist", "Evangelist", ev.position, ev, "Talk", "talk", _act_evangelist, true)
	var warp := Node3D.new(); warp.position = Vector3(21, 0, 0); add_child(warp)
	var ws := Sprite3D.new(); ws.texture = G.tex("res://assets/fx/warp.png"); ws.pixel_size = 0.014; ws.rotation_degrees.x = -90; ws.position.y = 0.06
	ws.shaded = false; ws.transparent = true; warp.add_child(ws); warp.set_meta("spin", ws)
	var beam := Sprite3D.new(); beam.texture = G.tex("res://assets/fx/glow.png"); beam.pixel_size = 0.09; beam.scale = Vector3(1, 3, 1)
	beam.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; beam.shaded = false; beam.position.y = 3.0; beam.modulate = Color(1, 0.95, 0.75, 0.75); warp.add_child(beam)
	var wl := OmniLight3D.new(); wl.light_color = Color("fff0c0"); wl.light_energy = 3.0; wl.omni_range = 8.0; wl.position.y = 2.0; warp.add_child(wl)
	_add_ent("warp", "A Shining Light", warp.position, warp, "Enter", "warp", _finish, true)
	objectives = [
		{"id": "fight", "text": "Overcome the Slothlings (0/3)"},
		{"id": "talk", "text": "Speak with Evangelist", "ent": "evangelist"},
		{"id": "light", "text": "Follow the light toward the Wicket Gate", "ent": "warp", "zone": Vector3(21, 0, 0)}]
	for i in 6:
		_spawn_mob(Vector3(-4.0 + i * 3.8, 0, randf_range(-5, 6)))
	_edge_fade(Color("2a2832"))
	_add_secret("almanac", Vector3(-9.6, 0, 11.7), "An Old Almanac", "Pages of fortunes and festivals for the coming year. Not one word about the wrath to come.", {"xp": 15})
	_add_secret("drawing", Vector3(15.6, 0, 7.4), "A Child's Drawing", "A shining gate, drawn in charcoal by someone in this city who once hoped. You keep it: Charcoal Gate (Snapshot frame).", {"item": "Charcoal Gate frame"})
	_add_waymark(Vector3(-9.0, 0, 1.6), "Beware: Slothlings ahead. Step out of the red circle!", "Rook", 41)
	_add_waymark(Vector3(17.5, 0, 2.2), "Keep the light in your eye", "Tabitha", 112)
	_add_passerby([Vector3(-23, 0, -1), Vector3(-10, 0, -0.5), Vector3(6, 0, 0.8), Vector3(20, 0, 0)], "Ebenezer", "toward the Wicket Gate", [0, 4, 3], true)
	_add_passerby([Vector3(-23, 0, 2), Vector3(-4, 0, 1.5), Vector3(12, 0, -0.5), Vector3(20, 0, 0.5)], "Lumen", "toward the Wicket Gate", [2, 2, 1], true, 9.0)
	_weather_drizzle()
	Fx.particles(warp, warp.global_position + Vector3(0, 0.2, 0), {"amount": 24, "life": 2.2, "one_shot": false, "explode": 0.0, "sphere": 1.2, "vmin": 0.8, "vmax": 1.6, "spread": 8.0, "gravity": Vector3.ZERO, "color": Color("fff0c0"), "size": 0.14, "local": true})
	var ws2 := Sprite3D.new(); ws2.texture = G.tex("res://assets/fx/warp.png"); ws2.pixel_size = 0.011; ws2.rotation_degrees.x = -90; ws2.position.y = 0.08
	ws2.shaded = false; ws2.transparent = true; ws2.modulate = Color(1, 0.95, 0.7, 0.8); warp.add_child(ws2); warp.set_meta("spin2", ws2)
	holy_lights.append(wl)

func _smoke(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10; p.lifetime = 4.0; p.direction = Vector3(0.3, 1, 0); p.spread = 12.0; p.initial_velocity_min = 0.4; p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.15, 0.05, 0); p.scale_amount_min = 1.5; p.scale_amount_max = 3.0
	var q := QuadMesh.new(); q.size = Vector2(0.8, 0.8)
	var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.albedo_color = Color(0.35, 0.33, 0.38, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m; p.mesh = q; p.position = pos; add_child(p)

# ------------------------------------------------------------------ mobs
func _spawn_mob(pos: Vector3) -> void:
	var a := SpriteActor.new(); add_child(a); a.position = pos
	a.setup({"tex": G.tex("res://assets/sprites/mob_slothling.png"), "hframes": 7, "vframes": 1, "pixel": 0.04, "rows": false,
		"anims": {"idle": [0, 1], "walk": [2, 3], "hurt": [4], "die": [5, 6]}, "fps": {"idle": 2.0, "walk": 4.0, "die": 3.0}}, "Slothling", Color("ffe0e0"))
	var bg := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.9, 0.09); bg.mesh = q
	var bgm := StandardMaterial3D.new(); bgm.albedo_color = Color(0.1, 0.1, 0.12); bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; bgm.no_depth_test = true; bgm.render_priority = 4
	bg.material_override = bgm; bg.position.y = -0.45; bg.visible = false; a.add_child(bg)
	var fg := MeshInstance3D.new(); var q2 := QuadMesh.new(); q2.size = Vector2(0.86, 0.06); fg.mesh = q2
	var fgm := StandardMaterial3D.new(); fgm.albedo_color = Color("e83b3b"); fgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fgm.no_depth_test = true; fgm.render_priority = 5
	fg.material_override = fgm; bg.add_child(fg)
	var tr := MeshInstance3D.new(); var q3 := QuadMesh.new(); q3.size = Vector2(0.86, 0.06); tr.mesh = q3
	var trm := StandardMaterial3D.new(); trm.albedo_color = Color(1, 1, 1, 0.9); trm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; trm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; trm.no_depth_test = true; trm.render_priority = 4
	tr.material_override = trm; tr.position.z = -0.001; bg.add_child(tr)
	a.set_meta("trail", tr)
	mobs.append({"actor": a, "hp": 60.0, "max": 60.0, "alive": true, "next": 0.0, "home": pos, "wander": pos, "wander_t": randf_range(1, 4), "bg": bg, "fg": fg, "aggro": false, "respawn": 0.0, "tele": false, "tele_pos": Vector3.ZERO, "trail": tr, "trail_v": 1.0, "was_aggro": false})

func _mob_tick(delta: float) -> void:
	var p := player.position
	for m in mobs:
		if m.get("boss", false):
			continue
		var a: SpriteActor = m.actor
		if not m.alive:
			m.respawn -= delta
			if m.respawn <= 0.0 and m.respawn > -50.0:
				m.respawn = -99.0
				m.alive = true; m.hp = m.max; a.visible = true; a.position = m.home; a.play("idle"); m.bg.visible = false; m.aggro = false
			continue
		var d := a.position.distance_to(p)
		if dead:
			m.aggro = false
		elif d < 6.0 or m.aggro:
			m.aggro = true
		if m.aggro and not m.was_aggro:
			_pop_mark(a, "!", Color("ffd400"))
			var hop := create_tween(); hop.tween_property(a.sprite, "position:y", a.sprite.position.y + 0.35, 0.1); hop.tween_property(a.sprite, "position:y", a.sprite.position.y, 0.12)
		elif not m.aggro and m.was_aggro and not dead:
			_pop_mark(a, "?", Color("dff2ff"))
		m.was_aggro = m.aggro
		if d > 14.0 and m.aggro and not dead:
			m.aggro = false
		var goal: Vector3
		if m.aggro and not dead:
			goal = p
		else:
			m.wander_t -= delta
			if m.wander_t <= 0.0:
				m.wander_t = randf_range(2, 5); m.wander = m.home + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			goal = m.wander
		var to := goal - a.position; to.y = 0
		var stop := 1.4 if m.aggro else 0.2
		if to.length() > stop:
			var v := to.normalized() * (1.9 if m.aggro else 0.9) * delta
			a.position += v
			a.facing = to.normalized()
			a.play("walk")
		else:
			a.play("idle")
			if m.aggro and not dead:
				if m.next == 0.0:
					m.next = t + 1.2
				# telegraph 0.6 s before the lunge: step out of the red circle to avoid it
				if not m.tele and t > m.next - 0.6:
					m.tele = true
					m.tele_pos = p
					Fx.telegraph(self, p, 1.1, 0.6)
				if t > m.next:
					m.next = t + 2.0; m.tele = false
					a.play_once("walk", 0.3); a.squash(0.12)
					var tp: Vector3 = m.get("tele_pos", p)
					var still_in: bool = Vector2(p.x - tp.x, p.z - tp.z).length() < 1.25
					if not still_in or randf() < 0.12:
						_float_text(p + Vector3(0, 2.2, 0), "Miss", Color("dff2ff"))
					else:
						var dmg := 7 + randi() % 4
						_hurt_player(dmg)
		a.position.x = clampf(a.position.x, bounds.position.x, bounds.end.x)
		a.position.z = clampf(a.position.z, bounds.position.y, bounds.end.y)

func _hurt_player(dmg: int) -> void:
	if sitting:
		_stand()
	dmg = maxi(1, dmg - int(G.d.guard))   # Steadfastness blocks a little of every blow
	G.hp = maxf(0.0, G.hp - dmg)
	_float_text(player.position + Vector3(0, 2.2, 0), str(dmg), Color("ff6a6a"), false, dmg)
	if G.hp < G.hp_max * 0.5 and is_combat() and G.tip_once("low_hp"):
		hud.coach.tip("Health is low! Tap Take Refuge if you have learned it, or tap your Bread to eat it.", func(): return hud.item_btn, 6.0)
	pact.flash(Color("ff5050"), 0.8); pact.squash(0.06)
	shake(0.18)
	G.haptic(25)
	hud.hit_flash()
	if G.hp <= 0.0:
		_ko()
	G.stats_changed.emit()

func hit_mob(m: Dictionary, dmg: int, crit: bool = false, miss: bool = false) -> void:
	var a: SpriteActor = m.actor
	if miss:
		_float_text(a.position + Vector3(0, 1.6, 0), "Miss", Color("dff2ff")); return
	m.hp = maxf(0.0, m.hp - dmg)
	m.aggro = true
	var kill: bool = m.hp <= 0.0
	_float_text(a.position + Vector3(0, 1.6, 0), str(dmg), Color("ffe25a") if crit else Color.WHITE, crit or kill, dmg)
	G.zeal = minf(G.zeal_max, G.zeal + 3.0)
	a.play_once("hurt", 0.18)
	a.flash(Color.WHITE, 0.9); a.squash(0.14 if crit else 0.09); pact.squash(0.05)
	var dirv := (a.position - player.position); dirv.y = 0; dirv = dirv.normalized()
	Fx.sparks(self, a.position + Vector3(0, 0.7, 0), dirv, Color(0.85, 0.85, 0.8))   # Sloth family: grey dust
	Fx.dust(self, a.position, Color(0.7, 0.72, 0.66, 0.5), 3)
	if crit:
		Fx.star(self, a.position + Vector3(0, 0.9, 0)); shake(0.35); G.haptic(30)
		hitstop(0.1)
	elif kill:
		hitstop(0.1); shake(0.25)
	else:
		hitstop(0.05)
	var tw := create_tween(); tw.tween_property(a, "position", a.position + dirv * ((0.4 if crit else 0.25) * (0.15 if m.get("boss", false) else 1.0)), 0.08)
	m.bg.visible = not m.get("boss", false)
	m.fg.scale.x = maxf(0.001, m.hp / m.max); m.fg.position.x = -0.43 * (1.0 - m.hp / m.max)
	if m.hp <= 0.0 and m.get("boss", false):
		_boss_down(m)
		return
	if m.hp <= 0.0:
		m.alive = false; m.respawn = 14.0; m.bg.visible = false
		a.play_once("die", 0.7)
		get_tree().create_timer(0.35).timeout.connect(func(): Fx.motes_up(self, a.position + Vector3(0, 0.4, 0), Color("fff6d8"), 16, 1.2); Fx.ring(self, a.position, Color(1, 0.95, 0.75), 2.2, 0.5))
		get_tree().create_timer(0.7).timeout.connect(func(): if not m.alive: a.visible = false)
		if target == m:
			target = null
		slain += 1
		G.say("You overcame the Slothling.", G.SYS)
		G.add_xp(25, 20)
		if randf() < 0.8:
			_drop("Bread of Provision", "bread", a.position)
		if cur_obj() == "fight":
			objectives[0].text = "Overcome the Slothlings (%d/3)" % mini(slain, 3)
			if slain >= 3:
				get_tree().create_timer(1.6).timeout.connect(_evangelist_arrives)
			_update_quest()

# ------------------------------------------------------------------ drops and fx
func _drop(item: String, icon: String, pos: Vector3) -> void:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/icons/%s.png" % icon); s.pixel_size = 0.012
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED; s.shaded = false; s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(s)
	var land := pos + Vector3(randf_range(-0.8, 0.8), 0.4, randf_range(-0.8, 0.8))
	s.position = pos + Vector3(0, 0.8, 0)
	var tw := create_tween(); tw.tween_property(s, "position", land + Vector3(0, 0.6, 0), 0.18); tw.tween_property(s, "position", land, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drops.append({"node": s, "item": item, "icon": icon, "pos": land})

func _drop_tick() -> void:
	for d in drops.duplicate():
		var near := Vector2(player.position.x - d.pos.x, player.position.z - d.pos.z).length() < (2.6 if G.settings.auto_loot else 0.9)
		if near:
			d.node.queue_free(); drops.erase(d)
			G.bag_add(d.item, 1); G.say("You got %s." % d.item, G.INFO); _item_pop(d.icon)

func _item_pop(icon: String) -> void:
	hud.item_pop(icon, cam.unproject_position(player.position + Vector3(0, 1.5, 0)))

var _num_stagger := 0

func _float_text(pos: Vector3, text: String, color: Color, big: bool = false, amount: int = 0) -> void:
	if not G.settings.dmg_numbers and text != "Miss":
		return
	_num_stagger = (_num_stagger + 1) % 3
	pos += Vector3((_num_stagger - 1) * 0.25, _num_stagger * 0.12, 0)
	var l := Label3D.new(); l.text = text; l.font = G.font_ui_bold
	l.font_size = int((66 if big else 46) + clampf(amount, 0, 40) * 0.5)
	l.outline_size = 14; l.modulate = color; l.outline_modulate = Color(0.05, 0.03, 0.08); l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.render_priority = 10
	add_child(l); l.position = pos
	var side := randf_range(-0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	if G.settings.reduce_motion:
		tw.tween_property(l, "position:y", pos.y + 0.6, 0.8)
	else:
		l.scale = Vector3.ONE * 1.6
		tw.tween_property(l, "scale", Vector3.ONE, 0.15)
		tw.tween_property(l, "position:x", pos.x + side, 0.8)
		tw.tween_property(l, "position:y", pos.y + 0.9, 0.3).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(l, "position:y", pos.y + 0.2, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_method(_label_alpha.bind(l), 1.0, 0.0, 0.3).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)

## Fade a Label3D's fill and outline together (fading only the fill leaves a dark outline glyph).
func _label_alpha(a: float, l: Label3D) -> void:
	if is_instance_valid(l):
		l.modulate.a = a; l.outline_modulate.a = a

func _sparkle(pos: Vector3, color: Color = Color("fff2b0")) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.emitting = true; p.amount = 24; p.lifetime = 1.0; p.explosiveness = 0.9
	p.direction = Vector3.UP; p.spread = 70.0; p.initial_velocity_min = 1.5; p.initial_velocity_max = 3.0; p.gravity = Vector3(0, -2, 0)
	var q := QuadMesh.new(); q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m; p.mesh = q; p.position = pos; add_child(p)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _motes(pos: Vector3) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.emitting = true; p.amount = 20; p.lifetime = 1.8; p.explosiveness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP; p.spread = 15.0; p.initial_velocity_min = 0.8; p.initial_velocity_max = 1.4; p.gravity = Vector3.ZERO
	var q := QuadMesh.new(); q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m; p.mesh = q; p.position = pos + Vector3(0, 0.5, 0); add_child(p)
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)

func _on_level_up(kind: String) -> void:
	var ring := Sprite3D.new(); ring.texture = G.tex("res://assets/fx/ring.png"); ring.rotation_degrees.x = -90; ring.pixel_size = 0.01; ring.shaded = false
	add_child(ring); ring.position = player.position + Vector3(0, 0.08, 0)
	var tw2 := create_tween(); tw2.tween_property(ring, "scale", Vector3(3, 3, 3), 1.0); tw2.parallel().tween_property(ring, "modulate:a", 0.0, 1.0); tw2.tween_callback(ring.queue_free)
	var col := Sprite3D.new(); col.texture = G.tex("res://assets/fx/glow.png"); col.pixel_size = 0.05; col.scale = Vector3(1, 4, 1)
	col.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; col.shaded = false; col.modulate = Color(1, 0.95, 0.7, 0.8)
	add_child(col); col.position = player.position + Vector3(0, 1.5, 0)
	var tw3 := create_tween(); tw3.tween_property(col, "modulate:a", 0.0, 1.2); tw3.tween_callback(col.queue_free)
	_sparkle(player.position + Vector3(0, 1, 0), Color("ffe9a0"))
	Fx.spiral(self, player.position + Vector3(0, 0.2, 0), Color("ffe9a0") if kind.begins_with("Base") else Color("b8e0ff"))
	hud.level_banner(kind)
	_level_lesson(kind)

# ------------------------------------------------------------------ objectives
func cur_obj() -> String:
	return objectives[obj_idx].id if obj_idx < objectives.size() else ""

func complete() -> void:
	obj_idx += 1
	if cur_obj() == "trees":
		show_ent("trees", true)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sun, "light_color", Color("ffcf9a"), 4.0)
		tw.tween_property(sun, "light_energy", 0.62, 4.0)
		tw.tween_property(env, "ambient_light_energy", 0.34, 4.0)
		post.set_shader_parameter("tint", Vector3(1.06, 0.98, 0.88))
	_update_quest()
	if obj_idx < objectives.size():
		G.say("Quest: " + objectives[obj_idx].text, G.INFO)
		hud.quest_toast(objectives[obj_idx].text)
	G.haptic(18)
	_on_new_obj()

func _update_quest() -> void:
	if quest_mark:
		quest_mark.queue_free(); quest_mark = null
	if zone_fx:
		zone_fx.queue_free(); zone_fx = null
	if obj_idx >= objectives.size():
		hud.set_quest(""); return
	var o: Dictionary = objectives[obj_idx]
	hud.set_quest(o.text)
	if o.has("ent"):
		var e := ent(o.ent)
		if not e.is_empty() and not e.hidden:
			quest_mark = _label3d("!", e.pos + Vector3(0, 3.3 if o.ent in ["fig", "trees"] else 2.6, 0), Color("ffd400"), 90)
			quest_mark.outline_modulate = Color("3a2a00")
	if o.has("zone"):
		zone_fx = Node3D.new(); add_child(zone_fx); zone_fx.position = o.zone
		var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/glow.png"); g.pixel_size = 0.07; g.rotation_degrees.x = -90; g.position.y = 0.05; g.shaded = false
		zone_fx.add_child(g)
		var p := CPUParticles3D.new(); p.amount = 16; p.lifetime = 2.0; p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 1.0
		p.direction = Vector3.UP; p.spread = 10; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.0; p.gravity = Vector3.ZERO
		var q := QuadMesh.new(); q.size = Vector2(0.15, 0.15)
		var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.albedo_color = Color("fff3c0"); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = m; p.mesh = q; zone_fx.add_child(p)

func quest_target() -> Variant:
	if obj_idx >= objectives.size():
		return null
	var o: Dictionary = objectives[obj_idx]
	if o.has("ent") and not ent(o.ent).is_empty() and not ent(o.ent).hidden:
		return ent(o.ent)
	if o.has("zone"):
		return o.zone
	return null

func auto_path_quest() -> void:
	var q = quest_target()
	if q is Dictionary:
		pending = q; move_target = _approach_point(q.pos)
		G.say("Auto-path: %s" % q.name, G.SYS)
	elif q is Vector3:
		move_target = q; pending = null
	elif cur_obj() in ["fight", "boss"]:
		_attack_pressed()

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
	if dead:
		return
	# 1) entities and mobs under the finger
	var best = null; var best_d := PICK_PX
	for m in mobs:
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
	for dr in drops:
		var sp3 := cam.unproject_position(dr.pos)
		if sp3.distance_to(screen_pos) < best_d:
			best_d = sp3.distance_to(screen_pos); best = {"drop": dr}
	if sitting:
		_stand()
	if best != null:
		if best.has("mob"):
			target = best.mob; pending = null; move_target = null
			return
		if best.has("ent"):
			pending = best.ent; target = null; move_target = _approach_point(best.ent.pos)
			return
		if best.has("drop"):
			move_target = best.drop.pos; pending = null; target = null
			return
	# 2) ground
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return
	var k := -from.y / dir.y
	var hit := from + dir * k
	hit.x = clampf(hit.x, bounds.position.x, bounds.end.x); hit.z = clampf(hit.z, bounds.position.y, bounds.end.y)
	move_target = hit; pending = null; target = null
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

func _attack_pressed() -> void:
	if dead:
		return
	if target == null or not target.alive:
		target = _nearest_mob(28.0)
	if target == null:
		G.say("There is nothing to attack nearby.", G.WARN)

func attack_pressed() -> void:
	_attack_pressed()

func _nearest_mob(r: float) -> Variant:
	var best = null; var bd := r
	for m in mobs:
		if m.alive:
			var d: float = m.actor.position.distance_to(player.position)
			if d < bd:
				bd = d; best = m
	return best

func skill(id: String) -> void:
	if dead or cinema:
		return
	if not G.has_skill(id):
		G.say("You have not learned %s yet (More → Skills)." % G.SKILL_INFO[id].name, G.WARN); return
	if gcd > 0.0 and gcd < 0.3 and cd.get(id, 0.0) <= 0.0:
		queued_skill = id  # buffer the press; fires when the global cooldown ends
		return
	var info: Dictionary = G.SKILL_INFO[id]
	if cd.get(id, 0.0) > 0.0:
		G.say("%s is recharging." % info.name, G.WARN); return
	if G.zeal < int(info.zeal):
		G.say("Not enough Zeal (the blue bar). It refills over time, faster while sitting.", G.WARN); return
	match id:
		"tend":
			var best = null; var bd := 3.2
			for l in lilies:
				var dl := Vector2(player.position.x - l.pos.x, player.position.z - l.pos.z).length()
				if not l.bloomed and dl < bd:
					bd = dl; best = l
			if best == null:
				G.say("Stand next to a drooping lily, then use Tend and Keep.", G.WARN); return
			G.zeal -= int(info.zeal); cd.tend = float(info.cd); gcd = 1.0
			pact.play_once("cast", 0.5); pact.facing = (best.pos - player.position).normalized()
			best.bloomed = true; best.actor.play("bloom")
			best.actor.squash(0.2)
			_sparkle(best.pos + Vector3(0, 0.6, 0), Color("dff7ff"))
			Fx.ring(self, best.pos, Color(0.85, 1, 0.85), 1.6, 0.5)
			lilies_done += 1
			G.add_xp(15, 10, "eden")
			G.say("The lily lifts its head and blooms.", G.SYS)
			if cur_obj() == "lilies":
				objectives[obj_idx].text = "Tend the drooping lilies with your skill (%d/3)" % lilies_done
				_update_quest()
				if lilies_done >= 3:
					complete()
		"steps":
			var m = target if (target != null and target.alive) else _nearest_mob(10.0)
			if m == null:
				G.say("No target.", G.WARN); return
			target = m
			if m.actor.position.distance_to(player.position) > 2.2:
				G.say("Too far. Moving closer…", G.WARN); return
			G.zeal -= int(info.zeal); cd.steps = float(info.cd); gcd = 1.0
			used_steps = true
			var to_m: Vector3 = (m.actor.position - player.position); to_m.y = 0
			pact.facing = to_m.normalized()
			pact.play_once("attack", 0.35)
			var from := player.position
			var dest := player.position + to_m.normalized() * maxf(0.0, to_m.length() - 1.1)
			Fx.afterimages(self, pact, from, dest, 3)
			Fx.dust(self, from, Color(0.8, 0.76, 0.66, 0.6), 6)
			var lunge := create_tween(); lunge.tween_property(player, "position", dest, 0.09).set_ease(Tween.EASE_OUT)
			Fx.burst(self, m.actor.position + Vector3(0, 0.8, 0), Color("fff2b0"), 22)
			Fx.ring(self, m.actor.position, Color(1, 0.95, 0.7), 1.8, 0.4)
			hit_mob(m, int(G.skill_num("steps").dmg) + randi_range(-2, 2), true)
			G.say("First Steps!", G.SYS)
		"refuge":
			G.zeal -= int(info.zeal); cd.refuge = float(info.cd); gcd = 1.0
			var h := minf(G.hp_max - G.hp, float(G.skill_num("refuge").heal))
			G.hp += h
			pact.play_once("cast", 0.5)
			pact.flash(Color("fff0b0"), 0.6)
			_float_text(player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
			Fx.dome(self, player.position)
			G.say("Take Refuge. [BSB: Psalm 9:9 · pulled at build time]", G.SYS)
	G.stats_changed.emit()

func use_item(item: String) -> void:
	if not G.bag_take(item):
		G.say("You have no %s." % item, G.WARN); return
	var h := minf(G.hp_max - G.hp, 40.0 if item == "Bread of Provision" else 20.0)
	G.hp += h
	_float_text(player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
	G.say("Used %s." % item, G.SYS)
	G.stats_changed.emit()

func toggle_sit() -> void:
	if sitting:
		_stand()
	else:
		sitting = true; move_target = null; pending = null; target = null
		pact.play("sit"); G.say("You sit and rest. (Faster recovery)", G.SYS)

func _stand() -> void:
	sitting = false; pact.play("idle")

func set_auto(on: bool) -> void:
	auto_on = on
	G.say("Auto battle %s." % ("on" if on else "off"), G.SYS)

# ------------------------------------------------------------------ KO
func _ko() -> void:
	if dead:
		return
	dead = true; target = null; auto_on = false; move_target = null
	pact.play("rest")
	G.kos += 1
	var spoil: float = snappedf(G.manna * 0.05, 0.1)
	G.manna = maxf(0.0, G.manna - spoil)
	hud.show_ko(spoil)

func rise() -> void:
	dead = false
	G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = true
	player.position = info("start")
	pact.play("idle")
	for m in mobs:
		m.aggro = false
		if m.actor.position.distance_to(player.position) < 8.0:
			m.actor.position = m.home
	G.say("You rest, and rise again.", G.SYS)
	G.stats_changed.emit()
	get_tree().create_timer(25.0).timeout.connect(_weary_end)

# ------------------------------------------------------------------ Evangelist and ending
func after_evangelist() -> void:
	G.bag_add("Parchment Roll", 1)
	G.say("You got Parchment Roll.", G.INFO)
	show_ent("warp", true)
	snapshot_unlocked = true
	complete()
	hud.refresh()
	G.say("New: Snapshot mode (camera button by the minimap).", G.INFO)

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
	gcd = maxf(0.0, gcd - delta)
	for k in cd.keys():
		cd[k] = maxf(0.0, cd[k] - delta)
	if dead or cinema or (hud and (hud.overlay_open() or hud.coach.blocking())):
		player.velocity = Vector3.ZERO
		if not dead and pact.anim == "walk":
			pact.play("idle")
		_place_camera()
		return
	var v := Vector3.ZERO
	var jv: Vector2 = hud.joy_vec() if hud else Vector2.ZERO
	var basis_y := Basis(Vector3.UP, cam_yaw)
	if jv.length() > 0.0:
		v = basis_y * Vector3(jv.x, 0, jv.y)
		move_target = null; pending = null
		if target != null and auto_on == false:
			target = null
	elif target != null and target.alive:
		var to: Vector3 = target.actor.position - player.position; to.y = 0
		if to.length() > 1.8:
			v = to.normalized()
		else:
			pact.facing = to.normalized()
			if t > next_atk and gcd <= 0.0:
				# basic attack from attributes: Fortitude (damage), Diligence (speed), Sobriety (misses), Hope (crits)
				next_atk = t + float(G.d.interval)
				pact.play_once("attack", 0.32)
				var crit := randf() < float(G.d.crit)
				var dmg := int(G.d.atk) + randi_range(-2, 2)
				hit_mob(target, dmg * (2 if crit else 1), crit, randf() < float(G.d.miss))
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
	if obj_idx < objectives.size() and objectives[obj_idx].has("zone"):
		var z: Vector3 = objectives[obj_idx].zone
		if Vector2(player.position.x - z.x, player.position.z - z.z).length() < 1.6:
			if cur_obj() in ["light", "return"]:
				_finish()
			else:
				complete()
	# auto battle (within the Tier 1 auto scope: auto-attack and the auto-skill slots)
	if auto_on and is_combat():
		if target == null or not target.alive:
			target = _nearest_mob(14.0)
		if G.has_skill("steps") and target != null and cd.steps <= 0.0 and G.zeal >= 10 and target.actor.position.distance_to(player.position) < 2.2 and gcd <= 0.0:
			skill("steps")
		if G.has_skill("refuge") and G.hp < G.hp_max * 0.45 and cd.refuge <= 0.0 and G.zeal >= 15:
			skill("refuge")
	if is_combat():
		_mob_tick(delta)
	if boss != null:
		_boss_tick(delta)
	_allies_tick(delta)
	_others_tick(delta)
	_glint_tick()
	_dreamer_tick(delta)
	if map_id == "eden":
		_eden_obj_tick()
	_city_tips_tick()
	_drop_tick()
	# regeneration (faster while sitting)
	regen_t += delta
	if regen_t >= 1.0:
		regen_t = 0.0
		var mult := 3.0 if sitting else 1.0
		G.zeal = minf(G.zeal_max, G.zeal + float(G.d.regen) * mult)
		if not (is_combat() and _any_aggro()):
			G.hp = minf(G.hp_max, G.hp + 1.0 * mult)
		G.stats_changed.emit()
	if queued_skill != "" and gcd <= 0.0:
		var qs := queued_skill; queued_skill = ""
		skill(qs)
	_ambient_tick(delta)
	# camera
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, 0.12)
	trauma = maxf(0.0, trauma - delta * 1.6)
	_place_camera()
	# warp spin
	var w := ent("warp")
	if not w.is_empty() and w.node.has_meta("spin"):
		w.node.get_meta("spin").rotation.y += delta * 1.5

func _any_aggro() -> bool:
	for m in mobs:
		if m.alive and m.aggro:
			return true
	return false

func in_combat() -> bool:
	return target != null or _any_aggro()

func cooldown_frac(id: String) -> float:
	return cd.get(id, 0.0) / float(G.SKILL_INFO[id].cd)

# ------------------------------------------------------------------ interaction handlers
func _act_vine() -> void:
	if cur_obj() != "tend":
		G.say("The vine is flourishing.", G.SYS); return
	var nm := _mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(1.0, 1.2, 0.9))
	for lf in _vine_leaves:
		lf.material_override = nm
	_sparkle(ent("vine").pos + Vector3(0, 1.4, 0))
	G.say("You tended the vine. It flourishes.", G.SYS)
	complete()
	G.add_xp(40, 30, "eden")

func _act_fig() -> void:
	if cur_obj() != "gather":
		G.say("The branches are heavy with fruit.", G.SYS); return
	G.bag_add("Garden Fig", 3); G.say("You got Garden Fig ×3. They are in your Satchel.", G.INFO); _item_pop("fig")
	complete()
	G.add_xp(30, 20, "eden")

func _act_lamb() -> void:
	if cur_obj() != "name":
		G.say("%s grazes peacefully." % ent("lamb").name, G.SYS); return
	hud.name_animal(_lamb_named)

func _lamb_named(n: String) -> void:
	ent("lamb").name = n
	_lamb_actor.set_name_text(n)
	G.say("You named the lamb %s." % n, G.SYS)
	G.add_xp(40, -1, "eden"); complete()

func _act_stone() -> void:
	if cur_obj() != "read":
		G.say("Words are carved upon the stone.", G.SYS); return
	hud.word_study(_stone_read)

func _stone_read() -> void:
	hud.motes_to_plate(cam.unproject_position(ent("stone").pos + Vector3(0, 1.2, 0)))
	G.manna += 5
	G.say("Word Study complete. Manna +5.", G.INFO)
	_motes(player.position)
	G.add_xp(60, -1, "eden"); complete()
	if G.tip_once("manna"):
		get_tree().create_timer(1.4).timeout.connect(_lesson_manna)

func _act_trees() -> void:
	if ending:
		return
	ending = true
	_fall_scene()

func _act_evangelist() -> void:
	hud.evangelist_dialog()

func _evangelist_arrives() -> void:
	show_ent("evangelist", true)
	G.say("Evangelist approaches you.", G.NPC)
	complete()

func _weary_end() -> void:
	G.weary = false
	G.say("Your weariness has passed.", G.SYS)
	G.stats_changed.emit()

# ------------------------------------------------------------------ ambience and feedback ticks
func _ambient_tick(delta: float) -> void:
	for sw in sways:
		if is_instance_valid(sw[0]):
			sw[0].rotation.z = sin(t * 1.1 + sw[1]) * 0.025
			sw[0].rotation.x = cos(t * 0.8 + sw[1]) * 0.015
	for l in lamps:
		l.light_energy = 1.5 + sin(t * 9.0 + l.position.x) * 0.12 + randf() * 0.1
	for h in holy_lights:
		if h is OmniLight3D:
			h.light_energy = 2.0 + sin(t * 1.6) * 0.5
		elif h is Sprite3D:
			h.modulate.a = 0.45 + sin(t * 1.6) * 0.15
	var w := ent("warp")
	if not w.is_empty() and w.node.has_meta("spin2"):
		w.node.get_meta("spin2").rotation.y -= delta * 2.4
	# target ring + outline on the current target
	var tgt = target if (target != null and target.alive) else null
	if tgt != last_target:
		if last_target != null and is_instance_valid(last_target.actor):
			last_target.actor.set_outline(false)
		if tgt != null:
			tgt.actor.set_outline(true)
		last_target = tgt
	if tgt != null:
		if target_ring == null:
			target_ring = Sprite3D.new(); target_ring.texture = G.tex("res://assets/fx/ring.png"); target_ring.pixel_size = 0.011
			target_ring.rotation_degrees.x = -90; target_ring.shaded = false; target_ring.modulate = Color(1, 0.85, 0.3, 0.9); add_child(target_ring)
		target_ring.visible = true
		target_ring.position = tgt.actor.position + Vector3(0, 0.05, 0)
		target_ring.rotation.y += delta * 2.0
	elif target_ring:
		target_ring.visible = false
	# mob HP trail
	for m in mobs:
		if m.bg.visible:
			var v: float = m.hp / m.max
			m.trail_v = lerpf(m.trail_v, v, delta * 3.0) if m.trail_v > v else v
			m.trail.scale.x = maxf(0.001, m.trail_v); m.trail.position.x = -0.43 * (1.0 - m.trail_v)
	# status visuals on the body
	if burden_fx != null and not G.burden:
		burden_fx.queue_free(); burden_fx = null
	if G.burden and burden_fx == null:
		burden_fx = Fx.particles(player, player.global_position + Vector3(0.25, 1.1, 0), {"amount": 6, "life": 1.4, "one_shot": false, "explode": 0.0, "sphere": 0.25,
			"vmin": 0.05, "vmax": 0.2, "gravity": Vector3(0, -0.4, 0), "color": Color(0.2, 0.16, 0.12, 0.45), "size": 0.3, "tex": "res://assets/fx/puff.png", "add": false, "local": false})
	if burden_fx:
		burden_fx.global_position = player.global_position + Vector3(0.25, 1.1, 0)
	if G.weary and weary_fx == null:
		weary_fx = Fx.particles(player, player.global_position + Vector3(0, 2.0, 0), {"amount": 3, "life": 0.9, "one_shot": false, "explode": 0.0,
			"dir": Vector3(0.3, 1, 0), "spread": 30.0, "vmin": 0.6, "vmax": 0.9, "gravity": Vector3(0, -3, 0), "color": Color(0.7, 0.85, 1.0, 0.9), "size": 0.18, "tex": "res://assets/fx/drop.png", "add": false, "local": false})
	elif not G.weary and weary_fx != null:
		weary_fx.queue_free(); weary_fx = null
	if weary_fx:
		weary_fx.global_position = player.global_position + Vector3(0, 2.0, 0)
	# low-health warning
	var frac := G.hp / G.hp_max
	var target_d := 0.0
	if frac < 0.25 and not dead:
		low_hp_pulse += delta * (6.0 if frac < 0.1 else 3.5)
		target_d = 0.45 + 0.35 * sin(low_hp_pulse)
	post.set_shader_parameter("danger", target_d)

func _pop_mark(a: SpriteActor, mark: String, col: Color) -> void:
	var l := _label3d(mark, a.position + Vector3(0, 1.9, 0), col, 80)
	l.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.tween_interval(0.6)
	tw.tween_method(_label_alpha.bind(l), 1.0, 0.0, 0.25)
	tw.tween_callback(l.queue_free)

func _edge_fade(col: Color) -> void:
	## Soft darkening band at every map border so no hard edge or void is visible.
	var gt := GradientTexture2D.new()
	var gr := Gradient.new(); gr.set_color(0, Color(col.r, col.g, col.b, 0.0)); gr.set_color(1, Color(col.r, col.g, col.b, 0.92))
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1); gt.width = 4; gt.height = 64
	var m := StandardMaterial3D.new(); m.albedo_texture = gt; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var b := bounds; var w := 7.0
	var specs := [
		[Vector2(b.size.x + 2 * w, w), Vector3(b.get_center().x, 0.08, b.position.y - w * 0.5 + 1.5), PI],
		[Vector2(b.size.x + 2 * w, w), Vector3(b.get_center().x, 0.08, b.end.y + w * 0.5 - 1.5), 0.0],
		[Vector2(b.size.y + 2 * w, w), Vector3(b.position.x - w * 0.5 + 1.5, 0.08, b.get_center().y), -PI * 0.5],
		[Vector2(b.size.y + 2 * w, w), Vector3(b.end.x + w * 0.5 - 1.5, 0.08, b.get_center().y), PI * 0.5]]
	for sp in specs:
		var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = sp[0]; mi.mesh = pm; mi.material_override = m
		mi.position = sp[1]; mi.rotation.y = sp[2]; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _weather_petals() -> void:
	var p := Fx.particles(cam_rig, cam_rig.global_position + Vector3(0, 7, 0), {"amount": 26, "life": 6.0, "one_shot": false, "explode": 0.0, "sphere": 9.0,
		"dir": Vector3(0.4, -1, 0.2), "spread": 25.0, "vmin": 0.6, "vmax": 1.1, "gravity": Vector3(0.3, -0.25, 0.1), "color": Color(1, 1, 1, 0.95),
		"size": 0.16, "tex": "res://assets/fx/petal.png", "add": false, "local": false})
	p.set_meta("follow", true)
	_followers.append([p, Vector3(0, 7, 0)])

func _weather_drizzle() -> void:
	if not G.settings.fx_high:
		return
	var p := Fx.particles(cam_rig, cam_rig.global_position + Vector3(0, 9, 0), {"amount": 60, "life": 1.0, "one_shot": false, "explode": 0.0, "sphere": 10.0,
		"dir": Vector3(0.15, -1, 0), "spread": 4.0, "vmin": 11.0, "vmax": 13.0, "gravity": Vector3.ZERO, "color": Color(0.8, 0.85, 0.95, 0.45),
		"size": 0.5, "stretch": 0.15, "tex": "res://assets/fx/rain.png", "add": false, "local": false})
	_followers.append([p, Vector3(0, 9, 0)])

var _followers: Array = []

func _process(_d: float) -> void:
	for f in _followers:
		if is_instance_valid(f[0]):
			f[0].global_position = player.global_position + f[1]

# ======================================================================
# World model (GDD v0.3): Way traces, the House, the Muster
# ======================================================================

# ------------------------------------------------------------------ secrets on the Way
func _add_secret(id: String, pos: Vector3, title: String, text: String, reward: Dictionary) -> void:
	secret_ids.append(id)
	if G.secret_found(map_id, id):
		return
	var n := Node3D.new(); n.position = pos; add_child(n)
	var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/star.png"); g.pixel_size = 0.004; g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.shaded = false; g.transparent = true; g.modulate = Color(1, 0.97, 0.8, 0.0); g.position.y = 0.55; n.add_child(g)
	n.set_meta("glint", g)
	var e := _add_ent("secret_" + id, "Something glints", pos, n, "Search", "eye", _find_secret.bind(id, title, text, reward))
	e["kind"] = "secret"

func _find_secret(id: String, title: String, text: String, reward: Dictionary) -> void:
	var e := ent("secret_" + id)
	if e.is_empty() or e.hidden:
		return
	show_ent("secret_" + id, false)
	var found: Array = G.secrets.get(map_id, [])
	found.append(id); G.secrets[map_id] = found
	_sparkle(e.pos + Vector3(0, 0.6, 0), Color("fff2b0"))
	Fx.ring(self, e.pos, Color(1, 0.95, 0.7), 2.0, 0.5)
	if reward.has("item"):
		G.bag_add(reward.item, 1); _item_pop("scroll")
	if reward.has("xp"):
		G.add_xp(int(reward.xp), -1, map_id)
	G.say("Secret found (%d/%d): %s" % [found.size(), secret_ids.size(), title], G.INFO)
	hud.secret_card(title, text, found.size(), secret_ids.size())
	G.haptic(30)

func secrets_text() -> String:
	if secret_ids.is_empty():
		return ""
	return "✦ %d/%d" % [G.secrets.get(map_id, []).size(), secret_ids.size()]

# ------------------------------------------------------------------ Waymarks (after the pillar at the By-path stile)
var waymark_phrases := ["Beware: danger ahead", "Rest here", "Look closely here", "Keep to the narrow way", "Well done, pilgrim!",
	"Remember [BSB: Psalm 46:1]", "Read slowly [BSB: Psalm 119:105]"]

func _add_waymark(pos: Vector3, phrase: String, author: String, thanks: int) -> Dictionary:
	var n := Node3D.new(); n.position = pos; add_child(n)
	var wood := _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.85, 0.75, 0.6))
	var post_m := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.12, 1.2, 0.12); post_m.mesh = pb; post_m.material_override = wood; post_m.position.y = 0.6; n.add_child(post_m)
	var plank := MeshInstance3D.new(); var pk := BoxMesh.new(); pk.size = Vector3(0.7, 0.32, 0.06); plank.mesh = pk; plank.material_override = wood; plank.position.y = 1.08; n.add_child(plank)
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color("9ad0ff"); stone.emission_enabled = true; stone.emission = Color("6ab8ff"); stone.emission_energy_multiplier = 1.2
	var gem := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.14; gem.mesh = sm; gem.material_override = stone; gem.position = Vector3(0, 1.32, 0); n.add_child(gem)
	var wm := {"phrase": phrase, "author": author, "thanks": thanks, "thanked": false, "mine": author == G.pname}
	var e := _add_ent("waymark_%d" % ents.size(), "Waymark", pos, n, "Read", "scroll", func(): hud.waymark_read(wm))
	e["kind"] = "waymark"
	return wm

func place_waymark(phrase: String) -> void:
	var p := player.position + pact.facing.normalized() * 1.3
	p.y = 0.0
	_add_waymark(p, phrase, G.pname, 0)
	G.my_waymarks.append({"map": map_id, "pos": p, "phrase": phrase})
	_sparkle(p + Vector3(0, 1.2, 0), Color("bfe4ff"))
	G.say("You raised a Waymark: \"%s\". Pilgrims who pass this way will see it." % phrase, G.INFO)

# ------------------------------------------------------------------ other pilgrims (passing ghosts on the Way, real players in Houses)
func _pilgrim_actor(look: Array, nm: String, col: Color, ghost: bool) -> SpriteActor:
	var a := SpriteActor.new(); add_child(a)
	a.setup({"tex": G.build_sheet(int(look[0]), int(look[1]), int(look[2])), "hframes": 10, "vframes": 5, "pixel": 0.042, "rows": true, "ghost": ghost,
		"anims": {"idle": [0], "walk": [1, 2, 3, 4], "attack": [5, 6], "sit": [7], "rest": [8], "cast": [9]}, "fps": {"walk": 9.0, "attack": 6.0}}, nm, col)
	return a

func _add_passerby(path: Array, nm: String, dest: String, look: Array, ghost: bool, delay: float = 0.0) -> void:
	var a := _pilgrim_actor(look, "%s · %s" % [nm, dest], Color(0.85, 0.92, 1.0, 0.75), ghost)
	a.position = path[0]
	if a.name_lbl:
		a.name_lbl.font_size = 26
	a.visible = delay <= 0.0
	others.append({"actor": a, "path": path, "i": 1, "speed": 2.3, "ghost": ghost, "wait": delay, "kind": "passer"})

func _others_tick(delta: float) -> void:
	for o in others:
		var a: SpriteActor = o.actor
		if o.wait > 0.0:
			o.wait -= delta
			if o.wait <= 0.0:
				a.visible = true; a.position = o.path[0]; o.i = 1
				if o.kind == "passer":
					_fade_actor(a, 0.0, 1.0)
			else:
				if o.kind == "house" and a.anim == "walk":
					a.play("sit" if o.get("sitter", false) else "idle")
				_house_chat_tick(o, delta)
				continue
		var goal: Vector3 = o.path[o.i]
		var to := goal - a.position; to.y = 0
		if to.length() > 0.2:
			a.position += to.normalized() * o.speed * delta
			a.facing = to.normalized(); a.play("walk")
		else:
			if o.kind == "passer":
				o.i += 1
				if o.i >= o.path.size():
					_fade_actor(a, 1.0, 0.0)
					o.wait = randf_range(8.0, 14.0)
			else:
				o.path = [a.position, _house_spot()]
				o.i = 1
				o.wait = randf_range(3.0, 9.0)
		_house_chat_tick(o, delta)

func _fade_actor(a: SpriteActor, from: float, to: float) -> void:
	var tw := create_tween()
	tw.tween_method(_actor_alpha.bind(a), from, to, 0.8)
	if to <= 0.0:
		tw.tween_callback(_hide_node.bind(a))

func _actor_alpha(v: float, a: SpriteActor) -> void:
	if not is_instance_valid(a):
		return
	var c: Color = G.sprite_tint; c.a = v; a.set_tint(c)
	if a.name_lbl:
		a.name_lbl.modulate.a = v * 0.75; a.name_lbl.outline_modulate.a = v * 0.75

func _hide_node(n: Node3D) -> void:
	if is_instance_valid(n):
		n.visible = false

# ------------------------------------------------------------------ the House: Palace Beautiful
const HOUSE_FOLK := [
	["Lumen", [2, 2, 1]], ["Rook", [0, 1, 5]], ["Tabitha", [1, 3, 2]], ["Ebenezer", [0, 4, 3]], ["Wren", [1, 0, 0]],
	["Psalter", [2, 5, 4]], ["Marigold", [1, 2, 2]], ["Honestly", [0, 0, 1]], ["Faithwalker", [2, 1, 0]]]
const HOUSE_CHAT := ["Grace and peace!", "LF 2 for the Lions' Gate (Normal)", "Anyone reading Psalm 23 in the reading room?",
	"Thanks for the Help in the Slough earlier!", "First time at the House. Where is the armory?", "Armory is the west door.",
	"Muster was quick: a Steward filled our last place.", "Waymark at the Hill: rest at the Arbour, but don't sleep there!",
	"Heading out to the Valley meadows later, anyone?", "Welcome, new pilgrim!"]

func _house_spot() -> Vector3:
	return Vector3(randf_range(-11, 11), 0, randf_range(-6, 6))

func _house_chat_tick(o: Dictionary, delta: float) -> void:
	if o.kind != "house":
		return
	o.chat_t -= delta
	if o.chat_t <= 0.0:
		o.chat_t = randf_range(9.0, 20.0)
		var line: String = HOUSE_CHAT[randi() % HOUSE_CHAT.size()]
		G.say("[Local] %s: %s" % [o.name, line], G.CHAT)
		_bubble(o.actor, line)

func _bubble(a: SpriteActor, text: String) -> void:
	var l := _label3d(text, a.position + Vector3(0, 2.45, 0), Color("1d2b52"), 24)
	l.outline_modulate = Color(1, 1, 1, 0.95); l.outline_size = 16; l.width = 360; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.reparent(a); l.position = Vector3(0, 2.45, 0)
	var tw := create_tween(); tw.tween_interval(3.2); tw.tween_method(_label_alpha.bind(l), 1.0, 0.0, 0.4); tw.tween_callback(l.queue_free)

func _build_palace() -> void:
	bounds = Rect2(-20, -12, 40, 26)
	_plane(Vector2(120, 100), _mat("res://assets/tiles/grass.png", Vector2(60, 50), false, Color(0.9, 0.95, 0.8)), Vector3.ZERO)
	_plane(Vector2(26, 15), _mat("res://assets/tiles/cobble.png", Vector2(13, 7.5), false, Color(1.0, 0.96, 0.88)), Vector3(0, 0.01, -1.5))
	_plane(Vector2(3.4, 14), _mat("res://assets/tiles/dirt.png", Vector2(1.7, 7), false, Color(0.92, 0.86, 0.74)), Vector3(0, 0.012, 9))
	var stonem := _mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(1.0, 0.97, 0.9))
	var roofm := _mat("res://assets/tiles/roof.png", Vector2(0.6, 0.6), true, Color(0.62, 0.72, 1.0))
	# the palace itself, "a very stately palace … by the highway side"
	_box(Vector3(26, 6.5, 5), stonem, Vector3(0, 3.25, -12.5))
	var pr := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(27, 3.0, 5.8); pr.mesh = pm; pr.material_override = roofm; pr.position = Vector3(0, 8.0, -12.5); add_child(pr)
	for tx in [-14.0, 14.0]:
		_box(Vector3(4.2, 10, 4.2), stonem, Vector3(tx, 5, -12.0))
		var cone := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 3.0; cm.height = 4.0; cone.mesh = cm; cone.material_override = roofm
		cone.position = Vector3(tx, 12.0, -12.0); add_child(cone)
	var win := StandardMaterial3D.new(); win.albedo_color = Color("ffd98a"); win.emission_enabled = true; win.emission = Color("ffc860"); win.emission_energy_multiplier = 1.1
	for wx in [-9.0, -6.0, 6.0, 9.0]:
		for wy in [2.4, 4.8]:
			_box(Vector3(1.0, 1.3, 0.06), win, Vector3(wx, wy, -9.97), false)
	_box(Vector3(3.0, 3.6, 0.1), _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.6, 0.45, 0.32)), Vector3(0, 1.8, -9.95), false)
	var door_l := OmniLight3D.new(); door_l.light_color = Color("ffe9b0"); door_l.light_energy = 2.2; door_l.omni_range = 7.0; door_l.position = Vector3(0, 3.2, -8.6); add_child(door_l)
	holy_lights.append(door_l)
	var dh := Sprite3D.new(); dh.texture = G.tex("res://assets/fx/glow.png"); dh.pixel_size = 0.07; dh.billboard = BaseMaterial3D.BILLBOARD_ENABLED; dh.shaded = false
	dh.modulate = Color(1, 0.95, 0.75, 0.5); dh.position = Vector3(0, 2.4, -9.6); add_child(dh); holy_lights.append(dh)
	# the hearth (rest is required once before Act III)
	var hearth := Node3D.new(); hearth.position = Vector3(-8, 0, -3); add_child(hearth)
	var rockm := _mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.7, 0.68, 0.66))
	for k in 8:
		var ang := k * TAU / 8.0
		var r := MeshInstance3D.new(); var rs := SphereMesh.new(); rs.radius = 0.24; rs.height = 0.36; r.mesh = rs; r.material_override = rockm
		r.position = Vector3(cos(ang) * 0.8, 0.14, sin(ang) * 0.8); hearth.add_child(r)
	_solid_cyl(0.9, hearth.position)
	Fx.particles(hearth, hearth.global_position + Vector3(0, 0.2, 0), {"amount": 22, "life": 0.9, "one_shot": false, "explode": 0.0, "sphere": 0.35, "dir": Vector3.UP, "spread": 12.0,
		"vmin": 1.0, "vmax": 1.8, "gravity": Vector3(0, 0.6, 0), "color": Color("ffb048"), "size": 0.32, "local": true})
	var fire := OmniLight3D.new(); fire.light_color = Color("ff9a40"); fire.light_energy = 1.8; fire.omni_range = 6.0; fire.position = Vector3(0, 1.0, 0); hearth.add_child(fire)
	lamps.append(fire)
	var benchm := _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.75, 0.6, 0.45))
	_box(Vector3(0.6, 0.42, 1.8), benchm, Vector3(-10.4, 0.21, -3))
	_box(Vector3(0.6, 0.42, 1.8), benchm, Vector3(-5.6, 0.21, -3))
	_box(Vector3(2.4, 0.42, 0.6), benchm, Vector3(-8, 0.21, -5.4))
	_add_ent("hearth", "The Hearth", hearth.position, hearth, "Rest", "sit", _act_hearth)
	# the Muster Board
	var board := Node3D.new(); board.position = Vector3(8, 0, -3); add_child(board)
	for x in [-1.1, 1.1]:
		var bpst := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.16, 2.4, 0.16); bpst.mesh = bb; bpst.material_override = benchm; bpst.position = Vector3(x, 1.2, 0); board.add_child(bpst)
	var panel := MeshInstance3D.new(); var pbm := BoxMesh.new(); pbm.size = Vector3(2.4, 1.4, 0.1); panel.mesh = pbm; panel.material_override = benchm; panel.position = Vector3(0, 1.6, 0); board.add_child(panel)
	var parch := StandardMaterial3D.new(); parch.albedo_color = Color("f4e8c8")
	for k in 3:
		var sh := MeshInstance3D.new(); var qb := BoxMesh.new(); qb.size = Vector3(0.6, 0.8, 0.02); sh.mesh = qb; sh.material_override = parch
		sh.position = Vector3(-0.72 + k * 0.72, 1.6, 0.07); sh.rotation.z = (k - 1) * 0.06; board.add_child(sh)
	_solid_box(Vector3(2.6, 2, 0.4), board.position + Vector3(0, 1, 0))
	_add_ent("board", "Muster Board", board.position, board, "Muster", "friends", func(): hud.muster_board())
	# doors: armory and reading room
	_add_ent("armory", "The Armory", Vector3(-6, 0, -9.2), null, "Enter", "equip", func(): G.say("The armory: here every pilgrim is given the whole armour of God, the same for all (Act II, full game). [BSB: Ephesians 6:13]", G.NPC))
	_add_ent("reading", "Reading Room", Vector3(6, 0, -9.2), null, "Enter", "library", func(): G.say("Reading Together rooms: friends read one passage side by side. On the Lord's Day they are quiet and reward-free.", G.NPC))
	# the porter
	var watchful := _sprite_npc("res://assets/sprites/npc_evangelist.png", 2, 5, true, Vector3(2.6, 0, 6.5), "Watchful the Porter", Color("ffe9a0"))
	watchful.set_tint(Color(1.05, 0.95, 0.8))
	_add_ent("watchful", "Watchful", watchful.position, watchful, "Talk", "talk", _act_watchful)
	# lamps, trees, a fountain
	for lp in [Vector3(-3, 0, 4.5), Vector3(3, 0, 4.5), Vector3(-12, 0, 2), Vector3(12, 0, 2)]:
		_box(Vector3(0.15, 3, 0.15), _mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.3, 0.3, 0.32)), lp + Vector3(0, 1.5, 0))
		var lamp := OmniLight3D.new(); lamp.light_color = Color("ffd080"); lamp.light_energy = 1.4; lamp.omni_range = 5.0; lamp.position = lp + Vector3(0, 3.0, 0); add_child(lamp); lamps.append(lamp)
		var halo := Sprite3D.new(); halo.texture = G.tex("res://assets/fx/glow.png"); halo.pixel_size = 0.03; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.shaded = false; halo.modulate = Color(1, 0.85, 0.5, 0.7); halo.position = lp + Vector3(0, 3.05, 0); add_child(halo)
	var basin := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 1.4; bc.bottom_radius = 1.5; bc.height = 0.6; basin.mesh = bc; basin.material_override = stonem
	basin.position = Vector3(0, 0.3, -2); add_child(basin); _solid_cyl(1.5, Vector3(0, 0, -2))
	_water(Vector2(2.4, 2.4), Vector3(0, 0.62, -2))
	Fx.particles(self, Vector3(0, 0.9, -2), {"amount": 18, "life": 1.0, "one_shot": false, "explode": 0.0, "sphere": 0.1, "dir": Vector3.UP, "spread": 18.0,
		"vmin": 2.2, "vmax": 2.8, "gravity": Vector3(0, -5, 0), "color": Color(0.85, 0.93, 1.0, 0.7), "size": 0.12, "tex": "res://assets/fx/drop.png", "add": false, "local": false})
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 18:
		var side := i % 3
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(-20, 20), 0, 14.5)
			1: p = Vector3(-20.5, 0, rng.randf_range(-8, 14))
			2: p = Vector3(20.5, 0, rng.randf_range(-8, 14))
		if side == 0 and absf(p.x) < 3.5:
			continue
		_tree(p, rng.randf_range(0.9, 1.25), Color(rng.randf_range(0.9, 1.1), 1.05, rng.randf_range(0.85, 1.0)))
	_walls()
	for sp in [Vector3(-6, 0, 2), Vector3(6, 0, -1)]:
		Fx.shaft(self, sp, 10.0, 2.4, 0.16)
	_add_waymark(Vector3(-2.4, 0, 9.5), "Rest at the hearth before you go on", "Ebenezer", 230)
	# pilgrims in the House (simulated in the offline demo; real players online)
	for i in HOUSE_FOLK.size():
		var f: Array = HOUSE_FOLK[i]
		var a := _pilgrim_actor(f[1], f[0], Color("dfe9ff"), false)
		var sitter := i in [3, 6]
		a.position = (Vector3(-8, 0, -3) + Vector3(cos(i) * 1.8, 0, sin(i) * 1.8 + 0.4)) if sitter else _house_spot()
		others.append({"actor": a, "path": [a.position, _house_spot()], "i": 1, "speed": 2.0, "ghost": false, "wait": randf_range(0.5, 6.0) if not sitter else 999.0,
			"kind": "house", "name": f[0], "chat_t": randf_range(2.0, 12.0) + i * 1.5, "sitter": sitter})
		if sitter:
			a.play("sit")
	_edge_fade(Color("3a4a30"))
	_weather_petals()
	objectives = [
		{"id": "porter", "text": "Speak with Watchful the Porter", "ent": "watchful"},
		{"id": "rest", "text": "Rest at the hearth (needed once before Act III)", "ent": "hearth"},
		{"id": "muster", "text": "Answer the Muster Board", "ent": "board"}]

func _act_watchful() -> void:
	var src := "John Bunyan, The Pilgrim's Progress (1678) · public domain"
	hud.run_dialog([
		{"who": "Watchful", "text": "Fear not the lions, for they are chained, and are placed there for trial of faith where it is, and for discovery of those that have none.", "src": src},
		{"who": "Watchful", "text": "This house was built by the Lord of the hill, and he built it for the relief and security of pilgrims.", "src": src},
		{"who": "Watchful", "text": "Here pilgrims who walked the way alone find one another. Rest at the hearth. Then see the Muster Board: Giant Grim has come to back the lions, and a company is wanted to drive him off.", "src": "Part II tells how Great-heart's company met Giant Grim at the lions."}],
		_watchful_done)

func _watchful_done() -> void:
	if cur_obj() == "porter":
		G.add_xp(30, 20); complete()

func _act_hearth() -> void:
	if not sitting:
		toggle_sit()
	if cur_obj() == "rest":
		G.house_rested = true
		_sparkle(player.position + Vector3(0, 1.2, 0), Color("ffd8a0"))
		G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = false
		G.say("You rest in the House, among the pilgrims. HP and Zeal restored.", G.INFO)
		G.add_xp(20, 15); complete()
	else:
		G.say("You sit by the fire.", G.SYS)

func enter_muster(party: Array) -> void:
	G.muster_party = party
	if cur_obj() == "muster":
		complete()
	ending = true
	G.goto("world", {"map": "lions"})

# ------------------------------------------------------------------ the Muster: Giant Grim at the Lions' Gate
func _build_lions() -> void:
	bounds = Rect2(-9, -12, 18, 24)
	_plane(Vector2(120, 100), _mat("res://assets/tiles/grass.png", Vector2(60, 50), false, Color(0.78, 0.76, 0.62)), Vector3.ZERO)
	_plane(Vector2(8, 40), _mat("res://assets/tiles/dirt.png", Vector2(4, 20), false, Color(0.9, 0.82, 0.68)), Vector3(0, 0.01, 0))
	var wallm := _mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(0.82, 0.78, 0.72))
	for x in [-10.0, 10.0]:
		_box(Vector3(1.2, 2.2, 30), wallm, Vector3(x, 1.1, 0))
	# the chained lions
	var lionm := _mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.62, 0.55, 0.45))
	var mane := _mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.5, 0.4, 0.3))
	var chainm := StandardMaterial3D.new(); chainm.albedo_color = Color(0.3, 0.3, 0.34); chainm.metallic = 0.6
	for sx in [-1.0, 1.0]:
		var lp := Vector3(sx * 6.4, 0, -5.0)
		_box(Vector3(2.2, 1.1, 1.0), lionm, lp + Vector3(0, 0.75, 0))
		_sphere(0.75, mane, lp + Vector3(-sx * 1.1, 1.45, 0))
		_sphere(0.45, lionm, lp + Vector3(-sx * 1.5, 1.4, 0))
		_box(Vector3(2.4, 0.08, 0.08), chainm, lp + Vector3(sx * 1.9, 1.2, 0), false)
	# the palace gate beyond
	_box(Vector3(9, 5, 1.2), _mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(1.0, 0.97, 0.9)), Vector3(0, 2.5, -13.5))
	var gl := OmniLight3D.new(); gl.light_color = Color("ffe9b0"); gl.light_energy = 2.4; gl.omni_range = 8.0; gl.position = Vector3(0, 3, -12); add_child(gl); holy_lights.append(gl)
	_walls()
	_edge_fade(Color("342c24"))
	# the company
	var party: Array = G.muster_party
	if party.is_empty():
		party = [{"name": "Lumen", "role": "support", "ai": false, "look": [2, 2, 1]}, {"name": "Rook", "role": "defender", "ai": false, "look": [0, 1, 5]},
			{"name": "Steward of the House", "role": "damage", "ai": true, "look": [0, 4, 5]}]
	var k := 0
	for m in party:
		var md: Dictionary = m
		var label: String = md.name + (" (AI)" if md.ai else "")
		var a := _pilgrim_actor(md.look, label, Color("9ff5a0") if not md.ai else Color("cfe8cf"), false)
		a.position = info("start") + Vector3(-2.0 + k * 2.0, 0, 1.2)
		allies.append({"actor": a, "name": md.name, "role": md.role, "ai": md.ai, "next": 1.0 + k * 0.4, "slot": k, "heal_t": 4.0})
		k += 1
	# Giant Grim (placeholder art: a scaled Slothling sheet until the boss sprite lands)
	var g := SpriteActor.new(); add_child(g); g.position = Vector3(0, 0, -2.5)
	g.setup({"tex": G.tex("res://assets/sprites/mob_slothling.png"), "hframes": 7, "vframes": 1, "pixel": 0.088, "rows": false, "shadow": 2.2,
		"anims": {"idle": [0, 1], "walk": [2, 3], "hurt": [4], "die": [5, 6]}, "fps": {"idle": 1.4, "walk": 2.6, "die": 2.0}}, "Giant Grim", Color("ff9a8a"))
	g.set_tint(Color(0.78, 0.6, 0.58))
	if g.name_lbl:
		g.name_lbl.font_size = 44; g.name_lbl.position.y = -0.3
	var bg := MeshInstance3D.new(); var fg := MeshInstance3D.new(); var tr := MeshInstance3D.new()
	bg.visible = false; g.add_child(bg); bg.add_child(fg); bg.add_child(tr)
	boss = {"actor": g, "hp": 1100.0, "max": 1100.0, "alive": true, "next": 0.0, "home": g.position, "wander": g.position, "wander_t": 99.0, "bg": bg, "fg": fg,
		"aggro": true, "respawn": 0.0, "tele": false, "tele_pos": Vector3.ZERO, "trail": tr, "trail_v": 1.0, "was_aggro": true, "boss": true, "goal": Vector3.ZERO}
	mobs.append(boss)
	boss_atk_t = 3.0
	objectives = [
		{"id": "boss", "text": "Drive off Giant Grim with your company"},
		{"id": "return", "text": "Return to the House", "ent": "warp", "zone": Vector3(0, 0, -10.5)}]
	var warp := Node3D.new(); warp.position = Vector3(0, 0, -10.5); add_child(warp)
	var ws := Sprite3D.new(); ws.texture = G.tex("res://assets/fx/warp.png"); ws.pixel_size = 0.014; ws.rotation_degrees.x = -90; ws.position.y = 0.06
	ws.shaded = false; ws.transparent = true; warp.add_child(ws); warp.set_meta("spin", ws)
	_add_ent("warp", "Return to the House", warp.position, warp, "Enter", "warp", _finish, true)

func _boss_targets() -> Array:
	## Weighted: the defender draws the Giant most; the player is never ignored.
	var t: Array = [{"pos": player.position, "who": "player", "w": 1.6}]
	for al in allies:
		t.append({"pos": al.actor.position, "who": al, "w": 3.0 if al.role == "defender" else 1.0})
	return t

func _pick_target() -> Dictionary:
	var ts := _boss_targets()
	var total := 0.0
	for x in ts: total += float(x.w)
	var r := randf() * total
	for x in ts:
		r -= float(x.w)
		if r <= 0.0:
			return x
	return ts[0]

func _boss_tick(delta: float) -> void:
	if not boss.alive or ending:
		return
	var a: SpriteActor = boss.actor
	hud.boss_bar("Giant Grim", boss.hp / boss.max)
	if not boss_enraged and boss.hp < boss.max * 0.5:
		boss_enraged = true
		G.say("Giant Grim roars and lays about him faster!", G.WARN)
		_pop_mark(a, "!!", Color("ff6a3a")); shake(0.4); a.flash(Color("ff6a3a"), 0.7)
	boss_atk_t -= delta * (1.35 if boss_enraged else 1.0)
	var goal: Vector3 = boss.goal if boss.goal != Vector3.ZERO else player.position
	var to := goal - a.position; to.y = 0
	if to.length() > 2.6 and boss_atk_t > 1.2:
		a.position += to.normalized() * 1.25 * delta
		a.facing = to.normalized(); a.play("walk")
	else:
		a.play("idle")
	a.position.x = clampf(a.position.x, bounds.position.x + 1, bounds.end.x - 1)
	a.position.z = clampf(a.position.z, bounds.position.y + 1, bounds.end.y - 1)
	if boss_atk_t <= 0.0:
		boss_count += 1
		boss_atk_t = 3.4
		if boss_count % 4 == 0:
			# wide slam around the Giant: everyone must step out
			var c := a.position
			Fx.telegraph(self, c, 3.3, 1.5)
			G.say("Giant Grim raises his club high!", G.WARN)
			get_tree().create_timer(1.5).timeout.connect(_boss_resolve.bind(c, 3.3, 20, true))
			for al in allies:
				var away: Vector3 = al.actor.position - c; away.y = 0
				al["dodge"] = c + (away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)) * 4.4
		else:
			var tg := _pick_target()
			boss.goal = tg.pos
			var pos: Vector3 = tg.pos
			Fx.telegraph(self, pos, 1.8, 1.1)
			get_tree().create_timer(1.1).timeout.connect(_boss_resolve.bind(pos, 1.8, 14, false))
			if tg.who is Dictionary and randf() < 0.75:
				var al2: Dictionary = tg.who
				var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				al2["dodge"] = pos + side * 2.6

func _boss_resolve(c: Vector3, r: float, dmg: int, slam: bool) -> void:
	if boss == null or not boss.alive or ending:
		return
	var a: SpriteActor = boss.actor
	a.play_once("walk", 0.3); a.squash(0.16 if slam else 0.1)
	Fx.dust(self, c, Color(0.75, 0.68, 0.55, 0.7), 14 if slam else 6)
	Fx.ring(self, c, Color(1, 0.8, 0.6), r * 0.9, 0.35)
	shake(0.45 if slam else 0.22)
	if not dead and Vector2(player.position.x - c.x, player.position.z - c.z).length() < r + 0.1:
		_hurt_player(dmg + randi() % 4)
	for al in allies:
		var ap: Vector3 = al.actor.position
		if Vector2(ap.x - c.x, ap.z - c.z).length() < r + 0.1:
			al.actor.flash(Color("ff5050"), 0.7); al.actor.squash(0.06)
			_float_text(ap + Vector3(0, 2.2, 0), str(dmg + randi() % 4), Color("ffb0b0"))

func _allies_tick(delta: float) -> void:
	if allies.is_empty():
		return
	var fighting: bool = boss != null and boss.alive and not ending
	for al in allies:
		var a: SpriteActor = al.actor
		var goal: Vector3
		if al.has("dodge"):
			goal = al.dodge
		elif fighting:
			var ang: float = PI * 0.5 + (al.slot - 1) * 0.9 + (PI if al.role == "support" else 0.0)
			var dist := 4.4 if al.role == "support" else 2.5
			goal = boss.actor.position + Vector3(cos(ang), 0, sin(ang)) * dist
		else:
			goal = player.position + Vector3(-1.6 + al.slot * 1.6, 0, 1.4)
		var to := goal - a.position; to.y = 0
		if to.length() > 0.3:
			a.position += to.normalized() * (4.0 if al.has("dodge") else 3.0) * delta
			a.facing = to.normalized(); a.play("walk")
		else:
			if al.has("dodge"):
				al.erase("dodge")
			a.play("idle")
			if fighting:
				var tb: Vector3 = boss.actor.position - a.position; tb.y = 0
				a.facing = tb.normalized()
		if not fighting:
			continue
		al.next -= delta
		if al.next <= 0.0 and not al.has("dodge"):
			al.next = randf_range(1.2, 1.6)
			if al.role == "support":
				a.play_once("cast", 0.4)
				_ally_hit(al, 6 + randi() % 4)
			elif a.position.distance_to(boss.actor.position) < 3.0:
				a.play_once("attack", 0.32)
				_ally_hit(al, (9 if al.role == "damage" else 7) + randi() % 5)
		if al.role == "support":
			al.heal_t -= delta
			if al.heal_t <= 0.0 and G.hp < G.hp_max * 0.7 and not dead:
				al.heal_t = 6.0
				var h := minf(G.hp_max - G.hp, 22.0)
				G.hp += h; G.stats_changed.emit()
				a.play_once("cast", 0.5)
				_float_text(player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
				Fx.ring(self, player.position, Color(0.6, 1.0, 0.6), 1.6, 0.4)
				G.say("%s: Hold on, I've got you." % al.name, G.CHAT)

func _ally_hit(al: Dictionary, dmg: int) -> void:
	var b: SpriteActor = boss.actor
	boss.hp = maxf(0.0, boss.hp - dmg)
	_float_text(b.position + Vector3(0, 2.6, 0), str(dmg), Color("bfe4ff"))
	b.flash(Color.WHITE, 0.45)
	var dirv: Vector3 = b.position - al.actor.position; dirv.y = 0
	Fx.sparks(self, b.position + Vector3(0, 1.4, 0), dirv.normalized(), Color(0.85, 0.9, 1.0))
	if boss.hp <= 0.0:
		_boss_down(boss)

func _boss_down(m: Dictionary) -> void:
	if not m.alive:
		return
	m.alive = false
	var a: SpriteActor = m.actor
	a.play_once("die", 1.2)
	hud.boss_bar("", -1.0)
	shake(0.6); hitstop(0.18)
	get_tree().create_timer(0.6).timeout.connect(_boss_fade_fx.bind(a.position))
	get_tree().create_timer(1.2).timeout.connect(_hide_node.bind(a))
	if target == m:
		target = null
	var humans := 0
	for al in allies:
		if not al.ai: humans += 1
	G.marks += humans
	G.add_xp(120, 80)
	G.bag_add("Grim's Broken Chain", 1)
	G.say("Muster cleared! Giant Grim is driven from the way.", G.INFO)
	G.say("Rewards: Grim's Broken Chain · Fellowship Marks +%d (one per pilgrim in your company)." % humans, G.INFO)
	hud.muster_cleared(humans)
	for al in allies:
		al.actor.play_once("cast", 0.8)
	get_tree().create_timer(1.6).timeout.connect(func(): G.say("Lumen: Well fought, all! See you at the hearth.", G.CHAT))
	show_ent("warp", true)
	complete()

func _boss_fade_fx(p: Vector3) -> void:
	Fx.motes_up(self, p + Vector3(0, 1.0, 0), Color("fff6d8"), 40, 1.8)
	Fx.ring(self, p, Color(1, 0.95, 0.75), 5.0, 0.7)

func _glint_tick() -> void:
	for e in ents:
		if e.get("kind", "") != "secret" or e.hidden or e.node == null:
			continue
		var g: Sprite3D = e.node.get_meta("glint")
		var d := Vector2(player.position.x - e.pos.x, player.position.z - e.pos.z).length()
		var near := clampf(1.0 - (d - 2.0) / 6.0, 0.0, 1.0)
		g.modulate.a = near * (0.55 + 0.45 * sin(t * 4.0 + e.pos.x))
		g.rotation.z = t * 0.8

# ======================================================================
# Onboarding: the Dreamer's guided Prologue (combat-free Eden), the Fall played out
# in the garden, waking in the City, and first-fight lessons.
# Pattern (from OSRS Tutorial Island, RO Training Grounds, Ragnarok Origin, Genshin):
# one guide voice, one thing at a time, learn by doing, every lesson ends in a reward.
# ======================================================================
const DREAMER := "The Dreamer"
const BSB := " · text pulled at build time]"

func _build_eden_guides() -> void:
	# the Dreamer walks beside you (a vision-guide; never a depiction of God)
	dreamer = _pilgrim_actor([1, 5, 3], DREAMER, Color("ffe9a0"), false)
	dreamer.position = info("start") + Vector3(1.6, 0, 1.0)
	var de := _add_ent("dreamer", DREAMER, dreamer.position, dreamer, "Talk", "talk", _talk_dreamer)
	de["kind"] = "guide"   # tap him to ask what's next; he never steals the Act button
	# three drooping lilies for the first skill
	for lp in [Vector3(0.2, 0, 5.2), Vector3(2.2, 0, 3.4), Vector3(-1.6, 0, 1.8)]:
		var a := SpriteActor.new(); add_child(a); a.position = lp
		a.setup({"tex": G.tex("res://assets/sprites/lily.png"), "hframes": 2, "vframes": 1, "pixel": 0.035, "rows": false, "shadow": 0.5,
			"anims": {"idle": [0], "bloom": [1]}}, "", Color.WHITE)
		lilies.append({"actor": a, "pos": lp, "bloomed": false})

func _dreamer_tick(delta: float) -> void:
	if dreamer == null or cinema:
		return
	var e := ent("dreamer")
	var to := player.position - dreamer.position; to.y = 0
	if to.length() > 3.2:
		dreamer.position += to.normalized() * minf(SPEED * 0.95 * delta, to.length() - 2.4)
		dreamer.facing = to.normalized(); dreamer.play("walk")
	else:
		dreamer.play("idle"); dreamer.facing = to.normalized() if to.length() > 0.1 else dreamer.facing
	if not e.is_empty():
		e.pos = dreamer.position

func _talk_dreamer() -> void:
	var o: Dictionary = objectives[obj_idx] if obj_idx < objectives.size() else {"text": "Behold the two trees"}
	hud.run_dialog([{"who": DREAMER, "text": "Your next step: %s. Tap the quest box on the left and you will walk there by yourself. The Pilgrim's Guide in More answers every question." % o.text}], func(): pass)

# ------------------------------------------------------------------ Eden lessons
func _eden_intro() -> void:
	if not is_inside_tree():
		return
	hud.run_dialog([
		{"who": DREAMER, "text": "Here we are, inside my dream. This is Eden, the garden as it was in the beginning. Nothing here can harm you, so it is a good place to learn how to walk the Way.",
			"choices": [{"t": "Why am I here?"}, {"t": "I'm ready. Show me.", "goto": 2}]},
		{"who": DREAMER, "text": "Soon the dream will turn, and you will wake in a city with a great burden on your back. You will need to flee from it to the Wicket Gate. All you learn in this garden, you will use on that road."},
		{"who": DREAMER, "text": "Tell me: have you walked in worlds like this one before?",
			"choices": [{"t": "No, this is new to me.", "fn": func(): G.guide = "full"}, {"t": "Yes, I've played MMOs.", "fn": func(): G.guide = "light"}]},
		{"who": DREAMER, "text": "Then I will show you one thing at a time. You can turn my tips off whenever you like, in More → Guide."}],
		_lesson_move)

func _lesson_move() -> void:
	var L: bool = not G.settings.left_handed
	hud.coach.run([
		{"kind": "action", "text": "Put your thumb on the left side of the screen and drag to walk. Walk into the glowing circle by my lamp.",
			"short": "Drag on the left to walk. Go to the glowing circle.",
			"target": func(): return _joy_zone(L), "done": func(): return obj_idx > 0},
		{"tour": true, "text": "Well walked! You can also just tap the ground, and you will walk there.", "target": null},
		{"tour": true, "text": "This is you. The green bar is Health. The blue bar is Zeal: it powers your skills. Tap this plate any time to see your Status.",
			"target": func(): return hud.plate},
		{"tour": true, "text": "Your next step always shows here. Tap this box and you will walk there by yourself.", "target": func(): return hud.quest_box},
		{"tour": true, "text": "The map. The gold ★ marks where to go. ✦ 0/2 counts the secrets hidden on this map. Tap the map to see your quest log.",
			"target": func(): return hud.minimap},
		{"tour": true, "text": "More holds everything else: Status, Skills, Satchel, the Pilgrim's Guide and Settings. A red number on it means points are waiting to be spent.",
			"target": func(): return hud.more_btn},
		{"tour": true, "text": "Messages from the world appear here. Tap to read older ones.", "target": func(): return hud.chat_box},
		{"kind": "action", "text": "Now tend the Young Vine. Tap the quest box to walk there, or tap the vine itself.", "short": "Go to the Young Vine.",
			"target": func(): return hud.quest_box, "done": func(): return nearest_ent() != null and nearest_ent().id == "vine" or cur_obj() != "tend"},
		{"kind": "action", "text": "When you are close to something, this big button shows what you can do with it. Tap Tend.", "short": "Tap Tend.",
			"target": func(): return hud.act_btn, "done": func(): return cur_obj() != "tend"}])

func _joy_zone(L: bool) -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	return Rect2(Vector2(40 if L else vs.x * 0.62, vs.y * 0.5), Vector2(vs.x * 0.3, vs.y * 0.4))

## First Base and Job Level-ups teach levels, attributes and skills.
func _level_lesson(kind: String) -> void:
	if map_id != "eden":
		if kind.begins_with("Job") and G.tip_once("job_up_city"):
			hud.coach.tip("Job Level up: +2 skill points. Open More → Skills to make First Steps or Take Refuge stronger.", func(): return hud.more_btn, 6.0)
		elif kind.begins_with("Base") and G.tip_once("base_up_city"):
			hud.coach.tip("Base Level up: +2 attribute points. Open More → Status to spend them.", func(): return hud.more_btn, 6.0)
		return
	if kind.begins_with("Base") and G.tip_once("first_base"):
		get_tree().create_timer(1.2).timeout.connect(_lesson_stats)

func _lesson_stats() -> void:
	hud.coach.run([
		{"text": "You grew! Your Base Level is now %d. There are two kinds of level, shown here: Base and Job." % G.lvl, "target": func(): return hud.lv_txt},
		{"text": "Base Level is you. Each one gives 2 attribute points and refills your Health and Zeal. Job Level is your calling. Each one gives 2 skill points.", "tour": true,
			"target": func(): return hud.lv_txt},
		{"tour": true, "text": "This thin bar along the bottom fills with experience. When it is full, you level up. Quests, tending, reading and overcoming foes all give experience, and you never lose it.",
			"target": func(): return hud.exp_bar},
		{"kind": "action", "text": "Let's spend your 2 attribute points. Tap More (see the red +2).", "short": "Tap More.",
			"target": func(): return hud.more_btn, "done": func(): return hud.overlay_open() or G.stat_pts == 0},
		{"kind": "action", "text": "Tap Status.", "target": func(): return hud.more_tiles.get("status"),
			"done": func(): return hud.sheet_tab == "status" or G.stat_pts == 0, "skip_if": func(): return hud.sheet_tab == "status"},
		{"kind": "action", "text": "Six attributes shape you. Tap + to add a point. The green words show exactly what it changes. Steadfastness gives more Health; Fortitude hits harder. Resetting is free here, so try anything.",
			"short": "Tap + twice. Green text shows the effect.",
			"target": func(): return hud.stat_plus.get("ste"), "done": func(): return G.stat_pts == 0},
		{"kind": "action", "text": "Well chosen. Close the window with ✕, or tap the dark area beside it.", "target": null, "done": func(): return not hud.overlay_open()},
		{"kind": "tip", "text": "Next: gather figs from the Fig Tree. Tap the quest box to walk there.", "target": func(): return hud.quest_box, "secs": 4.5}])

func _lesson_skills() -> void:
	hud.coach.run([
		{"tour": true, "text": "Your figs went into your Satchel (More → Satchel). This quick-item button eats one to restore Health. You will want food after the garden.",
			"target": func(): return hud.item_btn},
		{"text": "Your Job Level rose to %d, so you have %d skill points. Skills are special actions that cost Zeal. Let's learn your first one." % [G.job, G.skill_pts],
			"target": func(): return hud.lv_txt},
		{"kind": "action", "text": "Tap More.", "target": func(): return hud.more_btn, "done": func(): return hud.overlay_open() or G.has_skill("tend")},
		{"kind": "action", "text": "Tap Skills.", "target": func(): return hud.more_tiles.get("skills"),
			"done": func(): return hud.sheet_tab == "skills" or G.has_skill("tend"), "skip_if": func(): return hud.sheet_tab == "skills"},
		{"kind": "action", "text": "Tap Learn on Tend and Keep. It is a garden skill for Eden only. Keep your other point: you will want it for First Steps after you wake.",
			"short": "Learn Tend and Keep.", "target": func(): return hud.skill_learn.get("tend"), "done": func(): return G.has_skill("tend")},
		{"kind": "action", "text": "Learned! Close this window (✕ or tap beside it).", "target": null, "done": func(): return not hud.overlay_open()},
		{"text": "Your skill is now on your skill bar. The blue number is its Zeal cost. After you use it, a dark sweep shows it recharging.",
			"target": func(): return hud.skill_btns[0]},
		{"kind": "action", "text": "Walk next to a drooping lily and tap Tend and Keep.", "short": "Tend a drooping lily.",
			"target": func(): return hud.skill_btns[0], "done": func(): return lilies_done >= 1}])

func _lesson_manna() -> void:
	hud.coach.run([
		{"text": "Word Study gave you Manna. Manna is gathered through the means of grace: reading the Word, rest and worship. Its count is shown here, by your experience.",
			"target": func(): return hud.exp_txt},
		{"tour": true, "text": "Later you spend Manna on Disciplines and Refreshments. If you fall in battle, a little unspent Manna spoils, so spend it rather than hoard it.", "target": null},
		{"text": "You have learned to walk, to tend, to grow and to use a skill. One thing remains: behold the two trees in the midst of the garden.", "target": func(): return hud.quest_box}])

## Objectives that finish by themselves (spend points, learn a skill).
func _eden_obj_tick() -> void:
	match cur_obj():
		"stats":
			if G.stat_pts == 0:
				complete()
		"learn":
			if G.has_skill("tend"):
				complete()

func _on_new_obj() -> void:
	if map_id != "eden":
		return
	match cur_obj():
		"learn":
			if G.tip_once("skills_lesson"):
				get_tree().create_timer(1.0).timeout.connect(_lesson_skills)

# ------------------------------------------------------------------ cinema
func _cinema(on: bool) -> void:
	cinema = on
	hud.cinema(on)
	if quest_mark:
		quest_mark.visible = not on
	if not on:
		cam_focus = null

## The Fall, played out in the garden rather than on black cards. The man and the woman are
## not shown: the player is the Dreamer's witness. God is never shown or voiced.
func _fall_scene() -> void:
	_cinema(true)
	target = null; move_target = null; pending = null
	cam_focus = Vector3(16, 0, 0.5)
	_serpent = SpriteActor.new(); add_child(_serpent); _serpent.position = Vector3(19.2, 0, 1.4)
	_serpent.setup({"tex": G.tex("res://assets/sprites/serpent.png"), "hframes": 2, "vframes": 1, "pixel": 0.04, "rows": false, "shadow": 0.7,
		"anims": {"idle": [0, 1]}, "fps": {"idle": 2.0}}, "", Color.WHITE)
	_serpent.visible = false
	hud.run_dialog([
		{"who": DREAMER, "text": "Behold the two trees in the midst of the garden: the tree of life, and the tree of the knowledge of good and evil.", "src": "[BSB: Genesis 2:9" + BSB},
		{"who": DREAMER, "text": "The man was told he could eat freely of every tree but one. In the day he ate of that tree, he would surely die.", "src": "[BSB: Genesis 2:16–17" + BSB},
		{"who": DREAMER, "text": "And I saw in my dream that the serpent spoke in the garden, and questioned the word that had been given.", "src": "[BSB: Genesis 3:1" + BSB,
			"fn": _fall_serpent},
		{"who": DREAMER, "text": "The fruit was taken and eaten. The man, the head of all his kind, broke the covenant, and all his children fell with him.", "src": "[BSB: Genesis 3:6 · Romans 5:12" + BSB,
			"fn": func(): _fall_darken(0.5)},
		{"who": DREAMER, "text": "Their eyes were opened, and they knew shame. They hid themselves among the trees of the garden.", "src": "[BSB: Genesis 3:7–8" + BSB,
			"fn": _fall_hide},
		{"who": DREAMER, "text": "So the man was driven out, east of Eden. Cherubim and a flaming sword, turning every way, guarded the way back to the tree of life.", "src": "[BSB: Genesis 3:24" + BSB,
			"fn": func(): _show_cherubim()},
		{"who": DREAMER, "text": "Now my dream turns, pilgrim. Wake… and remember the garden."}],
		func(): G.goto("world", {"map": "city", "wake": true}))

func _fall_serpent() -> void:
	_serpent.visible = true; _serpent.squash(0.3)
	Fx.dust(self, _serpent.position, Color(0.3, 0.35, 0.25, 0.6), 6)

func _fall_hide() -> void:
	_fall_darken(1.0)
	_serpent.visible = false
	cam_focus = Vector3(10, 0, -4)

func _fall_darken(k: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "light_color", Color("ffcf9a").lerp(Color("8a7a9a"), k), 2.0)
	tw.tween_property(sun, "light_energy", lerpf(0.62, 0.32, k), 2.0)
	tw.tween_property(env, "ambient_light_energy", lerpf(0.34, 0.18, k), 2.0)
	post.set_shader_parameter("tint", Vector3(1.0, 0.96, 0.9).lerp(Vector3(0.82, 0.82, 0.95), k))
	for h in holy_lights:
		if h is OmniLight3D:
			create_tween().tween_property(h, "light_energy", 0.3, 2.0)
	if k >= 1.0:
		shake(0.25)
		Fx.particles(self, player.position + Vector3(0, 6, 0), {"amount": 40, "life": 4.0, "one_shot": false, "explode": 0.0, "sphere": 10.0,
			"vmin": 0.2, "vmax": 0.6, "gravity": Vector3(0.3, -0.6, 0), "color": Color("8a6a3a"), "size": 0.16, "tex": "res://assets/fx/petal.png", "add": false, "local": false})

func _show_cherubim() -> void:
	var gate := Vector3(24, 0, 0)
	cam_focus = gate + Vector3(-3, 0, 0)
	for z in [-2.2, 2.2]:
		var c := Sprite3D.new(); c.texture = G.tex("res://assets/fx/cherub.png"); c.pixel_size = 0.03; c.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		c.shaded = false; c.position = gate + Vector3(0, 2.2, z); c.modulate = Color(1, 0.96, 0.8, 0.0); add_child(c)
		create_tween().tween_property(c, "modulate:a", 0.95, 1.2)
		_cherub_nodes.append(c)
	var sword := Sprite3D.new(); sword.texture = G.tex("res://assets/fx/flame_sword.png"); sword.pixel_size = 0.03; sword.shaded = false
	sword.position = gate + Vector3(0, 2.0, 0); sword.modulate = Color(1, 1, 1, 0); add_child(sword)
	create_tween().tween_property(sword, "modulate:a", 1.0, 0.8)
	var spin := create_tween().set_loops(); spin.tween_property(sword, "rotation:z", TAU, 1.6).as_relative()
	var fl := OmniLight3D.new(); fl.light_color = Color("ff9a40"); fl.light_energy = 3.0; fl.omni_range = 7.0; fl.position = gate + Vector3(0, 2, 0); add_child(fl)
	_cherub_nodes.append(sword)
	G.haptic(40)

# ------------------------------------------------------------------ City of Destruction
func _wake_scene() -> void:
	_cinema(true)
	pact.play("rest")
	cam_dist = 12.0
	hud.run_dialog([
		{"who": DREAMER, "text": "I saw a man clothed with rags, standing in a certain place, with his face from his own house, a book in his hand, and a great burden upon his back.",
			"src": "John Bunyan, The Pilgrim's Progress (1678) · public domain"},
		{"who": DREAMER, "text": "That man is you, pilgrim. This is the City of Destruction. You were born in Adam, and the burden is your sin. It slows you, and you cannot put it down by yourself."},
		{"who": G.pname, "text": "What shall I do?", "fn": _wake_rise},
		{"who": DREAMER, "text": "First, rise. Slothlings crowd these streets: the sins of sloth that would keep you sitting still. Overcome them, and someone will come to show you the way."}],
		_wake_done)

func _wake_rise() -> void:
	pact.play("idle"); Fx.dust(self, player.position, Color(0.7, 0.68, 0.66, 0.5), 4)

func _wake_done() -> void:
	_cinema(false)
	cam_dist = 17.0
	_city_lessons()

func _city_lessons() -> void:
	if not is_inside_tree():
		return
	var steps := [
		{"kind": "action", "text": "Tap Attack, or tap a Slothling, to fight. You keep striking until it is overcome. Combat is new: it only begins after the garden.",
			"short": "Tap Attack to fight.", "target": func(): return hud.atk_btn, "done": func(): return slain >= 1}]
	if not G.has_skill("steps"):
		steps += [
			{"kind": "action", "text": "Well fought! Now learn a fighting skill. Tap More.", "short": "Learn First Steps: tap More.",
				"target": func(): return hud.more_btn, "done": func(): return hud.overlay_open() or G.has_skill("steps")},
			{"kind": "action", "text": "Tap Skills.", "target": func(): return hud.more_tiles.get("skills"),
				"done": func(): return hud.sheet_tab == "skills" or G.has_skill("steps"), "skip_if": func(): return hud.sheet_tab == "skills"},
			{"kind": "action", "text": "Learn First Steps: a heavy lunge. If you still have a point, Take Refuge heals you.", "target": func(): return hud.skill_learn.get("steps"),
				"done": func(): return G.has_skill("steps")},
			{"kind": "action", "text": "Close the window (✕ or tap beside it).", "target": null, "done": func(): return not hud.overlay_open()}]
	steps += [
		{"kind": "action", "text": "Stand next to a Slothling and tap First Steps.", "short": "Use First Steps.",
			"target": func(): return _skill_btn_for("steps"), "done": func(): return used_steps or not G.has_skill("steps")}]
	hud.coach.run(steps)

func _skill_btn_for(id: String) -> Control:
	var ids: Array = hud.bar_skills()
	var k := ids.find(id)
	return hud.skill_btns[k] if k >= 0 else null

func _city_tips_tick() -> void:
	if map_id != "city" or cinema or hud.coach.busy():
		return
	if slain >= 2 and G.tip_once("auto"):
		hud.coach.tip("Auto attacks and uses your skills for you. It works only in fields like this street; bosses and story moments are always yours to play.", func(): return hud.auto_btn, 6.0)
	elif slain >= 3 and not _any_aggro() and G.hp < G.hp_max * 0.7 and G.tip_once("sit"):
		hud.coach.tip("Sit to recover Health and Zeal three times faster. Moving stands you up.", func(): return hud.sit_btn, 6.0)
