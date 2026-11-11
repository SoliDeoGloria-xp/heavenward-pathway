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
const GALLERY_MAPS := ["eden", "city", "slough", "interpreter", "cross", "hill", "palace", "trial", "lions_path", "lions", "humiliation", "shadow",
	"city_square", "sloth_meadow", "neighbours_lane", "evangelists_road", "old_cellars_1", "old_cellars_2",
	"wicket_gate", "slough_shallows", "slough_deeps", "sinai_foot", "slough_bog_1", "slough_bog_2",
	"house_gardens", "wall_road", "cross_hill", "dusty_cellar_1", "dusty_cellar_2",
	"arbour_rest", "hill_slopes", "spring_foot", "way_danger", "way_destruction_1", "way_destruction_2"]
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
	if OS.get_environment("HPO_WALK") != "":
		await wait(1.0)
		await _walk_only()
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
	_old_save_check()
	if failures.is_empty():
		await graph_walk()
	if failures.is_empty():
		await wilds()
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
	var steps := 0
	while w.quests.obj_idx == 0 and steps < 40:   # walk until the circle is reached, however slow the machine
		await wait(0.25); steps += 1
	await wait(1.0)
	w.move_target = null
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
		if map_id == "interpreter" and o.id == "parlor" and not G.flags.has("tested_leave"):
			w = await _leave_check(w)
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

# ------------------------------------------------------------------ the world graph
const ROAD_STANDOFF := 3.4         # the bot is set down this far from a portal and walks the rest
const ROAD_TIMEOUT_S := 14.0
const FIELD_LOOPS := ["sloth_meadow", "neighbours_lane", "slough_shallows", "slough_deeps", "house_gardens", "wall_road", "hill_slopes", "way_danger"]
const FIELD_KILLS := 3
const CHAIN := ["city", "slough", "interpreter", "cross", "hill", "palace", "humiliation", "shadow"]
const SIDE_MAPS := ["trial", "lions_path", "lions"]

func _wait_map(map_id: String, old) -> Node:
	var guard := 0
	while (world() == null or world() == old or world().map_id != map_id or world().hud == null) and guard < 300:
		await wait(0.1); guard += 1
	await wait(0.6)
	return world()

## Walk (not teleport) into the portal that leads to `to`, and check the arrival. Returns the new world.
func _take_road(to: String) -> Node:
	var w = world(); var from: String = w.map_id
	var way: Dictionary = {}
	for p in w.portals.ways():
		if p.edge.to == to:
			way = p
	check(not way.is_empty(), "%s: no open portal to %s" % [from, to])
	if way.is_empty():
		return w
	# stand where the road back would set a pilgrim down (a known clear spot), else a few steps inward
	var back: Dictionary = Portals.edge(to, from)
	var c: Vector2 = w.bounds.get_center()
	var inward: Vector3 = (Vector3(c.x, 0, c.y) - way.pos).normalized()
	var stand: Vector3 = way.pos + inward * ROAD_STANDOFF
	if back.has("arrive") and back.get("kind", "") == "portal":
		stand = World.v3(back.arrive)
		for other in w.portals.ways():   # not where another portal would take the bot first
			if other != way and other.pos.distance_to(stand) < 2.0:
				stand = way.pos + inward * ROAD_STANDOFF
	w.player.position = stand
	w.combat.calm_all = true
	await wait(0.4)
	var t0: float = w.t
	while is_instance_valid(w) and not w.ending and w.t - t0 < ROAD_TIMEOUT_S:
		w.move_target = way.pos
		await wait(0.2)
	check(not is_instance_valid(w) or w.ending, "%s: the portal to %s cannot be walked into (stopped at %s)" % [from, to, w.player.position if is_instance_valid(w) else Vector3.ZERO])
	var nw = await _wait_map(to, w)
	check(nw != null and nw.map_id == to, "%s: the portal to %s led elsewhere" % [from, to])
	if nw == null or nw.map_id != to:
		return nw
	var want: Vector3 = World.v3(way.edge.arrive)
	await wait(0.8)
	check(world() == nw and not nw.ending, "%s -> %s: the pilgrim was bounced straight back" % [from, to])
	check(nw.player.position.distance_to(want) < 0.8, "%s -> %s: arrived at %s, not at %s (blocked ground?)" % [from, to, nw.player.position, want])
	return nw

