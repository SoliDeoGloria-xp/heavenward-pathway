class_name FloatingJoystick
extends Control
## RO M / Origin style floating joystick: appears where the left thumb lands inside this zone.
## A quick tap (no drag) is forwarded as a world tap, so tap-to-walk still works in the zone.

signal tapped(screen_pos: Vector2)

var vec := Vector2.ZERO
var radius := 90.0
var _idx := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _start_ms := 0
var _moved := false
var base_tex: Texture2D
var knob_tex: Texture2D
var idle_hint := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	base_tex = G.tex("res://assets/ui/joy_base.png")
	knob_tex = G.tex("res://assets/ui/joy_knob.png")

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _idx == -1:
			_idx = e.index; _origin = e.position; _knob = e.position; _start_ms = Time.get_ticks_msec(); _moved = false
			queue_redraw(); accept_event()
		elif not e.pressed and e.index == _idx:
			if not _moved and Time.get_ticks_msec() - _start_ms < 300:
				tapped.emit(get_global_transform_with_canvas() * e.position)
			_idx = -1; vec = Vector2.ZERO; queue_redraw(); accept_event()
	elif e is InputEventScreenDrag and e.index == _idx:
		var d: Vector2 = e.position - _origin
		if d.length() > 12.0:
			_moved = true
		if d.length() > radius:
			d = d.normalized() * radius
		_knob = _origin + d
		vec = d / radius if d.length() > 10.0 else Vector2.ZERO
		queue_redraw(); accept_event()

func _draw() -> void:
	if _idx != -1:
		draw_texture_rect(base_tex, Rect2(_origin - Vector2(radius, radius) * 1.1, Vector2(radius, radius) * 2.2), false)
		draw_texture_rect(knob_tex, Rect2(_knob - Vector2(40, 40), Vector2(80, 80)), false)
	elif idle_hint:
		var c := Vector2(size.x * 0.32, size.y * 0.62)
		draw_texture_rect(base_tex, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(1, 1, 1, 0.35))
		draw_texture_rect(knob_tex, Rect2(c - Vector2(34, 34), Vector2(68, 68)), false, Color(1, 1, 1, 0.45))
