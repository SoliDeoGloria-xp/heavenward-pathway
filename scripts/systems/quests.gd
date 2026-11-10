class_name Quests
extends RefCounted
## Objective runner. Objectives, side objectives and their XP come from data/maps/<id>.json, so a
## chapter is added by writing data. Types: zone, path, exit, talk, interact, choice, kill, boss,
## check, travel, and script (finished by a map script calling complete()).
## Also owns secrets and Waymarks.

const ZONE_RADIUS := 1.6
const REST_SECONDS := 4.0          # how long "sit and rest" must be held
const MARK_HEIGHT := 2.6
const TIP_SECONDS := 7.0
const ENT_TYPES := ["talk", "interact", "choice", "travel", "boss", "script", "exit"]

var w: World
var def: Dictionary = {}
var objectives: Array = []
var side: Array = []
var done_side: Array = []
var obj_idx := 0
var kills := 0                     # kills counted toward the current objective
var path_i := 0                    # next waypoint of a path objective
var rest_t := 0.0
var busy := false                  # a dialogue or UI for the current objective is open
var fighting := false              # the current boss objective's fight has begun
var secret_ids: Array = []
var quest_mark: Label3D
var zone_fx: Node3D

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ loading and progress
func load_map(map_def: Dictionary) -> void:
	def = map_def
	objectives = def.get("objectives", []).duplicate(true)
	side = def.get("side", []).duplicate(true)
	var repeat: bool = def.has("repeat_flag") and G.flags.has(def.repeat_flag)
	for o in objectives + side:
		if repeat:
			o.xp = [0, 0]   # a cleared side-map can be walked again, but pays its quest XP once
		for k in ["zone", "at"]:
			if o.has(k):
				o[k] = World.v3(o[k])
		if o.has("points"):
			o.points = o.points.map(World.v3)
		o["base_text"] = o.text
	var st: Dictionary = G.map_state.get(w.map_id, {}) if def.get("resumable", false) else {}
	obj_idx = mini(int(st.get("idx", 0)), objectives.size())
	done_side = st.get("side", []).duplicate()

## Called once the HUD exists: replays finished objectives' world changes, then starts the current one.
func begin() -> void:
	for i in obj_idx:
		apply(objectives[i].get("on_start", {}), true)
		apply(objectives[i].get("on_fight", {}), true)
		apply(objectives[i].get("on_done", {}), true)
	for sd in side:
		if sd.id in done_side:
			apply(sd.get("on_done", {}), true)
			if sd.get("page", false):
				w.show_ent(sd.ent, false)
	_start()

func cur() -> Dictionary:
	return objectives[obj_idx] if obj_idx < objectives.size() else {}

func cur_obj() -> String:
	return cur().get("id", "")

func _start() -> void:
	kills = 0; path_i = 0; rest_t = 0.0; busy = false; fighting = false
	var o := cur()
	if o.is_empty():
		_update_quest(); return
	if o.has("chapter"):
		G.say("Chapter: %s" % o.chapter, G.INFO)
	apply(o.get("on_start", {}))
	w.combat.spawn_group(o.id)
	_refresh_text()
	_update_quest()
	_lesson(o)
	w.lessons._on_new_obj()
	if o.type == "travel" and G.flags.has(o.until):
		complete.call_deferred()
	elif o.type == "boss" and not o.has("ent"):
		_begin_fight(o)
	elif o.has("dialog_start"):
		busy = true
		w.scene.play(o.dialog_start, func() -> void: busy = false)

func _lesson(o: Dictionary) -> void:
	var tips: Dictionary = G.data("lessons").get(w.map_id, {})
	if tips.has(o.id) and G.tip_once("lesson_%s_%s" % [w.map_id, o.id]):
		var tip: Dictionary = tips[o.id]
		w.hud.coach.tip(tip.text, func() -> Variant: return w.hud.get(tip.target), TIP_SECONDS)

## Finish the current objective: pay its XP, apply its effects, move on.
func complete() -> void:
	var o := cur()
	if o.is_empty():
		return
	busy = false
	var xv: Array = o.get("xp", [0, 0])
	if int(xv[0]) > 0 or int(xv[1]) > 0:
		G.add_xp(int(xv[0]), int(xv[1]), w.map_id)
	G.haptic(18); G.sfx("quest")
	var fx: Dictionary = o.get("on_done", {})
	apply(fx)
	obj_idx += 1
	_save()
	if o.type == "exit":
		leave(o.to)
	elif fx.has("dialog"):
		busy = true
		w.scene.play(fx.dialog, _after_done.bind(fx))
	else:
		_after_done(fx)

