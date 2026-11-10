extends Node
## Scripted run used in CI/dev: plays the whole game from the title to the first Calling,
## saves screenshots, prints [pacing] lines per act and asserts the design doc's XP budget.
## Run: godot --path . -- --autotest   (screens saved to user://autotest/ or $HPO_SHOTS)
## Eden is driven step by step (it teaches the UI); every later map is played by a small bot
## that reads the current objective from data, so new chapters are covered without new test code.

const SPEED := 3.0                 # game runs faster than real time during the test
const FIGHT_TIMEOUT_S := 400.0
const TRIAL_JOB := "valiant"
const FINAL_JOB := "shepherd"
const ROUTE := ["city", "slough", "interpreter", "cross", "hill", "palace", "trial", "palace", "lions_path", "palace", "lions", "palace", "humiliation", "shadow"]

var dir := ""
var failures: Array[String] = []
var pilgrim_quest: Array = []      # quest XP ledger at the moment of the Calling
var gear_checked := false

func _ready() -> void:
	dir = OS.get_environment("HPO_SHOTS")
	if dir == "":
		dir = OS.get_user_data_dir() + "/autotest"
	DirAccess.make_dir_recursive_absolute(dir)
	G.delete_save()
	G.settings.lords_day_bypass = true   # the test must run on any day of the week
	G.time_scale = SPEED; Engine.time_scale = SPEED; Engine.max_physics_steps_per_frame = 32
	run()

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])
	print("[autotest] shot ", n)

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("[autotest] FAIL: " + msg)

func cur() -> Node:
	return G.main.current

func world() -> Node:
	return cur() if cur() and cur().name == "World" else null

func tp(id: String) -> void:
	var w = world(); var e: Dictionary = w.ent(id)
	w.player.position = e.pos + Vector3(-1.2, 0, 1.0)
	await wait(0.4)

func talk(n: int, choice: int = 0) -> void:
	for k in n:
		if world() and world().hud.dialog_active():
			world().hud.dialog_next(choice)
		await wait(0.35)

func skip_info() -> void:
	var w = world()
	var guard := 0
	while w and w.hud.coach.blocking() and guard < 12:
		w.hud.coach.next(); guard += 1
		await wait(0.15)

## Dev shortcut: HPO_FROM=<map id> starts the bot on that map with the earlier acts' quest XP already paid.
func _jump(from: String) -> void:
	var acts: Dictionary = G.data("acts")
	var act: String = G.data("maps/" + from).act
	G.pname = "Steadfast"; G.lamb_name = "Meadow"; G.build_player_sheet(); G.base_cap = 10
	for a in acts.order:
		if a == act:
			break
		G.cur_act = a
		G.add_xp(int(acts.acts[a].base), int(acts.acts[a].job))
		G.flags["page_" + a] = true
	for f in ["city_fight", "prayer_taught"] + (["burden_gone", "sealed", "hill_reached"] if act in ["hill", "palace", "humiliation", "shadow"] else []):
		G.flags[f] = true
	G.flags.erase("page_eden")
	G.goto("world", {"map": from})
	var i := ROUTE.find(from)
	for map_id in ROUTE.slice(i):
		if not failures.is_empty():
			break
		await play_map(map_id)
	print("[autotest] partial run from %s: %s" % [from, "PASS" if failures.is_empty() else str(failures)])
	get_tree().quit(0 if failures.is_empty() else 1)

## Gallery (HPO_GALLERY=1): one fixed set of pictures of every map and screen, taken the same way
## every build, so tools/shot_diff.py can compare them with the golden set in tests/golden.
const GALLERY_MAPS := ["eden", "city", "slough", "interpreter", "cross", "hill", "palace", "trial", "lions_path", "lions", "humiliation", "shadow"]
const GALLERY_SHEETS := ["status", "skills", "bag", "guide", "settings"]

func _gallery_world(map_id: String) -> Node:
	G.goto("world", {"map": map_id})
	var guard := 0
	while (world() == null or world().map_id != map_id or world().hud == null) and guard < 200:
		await wait(0.1); guard += 1
	await wait(1.2)
	return world()

