class_name Lessons
extends RefCounted
## Coach text: the Dreamer's guided lessons and first-fight tips.

var w: World

func _init(world: World) -> void:
	w = world

# ======================================================================
# Onboarding: the Dreamer's guided Prologue (combat-free Eden), the Fall played out
# in the garden, waking in the City, and first-fight lessons.
# Pattern (from OSRS Tutorial Island, RO Training Grounds, Ragnarok Origin, Genshin):
# one guide voice, one thing at a time, learn by doing, every lesson ends in a reward.
# ======================================================================
const DREAMER := "The Dreamer"

const BSB := " · text pulled at build time]"


func _talk_dreamer() -> void:
	var o: Dictionary = w.quests.objectives[w.quests.obj_idx] if w.quests.obj_idx < w.quests.objectives.size() else {"text": "Behold the two trees"}
	w.hud.run_dialog([{"who": DREAMER, "text": "Your next step: %s. Tap the quest box on the left and you will walk there by yourself. The Pilgrim's Guide in More answers every question." % o.text}], func(): pass)


# ------------------------------------------------------------------ Eden lessons
func _eden_intro() -> void:
	if not w.is_inside_tree():
		return
	w.hud.run_dialog([
		{"who": DREAMER, "text": "Here we are, inside my dream. This is Eden, the garden as it was in the beginning. Nothing here can harm you, so it is a good place to learn how to walk the Way.",
			"choices": [{"t": "Why am I here?"}, {"t": "I'm ready. Show me.", "goto": 2}]},
		{"who": DREAMER, "text": "Soon the dream will turn, and you will wake in a city with a great burden on your back. You will need to flee from it to the Wicket Gate. All you learn in this garden, you will use on that road."},
		{"who": DREAMER, "text": "Tell me: have you walked in worlds like this one before?",
			"choices": [{"t": "No, this is new to me.", "fn": func(): G.guide = "full"}, {"t": "Yes, I've played MMOs.", "fn": func(): G.guide = "light"}]},
		{"who": DREAMER, "text": "Then I will show you one thing at a time. You can turn my tips off whenever you like, in More → Guide."}],
		_lesson_move)


func _lesson_move() -> void:
	var L: bool = not G.settings.left_handed
	w.hud.coach.run([
		{"kind": "action", "text": "Put your thumb on the left side of the screen and drag to walk. Walk into the glowing circle by my lamp.",
			"short": "Drag on the left to walk. Go to the glowing circle.",
			"target": func(): return _joy_zone(L), "done": func(): return w.quests.obj_idx > 0},
		{"tour": true, "text": "Well walked! You can also just tap the ground, and you will walk there.", "target": null},
		{"tour": true, "text": "This is you. The green bar is Health. The blue bar is Zeal: it powers your skills. Tap this plate any time to see your Status.",
			"target": func(): return w.hud.plate},
		{"tour": true, "text": "Your next step always shows here. Tap this box and you will walk there by yourself.", "target": func(): return w.hud.quest_box},
		{"tour": true, "text": "The map. The gold ★ marks where to go. ✦ 0/2 counts the secrets hidden on this map. Tap the map to see your quest log.",
			"target": func(): return w.hud.minimap},
		{"tour": true, "text": "More holds everything else: Status, Skills, Satchel, the Pilgrim's Guide and Settings. A red number on it means points are waiting to be spent.",
			"target": func(): return w.hud.more_btn},
		{"tour": true, "text": "Messages from the world appear here. Tap to read older ones.", "target": func(): return w.hud.chat_box},
		{"kind": "action", "text": "Now tend the Young Vine. Tap the quest box to walk there, or tap the vine itself.", "short": "Go to the Young Vine.",
			"target": func(): return w.hud.quest_box, "done": func(): return w.nearest_ent() != null and w.nearest_ent().id == "vine" or w.quests.cur_obj() != "tend"},
		{"kind": "action", "text": "When you are close to something, this big button shows what you can do with it. Tap Tend.", "short": "Tap Tend.",
			"target": func(): return w.hud.act_btn, "done": func(): return w.quests.cur_obj() != "tend"}])


