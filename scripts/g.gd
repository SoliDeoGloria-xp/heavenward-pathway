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
const CHAT := Color(0.86, 0.86, 1.0)

const ROBES := [Color("4f79b8"), Color("7a5aa6"), Color("4e8f55"), Color("b8642e"), Color("a8423a"), Color("5e6b78")]
const HAIRS := [Color("6a4428"), Color("2a2a32"), Color("d0a85e"), Color("a8423a"), Color("8a909c"), Color("e2dccd")]
const BLOCKED := ["god", "jesus", "christ", "emmanuel", "immanuel", "shaddai", "lord", "yahweh", "jehovah", "holyspirit", "messiah"]
var PROG := {}          # loaded from data/progression.json
var base_cap := 5       # Eden Isle caps Base at 5; world.gd raises it on leaving

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
## Attributes (GDD: Fortitude, Diligence, Steadfastness, Wisdom, Sobriety, Hope). All pilgrims begin equal.
const STATS := ["for", "dil", "ste", "wis", "sob", "hop"]
const STAT_INFO := {
	"for": {"name": "Fortitude", "short": "FOR", "does": "Stronger basic attacks and First Steps.", "plain": "Hit harder"},
	"dil": {"name": "Diligence", "short": "DIL", "does": "Faster attacks.", "plain": "Attack faster"},
	"ste": {"name": "Steadfastness", "short": "STE", "does": "More Health and less damage taken.", "plain": "Stay standing"},
	"wis": {"name": "Wisdom", "short": "WIS", "does": "More Zeal and stronger skills.", "plain": "More skills"},
	"sob": {"name": "Sobriety", "short": "SOB", "does": "Fewer misses; keeps your aim true.", "plain": "Miss less"},
	"hop": {"name": "Hope", "short": "HOP", "does": "More critical hits and faster Zeal recovery.", "plain": "Lucky strikes"}}
const STAT_START := 3
var stat := {}
var stat_pts := 0
## Skills (2 skill points per Job Level). Max levels for the Pilgrim (Novice) job.
const SKILL_INFO := {
	"tend": {"name": "Tend and Keep", "icon": "tend", "max": 1, "zeal": 8, "cd": 3.0, "eden": true, "kind": "active",
		"does": "Tend a plant that needs care. Used only in Eden. [BSB: Genesis 2:15]"},
	"steps": {"name": "First Steps", "icon": "steps", "max": 5, "zeal": 10, "cd": 6.0, "kind": "active",
		"does": "A sure lunge at your target for heavy damage."},
	"refuge": {"name": "Take Refuge", "icon": "refuge", "max": 5, "zeal": 15, "cd": 12.0, "kind": "active",
		"does": "Restores Health. [BSB: Psalm 9:9]"}}
const SKILL_ORDER := ["tend", "steps", "refuge"]
var skill_lv := {}
var skill_pts := 0
## Onboarding: "full" (new to MMOs), "light" (played MMOs), "off" (tips skipped).
var guide := "full"
var tips_seen := {}
var settings := {"auto_loot": true, "reduce_motion": false, "left_handed": false, "dmg_numbers": true, "hud_opacity": 1.0, "reduce_flashing": false, "fx_high": true, "haptics": true}
var minor := false
## World model (GDD v0.3): the Way is solo, Houses and Wilds are shared, Musters are queued.
var marks := 0                 # Fellowship Marks (company rewards, never a penalty for solitude)
var secrets := {}              # map_id -> Array of found secret ids
var muster_party: Array = []   # [{name, role, ai, look:[hair_style, hair_col, robe_col]}]
var house_rested := false
var my_waymarks: Array = []    # [{map, pos, phrase}]
var _sheet_cache := {}

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
	lvl = 1; job = 1; xp = 0; jxp = 0; base_cap = 5; hp_max = 120; hp = 120; zeal_max = 40; zeal = 40
	manna = 0.0; bag = {}; weary = false; burden = false; kos = 0; snaps = 0
	start_ms = Time.get_ticks_msec(); log_lines = []
	marks = 0; secrets = {}; muster_party = []; house_rested = false; my_waymarks = []
	stat = {}
	for k in STATS: stat[k] = STAT_START
	stat_pts = 0; skill_pts = 0; skill_lv = {"tend": 0, "steps": 0, "refuge": 0}; tips_seen = {}
	recalc(); hp = hp_max; zeal = zeal_max

