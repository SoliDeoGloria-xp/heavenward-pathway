class_name TouchScroll
extends ScrollContainer
## A list a thumb can scroll. Godot's ScrollContainer only scrolls when the drag starts on bare
## background: a finger that lands on a row, a tile or a button never scrolls, which made the long
## windows hard to use on a phone. This one watches the touch itself: drag anywhere inside it and the
## list follows the finger and glides on after release; a touch that does not move is still a tap on
## whatever is under it. When a drag begins, the button under the finger is let go without firing.

const DEADZONE := 14.0             # px a finger may wander and still count as a tap
const FRICTION := 5.0              # how quickly a flick slows (per second)
const MIN_GLIDE := 30.0            # px/s below which the glide stops
const BAR_W := 12                  # the scrollbar is wide enough to see and to grab
const FAR := Vector2(-4000, -4000)

var dragging := false
var _finger := -1
var _from := Vector2.ZERO
var _vel := 0.0
var _swallow_mouse := false

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	get_v_scroll_bar().custom_minimum_size.x = BAR_W
	set_process(false)

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed and _finger == -1 and get_global_rect().has_point(e.position):
			_finger = e.index; _from = e.position; dragging = false; _vel = 0.0; set_process(false)
		elif not e.pressed and e.index == _finger:
			_finger = -1
			if dragging:
				dragging = false
				set_process(absf(_vel) > MIN_GLIDE)
				get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index == _finger:
		var moved: Vector2 = e.position - _from
		if not dragging and absf(moved.y) > DEADZONE and absf(moved.y) > absf(moved.x):
			dragging = true
			_let_go()
		if dragging:
			scroll_vertical -= int(round(e.relative.y))
			_vel = -e.velocity.y
			get_viewport().set_input_as_handled()
	elif _swallow_mouse and (e is InputEventMouseMotion or e is InputEventMouseButton) and e.position != FAR:
		# the mouse events a touch also sends: the pressed button must not see the finger come up on it
		if e is InputEventMouseButton and not e.pressed:
			_swallow_mouse = false
		get_viewport().set_input_as_handled()

## Tell whatever button the finger went down on that the press left it, so it does not fire.
func _let_go() -> void:
	_swallow_mouse = true
	var away := InputEventMouseMotion.new(); away.position = FAR; away.global_position = FAR
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = FAR; up.global_position = FAR
	get_viewport().push_input(away); get_viewport().push_input(up)

func _process(delta: float) -> void:
	scroll_vertical += int(round(_vel * delta))
	_vel = lerpf(_vel, 0.0, minf(1.0, FRICTION * delta))
	var bar := get_v_scroll_bar()
	if absf(_vel) < MIN_GLIDE or scroll_vertical <= 0 or scroll_vertical >= int(bar.max_value - bar.page):
		set_process(false)
