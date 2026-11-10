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
const JOB_TINT_MIX := 0.65
const BLOCKED := ["god", "jesus", "christ", "emmanuel", "immanuel", "shaddai", "lord", "yahweh", "jehovah", "holyspirit", "messiah"]
## Single-player build: online-only UI (Trading Board, Muster matchmaking, friends) is hidden, not deleted.
const ONLINE := false
## Internal-testing switch: lets testers bypass Lord's Day Mode from Settings. Set false for public launch.
const DEV_UNLOCK := true
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1
const PILGRIM := "pilgrim"
const SUNDAY := 0
const TEXT_SCALES := [1.0, 1.1, 1.2]
var PROG := {}          # loaded from data/progression.json
var base_cap := 5       # Eden Isle caps Base at 5; world.gd raises it on leaving
var SKILL_INFO := {}    # data/skills.json: id -> {name, icon, max, zeal, cd, kind, job, fx, does}
var SKILL_ORDER: Array = []
var JOBS := {}          # data/jobs.json: id -> {name, role, tint, blurb, skills}
var JOB_ORDER: Array = []
var MOBS := {}          # data/mobs.json
var audio: AudioHub

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
## Skills (2 skill points per Job Level) are defined in data/skills.json.
var skill_lv := {}
var skill_pts := 0
## Onboarding: "full" (new to MMOs), "light" (played MMOs), "off" (tips skipped).
var guide := "full"
var tips_seen := {}
var settings := {"auto_loot": true, "reduce_motion": false, "left_handed": false, "dmg_numbers": true, "hud_opacity": 1.0, "reduce_flashing": false, "fx_high": true, "haptics": true,
	"music_vol": 0.7, "sfx_vol": 0.9, "text_size": 0.0, "lords_day_bypass": false}
var minor := false
## World model (GDD v0.3): the Way is solo, Houses and Wilds are shared, Musters are queued.
var marks := 0                 # Fellowship Marks (company rewards, never a penalty for solitude)
var secrets := {}              # map_id -> Array of found secret ids
var muster_party: Array = []   # [{name, role, ai, look:[hair_style, hair_col, robe_col]}]
var house_rested := false
var my_waymarks: Array = []    # [{map, pos, phrase}]
var _sheet_cache := {}
## Story state (all saved): the Calling, flags set by objectives, per-map objective progress.
var job_id := PILGRIM
var trial_job := ""             # job being tried in the Calling trial (its first skill is lent for the fight)
var armor := false              # the whole Armor of God, given at the Palace, the same for every pilgrim
var flags := {}
var map_state := {}             # map_id -> {"idx": int, "side": [ids]}
var cur_map := "eden"
var lamb_name := ""
var ledger := {"quest": [0, 0], "mob": [0, 0]}   # [base, job] XP by source, for pacing checks
var act_xp := {}                # act id -> [base, job] quest XP earned there
var cur_act := "eden"
var played_ms := 0              # play time carried across saves
var time_scale := 1.0           # 1 in play; the autotest runs faster
var _data_cache := {}
var _overrides := {}            # placeholder path -> verified art path (data/asset_overrides.json)

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
	_load_data()
	audio = AudioHub.new(); add_child(audio)
	load_settings()
	reset()

## Read a JSON file under res://data once.
func data(name: String) -> Variant:
	if not _data_cache.has(name):
		var f := FileAccess.open("res://data/%s.json" % name, FileAccess.READ)
		_data_cache[name] = JSON.parse_string(f.get_as_text()) if f else null
		if _data_cache[name] == null:
			push_error("Missing or invalid data file: %s.json" % name)
	return _data_cache[name]

func _load_data() -> void:
	_load_prog()
	var sk: Dictionary = data("skills")
	SKILL_ORDER = sk.order; SKILL_INFO = sk.skills
	var jb: Dictionary = data("jobs")
	JOB_ORDER = jb.order; JOBS = jb.jobs
	MOBS = data("mobs")
	_overrides = data("asset_overrides")

