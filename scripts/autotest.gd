extends Node
## Scripted run used in CI/dev to smoke-test the whole first session and capture screenshots.
## Run: godot --path . -- --autotest   (screens saved to user://autotest/ or $HPO_SHOTS)

var dir := ""

func _ready() -> void:
	dir = OS.get_environment("HPO_SHOTS")
	if dir == "":
		dir = OS.get_user_data_dir() + "/autotest"
	DirAccess.make_dir_recursive_absolute(dir)
	run()

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, n])
	print("[autotest] shot ", n)

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

func run() -> void:
	await wait(1.5); await shot("01_title")
	cur().start_age(); await wait(0.5); await shot("02_age")
	cur()._age_ok(); await wait(0.4); await shot("03_server")
	G.goto("create"); await wait(1.2)
	cur().name_edit.text = "Steadfast"; await wait(0.6); await shot("04_create")
	cur()._make(); await wait(1.4); await shot("05_dream")
	cur().advance(); await wait(1.0); await shot("05b_dream_choice")
	cur().advance(true); await wait(0.4); cur().advance(); await wait(0.4); cur().advance(true); await wait(3.0)
	await shot("06_eden_intro")
	var w = world()
	await talk(1); await wait(0.6); await shot("06b_eden_choice")
	await talk(1, 0); await talk(1); await talk(1, 0); await wait(0.5); await shot("06c_eden_guide")
	await talk(1); await wait(0.6)
	await shot("07_coach_move")
	w.move_target = w.objectives[0].zone
	await wait(3.5)
	await shot("07b_tour_tap")
	w.hud.coach.next(); await wait(0.4); await shot("07c_tour_plate")
	w.hud.coach.next(); await wait(0.3); w.hud.coach.next(); await wait(0.3); await shot("07d_tour_map")
	await skip_info()
	await shot("07e_coach_vine")
	await tp("vine"); await shot("08_act_prompt"); w.act_pressed(); await wait(2.6)
	await shot("08b_level_lesson")
	await skip_info(); await wait(0.3); await shot("08c_coach_more")
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
	for l in w.lilies:
		w.player.position = l.pos + Vector3(1.0, 0, 0.4); await wait(0.4)
		w.skill("tend"); await wait(0.5)
		if l == w.lilies[0]:
			await shot("09e_tend")
		await wait(2.8)
	await shot("09f_lilies_done")
	await tp("lamb"); w.act_pressed(); await wait(0.5); await shot("10_name_lamb")
	w.hud.clear_overlay(); w._lamb_named("Meadow"); await wait(0.6)
	await tp("stone"); w.act_pressed(); await wait(0.6); await shot("10b_word_study")
	w.hud.clear_overlay(); w._stone_read(); await wait(2.4)
	await shot("11_manna_lesson")
	await skip_info()
	w.hud.open_sheet("bag"); await wait(0.5); await shot("12_sheet_bag")
	w.hud.open_sheet("guide"); await wait(0.5); await shot("13_sheet_guide")
	w.hud.clear_overlay(); w.hud.open_more(); await wait(0.4); await shot("14_more")
	w.hud.clear_overlay(); await skip_info(); w.hud.coach._finish()
	await tp("trees"); w.act_pressed(); await wait(1.5); await shot("15_fall_trees")
	await talk(2); await wait(1.2); await shot("15b_fall_serpent")
	await talk(2); await wait(2.0); await shot("15c_fall_hide")
	await talk(1); await wait(1.8); await shot("15d_cherubim")
	await talk(2); await wait(3.0)
	w = world()
	await shot("16_wake")
	await talk(2); await wait(0.4); await shot("16b_wake_reply"); await talk(2); await wait(1.0)
	await shot("17_city")
	w.player.position = Vector3(-8.0, 0, 2.6); await wait(1.2); await shot("17b_passing_pilgrims")
	w.act_pressed(); await wait(0.5); await shot("17c_waymark"); w.hud.clear_overlay()
	var t0 := Time.get_ticks_msec(); var ko_done := false; var mid := false
	var learned_shot := false
	while w.slain < 3 and Time.get_ticks_msec() - t0 < 90000:
		w.attack_pressed()
		if w.slain >= 1 and not G.has_skill("steps") and not learned_shot:
			learned_shot = true
			await wait(0.6); await shot("18a_coach_learn")
			G.learn_skill("steps"); G.learn_skill("refuge"); w.hud.clear_overlay()
		if w.slain >= 1 and not mid:
			mid = true; await wait(0.3); await shot("18_combat")
		if w.slain >= 1 and not ko_done:
			ko_done = true; G.hp = 2.0
			await wait(4.0)
			if w.dead:
				await shot("19_ko"); w.hud.clear_overlay(); w.rise()
		w.skill("steps")
		await wait(0.6)
	print("[autotest] slain ", w.slain)
	await wait(2.5); await shot("20_evangelist")
	w.hud.coach._finish()
	if w.dead:
		w.hud.clear_overlay(); w.rise()
	G.hp = G.hp_max
	await tp("evangelist"); w.act_pressed(); await wait(1.6); await shot("21_dialog")
	w.hud.clear_overlay(); w.after_evangelist(); await wait(1.0)
	await shot("22_warp")
	w.hud.enter_snapshot(); await wait(0.5); await shot("23_snapshot"); w.hud.exit_snapshot()
	if w.dead:
		w.hud.clear_overlay(); w.rise()
	G.hp = G.hp_max
	w.player.position = Vector3(19.5, 0, 0); await wait(2.0)
	await shot("24_onward")
	for i in 4:
		cur().advance(true); await wait(0.5)
	await wait(2.5)
	w = world()
	await shot("25_palace")
	await wait(4.0); await shot("26_palace_life")
	await tp("watchful"); w.act_pressed(); await wait(0.5); await shot("27_watchful")
	w.hud.clear_overlay(); w._watchful_done(); await wait(0.5)
	await tp("hearth"); w.act_pressed(); await wait(1.0); await shot("28_hearth")
	w.toggle_sit()
	w.hud.waymark_place(); await wait(0.4); await shot("29_waymark_place")
	w.hud.clear_overlay(); w.place_waymark("Rest here"); await wait(0.6)
	await tp("board"); w.act_pressed(); await wait(0.5); await shot("30_muster_board")
	w.hud.muster_queue(w.hud.MUSTERS[0]); await wait(2.5); await shot("31_muster_queue")
	await wait(4.5); await shot("32_muster_ready")
	w.hud.muster_enter(); await wait(3.0)
	w = world()
	await shot("33_lions")
	t0 = Time.get_ticks_msec(); mid = false
	while w.boss != null and w.boss.alive and Time.get_ticks_msec() - t0 < 150000:
		if w.dead:
			w.hud.clear_overlay(); w.rise()
		G.hp = maxf(G.hp, G.hp_max * 0.5)
		w.attack_pressed()
		if not mid and w.boss.hp < w.boss.max * 0.7:
			mid = true; await shot("34_muster_fight")
		w.skill("steps")
		await wait(0.6)
	print("[autotest] boss alive=", w.boss.alive, " hp=", w.boss.hp)
	await wait(1.4); await shot("35_muster_cleared")
	w.hud.clear_overlay(); await wait(0.5)
	w.player.position = Vector3(0, 0, -9.6); await wait(2.5)
	await shot("36_end")
	print("[autotest] marks ", G.marks, " secrets ", G.secrets)
	print("[autotest] done")
	get_tree().quit()