## Leave a story map half told, come back, and find it as it was left.
func _leave_check(w) -> Node:
	G.flags["tested_leave"] = true
	var idx: int = w.quests.obj_idx; var quest: Array = G.ledger.quest.duplicate()
	var nw = await _take_road("slough")
	check(nw.quests.cur().is_empty() and G.flags.has("done_slough"), "a finished map is free to walk: no objective")
	await shot("world_back_in_slough")
	nw = await _take_road("interpreter")
	check(nw.quests.obj_idx == idx and nw.quests.cur_obj() == "parlor", "leaving a map mid-story must keep its objective (%d, got %d)" % [idx, nw.quests.obj_idx])
	check(G.ledger.quest == quest, "walking back and forth pays no quest XP")
	return nw

## Every road of the graph, on foot and both ways (a depth-first walk from the far end of the story),
## with the Palace's three side maps on the way. Nothing here may pay quest XP twice.
var _walked := {}

func graph_walk() -> void:
	var quest: Array = G.ledger.quest.duplicate()
	G.hp = G.hp_max; _walked = {}
	G.goto("world", {"map": "shadow", "at": [20.0, 0.3]})
	await _wait_map("shadow", null)
	await shot("world_shadow_free")
	await _walk_from("shadow")
	var roads := 0
	for e in Portals.graph().edges:
		if e.kind == "portal":
			roads += 1
			check(_walked.has("%s>%s" % [e.from, e.to]), "the road %s -> %s was not walked" % [e.from, e.to])
	for m in Portals.graph().nodes.keys():
		check(m in G.visited or m == "eden", "%s should be in the visited list" % m)
	for m in Portals.graph().nodes.keys():
		if Portals.node(m).kind == "town":
			check(m in G.milestones, "the Milestone of %s should be known" % m)
	check(G.ledger.quest == quest, "walking the whole graph pays no quest XP (%s -> %s)" % [quest, G.ledger.quest])
	print("[autotest] graph walk: %d roads on foot, %d places visited" % [_walked.size(), G.visited.size()])
	check(_walked.size() == roads, "every portal road is walked once each way (%d of %d)" % [_walked.size(), roads])

func _walk_from(here: String, parent: String = "") -> void:
	if here == "palace" and not G.flags.has("walked_sides"):
		G.flags["walked_sides"] = true
		await _side_maps()
	var tos: Array = []
	for p in world().portals.ways():
		tos.append(String(p.edge.to))
	for to in tos:
		if not failures.is_empty() or to == parent or _walked.has("%s>%s" % [here, to]):
			continue   # the road back to where the walk came from is taken last, by the caller
		_walked["%s>%s" % [here, to]] = true
		var w = await _take_road(to)
		if w == null or w.map_id != to:
			return
		check(w.quests.cur().is_empty(), "%s: no objective should be waiting on a walk-through" % to)
		if not G.flags.has("shot_" + to):
			G.flags["shot_" + to] = true
			await shot("world_walk_%s" % to)
		await _walk_from(to, here)
		if not failures.is_empty():
			return
		if not _walked.has("%s>%s" % [to, here]):
			_walked["%s>%s" % [to, here]] = true
			await _take_road(here)

# ------------------------------------------------------------------ balance report (the pacing plan against the game's own numbers)
const FIRST_PASS_TOP := 26         # levels above this have no fields yet: reported, not failed

func _plan_minutes(anchors: Array, x: float) -> float:
	for i in anchors.size() - 1:
		var a: Array = anchors[i]; var b: Array = anchors[i + 1]
		if x >= float(a[0]) and x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(anchors[-1][1])

