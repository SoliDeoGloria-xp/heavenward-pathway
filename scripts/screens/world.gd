extends Node3D
## The 3D world: classic RO presentation (2D sprites on a lit 3D map, fixed three-quarter camera)
## with RO M / Origin phone controls (joystick, attack + skill arc, auto, context Act button).
## Maps: "eden" (Eden Isle prologue, no combat) and "city" (City of Destruction, first fights).

const SPEED := 4.6
const PICK_PX := 70.0

var map_id := "eden"
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
var cd := {"steps": 0.0, "refuge": 0.0}
const CD_LEN := {"steps": 6.0, "refuge": 12.0}
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
var _lamb_actor: SpriteActor

func _ready() -> void:
	map_id = get_meta("data").get("map", "eden")
	_build_env()
	_build_player()
	_build_camera()
	if map_id == "eden":
		_build_eden()
	else:
		_build_city()
	hud = load("res://scripts/ui/hud.gd").new()
	hud.world = self
	add_child(hud)
	G.level_up.connect(_on_level_up)
	_update_quest()
	hud.banner("Eden Isle" if map_id == "eden" else "City of Destruction", "Prologue · The Garden" if map_id == "eden" else "Chapter 1 · Flee from the wrath to come")
	if map_id == "eden":
		G.say("Welcome to Eden Isle. Drag on the left to walk, or tap the ground.", G.INFO)
	else:
		G.burden = true
		G.say("A great burden weighs upon your back.", G.WARN)
		get_tree().create_timer(1.5).timeout.connect(func(): G.say("Slothlings stir in the street. Tap Attack or tap a monster.", G.WARN))
	hud.refresh()

# ------------------------------------------------------------------ environment
func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if map_id == "eden":
		env.background_color = Color("2e4a2a")
		env.ambient_light_color = Color("e8eef8"); env.ambient_light_energy = 0.42
	else:
		env.background_color = Color("2a2832")
		env.ambient_light_color = Color("a8a4c0"); env.ambient_light_energy = 0.38
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.78 if map_id == "eden" else 0.55
	sun.light_color = Color("fff3dc") if map_id == "eden" else Color("c8c4d8")
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
	ALBEDO = mix(a, b, 0.5) * vec3(0.95, 1.0, 1.05);
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
	player.position = Vector3(-14, 0, 6) if map_id == "eden" else Vector3(-12, 0, 3)

func _build_camera() -> void:
	cam_rig = Node3D.new(); add_child(cam_rig)
	cam = Camera3D.new(); cam.fov = 30.0; cam.far = 200.0
	cam_rig.add_child(cam)
	_place_camera(true)

