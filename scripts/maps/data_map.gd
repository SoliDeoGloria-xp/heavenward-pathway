class_name DataMap
extends RefCounted
## Builds a map from its JSON definition (data/maps/<id>.json): ground, props, entities.
## Maps with hand-built geometry (scripts/maps/<id>.gd) still get their JSON props and entities
## added on top, so new characters and pages are data too. See README "Adding a chapter".

const PLANE_SIZE := Vector2(120, 100)
const TILE := "res://assets/tiles/%s.png"
const DEFAULT_BOUNDS := [-24, -14, 48, 28]
const STONE := Color("d8d2c0")

var w: World
var kit: MapKit

func _init(world: World) -> void:
	w = world; kit = world.kit

# ------------------------------------------------------------------ whole-map build (no bespoke script)
func build() -> void:
	var look: Dictionary = w.def.look
	var b: Array = w.def.get("bounds", DEFAULT_BOUNDS)
	w.bounds = Rect2(b[0], b[1], b[2], b[3])
	kit._plane(PLANE_SIZE, kit._mat(TILE % look.ground, PLANE_SIZE * 0.5, false, Color(String(look.ground_tint))), Vector3.ZERO)
	kit._walls()
	kit._edge_fade(Color(String(look.bg)))
	match String(look.get("weather", "")):
		"drizzle": kit._weather_drizzle()
		"petals": kit._weather_petals()

## Props and entities from data; runs for every map.
func populate() -> void:
	for p in w.def.get("props", []):
		prop(p, World.v3(p.get("at", [0, 0])))
	for e in w.def.get("ents", []):
		_ent(e)

# ------------------------------------------------------------------ props
func prop(p: Dictionary, at: Vector3) -> Node3D:
	var tint := Color(String(p.get("tint", "#ffffff")))
	match String(p.t):
		"path": return kit._plane(Vector2(p.size[0], p.size[1]), kit._mat(TILE % p.tile, Vector2(p.size[0], p.size[1]) * 0.5, false, tint), at + Vector3(0, float(p.get("y", 0.012)), 0))
		"water": kit._water(Vector2(p.size[0], p.size[1]), at + Vector3(0, float(p.get("y", 0.03)), 0), Color(String(p.get("tint", "#f2ffff"))))
		"box":
			var size := Vector3(p.size[0], p.size[1], p.size[2])
			return kit._box(size, kit._mat(TILE % p.tile, Vector2(0.5, 0.5), true, tint), at + Vector3(0, size.y * 0.5, 0), p.get("solid", true))
		"wall": _wall(World.v3(p.from), World.v3(p.to), float(p.h), tint)
		"tree": return kit._tree(at, float(p.get("s", 1.1)), tint)
		"trees": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit._tree(pos, rng.randf_range(0.9, 1.3), tint))
		"rocks": _scatter(p, _rock)
		"lamp": _lamp(at, Color(String(p.get("color", "#ffb060"))))
		"light": _light(at + Vector3(0, float(p.get("y", 3.0)), 0), Color(String(p.color)), float(p.e), float(p.range))
		"shaft": Fx.shaft(w, at, 10.0, 2.4, 0.18)
		"house": _house(at, float(p.get("w", 6.5)))
		"stone": return _stepping_stone(at)
		"gate": return _gate(at)
		"cross": return _cross(at)
		"tomb": return _tomb(at)
		"arbour": return _arbour(at)
		"lion": return _lion(at, float(p.get("side", 1)))
		"billboard": return _billboard(at, String(p.art), float(p.get("h", 6.0)), tint)
		"ridge": _ridge(p, tint)
		"terrace": return kit._box(Vector3(p.size[0], float(p.h), p.size[1]), kit._mat(TILE % String(p.get("tile", "grass")), Vector2(p.size[0], p.size[1]) * 0.25, true, tint), at + Vector3(0, float(p.h) * 0.5, 0))
		"pillars": _pillars(p, tint)
		"crystals": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: _crystal(pos, rng, Color(String(p.get("color", "#9fd8ff")))))
		"mushrooms": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: _mushroom(pos, rng, Color(String(p.get("color", "#ffb0e0")))))
		"blooms": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: _bloom(pos, rng, Color(String(p.get("color", "#fff0a0")))))
		"dead_trees": _scatter(p, _dead_tree)
		"spires": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: _spire(pos, rng, tint))
		"eyes": _scatter(p, _eyes)
		"torch": return _torch(at, Color(String(p.get("color", "#ffb050"))), p.get("light", false))
		"banner": return _banner(at, Color(String(p.get("color", "#b03030"))))
		"fence": _fence(World.v3(p.from), World.v3(p.to))
		"bridge": return _bridge(at, float(p.get("len", 6.0)))
		"stairs": _stairs(at, int(p.get("steps", 4)), float(p.get("w", 4.0)), tint)
		"fog": _fog(p, tint)
		"motes": _motes(at, p)
		"menhirs": _menhirs(at, float(p.get("r", 4.0)), int(p.get("n", 7)))
		"crates": _scatter(p, _crate)
		"diorama": return _diorama(at, String(p.kind))
		"pedestal": return _pedestal(at, Color(String(p.get("color", "#fff0c0"))))
		_: push_warning("Unknown prop type: %s" % p.t)
	return null

