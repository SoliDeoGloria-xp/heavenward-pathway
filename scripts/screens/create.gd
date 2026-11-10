extends Control
## RO-style Make Character, staged in the Eden glade: turntable sprite, hair style/colour arrows,
## robe colour swatches, the six-attribute hexagon (all pilgrims begin equal), name check.

var preview: TextureRect
var atlas: AtlasTexture
var name_edit: LineEdit
var msg: Label
var hair_lbl: Label
var swatch_row: HBoxContainer
var hair_swatch: ColorRect
var turn := 0.0

func _ready() -> void:
	UIKit.full_rect(self); theme = G.theme
	var bg := Glade.new(); add_child(UIKit.pixelate(bg))
	var root := BoxContainer.new(); root.vertical = G.portrait; UIKit.full_rect(root)
	root.add_theme_constant_override("separation", 30)
	var edge := 16.0 if G.portrait else 50.0
	root.offset_left = edge; root.offset_right = -edge; root.offset_top = 40; root.offset_bottom = -40
	add_child(root)
	# --- left: stage
	var lw := UIKit.window("Make character", Vector2(520, 0))
	lw.root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lb: VBoxContainer = lw.body
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/parchment.png", 5, 6))
	stage.custom_minimum_size = Vector2(0, 330)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	atlas = AtlasTexture.new()
	preview = TextureRect.new(); preview.texture = atlas
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage.add_child(preview)
	lb.add_child(stage)
	lb.add_child(_arrow_row("Look", func(): _hair_style(-1), func(): _hair_style(1), true))
	root.add_child(lw.root)
	# --- right: details
	var rw := UIKit.window("Pilgrim", Vector2(0, 0))
	rw.root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rw.root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rb: VBoxContainer = rw.body
	rb.add_child(UIKit.label("Name", 22, UIKit.BLUE_INK, true))
	name_edit = LineEdit.new(); name_edit.placeholder_text = "e.g. Steadfast"; name_edit.max_length = 16
	name_edit.text = G.pname if G.pname != "Pilgrim" else ""
	name_edit.custom_minimum_size = Vector2(0, 58)
	rb.add_child(name_edit)
	msg = UIKit.label("3 to 16 letters. Divine names are reserved.", 18, UIKit.SUB)
	rb.add_child(msg)
	swatch_row = HBoxContainer.new()   # robe colours belonged to the old paper-doll; looks are whole pictures now
	var hx := HBoxContainer.new(); hx.add_theme_constant_override("separation", 18)
	var hex := Hexagon.new(); hex.custom_minimum_size = Vector2(190, 190)
	hx.add_child(hex)
	var note := UIKit.label("All pilgrims begin equal. You gain 2 attribute points every Base Level and shape your pilgrim as you go.\n\nAn image-bearer, in a garden unfallen.", 19, UIKit.SUB, false, true)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hx.add_child(note)
	rb.add_child(hx)
	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; rb.add_child(sp)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIKit.button("Make", _make, 200, true))
	rb.add_child(row)
	root.add_child(rw.root)
	_rebuild()

func _arrow_row(title: String, prev: Callable, next: Callable, style: bool) -> HBoxContainer:
	var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 10)
	var l := UIKit.label(title, 21, UIKit.BLUE_INK, true); l.custom_minimum_size = Vector2(150, 0)
	r.add_child(l)
	r.add_child(UIKit.button("◀", prev, 64))
	if style:
		hair_lbl = UIKit.label("1 / 3", 22); hair_lbl.custom_minimum_size = Vector2(90, 0)
		hair_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(hair_lbl)
	else:
		hair_swatch = ColorRect.new(); hair_swatch.custom_minimum_size = Vector2(90, 34)
		var cc := CenterContainer.new(); cc.add_child(hair_swatch); cc.custom_minimum_size = Vector2(90, 0)
		r.add_child(cc)
	r.add_child(UIKit.button("▶", next, 64))
	return r

func _swatches() -> void:
	for c in swatch_row.get_children():
		c.queue_free()
	for i in G.ROBES.size():
		var b := Button.new(); b.custom_minimum_size = Vector2(62, 62); b.focus_mode = Control.FOCUS_NONE
		var s := StyleBoxFlat.new(); s.bg_color = G.ROBES[i]
		s.set_corner_radius_all(0); s.set_border_width_all(5 if i == G.robe_col else 2)
		s.border_color = Color("1f2a52") if i == G.robe_col else Color("9fd3e8")
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, s)
		var idx := i
		b.pressed.connect(func(): G.robe_col = idx; _swatches(); _rebuild())
		swatch_row.add_child(b)

func _hair_style(d: int) -> void:
	G.hair_style = (G.hair_style + d + G.PILGRIM_LOOKS.size()) % G.PILGRIM_LOOKS.size(); _rebuild()

func _hair_col(d: int) -> void:
	G.hair_col = (G.hair_col + d + G.HAIRS.size()) % G.HAIRS.size(); _rebuild()

func _rebuild() -> void:
	atlas.atlas = G.build_player_sheet()
	hair_lbl.text = "%d / %d" % [G.hair_style + 1, G.PILGRIM_LOOKS.size()]

func _process(delta: float) -> void:
	turn += delta
	var dir8 := int(turn / 0.9) % 8
	var rows := [0, 1, 2, 3, 4, 3, 2, 1]
	var flip := dir8 >= 5
	var walk := 1 + int(turn * 6.0) % 4
	atlas.region = Rect2(Vector2(walk, rows[dir8]) * G.PLAYER_CELL, G.PLAYER_CELL)
	preview.flip_h = flip

func _make() -> void:
	var err := G.name_ok(name_edit.text)
	if err != "":
		msg.text = err; msg.add_theme_color_override("font_color", Color("b33a35")); return
	G.pname = name_edit.text.strip_edges()
	G.reset()
	G.goto("story", {"id": "dream"})


class Glade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x; var h := size.y
		for i in 40:
			var f := float(i) / 39.0
			draw_rect(Rect2(0, h * f, w, h / 39.0 + 1), Color("f4efe4").lerp(Color("4f8a45"), f))
		for i in 9:
			draw_circle(Vector2(w * (0.05 + i * 0.12), h * 0.12 + (i % 2) * 40), 120, Color(0.35, 0.6, 0.3, 0.25))


class Hexagon extends Control:
	const NAMES := ["FOR", "DIL", "STE", "WIS", "SOB", "HOP"]
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.36
		var outer := PackedVector2Array(); var inner := PackedVector2Array()
		for i in 6:
			var a := -PI * 0.5 + i * PI / 3.0
			outer.append(c + Vector2(cos(a), sin(a)) * r)
			inner.append(c + Vector2(cos(a), sin(a)) * r * 0.25)
		draw_colored_polygon(outer, Color("f4efe4"))
		outer.append(outer[0]); draw_polyline(outer, Color("625e68"), 2.0, true)
		for i in 3:
			draw_line(outer[i], outer[i + 3], Color(0.36, 0.43, 0.6, 0.3), 1.0)
		draw_colored_polygon(inner, Color(0.31, 0.47, 0.72, 0.6))
		for i in 6:
			var a := -PI * 0.5 + i * PI / 3.0
			var p := c + Vector2(cos(a), sin(a)) * (r + 22) - Vector2(18, -7)
			draw_string(G.font_ui_bold, p, NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("1f2a52"))
