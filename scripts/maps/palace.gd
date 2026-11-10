extends RefCounted
## Palace Beautiful: the first House.

var w: World

func _init(world: World) -> void:
	w = world

func build() -> void:
	w.bounds = Rect2(-20, -12, 40, 26)
	w.kit._plane(Vector2(120, 100), w.kit._mat("res://assets/tiles/grass.png", Vector2(60, 50), false, Color(0.9, 0.95, 0.8)), Vector3.ZERO)
	w.kit._plane(Vector2(26, 15), w.kit._mat("res://assets/tiles/cobble.png", Vector2(13, 7.5), false, Color(1.0, 0.96, 0.88)), Vector3(0, 0.01, -1.5))
	w.kit._plane(Vector2(3.4, 14), w.kit._mat("res://assets/tiles/dirt.png", Vector2(1.7, 7), false, Color(0.92, 0.86, 0.74)), Vector3(0, 0.012, 9))
	var stonem := w.kit._mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(1.0, 0.97, 0.9))
	var roofm := w.kit._mat("res://assets/tiles/roof.png", Vector2(0.6, 0.6), true, Color(0.62, 0.72, 1.0))
	# the palace itself, "a very stately palace … by the highway side"
	w.kit._box(Vector3(26, 6.5, 5), stonem, Vector3(0, 3.25, -12.5))
	var pr := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(27, 3.0, 5.8); pr.mesh = pm; pr.material_override = roofm; pr.position = Vector3(0, 8.0, -12.5); w.add_child(pr)
	for tx in [-14.0, 14.0]:
		w.kit._box(Vector3(4.2, 10, 4.2), stonem, Vector3(tx, 5, -12.0))
		var cone := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 3.0; cm.height = 4.0; cone.mesh = cm; cone.material_override = roofm
		cone.position = Vector3(tx, 12.0, -12.0); w.add_child(cone)
	var win := StandardMaterial3D.new(); win.albedo_color = Color("ffd98a"); win.emission_enabled = true; win.emission = Color("ffc860"); win.emission_energy_multiplier = 1.1
	for wx in [-9.0, -6.0, 6.0, 9.0]:
		for wy in [2.4, 4.8]:
			w.kit._box(Vector3(1.0, 1.3, 0.06), win, Vector3(wx, wy, -9.97), false)
	w.kit._box(Vector3(3.0, 3.6, 0.1), w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.6, 0.45, 0.32)), Vector3(0, 1.8, -9.95), false)
	var door_l := OmniLight3D.new(); door_l.light_color = Color("ffe9b0"); door_l.light_energy = 2.2; door_l.omni_range = 7.0; door_l.position = Vector3(0, 3.2, -8.6); w.add_child(door_l)
	w.kit.holy_lights.append(door_l)
	var dh := Sprite3D.new(); dh.texture = G.tex("res://assets/fx/glow.png"); dh.pixel_size = 0.07; dh.billboard = BaseMaterial3D.BILLBOARD_ENABLED; dh.shaded = false
	dh.modulate = Color(1, 0.95, 0.75, 0.5); dh.position = Vector3(0, 2.4, -9.6); w.add_child(dh); w.kit.holy_lights.append(dh)
	# the hearth (rest is required once before Act III)
	var hearth := Node3D.new(); hearth.position = Vector3(-8, 0, -3); w.add_child(hearth)
	var rockm := w.kit._mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.7, 0.68, 0.66))
	for k in 8:
		var ang := k * TAU / 8.0
		var r := MeshInstance3D.new(); var rs := SphereMesh.new(); rs.radius = 0.24; rs.height = 0.36; r.mesh = rs; r.material_override = rockm
		r.position = Vector3(cos(ang) * 0.8, 0.14, sin(ang) * 0.8); hearth.add_child(r)
	w.kit._solid_cyl(0.9, hearth.position)
	Fx.particles(hearth, hearth.global_position + Vector3(0, 0.2, 0), {"amount": 22, "life": 0.9, "one_shot": false, "explode": 0.0, "sphere": 0.35, "dir": Vector3.UP, "spread": 12.0,
		"vmin": 1.0, "vmax": 1.8, "gravity": Vector3(0, 0.6, 0), "color": Color("ffb048"), "size": 0.32, "local": true})
	var fire := OmniLight3D.new(); fire.light_color = Color("ff9a40"); fire.light_energy = 1.8; fire.omni_range = 6.0; fire.position = Vector3(0, 1.0, 0); hearth.add_child(fire)
	w.kit.lamps.append(fire)
	var benchm := w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.75, 0.6, 0.45))
	w.kit._box(Vector3(0.6, 0.42, 1.8), benchm, Vector3(-10.4, 0.21, -3))
	w.kit._box(Vector3(0.6, 0.42, 1.8), benchm, Vector3(-5.6, 0.21, -3))
	w.kit._box(Vector3(2.4, 0.42, 0.6), benchm, Vector3(-8, 0.21, -5.4))
	w._add_ent("hearth", "The Hearth", hearth.position, hearth, "Rest", "sit", _act_hearth)
	# the Muster Board
	var board := Node3D.new(); board.position = Vector3(8, 0, -3); w.add_child(board)
	for x in [-1.1, 1.1]:
		var bpst := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.16, 2.4, 0.16); bpst.mesh = bb; bpst.material_override = benchm; bpst.position = Vector3(x, 1.2, 0); board.add_child(bpst)
	var panel := MeshInstance3D.new(); var pbm := BoxMesh.new(); pbm.size = Vector3(2.4, 1.4, 0.1); panel.mesh = pbm; panel.material_override = benchm; panel.position = Vector3(0, 1.6, 0); board.add_child(panel)
	var parch := StandardMaterial3D.new(); parch.albedo_color = Color("f4e8c8")
	for k in 3:
		var sh := MeshInstance3D.new(); var qb := BoxMesh.new(); qb.size = Vector3(0.6, 0.8, 0.02); sh.mesh = qb; sh.material_override = parch
		sh.position = Vector3(-0.72 + k * 0.72, 1.6, 0.07); sh.rotation.z = (k - 1) * 0.06; board.add_child(sh)
	w.kit._solid_box(Vector3(2.6, 2, 0.4), board.position + Vector3(0, 1, 0))
	w._add_ent("board", "Muster Board", board.position, board, "Muster", "friends", func(): w.hud.muster_board())
	# doors: armory and reading room
	w._add_ent("armory", "The Armory", Vector3(-6, 0, -9.2), null, "Enter", "equip", func(): G.say("The armory: here every pilgrim is given the whole armour of God, the same for all (Act II, full game). [BSB: Ephesians 6:13]", G.NPC))
	w._add_ent("reading", "Reading Room", Vector3(6, 0, -9.2), null, "Enter", "library", func(): G.say("Reading Together rooms: friends read one passage side by side. On the Lord's Day they are quiet and reward-free.", G.NPC))
	# the porter
	var watchful := w.kit._sprite_npc("res://assets/sprites/npc_evangelist.png", 2, 5, true, Vector3(2.6, 0, 6.5), "Watchful the Porter", Color("ffe9a0"))
	watchful.set_tint(Color(1.05, 0.95, 0.8))
	w._add_ent("watchful", "Watchful", watchful.position, watchful, "Talk", "talk", _act_watchful)
	# lamps, trees, a fountain
	for lp in [Vector3(-3, 0, 4.5), Vector3(3, 0, 4.5), Vector3(-12, 0, 2), Vector3(12, 0, 2)]:
		w.kit._box(Vector3(0.15, 3, 0.15), w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.3, 0.3, 0.32)), lp + Vector3(0, 1.5, 0))
		var lamp := OmniLight3D.new(); lamp.light_color = Color("ffd080"); lamp.light_energy = 1.4; lamp.omni_range = 5.0; lamp.position = lp + Vector3(0, 3.0, 0); w.add_child(lamp); w.kit.lamps.append(lamp)
		var halo := Sprite3D.new(); halo.texture = G.tex("res://assets/fx/glow.png"); halo.pixel_size = 0.03; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.shaded = false; halo.modulate = Color(1, 0.85, 0.5, 0.7); halo.position = lp + Vector3(0, 3.05, 0); w.add_child(halo)
	var basin := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 1.4; bc.bottom_radius = 1.5; bc.height = 0.6; basin.mesh = bc; basin.material_override = stonem
	basin.position = Vector3(0, 0.3, -2); w.add_child(basin); w.kit._solid_cyl(1.5, Vector3(0, 0, -2))
	w.kit._water(Vector2(2.4, 2.4), Vector3(0, 0.62, -2))
	Fx.particles(w, Vector3(0, 0.9, -2), {"amount": 18, "life": 1.0, "one_shot": false, "explode": 0.0, "sphere": 0.1, "dir": Vector3.UP, "spread": 18.0,
		"vmin": 2.2, "vmax": 2.8, "gravity": Vector3(0, -5, 0), "color": Color(0.85, 0.93, 1.0, 0.7), "size": 0.12, "tex": "res://assets/fx/drop.png", "add": false, "local": false})
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 18:
		var side := i % 3
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(-20, 20), 0, 14.5)
			1: p = Vector3(-20.5, 0, rng.randf_range(-8, 14))
			2: p = Vector3(20.5, 0, rng.randf_range(-8, 14))
		if side == 0 and absf(p.x) < 3.5:
			continue
		w.kit._tree(p, rng.randf_range(0.9, 1.25), Color(rng.randf_range(0.9, 1.1), 1.05, rng.randf_range(0.85, 1.0)))
	w.kit._walls()
	for sp in [Vector3(-6, 0, 2), Vector3(6, 0, -1)]:
		Fx.shaft(w, sp, 10.0, 2.4, 0.16)
	w.quests._add_waymark(Vector3(-2.4, 0, 9.5), "Rest at the hearth before you go on", "Ebenezer", 230)
	# pilgrims in the House (simulated in the offline demo; real players online)
	for i in w.folk.HOUSE_FOLK.size():
		var f: Array = w.folk.HOUSE_FOLK[i]
		var a := w.kit._pilgrim_actor(f[1], f[0], Color("dfe9ff"), false)
		var sitter := i in [3, 6]
		a.position = (Vector3(-8, 0, -3) + Vector3(cos(i) * 1.8, 0, sin(i) * 1.8 + 0.4)) if sitter else w.folk._house_spot()
		w.folk.others.append({"actor": a, "path": [a.position, w.folk._house_spot()], "i": 1, "speed": 2.0, "ghost": false, "wait": randf_range(0.5, 6.0) if not sitter else 999.0,
			"kind": "house", "name": f[0], "chat_t": randf_range(2.0, 12.0) + i * 1.5, "sitter": sitter})
		if sitter:
			a.play("sit")
	w.kit._edge_fade(Color("3a4a30"))
	w.kit._weather_petals()
	w.quests.objectives = [
		{"id": "porter", "text": "Speak with Watchful the Porter", "ent": "watchful"},
		{"id": "rest", "text": "Rest at the hearth (needed once before Act III)", "ent": "hearth"},
		{"id": "muster", "text": "Answer the Muster Board", "ent": "board"}]