func _joy_zone(L: bool) -> Rect2:
	var vs := w.get_viewport().get_visible_rect().size
	return Rect2(Vector2(40 if L else vs.x * 0.62, vs.y * 0.5), Vector2(vs.x * 0.3, vs.y * 0.4))


## First Base and Job Level-ups teach levels, attributes and skills.
func _level_lesson(kind: String) -> void:
	if w.map_id != "eden":
		if kind.begins_with("Job") and G.tip_once("job_up_city"):
			w.hud.coach.tip("Job Level up: +2 skill points. Open More → Skills to make First Steps or Take Refuge stronger.", func(): return w.hud.more_btn, 6.0)
		elif kind.begins_with("Base") and G.tip_once("base_up_city"):
			w.hud.coach.tip("Base Level up: +2 attribute points. Open More → Status to spend them.", func(): return w.hud.more_btn, 6.0)
		return
	if kind.begins_with("Base") and G.tip_once("first_base"):
		w.get_tree().create_timer(1.2).timeout.connect(_lesson_stats)


func _lesson_stats() -> void:
	w.hud.coach.run([
		{"text": "You grew! Your Base Level is now %d. There are two kinds of level, shown here: Base and Job." % G.lvl, "target": func(): return w.hud.lv_txt},
		{"text": "Base Level is you. Each one gives 2 attribute points and refills your Health and Zeal. Job Level is your calling. Each one gives 2 skill points.", "tour": true,
			"target": func(): return w.hud.lv_txt},
		{"tour": true, "text": "This thin bar along the bottom fills with experience. When it is full, you level up. Quests, tending, reading and overcoming foes all give experience, and you never lose it.",
			"target": func(): return w.hud.exp_bar},
		{"kind": "action", "text": "Let's spend your 2 attribute points. Tap More (see the red +2).", "short": "Tap More.",
			"target": func(): return w.hud.more_btn, "done": func(): return w.hud.overlay_open() or G.stat_pts == 0},
		{"kind": "action", "text": "Tap Status.", "target": func(): return w.hud.more_tiles.get("status"),
			"done": func(): return w.hud.sheet_tab == "status" or G.stat_pts == 0, "skip_if": func(): return w.hud.sheet_tab == "status"},
		{"kind": "action", "text": "Six attributes shape you. Tap + to add a point. The green words show exactly what it changes. Steadfastness gives more Health; Fortitude hits harder. Resetting is free here, so try anything.",
			"short": "Tap + twice. Green text shows the effect.",
			"target": func(): return w.hud.stat_plus.get("ste"), "done": func(): return G.stat_pts == 0},
		{"kind": "action", "text": "Well chosen. Close the window with ✕, or tap the dark area beside it.", "target": null, "done": func(): return not w.hud.overlay_open()},
		{"kind": "tip", "text": "Next: gather figs from the Fig Tree. Tap the quest box to walk there.", "target": func(): return w.hud.quest_box, "secs": 4.5}])


func _lesson_skills() -> void:
	w.hud.coach.run([
		{"tour": true, "text": "Your figs went into your Satchel (More → Satchel). This quick-item button eats one to restore Health. You will want food after the garden.",
			"target": func(): return w.hud.item_btn},
		{"text": "Your Job Level rose to %d, so you have %d skill points. Skills are special actions that cost Zeal. Let's learn your first one." % [G.job, G.skill_pts],
			"target": func(): return w.hud.lv_txt},
		{"kind": "action", "text": "Tap More.", "target": func(): return w.hud.more_btn, "done": func(): return w.hud.overlay_open() or G.has_skill("tend")},
		{"kind": "action", "text": "Tap Skills.", "target": func(): return w.hud.more_tiles.get("skills"),
			"done": func(): return w.hud.sheet_tab == "skills" or G.has_skill("tend"), "skip_if": func(): return w.hud.sheet_tab == "skills"},
		{"kind": "action", "text": "Tap Learn on Tend and Keep. It is a garden skill for Eden only. Keep your other point: you will want it for First Steps after you wake.",
			"short": "Learn Tend and Keep.", "target": func(): return w.hud.skill_learn.get("tend"), "done": func(): return G.has_skill("tend")},
		{"kind": "action", "text": "Learned! Close this window (✕ or tap beside it).", "target": null, "done": func(): return not w.hud.overlay_open()},
		{"text": "Your skill is now on your skill bar. The blue number is its Zeal cost. After you use it, a dark sweep shows it recharging.",
			"target": func(): return w.hud.skill_btns[0]},
		{"kind": "action", "text": "Walk next to a drooping lily and tap Tend and Keep.", "short": "Tend a drooping lily.",
			"target": func(): return w.hud.skill_btns[0], "done": func(): return w.map.lilies_done >= 1}])