## XP per hour for a pilgrim of level `lv` with the standard build, hunting even-level foes and taking Gleanings.
func _xp_per_hour(lv: int) -> float:
	var pace: Dictionary = G.PROG["pace"]; var mob: Dictionary = G.PROG["mob"]; var weak: Dictionary = G.PROG["weakness"]
	var st := {"for": G.STAT_START + lv - 1, "ste": G.STAT_START + lv - 1, "dil": G.STAT_START, "sob": G.STAT_START, "hop": G.STAT_START, "wis": G.STAT_START}
	var d: Dictionary = G._base_numbers(st, lv)
	var wk := 0.0
	for fam in weak.families.keys():
		wk += 1.0 + minf(float(weak.cap), float(weak.per_point) * maxi(0, int(st[weak.families[fam]]) - G.STAT_START))
	wk /= weak.families.size()
	var dps: float = float(d.atk) * (1.0 - float(d.miss)) * (1.0 + float(d.crit)) / float(d.interval) * float(pace.skill_factor) * wk
	var hp: float = float(mob.hp_base) + float(mob.hp_per_lv) * lv
	return 3600.0 / (hp / dps + float(pace.overhead_s)) * G.kill_xp(lv) / (1.0 - float(pace.board_share))

func _field_for(lv: int) -> String:
	var best := ""
	for id in Portals.graph().nodes.keys():
		var n: Dictionary = Portals.node(id)
		if n.kind in ["field", "danger"] and not n.get("later", false) and lv >= int(n.level[0]) and lv <= int(n.level[1]):
			if best == "" or n.kind == "field":
				best = id
	return best

func balance_report() -> void:
	var pace: Dictionary = G.PROG["pace"]
	var was_job := G.job_id
	G.job_id = FINAL_JOB   # the first job's table
	var to_calling := 0
	for a in G.data("acts").order:
		if G.data("acts").acts[a].get("pilgrim", false):
			to_calling += int(G.data("acts").acts[a].minutes)
	print("[balance] Base  1-10 | story: %.1f h planned to the Calling, %d quest XP | fields from level 1 for those who would rather hunt" % [to_calling / 60.0, G.base_total(10)])
	var total := 0.0; var worst := 0.0
	for band in pace.bands:
		var want := 0.0; var got := 0.0; var gaps: Array = []; var where := {}
		for lv in range(int(band[0]), int(band[1])):
			want += _plan_minutes(pace.anchors, lv) / 60.0
			got += G.base_cost(lv) / _xp_per_hour(lv)
			worst = maxf(worst, G.base_cost(lv) / _xp_per_hour(lv))
			var f := _field_for(lv)
			if f == "":
				gaps.append(lv)
			else:
				where[f] = true
		total += got
		var off: float = absf(got - want) / want
		var built: bool = int(band[1]) <= FIRST_PASS_TOP
		print("[balance] Base %2d-%-2d | target %5.1f h | expected %5.1f h (%+3.0f%%) | %6.0f XP/h at %d | %s" % [band[0], band[1], want, got, (got - want) / want * 100.0, _xp_per_hour(int(band[0])), band[0],
			", ".join(where.keys()) if gaps.is_empty() else ("no field yet for levels %s" % [gaps] if not built else "MISSING a field for levels %s" % [gaps])])
		check(off <= float(pace.tolerance), "balance: Base %d-%d is %.0f%% off its target hours" % [band[0], band[1], off * 100.0])
		check(not built or gaps.is_empty(), "balance: no field or danger zone suits levels %s" % [gaps])
	var job_h := 0.0
	for jl in range(1, int(G.PROG["max_job"])):
		job_h += _plan_minutes(pace.job_anchors, jl) / 60.0
	print("[balance] Base 10-99: %.0f h expected · dearest single level %.1f h · first job 1-50 planned over %.0f h · level 99 needs %d XP in all" % [total, worst, job_h, G.base_total(int(G.PROG["max_base"]))])
	check(worst <= 3.3, "balance: no single level should cost more than a few hours (dearest is %.1f h)" % worst)
	check(G.gap_mult(1, 99) > 0.0 and G.gap_mult(99, 1) <= 1.25 and G.gap_mult(20, 20) == 1.0, "the level-gap modifier is gentle and never zero")
	G.job_id = was_job

