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
const ROUTE := ["city", "slough", "interpreter", "cross", "hill", "palace", "trial", "palace", "lions_path", "palace", "lions", "palace"]

var dir := ""
var failures: Array[String] = []

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
	for f in ["city_fight", "prayer_taught"] + (["burden_gone", "sealed", "hill_reached"] if act in ["hill", "palace"] else []):
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

func run() -> void:
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
	for id in ["steps", "refuge", "steady", "watchful_eye", "rest_prayer", "steps", "refuge", "steps"] + G.JOBS[G.job_id].skills if G.job_id != G.PILGRIM else ["steps", "refuge", "steady", "watchful_eye", "rest_prayer", "steps", "refuge", "steps", "steps"]:
		if G.skill_pts > 0 and G.skill_open(id):
			G.learn_skill(id)

## Windows opened by an objective (Calling, Muster, Word Study).
func _ui(w) -> void:
	var o: Dictionary = w.quests.cur()
	match String(o.get("ui", "")):
		"calling_trial":
			await shot("ui_calling_trial"); w.hud.more_tiles["calling_" + TRIAL_JOB].pressed.emit()
		"calling":
			await shot("ui_calling"); w.hud.more_tiles["calling_" + FINAL_JOB].pressed.emit()
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
		for page in 2:
			for id in G.page_skills(page, false):
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
	_pacing("palace")
	var q: Array = G.ledger.quest; var m: Array = G.ledger.mob
	var share := float(m[0]) / float(q[0])
	print("[pacing] total quest XP %d base / %d job (design: 2210 / 855) | mob XP %d (%.0f%% extra) | %s, Base %d, Job %d" % [q[0], q[1], m[0], share * 100.0, G.job_name(), G.lvl, G.job])
	check(int(q[0]) == G.base_total(10) and int(q[1]) == 855, "quest XP must total 2210 base / 855 job, got %s" % [q])
	check(G.job_id == FINAL_JOB and G.job == 1 and G.lvl >= 10, "the first job change must leave Base >= 10 and the new job at Job Level 1")
	check(cur() != null and cur().name == "End", "the run must finish on the end screen")
	check(G.has_save() and G.load_game() and G.cur_map == "palace" and G.job_id == FINAL_JOB, "the final save must hold the Calling")
	check(G.armor and not G.burden and Quests.pages_found() == 6, "story state: armor given, burden gone, six Dreamer's Pages (got %d)" % Quests.pages_found())
	print("[autotest] marks ", G.marks, " secrets ", G.secrets, " kos ", G.kos)