func reset() -> void:
	lvl = 1; job = 1; xp = 0; jxp = 0; base_cap = 5; hp_max = 120; hp = 120; zeal_max = 40; zeal = 40
	manna = 0.0; bag = {}; weary = false; burden = false; kos = 0; snaps = 0
	start_ms = Time.get_ticks_msec(); log_lines = []
	marks = 0; secrets = {}; muster_party = []; house_rested = false; my_waymarks = []
	stat = {}
	for k in STATS: stat[k] = STAT_START
	stat_pts = 0; skill_pts = 0; skill_lv = {}; tips_seen = {}
	job_id = PILGRIM; trial_job = ""; armor = false; flags = {}; map_state = {}; cur_map = "eden"; lamb_name = ""
	ledger = {"quest": [0, 0], "mob": [0, 0]}; act_xp = {}; cur_act = "eden"; played_ms = 0
	_sheet_cache = {}; player_sheet = null
	recalc(); hp = hp_max; zeal = zeal_max

# ------------------------------------------------------------------ derived numbers
## Every stat has one visible job, so the Status window can show "before -> after".
func calc_for(s: Dictionary, base_lv: int) -> Dictionary:
	# Armor of God and Steady Footing both add a flat guard (numbers in progression.json).
	var guard_bonus := (int(PROG.get("armor_guard", 0)) if armor else 0) + int(skill_lv.get("steady", 0))
	return {
		"hp": 80 + 14 * (base_lv - 1) + 12 * int(s.ste),
		"zeal": 28 + 5 * (base_lv - 1) + 6 * int(s.wis),
		"atk": 4 + 2 * int(s["for"]) + base_lv,
		"interval": maxf(0.6, 1.2 - 0.04 * int(s.dil)),
		"miss": maxf(0.0, 0.11 - 0.012 * int(s.sob)),
		"crit": 0.06 + 0.015 * int(s.hop),
		"guard": int(s.ste) / 3 + guard_bonus,
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
	recalc()
	say("%s is now level %d." % [info.name, skill_lv[id]], INFO)
	haptic(25); stats_changed.emit()
	return true

func has_skill(id: String) -> bool:
	return int(skill_lv.get(id, 0)) > 0

## A skill shows in the Skills window once its job matches and its story lesson (if any) has been given.
func skill_open(id: String) -> bool:
	var info: Dictionary = SKILL_INFO[id]
	if info.job != PILGRIM and info.job != job_id:
		return false
	return not info.has("needs") or flags.has(info.needs)

## Skills on a bar page: page 0 = Pilgrim skills, page 1 = the Calling's skills (or the one lent for a trial).
func page_skills(page: int, in_eden: bool) -> Array:
	var out: Array = []
	for id in SKILL_ORDER:
		var info: Dictionary = SKILL_INFO[id]
		var mine: bool = info.job == PILGRIM if page == 0 else (info.job == job_id and job_id != PILGRIM)
		var lent: bool = page == 1 and trial_job != "" and JOBS[trial_job].skills[0] == id
		if info.kind != "active" or bool(info.get("eden", false)) != in_eden:
			continue
		if (mine and has_skill(id)) or lent:
			out.append(id)
	return out

## Skill numbers at a level (what the Skills window shows and combat uses). Shapes come from the skill's "fx".
func skill_num(id: String, lv: int = -1) -> Dictionary:
	if lv < 0:
		lv = int(skill_lv.get(id, 0))
	lv = maxi(lv, 1)
	var fx: Dictionary = SKILL_INFO[id].fx
	var per: float = float(fx.get("per_lv", 0.0)) * lv
	match fx.type:
		"strike", "aoe":
			var dmg := int((d.atk * float(fx.mult) + per) * d.power)
			return {"dmg": dmg, "text": "Deals about %d damage%s." % [dmg, " to every foe nearby" if fx.type == "aoe" else ""]}
		"heal":
			var heal := int((float(fx.base) + per) * d.power)
			return {"heal": heal, "text": "Restores %d Health." % heal}
		"regen":
			var z := int(float(fx.base) + per)
			return {"zeal": z, "text": "Restores %d Zeal over %d s." % [z, int(fx.secs)]}
		"buff":
			var add: float = float(fx.add) + per
			return {"add": add, "text": String(fx.text) % [add * float(fx.get("show_mult", 1.0)), int(fx.secs)]}
		"passive":
			return {"text": String(fx.text) % int(per)}
	return {"text": String(fx.get("text", ""))}

func tip_once(id: String) -> bool:
	## true the first time an id is asked for (onboarding tips show once).
	if tips_seen.has(id) or guide == "off":
		return false
	tips_seen[id] = true
	return true

## Textures go through the asset overrides so verified art replaces a placeholder without code changes.
func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		var real: String = _overrides.get(path, path)
		_tex_cache[path] = load(real if ResourceLoader.exists(real) else path)
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
	if job_id != PILGRIM:   # first job: 220 x 1.10^(JL-9), from the design doc
		return int(round(float(PROG["job_after10"]["start"]) * pow(float(PROG["job_after10"]["growth"]), L - t.size())))
	if L <= t.size():
		return int(t[L - 1])
	return int(round(float(PROG["job_after10"]["start"]) * pow(float(PROG["job_after10"]["growth"]), L - t.size())))

func base_total(L: int) -> int:   ## cumulative XP at which level L is reached
	var n := 0
	for i in range(1, L):
		n += base_cost(i)
	return n

## src is "quest" (designed budget) or "mob" (optional extra); the ledger lets tests check pacing.
func add_xp(amount: int, job_amount: int = -1, region: String = "", src: String = "quest") -> void:
	_load_prog()
	if job_amount < 0:
		job_amount = int(amount * 0.4)
	xp += amount; jxp += job_amount
	ledger[src][0] += amount; ledger[src][1] += job_amount
	if src == "quest":
		var a: Array = act_xp.get(cur_act, [0, 0])
		act_xp[cur_act] = [int(a[0]) + amount, int(a[1]) + job_amount]
	while lvl < mini(base_cap, int(PROG["max_base"])) and xp >= base_total(lvl + 1):
		lvl += 1; stat_pts += 2
		recalc(); hp = hp_max; zeal = zeal_max
		say("Base Level %d! +2 attribute points (More → Status)." % lvl, INFO)
		level_up.emit("Base Level Up!")
	var jcap := int(PROG["first_job_gate"]["job"]) if job_id == PILGRIM else int(PROG["max_job"])
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
	var gate: Dictionary = PROG["first_job_gate"]
	return lvl >= int(gate.base) and job >= int(gate.job)

## Highest Base Level the current map and Calling allow.
func cap_for(map_cap: int) -> int:
	return map_cap if job_id == PILGRIM else int(PROG["max_base"])

## The Calling: Base Level carries over, Job Level starts again at 1 in the new job.
func change_job(id: String) -> void:
	job_id = id; trial_job = ""; job = 1; jxp = 0; skill_pts += 2
	base_cap = int(PROG["max_base"])
	player_sheet = null; build_player_sheet()
	say("You are called as a %s. Job Level 1. +2 skill points (More → Skills)." % JOBS[id].name, INFO)
	level_up.emit("Calling: %s" % JOBS[id].name)
	stats_changed.emit()

func job_name() -> String:
	return "Pilgrim" if job_id == PILGRIM else String(JOBS[job_id].name)

## Dialogue from data/dialogue.json with the pilgrim's and the lamb's names filled in.
func dialog(id: String) -> Array:
	var all: Dictionary = data("dialogue")
	if not all.has(id):
		push_error("Unknown dialogue: " + id)
		return []
	var out: Array = []
	for line in all[id]:
		var L: Dictionary = (line as Dictionary).duplicate(true)
		if (L.has("if") and not flags.has(L["if"])) or (L.has("unless") and flags.has(L["unless"])):
			continue
		if L.who == "$player":
			L.who = pname
		L.text = String(L.text).replace("{name}", pname).replace("{lamb}", lamb_name if lamb_name != "" else "the lamb")
		for c in L.get("choices", []):
			if c.has("flag"):
				var f: String = c.flag
				c["fn"] = func() -> void: flags[f] = true
		out.append(L)
	return out

func sfx(id: String) -> void:
	audio.sfx(id)

# ------------------------------------------------------------------ Lord's Day Mode
## On the Lord's Day (device local time) the game is limited to quiet Scripture reading (GDD: mandatory).
func lords_day() -> bool:
	if settings.get("lords_day_bypass", false) and DEV_UNLOCK:
		return false
	return int(Time.get_datetime_dict_from_system().weekday) == SUNDAY

# ------------------------------------------------------------------ save / continue (one local slot)
const SAVED := ["pname", "hair_style", "hair_col", "robe_col", "lvl", "job", "xp", "jxp", "manna", "bag", "weary", "burden", "kos", "snaps",
	"stat", "stat_pts", "skill_lv", "skill_pts", "guide", "tips_seen", "minor", "marks", "secrets", "house_rested",
	"job_id", "armor", "flags", "map_state", "cur_map", "lamb_name", "ledger", "act_xp", "cur_act"]
const SAVED_INTS := ["hair_style", "hair_col", "robe_col", "lvl", "job", "xp", "jxp", "kos", "snaps", "stat_pts", "skill_pts", "marks"]

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var out := {"version": SAVE_VERSION, "played_ms": played_ms + Time.get_ticks_msec() - start_ms, "lords_day_mode": lords_day()}
	for k in SAVED:
		out[k] = get(k)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))

