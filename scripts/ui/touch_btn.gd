class_name TouchBtn
extends Control
## Multi-touch HUD button (works while the other thumb holds the joystick).
## Reacts to InputEventScreenTouch only; mouse input reaches it as emulated touch on desktop/web.

signal pressed
signal long_pressed

var tex_normal: Texture2D
var tex_on: Texture2D
var icon: Texture2D
var caption := ""
var on := false
var cd_frac := 0.0          # 0..1 remaining cooldown
var cd_text := ""
var disabled := false
var badge := ""
var caption_size := 18
var _down := -1
var _down_t := 0
var _fired_long := false
var _flash := 0.0

func _init(size_px: float = 120.0, normal: String = "res://assets/ui/btn_skill.png", icon_name: String = "", text: String = "") -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	tex_normal = G.tex(normal)
	if icon_name != "":
		icon = G.tex("res://assets/icons/%s.png" % icon_name)
	caption = text
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_icon(icon_name: String) -> void:
	icon = G.tex("res://assets/icons/%s.png" % icon_name) if icon_name != "" else null
	queue_redraw()

func flash() -> void:
	_flash = 1.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _down == -1:
			_down = e.index; _down_t = Time.get_ticks_msec(); _fired_long = false
			queue_redraw(); accept_event()
		elif not e.pressed and e.index == _down:
			_down = -1; queue_redraw(); accept_event()
			if not _fired_long and Rect2(Vector2.ZERO, size).has_point(e.position) and not disabled:
				pressed.emit()

func _process(delta: float) -> void:
	if _down != -1 and not _fired_long and Time.get_ticks_msec() - _down_t > 550:
		_fired_long = true
		long_pressed.emit()
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 2.5)
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var k := 0.94 if _down != -1 else 1.0
	var rr := Rect2(r.position + r.size * (1.0 - k) * 0.5, r.size * k)
	var t := tex_on if (on and tex_on) else tex_normal
	if t:
		draw_texture_rect(t, rr, false, Color(1, 1, 1, 0.55 if disabled else 1.0))
	if icon:
		var isz := rr.size * 0.5
		var ip := rr.position + (rr.size - isz) * Vector2(0.5, 0.40 if caption != "" else 0.46)
		draw_texture_rect(icon, Rect2(ip, isz), false, Color(1, 1, 1, 0.5 if disabled else 1.0))
	var f: Font = G.font_ui_bold
	if caption != "":
		var cs := caption_size
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, cs).x
		var pos := Vector2(rr.position.x + (rr.size.x - tw) * 0.5, rr.position.y + rr.size.y * 0.84)
		draw_string_outline(f, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, 5, Color(0.1, 0.1, 0.16))
		draw_string(f, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color.WHITE)
	if cd_frac > 0.0:
		var c := rr.get_center()
		var rad := rr.size.x * 0.42
		var pts := PackedVector2Array([c])
		var steps := 32
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * cd_frac * float(i) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.06, 0.08, 0.16, 0.62))
		if cd_text != "":
			var tw2 := f.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
			draw_string_outline(f, c + Vector2(-tw2 * 0.5, 11), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0.05, 0.05, 0.1))
			draw_string(f, c + Vector2(-tw2 * 0.5, 11), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	if badge != "":
		var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x + 14
		var br := Rect2(rr.position + Vector2(rr.size.x - bw, 0), Vector2(bw, 26))
		draw_rect(br, Color(0.12, 0.15, 0.28, 0.9))
		draw_string(f, br.position + Vector2(7, 20), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if _flash > 0.0:
		draw_circle(rr.get_center(), rr.size.x * (0.5 + (1.0 - _flash) * 0.15), Color(1, 0.95, 0.7, _flash * 0.45))