func _scatter(p: Dictionary, make: Callable) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.get("seed", 1))
	var a: Array = p.area
	for i in int(p.n):
		make.call(Vector3(rng.randf_range(a[0], a[0] + a[2]), 0, rng.randf_range(a[1], a[1] + a[3])), rng)

func _stone_mat(tint: Color = STONE) -> StandardMaterial3D:
	return kit._mat(TILE % "wall", Vector2(0.5, 0.5), true, tint)

func _wood_mat(tint: Color = Color(0.7, 0.56, 0.42)) -> StandardMaterial3D:
	return kit._mat(TILE % "bark", Vector2.ONE, true, tint)

func _wall(from: Vector3, to: Vector3, h: float, tint: Color) -> void:
	var mid := (from + to) * 0.5
	var size := Vector3(maxf(absf(to.x - from.x), 0.8), h, maxf(absf(to.z - from.z), 0.8))
	kit._box(size, _stone_mat(tint), mid + Vector3(0, h * 0.5, 0))

func _rock(at: Vector3, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(0.35, 0.9)
	kit._sphere(r, _stone_mat(Color(0.62, 0.6, 0.56)), at + Vector3(0, r * 0.3, 0), 0.7)
	kit._solid_cyl(r * 0.8, at)

func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = energy; l.omni_range = reach; l.position = at
	w.add_child(l); kit.holy_lights.append(l)

func _lamp(at: Vector3, color: Color) -> void:
	kit._box(Vector3(0.15, 3, 0.15), _wood_mat(Color(0.3, 0.3, 0.32)), at + Vector3(0, 1.5, 0))
	var lamp := OmniLight3D.new(); lamp.light_color = color; lamp.light_energy = 1.5; lamp.omni_range = 5.5; lamp.position = at + Vector3(0, 3.0, 0)
	w.add_child(lamp); kit.lamps.append(lamp)
	var halo := Sprite3D.new(); halo.texture = G.tex("res://assets/fx/glow.png"); halo.pixel_size = 0.03; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.shaded = false; halo.modulate = Color(color.r, color.g, color.b, 0.7); halo.position = at + Vector3(0, 3.05, 0); w.add_child(halo)

func _house(at: Vector3, width: float) -> void:
	kit._box(Vector3(width, 3.4, 4.5), _stone_mat(Color(0.8, 0.76, 0.74)), at + Vector3(0, 1.7, 0))
	var roof := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(width + 0.8, 2.0, 5.2); roof.mesh = pm
	roof.material_override = kit._mat(TILE % "roof", Vector2(0.6, 0.6), true, Color(0.75, 0.7, 0.72)); roof.position = at + Vector3(0, 4.4, 0); w.add_child(roof)

func _stepping_stone(at: Vector3) -> Node3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.1; cm.height = 0.16; cm.radial_segments = 10
	mi.mesh = cm; mi.material_override = _stone_mat(Color(0.92, 0.9, 0.82)); mi.position = at + Vector3(0, 0.1, 0); w.add_child(mi)
	return mi

func _gate(at: Vector3) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	for z in [-1.8, 1.8]:
		kit._box(Vector3(1.0, 4.2, 1.0), _stone_mat(), at + Vector3(0, 2.1, z))
	kit._box(Vector3(1.0, 0.9, 4.6), _stone_mat(), at + Vector3(0, 4.4, 0), false)
	kit._box(Vector3(0.2, 3.2, 2.6), _wood_mat(Color(0.55, 0.4, 0.28)), at + Vector3(0.1, 1.6, 0), false)
	return root

func _cross(at: Vector3) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	var wood := _wood_mat(Color(0.5, 0.38, 0.28))
	kit._box(Vector3(0.36, 5.0, 0.36), wood, at + Vector3(0, 3.0, 0))
	kit._box(Vector3(0.3, 0.34, 2.6), wood, at + Vector3(0, 4.2, 0), false)
	var halo := Sprite3D.new(); halo.texture = G.tex("res://assets/fx/glow.png"); halo.pixel_size = 0.13; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.shaded = false; halo.modulate = Color(1, 0.96, 0.78, 0.5); halo.position = at + Vector3(0, 4.0, 0); w.add_child(halo)
	kit.holy_lights.append(halo)
	return root

func _tomb(at: Vector3) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	kit._box(Vector3(4.2, 2.4, 3.0), _stone_mat(Color(0.7, 0.68, 0.64)), at + Vector3(0, 1.2, 0.6))
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.03, 0.03, 0.04); dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kit._box(Vector3(1.6, 1.6, 0.1), dark, at + Vector3(0, 0.8, -0.92), false)
	return root