func _gallery_clear(w) -> void:
	var guard := 0
	while is_instance_valid(w) and (w.hud.dialog_active() or w.hud.coach.blocking()) and guard < 60:
		guard += 1
		if w.hud.dialog_active():
			w.hud.dialog_next(0)
		else:
			w.hud.coach.next()
		await wait(0.2)
	w.hud.clear_overlay()

func gallery() -> void:
	seed(7)
	G.pname = "Steadfast"; G.lamb_name = "Meadow"; G.build_player_sheet(); G.base_cap = 10
	G.settings.auto_battle = false; G.guide = "off"
	await wait(1.5); await shot("ui_title")
	get_window().size = Vector2i(720, 1280); await wait(1.0); await shot("portrait_title")
	get_window().size = Vector2i(1280, 720); await wait(0.6)
	for map_id in GALLERY_MAPS:
		var w = await _gallery_world(map_id)
		if w == null:
			check(false, "gallery: map '%s' did not load" % map_id); continue
		if map_id == "city":
			await shot("ui_dialogue")
		await _gallery_clear(w)
		if w.hud.coach.busy():
			w.hud.coach._skip_all()
		w.combat.calm_all = true
		var b: Rect2 = w.bounds
		var spots := [w.player.position, Vector3(b.get_center().x, 0, b.get_center().y), Vector3(b.end.x - 7.0, 0, b.get_center().y)]
		for i in spots.size():
			w.player.position = spots[i]; G.hp = G.hp_max
			w._place_camera(true)
			await wait(0.7)
			await _gallery_clear(w)
			await wait(0.3)
			await shot("map_%s_%s" % [map_id, "abc"[i]])
		if map_id == "city":
			for tab in GALLERY_SHEETS:
				w.hud.open_sheet(tab); await wait(0.5); await shot("ui_sheet_" + tab)
			w.hud.clear_overlay()
			w.hud.open_more(); await wait(0.4); await shot("ui_more"); w.hud.clear_overlay()
			w.hud.shop(); await wait(0.4); await shot("ui_shop"); w.hud.clear_overlay()
			w.hud.bench(); await wait(0.4); await shot("ui_bench"); w.hud.clear_overlay()
			if OS.get_environment("HPO_PORTRAIT") != "0":
				get_window().size = Vector2i(720, 1280); await wait(1.0)
				w._place_camera(true); await wait(0.5)
				await shot("portrait_hud")
				w.hud.open_sheet("status"); await wait(0.5); await shot("portrait_sheet"); w.hud.clear_overlay()
				w.hud.open_more(); await wait(0.4); await shot("portrait_more"); w.hud.clear_overlay()
				w.hud.shop(); await wait(0.4); await shot("portrait_shop"); w.hud.clear_overlay()
				w.hud.run_dialog([{"who": "Evangelist", "text": "Do you see yonder shining light? Keep that light in your eye, and go up directly thereto."}], func() -> void: pass)
				await wait(1.2); await shot("portrait_dialogue"); w.hud.dialog_next(0); await wait(0.3); w.hud.clear_overlay()
				get_window().size = Vector2i(1280, 720); await wait(1.0)
	print("[autotest] gallery: ", "PASS" if failures.is_empty() else "FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)

func run() -> void:
	if OS.get_environment("HPO_GALLERY") != "":
		await gallery()
		return
	if OS.get_environment("HPO_FROM") != "":
		await wait(1.0)
		await _jump(OS.get_environment("HPO_FROM"))
		return
	await wait(1.5); await shot("01_title")
	cur().start(); await wait(0.5); await shot("02_age")
	cur()._age_ok(); await wait(1.2)
	cur().name_edit.text = "Steadfast"; await wait(0.6); await shot("04_create")
	cur()._make(); await wait(1.4); await shot("05_dream")
	cur().advance(); await wait(1.0); await shot("05b_dream_choice")
	cur().advance(true); await wait(0.4); cur().advance(); await wait(0.4); cur().advance(true); await wait(3.0)
	await _eden()
	for map_id in ROUTE:
		if failures.is_empty():
			await play_map(map_id)
	await wait(3.0)
	await shot("90_end")
	_final_checks()
	print("[autotest] ", "PASS" if failures.is_empty() else "FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ Eden (step by step: it teaches the HUD)
func _eden() -> void:
	await shot("06_eden_intro")
	var w = world()
	await talk(1); await wait(0.6); await shot("06b_eden_choice")
	await talk(1, 0); await talk(1); await talk(1, 0); await wait(0.5); await shot("06c_eden_guide")
	await talk(1); await wait(0.6)
	await shot("07_coach_move")
	w.move_target = w.quests.objectives[0].zone
	await wait(3.5)
	await shot("07b_tour_tap")
	w.hud.coach.next(); await wait(0.4); await shot("07c_tour_plate")
	w.hud.coach.next(); await wait(0.3); w.hud.coach.next(); await wait(0.3); await shot("07d_tour_map")
	await skip_info()
	await tp("vine"); await shot("08_act_prompt"); w.act_pressed(); await wait(2.6)
	await shot("08b_level_lesson")
	await skip_info(); await wait(0.3)
	w.player.position = w.quests.cur().zone; await wait(1.0)   # E2 rivers
	w.hud.open_more(); await wait(0.6); await shot("08d_more")
	w.hud.open_sheet("status"); await wait(0.6); await shot("08e_status")
	G.raise_stat("ste"); w.hud.open_sheet("status"); G.raise_stat("for"); w.hud.open_sheet("status"); await wait(0.5); await shot("08f_status_spent")
	w.hud.clear_overlay(); await wait(0.6); await skip_info()
	w.player.position = Vector3(22.6, 0, 3.2); await wait(0.8); await shot("08g_secret_glint")
	w.ent("secret_dreamer_note").fn.call(); await wait(0.6); await shot("08h_secret_card"); w.hud.clear_overlay()
	await tp("fig"); w.act_pressed(); await wait(2.2)
	await shot("09_skills_lesson")
	await skip_info(); await wait(0.3)
	w.hud.open_sheet("skills"); await wait(0.6); await shot("09b_skills_sheet")
	G.learn_skill("tend"); w.hud.open_sheet("skills"); await wait(0.5); await shot("09c_learned")
	w.hud.clear_overlay(); await wait(0.6); await skip_info(); await wait(0.3)
	await shot("09d_skillbar")
	for l in w.map.lilies:
		w.player.position = l.pos + Vector3(1.0, 0, 0.4); await wait(0.4)
		w.combat.skill("tend"); await wait(0.5)
		if l == w.map.lilies[0]:
			await shot("09e_tend")
		await wait(2.8)
	await shot("09f_lilies_done")
	await tp("lamb"); w.act_pressed(); await wait(0.5); await shot("10_name_lamb")
	w.hud.clear_overlay(); w.map._lamb_named("Meadow"); await wait(0.6)
	await tp("stone"); w.act_pressed(); await wait(0.6); await shot("10b_word_study")
	w.hud.clear_overlay(); w.map._stone_read(); await wait(2.4)
	await shot("11_manna_lesson")
	await skip_info()
	w.hud.open_sheet("bag"); await wait(0.5); await shot("12_sheet_bag")
	w.hud.open_sheet("guide"); await wait(0.5); await shot("13_sheet_guide")
	w.hud.open_sheet("settings"); await wait(0.5); await shot("14_settings")
	w.hud.clear_overlay(); await skip_info(); w.hud.coach._finish()
	await tp("trees"); w.act_pressed(); await wait(1.5); await shot("15_fall_trees")
	_pacing("eden")
	await talk(2); await wait(1.2); await shot("15b_fall_serpent")
	await talk(2); await wait(2.0); await shot("15c_fall_hide")
	await talk(1); await wait(1.8); await shot("15d_cherubim")
	await talk(1); await wait(1.2); await shot("15e_lamb_stays")
	await talk(2); await wait(1.0)

# ------------------------------------------------------------------ the bot (plays any data-driven map)
func play_map(map_id: String) -> void:
	var guard := 0
	while (world() == null or world().map_id != map_id or world().hud == null or world().ending) and guard < 300:
		await wait(0.1); guard += 1
	var w = world()
	check(w != null and w.map_id == map_id, "expected to arrive on map '%s'" % map_id)
	if map_id == "humiliation":
		_pacing("palace")
	if w == null or w.map_id != map_id:
		return
	await wait(1.0)
	await shot("%s_%d_enter" % [map_id, w.quests.obj_idx])
	var steps := 0; var last := ""
	while is_instance_valid(w) and not w.ending and not w.quests.cur().is_empty() and steps < 80:
		steps += 1
		await _settle(w)
		if not is_instance_valid(w):
			break
		await _do_side(w)
		if not is_instance_valid(w):
			break
		var o: Dictionary = w.quests.cur()
		if o.is_empty() or w.ending:
			break
		if map_id == "slough" and o.id == "wiseman" and not G.flags.has("tested_continue"):
			w = await _continue_check(w)
			continue
		if o.id != last:
			last = o.id
			await shot("%s_%d_%s" % [map_id, w.quests.obj_idx, o.id])
		await _do(w, o)
	check(steps < 80, "map '%s' did not finish (stuck on '%s')" % [map_id, last])
	if map_id != "palace" and map_id in G.data("acts").order:
		_pacing(map_id)

## Save / Continue: reload the save mid-map and make sure the objective and the world state come back.
func _continue_check(w) -> Node:
	G.flags["tested_continue"] = true
	G.save_game()
	var idx: int = w.quests.obj_idx; var xp: int = G.xp
	check(G.load_game(), "the save file must load")
	check(G.cur_map == "slough" and G.xp == xp, "Continue must restore the map and XP")
	G.goto("world", {"map": G.cur_map})
	await wait(1.5)
	while world() == null or world() == w or world().hud == null:
		await wait(0.1)
	var nw = world()
	await wait(0.5)
	check(nw.quests.obj_idx == idx, "Continue must resume at objective %d, got %d" % [idx, nw.quests.obj_idx])
	check(not nw.ent("wiseman").hidden and not nw.ent("help").hidden and nw.ent("pliable").hidden, "Continue must replay earlier objectives' world changes")
	await shot("slough_continued")
	return nw

## Clear coach tips and dialogue, and spend points like a player would.
func _settle(w) -> void:
	var guard := 0
	while is_instance_valid(w) and not w.ending and guard < 60 and (w.hud.dialog_active() or w.hud.coach.blocking() or w.quests.busy):
		guard += 1
		if w.hud.dialog_active():
			w.hud.dialog_next(0)
		elif w.hud.coach.blocking():
			w.hud.coach.next()
		elif w.hud.overlay_open():
			await _ui(w)
		await wait(0.2)
	if is_instance_valid(w) and w.hud.overlay_open() and not w.hud.dialog_active():
		w.hud.clear_overlay()   # result windows such as "Muster cleared"
	if not is_instance_valid(w):
		return
	if w.combat.dead:
		w.hud.clear_overlay(); w.combat.rise()
	w.hud.coach._finish()
	while G.stat_pts > 0:
		G.raise_stat("for" if G.stat_pts % 2 == 0 else "ste")
	var learned := true
	while G.skill_pts > 0 and learned:
		learned = false
		for id in G.SKILL_ORDER:
			if G.skill_pts > 0 and G.skill_open(id) and not G.SKILL_INFO[id].get("eden", false) and int(G.skill_lv.get(id, 0)) < int(G.SKILL_INFO[id].max):
				var has_req: bool = not G.SKILL_INFO[id].has("req") or int(G.skill_lv.get(G.SKILL_INFO[id].req.skill, 0)) >= int(G.SKILL_INFO[id].req.lv)
				if has_req and G.learn_skill(id):
					learned = true
	Gear.equip_best()
	if G.armor and not gear_checked and w.map_id == "palace":
		await _gear_check(w)

## The loot loop: buy, wear, refine, cut and set a Fruit stone, read the Codex.
func _gear_check(w) -> void:
	gear_checked = true
	G.denarii += 300; G.manna = maxf(G.manna, 4.0)   # test purse
	w.hud.shop(); await wait(0.4); await shot("ui_shop")
	check(Gear.buy("tunic") and Gear.buy("Honey from the Rock"), "the vendor must sell gear and provisions")
	Gear.equip_best()
	check(not Gear.equipped("garment").is_empty(), "bought gear can be worn")
	var before: Dictionary = G.d.duplicate()
	check(Gear.refine(int(Gear.equipped("hand").uid)), "refining an equipped piece succeeds")
	check(Gear.cut_stone("peace"), "a Fruit stone is cut from Manna"); Gear.set_stone("peace")
	check(int(G.d.guard) == int(before.guard) + 1 and int(G.d.atk) >= int(before.atk), "the Stone of Peace adds 1 block; refining never lowers Attack")
	w.hud.bench(); await wait(0.4); await shot("ui_bench")
	w.hud.open_sheet("equip"); await wait(0.4); await shot("ui_equipment")
	G.daily_state().read = true
	w.hud.open_sheet("codex"); await wait(0.4); await shot("ui_codex")
	w.hud.open_sheet("skills"); await wait(0.4); await shot("ui_skills")
	w.hud.clear_overlay()

## Windows opened by an objective (Calling, Muster, Word Study).
func _ui(w) -> void:
	var o: Dictionary = w.quests.cur()
	match String(o.get("ui", "")):
		"calling_trial":
			await shot("ui_calling_trial"); w.hud.more_tiles["calling_" + TRIAL_JOB].pressed.emit()
		"calling":
			await shot("ui_calling"); pilgrim_quest = G.ledger.quest.duplicate(); pilgrim_quest[0] += 0
			w.hud.more_tiles["calling_" + FINAL_JOB].pressed.emit()
		"muster":
			await shot("ui_muster"); w.hud.muster_enter()
		"word_study":
			await shot("ui_word_study_%s" % w.map_id); w.hud.clear_overlay(); w.quests.complete()
		_:
			w.hud.clear_overlay()

func _do_side(w) -> void:
	for sd in w.quests.side:
		if not is_instance_valid(w):
			return
		if sd.has("ent") and not sd.id in w.quests.done_side and not w.ent(sd.ent).is_empty() and not w.ent(sd.ent).hidden:
			await _use(w, sd.ent)
			if sd.get("page", false):
				await wait(0.3); await shot("%s_page" % w.map_id)
			await _settle(w)

func _use(w, ent_id: String) -> void:
	var e: Dictionary = w.ent(ent_id)
	w.player.position = e.pos + Vector3(-1.2, 0, 1.0)
	await wait(0.3)
	w.use(e)
	await wait(0.4)

func _do(w, o: Dictionary) -> void:
	match String(o.type):
		"zone", "exit":
			w.player.position = o.zone; await wait(0.5)
		"path":
			while w.quests.cur() == o and w.quests.path_i < o.points.size():
				w.player.position = o.points[w.quests.path_i]; await wait(0.4)
			if w.quests.cur() == o:
				await _fight(w, o)
		"kill":
			await _fight(w, o)
		"check":
			if String(o.check) == "rested" and not w.sitting:
				w.toggle_sit(); await shot("%s_resting" % w.map_id)
			await wait(1.0)
		"script":
			if w.combat.boss != null and w.combat.boss.alive:
				await _fight(w, o)
			else:
				await wait(0.5)
		"boss":
			if not w.quests.fighting:
				await _use(w, o.ent); await _settle(w)
			await _fight(w, o)
		_:
			await _use(w, o.ent)

## Fight until the objective changes. The bot plays plainly: attack, use every ready skill, eat when low.
func _fight(w, o: Dictionary) -> void:
	var t0: float = w.t; var shot_done := false
	while is_instance_valid(w) and w.quests.cur() == o and not w.ending and w.t - t0 < FIGHT_TIMEOUT_S:
		if w.hud.dialog_active() or w.hud.coach.blocking():
			await _settle(w)
		if w.combat.dead:
			await shot("%s_ko" % w.map_id); w.hud.clear_overlay(); w.combat.rise()
		if G.hp < G.hp_max * 0.4:
			G.hp = G.hp_max * 0.8   # test only: the bot does not dodge, so it is kept on its feet
		if w.combat.target == null or not w.combat.target.alive:
			var boss = w.combat.boss
			var m = boss if (boss != null and boss.alive) else w.combat._nearest_mob(999.0)
			w.combat.target = m
			if m != null and m.actor.position.distance_to(w.player.position) > 12.0:
				w.player.position = m.actor.position + Vector3(1.5, 0, 0)
		var only: String = w.combat.target.get("only", "") if w.combat.target != null else ""
		for page in G.bar_pages(false).size():
			for id in G.page_skills(page, false):
				if only != "" and id != only:
					continue   # save Zeal for the one thing that works
				if w.combat.cd.get(id, 0.0) <= 0.0 and G.zeal >= int(G.SKILL_INFO[id].zeal) and w.combat.gcd <= 0.0:
					w.combat.skill(id)
		if not shot_done and w.combat.slain >= 1:
			shot_done = true; await shot("%s_%d_fight" % [w.map_id, w.quests.obj_idx])
		await wait(0.5)
	check(not is_instance_valid(w) or w.quests.cur() != o or w.ending, "fight for '%s' on %s timed out" % [o.id, w.map_id])

# ------------------------------------------------------------------ pacing and budget checks
func _pacing(act: String) -> void:
	var plan: Dictionary = G.data("acts").acts[act]
	var got: Array = G.act_xp.get(act, [0, 0])
	print("[pacing] %-12s quest XP %4d/%-4d base, %3d/%-3d job | Base %d Job %d | mob XP so far %d | plan %d min" % [act, got[0], plan.base, got[1], plan.job, G.lvl, G.job, G.ledger.mob[0], plan.minutes])
	check(int(got[0]) == int(plan.base) and int(got[1]) == int(plan.job), "%s quest XP %s differs from the design budget %d/%d" % [act, got, plan.base, plan.job])
	check(G.lvl >= int(plan.end_base) and (G.job >= int(plan.end_job) or G.job_id != G.PILGRIM),   # the Calling restarts Job Level at 1
		 "%s should end at Base %d / Job %d or above, got %d / %d" % [act, plan.end_base, plan.end_job, G.lvl, G.job])

func _final_checks() -> void:
	var q: Array = G.ledger.quest; var m: Array = G.ledger.mob
	var acts: Dictionary = G.data("acts")
	var want := [0, 0]
	for a in acts.order:
		want[0] += int(acts.acts[a].base); want[1] += int(acts.acts[a].job)
	print("[pacing] to the Calling: quest XP %s (design: 2210 / 855) | whole run: quest %s, mob XP %d | %s, Base %d, Job %d | Denarii %d, gear %d" % [pilgrim_quest, q, m[0], G.job_name(), G.lvl, G.job, G.denarii, G.gear.size()])
	check(pilgrim_quest.size() == 2 and int(pilgrim_quest[0]) == G.base_total(10) and int(pilgrim_quest[1]) == 855, "quest XP at the Calling must be 2210 base / 855 job, got %s" % [pilgrim_quest])
	check(int(q[0]) == want[0] and int(q[1]) == want[1], "quest XP for the whole run must be %s, got %s" % [want, q])
	check(G.job_id == FINAL_JOB and G.lvl >= 11, "after Act III the pilgrim keeps the Calling and has passed Base 10")
	check(G.has_skill("all_prayer") and G.flags.has("faithful_joined") and G.bestiary.size() >= 10, "Act III state: All-Prayer learned, Faithful joined, bestiary filled")
	check(cur() != null and cur().name == "End", "the run must finish on the end screen")
	check(G.has_save() and G.load_game() and G.cur_map == "shadow" and G.job_id == FINAL_JOB, "the final save must hold the Calling")
	check(G.armor and not G.burden and Quests.pages_found() == 8, "story state: armor given, burden gone, eight Dreamer's Pages (got %d)" % Quests.pages_found())
	print("[autotest] marks ", G.marks, " secrets ", G.secrets, " kos ", G.kos)
