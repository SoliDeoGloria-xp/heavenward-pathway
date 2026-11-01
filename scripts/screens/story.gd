extends Control
## Story cards: the dream opening, the Fall (fixed, non-interactive), waking in the City.
## Bunyan text is public domain (1678). Scripture appears only as BSB references pulled at build time.
## God is never depicted or voiced.

const PD := "John Bunyan, The Pilgrim's Progress (1678) · public domain"
var cards: Array = []
var idx := 0
var next_screen := ""
var next_data := {}
var holder: Control
var art: Panel
var done := false

func _ready() -> void:
	UIKit.full_rect(self); theme = G.theme
	var bg := ColorRect.new(); bg.color = Color("0b0b12"); UIKit.full_rect(bg); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	var id: String = get_meta("data").get("id", "dream")
	match id:
		"dream":
			cards = [
				{"quote": "“As I walked through the wilderness of this world, I lighted on a certain place where was a Den; and I laid me down in that place to sleep: and, as I slept, I dreamed a dream.”", "src": PD, "art": "den"},
				{"who": "The Dreamer", "text": "In the dream you walk as my witness. Behold first a garden, as it was in the beginning.", "art": "garden"}]
			next_screen = "world"; next_data = {"map": "eden"}
		"fall":
			cards = [
				{"who": "The Dreamer", "text": "And I saw in my dream that the serpent spoke in the garden, and questioned the word that had been given.", "src": "[BSB: Genesis 3:1 · pulled at build time]", "art": "serpent"},
				{"who": "The Dreamer", "text": "The fruit was taken and eaten. The man, the head of all his kind, broke the covenant, and all his children fell with him.", "src": "[BSB: Genesis 3:6 · Romans 5:12]", "art": "fruit"},
				{"who": "The Dreamer", "text": "Their eyes were opened, and they knew shame. They hid themselves among the trees of the garden.", "src": "[BSB: Genesis 3:7–8]", "art": "hide"},
				{"who": "The Dreamer", "text": "So the man was driven out, east of Eden. Cherubim and a flaming sword, turning every way, guarded the way back to the tree of life.", "src": "[BSB: Genesis 3:24]", "art": "cherubim"}]
			next_screen = "story"; next_data = {"id": "wake"}
		"wake":
			cards = [
				{"quote": "“I saw a man clothed with rags, standing in a certain place, with his face from his own house, a book in his hand, and a great burden upon his back.”", "src": PD, "art": "burden"},
				{"who": "The Dreamer", "text": "You wake in the City of Destruction, born in Adam, with a burden upon your back.", "art": "city"}]
			next_screen = "world"; next_data = {"map": "city"}
		"onward":
			cards = [
				{"who": "The Dreamer", "text": "So the pilgrim ran, and the way led on: through the Slough of Despond, where Help drew him out; to the Wicket Gate; to the House of the Interpreter.", "art": "way"},
				{"who": "The Dreamer", "text": "At the Cross his burden loosed from off his shoulders and tumbled into the sepulchre, and he saw it no more. Then up the Hill Difficulty, alone, on hands and knees.", "src": "Paraphrasing " + PD, "art": "cross"},
				{"quote": "“He lift up his eyes, and behold there was a very stately palace before him, the name of which was Beautiful; and it stood just by the highway side.”", "src": PD, "art": "palace"},
				{"who": "Demo preview", "text": "Skipping ahead to the end of Act II. The Palace Beautiful is the first House, where pilgrims who walked the Way alone meet one another.", "art": "palace"}]
			next_screen = "world"; next_data = {"map": "palace"}
	art = StoryArt.new(); art.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	art.position = Vector2(-220, 40); art.size = Vector2(440, 260); add_child(art)
	holder = CenterContainer.new(); UIKit.full_rect(holder); holder.offset_top = 300; holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_show()

func _show() -> void:
	for c in holder.get_children():
		c.queue_free()
	var c: Dictionary = cards[idx]
	art.set("kind", c.get("art", ""))
	art.queue_redraw()
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); box.custom_minimum_size = Vector2(900, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c.has("quote"):
		var q := UIKit.label(c.quote, 32, Color("f2ead8"), false, true)
		q.add_theme_font_override("font", G.font_title)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(q)
		var s := UIKit.label(c.src.to_upper(), 15, Color(1, 1, 1, 0.55)); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	else:
		var w := UIKit.window("")
		var b: VBoxContainer = w.body
		b.add_child(UIKit.label("[%s]" % c.who, 22, Color("1d4fb8"), true))
		b.add_child(UIKit.label(c.text, 24, UIKit.INK, false, true))
		if c.has("src"):
			b.add_child(UIKit.label(c.src, 16, UIKit.SUB))
		w.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(w.root)
	var hint := UIKit.label("%d / %d  ·  Tap to continue" % [idx + 1, cards.size()], 16, Color(1, 1, 1, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	box.modulate.a = 0.0
	holder.add_child(box)
	create_tween().tween_property(box, "modulate:a", 1.0, 0.5)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		advance()

func advance() -> void:
	if done:
		return
	idx += 1
	if idx >= cards.size():
		done = true
		G.goto(next_screen, next_data)
		return
	_show()


class StoryArt extends Panel:
	var kind := ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	func _draw() -> void:
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
