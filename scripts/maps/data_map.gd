class_name DataMap
extends RefCounted
## Builds a map from its JSON definition (data/maps/<id>.json): ground, props, entities.
## Maps with hand-built geometry (scripts/maps/<id>.gd) still get their JSON props and entities
## added on top, so new characters and pages are data too. See README "Adding a chapter".

const DEFAULT_BOUNDS := [-24, -14, 48, 28]

var w: World
var kit: MapKit

func _init(world: World) -> void:
	w = world; kit = world.kit

# ------------------------------------------------------------------ whole-map build (no bespoke script)
func build() -> void:
	var look: Dictionary = w.def.look
	var b: Array = w.def.get("bounds", DEFAULT_BOUNDS)
	w.bounds = Rect2(b[0], b[1], b[2], b[3])
	kit.ground(String(look.ground), String(look.get("ground_b", "")), float(look.get("ground_share", 0.42)))
	kit._walls()
	kit._edge_fade(Color(String(look.bg)))
	match String(look.get("weather", "")):
		"drizzle": kit._weather_drizzle()
		"petals": kit._weather_petals()

## Props and entities from data; runs for every map.
func populate() -> void:
	var look: Dictionary = w.def.look
	kit.flora = String(look.get("flora", "green")); kit.rock_kind = String(look.get("rock", "stone"))
	for p in w.def.get("props", []):
		prop(p, World.v3(p.get("at", [0, 0])))
	for e in w.def.get("ents", []):
		_ent(e)
	for s in w.def.get("secrets", []):
		w.quests._add_secret(String(s.id), World.v3(s.at), String(s.title), String(s.text), s.get("reward", {}))
	if look.get("scatter", true):
		kit.scatter(hash(w.map_id), int(look.get("tufts", 80)), int(look.get("patches", 22)), int(look.get("flowers", 10)))

# ------------------------------------------------------------------ props
## Colours in map data choose among the drawn variants; nothing is recoloured at run time.
const CLOTH := {"cloth_red": Color("b33a35"), "cloth_blue": Color("2f4f8f"), "night": Color("57407a"), "gold": Color("e8b83e"), "leaf": Color("4f8a45")}
const GEM := {"night": Color("9a7cc4"), "cloth_red": Color("e0704a"), "water": Color("9fd3e8"), "gold": Color("fbe58a"), "leaf": Color("8cb84f")}
const BLOOM := {"gold": Color("fbe58a"), "cloth_red": Color("e0704a"), "night": Color("9a7cc4"), "stone": Color("f4efe4"), "cloth_blue": Color("4f8fc7")}

static func nearest(c: Color, table: Dictionary) -> String:
	var best := ""; var bd := 9.0
	for k in table:
		var t: Color = table[k]
		var d := Vector3(c.r - t.r, c.g - t.g, c.b - t.b).length()
		if d < bd:
			bd = d; best = k
	return best