func _act_watchful() -> void:
	var src := "John Bunyan, The Pilgrim's Progress (1678) · public domain"
	w.hud.run_dialog([
		{"who": "Watchful", "text": "Fear not the lions, for they are chained, and are placed there for trial of faith where it is, and for discovery of those that have none.", "src": src},
		{"who": "Watchful", "text": "This house was built by the Lord of the hill, and he built it for the relief and security of pilgrims.", "src": src},
		{"who": "Watchful", "text": "Here pilgrims who walked the way alone find one another. Rest at the hearth. Then see the Muster Board: Giant Grim has come to back the lions, and a company is wanted to drive him off.", "src": "Part II tells how Great-heart's company met Giant Grim at the lions."}],
		_watchful_done)


func _watchful_done() -> void:
	if w.quests.cur_obj() == "porter":
		G.add_xp(60, 12); w.quests.complete()


func _act_hearth() -> void:
	if not w.sitting:
		w.toggle_sit()
	if w.quests.cur_obj() == "rest":
		G.house_rested = true
		w.kit._sparkle(w.player.position + Vector3(0, 1.2, 0), Color("ffd8a0"))
		G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = false
		G.say("You rest in the House, among the pilgrims. HP and Zeal restored.", G.INFO)
		G.add_xp(40, 8); w.quests.complete()
	else:
		G.say("You sit by the fire.", G.SYS)


func enter_muster(party: Array) -> void:
	G.muster_party = party
	if w.quests.cur_obj() == "muster":
		w.quests.complete()
	w.ending = true
	G.goto("world", {"map": "lions"})