func _after_done(fx: Dictionary) -> void:
	if fx.has("screen"):
		w.ending = true
		G.goto(fx.screen)
		return
	_start()
	var o := cur()
	if not o.is_empty():
		G.say("Quest: " + o.text, G.INFO)
		w.hud.quest_toast(o.text)

func _save() -> void:
	if def.get("resumable", false):
		G.map_state[w.map_id] = {"idx": obj_idx, "side": done_side}
		G.save_game()

func leave(to: String) -> void:
	w.ending = true; G.sfx("warp")
	G.goto("world", {"map": to})

# ------------------------------------------------------------------ effects (declarative, so progress can be replayed after a load)
func apply(fx: Dictionary, replay: bool = false) -> void:
	for id in fx.get("show", []):
		w.show_ent(id, true)
	for id in fx.get("hide", []):
		w.show_ent(id, false)
	if fx.has("flag"):
		G.flags[fx.flag] = true
	if fx.has("burden"):
		G.burden = fx.burden
	if fx.has("armor"):
		G.armor = true; G.recalc()
	if fx.get("unlock", "") == "snapshot":
		w.snapshot_unlocked = true
	if replay:
		return
	if fx.has("say"):
		G.say(fx.say, G.INFO)
	for item in fx.get("give", {}).keys():
		G.bag_add(item, int(fx.give[item])); G.say("You got %s." % item, G.INFO)
	if fx.has("manna"):
		G.manna += float(fx.manna)
	if fx.has("learn") and not G.has_skill(fx.learn):   # a skill the story itself teaches: free, level 1
		G.skill_lv[fx.learn] = 1; G.recalc()
		G.say("You learned %s. It is on your skill bar." % G.SKILL_INFO[fx.learn].name, G.INFO)
	if fx.get("heal", false):
		G.hp = G.hp_max; G.zeal = G.zeal_max
	if fx.get("weary", false):
		w.combat.make_weary()
	if fx.has("call"):
		_call(fx.call)
	if fx.has("branch") and G.flags.has(fx.branch.flag):
		apply(fx.branch.get("then", {}))
	elif fx.has("branch"):
		apply(fx.branch.get("else", {}))
	G.stats_changed.emit()
	if w.hud:
		w.hud.refresh()

## "call" effects name a method on the map's script, the coach, or the scene player.
func _call(method: String) -> void:
	for target in [w.map, w.lessons, w.scene, w.combat]:
		if target != null and target.has_method(method):
			target.call(method)
			return
	push_warning("Objective effect calls unknown method: " + method)

# ------------------------------------------------------------------ per-frame checks
func tick(delta: float) -> void:
	var o := cur()
	if o.is_empty() or busy or w.ending:
		return
	match o.type:
		"zone", "exit":
			if _near(o.zone):
				_trigger(o)
		"path":
			if path_i < o.points.size() and _near(o.points[path_i]):
				path_i += 1
				w.kit._sparkle(w.player.position + Vector3(0, 0.6, 0))
				_refresh_text(); _update_quest()
			_check_path(o)
		"check":
			if _check(String(o.check), delta):
				complete()

func _near(p: Vector3) -> bool:
	return Vector2(w.player.position.x - p.x, w.player.position.z - p.z).length() < ZONE_RADIUS

func _check_path(o: Dictionary) -> void:
	if path_i >= o.points.size() and kills >= int(o.get("kills", 0)):
		_trigger(o)

func _check(what: String, delta: float) -> bool:
	if what == "stat_pts":
		return G.stat_pts == 0
	if what == "rested":
		if w.sitting:   # total time counts, so a Slothling's interruption does not waste the rest
			rest_t += delta
		return rest_t >= REST_SECONDS
	if what.begins_with("skill:"):
		return G.has_skill(what.trim_prefix("skill:"))
	push_warning("Unknown objective check: " + what)
	return false

## The objective's condition is met: play its dialogue (if any), then complete.
func _trigger(o: Dictionary) -> void:
	if o.has("dialog"):
		busy = true
		w.scene.play(o.dialog, complete)
	else:
		complete()

func on_kill(m: Dictionary) -> void:
	var o := cur()
	if o.is_empty():
		return
	if o.type == "kill" or (o.type == "path" and o.has("kills")):
		kills += 1
		_refresh_text(); _update_quest()
		if o.type == "kill" and kills >= int(o.count):
			complete()
	if o.type == "boss" and m.get("boss", false):
		complete()

