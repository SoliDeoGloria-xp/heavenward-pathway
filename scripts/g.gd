extends Node
## Global game state, shared resources and helpers (autoload "G").
## Gameplay numbers follow the locked GDD rules: Zeal, Manna, Weariness, no XP loss on KO,
## Base Level cap 5 on Eden Isle, 2 attribute points per Base Level.

signal log_added(text: String, color: Color)
signal stats_changed
signal level_up(kind: String)

const SYS := Color(0.71, 0.97, 0.64)
const INFO := Color(1.0, 0.89, 0.48)
const NPC := Color(0.62, 0.85, 1.0)
const WARN := Color(1.0, 0.62, 0.62)

const ROBES := [Color("4f79b8"), Color("7a5aa6"), Color("4e8f55"), Color("b8642e"), Color("a8423a"), Color("5e6b78")]
const HAIRS := [Color("6a4428"), Color("2a2a32"), Color("d0a85e"), Color("a8423a"), Color("8a909c"), Color("e2dccd")]
const BLOCKED := ["god", "jesus", "christ", "emmanuel", "immanuel", "shaddai", "lord", "yahweh", "jehovah", "holyspirit", "messiah"]
const XPT := [0, 40, 90, 150, 220]  # Base 2..5 thresholds

var main: Node  # set by main.gd
var pname := "Pilgrim"
var hair_style := 0
var hair_col := 0
var robe_col := 0
var lvl := 1
var job := 1
var xp := 0
var jxp := 0
var hp := 120.0
var hp_max := 120
var zeal := 40.0
var zeal_max := 40
var manna := 0.0
var bag := {}
var weary := false
var burden := false
var kos := 0
var snaps := 0
var start_ms := 0
var log_lines: Array = []
var settings := {"auto_loot": true, "reduce_motion": false, "left_handed": false, "dmg_numbers": true, "hud_opacity": 1.0, "reduce_flashing": false, "fx_high": true, "haptics": true}
var minor := false

var font_ui: FontVariation
var font_ui_bold: FontVariation
var font_title: FontVariation
var theme: Theme
var _tex_cache := {}
var player_sheet: ImageTexture
var sprite_tint := Color.WHITE

func _ready() -> void:
	var base := load("res://assets/fonts/Nunito.ttf") as FontFile
	var sym := load("res://assets/fonts/NotoSansSymbols2.ttf") as FontFile
	base.fallbacks = [sym]
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	font_ui = FontVariation.new(); font_ui.base_font = base; font_ui.variation_opentype = {wght: 600}
	font_ui_bold = FontVariation.new(); font_ui_bold.base_font = base; font_ui_bold.variation_opentype = {wght: 850}
	var corm := load("res://assets/fonts/CormorantGaramond.ttf") as FontFile
	corm.fallbacks = [sym]
	font_title = FontVariation.new(); font_title.base_font = corm; font_title.variation_opentype = {wght: 700}
	theme = UIKit.make_theme()
	reset()

func reset() -> void:
	lvl = 1; job = 1; xp = 0; jxp = 0; hp_max = 120; hp = 120; zeal_max = 40; zeal = 40
	manna = 0.0; bag = {}; weary = false; burden = false; kos = 0; snaps = 0
	start_ms = Time.get_ticks_msec(); log_lines = []

func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]

func say(text: String, color: Color = SYS) -> void:
	log_lines.append([text, color])
	if log_lines.size() > 40:
		log_lines.pop_front()
	log_added.emit(text, color)

func name_ok(n: String) -> String:
	n = n.strip_edges()
	var re := RegEx.new(); re.compile("^[A-Za-z][A-Za-z '\\-]{2,15}$")
	if re.search(n) == null:
		return "Please use 3 to 16 letters."
	var key := n.to_lower().replace(" ", "").replace("'", "").replace("-", "")
	for b in BLOCKED:
		if key.contains(b):
			return "That name is reserved. Please choose another."
	return ""

func add_xp(amount: int, job_amount: int = -1, region: String = "") -> void:
	if job_amount < 0:
		job_amount = int(amount * 0.6)
	xp += amount; jxp += job_amount
	while lvl < 5 and xp >= XPT[lvl]:
		lvl += 1; hp_max += 14; hp = hp_max; zeal_max += 5; zeal = zeal_max
		say("Base Level %d! You gain 2 attribute points." % lvl, INFO)
		level_up.emit("Base Level Up!")
	if job < 10 and jxp >= job * 45:
		job += 1
		say("Job Level %d." % job, INFO)
		level_up.emit("Job Level Up!")
	if lvl >= 5 and region == "eden":
		say("Base Level 5: Eden Isle can teach you no further.", INFO)
	stats_changed.emit()

func base_pct() -> float:
	if lvl >= 5:
		return 1.0
	var lo: int = XPT[lvl - 1]
	var hi: int = XPT[lvl]
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)

func job_pct() -> float:
	return clampf(float(jxp - (job - 1) * 45) / 45.0, 0.0, 1.0)

func bag_add(item: String, n: int) -> void:
	bag[item] = int(bag.get(item, 0)) + n
	stats_changed.emit()

func bag_take(item: String) -> bool:
	if int(bag.get(item, 0)) <= 0:
		return false
	bag[item] = int(bag[item]) - 1
	stats_changed.emit()
	return true

func goto(screen: String, data: Dictionary = {}) -> void:
	main.show_screen(screen, data)

## Composite the layered paper-doll sheet (body + tinted robe + tinted hair + staff) into one texture.
func build_player_sheet() -> ImageTexture:
	var body := (load("res://assets/sprites/pilgrim_body.png") as Texture2D).get_image()
	var out := Image.create(body.get_width(), body.get_height(), false, Image.FORMAT_RGBA8)
	out.blend_rect(_converted(body), Rect2i(Vector2i.ZERO, body.get_size()), Vector2i.ZERO)
	out.blend_rect(_tinted("res://assets/sprites/pilgrim_robe.png", ROBES[robe_col]), Rect2i(Vector2i.ZERO, body.get_size()), Vector2i.ZERO)
	out.blend_rect(_tinted("res://assets/sprites/pilgrim_hair_%d.png" % hair_style, HAIRS[hair_col]), Rect2i(Vector2i.ZERO, body.get_size()), Vector2i.ZERO)
	out.blend_rect(_converted((load("res://assets/sprites/pilgrim_staff.png") as Texture2D).get_image()), Rect2i(Vector2i.ZERO, body.get_size()), Vector2i.ZERO)
	player_sheet = ImageTexture.create_from_image(out)
	return player_sheet

func _converted(img: Image) -> Image:
	var c := img.duplicate() as Image
	if c.is_compressed():
		c.decompress()
	c.convert(Image.FORMAT_RGBA8)
	return c

func _tinted(path: String, col: Color) -> Image:
	var img := _converted((load(path) as Texture2D).get_image())
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color(p.r * col.r, p.g * col.g, p.b * col.b, p.a))
	return img

func haptic(ms: int = 20) -> void:
	if settings.get("haptics", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