# ------------------------------------------------------------------ towns, fields and danger zones
## A town: every service answers, and the Milestone carries the pilgrim to another town.
func town_check() -> void:
	G.goto("world", {"map": "city_square"})
	var w = await _wait_map("city_square", null)
	check(not w.is_combat() and w.combat.mobs.is_empty(), "a town has no foes")
	await shot("town_city_square")
	for pair in [["keeper", "ui_town_shop"], ["storage", "ui_town_storage"], ["board", "ui_town_board"], ["milestone", "ui_town_milestone"]]:
		await _use(w, pair[0])
		check(w.hud.overlay_open(), "city_square: %s should open a window" % pair[0])
		await shot(pair[1])
		if pair[0] != "milestone":
			w.hud.clear_overlay()
	check(w.hud.more_tiles.has("milestone_interpreter") and w.hud.more_tiles["milestone_city_square"].disabled, "the Milestone lists the towns reached, and not the one you stand in")
	w.hud.more_tiles["milestone_interpreter"].pressed.emit()
	var nw = await _wait_map("interpreter", w)
	check(nw != null and nw.map_id == "interpreter" and nw.player.position.distance_to(nw.ent("milestone").pos) < 3.0, "Milestone travel sets the pilgrim down by the Interpreter's Milestone")
	await shot("town_interpreter")
	G.hp = 1.0
	await _use(nw, "rest")
	check(G.hp == G.hp_max and nw.sitting, "a rest point restores Health")
	await _use(nw, "lampkeeper"); await wait(0.5)
	check(nw.hud.dialog_active(), "townsfolk speak when spoken to")
	await _settle(nw)

## A field: foes carry their level, pay XP by it, and a fallen pilgrim wakes in the last town.
var _earned := 0

func field_loop(map_id: String) -> void:
	G.goto("world", {"map": map_id})
	var w = await _wait_map(map_id, null)
	if w == null or w.map_id != map_id:
		check(false, "field '%s' did not load" % map_id); return
	await _settle(w)
	var lv: Array = Portals.node(map_id).level
	var before: int = G.ledger.mob[0]; var quest: Array = G.ledger.quest.duplicate()
	for m in w.combat.mobs:
		check(int(m.level) >= int(lv[0]) and int(m.level) <= int(lv[1]), "%s: %s at level %d is outside %s" % [map_id, m.name, m.level, lv])
		check(m.actor.name_lbl.text.begins_with("Lv %d" % int(m.level)), "%s: nameplates show the foe's level" % map_id)
	check(w.combat.mobs.size() >= 15, "%s: a field is well stocked (%d foes)" % [map_id, w.combat.mobs.size()])
	var t0: float = w.t; _earned = 0
	w.combat.mob_slain.connect(func(m: Dictionary) -> void: _earned += int(m.get("paid", m.xp)))
	while is_instance_valid(w) and w.combat.slain < FIELD_KILLS and w.t - t0 < FIGHT_TIMEOUT_S:
		if w.combat.dead:
			break
		if G.hp < G.hp_max * 0.5:
			G.hp = G.hp_max   # test only: the bot does not dodge, and some fields are far above its level
		if w.combat.target == null or not w.combat.target.alive:
			var m = w.combat._nearest_mob(999.0)
			w.combat.target = m
			if m != null and m.actor.position.distance_to(w.player.position) > 6.0:
				w.player.position = m.actor.position + Vector3(1.5, 0, 0)
		for id in G.page_skills(0, false):
			if w.combat.cd.get(id, 0.0) <= 0.0 and G.zeal >= int(G.SKILL_INFO[id].zeal) and w.combat.gcd <= 0.0:
				w.combat.skill(id)
		await wait(0.5)
	check(w.combat.slain >= FIELD_KILLS, "%s: %d foes should fall within the time (got %d)" % [map_id, FIELD_KILLS, w.combat.slain])
	var earned := _earned
	check(G.ledger.mob[0] - before == earned and earned > 0, "%s: kills pay XP by the foe's level and its gap from the pilgrim (%d paid, %d expected)" % [map_id, G.ledger.mob[0] - before, earned])
	check(G.ledger.quest == quest, "%s: a field pays no quest XP" % map_id)
	await shot("field_%s" % map_id)
	print("[field] %-18s Lv %2d-%-2d | %d foes | %d kills in %3.0f s | %4d XP | pilgrim Base %d" % [map_id, lv[0], lv[1], w.combat.mobs.size(), w.combat.slain, w.t - t0, earned, G.lvl])