func _refresh_text() -> void:
	var o := cur()
	match o.type:
		"kill": o.text = "%s (%d/%d)" % [o.base_text, mini(kills, int(o.count)), int(o.count)]
		"path":
			o.text = "%s (%d/%d)" % [o.base_text, path_i, o.points.size()]
			if o.has("kills"):
				o.text += " · foes %d/%d" % [mini(kills, int(o.kills)), int(o.kills)]

# ------------------------------------------------------------------ entities
## An interactable was used. Returns true when an objective, side objective or idle dialogue handled it.
func use_ent(e: Dictionary) -> bool:
	if busy:
		return true
	var o := cur()
	if not o.is_empty() and o.get("ent", "") == e.id and o.type in ENT_TYPES and o.type != "script":
		_use_objective(o)
		return true
	for sd in side:
		if sd.get("ent", "") == e.id and not sd.id in done_side:
			busy = true
			w.scene.play(sd.dialog, _side_done.bind(sd))
			return true
	if e.has("dialog"):
		busy = true
		w.scene.play(e.dialog, func() -> void: busy = false)
		return true
	return false

func _use_objective(o: Dictionary) -> void:
	if o.type == "exit":
		return   # reached by walking into its zone
	if o.type == "boss" and fighting:
		return
	if o.get("needs", "") == "first_job" and not G.first_job_ready():
		busy = true
		w.scene.play("palace.not_ready", func() -> void: busy = false)
		return
	busy = true
	var next := func() -> void: _after_dialog(o)
	if o.has("dialog") and not (o.type == "travel" and G.flags.has("seen_" + o.id)):
		G.flags["seen_" + o.id] = true
		w.scene.play(o.dialog, next)
	else:
		next.call()

func _after_dialog(o: Dictionary) -> void:
	match o.get("ui", ""):
		"word_study": w.hud.word_study(complete, w.map_id)
		"calling_trial": w.hud.calling(true, func(id: String) -> void: G.trial_job = id; travel_go())
		"calling": w.hud.calling(false, func(id: String) -> void: G.change_job(id); w.refresh_player_sheet(); complete())
		"muster": w.hud.muster_board()
		_:
			if o.type == "travel":
				travel_go()
			elif o.type == "boss":
				_begin_fight(o)
			else:
				complete()

## The UI closed without a choice (for example the player backed out of the Calling window).
func ui_cancelled() -> void:
	busy = false

func _begin_fight(o: Dictionary) -> void:
	busy = false; fighting = true
	apply(o.get("on_fight", {}))
	w.combat.spawn_boss(String(o.mob), o.at)
	_update_quest()

func travel_go() -> void:
	_save()
	leave(cur().to)

func _side_done(sd: Dictionary) -> void:
	busy = false
	done_side.append(sd.id)
	var xv: Array = sd.get("xp", [0, 0])
	G.add_xp(int(xv[0]), int(xv[1]), w.map_id)
	apply(sd.get("on_done", {}))
	if sd.get("page", false):
		w.show_ent(sd.ent, false)
		G.flags["page_" + w.map_id] = true; G.sfx("page")
		G.say("Dreamer's Page found (%d of %d). They are kept in More → The Way." % [pages_found(), G.data("acts").order.size() - 1], G.INFO)
	else:
		G.say("Done: %s" % sd.text, G.INFO)
	_save()
	_update_quest()

static func pages_found() -> int:
	var n := 0
	for k in G.flags.keys():
		if String(k).begins_with("page_"):
			n += 1
	return n

# ------------------------------------------------------------------ quest marker and auto-path
func _update_quest() -> void:
	if quest_mark:
		quest_mark.queue_free(); quest_mark = null
	if zone_fx:
		zone_fx.queue_free(); zone_fx = null
	var o := cur()
	if o.is_empty():
		w.hud.set_quest(""); return
	w.hud.set_quest(o.text)
	var q: Variant = quest_target()
	if q is Dictionary:
		var tall: bool = q.id in ["fig", "trees"]
		quest_mark = w.kit._label3d("!", q.pos + Vector3(0, MARK_HEIGHT + (0.7 if tall else 0.0), 0), Color("ffd400"), 90)
		quest_mark.outline_modulate = Color("3a2a00")
	elif q is Vector3:
		zone_fx = w.kit.zone_marker(q)

## Where the current objective wants the player: an entity (Dictionary), a point (Vector3) or null.
func quest_target() -> Variant:
	var o := cur()
	if o.is_empty() or (o.type == "boss" and fighting):
		return null
	if o.type == "path":
		if path_i < o.points.size():
			return o.points[path_i]
		return null
	if o.has("ent") and not w.ent(o.ent).is_empty() and not w.ent(o.ent).hidden and o.type != "exit":
		return w.ent(o.ent)
	if o.has("zone"):
		return o.zone
	return null

