class_name UIKit
extends RefCounted
## RO-style UI kit built from the generated 9-slice textures. Every window, button and gauge
## comes from here so the art can be swapped in one place.

const BLUE_INK := Color("1d2b52")
const INK := Color("1b1d26")
const SUB := Color("4a5472")
const GOLD := Color("b8933e")

static func sb(path: String, margin: int, pad: int = 8) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = G.tex(path)
	s.texture_margin_left = margin; s.texture_margin_right = margin
	s.texture_margin_top = margin; s.texture_margin_bottom = margin
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = G.font_ui
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", sb("res://assets/ui/window.png", 12, 14))
	t.set_stylebox("panel", "Panel", sb("res://assets/ui/window.png", 12, 14))
	var b := sb("res://assets/ui/btn.png", 10, 14)
	var bp := sb("res://assets/ui/btn_pressed.png", 10, 14)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", b)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", b)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", BLUE_INK)
	t.set_color("font_hover_color", "Button", BLUE_INK)
	t.set_color("font_pressed_color", "Button", BLUE_INK)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.48, 0.58))
	t.set_font("font", "Button", G.font_ui_bold)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Label", INK)
	var le := sb("res://assets/ui/slot.png", 8, 12)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.52, 0.6))
	t.set_color("caret_color", "LineEdit", BLUE_INK)
	t.set_font_size("font_size", "LineEdit", 24)
	t.set_stylebox("panel", "TooltipPanel", sb("res://assets/ui/window.png", 12, 10))
	var sc := StyleBoxFlat.new(); sc.bg_color = Color(0.36, 0.43, 0.6, 0.6); sc.corner_radius_top_left = 4; sc.corner_radius_bottom_left = 4; sc.corner_radius_top_right = 4; sc.corner_radius_bottom_right = 4
	t.set_stylebox("grabber", "VScrollBar", sc)
	t.set_stylebox("grabber_highlight", "VScrollBar", sc)
	t.set_stylebox("grabber_pressed", "VScrollBar", sc)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t

static func window(title: String = "", min_size: Vector2 = Vector2.ZERO) -> Dictionary:
	## Returns {"root": PanelContainer, "body": VBoxContainer}
	var p := PanelContainer.new()
	p.theme = G.theme
	p.custom_minimum_size = min_size
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	if title != "":
		var tp := PanelContainer.new()
		tp.add_theme_stylebox_override("panel", sb("res://assets/ui/title.png", 9, 10))
		var tl := label(title, 22, BLUE_INK, true)
		tp.add_child(tl)
		v.add_child(tp)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return {"root": p, "body": body, "box": v}

static func label(text: String, size: int = 22, color: Color = INK, bold: bool = false, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", G.font_ui_bold)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func outlined(text: String, size: int = 22, color: Color = Color.WHITE, font: Font = null) -> Label:
	var l := label(text, size, color, true)
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.1))
	l.add_theme_constant_override("outline_size", max(4, size / 5))
	return l

static func button(text: String, cb: Callable, min_w: float = 0.0, gold: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = G.theme
	b.custom_minimum_size = Vector2(min_w, 56)
	b.focus_mode = Control.FOCUS_NONE
	if gold:
		var g := sb("res://assets/ui/btn_gold.png", 10, 14)
		b.add_theme_stylebox_override("normal", g); b.add_theme_stylebox_override("hover", g)
	b.pressed.connect(cb)
	return b

static func icon_rect(name: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = G.tex("res://assets/icons/%s.png" % name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func gauge(fill: String, w: float, h: float) -> TextureProgressBar:
	var g := TextureProgressBar.new()
	g.texture_under = G.tex("res://assets/ui/gauge_bg.png")
	g.texture_progress = G.tex("res://assets/ui/gauge_%s.png" % fill)
	g.nine_patch_stretch = true
	g.stretch_margin_left = 3; g.stretch_margin_right = 3; g.stretch_margin_top = 3; g.stretch_margin_bottom = 3
	g.custom_minimum_size = Vector2(w, h)
	g.max_value = 1000
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

static func parchment(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb("res://assets/ui/parchment.png", 10, 14))
	var l := label(text, 21, Color("4a3a20"), false, true)
	p.add_child(l)
	return p

static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
