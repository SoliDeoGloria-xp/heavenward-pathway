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
## Visual kind so players can tell buttons apart at a glance:
##  "primary" gold disc (Attack, Act) · "skill" blue disc with name pill and Zeal cost
##  "utility" small slate square (Auto, Sit, item, page, More) · "empty" dashed slot (nothing learned yet)
var kind := "skill"
var cost := ""          # Zeal cost badge (skills)
var state_text := ""    # "ON"/"OFF" pill for toggles
var pulse := false      # onboarding: gently pulse to draw the eye
var _t := 0.0
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
			G.haptic(8 if kind != "primary" else 14)
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
	if pulse:
		_t += delta; queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var k := 0.94 if _down != -1 else 1.0
	var rr := Rect2(r.position + r.size * (1.0 - k) * 0.5, r.size * k)
	var c := rr.get_center()
	var f: Font = G.font_ui_bold
	var dim := 0.5 if disabled else 1.0
	if pulse and not disabled:
		var a := 0.35 + 0.35 * sin(_t * 5.0)
		draw_arc(c, rr.size.x * 0.5 + 6 + 4 * sin(_t * 5.0), 0, TAU, 48, Color(1, 0.88, 0.4, a), 6.0, true)
	match kind:
		"empty":
			# dashed ring: an open slot, clearly not a button you can use yet
			var rad := rr.size.x * 0.40
			draw_circle(c, rad, Color(0.08, 0.1, 0.18, 0.28))
			for i in 16:
				var a0 := TAU * i / 16.0
				draw_arc(c, rad, a0, a0 + TAU / 32.0, 4, Color(1, 1, 1, 0.55), 2.5, true)
		"utility":
			var sq := Rect2(rr.position + rr.size * 0.08, rr.size * 0.84)
			var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.13, 0.17, 0.28, 0.82) if not on else Color(0.2, 0.42, 0.24, 0.92)
			sb.set_corner_radius_all(int(sq.size.x * 0.24)); sb.set_border_width_all(3)
			sb.border_color = Color(0.78, 0.84, 0.98, 0.9) if not on else Color(0.62, 1.0, 0.62)
			draw_style_box(sb, sq)
		_:
			var t := tex_on if (on and tex_on) else tex_normal
			if t:
				draw_texture_rect(t, rr, false, Color(1, 1, 1, 0.55 if disabled else 1.0))
			# coloured rim: gold = main action, blue = skill
			var rim := Color("f2c14e") if kind == "primary" else Color("7fb2ff")
			draw_arc(c, rr.size.x * 0.47, 0, TAU, 48, Color(rim.r, rim.g, rim.b, 0.95 * dim), 4.0 if kind == "primary" else 3.0, true)
	if icon:
		var isz := rr.size * (0.46 if kind != "utility" else 0.5)
		var ip := rr.position + (rr.size - isz) * Vector2(0.5, 0.40 if (caption != "" and kind != "skill") else 0.44)
		draw_texture_rect(icon, Rect2(ip, isz), false, Color(1, 1, 1, 0.45 if disabled else 1.0))
	if caption != "":
		var cs := caption_size
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, cs).x
		var pos: Vector2
		if kind == "skill" or kind == "empty":
			# name pill below the disc, always readable over the map
			var pill := Rect2(Vector2(c.x - tw * 0.5 - 8, rr.end.y - cs * 0.55), Vector2(tw + 16, cs + 8))
			var ps := StyleBoxFlat.new(); ps.bg_color = Color(0.06, 0.08, 0.16, 0.86 if kind == "skill" else 0.5); ps.set_corner_radius_all(8)
			draw_style_box(ps, pill)
			pos = Vector2(pill.position.x + 8, pill.position.y + cs)
		else:
			pos = Vector2(rr.position.x + (rr.size.x - tw) * 0.5, rr.position.y + rr.size.y * (0.86 if kind == "utility" else 0.84))
		draw_string_outline(f, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, 5, Color(0.1, 0.1, 0.16))
		draw_string(f, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color(1, 1, 1, 0.75 if (disabled or kind == "empty") else 1.0))
	if cost != "" and kind == "skill":
		var cr := Rect2(rr.position + Vector2(-2, -2), Vector2(f.get_string_size(cost, 0, -1, 16).x + 12, 24))
		var cb := StyleBoxFlat.new(); cb.bg_color = Color("2a5bd7"); cb.set_corner_radius_all(10); cb.set_border_width_all(2); cb.border_color = Color.WHITE
		draw_style_box(cb, cr)
		draw_string(f, cr.position + Vector2(6, 18), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if state_text != "":
		var sw := f.get_string_size(state_text, 0, -1, 15).x + 12
		var sr := Rect2(Vector2(c.x - sw * 0.5, rr.position.y - 6), Vector2(sw, 22))
		var ss := StyleBoxFlat.new(); ss.bg_color = Color("2f9a45") if on else Color(0.3, 0.32, 0.4); ss.set_corner_radius_all(9)
		draw_style_box(ss, sr)
		draw_string(f, sr.position + Vector2(6, 17), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if cd_frac > 0.0:
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
		var br := Rect2(rr.position + Vector2(rr.size.x - bw + 6, -6), Vector2(bw, 26))
		var bs := StyleBoxFlat.new(); bs.bg_color = Color("d23a2a") if badge.begins_with("+") else Color(0.12, 0.15, 0.28, 0.92); bs.set_corner_radius_all(12)
		draw_style_box(bs, br)
		draw_string(f, br.position + Vector2(7, 20), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if _flash > 0.0:
		draw_circle(c, rr.size.x * (0.5 + (1.0 - _flash) * 0.15), Color(1, 0.95, 0.7, _flash * 0.45))