func _arbour(at: Vector3) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	for off in [Vector3(-1.4, 0, -1), Vector3(1.4, 0, -1), Vector3(-1.4, 0, 1), Vector3(1.4, 0, 1)]:
		kit._box(Vector3(0.16, 2.4, 0.16), _wood_mat(), at + off + Vector3(0, 1.2, 0), false)
	# open beams, not a roof: the camera looks down, and a roof would hide the pilgrim resting beneath
	for z in [-1.0, 1.0]:
		kit._box(Vector3(3.2, 0.14, 0.14), _wood_mat(), at + Vector3(0, 2.45, z), false)
	kit._box(Vector3(3.0, 1.6, 0.3), kit._mat(TILE % "leaves", Vector2.ONE, true, Color(0.85, 1.0, 0.8)), at + Vector3(0, 0.8, -1.3), false)
	kit._box(Vector3(2.2, 0.42, 0.6), _wood_mat(), at + Vector3(0, 0.21, 0.6))
	return root

func _lion(at: Vector3, side: float) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	var body := _stone_mat(Color(0.62, 0.55, 0.45)); var mane := _stone_mat(Color(0.5, 0.4, 0.3))
	kit._box(Vector3(2.2, 1.1, 1.0), body, at + Vector3(0, 0.75, 0))
	kit._sphere(0.75, mane, at + Vector3(0.2, 1.45, -side * 0.9))
	kit._sphere(0.45, body, at + Vector3(0.2, 1.4, -side * 1.3))
	var chain := StandardMaterial3D.new(); chain.albedo_color = Color(0.3, 0.3, 0.34); chain.metallic = 0.6
	kit._box(Vector3(0.08, 0.08, 2.0), chain, at + Vector3(0, 1.2, side * 1.4), false)
	return root