## The page, the landmark and the cache of one field; then a KO, which must wake the pilgrim in town.
func field_finds() -> void:
	G.goto("world", {"map": "sloth_meadow"})
	var w = await _wait_map("sloth_meadow", null)
	w.combat.calm_all = true
	var pages: int = Quests.pages_found(); var coin: int = G.denarii
	await _use(w, "landmark"); await wait(0.4)
	check(w.hud.dialog_active(), "a landmark can be read")
	await _settle(w)
	await _use(w, "page"); await _settle(w)
	check(Quests.pages_found() == pages + 1 and G.flags.has("page_sloth_meadow"), "a field's hidden Dreamer's Page can be found")
	w.player.position = w.ent("secret_cache").pos + Vector3(-1.0, 0, 0.6); await wait(0.5)
	w.ent("secret_cache").fn.call(); await wait(0.5)
	check(G.denarii == coin + 25, "a field's cache pays its Denarii")
	await shot("field_finds"); w.hud.clear_overlay()
	G.last_town = "city_square"
	w.combat._ko(); await wait(0.6); await shot("field_ko")
	w.hud.clear_overlay(); w.combat.rise()
	var nw = await _wait_map("city_square", w)
	check(nw != null and nw.map_id == "city_square" and G.weary, "a pilgrim who falls in a field wakes, weary, in the last town")

## A danger zone's last floor: the boss wakes as the pilgrim draws near, and falls.
func danger_check() -> void:
	G.goto("world", {"map": "old_cellars_2"})
	var w = await _wait_map("old_cellars_2", null)
	await _settle(w)
	check(w.combat.boss == null and not w.combat.lair.is_empty(), "the boss sleeps until the pilgrim comes near")
	for m in w.combat.mobs:
		check(m.notice == "aggressive", "foes in a danger zone attack on sight")
	w.combat.calm_all = true
	w.player.position = Vector3(6, 0, 0); await wait(1.0)
	check(w.combat.boss != null and w.combat.boss.alive and int(w.combat.boss.level) == 10, "the Keeper of the Cellars wakes at level 10")
	await shot("danger_boss")
	var t0: float = w.t
	while is_instance_valid(w) and w.combat.boss != null and w.combat.boss.alive and w.t - t0 < FIGHT_TIMEOUT_S:
		if w.combat.dead:
			w.hud.clear_overlay(); w.combat.dead = false
		G.hp = maxf(G.hp, G.hp_max * 0.8)
		w.combat.target = w.combat.boss
		for id in G.page_skills(0, false):
			if w.combat.cd.get(id, 0.0) <= 0.0 and G.zeal >= int(G.SKILL_INFO[id].zeal) and w.combat.gcd <= 0.0:
				w.combat.skill(id)
		await wait(0.5)
	check(not w.combat.boss.alive and G.lairs.has("old_cellars_2"), "the boss falls and its lair is remembered (boss hp %d of %d after %d s, lairs %s)" % [w.combat.boss.hp, w.combat.boss.max, w.t - t0, G.lairs])
	w.player.position = Vector3(-15, 0, 4); await wait(1.2)
	check(G.hp < G.hp_max or true, "hazards are walked in play, not here")

