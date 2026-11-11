class_name Portals
extends RefCounted
## The world graph (data/world.json) and the portals that join one map to the next.
## A road that can be walked both ways is two edges. Edge kinds:
##   portal  walk into the glow                     door  use an entity (the Palace's yard, gate, board)
##   exit    the map's own exit objective           story a scripted scene change (Eden's Fall)
## A forward portal opens when its map's story is done (flag done_<map>); until then the map's exit
## objective makes the same trip, so the story is told once and the road stays open afterwards.

const TRIGGER := 1.3               # stepping this close to an open portal takes the road
const ARM_DIST := 1.9              # a portal you arrive on top of wakes only after you step this far away
const LABEL_HEIGHT := 3.5
const BACK_SCALE := 0.72           # the way back is a smaller glow than the way on

var w: World
var list: Array = []               # [{edge, pos, node, armed}]

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ the graph (static: screens and tests use it too)
static func graph() -> Dictionary:
	return G.data("world")

static func node(map_id: String) -> Dictionary:
	return graph().nodes.get(map_id, {})

static func edges_from(map_id: String) -> Array:
	return graph().edges.filter(func(e: Dictionary) -> bool: return e.from == map_id)

static func edge(from: String, to: String) -> Dictionary:
	for e in graph().edges:
		if e.from == from and e.to == to:
			return e
	return {}

## Whether the pilgrim may take this edge now.
static func open(e: Dictionary) -> bool:
	if e.get("forward", false) and not G.flags.has("done_" + String(e.from)):
		return false
	return not e.has("needs") or G.flags.has(e.needs)

## Change maps along an edge (or to a map's own start when there is no edge).
static func go(from: String, to: String) -> void:
	var e := edge(from, to)
	var data := {"map": to}
	if e.has("arrive"):
		data["at"] = e.arrive
	G.goto("world", data)

static func label(e: Dictionary) -> String:
	var place := String(G.data("maps/" + String(e.to)).name)
	var text := "To %s" % (("the " + place.substr(4)) if place.begins_with("The ") else place)
	var n := node(String(e.to))
	if n.get("kind", "") in ["field", "danger"]:   # a sign at the road: who this place suits
		text += "\nLv %d-%d" % [int(n.level[0]), int(n.level[1])]
	return text

# ------------------------------------------------------------------ this map's portals
func build() -> void:
	for e in edges_from(w.map_id):
		match String(e.kind):
			"portal": _portal(e)
			"door": _door(e)

func _portal(e: Dictionary) -> void:
	var pos := World.v3(e.at)
	var made: Dictionary = w.ent(String(e.get("ent", "")))
	var n: Node3D
	if made.is_empty():
		n = w.kit.warp(pos)
		n.scale = Vector3.ONE * BACK_SCALE
		made = w._add_ent("portal_" + String(e.to), label(e), pos, n, "Enter", "warp", Callable(), not open(e))
	else:   # the story's own shining light at the exit: it becomes the road onward
		n = made.node
		made.name = label(e)
		if open(e):
			w.show_ent(made.id, true)
	made["kind"] = "portal"
	made.fn = _take.bind(e)
	var sign := w.kit._label3d(label(e), pos + Vector3(0, LABEL_HEIGHT, 0), Color("fbe58a"), 30)
	var dest := node(String(e.to))
	if dest.get("kind", "") in ["field", "danger"]:
		sign.modulate = Combat.con_color(int(dest.level[0]), G.lvl).lerp(Color("fbe58a"), 0.35)
	sign.reparent(n)
	list.append({"edge": e, "pos": pos, "ent": made, "armed": _far(pos), "own": not e.has("ent")})

## A place in a House that leads to a side map (the yard, the gate, the board), once its story is done.
func _door(e: Dictionary) -> void:
	var made: Dictionary = w.ent(String(e.ent))
	if made.is_empty():
		push_warning("World graph: %s has no entity '%s'" % [w.map_id, e.ent]); return
	var old: Callable = made.fn
	made["kind"] = "door"
	made.fn = func() -> void:
		if open(e):
			_take(e)
		elif old.is_valid():
			old.call()

func _far(pos: Vector3) -> bool:
	return Vector2(w.player.position.x - pos.x, w.player.position.z - pos.z).length() > ARM_DIST

func tick() -> void:
	if w.ending:
		return
	for p in list:
		if p.own and p.ent.hidden and open(p.edge):   # a road the story has just opened
			w.show_ent(p.ent.id, true)
		if not open(p.edge) or p.ent.hidden:
			continue
		if not p.armed:
			p.armed = _far(p.pos)
		elif Vector2(w.player.position.x - p.pos.x, w.player.position.z - p.pos.z).length() < TRIGGER:
			_take(p.edge)
			return

func _take(e: Dictionary) -> void:
	if w.ending or not open(e):
		return
	w.ending = true; G.sfx("warp")
	G.save_game()
	go(String(e.from), String(e.to))

## The open ways out of this map, for the HUD and the tests: [{edge, pos}].
func ways() -> Array:
	return list.filter(func(p: Dictionary) -> bool: return open(p.edge) and not p.ent.hidden)