# ------------------------------------------------------------------ scenery kit (terrain, fantasy dressing, atmosphere)
func _emissive(color: Color, energy: float = 1.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = energy
	return m

func _halo(at: Vector3, color: Color, size: float = 0.03, alpha: float = 0.6) -> Sprite3D:
	var h := Sprite3D.new(); h.texture = G.tex("res://assets/fx/glow.png"); h.pixel_size = size; h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	h.shaded = false; h.modulate = Color(color.r, color.g, color.b, alpha); h.position = at; w.add_child(h)
	return h

func _cyl(top: float, bottom: float, height: float, mat: Material, at: Vector3, sides: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = top; cm.bottom_radius = bottom; cm.height = height; cm.radial_segments = sides
	mi.mesh = cm; mi.material_override = mat; mi.position = at + Vector3(0, height * 0.5, 0); w.add_child(mi)
	return mi

## A broken line of rock masses along a map edge: reads as cliffs or far mountains. "rise" makes
## the line climb toward its end, which is how a flat map suggests a hill.
func _ridge(p: Dictionary, tint: Color) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.get("seed", 7))
	var a := World.v3(p.from); var b := World.v3(p.to)
	var n := int(p.get("n", 10))
	for i in n:
		var f := (i + 0.5) / n
		var h := float(p.h) * rng.randf_range(0.6, 1.25) * (1.0 + float(p.get("rise", 0.0)) * f)
		var size := Vector3(a.distance_to(b) / n * rng.randf_range(1.1, 1.5), h, float(p.get("depth", 5.0)) * rng.randf_range(0.8, 1.3))
		var box := kit._box(size, _stone_mat(tint.darkened(rng.randf_range(0.0, 0.25))), a.lerp(b, f) + Vector3(0, h * 0.5 - 0.3, 0), false)
		box.rotation.y = rng.randf_range(-0.25, 0.25)
		if p.get("cap", "") != "":   # snow, moss or grass on top
			kit._box(Vector3(size.x * 0.96, 0.3, size.z * 0.96), kit._mat(TILE % String(p.cap), Vector2.ONE, true, Color(String(p.get("cap_tint", "#ffffff")))), box.position + Vector3(0, h * 0.5, 0), false).rotation.y = box.rotation.y

func _pillars(p: Dictionary, tint: Color) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.get("seed", 3))
	for at in p.points:
		var h := float(p.get("h", 4.0)) * (rng.randf_range(0.35, 0.8) if p.get("ruined", false) and rng.randf() < 0.5 else 1.0)
		var pos := World.v3(at)
		_cyl(0.42, 0.5, h, _stone_mat(tint), pos, 10)
		kit._box(Vector3(1.3, 0.3, 1.3), _stone_mat(tint), pos + Vector3(0, 0.15, 0))
		if h >= float(p.get("h", 4.0)):
			kit._box(Vector3(1.3, 0.3, 1.3), _stone_mat(tint), pos + Vector3(0, h + 0.15, 0), false)

func _crystal(at: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	for i in rng.randi_range(2, 4):
		var h := rng.randf_range(0.6, 1.8)
		var c := _cyl(0.0, rng.randf_range(0.12, 0.26), h, _emissive(color, 1.6), at + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), 5)
		c.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
	_halo(at + Vector3(0, 0.8, 0), color, 0.035, 0.45)

func _mushroom(at: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	var h := rng.randf_range(0.5, 1.6)
	_cyl(h * 0.09, h * 0.13, h, _emissive(Color(0.92, 0.9, 0.82), 0.25), at, 7)
	var cap := kit._sphere(h * 0.45, _emissive(color, 0.9), at + Vector3(0, h, 0), 0.45)
	cap.rotation.z = rng.randf_range(-0.2, 0.2)
	_halo(at + Vector3(0, h + 0.1, 0), color, 0.02 + h * 0.012, 0.35)

func _bloom(at: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	var c := color.darkened(rng.randf_range(0.0, 0.25))
	kit._sphere(rng.randf_range(0.045, 0.085), _emissive(c, 0.25), at + Vector3(0, rng.randf_range(0.12, 0.28), 0), 0.8)

func _dead_tree(at: Vector3, rng: RandomNumberGenerator) -> void:
	var bark := _wood_mat(Color(0.3, 0.27, 0.26))
	var h := rng.randf_range(2.2, 4.0)
	_cyl(0.1, 0.24, h, bark, at, 6).rotation.z = rng.randf_range(-0.12, 0.12)
	for i in rng.randi_range(2, 4):
		var br := _cyl(0.02, 0.07, rng.randf_range(0.8, 1.6), bark, at + Vector3(0, h * rng.randf_range(0.5, 0.9), 0), 5)
		br.rotation = Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(0, TAU), rng.randf_range(0.5, 1.2))
	kit._solid_cyl(0.3, at)

func _spire(at: Vector3, rng: RandomNumberGenerator, tint: Color) -> void:
	var h := rng.randf_range(3.0, 8.0)
	_cyl(0.0, rng.randf_range(0.5, 1.1), h, _stone_mat(tint.darkened(0.3)), at, 6).rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0, TAU), rng.randf_range(-0.12, 0.12))
	kit._solid_cyl(0.6, at)