func _place_camera(snap: bool = false) -> void:
	var pitch := deg_to_rad(52.0)
	cam_rig.position = cam_rig.position.lerp(player.position, 1.0 if snap else 0.15)
	cam.position = Vector3(0, sin(pitch) * cam_dist, cos(pitch) * cam_dist)
	cam_rig.rotation.y = cam_yaw
	cam.look_at(cam_rig.global_position + Vector3(0, 0.9, 0), Vector3.UP)

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
	_plane(Vector2(52, 3.2), _mat("res://assets/tiles/dirt.png", Vector2(26, 1.6)), Vector3(0, 0.01, 7), 0.0)
	_plane(Vector2(3.2, 20), _mat("res://assets/tiles/dirt.png", Vector2(1.6, 10)), Vector3(4, 0.012, -1))
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
	var know := _tree(Vector3(18, 0, 0.4), 1.3, Color(0.8, 0.95, 0.75), Color("d8342a"), false)
	know.reparent(trees)
	_add_ent("trees", "The Two Trees", Vector3(16, 0, 1.6), trees, "Behold", "eye", _act_trees, true)
	objectives = [
		{"id": "walk", "text": "Walk to the shining place", "zone": Vector3(-8, 0, 7)},
		{"id": "tend", "text": "Tend the Young Vine", "ent": "vine"},
		{"id": "gather", "text": "Gather from the Fig Tree", "ent": "fig"},
		{"id": "name", "text": "Give the Lamb a name", "ent": "lamb"},
		{"id": "read", "text": "Read the Stone Tablet", "ent": "stone"},
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
		var lamp := OmniLight3D.new(); lamp.light_color = Color("ffb060"); lamp.light_energy = 1.6; lamp.omni_range = 5.0; lamp.position = lp + Vector3(0, 3.0, 0); add_child(lamp)
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
	mobs.append({"actor": a, "hp": 60.0, "max": 60.0, "alive": true, "next": 0.0, "home": pos, "wander": pos, "wander_t": randf_range(1, 4), "bg": bg, "fg": fg, "aggro": false, "respawn": 0.0})

func _mob_tick(delta: float) -> void:
	var p := player.position
	for m in mobs:
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
			if m.aggro and not dead and t > m.next:
				if m.next == 0.0:
					m.next = t + 1.0
				else:
					m.next = t + 1.8
					a.play_once("walk", 0.3)
					if randf() < 0.2:
						_float_text(p + Vector3(0, 2.2, 0), "Miss", Color("dff2ff"))
					else:
						var dmg := 7 + randi() % 4
						_hurt_player(dmg)
		a.position.x = clampf(a.position.x, bounds.position.x, bounds.end.x)
		a.position.z = clampf(a.position.z, bounds.position.y, bounds.end.y)

func _hurt_player(dmg: int) -> void:
	if sitting:
		_stand()
	G.hp = maxf(0.0, G.hp - dmg)
	_float_text(player.position + Vector3(0, 2.2, 0), str(dmg), Color("ff6a6a"))
	pact.play_once("attack", 0.0)
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
	_float_text(a.position + Vector3(0, 1.6, 0), str(dmg), Color("ffe25a") if crit else Color.WHITE, crit)
	G.zeal = minf(G.zeal_max, G.zeal + 3.0)
	a.play_once("hurt", 0.18)
	var tw := create_tween(); tw.tween_property(a, "position", a.position + (a.position - player.position).normalized() * 0.25, 0.08)
	m.bg.visible = true
	m.fg.scale.x = maxf(0.001, m.hp / m.max); m.fg.position.x = -0.43 * (1.0 - m.hp / m.max)
	if m.hp <= 0.0:
		m.alive = false; m.respawn = 14.0; m.bg.visible = false
		a.play_once("die", 0.7)
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

func _float_text(pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	if not G.settings.dmg_numbers and text != "Miss":
		return
	var l := Label3D.new(); l.text = text; l.font = G.font_ui_bold; l.font_size = 64 if big else 50
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
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)

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
	var l := _label3d(kind, player.position + Vector3(0, 2.8 if kind.begins_with("Base") else 3.5, 0), Color("ffe27a") if kind.begins_with("Base") else Color("a8dcff"), 56)
	l.outline_modulate = Color("7a4a00")
	var tw := create_tween(); tw.tween_property(l, "position:y", l.position.y + 1.0, 1.6); tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tw.tween_callback(l.queue_free)
	var ring := Sprite3D.new(); ring.texture = G.tex("res://assets/fx/ring.png"); ring.rotation_degrees.x = -90; ring.pixel_size = 0.01; ring.shaded = false
	add_child(ring); ring.position = player.position + Vector3(0, 0.08, 0)
	var tw2 := create_tween(); tw2.tween_property(ring, "scale", Vector3(3, 3, 3), 1.0); tw2.parallel().tween_property(ring, "modulate:a", 0.0, 1.0); tw2.tween_callback(ring.queue_free)
	var col := Sprite3D.new(); col.texture = G.tex("res://assets/fx/glow.png"); col.pixel_size = 0.05; col.scale = Vector3(1, 4, 1)
	col.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; col.shaded = false; col.modulate = Color(1, 0.95, 0.7, 0.8)
	add_child(col); col.position = player.position + Vector3(0, 1.5, 0)
	var tw3 := create_tween(); tw3.tween_property(col, "modulate:a", 0.0, 1.2); tw3.tween_callback(col.queue_free)
	_sparkle(player.position + Vector3(0, 1, 0), Color("ffe9a0"))

# ------------------------------------------------------------------ objectives
func cur_obj() -> String:
	return objectives[obj_idx].id if obj_idx < objectives.size() else ""

func complete() -> void:
	obj_idx += 1
	if cur_obj() == "trees":
		show_ent("trees", true)
	_update_quest()
	if obj_idx < objectives.size():
		G.say("Quest: " + objectives[obj_idx].text, G.INFO)
		hud.quest_toast(objectives[obj_idx].text)

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
	elif cur_obj() == "fight":
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
		if e.hidden or e.fn == null:
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
	if dead:
		return
	match id:
		"steps":
			if cd.steps > 0.0:
				G.say("First Steps is not ready.", G.WARN); return
			if G.zeal < 10:
				G.say("Not enough Zeal.", G.WARN); return
			var m = target if (target != null and target.alive) else _nearest_mob(10.0)
			if m == null:
				G.say("No target.", G.WARN); return
			target = m
			if m.actor.position.distance_to(player.position) > 2.2:
				G.say("Too far. Moving closer…", G.WARN); return
			G.zeal -= 10; cd.steps = CD_LEN.steps; gcd = 1.0
			pact.facing = (m.actor.position - player.position).normalized()
			pact.play_once("attack", 0.35)
			hit_mob(m, 20 + randi() % 5, true)
			G.say("First Steps!", G.SYS)
		"refuge":
			if cd.refuge > 0.0:
				G.say("Take Refuge is not ready.", G.WARN); return
			if G.zeal < 15:
				G.say("Not enough Zeal.", G.WARN); return
			G.zeal -= 15; cd.refuge = CD_LEN.refuge; gcd = 1.0
			var h := minf(G.hp_max - G.hp, 30.0)
			G.hp += h
			pact.play_once("cast", 0.5)
			_float_text(player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
			_sparkle(player.position + Vector3(0, 1, 0), Color("c8e8ff"))
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
	player.position = Vector3(-12, 0, 3)
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
	G.goto("end")

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	t += delta
	gcd = maxf(0.0, gcd - delta)
	for k in cd.keys():
		cd[k] = maxf(0.0, cd[k] - delta)
	if dead or (hud and hud.overlay_open()):
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
				next_atk = t + 1.1
				pact.play_once("attack", 0.32)
				var crit := randf() < 0.12
				hit_mob(target, (8 + randi() % 5) * (2 if crit else 1), crit, randf() < 0.08)
	elif move_target != null:
		var to2: Vector3 = move_target - player.position; to2.y = 0
		if to2.length() > 0.25:
			v = to2.normalized()
		else:
			move_target = null
	if v.length() > 0.0:
		var spd := SPEED * (0.8 if G.weary else 1.0)
		player.velocity = v.normalized() * spd * minf(1.0, maxf(v.length(), 0.35))
		pact.facing = v.normalized()
		pact.play("walk")
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
			if cur_obj() == "light":
				_finish()
			else:
				complete()
				if cur_obj() == "tend":
					G.say("Well walked! Tap things in the world, or use the Act button when near.", G.SYS)
	# auto battle (within the Tier 1 auto scope: auto-attack and the auto-skill slots)
	if auto_on and map_id == "city":
		if target == null or not target.alive:
			target = _nearest_mob(14.0)
		if target != null and cd.steps <= 0.0 and G.zeal >= 10 and target.actor.position.distance_to(player.position) < 2.2 and gcd <= 0.0:
			skill("steps")
		if G.hp < G.hp_max * 0.45 and cd.refuge <= 0.0 and G.zeal >= 15:
			skill("refuge")
	if map_id == "city":
		_mob_tick(delta)
	_drop_tick()
	# regeneration (faster while sitting)
	regen_t += delta
	if regen_t >= 1.0:
		regen_t = 0.0
		var mult := 3.0 if sitting else 1.0
		G.zeal = minf(G.zeal_max, G.zeal + 1.0 * mult)
		if not (map_id == "city" and _any_aggro()):
			G.hp = minf(G.hp_max, G.hp + 1.0 * mult)
		G.stats_changed.emit()
	# camera
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, 0.12)
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
	return cd[id] / CD_LEN[id]

# ------------------------------------------------------------------ interaction handlers
func _act_vine() -> void:
	if cur_obj() != "tend":
		G.say("The vine is flourishing.", G.SYS); return
	var nm := _mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(1.0, 1.2, 0.9))
	for lf in _vine_leaves:
		lf.material_override = nm
	_sparkle(ent("vine").pos + Vector3(0, 1.4, 0))
	G.say("You tended the vine. It flourishes.", G.SYS)
	G.add_xp(40, -1, "eden"); complete()

func _act_fig() -> void:
	if cur_obj() != "gather":
		G.say("The branches are heavy with fruit.", G.SYS); return
	G.bag_add("Garden Fig", 3); G.say("You got Garden Fig ×3. (Satchel)", G.INFO); _item_pop("fig")
	G.add_xp(30, -1, "eden"); complete()

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
	G.manna += 5
	G.say("Word Study complete. Manna +5.", G.INFO)
	_motes(player.position)
	G.add_xp(60, -1, "eden"); complete()

func _act_trees() -> void:
	if ending:
		return
	ending = true
	G.goto("story", {"id": "fall"})

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