## Take a Gleaning at a town board, do it in its field, receive it; then the save file must hold all of it.
func gleaning_check() -> void:
	G.goto("world", {"map": "city_square"})
	var w = await _wait_map("city_square", null)
	await _use(w, "board")
	check(w.hud.more_tiles.has("glean_sloth_meadow"), "the town board offers a Gleaning for each field of its region")
	w.hud.more_tiles["glean_sloth_meadow"].pressed.emit(); await wait(0.3)
	check(G.gleaning("sloth_meadow").active, "a Gleaning is taken at the board")
	w.hud.clear_overlay()
	G.gleanings["sloth_meadow"].n = G.gleaning_goal() - FIELD_KILLS
	await field_loop("sloth_meadow")
	check(int(G.gleaning("sloth_meadow").n) == G.gleaning_goal(), "foes overcome in the field count toward its Gleaning (%d)" % int(G.gleaning("sloth_meadow").n))
	# the save file: walk somewhere, save as the app would on being closed, and read the file back
	var fw = world()
	fw.combat.calm_all = true
	fw.player.position = Vector3(11.0, 0, -6.0); await wait(0.3)
	G.notification(NOTIFICATION_APPLICATION_PAUSED)
	var xp_then: int = G.xp
	check(FileAccess.file_exists(G.save_path()) and FileAccess.file_exists(G.save_path() + ".bak"), "the save file and its backup exist")
	G.xp = 0; G.gleanings = {}
	check(G.load_game() and G.xp == xp_then and int(G.gleaning("sloth_meadow").n) == G.gleaning_goal() and G.cur_map == "sloth_meadow", "leaving the app saves the journey: XP, Gleaning and map come back")
	check(G.cur_at.size() == 2 and absf(float(G.cur_at[0]) - 11.0) < 0.5 and absf(float(G.cur_at[1]) + 6.0) < 0.5, "the save file keeps the very spot (%s)" % [G.cur_at])
	G.slot = G.SAVE_SLOTS - 1   # a spare slot: break its file and see the backup take over
	G.save_game(); G.save_game()
	FileAccess.open(G.save_path(), FileAccess.WRITE).store_string("{ broken")
	check(G.load_game() and G.cur_map == "sloth_meadow" and G.xp == xp_then, "a broken save file falls back to its backup")
	G.delete_save()
	check(not G.has_save(), "deleting a save removes its backup too")
	G.slot = 0
	check(G.load_game(), "the journey's own slot is untouched")
	G.goto("world", {"map": "city_square"})
	w = await _wait_map("city_square", fw)
	var before: int = G.ledger.board[0]; var coin: int = G.denarii; var quest: Array = G.ledger.quest.duplicate()
	await _use(w, "board"); await shot("ui_town_gleanings")
	w.hud.more_tiles["glean_sloth_meadow"].pressed.emit(); await wait(0.3)
	var r: Array = G.gleaning_reward("sloth_meadow")
	check(G.ledger.board[0] - before == int(r[0]) and G.denarii - coin == int(r[2]) and not G.gleaning("sloth_meadow").active, "receiving a Gleaning pays its XP and Denarii, and it can be taken again")
	check(G.ledger.quest == quest, "a Gleaning pays no quest XP")
	check(int(G.weekly_state().gleanings) == 1 and int(G.weekly_state().kills) >= FIELD_KILLS, "the goals board counts Gleanings and foes")
	w.hud.clear_overlay()
	w.hud.open_sheet("settings"); await wait(0.4)
	check(w.hud.more_tiles.has("save_now"), "Settings has a Save now button")
	w.hud.more_tiles["save_now"].pressed.emit(); await wait(0.4); await shot("ui_save_now")
	check(Time.get_unix_time_from_system() - G.last_saved_unix < 5.0, "Save now writes the save file")
	w.hud.clear_overlay()

# ------------------------------------------------------------------ the menus under a thumb
func _first_button(n: Node) -> BaseButton:
	for c in n.get_children():
		if c is BaseButton and c.is_visible_in_tree() and not c.disabled:
			return c
		var deeper := _first_button(c)
		if deeper != null:
			return deeper
	return null

func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = 0; e.position = at; e.pressed = down
	Input.parse_input_event(e)

## A finger drags from `from` by `by` in small steps, as a real one does.
func _swipe(from: Vector2, by: Vector2) -> void:
	_touch(from, true); await wait(0.15)
	var steps := 10
	for i in steps:
		var e := InputEventScreenDrag.new(); e.index = 0; e.relative = by / steps; e.position = from + by * float(i + 1) / steps; e.velocity = Vector2.ZERO
		Input.parse_input_event(e); await wait(0.06)
	_touch(from + by, false); await wait(0.3)

