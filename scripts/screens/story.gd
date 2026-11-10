extends Control
## Story cards: the dream opening, the Fall (fixed, non-interactive), waking in the City.
## Bunyan text is public domain (1678). Scripture appears only as BSB references pulled at build time.
## God is never depicted or voiced.

const PD := "John Bunyan, The Pilgrim's Progress (1678) · public domain"
const DREAMER := "The Dreamer"
## Story scenes are conversations: the Dreamer speaks to you over a painted scene, and you answer.
## Line keys: who, text, src?, art, choices? [{t}]
var cards: Array = []
var idx := 0
var next_screen := ""
var next_data := {}
var art: Control
var portrait: TextureRect
var box: PanelContainer
var name_lbl: Label
var text_lbl: Label
var src_lbl: Label
var hint_lbl: Label
var choice_col: VBoxContainer
var tw: Tween
var done := false
var t := 0.0

func _ready() -> void:
	UIKit.full_rect(self); theme = G.theme
	var id: String = get_meta("data").get("id", "dream")
	match id:
		"dream":
			cards = [
				{"who": DREAMER, "art": "den", "text": "“As I walked through the wilderness of this world, I lighted on a certain place where was a Den; and I laid me down in that place to sleep: and, as I slept, I dreamed a dream.”", "src": PD},
				{"who": DREAMER, "art": "den", "text": "Peace to you, %s. I am the Dreamer, and you have found me sleeping. In my dream I see a pilgrim, and I think the pilgrim is you." % G.pname,
					"choices": [{"t": "Who are you?"}, {"t": "What will I see?", "skip": 1}]},
				{"who": DREAMER, "art": "den", "text": "Only a tinker who dreamed. I tell you what I saw, so that you may walk it yourself. I will be beside you, and I will show you how this world works."},
				{"who": DREAMER, "art": "garden", "text": "First, a garden, as it was in the beginning, before anything went wrong. Come. Walk with me.", "choices": [{"t": "I'll follow you."}]}]
			next_screen = "world"; next_data = {"map": "eden"}
	art = StoryArt.new(); UIKit.full_rect(art); add_child(art)
	var ins := UIKit.safe_insets(get_viewport())
	portrait = TextureRect.new(); portrait.texture = UIKit.face(MapKit.folk_sheet(MapKit.DREAMER_LOOK))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.anchor_top = 1; portrait.anchor_bottom = 1; portrait.offset_left = 24 + ins.x; portrait.offset_right = 254 + ins.x
	portrait.offset_top = -530; portrait.offset_bottom = -232; portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	var w := UIKit.window("", Vector2(0, 220))
	box = w.root
	box.anchor_left = 0; box.anchor_right = 1; box.anchor_top = 1; box.anchor_bottom = 1
	box.offset_left = 24 + ins.x; box.offset_right = -24 - ins.z; box.offset_top = -250 - ins.w; box.offset_bottom = -22 - ins.w
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	name_lbl = UIKit.label("", 24, Color("1d4fb8"), true); name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(name_lbl)
	hint_lbl = UIKit.label("Tap to continue ▼", 18, UIKit.SUB, true); top.add_child(hint_lbl)
	w.body.add_child(top)
	text_lbl = UIKit.label("", 27, UIKit.INK, false, true); text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL; w.body.add_child(text_lbl)
	src_lbl = UIKit.label("", 16, UIKit.SUB, false, true); w.body.add_child(src_lbl)
	add_child(box)
	choice_col = VBoxContainer.new(); choice_col.add_theme_constant_override("separation", 8)
	choice_col.anchor_left = 1; choice_col.anchor_right = 1; choice_col.anchor_top = 1; choice_col.anchor_bottom = 1
	choice_col.offset_right = -40 - ins.z; choice_col.offset_left = choice_col.offset_right - 440; choice_col.offset_bottom = -262; choice_col.offset_top = -420
	choice_col.alignment = BoxContainer.ALIGNMENT_END
	add_child(choice_col)
	var skip := UIKit.button("Skip scene ▶▶", func(): _finish(), 200)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); skip.position = Vector2(-224 - ins.z, 18 + ins.y)
	add_child(skip)
	_show()

func _process(delta: float) -> void:
	t += delta
	hint_lbl.modulate.a = 0.5 + 0.5 * sin(t * 4.0)
	art.set("t", t); art.queue_redraw()

