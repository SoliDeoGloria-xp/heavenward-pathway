extends Node
## Scripted run used in CI/dev to smoke-test the whole first session and capture screenshots.
## Run: godot --path . -- --autotest   (screens saved to user://autotest/ or $PPO_SHOTS)

var dir := ""

func _ready() -> void:
	dir = OS.get_environment("PPO_SHOTS")
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

func run() -> void:
	await wait(1.5); await shot("01_title")
	cur().start_age(); await wait(0.5); await shot("02_age")
	cur()._age_ok(); await wait(0.4); await shot("03_server")
	G.goto("create"); await wait(1.2)
	cur().name_edit.text = "Steadfast"; await wait(0.6); await shot("04_create")
	cur()._make(); await wait(1.2); await shot("05_dream")
	cur().advance(); await wait(0.4); cur().advance(); await wait(2.5)
	await shot("06_eden_start")
	var w = world()
	w.move_target = w.objectives[0].zone
	await wait(3.5)
	await shot("07_eden_walk")
	await tp("vine"); await shot("08_act_prompt"); w.act_pressed(); await wait(1.0)
	await tp("fig"); w.act_pressed(); await wait(1.2)
	await tp("lamb"); w.act_pressed(); await wait(0.5); await shot("09_name_lamb")
	w.hud.clear_overlay(); w._lamb_named("Meadow"); await wait(0.6)
	await tp("stone"); w.act_pressed(); await wait(0.6); await shot("10_word_study")
	w.hud.clear_overlay(); w._stone_read(); await wait(1.0)
	await shot("11_eden_trees")
	w.hud.open_sheet("bag"); await wait(0.5); await shot("12_sheet_bag")
	w.hud.open_sheet("status"); await wait(0.4); await shot("13_sheet_status")
	w.hud.clear_overlay(); w.hud.open_more(); await wait(0.4); await shot("14_more")
	w.hud.clear_overlay()
	await tp("trees"); w.act_pressed(); await wait(1.2); await shot("15_fall")
	for i in 4:
		cur().advance(); await wait(0.5)
	await wait(1.0); await shot("16_wake")
	cur().advance(); await wait(0.4); cur().advance(); await wait(3.0)
	w = world()
	await shot("17_city")
	var t0 := Time.get_ticks_msec(); var ko_done := false; var mid := false
	while w.slain < 3 and Time.get_ticks_msec() - t0 < 90000:
		w.attack_pressed()
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
	await tp("evangelist"); w.act_pressed(); await wait(0.6); await shot("21_dialog")
	w.hud.clear_overlay(); w.after_evangelist(); await wait(1.0)
	await shot("22_warp")
	w.hud.enter_snapshot(); await wait(0.5); await shot("23_snapshot"); w.hud.exit_snapshot()
	w.player.position = Vector3(19.5, 0, 0); await wait(2.5)
	await shot("24_end")
	print("[autotest] done")
	get_tree().quit()