func prop(p: Dictionary, at: Vector3) -> Node3D:
	var tint := Color(String(p.get("tint", "#ffffff")))
	match String(p.t):
		"path": return kit.path(Vector2(p.size[0], p.size[1]), kit.tile_path(String(p.tile), tint).get_file().get_basename(), at + Vector3(0, float(p.get("y", 0.012)), 0), float(p.get("ragged", 0.4)))
		"water": kit._water(Vector2(p.size[0], p.size[1]), at + Vector3(0, float(p.get("y", 0.03)), 0), tint); kit.path_rects.append(Rect2(at.x - p.size[0] * 0.5, at.z - p.size[1] * 0.5, p.size[0], p.size[1]))
		"box":
			var size := Vector3(p.size[0], p.size[1], p.size[2])
			return kit._box(size, kit._mat(String(p.tile), Vector2.ONE, true, tint), at + Vector3(0, size.y * 0.5, 0), p.get("solid", true))
		"wall": _wall(World.v3(p.from), World.v3(p.to), float(p.h), tint)
		"tree": return kit._tree(at, float(p.get("s", 1.1)))
		"trees": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit._tree(pos, rng.randf_range(0.9, 1.3)))
		"woods": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.art("forest_edge", pos, {"flip": rng.randf() < 0.5}); kit._solid_cyl(1.4, pos))
		"bushes": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.prop("bush_%s" % kit.flora, pos, {"flip": rng.randf() < 0.5}))
		"reeds": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.prop("reeds", pos, {"flip": rng.randf() < 0.5}))
		"rocks": _scatter(p, _rock)
		"lamp": kit.lamp(at, Color(String(p.get("color", "#ffb060"))))
		"light": _light(at + Vector3(0, float(p.get("y", 3.0)), 0), Color(String(p.color)), float(p.e), float(p.range))
		"shaft": Fx.shaft(w, at, 10.0, 2.4, 0.18)
		"house": return kit.prop("house_%s" % String(p.get("kind", "abc"[int(absf(at.x)) % 3])), at, {"flip": p.get("flip", false)})
		"stone": return kit.prop("stepping_stone", at, {"y": 0.06})
		"gate": return _gate(at)
		"cross": return _cross(at)
		"tomb": return kit.prop("tomb", at)
		"arbour": return kit.prop("arbour", at + Vector3(0, 0, -1.0))
		"lion": return kit.lion(at, float(p.get("side", 1)) < 0.0)
		"billboard":
			if String(p.art).begins_with("bd_"):
				kit.backdrop(String(p.art).trim_prefix("bd_"), at, float(p.get("h", 13.0)))
			else:
				return kit.art(String(p.art), at)
		"art": return kit.art(String(p.art), at, {"flip": p.get("flip", false)})
		"kit": return kit.prop(String(p.name), at, {"flip": p.get("flip", false)})
		"ridge": kit.cliffs(World.v3(p.from), World.v3(p.to), float(p.h), int(p.get("seed", 7)), String(p.get("cap", "")), float(p.get("rise", 0.0)))
		"terrace": return kit._box(Vector3(p.size[0], float(p.h), p.size[1]), kit._mat(String(p.get("tile", "grass")), Vector2.ONE, true, tint), at + Vector3(0, float(p.h) * 0.5, 0))
		"pillars": _pillars(p)
		"crystals": _scatter(p, func(pos: Vector3, _rng: RandomNumberGenerator) -> void: _crystal(pos, Color(String(p.get("color", "#9fd8ff")))))
		"mushrooms": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: _mushroom(pos, rng, Color(String(p.get("color", "#ffb0e0")))))
		"blooms": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.prop("flowers_%s" % nearest(Color(String(p.get("color", "#fff0a0"))), BLOOM), pos, {"flip": rng.randf() < 0.5}))
		"dead_trees": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.prop("dead_tree_%s" % "abc"[rng.randi() % 3], pos, {"flip": rng.randf() < 0.5}))
		"spires": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.prop(["spire_a", "spire_b", "spire_stone" if kit.rock_kind != "dark" else "spire_a"][rng.randi() % 3], pos, {"flip": rng.randf() < 0.5}))
		"eyes": _scatter(p, _eyes)
		"torch": return _torch(at, Color(String(p.get("color", "#ffb050"))), p.get("light", false))
		"banner": return kit.prop("banner_%s" % nearest(Color(String(p.get("color", "#b03030"))), CLOTH), at)
		"fence": _fence(World.v3(p.from), World.v3(p.to))
		"bridge": return _bridge(at, float(p.get("len", 6.0)))
		"stairs": _stairs(at, int(p.get("steps", 4)), float(p.get("w", 4.0)))
		"fog": _fog(p, tint)
		"motes": _motes(at, p)
		"menhirs": _menhirs(at, float(p.get("r", 4.0)), int(p.get("n", 7)))
		"crates": _scatter(p, func(pos: Vector3, rng: RandomNumberGenerator) -> void: kit.prop("crate" if rng.randf() < 0.5 else "barrel", pos))
		"diorama": return _diorama(at, String(p.kind))
		"pedestal": return _pedestal(at, Color(String(p.get("color", "#fff0c0"))))
		_: push_warning("Unknown prop type: %s" % p.t)
	return null

func _scatter(p: Dictionary, make: Callable) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.get("seed", 1))
	var a: Array = p.area
	for i in int(p.n):
		make.call(Vector3(rng.randf_range(a[0], a[0] + a[2]), 0, rng.randf_range(a[1], a[1] + a[3])), rng)

## Walls are the one thing still built as a solid: a billboard cannot enclose a room.
func _wall(from: Vector3, to: Vector3, h: float, tint: Color) -> void:
	var mid := (from + to) * 0.5
	var size := Vector3(maxf(absf(to.x - from.x), 0.8), h, maxf(absf(to.z - from.z), 0.8))
	kit._box(size, kit._mat("wall", Vector2.ONE, true, tint), mid + Vector3(0, h * 0.5, 0))

func _rock(at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.prop("rock_dark" if kit.rock_kind == "dark" else ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], at, {"flip": rng.randf() < 0.5})

func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = energy; l.omni_range = reach; l.position = at
	w.add_child(l); kit.holy_lights.append(l)

func _gate(at: Vector3) -> Node3D:
	var sp := kit.art("wicket_gate", at)
	# shut until the story opens it (an objective's "open_gate" effect), then it never bars the road again
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(1.0, 3.0, 4.6)
	cs.shape = sh; sb.add_child(cs); sb.position = at + Vector3(0, 1.5, 0); w.add_child(sb)
	w.gates.append(cs)
	return sp

## The Cross stands empty. No figure is drawn on it or near it.
func _cross(at: Vector3) -> Node3D:
	var sp := kit.prop("cross", at)
	kit.holy_lights.append(kit.halo(at + Vector3(0, 4.0, 0), Color(1, 0.96, 0.78), 0.13, 0.5))
	return sp