func _show() -> void:
	var c: Dictionary = cards[idx]
	art.set("kind", c.get("art", ""))
	name_lbl.text = c.who
	portrait.visible = c.who == DREAMER
	text_lbl.text = c.text
	src_lbl.text = c.get("src", "")
	src_lbl.visible = src_lbl.text != ""
	for ch in choice_col.get_children():
		ch.queue_free()
	hint_lbl.visible = not c.has("choices")
	if c.has("choices"):
		for ch in c.choices:
			var cc: Dictionary = ch
			var b := UIKit.button("▸ " + cc.t, func():
				G.haptic(12)
				idx += int(cc.get("skip", 0))
				advance(true), 440, true)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size.y = 62
			choice_col.add_child(b)
	if tw: tw.kill()
	if not G.settings.reduce_motion:
		text_lbl.visible_ratio = 0.0
		tw = create_tween(); tw.tween_property(text_lbl, "visible_ratio", 1.0, clampf(c.text.length() * 0.018, 0.3, 2.4))
		box.modulate.a = 0.0; create_tween().tween_property(box, "modulate:a", 1.0, 0.25)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and not e.pressed:
		if text_lbl.visible_ratio < 1.0:
			if tw: tw.kill()
			text_lbl.visible_ratio = 1.0
			return
		if not cards[idx].has("choices"):
			G.haptic(8)
			advance()

func advance(from_choice: bool = false) -> void:
	if done:
		return
	if not from_choice and cards[idx].has("choices"):
		return
	idx += 1
	if idx >= cards.size():
		_finish(); return
	_show()

func _finish() -> void:
	if done:
		return
	done = true
	G.goto(next_screen, next_data)