## Returns false when there is no usable save (the title then offers only a new game).
func load_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d0: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if not (d0 is Dictionary) or int(d0.get("version", 0)) != SAVE_VERSION:
		return false
	reset()
	for k in SAVED:
		if d0.has(k):
			set(k, int(d0[k]) if k in SAVED_INTS else d0[k])
	for k in stat.keys(): stat[k] = int(stat[k])            # JSON numbers load as floats
	for k in skill_lv.keys(): skill_lv[k] = int(skill_lv[k])
	for k in bag.keys(): bag[k] = int(bag[k])
	played_ms = int(d0.get("played_ms", 0)); start_ms = Time.get_ticks_msec()
	base_cap = cap_for(int(PROG["pilgrim_base_cap"]))
	recalc(); hp = hp_max; zeal = zeal_max
	build_player_sheet()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func minutes_played() -> int:
	return maxi(1, int((played_ms + Time.get_ticks_msec() - start_ms) / 60000.0))

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func load_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var d0: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if d0 is Dictionary:
		for k in settings.keys():
			if d0.has(k) and typeof(d0[k]) == typeof(settings[k]):
				settings[k] = d0[k]
	apply_settings()

func apply_settings() -> void:
	audio.set_volumes(float(settings.music_vol), float(settings.sfx_vol))
	get_window().content_scale_factor = TEXT_SCALES[clampi(int(settings.text_size), 0, TEXT_SCALES.size() - 1)]

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
	var robe: Color = ROBES[robe_col % ROBES.size()]
	if job_id != PILGRIM:   # the Calling shows on the robe: the chosen colour leans toward the job's
		robe = robe.lerp(Color(String(JOBS[job_id].tint)), JOB_TINT_MIX)
	player_sheet = build_sheet(hair_style, hair_col, robe_col, true, robe)
	return player_sheet

## Any pilgrim's sheet (other players, party members, passing pilgrims). Cached per look.
func build_sheet(hs: int, hc: int, rc: int, staff: bool = true, robe: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	if robe.a == 0.0:
		robe = ROBES[rc % ROBES.size()]
	var key := "%d_%d_%s_%s" % [hs, hc, robe.to_html(), staff]
	if _sheet_cache.has(key):
		return _sheet_cache[key]
	var body := (load("res://assets/sprites/pilgrim_body.png") as Texture2D).get_image()
	var out := Image.create(body.get_width(), body.get_height(), false, Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i.ZERO, body.get_size())
	out.blend_rect(_converted(body), r, Vector2i.ZERO)
	out.blend_rect(_tinted("res://assets/sprites/pilgrim_robe.png", robe), r, Vector2i.ZERO)
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