func _pillars(p: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(p.get("seed", 3))
	for at in p.points:
		kit.prop(["pillar_broken_a", "pillar_broken_b"][rng.randi() % 2] if p.get("ruined", false) and rng.randf() < 0.5 else "pillar", World.v3(at))

func _crystal(at: Vector3, color: Color) -> void:
	var c := nearest(color, GEM)
	kit.prop("crystal_%s" % c, at)
	kit.halo(at + Vector3(0, 0.8, 0), GEM[c], 0.035, 0.4)

func _mushroom(at: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	var c := nearest(color, GEM)
	kit.prop("mushroom_%s" % c, at, {"flip": rng.randf() < 0.5})
	kit.halo(at + Vector3(0, 1.1, 0), GEM[c], 0.026, 0.3)

## A pair of small red lights in the dark: something is watching.
func _eyes(at: Vector3, rng: RandomNumberGenerator) -> void:
	var e := kit.prop("eyes", at + Vector3(0, rng.randf_range(0.4, 1.4), 0))
	kit.blinkers.append(e)

func _torch(at: Vector3, color: Color, lit: bool) -> Node3D:
	var post := kit.prop("torch", at)
	kit.halo(at + Vector3(0, 1.8, 0), color, 0.022, 0.6)
	if lit:
		var l := OmniLight3D.new(); l.light_color = color; l.light_energy = 1.4; l.omni_range = 5.0; l.position = at + Vector3(0, 2.2, 0); w.add_child(l)
		kit.lamps.append(l)
	return post

## Fence rails stand along their line (a fixed plane, not a billboard), so a row reads as one fence.
func _fence(a: Vector3, b: Vector3) -> void:
	var seg := 1.6
	var n := maxi(1, int(round(a.distance_to(b) / seg)))
	var yaw := atan2(-(b.z - a.z), b.x - a.x)
	for i in n:
		kit.prop("fence", a.lerp(b, (i + 0.5) / n), {"yaw": yaw})

func _bridge(at: Vector3, length: float) -> Node3D:
	var deck := kit._box(Vector3(length, 0.14, 2.6), kit._mat("plank"), at + Vector3(0, 0.1, 0), false)
	for z in [-1.3, 1.3]:
		_fence(at + Vector3(-length * 0.5, 0.1, z), at + Vector3(length * 0.5, 0.1, z))
	return deck

## Shallow steps across the path: the ground stays level for walking, the eye reads a climb.
func _stairs(at: Vector3, steps: int, width: float) -> void:
	for i in steps:
		kit._box(Vector3(0.55, 0.06 + 0.012 * i, width), kit._mat("cobble" if i % 2 == 0 else "wall"), at + Vector3(i * 0.6, 0.03, 0), false)

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
	for i in n:
		var ang := TAU * i / n
		kit.prop("menhir_%s" % "abc"[i % 3], at + Vector3(cos(ang) * radius, 0, sin(ang) * radius), {"flip": i % 2 == 0})

## The Interpreter's five pictures, each a small scene on a dais.
func _diorama(at: Vector3, kind: String) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	var back := at + Vector3(0, 0, -1.6)
	kit._box(Vector3(3.6, 0.2, 3.0), kit._mat("cobble"), at + Vector3(0, 0.1, -0.9), false)
	match kind:
		"picture":
			kit.prop("picture", back + Vector3(0, 0.6, 0))
			kit.halo(back + Vector3(0, 2.4, 0.2), Color("fff0b0"), 0.03, 0.5)
		"parlor":
			kit.prop("broom", at + Vector3(0.6, 0.2, -1.0))
			_motes(at + Vector3(0, 0, -0.9), {"color": "#c8b89a", "n": 16, "r": 1.4, "y": 0.9, "size": 0.14})
		"children":
			kit.prop("chairs", at + Vector3(0, 0.2, -1.2))
			kit.prop("coins", at + Vector3(-0.8, 0.2, -0.5))
		"fire":
			kit.prop("hearth", back + Vector3(0, 0.2, 0.2))
			_light(at + Vector3(0, 1.2, -0.8), Color("ff9a40"), 1.6, 4.5)
		"armed":
			kit.prop("armed", back + Vector3(0, 0.2, 0.2))
			kit.halo(back + Vector3(0, 1.0, 0.4), Color("ffe9a8"), 0.06, 0.45)
	return root

func _pedestal(at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new(); root.position = at; w.add_child(root)
	kit.prop("pedestal", at)
	var orb := kit.halo(at + Vector3(0, 1.45, 0), color, 0.014, 0.95)
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
			for part in [Fx.shaft(w, at, 5.0, 1.0), kit.halo(at + Vector3(0, 1.3, 0), Color("fff6d8"), 0.05, 0.8), kit._label3d(String(e.name), at + Vector3(0, 2.7, 0), Color("fff2c0"), 40)]:
				part.reparent(node)
		"page":
			node = _glint(at)
		"warp":
			node = kit.warp(at)
		"milestone":   # a town's fast-travel stone: a pillar from the kit under a steady light
			node = Node3D.new(); node.position = at; w.add_child(node)
			for part in [kit.prop("pillar", at), kit.halo(at + Vector3(0, 3.3, 0), Color("fbe58a"), 0.03, 0.7), kit._label3d("Milestone", at + Vector3(0, 4.1, 0), Color("fbe58a"), 30)]:
				part.reparent(node)
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