## A pair of small red lights in the dark: something is watching.
func _eyes(at: Vector3, rng: RandomNumberGenerator) -> void:
	var y := rng.randf_range(0.5, 1.6)
	for dx in [-0.11, 0.11]:
		var e := kit._sphere(0.045, _emissive(Color(1.0, 0.25, 0.15), 2.5), at + Vector3(dx, y, 0))
		kit.blinkers.append(e)

func _torch(at: Vector3, color: Color, lit: bool) -> Node3D:
	var post := _cyl(0.06, 0.08, 1.9, _wood_mat(Color(0.32, 0.25, 0.2)), at, 6)
	Fx.particles(w, at + Vector3(0, 2.0, 0), {"amount": 10, "life": 0.7, "one_shot": false, "explode": 0.0, "sphere": 0.08, "dir": Vector3.UP, "spread": 14.0,
		"vmin": 0.6, "vmax": 1.2, "gravity": Vector3(0, 0.6, 0), "color": color, "size": 0.2, "local": false})
	_halo(at + Vector3(0, 2.05, 0), color, 0.022, 0.75)
	if lit:
		var l := OmniLight3D.new(); l.light_color = color; l.light_energy = 1.4; l.omni_range = 5.0; l.position = at + Vector3(0, 2.2, 0); w.add_child(l)
	return post

func _banner(at: Vector3, color: Color) -> Node3D:
	var pole := _cyl(0.05, 0.06, 3.6, _wood_mat(Color(0.4, 0.32, 0.24)), at, 6)
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = color; cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flag := kit._box(Vector3(0.9, 1.6, 0.04), cloth, at + Vector3(0.5, 2.7, 0), false)
	kit._box(Vector3(0.5, 0.5, 0.05), _emissive(Color(1, 0.9, 0.6), 0.3), flag.position + Vector3(0, 0.2, 0.01), false)
	return pole

func _fence(a: Vector3, b: Vector3) -> void:
	var wood := _wood_mat(Color(0.5, 0.4, 0.3))
	var n := maxi(2, int(a.distance_to(b) / 1.6))
	for i in n + 1:
		_cyl(0.06, 0.07, 1.0, wood, a.lerp(b, float(i) / n), 5)
	var mid := (a + b) * 0.5
	var len_x := maxf(absf(b.x - a.x), 0.08); var len_z := maxf(absf(b.z - a.z), 0.08)
	for y in [0.45, 0.8]:
		kit._box(Vector3(len_x, 0.07, len_z), wood, mid + Vector3(0, y, 0), false)

func _bridge(at: Vector3, length: float) -> Node3D:
	var wood := _wood_mat(Color(0.56, 0.44, 0.32))
	var deck := kit._box(Vector3(length, 0.14, 2.6), wood, at + Vector3(0, 0.1, 0), false)
	for z in [-1.3, 1.3]:
		kit._box(Vector3(length, 0.08, 0.08), wood, at + Vector3(0, 0.9, z), false)
		for x in [-length * 0.5, 0.0, length * 0.5]:
			_cyl(0.06, 0.06, 0.9, wood, at + Vector3(x, 0, z), 5)
	return deck

## Shallow steps across the path: the ground stays level for walking, the eye reads a climb.
func _stairs(at: Vector3, steps: int, width: float, tint: Color) -> void:
	for i in steps:
		kit._box(Vector3(0.55, 0.05, width), _stone_mat(tint.lightened(0.04 * i)), at + Vector3(i * 0.6, 0.03, 0), false)

func _fog(p: Dictionary, tint: Color) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.get("seed", 5))
	var a: Array = p.area
	for i in int(p.get("n", 8)):
		var q := Sprite3D.new(); q.texture = G.tex("res://assets/fx/glow.png"); q.pixel_size = rng.randf_range(0.12, 0.22); q.rotation_degrees.x = -90
		q.shaded = false; q.modulate = Color(tint.r, tint.g, tint.b, float(p.get("alpha", 0.16)))
		q.position = Vector3(rng.randf_range(a[0], a[0] + a[2]), rng.randf_range(0.25, 0.7), rng.randf_range(a[1], a[1] + a[3])); w.add_child(q)
		kit.drifters.append([q, q.position, rng.randf_range(0.0, TAU)])