# ------------------------------------------------------------------ derived numbers
## Every stat has one visible job, so the Status window can show "before -> after".
func calc_for(s: Dictionary, base_lv: int) -> Dictionary:
	return {
		"hp": 80 + 14 * (base_lv - 1) + 12 * int(s.ste),
		"zeal": 28 + 5 * (base_lv - 1) + 6 * int(s.wis),
		"atk": 4 + 2 * int(s["for"]) + base_lv,
		"interval": maxf(0.6, 1.2 - 0.04 * int(s.dil)),
		"miss": maxf(0.0, 0.11 - 0.012 * int(s.sob)),
		"crit": 0.06 + 0.015 * int(s.hop),
		"guard": int(s.ste) / 3,
		"regen": 1.0 + 0.15 * int(s.hop),
		"power": 1.0 + 0.05 * (int(s.wis) - STAT_START)}

var d := {}   # current derived numbers
func recalc() -> void:
	d = calc_for(stat, lvl)
	var hp_frac := hp / float(hp_max) if hp_max > 0 else 1.0
	var ze_frac := zeal / float(zeal_max) if zeal_max > 0 else 1.0
	hp_max = d.hp; zeal_max = d.zeal
	hp = clampf(hp_max * hp_frac, 0.0, hp_max); zeal = clampf(zeal_max * ze_frac, 0.0, zeal_max)

func raise_stat(k: String) -> bool:
	if stat_pts <= 0:
		return false
	stat[k] = int(stat[k]) + 1; stat_pts -= 1
	recalc(); haptic(15); stats_changed.emit()
	return true

func reset_stats() -> void:
	var spent := 0
	for k in STATS:
		spent += int(stat[k]) - STAT_START; stat[k] = STAT_START
	stat_pts += spent
	recalc(); stats_changed.emit()

func learn_skill(id: String) -> bool:
	var info: Dictionary = SKILL_INFO[id]
	if skill_pts <= 0 or int(skill_lv.get(id, 0)) >= int(info.max):
		return false
	skill_lv[id] = int(skill_lv.get(id, 0)) + 1; skill_pts -= 1
	say("%s is now level %d." % [info.name, skill_lv[id]], INFO)
	haptic(25); stats_changed.emit()
	return true

func has_skill(id: String) -> bool:
	return int(skill_lv.get(id, 0)) > 0

## Skill numbers at the current level (what the Skills window shows and the world uses).
func skill_num(id: String, lv: int = -1) -> Dictionary:
	if lv < 0:
		lv = int(skill_lv.get(id, 0))
	lv = maxi(lv, 1)
	match id:
		"steps": return {"dmg": int((d.atk * 1.5 + 4 * lv) * d.power), "text": "Deals about %d damage." % int((d.atk * 1.5 + 4 * lv) * d.power)}
		"refuge": return {"heal": int((20 + 10 * lv) * d.power), "text": "Restores %d Health." % int((20 + 10 * lv) * d.power)}
		"tend": return {"text": "Brings one drooping plant back to bloom."}
	return {"text": ""}

func tip_once(id: String) -> bool:
	## true the first time an id is asked for (onboarding tips show once).
	if tips_seen.has(id) or guide == "off":
		return false
	tips_seen[id] = true
	return true

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

func _load_prog() -> void:
	if not PROG.is_empty():
		return
	var f := FileAccess.open("res://data/progression.json", FileAccess.READ)
	PROG = JSON.parse_string(f.get_as_text()) if f else {}
	if PROG.is_empty():
		PROG = {"base_cost": [40, 60, 90, 130, 190, 260, 350, 470, 620], "job_cost": [20, 30, 45, 60, 80, 100, 130, 170, 220],
			"base_after10": {"start": 800, "growth": 1.12}, "job_after10": {"start": 220, "growth": 1.10}, "max_base": 99, "max_job": 50}

## XP needed to go from level L to L+1.
func base_cost(L: int) -> int:
	_load_prog()
	var t: Array = PROG["base_cost"]
	if L <= t.size():
		return int(t[L - 1])
	return int(round(float(PROG["base_after10"]["start"]) * pow(float(PROG["base_after10"]["growth"]), L - t.size())))

