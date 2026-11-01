extends Control
## Title (key art + Tap to start) -> age gate (13+) -> one world, no server choice (GDD v0.3).

var year := 2008
var year_lbl: Label
var age_msg: Label
var panel_holder: CenterContainer
var tap_lbl: Label
var phase := "start"
var t := 0.0

func _ready() -> void:
	UIKit.full_rect(self)
	theme = G.theme
	var art := KeyArt.new(); UIKit.full_rect(art); add_child(art)
	var logo_box := VBoxContainer.new()
	logo_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	logo_box.position = Vector2(-500, 40); logo_box.size = Vector2(1000, 180)
	logo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := UIKit.outlined("Heavenward Pathway Online", 78, Color("fff1c8"), G.font_title)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", Color("5a3600"))
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", Color(1, 0.86, 0.5, 0.45))
	logo.add_theme_constant_override("shadow_outline_size", 28)
	logo_box.add_child(logo)
	var sub := UIKit.outlined("After John Bunyan", 26, Color.WHITE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_box.add_child(sub)
	add_child(logo_box)
	tap_lbl = UIKit.outlined("Tap to start", 34, Color.WHITE)
	tap_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tap_lbl.position = Vector2(-150, -110); tap_lbl.size = Vector2(300, 50)
	tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tap_lbl)
	var ver := UIKit.outlined("Demo build 0.1 · placeholder art", 16, Color(1, 1, 1, 0.8))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-330, -36); add_child(ver)
	panel_holder = CenterContainer.new(); UIKit.full_rect(panel_holder)
	panel_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_holder)

func _process(delta: float) -> void:
	t += delta
	if tap_lbl.visible:
		tap_lbl.modulate.a = 0.55 + 0.45 * sin(t * 3.0)

func _gui_input(e: InputEvent) -> void:
	if phase == "start" and e is InputEventScreenTouch and e.pressed:
		start_age()

func start_age() -> void:
	if phase != "start":
		return
	phase = "age"
	tap_lbl.visible = false
	var w := UIKit.window("Before you begin", Vector2(560, 0))
	var b: VBoxContainer = w.body
	b.add_child(UIKit.label("Year of birth", 22, UIKit.BLUE_INK, true))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8)
	row.add_child(UIKit.button("−10", func(): _yr(-10), 76))
	row.add_child(UIKit.button("−1", func(): _yr(-1), 64))
	year_lbl = UIKit.label(str(year), 40, UIKit.INK, true); year_lbl.custom_minimum_size = Vector2(140, 0)
	year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(year_lbl)
	row.add_child(UIKit.button("+1", func(): _yr(1), 64))
	row.add_child(UIKit.button("+10", func(): _yr(10), 76))
	b.add_child(row)
	age_msg = UIKit.label("Pilgrims must be 13 or older. Your birth year only confirms age and sets protective defaults for players under 18.", 19, UIKit.SUB, false, true)
	age_msg.custom_minimum_size = Vector2(500, 0)
	b.add_child(age_msg)
	b.add_child(UIKit.button("Continue", _age_ok, 0, true))
	panel_holder.add_child(w.root)

func _yr(d: int) -> void:
	year = clampi(year + d, 1930, 2026)
	year_lbl.text = str(year)

func _age_ok() -> void:
	var age := 2026 - year
	if age < 13:
		age_msg.text = "Heavenward Pathway Online is for players 13 and older. Thank you for your interest; please come back when you are older."
		age_msg.add_theme_color_override("font_color", Color("a8342a"))
		return
	G.minor = age < 18
	for c in panel_holder.get_children():
		c.queue_free()
	phase = "server"
	var w := UIKit.window("One world for every pilgrim", Vector2(620, 0))
	var b: VBoxContainer = w.body
	b.add_child(UIKit.label("No server to choose. Your story is walked solo or with friends; you meet other pilgrims in the Houses, the Wilds and the Muster Board.", 19, UIKit.INK, false, true))
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 4)
	for kv in [["Region", "Nearest (automatic)"], ["Language", "English"], ["This demo", "Offline; other pilgrims are simulated"]]:
		g.add_child(UIKit.label(kv[0], 17, UIKit.SUB)); g.add_child(UIKit.label(kv[1], 17, UIKit.INK, true))
	b.add_child(g)
	b.add_child(UIKit.button("Begin the pilgrimage", func(): G.goto("create"), 0, true))
	panel_holder.add_child(w.root)


