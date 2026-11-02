class_name Coach
extends CanvasLayer
## Onboarding coach (OSRS "control guide" + Ragnarok Origin highlight style).
## The Dreamer speaks in a bubble, a gold ring and a pointing hand mark one thing on screen,
## and the rest of the screen dims. Three step kinds:
##   info   - read, then tap anywhere or "Got it" (screen dimmed, world paused)
##   action - do the thing (ring + hand; nothing blocked); advances when done() is true
##   tip    - short hint that fades after a few seconds; never blocks
## Step keys: text, short (Light guide text), target (Callable -> Control | Rect2 | Vector2 | null),
## kind, done (Callable -> bool), enter (Callable), tour (true = skipped in Light guide), secs (tips).

signal finished

var hud
var steps: Array = []
var i := -1
var active := false
var t := 0.0
var step_t := 0.0
var _done_cb := Callable()
var tip_queue: Array = []

var dims: Array = []
var catcher: Control
var ring: Panel
var hand: Label
var bubble: PanelContainer
var text_lbl: Label
var name_lbl: Label
var btn_row: HBoxContainer
var next_btn: Button
var skip_btn: Button

func _ready() -> void:
	layer = 15
	for k in 4:
		var d := ColorRect.new(); d.color = Color(0.02, 0.03, 0.08, 0.55); d.visible = false
		d.gui_input.connect(_dim_input)
		add_child(d); dims.append(d)
	catcher = Control.new(); catcher.visible = false; catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_dim_input); add_child(catcher)
	ring = Panel.new(); ring.mouse_filter = Control.MOUSE_FILTER_IGNORE; ring.visible = false
	var rs := StyleBoxFlat.new(); rs.bg_color = Color(1, 1, 1, 0); rs.set_border_width_all(5); rs.border_color = Color("ffd34e")
	rs.set_corner_radius_all(18); rs.shadow_color = Color(1, 0.85, 0.3, 0.5); rs.shadow_size = 10
	ring.add_theme_stylebox_override("panel", rs); add_child(ring)
	hand = UIKit.outlined("▼", 56, Color("ffd34e")); hand.add_theme_color_override("font_outline_color", Color("4a2c00"))
	hand.add_theme_constant_override("outline_size", 12); hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand.size = Vector2(72, 64); hand.mouse_filter = Control.MOUSE_FILTER_IGNORE; hand.visible = false; add_child(hand)
	bubble = PanelContainer.new(); bubble.theme = G.theme; bubble.visible = false
	bubble.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/window.png", 12, 14))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); bubble.add_child(h)
	var face := TextureRect.new(); face.texture = G.tex("res://assets/portraits/dreamer.png"); face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; face.custom_minimum_size = Vector2(92, 115); face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(face)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); v.custom_minimum_size = Vector2(500, 0); h.add_child(v)
	name_lbl = UIKit.label("The Dreamer", 19, Color("1d4fb8"), true); v.add_child(name_lbl)
	text_lbl = UIKit.label("", 22, UIKit.INK, false, true); text_lbl.custom_minimum_size = Vector2(500, 0); v.add_child(text_lbl)
	btn_row = HBoxContainer.new(); btn_row.alignment = BoxContainer.ALIGNMENT_END; btn_row.add_theme_constant_override("separation", 8); v.add_child(btn_row)
	skip_btn = UIKit.button("Skip tips", _skip_all, 130); skip_btn.custom_minimum_size.y = 48; skip_btn.add_theme_font_size_override("font_size", 18)
	next_btn = UIKit.button("Got it ▶", next, 150, true); next_btn.custom_minimum_size.y = 52
	btn_row.add_child(skip_btn); btn_row.add_child(next_btn)
	add_child(bubble)

## Run a list of steps; done is called when they end (also when tips are off).
func run(list: Array, done: Callable = Callable()) -> void:
	_done_cb = done
	steps = []
	for st in list:
		if G.guide == "off" and st.get("kind", "info") != "action":
			continue
		if G.guide == "light" and st.get("tour", false):
			continue
		steps.append(st)
	i = -1; active = true
	next()

func blocking() -> bool:
	return active and i >= 0 and i < steps.size() and steps[i].get("kind", "info") == "info"

func busy() -> bool:
	return active

## A short hint that never blocks. Shown now, or after the current lesson ends.
func tip(text: String, target = null, secs: float = 5.5) -> void:
	if G.guide == "off":
		return
	var st := {"text": text, "kind": "tip", "secs": secs}
	if target != null:
		st.target = target
	if active:
		tip_queue.append(st)
	else:
		run([st])

func next() -> void:
	i += 1
	step_t = 0.0
	if i >= steps.size():
		_finish(); return
	var st: Dictionary = steps[i]
	if st.has("skip_if") and st.skip_if.call():
		next(); return
	if st.has("enter"):
		st.enter.call()
	var kind: String = st.get("kind", "info")
	var txt: String = st.text
	if G.guide == "light" and st.has("short"):
		txt = st.short
	text_lbl.text = txt
	next_btn.visible = kind == "info"
	skip_btn.visible = kind != "tip"
	btn_row.visible = kind != "tip"
	bubble.visible = true
	bubble.modulate.a = 0.0
	create_tween().tween_property(bubble, "modulate:a", 1.0, 0.18)
	for dd in dims:
		dd.mouse_filter = Control.MOUSE_FILTER_STOP if kind == "info" else Control.MOUSE_FILTER_IGNORE
		dd.color.a = 0.55 if kind == "info" else (0.22 if kind == "action" else 0.0)
	catcher.visible = kind == "info"
	G.haptic(8)