func _motes(at: Vector3, p: Dictionary) -> void:
	Fx.particles(w, at + Vector3(0, float(p.get("y", 1.2)), 0), {"amount": int(p.get("n", 24)), "life": 5.0, "one_shot": false, "explode": 0.0, "sphere": float(p.get("r", 8.0)),
		"dir": Vector3.UP, "spread": 60.0, "vmin": 0.1, "vmax": 0.4, "gravity": Vector3(0, float(p.get("rise", 0.05)), 0), "color": Color(String(p.color)), "size": float(p.get("size", 0.1)), "local": false})

## A ring of standing stones: an old, uneasy place.
func _menhirs(at: Vector3, radius: float, n: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = n * 13
	for i in n:
		var ang := TAU * i / n
		var pos := at + Vector3(cos(ang) * radius, 0, sin(ang) * radius)
		var h := rng.randf_range(1.6, 3.2)
		var s := kit._box(Vector3(0.9, h, 0.6), _stone_mat(Color(0.5, 0.5, 0.52)), pos + Vector3(0, h * 0.5, 0))
		s.rotation = Vector3(rng.randf_range(-0.1, 0.1), -ang, rng.randf_range(-0.12, 0.12))

func _crate(at: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.6, 0.95)
	if rng.randf() < 0.5:
		kit._box(Vector3(s, s, s), _wood_mat(Color(0.55, 0.43, 0.3)), at + Vector3(0, s * 0.5, 0)).rotation.y = rng.randf_range(0, 1.5)
	else:
		_cyl(s * 0.42, s * 0.42, s * 1.1, _wood_mat(Color(0.45, 0.33, 0.24)), at, 10); kit._solid_cyl(s * 0.45, at)

## The Interpreter's five pictures, each a small scene on a dais instead of a bare pedestal.
func _diorama(at: Vector3, kind: String) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	var back := at + Vector3(0, 0, -1.6)
	kit._box(Vector3(3.6, 0.2, 3.0), _stone_mat(Color(0.86, 0.82, 0.76)), at + Vector3(0, 0.1, -0.9), false)
	match kind:
		"picture":
			kit._box(Vector3(2.0, 2.6, 0.16), _wood_mat(Color(0.75, 0.6, 0.25)), back + Vector3(0, 1.7, 0), false)
			_billboard(back + Vector3(0, 0.55, 0.14), "../sprites/npc/evangelist", 2.0, Color.WHITE)
			_halo(back + Vector3(0, 3.2, 0.2), Color("fff0b0"), 0.03, 0.5)
		"parlor":
			kit._box(Vector3(3.0, 0.03, 2.2), _wood_mat(Color(0.5, 0.42, 0.34)), at + Vector3(0, 0.22, -0.9), false)
			_cyl(0.04, 0.04, 1.7, _wood_mat(), at + Vector3(0.9, 0.2, -1.2), 5).rotation.z = 0.5
			_motes(at + Vector3(0, 0, -0.9), {"color": "#c8b89a", "n": 16, "r": 1.4, "y": 0.9, "size": 0.14})
		"children":
			for x in [-0.8, 0.8]:
				kit._box(Vector3(0.7, 0.5, 0.7), _wood_mat(), at + Vector3(x, 0.45, -1.0)); kit._box(Vector3(0.7, 0.9, 0.12), _wood_mat(), at + Vector3(x, 1.0, -1.32), false)
			for i in 9:
				kit._sphere(0.09, _emissive(Color("ffd84a"), 0.9), at + Vector3(-0.8 + (i % 3) * 0.16 - 0.16, 0.26 + (i / 3) * 0.08, -0.35 + (i % 2) * 0.1))
		"fire":
			kit._box(Vector3(3.2, 2.4, 0.3), _stone_mat(Color(0.7, 0.66, 0.62)), back + Vector3(0, 1.4, 0))
			_torch(at + Vector3(0, -1.2, -1.1), Color("ff9a40"), true)
			Fx.particles(w, at + Vector3(0, 0.5, -1.1), {"amount": 26, "life": 0.9, "one_shot": false, "explode": 0.0, "sphere": 0.35, "dir": Vector3.UP, "spread": 18.0,
				"vmin": 1.0, "vmax": 2.2, "gravity": Vector3(0, 1.0, 0), "color": Color("ffb048"), "size": 0.3, "local": false})
		"armed":
			for x in [-1.2, 1.2]:
				_cyl(0.3, 0.34, 3.0, _stone_mat(), back + Vector3(x, 0.2, 0), 10)
			kit._box(Vector3(3.0, 0.5, 0.7), _stone_mat(), back + Vector3(0, 3.4, 0), false)
			kit._box(Vector3(1.9, 2.9, 0.1), _emissive(Color("ffe9a8"), 0.9), back + Vector3(0, 1.65, -0.1), false)
			_halo(back + Vector3(0, 1.8, 0.2), Color("ffe9a8"), 0.06, 0.45)
	return root

## A cleaned picture from assets/props standing upright as scenery, h world units tall.
func _billboard(at: Vector3, art: String, h: float, tint: Color = Color.WHITE) -> Node3D:
	var sp := Sprite3D.new(); sp.texture = G.tex("res://assets/props/%s.png" % art)
	sp.pixel_size = h / float(sp.texture.get_height()); sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.modulate = tint; sp.shaded = false
	sp.position = at + Vector3(0, h * 0.5, 0); w.add_child(sp)
	return sp

func _pedestal(at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	kit._box(Vector3(1.2, 0.9, 1.2), _stone_mat(), at + Vector3(0, 0.45, 0))
	var gem := StandardMaterial3D.new(); gem.albedo_color = color; gem.emission_enabled = true; gem.emission = color; gem.emission_energy_multiplier = 1.2
	var orb := kit._sphere(0.3, gem, at + Vector3(0, 1.35, 0))
	kit.bobbers.append(orb)
	_light(at + Vector3(0, 1.8, 0), color, 1.2, 3.5)
	return root

# ------------------------------------------------------------------ entities
func _ent(e: Dictionary) -> void:
	var at := World.v3(e.at)
	var node: Node3D = null
	match String(e.kind):
		"npc":
			var color := Color(String(e.get("color", "#9fd8ff")))
			var actor: SpriteActor = kit.standee(String(e.standee), e.name, color) if e.has("standee") else kit._pilgrim_actor(e.look, e.name, color, false)
			actor.position = at
			if e.get("glow", false):
				actor.set_tint(Color(1.5, 1.45, 1.2))
			node = actor
		"spot":
			if e.has("prop"):
				node = prop(e.prop, at)
		"light":   # a figure of light: no face or form is drawn
			node = Node3D.new(); node.position = at; w.add_child(node)
			# children of the entity's node, so they appear and vanish with it
			for part in [Fx.shaft(w, at, 5.0, 1.0), _halo(at + Vector3(0, 1.3, 0), Color("fff6d8"), 0.05, 0.8), kit._label3d(String(e.name), at + Vector3(0, 2.7, 0), Color("fff2c0"), 40)]:
				part.reparent(node)
		"page":
			node = _glint(at)
		"warp":
			node = kit.warp(at)
	var made := w._add_ent(e.id, e.name, at, node, e.act, e.icon, Callable(), e.get("hidden", false))
	if e.has("ui"):   # a vendor or bench: opens a HUD window
		var ui: String = e.ui
		made.fn = func() -> void: w.hud.call(ui)
	for k in ["dialog", "follow"]:
		if e.has(k):
			made[k] = e[k]
	if e.kind == "page":
		made["kind"] = "secret"   # glints like a secret as the player comes near

func _glint(at: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = at; w.add_child(n)
	var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/star.png"); g.pixel_size = 0.004; g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.shaded = false; g.transparent = true; g.modulate = Color(1, 0.97, 0.8, 0.0); g.position.y = 0.55; n.add_child(g)
	n.set_meta("glint", g)
	return n
