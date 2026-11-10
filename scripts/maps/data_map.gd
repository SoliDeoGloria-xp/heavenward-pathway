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
		"page":
			node = _glint(at)
		"warp":
			node = kit.warp(at)
	var made := w._add_ent(e.id, e.name, at, node, e.act, e.icon, Callable(), e.get("hidden", false))
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