func _finish() -> void:
	active = false
	for dd in dims: dd.visible = false
	catcher.visible = false; ring.visible = false; hand.visible = false; bubble.visible = false
	var cb := _done_cb; _done_cb = Callable()
	finished.emit()
	if cb.is_valid():
		cb.call()
	if not active and tip_queue.size() > 0:
		var nt: Dictionary = tip_queue.pop_front()
		run([nt])

func _skip_all() -> void:
	G.guide = "off"
	# keep only required actions (e.g. spend points) as silent steps; the quest tracker still says what to do
	G.say("Tips are off. Turn them back on in More → Guide.", G.SYS)
	var cb := _done_cb
	steps = []; i = 0
	_done_cb = cb
	_finish()

func _dim_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and not e.pressed and step_t > 0.35 and blocking():
		next()

func _target_rect(st: Dictionary) -> Variant:
	if not st.has("target"):
		return null
	var tg = st.target.call() if st.target is Callable else st.target
	if tg == null:
		return null
	if tg is Control:
		var c: Control = tg
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			return null
		return c.get_global_rect().grow(8)
	if tg is Rect2:
		return tg
	if tg is Vector2:
		return Rect2(tg - Vector2(70, 70), Vector2(140, 140))
	return null

func _process(delta: float) -> void:
	if not active or i < 0 or i >= steps.size():
		return
	# conversations and story scenes own the screen; the coach waits quietly
	var hide: bool = hud != null and (hud.dialog_active() or (hud.world != null and hud.world.cinema))
	visible = not hide
	if hide:
		return
	t += delta; step_t += delta
	var st: Dictionary = steps[i]
	var kind: String = st.get("kind", "info")
	var vs := get_viewport().get_visible_rect().size
	var r = _target_rect(st)
	# dims around the hole
	if r == null or kind == "tip":
		dims[0].visible = kind == "info"; dims[0].position = Vector2.ZERO; dims[0].size = vs
		for k in range(1, 4): dims[k].visible = false
	else:
		var rr: Rect2 = r
		var parts := [Rect2(0, 0, vs.x, rr.position.y), Rect2(0, rr.end.y, vs.x, vs.y - rr.end.y),
			Rect2(0, rr.position.y, rr.position.x, rr.size.y), Rect2(rr.end.x, rr.position.y, vs.x - rr.end.x, rr.size.y)]
		for k in 4:
			dims[k].visible = kind != "tip"
			dims[k].position = parts[k].position; dims[k].size = parts[k].size.max(Vector2.ZERO)
	catcher.position = Vector2.ZERO; catcher.size = vs
	# ring + hand
	if r != null:
		var rr2: Rect2 = r
		ring.visible = true; ring.position = rr2.position; ring.size = rr2.size
		ring.modulate.a = 0.6 + 0.4 * sin(t * 6.0)
		hand.visible = true
		var bob := 0.0 if G.settings.reduce_motion else sin(t * 5.0) * 10.0
		var above := rr2.position.y > 100
		hand.text = "▼" if above else "▲"
		hand.position = Vector2(rr2.get_center().x - 36, (rr2.position.y - 78 + bob) if above else (rr2.end.y + 6 - bob))
		if hud != null and hud.sheet_tab != "" and rr2.position.x > vs.x * 0.45:
			# inside a list window: point from the side so the arrow never hides the row above
			hand.text = "▶"
			hand.position = Vector2(rr2.position.x - 70 + bob, rr2.get_center().y - 34)
	else:
		ring.visible = false; hand.visible = false
	# bubble placement: away from the target; beside an open side window, never over it
	var tw := 500.0
	if hud != null and hud.sheet_tab != "":
		tw = clampf(vs.x - 708.0 - 175.0, 300.0, 500.0)
	if absf(text_lbl.custom_minimum_size.x - tw) > 1.0:
		text_lbl.custom_minimum_size.x = tw
		text_lbl.get_parent().custom_minimum_size.x = tw
	bubble.reset_size()
	var bs := bubble.size
	var pos := Vector2((vs.x - bs.x) * 0.5, 96)
	if r != null:
		var c: Vector2 = (r as Rect2).get_center()
		pos.x = 24.0 if c.x > vs.x * 0.5 else vs.x - bs.x - 24.0
		pos.y = 110.0 if c.y > vs.y * 0.5 else vs.y - bs.y - 60.0
		if c.x > vs.x * 0.42 and c.x < vs.x * 0.58:
			pos.x = (vs.x - bs.x) * 0.5
	bubble.position = pos
	# advance
	match kind:
		"action":
			if st.has("done") and st.done.call():
				G.haptic(18); next()
		"tip":
			if step_t > float(st.get("secs", 5.5)):
				next()
