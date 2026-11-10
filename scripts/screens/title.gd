extends Control
## Title (key art + Tap to start) -> age gate (13+) -> create (single-player).

var year := 2008
var year_lbl: Label
var age_msg: Label
var panel_holder: CenterContainer
var tap_lbl: Label
const MIN_AGE := 13
const ADULT_AGE := 18
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
	var ver := UIKit.outlined("Version %s · placeholder art" % ProjectSettings.get_setting("application/config/version"), 16, Color(1, 1, 1, 0.8))
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
		start()

## First tap: Lord's Day reading, Continue / New game when a save exists, otherwise the age gate.
func start() -> void:
	if G.lords_day():
		_lords_day_panel()
	elif G.has_save():
		_continue_panel()
	else:
		start_age()

func _panel(title: String, width: float) -> VBoxContainer:
	phase = "panel"
	tap_lbl.visible = false
	for c in panel_holder.get_children():
		c.queue_free()
	var w := UIKit.window(title, Vector2(width, 0))
	panel_holder.add_child(w.root)
	return w.body

func _continue_panel() -> void:
	var b := _panel("Welcome back, pilgrim", 560)
	b.add_child(UIKit.label("Your journey is saved on this device.", 20, UIKit.SUB, false, true))
	b.add_child(UIKit.button("Continue", _continue, 0, true))
	b.add_child(UIKit.button("New game (replaces the save)", func() -> void: phase = "start"; start_age(), 0))

func _continue() -> void:
	if G.load_game():
		G.goto("world", {"map": G.cur_map})
	else:
		G.delete_save(); phase = "start"; start_age()

## Lord's Day Mode: the road rests; only quiet reading is offered, with no rewards.
func _lords_day_panel() -> void:
	var b := _panel("The Lord's Day", 640)
	b.add_child(UIKit.label("Today the road rests. Nothing is earned or lost. Read, be with your church, and come back tomorrow.", 20, UIKit.INK, false, true))
	for ref in G.data("lords_day").readings:
		b.add_child(UIKit.parchment("[BSB: %s]" % ref))
	if G.DEV_UNLOCK:
		b.add_child(UIKit.button("Tester: play anyway", func() -> void:
			G.settings.lords_day_bypass = true; G.save_settings(); phase = "start"; start(), 0))

func start_age() -> void:
	if phase != "start":
		return
	var b := _panel("Before you begin", 560)
	phase = "age"
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

func _yr(d: int) -> void:
	year = clampi(year + d, 1930, _this_year())
	year_lbl.text = str(year)

func _age_ok() -> void:
	var age := _this_year() - year
	if age < MIN_AGE:
		age_msg.text = "Heavenward Pathway Online is for players 13 and older. Thank you for your interest; please come back when you are older."
		age_msg.add_theme_color_override("font_color", Color("a8342a"))
		return
	G.minor = age < ADULT_AGE
	for c in panel_holder.get_children():
		c.queue_free()
	G.delete_save()
	G.goto("create")   # single-player: no server screen

func _this_year() -> int:
	return int(Time.get_datetime_dict_from_system().year)


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
