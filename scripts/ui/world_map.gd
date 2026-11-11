class_name WorldMap
extends Control
## The world map: every place the pilgrim has stood on, the roads between them, and a "?" for each
## place a known road leads to. Drag to move the map; tap a place to choose it. Drawn from
## data/world.json (each node's "map": [column, row]).

signal picked(map_id: String)

const CELL := Vector2(118, 84)     # px between neighbours
const BOX := Vector2(104, 58)
const KIND_COLOR := {"town": "e8b83e", "field": "8cb84f", "danger": "b33a35", "story": "4f6fa8", "instance": "6a5a8a"}
const TAP_SLOP := 12.0

var here := ""                     # the map the pilgrim is on
var chosen := ""
var pan := Vector2.ZERO
var _press := Vector2.ZERO
var _moved := 0.0
var _down := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void: center_on(chosen if chosen != "" else here))

func known(id: String) -> bool:
	return id in G.visited

## A place not yet walked is shown (as "?") when a walked place has a road to it.
func hinted(id: String) -> bool:
	for e in Portals.graph().edges:
		if e.to == id and known(String(e.from)) and e.kind != "story":
			return true
	return false

func _at(id: String) -> Vector2:
	var m: Array = Portals.node(id).map
	return Vector2(float(m[0]), float(m[1])) * CELL + pan

func center_on(id: String) -> void:
	if id == "":
		return
	pan = Vector2.ZERO
	pan = size * 0.5 - _at(id)
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true; _press = e.position; _moved = 0.0
		elif _down:
			_down = false
			if _moved < TAP_SLOP:
				_tap(e.position)
	elif e is InputEventMouseMotion and _down:
		_moved += e.relative.length()
		pan += e.relative
		queue_redraw()

func _tap(at: Vector2) -> void:
	for id in Portals.graph().nodes.keys():
		if (known(id) or hinted(id)) and Rect2(_at(id) - BOX * 0.5, BOX).has_point(at):
			chosen = id; queue_redraw(); picked.emit(id)
			return

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a2832"))
	var nodes: Dictionary = Portals.graph().nodes
	var drawn := {}
	for e in Portals.graph().edges:   # roads
		var a := String(e.from); var b := String(e.to)
		if drawn.has(b + ">" + a) or not ((known(a) or hinted(a)) and (known(b) or hinted(b))) or not (known(a) or known(b)):
			continue
		drawn[a + ">" + b] = true
		var both: bool = known(a) and known(b)
		draw_line(_at(a), _at(b), Color("c79a5e") if both else Color(0.78, 0.6, 0.37, 0.4), 5.0 if both else 3.0)
	var f: Font = G.font_ui_bold
	for id in nodes.keys():
		var n: Dictionary = nodes[id]
		if not (known(id) or hinted(id)):
			continue
		var r := Rect2(_at(id) - BOX * 0.5, BOX)
		if not Rect2(Vector2.ZERO, size).intersects(r):
			continue
		var col := Color(String(KIND_COLOR.get(n.kind, "4f6fa8")))
		if not known(id):
			draw_rect(r, Color("3a3840")); draw_rect(r, Color("625e68"), false, 2.0)
			_text(f, r, "?", 26, Color("918a7e"), 0)
			continue
		draw_rect(r, col.darkened(0.55)); draw_rect(r, col, false, 3.0)
		if id == chosen:
			draw_rect(r.grow(4), Color("fbe58a"), false, 3.0)
		var name: String = String(G.data("maps/" + String(id)).name).trim_prefix("The ")
		_text(f, r, name, 13, Color("f4efe4"), -9)
		var sub := "Town" if n.kind == "town" else "Lv %d-%d" % [int(n.level[0]), int(n.level[1])]
		_text(f, r, sub, 13, Combat.con_color(int(n.level[0]), G.lvl) if n.kind in ["field", "danger"] else col.lightened(0.3), 16)
		if id == here:
			var top := r.position + Vector2(r.size.x * 0.5, -6)
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(-9, -14), top + Vector2(9, -14)]), Color.WHITE)
		if n.kind == "town" and id in G.milestones:
			draw_circle(r.position + Vector2(r.size.x - 8, 8), 5, Color("fbe58a"))

func _text(f: Font, r: Rect2, s: String, px: int, col: Color, dy: float) -> void:
	var lines: Array = [s]
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > r.size.x - 8 and " " in s:   # two lines for a long name
		var words := s.split(" "); var half := int(ceil(words.size() / 2.0))
		lines = [" ".join(words.slice(0, half)), " ".join(words.slice(half))]
		dy -= 7
	for i in lines.size():
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, Vector2(r.position.x + (r.size.x - minf(w, r.size.x - 4)) * 0.5, r.position.y + r.size.y * 0.5 + dy + i * (px + 1) + px * 0.35), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, px, col)