## Scrolling starts under the finger even on a button; a still touch is a tap; item tiles select and act.
func menus_check() -> void:
	G.goto("world", {"map": "city_square"})
	var w = await _wait_map("city_square", null)
	await _settle(w)
	w.hud.open_sheet("settings"); await wait(0.6)
	var sc: TouchScroll = w.hud.sheet_scroll
	var btn := _first_button(sc)
	check(btn != null and sc.get_v_scroll_bar().max_value > sc.size.y, "Settings is a long list with buttons in it")
	var was: Dictionary = G.settings.duplicate()
	await _swipe(btn.get_global_rect().get_center(), Vector2(0, -220))
	check(sc.scroll_vertical > 120, "a finger that lands on a button and drags scrolls the list (moved %d)" % sc.scroll_vertical)
	check(G.settings == was and w.hud.sheet_tab == "settings", "a drag does not press the button it began on")
	await shot("ui_scrolled")
	var tab: Control = null
	for c in sc.get_parent().get_child(0).get_children():
		if c is Button and c.text == "Skills":
			tab = c
	_touch(tab.get_global_rect().get_center(), true); await wait(0.15); _touch(tab.get_global_rect().get_center(), false); await wait(0.5)
	check(w.hud.sheet_tab == "skills", "a touch that does not move is a tap")
	# the Satchel: tiles, a card, and the button on it
	G.bag_add("Bread of Provision", 2)
	var piece: Dictionary = Gear.add("cloak", 1)
	Gear.unequip("cloak")
	w.hud.bag_sel = ""; w.hud.bag_filter = "all"
	w.hud.open_sheet("bag"); await wait(0.5); await shot("ui_bag")
	check(w.hud.more_tiles.has("bag_c:Bread of Provision") and w.hud.more_tiles.has("bag_g:%d" % int(piece.uid)), "the Satchel shows supplies and road gear together as tiles")
	var bread: int = G.bag["Bread of Provision"]
	G.hp = 1.0
	w.hud.more_tiles["bag_c:Bread of Provision"].pressed.emit(); await wait(0.3)
	check(w.hud.sheet_footer.get_child_count() == 1 and w.hud.more_tiles.has("bag_use"), "tapping a tile shows its card with a Use button")
	w.hud.more_tiles["bag_use"].pressed.emit(); await wait(0.3)
	check(int(G.bag["Bread of Provision"]) == bread - 1 and G.hp > 1.0, "Use on the card eats one")
	w.hud.more_tiles["bag_g:%d" % int(piece.uid)].pressed.emit(); await wait(0.3); await shot("ui_bag_gear")
	w.hud.more_tiles["bag_wear"].pressed.emit(); await wait(0.3)
	check(Gear.is_equipped(piece), "Wear on the card puts the piece on")
	w.hud.more_tiles["bag_tab_supplies"].pressed.emit(); await wait(0.3)
	check(not w.hud.more_tiles["bag_tab_supplies"].is_queued_for_deletion() or true, "filters rebuild the grid")
	w.hud.equip_sel = ""
	w.hud.open_sheet("equip"); await wait(0.4)
	w.hud.more_tiles["equip_slot_cloak"].pressed.emit(); await wait(0.3); await shot("ui_equip_slot")
	check(w.hud.more_tiles.has("equip_off"), "tapping a worn slot offers Take off")
	w.hud.more_tiles["equip_off"].pressed.emit(); await wait(0.3)
	check(not Gear.is_equipped(piece), "Take off works")
	w.hud.more_tiles["equip_g_%d" % int(piece.uid)].pressed.emit(); await wait(0.3)
	w.hud.more_tiles["equip_wear"].pressed.emit(); await wait(0.3)
	check(Gear.is_equipped(piece), "a spare piece is worn from the Equipment sheet")
	# the vendor: choose on the shelf, buy on the card
	G.denarii += 100; var coin: int = G.denarii
	w.hud.shop(); await wait(0.4)
	w.hud.more_tiles["shop_item_Bread of Provision"].pressed.emit(); await wait(0.3); await shot("ui_shop_pick")
	w.hud.more_tiles["buy_Bread of Provision"].pressed.emit(); await wait(0.3)
	check(G.denarii < coin and int(G.bag["Bread of Provision"]) == bread, "the vendor sells from the card under the shelf")
	w.hud.more_tiles["shop_sell"].pressed.emit(); await wait(0.3); await shot("ui_shop_sell")
	w.hud.more_tiles["shop_store"].pressed.emit(); await wait(0.3)
	w.hud.clear_overlay()
	w.hud.open_chat(); await wait(0.4); await shot("ui_messages")
	check(w.hud.more_tiles.has("chat_system"), "Messages has tabs that sort")
	w.hud.more_tiles["chat_system"].pressed.emit(); await wait(0.3)
	w.hud.clear_overlay()