class KeyArt extends Control:
	## Placeholder painted key art: dawn sky, drifting clouds, hills, the narrow way to a shining gate.
	var tt := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		tt += d; queue_redraw()
	func _draw() -> void:
		var w := size.x; var h := size.y
		var sky := [Color("6e86c6"), Color("a9c3ea"), Color("f4dcb0"), Color("ffe9b8")]
		for i in 60:
			var f := float(i) / 59.0
			var c: Color
			if f < 0.5: c = sky[0].lerp(sky[1], f * 2.0)
			elif f < 0.8: c = sky[1].lerp(sky[2], (f - 0.5) / 0.3)
			else: c = sky[2].lerp(sky[3], (f - 0.8) / 0.2)
			draw_rect(Rect2(0, h * 0.62 * f, w, h * 0.62 / 59.0 + 1), c)
		var gate := Vector2(w * 0.5, h * 0.5)
		for r in range(220, 0, -10):
			draw_circle(gate, r, Color(1, 0.96, 0.8, 0.05))
		draw_circle(gate, 16, Color(1, 0.98, 0.9))
		for i in 6:
			var cx := fmod(i * 260.0 + tt * (8.0 + i * 2.0), w + 400.0) - 200.0
			var cy := 90.0 + (i % 3) * 60.0
			for k in 4:
				draw_circle(Vector2(cx + k * 34.0, cy + (k % 2) * 8.0), 34.0 - (k % 2) * 6.0, Color(1, 1, 1, 0.55))
		draw_colored_polygon(_hill(h * 0.56, 0.0, 70.0, w), Color("8fbf74"))
		draw_colored_polygon(_hill(h * 0.64, 2.0, 50.0, w), Color("6faa58"))
		draw_colored_polygon(_hill(h * 0.74, 4.0, 40.0, w), Color("5d9a4a"))
		var path := PackedVector2Array([gate + Vector2(-6, 10), gate + Vector2(6, 10), Vector2(w * 0.66, h), Vector2(w * 0.34, h)])
		draw_colored_polygon(path, Color("e8d6a2"))
		draw_colored_polygon(PackedVector2Array([gate + Vector2(-2, 10), gate + Vector2(2, 10), Vector2(w * 0.52, h), Vector2(w * 0.48, h)]), Color(1, 1, 1, 0.25))
		for x in [w * 0.12, w * 0.86, w * 0.24]:
			_tree(Vector2(x, h * (0.86 if x != w * 0.24 else 0.74)), 1.0 if x != w * 0.24 else 0.7)
	func _hill(y: float, seed: float, amp: float, w: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 41:
			var x := w * i / 40.0
			p.append(Vector2(x, y + sin(i * 0.4 + seed) * amp * 0.4 + sin(i * 0.13 + seed) * amp))
		p.append(Vector2(w, size.y)); p.append(Vector2(0, size.y))
		return p
	func _tree(base: Vector2, s: float) -> void:
		draw_rect(Rect2(base + Vector2(-10, -90) * s, Vector2(20, 90) * s), Color("6e4a2c"))
		for c in [Vector2(-34, -110), Vector2(34, -110), Vector2(0, -150)]:
			draw_circle(base + c * s, 52.0 * s, Color("3f7f34"))
		draw_circle(base + Vector2(-12, -160) * s, 22.0 * s, Color("6fb35a"))
