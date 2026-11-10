class_name UIKit
extends RefCounted
## RO-style UI kit built from the generated 9-slice textures. Every window, button and gauge
## comes from here so the art can be swapped in one place.

## Interface colours are palette colours (tools/artkit.py); frames come from tools/gen_ui.py.
const BLUE_INK := Color("1f2a52")    # deep: headings on parchment
const INK := Color("1a1622")         # ink: body text on parchment
const SUB := Color("625e68")         # iron: secondary text
const GOLD := Color("b8862e")        # brass
const LIGHT := Color("f4efe4")       # bone: text on dark panels
const GLOW := Color("fbe58a")        # glow: headings on dark panels

## Smallest touch target (48 dp on a 160 dpi baseline; the 720-high canvas maps 1 unit to about 1 dp on phones).
const MIN_TOUCH := 48.0

## A 9-slice frame: the corners (margin px) keep their size, the edges and centre stretch.
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
	t.set_stylebox("panel", "PanelContainer", sb("res://assets/ui/window.png", 8, 14))
	t.set_stylebox("panel", "Panel", sb("res://assets/ui/window.png", 8, 14))
	var b := sb("res://assets/ui/btn.png", 5, 14)
	var bp := sb("res://assets/ui/btn_pressed.png", 5, 14)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", b)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", b)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", BLUE_INK)
	t.set_color("font_hover_color", "Button", BLUE_INK)
	t.set_color("font_pressed_color", "Button", BLUE_INK)
	t.set_color("font_disabled_color", "Button", SUB)
	t.set_font("font", "Button", G.font_ui_bold)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Label", INK)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", sb("res://assets/ui/card.png", 4, 12))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	var le := sb("res://assets/ui/slot.png", 5, 12)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", LIGHT)
	t.set_color("font_placeholder_color", "LineEdit", Color("c79a5e"))
	t.set_color("caret_color", "LineEdit", GLOW)
	t.set_font_size("font_size", "LineEdit", 24)
	t.set_stylebox("panel", "TooltipPanel", sb("res://assets/ui/window.png", 8, 10))
	var sc := StyleBoxFlat.new(); sc.bg_color = GOLD; sc.set_border_width_all(1); sc.border_color = INK
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
		tp.add_theme_stylebox_override("panel", sb("res://assets/ui/title.png", 6, 10))
		var tl := label(title, 22, GLOW, true)
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
	b.pressed.connect(func() -> void: G.sfx("tap"))
	if gold:
		var g := sb("res://assets/ui/btn_gold.png", 5, 14)
		b.add_theme_stylebox_override("normal", g); b.add_theme_stylebox_override("hover", g)
	b.pressed.connect(cb)
	press_feel(b)
	return b

## Button press feel: dip to 94% on press, spring back on release.
static func press_feel(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	if b is BaseButton:
		b.button_down.connect(func():
			G.haptic(10)
			b.pivot_offset = b.size * 0.5
			b.create_tween().tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
		b.button_up.connect(func():
			var tw := b.create_tween(); tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.07); tw.tween_property(b, "scale", Vector2.ONE, 0.08))

## Shared pop-in motion for windows (0.92 -> 1.03 -> 1.0 over ~220 ms); fades only with Reduce Motion.
static func pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	if G.settings.reduce_motion:
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.15); return
	c.pivot_offset = c.size * 0.5
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.scale = Vector2(0.92, 0.92)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.14)
	tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.14).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(c, "scale", Vector2.ONE, 0.08)

## Safe-area insets (notches, rounded corners, home bar) in viewport units: left, top, right, bottom.
static func safe_insets(vp: Viewport) -> Vector4:
	var scr := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if scr.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var vs := vp.get_visible_rect().size
	var kx := vs.x / float(scr.x); var ky := vs.y / float(scr.y)
	return Vector4(safe.position.x * kx, safe.position.y * ky, (scr.x - safe.end.x) * kx, (scr.y - safe.end.y) * ky)

## Head and shoulders from the first frame of a character sheet or standee (64x96 cells).
static func face(sheet: Texture2D) -> AtlasTexture:
	var at := AtlasTexture.new(); at.atlas = sheet; at.region = G.PLAYER_FACE
	return at

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
	g.stretch_margin_left = 2; g.stretch_margin_right = 2; g.stretch_margin_top = 3; g.stretch_margin_bottom = 3
	g.custom_minimum_size = Vector2(w, h)
	g.max_value = 1000
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

static func parchment(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb("res://assets/ui/parchment.png", 5, 14))
	var l := label(text, 21, Color("3d2a25"), false, true)
	p.add_child(l)
	return p

static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Drawn backdrops (title, story, creation) are rendered small and mapped onto the 32-colour
## palette with an ordered dither, so they are pixel art like everything else on screen.
const PIXEL := 4
static var _pal_shader: Shader

static func pixelate(art: Control) -> SubViewportContainer:
	if _pal_shader == null:
		_pal_shader = Shader.new()
		_pal_shader.code = """shader_type canvas_item;
uniform sampler2D pal : filter_nearest;
uniform float dither = 0.09;
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	ivec2 p = ivec2(UV / TEXTURE_PIXEL_SIZE);
	c += (BAYER[(p.y % 4) * 4 + (p.x % 4)] / 16.0 - 0.47) * dither;
	float best = 1e9; vec3 pick = c;
	for (int i = 0; i < 32; i++) {
		vec3 q = texelFetch(pal, ivec2(i, 0), 0).rgb;
		vec3 d = c - q;
		float dist = dot(d * vec3(0.9, 1.2, 0.8), d);
		if (dist < best) { best = dist; pick = q; }
	}
	COLOR = vec4(pick, 1.0);
}"""
	var box := SubViewportContainer.new(); full_rect(box)
	box.stretch = true; box.stretch_shrink = PIXEL; box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new(); m.shader = _pal_shader; m.set_shader_parameter("pal", G.tex("res://assets/ui/palette.png")); box.material = m
	var vp := SubViewport.new(); vp.transparent_bg = false; vp.size_2d_override_stretch = true; vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	full_rect(art); vp.add_child(art)
	var fit := func() -> void: vp.size_2d_override = Vector2i(box.size)
	box.resized.connect(fit); box.ready.connect(fit)
	return box