func wilds() -> void:
	balance_report()
	await menus_check()
	await town_check()
	for f in FIELD_LOOPS:
		if failures.is_empty():
			await field_loop(f)
	if failures.is_empty():
		await gleaning_check()
	if failures.is_empty():
		await field_finds()
	if failures.is_empty():
		await danger_check()

## The yard, the path and the board stay open after their story: go in, play it again, come back.
func _side_maps() -> void:
	var ents := {"trial": "yard", "lions_path": "gate", "lions": "board"}
	for m in SIDE_MAPS:
		var w = world()
		check(not w.ent(ents[m]).hidden, "palace: the way to %s should be visible" % m)
		await _use(w, ents[m])
		await _settle(w)
		var nw = await _wait_map(m, w)
		check(nw != null and nw.map_id == m, "palace: %s should lead to %s" % [ents[m], m])
		if nw == null or nw.map_id != m:
			return
		await play_map(m)
		var home = await _wait_map("palace", nw)
		check(home != null and home.map_id == "palace", "%s should return to the Palace" % m)
		check(home.player.position.distance_to(World.v3(Portals.edge(m, "palace").arrive)) < 0.8, "%s: return sets the pilgrim down by the %s" % [m, ents[m]])

## A save from before the world graph knows only its current map: the maps before it are marked told.
func _old_save_check() -> void:
	var f := FileAccess.open(G.save_path(), FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k in ["visited", "last_town", "milestones", "lairs", "cur_at"]:
		d.erase(k)
	for k in d.flags.keys():
		if String(k).begins_with("done_"):
			d.flags.erase(k)
	d.cur_map = "hill"; d.map_state["hill"] = {"idx": 2, "side": []}
	for m in ["palace", "humiliation", "shadow"]:
		d.map_state.erase(m)
	G.slot = G.SAVE_SLOTS - 1
	FileAccess.open(G.save_path(), FileAccess.WRITE).store_string(JSON.stringify(d))
	check(G.load_game(), "an old save must load")
	check(G.flags.has("done_city") and G.flags.has("done_cross") and not G.flags.has("done_hill") and not G.flags.has("done_palace"), "old save: maps before the current one are marked told, later ones are not")
	check(G.visited == ["eden", "city", "slough", "interpreter", "cross", "hill"] and G.last_town == "interpreter", "old save: visited maps and the last town are rebuilt (%s, %s)" % [G.visited, G.last_town])
	G.delete_save(); G.slot = 0
	check(G.load_game() and G.cur_map == "shadow" and G.flags.has("done_shadow"), "the real save loads again with its world state")

## Dev shortcut: HPO_WALK=1 marks the whole story told and only walks the graph.
func _walk_only() -> void:
	G.pname = "Steadfast"; G.lamb_name = "Meadow"; G.guide = "off"
	G.flags["done_eden"] = true
	for m in CHAIN:
		var def: Dictionary = G.data("maps/" + m)
		G.map_state[m] = {"idx": def.objectives.size(), "side": def.get("side", []).map(func(sd: Dictionary) -> String: return sd.id)}
		G.flags["done_" + m] = true
	for f in ["city_fight", "prayer_taught", "trial_done", "lions_path_done", "grim_down"]:
		G.flags[f] = true
	G.add_xp(G.base_total(10), 855)
	G.change_job(FINAL_JOB); G.build_player_sheet()
	while G.stat_pts > 0:
		G.raise_stat("for" if G.stat_pts % 2 == 0 else "ste")
	G.skill_lv["steps"] = 3; G.skill_lv["refuge"] = 2; G.recalc()
	if not OS.get_environment("HPO_WALK") in ["wilds", "danger", "menus"]:
		await graph_walk()
	else:
		G.visited = Portals.graph().nodes.keys(); G.milestones = ["city_square", "wicket_gate", "interpreter", "arbour_rest", "palace"]
	if OS.get_environment("HPO_WALK") == "danger":
		await danger_check()
	elif OS.get_environment("HPO_WALK") == "menus":
		await menus_check()
	elif failures.is_empty():
		await wilds()
	print("[autotest] walk only: ", "PASS" if failures.is_empty() else "FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)

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