func job_cost(L: int) -> int:
	_load_prog()
	var t: Array = PROG["job_cost"]
	if L <= t.size():
		return int(t[L - 1])
	return int(round(float(PROG["job_after10"]["start"]) * pow(float(PROG["job_after10"]["growth"]), L - t.size())))

func base_total(L: int) -> int:   ## cumulative XP at which level L is reached
	var n := 0
	for i in range(1, L):
		n += base_cost(i)
	return n

func add_xp(amount: int, job_amount: int = -1, region: String = "") -> void:
	_load_prog()
	if job_amount < 0:
		job_amount = int(amount * 0.4)
	xp += amount; jxp += job_amount
	while lvl < mini(base_cap, int(PROG["max_base"])) and xp >= base_total(lvl + 1):
		lvl += 1; stat_pts += 2
		recalc(); hp = hp_max; zeal = zeal_max
		say("Base Level %d! +2 attribute points (More → Status)." % lvl, INFO)
		level_up.emit("Base Level Up!")
	var jcap := 10 if base_cap <= 10 else int(PROG["max_job"])
	while job < jcap and jxp >= job_total(job + 1):
		job += 1; skill_pts += 2
		say("Job Level %d! +2 skill points (More → Skills)." % job, INFO)
		level_up.emit("Job Level Up!")
	if lvl >= base_cap and region == "eden":
		say("Base Level %d: Eden Isle can teach you no further." % base_cap, INFO)
	stats_changed.emit()

func job_total(L: int) -> int:
	var n := 0
	for i in range(1, L):
		n += job_cost(i)
	return n

func base_pct() -> float:
	if lvl >= base_cap:
		return 1.0
	var lo := base_total(lvl)
	return clampf(float(xp - lo) / float(base_cost(lvl)), 0.0, 1.0)

func job_pct() -> float:
	var lo := job_total(job)
	return clampf(float(jxp - lo) / float(job_cost(job)), 0.0, 1.0)

## True when the pilgrim has earned the first job change (Base 10 + Job 10).
func first_job_ready() -> bool:
	return lvl >= 10 and job >= 10

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
	player_sheet = build_sheet(hair_style, hair_col, robe_col, true)
	return player_sheet

## Any pilgrim's sheet (other players, party members, passing pilgrims). Cached per look.
func build_sheet(hs: int, hc: int, rc: int, staff: bool = true) -> ImageTexture:
	var key := "%d_%d_%d_%s" % [hs, hc, rc, staff]
	if _sheet_cache.has(key):
		return _sheet_cache[key]
	var body := (load("res://assets/sprites/pilgrim_body.png") as Texture2D).get_image()
	var out := Image.create(body.get_width(), body.get_height(), false, Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i.ZERO, body.get_size())
	out.blend_rect(_converted(body), r, Vector2i.ZERO)
	out.blend_rect(_tinted("res://assets/sprites/pilgrim_robe.png", ROBES[rc % ROBES.size()]), r, Vector2i.ZERO)
	out.blend_rect(_tinted("res://assets/sprites/pilgrim_hair_%d.png" % (hs % 3), HAIRS[hc % HAIRS.size()]), r, Vector2i.ZERO)
	if staff:
		out.blend_rect(_converted((load("res://assets/sprites/pilgrim_staff.png") as Texture2D).get_image()), r, Vector2i.ZERO)
	var t := ImageTexture.create_from_image(out)
	_sheet_cache[key] = t
	return t

func secret_found(map_id: String, id: String) -> bool:
	return id in secrets.get(map_id, [])

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

## Haptics. Android needs the VIBRATE permission (export preset). Mobile browsers use navigator.vibrate.
## Light 10 ms = UI tap; 20-30 = confirm or hit; 40+ = level up, KO.
func haptic(ms: int = 20) -> void:
	if not settings.get("haptics", true):
		return
	if OS.has_feature("web"):
		if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
			JavaScriptBridge.eval("if (navigator.vibrate) navigator.vibrate(%d);" % ms, true)
	elif OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(ms)

func haptic_pattern(kind: String) -> void:
	match kind:
		"tap": haptic(10)
		"confirm": haptic(22)
		"hit": haptic(28)
		"hurt": haptic(40)
		"level":
			haptic(35)
			get_tree().create_timer(0.12).timeout.connect(func(): haptic(35))
			get_tree().create_timer(0.24).timeout.connect(func(): haptic(60))
		"ko": haptic(90)
