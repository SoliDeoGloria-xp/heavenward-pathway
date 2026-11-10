extends RefCounted
## Palace Beautiful: the first House.

var w: World

func _init(world: World) -> void:
	w = world

func build() -> void:
	w.bounds = Rect2(-20, -12, 40, 26)
	w.kit.flora = "green"
	w.kit.ground("grass", "grass_dark", 0.36)
	w.kit.path(Vector2(26, 15), "cobble_warm", Vector3(0, 0.012, -1.5), 0.25)
	w.kit.path(Vector2(3.4, 14), "dirt", Vector3(0, 0.014, 9))
	# the palace itself, "a very stately palace … by the highway side": the delivered painting
	w.kit.art("palace_beautiful", Vector3(0, 0, -13.5))
	for x in [-14.0, 14.0]:
		w.kit.art("city_wall", Vector3(x, 0, -11.5))
	w.kit._solid_box(Vector3(40, 6.5, 5), Vector3(0, 3.25, -12.5))
	var door_l := OmniLight3D.new(); door_l.light_color = Color("ffe9b0"); door_l.light_energy = 2.2; door_l.omni_range = 7.0; door_l.position = Vector3(0, 3.2, -8.6); w.add_child(door_l)
	w.kit.holy_lights.append(door_l)
	var dh := Sprite3D.new(); dh.texture = G.tex("res://assets/fx/glow.png"); dh.pixel_size = 0.07; dh.billboard = BaseMaterial3D.BILLBOARD_ENABLED; dh.shaded = false
	dh.modulate = Color(1, 0.95, 0.75, 0.5); dh.position = Vector3(0, 2.4, -9.6); w.add_child(dh); w.kit.holy_lights.append(dh)
	# the hearth (rest is required once before Act III)
	var hearth := Node3D.new(); hearth.position = Vector3(-8, 0, -3); w.add_child(hearth)
	for k in 6:
		var ang := k * TAU / 6.0
		w.kit.prop("rock_a", hearth.position + Vector3(cos(ang) * 0.8, 0, sin(ang) * 0.6), {"flip": k % 2 == 0})
	w.kit._solid_cyl(0.9, hearth.position)
	Fx.particles(hearth, hearth.global_position + Vector3(0, 0.2, 0), {"amount": 22, "life": 0.9, "one_shot": false, "explode": 0.0, "sphere": 0.35, "dir": Vector3.UP, "spread": 12.0,
		"vmin": 1.0, "vmax": 1.8, "gravity": Vector3(0, 0.6, 0), "color": Color("ffb048"), "size": 0.32, "local": true})
	var fire := OmniLight3D.new(); fire.light_color = Color("ff9a40"); fire.light_energy = 1.8; fire.omni_range = 6.0; fire.position = Vector3(0, 1.0, 0); hearth.add_child(fire)
	w.kit.lamps.append(fire)
	for bp in [Vector3(-10.6, 0, -3), Vector3(-5.4, 0, -3), Vector3(-8, 0, -5.4)]:
		w.kit.prop("table", bp); w.kit._solid_cyl(0.8, bp)
	w._add_ent("hearth", "The Hearth", hearth.position, hearth, "Rest", "sit", _act_hearth)
	# the Muster Board
	var board := Node3D.new(); board.position = Vector3(8, 0, -3); w.add_child(board)
	w.kit.prop("signpost", board.position, {"solid": false}).reparent(board)
	w.kit._solid_box(Vector3(2.6, 2, 0.4), board.position + Vector3(0, 1, 0))
	w._add_ent("board", "Muster Board", board.position, board, "Muster", "friends", func() -> void: G.say("The Muster Board. Nothing is posted for you just now.", G.SYS))
	# doors: armory and reading room
	w._add_ent("armory", "The Armory", Vector3(-6, 0, -9.2), null, "Enter", "equip", _use_armory)
	w._add_ent("reading", "Reading Room", Vector3(6, 0, -9.2), null, "Enter", "library", func(): G.say("Reading Together rooms: friends read one passage side by side. On the Lord's Day they are quiet and reward-free.", G.NPC))
	# the porter
	var watchful := w.kit.standee("valiant", "Watchful the Porter", Color("ffe9a0")); watchful.position = Vector3(2.6, 0, 6.5)
	w._add_ent("watchful", "Watchful", watchful.position, watchful, "Talk", "talk", Callable())
	# lamps, trees, a fountain
	for lp in [Vector3(-3, 0, 4.5), Vector3(3, 0, 4.5), Vector3(-12, 0, 2), Vector3(12, 0, 2)]:
		w.kit.lamp(lp, Color("ffd080"), 1.4)
	w.kit.art("town_square", Vector3(0, 0, -1.2)); w.kit._solid_cyl(1.5, Vector3(0, 0, -2))
	for bx in [-10.0, 10.0]:
		w.kit.prop("banner_cloth_blue", Vector3(bx, 0, -9.0))
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
		if i % 4 == 1:
			w.kit.art("forest_edge", p, {"flip": i % 2 == 0}); w.kit._solid_cyl(1.2, p)
		else:
			w.kit._tree(p, rng.randf_range(0.9, 1.25))
	w.kit._walls()
	for sp in [Vector3(-6, 0, 2), Vector3(6, 0, -1)]:
		Fx.shaft(w, sp, 10.0, 2.4, 0.16)
	w.quests._add_waymark(Vector3(-2.4, 0, 9.5), "Rest at the hearth before you go on", "Ebenezer", 230)
	# the named fellow pilgrims of the House (single-player: they are characters, not other players)
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
	w.kit.scatter(41, 70, 18, 14)
	w.kit._weather_petals()

func _act_hearth() -> void:
	if not w.sitting:
		w.toggle_sit()
	G.house_rested = true
	w.kit._sparkle(w.player.position + Vector3(0, 1.2, 0), Color("ffd8a0"))
	G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = false
	G.say("You rest in the House, among the pilgrims. Health and Zeal restored.", G.INFO)
	G.stats_changed.emit()

## After the Armor of God is given, the armory's bench refines road gear and cuts Fruit stones.
func _use_armory() -> void:
	if G.armor:
		w.hud.bench()
	else:
		G.say("The armory. The family of the House will bring you here in time.", G.SYS)