class StoryArt extends Control:
	var kind := ""
	var t := 0.0
	const SKY := {"den": [Color("0b0b1e"), Color("2a2448")], "garden": [Color("bfe3f2"), Color("f4ecc8")], "city": [Color("2a2836"), Color("5a5266")],
		"burden": [Color("2a2836"), Color("5a5266")], "way": [Color("9cc8e8"), Color("f0e2b8")], "cross": [Color("f6e2b0"), Color("d8b880")],
		"palace": [Color("a8d0f0"), Color("f4ecd0")], "serpent": [Color("3a4a2a"), Color("8a9a6a")], "fruit": [Color("2a1e22"), Color("5a3a3a")],
		"hide": [Color("1a2418"), Color("3a4a32")], "cherubim": [Color("1a1420"), Color("4a2a20")]}
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sky: Array = SKY.get(kind, [Color("0b0b12"), Color("1b1b26")])
		for i in 32:
			var f := float(i) / 31.0
			draw_rect(Rect2(0, size.y * f, size.x, size.y / 31.0 + 1), (sky[0] as Color).lerp(sky[1], f))
		if kind == "den":
			for i in 60:
				var p := Vector2(fmod(i * 197.0, size.x), fmod(i * 83.0, size.y * 0.6))
				draw_circle(p, 1.5 + (i % 3) * 0.5, Color(1, 1, 0.9, 0.4 + 0.4 * sin(t * 2.0 + i)))
		# the scene itself, scaled up from its 440x260 design box and set above the dialogue box
		var k := minf(size.x / 440.0, (size.y - 240.0) / 260.0) * 0.95
		var off := Vector2(size.x * 0.5 - 220.0 * k + 60.0, 10.0)
		draw_set_transform(off, 0.0, Vector2(k, k))
		_scene(Vector2(440, 260))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	func _scene(size: Vector2) -> void:
		var c := size * 0.5
		match kind:
			"den":
				draw_circle(c + Vector2(0, 40), 120, Color(0.25, 0.22, 0.3))
				draw_circle(c + Vector2(0, 60), 80, Color(0.06, 0.06, 0.1))
				for i in 12:
					draw_circle(Vector2(30 + i * 36, 20 + (i * 37) % 60), 2, Color(1, 1, 0.9, 0.8))
			"garden", "city", "burden":
				var col := Color("6faa58") if kind == "garden" else Color("4a4652")
				draw_rect(Rect2(0, c.y + 30, size.x, c.y - 30), col)
				if kind == "garden":
					for x in [80, 220, 360]:
						draw_rect(Rect2(x - 8, c.y - 30, 16, 60), Color("6e4a2c"))
						draw_circle(Vector2(x, c.y - 50), 46, Color("3f8a3a"))
				elif kind == "city":
					for i in 6:
						var x := 20 + i * 72
						draw_rect(Rect2(x, c.y - 40 - (i % 3) * 20, 60, 70 + (i % 3) * 20), Color("2e2a36"))
						draw_colored_polygon(PackedVector2Array([Vector2(x - 6, c.y - 40 - (i % 3) * 20), Vector2(x + 30, c.y - 80 - (i % 3) * 20), Vector2(x + 66, c.y - 40 - (i % 3) * 20)]), Color("5a2e28"))
				else:
					draw_circle(c + Vector2(0, -30), 26, Color("f1d2b6"))
					draw_rect(Rect2(c.x - 26, c.y - 4, 52, 70), Color("6e6a62"))
					draw_circle(c + Vector2(30, 10), 30, Color("8a6438"))
			"way":
				draw_rect(Rect2(0, c.y + 30, size.x, c.y - 30), Color("6a8a4e"))
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - 8, c.y + 30), Vector2(c.x + 8, c.y + 30), Vector2(c.x + 90, size.y), Vector2(c.x - 90, size.y)]), Color("d8c690"))
				draw_rect(Rect2(c.x - 30, c.y - 40, 60, 70), Color("8a7a5e")); draw_rect(Rect2(c.x - 12, c.y - 8, 24, 38), Color("3a2a1e"))
				draw_circle(c + Vector2(0, -70), 16, Color(1, 0.96, 0.8))
			"cross":
				draw_colored_polygon(PackedVector2Array([Vector2(0, size.y), Vector2(c.x, c.y - 10), Vector2(size.x, size.y)]), Color("5e7e46"))
				draw_rect(Rect2(c.x - 6, c.y - 90, 12, 90), Color("6e4a2c")); draw_rect(Rect2(c.x - 34, c.y - 68, 68, 12), Color("6e4a2c"))
				for r in range(90, 0, -15):
					draw_circle(c + Vector2(0, -60), r, Color(1, 0.95, 0.75, 0.05))
				draw_circle(c + Vector2(70, 80), 22, Color("8a6438"))
			"palace":
				draw_rect(Rect2(0, c.y + 40, size.x, c.y - 40), Color("6faa58"))
				for r in range(130, 0, -13):
					draw_circle(c + Vector2(0, -20), r, Color(1, 0.96, 0.8, 0.04))
				draw_rect(Rect2(c.x - 110, c.y - 40, 220, 82), Color("e9e2cc"))
				for tx in [-110, 80]:
					draw_rect(Rect2(c.x + tx, c.y - 90, 30, 132), Color("f2ecd8"))
					draw_colored_polygon(PackedVector2Array([Vector2(c.x + tx - 4, c.y - 90), Vector2(c.x + tx + 15, c.y - 126), Vector2(c.x + tx + 34, c.y - 90)]), Color("4a6aa8"))
				draw_colored_polygon(PackedVector2Array([Vector2(c.x - 120, c.y - 40), Vector2(c.x, c.y - 96), Vector2(c.x + 120, c.y - 40)]), Color("5a7ab8"))
				draw_rect(Rect2(c.x - 18, c.y, 36, 42), Color("6e4a2c"))
				for wx in [-70, -40, 30, 60]:
					draw_rect(Rect2(c.x + wx, c.y - 22, 12, 16), Color("ffd98a"))
			"serpent":
				draw_rect(Rect2(c.x + 40, c.y - 10, 20, 120), Color("5e3e26"))
				draw_circle(c + Vector2(50, -40), 80, Color("4e7f3e"))
				draw_circle(c + Vector2(20, -20), 10, Color("d8342a")); draw_circle(c + Vector2(80, -60), 10, Color("d8342a"))
				var pts := PackedVector2Array()
				for i in 30:
					pts.append(c + Vector2(-160 + i * 7, 90 + sin(i * 0.6) * 14))
				draw_polyline(pts, Color("6a8a3a"), 12.0, true)
			"fruit":
				draw_circle(c, 46, Color("d8342a")); draw_line(c + Vector2(0, -46), c + Vector2(14, -70), Color("5e3e26"), 6)
				draw_circle(c + Vector2(26, -6), 18, Color("0b0b12"))
			"hide":
				draw_circle(c + Vector2(-90, 10), 90, Color("2e4a26")); draw_circle(c + Vector2(90, 0), 100, Color("2e4a26"))
			"cherubim":
				for s in [-1, 1]:
					for k in 3:
						draw_arc(c + Vector2(s * (120 - k * 16), 20), 70 - k * 14, PI if s < 0 else 0.0, PI * 1.5 if s < 0 else -PI * 0.5, 16, Color(1, 0.95, 0.78, 0.8), 4.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -110), c + Vector2(26, 60), c + Vector2(0, 110), c + Vector2(-26, 60)]), Color("f08a2a"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -60), c + Vector2(12, 50), c + Vector2(0, 90), c + Vector2(-12, 50)]), Color("fff3c8"))