func auto_path_quest() -> void:
	var q: Variant = quest_target()
	if q is Dictionary:
		w.pending = q; w.move_target = w._approach_point(q.pos)
		G.say("Auto-path: %s" % q.name, G.SYS)
	elif q is Vector3:
		w.move_target = q; w.pending = null
	elif w.is_combat():
		w.combat.attack_pressed()

# ------------------------------------------------------------------ secrets on the Way
func _add_secret(id: String, pos: Vector3, title: String, text: String, reward: Dictionary) -> void:
	secret_ids.append(id)
	if G.secret_found(w.map_id, id):
		return
	var n := Node3D.new(); n.position = pos; w.add_child(n)
	var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/star.png"); g.pixel_size = 0.004; g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.shaded = false; g.transparent = true; g.modulate = Color(1, 0.97, 0.8, 0.0); g.position.y = 0.55; n.add_child(g)
	n.set_meta("glint", g)
	var e := w._add_ent("secret_" + id, "Something glints", pos, n, "Search", "eye", _find_secret.bind(id, title, text, reward))
	e["kind"] = "secret"


func _find_secret(id: String, title: String, text: String, reward: Dictionary) -> void:
	var e := w.ent("secret_" + id)
	if e.is_empty() or e.hidden:
		return
	w.show_ent("secret_" + id, false)
	var found: Array = G.secrets.get(w.map_id, [])
	found.append(id); G.secrets[w.map_id] = found
	w.kit._sparkle(e.pos + Vector3(0, 0.6, 0), Color("fff2b0"))
	Fx.ring(w, e.pos, Color(1, 0.95, 0.7), 2.0, 0.5)
	if reward.has("item"):
		G.bag_add(reward.item, 1); w.kit._item_pop("scroll")
	if reward.has("xp"):
		G.add_xp(int(reward.xp), int(reward.get("jxp", -1)), w.map_id)
	if reward.has("manna"):
		G.manna += float(reward.manna)
	G.say("Secret found (%d/%d): %s" % [found.size(), secret_ids.size(), title], G.INFO)
	w.hud.secret_card(title, text, found.size(), secret_ids.size())
	G.haptic(30)


func secrets_text() -> String:
	if secret_ids.is_empty():
		return ""
	return "✦ %d/%d" % [G.secrets.get(w.map_id, []).size(), secret_ids.size()]


# ------------------------------------------------------------------ Waymarks (after the pillar at the By-path stile)
var waymark_phrases: Array = ["Beware: danger ahead", "Rest here", "Look closely here", "Keep to the narrow way", "Well done, pilgrim!",
	"Remember [BSB: Psalm 46:1]", "Read slowly [BSB: Psalm 119:105]"]


func _add_waymark(pos: Vector3, phrase: String, author: String, thanks: int) -> Dictionary:
	var n := Node3D.new(); n.position = pos; w.add_child(n)
	w.kit.prop("waymark", pos).reparent(n)
	var wm := {"phrase": phrase, "author": author, "thanks": thanks, "thanked": false, "mine": author == G.pname}
	var e := w._add_ent("waymark_%d" % w.ents.size(), "Waymark", pos, n, "Read", "scroll", func(): w.hud.waymark_read(wm))
	e["kind"] = "waymark"
	return wm


func place_waymark(phrase: String) -> void:
	var p := w.player.position + w.pact.facing.normalized() * 1.3
	p.y = 0.0
	_add_waymark(p, phrase, G.pname, 0)
	G.my_waymarks.append({"map": w.map_id, "pos": p, "phrase": phrase})
	w.kit._sparkle(p + Vector3(0, 1.2, 0), Color("bfe4ff"))
	G.say("You raised a Waymark: \"%s\". Pilgrims who pass this way will see it." % phrase, G.INFO)


func _glint_tick() -> void:
	for e in w.ents:
		if e.get("kind", "") != "secret" or e.hidden or e.node == null:
			continue
		var g: Sprite3D = e.node.get_meta("glint")
		var d := Vector2(w.player.position.x - e.pos.x, w.player.position.z - e.pos.z).length()
		var near := clampf(1.0 - (d - 2.0) / 6.0, 0.0, 1.0)
		g.modulate.a = near * (0.55 + 0.45 * sin(w.t * 4.0 + e.pos.x))
		g.rotation.z = w.t * 0.8