func _lesson_manna() -> void:
	w.hud.coach.run([
		{"text": "Word Study gave you Manna. Manna is gathered through the means of grace: reading the Word, rest and worship. Its count is shown here, by your experience.",
			"target": func(): return w.hud.exp_txt},
		{"tour": true, "text": "Later you spend Manna on Disciplines and Refreshments. If you fall in battle, a little unspent Manna spoils, so spend it rather than hoard it.", "target": null},
		{"text": "You have learned to walk, to tend, to grow and to use a skill. One thing remains: behold the two trees in the midst of the garden.", "target": func(): return w.hud.quest_box}])


func _on_new_obj() -> void:
	if w.map_id != "eden":
		return
	match w.quests.cur_obj():
		"learn":
			if G.tip_once("skills_lesson"):
				w.get_tree().create_timer(1.0).timeout.connect(_lesson_skills)


func _city_lessons() -> void:
	if not w.is_inside_tree():
		return
	var steps := [
		{"kind": "action", "text": "Tap Attack, or tap a Slothling, to fight. You keep striking until it is overcome. Combat is new: it only begins after the garden.",
			"short": "Tap Attack to fight.", "target": func(): return w.hud.atk_btn, "done": func(): return w.combat.slain >= 1}]
	if not G.has_skill("steps"):
		steps += [
			{"kind": "action", "text": "Well fought! Now learn a fighting skill. Tap More.", "short": "Learn First Steps: tap More.",
				"target": func(): return w.hud.more_btn, "done": func(): return w.hud.overlay_open() or G.has_skill("steps")},
			{"kind": "action", "text": "Tap Skills.", "target": func(): return w.hud.more_tiles.get("skills"),
				"done": func(): return w.hud.sheet_tab == "skills" or G.has_skill("steps"), "skip_if": func(): return w.hud.sheet_tab == "skills"},
			{"kind": "action", "text": "Learn First Steps: a heavy lunge. If you still have a point, Take Refuge heals you.", "target": func(): return w.hud.skill_learn.get("steps"),
				"done": func(): return G.has_skill("steps")},
			{"kind": "action", "text": "Close the window (✕ or tap beside it).", "target": null, "done": func(): return not w.hud.overlay_open()}]
	steps += [
		{"kind": "action", "text": "Stand next to a Slothling and tap First Steps.", "short": "Use First Steps.",
			"target": func(): return _skill_btn_for("steps"), "done": func(): return w.combat.used_steps or not G.has_skill("steps")}]
	w.hud.coach.run(steps)


func _skill_btn_for(id: String) -> Control:
	var ids: Array = w.hud.bar_skills()
	var k := ids.find(id)
	return w.hud.skill_btns[k] if k >= 0 else null


func _city_tips_tick() -> void:
	if w.map_id != "city" or w.cinema or w.hud.coach.busy():
		return
	if w.combat.slain >= 2 and G.tip_once("auto"):
		w.hud.coach.tip("Auto attacks and uses your skills for you. It works only in fields like this street; bosses and story moments are always yours to play.", func(): return w.hud.auto_btn, 6.0)
	elif w.combat.slain >= 3 and not w.combat._any_aggro() and G.hp < G.hp_max * 0.7 and G.tip_once("sit"):
		w.hud.coach.tip("Sit to recover Health and Zeal three times faster. Moving stands you up.", func(): return w.hud.sit_btn, 6.0)
