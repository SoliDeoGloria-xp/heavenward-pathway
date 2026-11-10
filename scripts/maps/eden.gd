extends RefCounted
## Eden Isle: geometry and the garden's interactions.

var w: World

func _init(world: World) -> void:
	w = world

var dreamer: SpriteActor         # the guide who walks beside you in Eden

var lilies: Array = []           # {actor, pos, bloomed}

var lilies_done := 0

var _vine_leaves: Array = []

var _lamb_actor: SpriteActor


# ------------------------------------------------------------------ Eden Isle
func build() -> void:
	w.bounds = Rect2(-26, -16, 52, 34)
	w.kit._plane(Vector2(120, 100), w.kit._mat("res://assets/tiles/grass.png", Vector2(60, 50), false, Color(0.86, 0.9, 0.78)), Vector3(0, 0, 0))
	w.kit._plane(Vector2(52, 3.2), w.kit._mat("res://assets/tiles/dirt.png", Vector2(26, 1.6), false, Color(0.86, 0.8, 0.7)), Vector3(0, 0.01, 7), 0.0)
	w.kit._plane(Vector2(3.2, 20), w.kit._mat("res://assets/tiles/dirt.png", Vector2(1.6, 10), false, Color(0.86, 0.8, 0.7)), Vector3(4, 0.012, -1))
	w.kit._water(Vector2(80, 6), Vector3(0, 0.03, -19))
	w.kit._box(Vector3(80, 0.6, 1.0), w.kit._mat("res://assets/tiles/dirt.png", Vector2(40, 1), true, Color("e8dcb0")), Vector3(0, 0.0, -15.6), false)
	# raised plateaus with cliffs (real height)
	for p in [[Vector3(-21, 0.7, -10), Vector3(10, 1.4, 9)], [Vector3(20, 0.9, 13), Vector3(14, 1.8, 8)], [Vector3(21, 0.6, -9), Vector3(10, 1.2, 8)]]:
		w.kit._box(p[1], w.kit._mat("res://assets/tiles/dirt.png", Vector2(0.5, 0.5), true, Color("c8a878")), p[0])
		w.kit._box(Vector3(p[1].x + 0.2, 0.18, p[1].z + 0.2), w.kit._mat("res://assets/tiles/grass.png", Vector2(0.5, 0.5), true), p[0] + Vector3(0, p[1].y * 0.5 + 0.08, 0), false)
		for k in 3:
			w.kit._tree(p[0] + Vector3(-p[1].x * 0.3 + k * p[1].x * 0.3, p[1].y * 0.5, randf_range(-1.5, 1.5)), randf_range(0.9, 1.2), Color(randf_range(0.9, 1.1), 1, randf_range(0.85, 1.0)), Color(0, 0, 0, 0), false)
	# border trees
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in 26:
		var side := i % 4
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(-26, 26), 0, 17.5)
			1: p = Vector3(-26.5, 0, rng.randf_range(-14, 17))
			2: p = Vector3(26.5, 0, rng.randf_range(-14, 17))
			3: p = Vector3(rng.randf_range(-12, 12), 0, -14.6)
		if side == 3 and absf(p.x) < 6:
			continue
		w.kit._tree(p, rng.randf_range(0.9, 1.3), Color(rng.randf_range(0.85, 1.1), 1, rng.randf_range(0.8, 1.0)))
	for i in 18:
		var bp := Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-12, 16))
		w.kit._sphere(0.55, w.kit._mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(0.9, 1.05, 0.85)), bp + Vector3(0, 0.35, 0), 0.7)
		var fl := StandardMaterial3D.new(); fl.albedo_color = [Color("f7e36a"), Color("f08ab8"), Color.WHITE][i % 3]; fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for k in 4:
			w.kit._sphere(0.08, fl, bp + Vector3(rng.randf_range(-0.9, 0.9), 0.08, rng.randf_range(-0.9, 0.9)))
	w.kit._walls()
	# vine trellis
	var vine := Node3D.new(); vine.position = Vector3(-4, 0, 3); w.add_child(vine)
	var wood := w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true)
	for x in [-1.0, 1.0]:
		var post := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.14, 1.6, 0.14); post.mesh = b; post.material_override = wood; post.position = Vector3(x, 0.8, 0); vine.add_child(post)
	var bar := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(2.3, 0.12, 0.12); bar.mesh = bb; bar.material_override = wood; bar.position.y = 1.55; vine.add_child(bar)
	var vleaf := w.kit._mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(0.8, 0.9, 0.7))
	var grapes := StandardMaterial3D.new(); grapes.albedo_color = Color("6a4c8c")
	var vine_leaves: Array = []
	for i in 5:
		var lf := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.5; lf.mesh = sm; lf.material_override = vleaf
		lf.position = Vector3(-0.9 + i * 0.45, 1.45 + (i % 2) * 0.1, 0.05); vine.add_child(lf); vine_leaves.append(lf)
		var gr := MeshInstance3D.new(); var gs := SphereMesh.new(); gs.radius = 0.11; gs.height = 0.22; gr.mesh = gs; gr.material_override = grapes
		gr.position = Vector3(-0.8 + i * 0.4, 1.15, 0.15); vine.add_child(gr)
	w.kit._solid_box(Vector3(2.3, 2, 0.3), vine.position + Vector3(0, 1, 0))
	_vine_leaves = vine_leaves
	w._add_ent("vine", "Young Vine", vine.position, vine, "Tend", "hand", _act_vine)
	# fig tree
	var fig := w.kit._tree(Vector3(6, 0, -2), 1.25, Color(0.95, 1.1, 0.9), Color("8c4a7a"))
	w._add_ent("fig", "Fig Tree", fig.position, fig, "Gather", "hand", _act_fig)
	# lamb
	var lamb := w.kit._sprite_npc("res://assets/sprites/npc_lamb.png", 2, 1, false, Vector3(9, 0, 8), "Lamb", Color.WHITE, 0.04, true)
	_lamb_actor = lamb
	w._add_ent("lamb", "Lamb", lamb.position, lamb, "Name", "tag", _act_lamb)
	# stone tablet
	var stone := Node3D.new(); stone.position = Vector3(-10, 0, -4); w.add_child(stone)
	var sm2 := MeshInstance3D.new(); var sbm := BoxMesh.new(); sbm.size = Vector3(1.2, 1.7, 0.35); sm2.mesh = sbm
	sm2.material_override = w.kit._mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.8, 0.8, 0.82)); sm2.position.y = 0.85; stone.add_child(sm2)
	w.kit._solid_box(Vector3(1.2, 2, 0.4), stone.position + Vector3(0, 1, 0))
	w._add_ent("stone", "Stone Tablet", stone.position, stone, "Read", "library", _act_stone)
	# the two trees (shown after reading)
	var trees := Node3D.new(); trees.position = Vector3(16, 0, 0); w.add_child(trees)
	var life := w.kit._tree(Vector3(14.6, 0, 0), 1.35, Color(2.2, 1.9, 0.9), Color(0, 0, 0, 0), false)
	life.reparent(trees)
	var glow := OmniLight3D.new(); glow.light_color = Color("ffe9a0"); glow.light_energy = 2.0; glow.omni_range = 6.0; glow.position = Vector3(-1.4, 3, 0); trees.add_child(glow)
	w.kit.holy_lights.append(glow)
	var lhalo := Sprite3D.new(); lhalo.texture = G.tex("res://assets/fx/glow.png"); lhalo.pixel_size = 0.12; lhalo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lhalo.shaded = false; lhalo.modulate = Color(1, 0.95, 0.7, 0.55); lhalo.position = Vector3(-1.4, 3.0, 0); trees.add_child(lhalo)
	w.kit.holy_lights.append(lhalo)
	var know := w.kit._tree(Vector3(18, 0, 0.4), 1.3, Color(0.8, 0.95, 0.75), Color("d8342a"), false)
	know.reparent(trees)
	w._add_ent("trees", "The Two Trees", Vector3(16, 0, 1.6), trees, "Behold", "eye", _act_trees, true)
	for sp in [Vector3(-12, 0, -6), Vector3(-2, 0, 0), Vector3(8, 0, -6), Vector3(3, 0, 9)]:
		Fx.shaft(w, sp, 10.0, 2.4, 0.18)
	w.kit._weather_petals()
	w.kit._edge_fade(Color("2e4a2a"))
	# Way traces and secrets (GDD v0.3): solo world, but never quite alone
	w.quests._add_secret("dreamer_note", Vector3(24.0, 0, 2.5), "The Dreamer's Note", "Written in a careful hand: \"Mark well the garden, for you will not walk here again.\"", {"xp": 20, "jxp": 3})
	w.quests._add_secret("lily", Vector3(-23.0, 0, -12.0), "A Lily Among Thorns", "A white lily grows alone by the water. [BSB: Song of Songs 2:2]  You take a cutting: Lily Hairpin (cosmetic headgear).", {"item": "Lily Hairpin"})
	w.quests._add_waymark(Vector3(-9.5, 0, 9.0), "Look up: the vine needs tending", "Wren", 18)
	w.quests._add_waymark(Vector3(-12.0, 0, -2.0), "Read slowly [BSB: Psalm 119:105]", "Psalter", 57)
	w.folk._add_passerby([Vector3(-24, 0, 4), Vector3(-6, 0, 8), Vector3(10, 0, 7), Vector3(24, 0, 5)], "Marigold", "walking in the garden", [1, 2, 2], true)
	_build_eden_guides()
	## Six chapters of the Prologue (see data/progression.json and the story doc):
	## E1 The Orchard (walk, tend) · E2 The Four Rivers (rivers, stats) · E3 The Fields (gather, learn)
	## E4 The Garden (name, lilies) · E5 The Midst (read) · E6 The Fall (trees). Base XP sums to 330, Job to 35.
	w.quests.objectives = [
		{"id": "walk", "text": "Walk to the glowing circle by the Dreamer's lamp", "zone": Vector3(-8, 0, 7), "xp": [20, 5]},
		{"id": "tend", "text": "Tend the Young Vine (tap Act when close)", "ent": "vine", "xp": [20, 2]},
		{"id": "rivers", "text": "Follow the water to the river's edge", "zone": Vector3(0, 0, -15), "xp": [35, 5], "chapter": "The Four Rivers"},
		{"id": "stats", "text": "Spend your attribute points (More → Status)"},
		{"id": "gather", "text": "Gather figs from the Fig Tree", "ent": "fig", "xp": [60, 8], "chapter": "The Fields"},
		{"id": "learn", "text": "Learn Tend and Keep (More → Skills)"},
		{"id": "lilies", "text": "Tend the drooping lilies with your skill (0/3)", "chapter": "The Garden"},
		{"id": "name", "text": "Give the Lamb a name", "ent": "lamb", "xp": [55, 7]},
		{"id": "read", "text": "Read the Stone Tablet (Word Study)", "ent": "stone", "xp": [20, 2], "chapter": "The Midst of the Garden"},
		{"id": "trees", "text": "Behold the two trees in the midst of the garden", "ent": "trees"}]


# ------------------------------------------------------------------ interaction handlers
func _act_vine() -> void:
	if w.quests.cur_obj() != "tend":
		G.say("The vine is flourishing.", G.SYS); return
	var nm := w.kit._mat("res://assets/tiles/leaves.png", Vector2(1, 1), true, Color(1.0, 1.2, 0.9))
	for lf in _vine_leaves:
		lf.material_override = nm
	w.kit._sparkle(w.ent("vine").pos + Vector3(0, 1.4, 0))
	G.say("You tended the vine. It flourishes.", G.SYS)
	w.quests.complete()


func _act_fig() -> void:
	if w.quests.cur_obj() != "gather":
		G.say("The branches are heavy with fruit.", G.SYS); return
	G.bag_add("Garden Fig", 3); G.say("You got Garden Fig ×3. They are in your Satchel.", G.INFO); w.kit._item_pop("fig")
	w.quests.complete()


func _act_lamb() -> void:
	if w.quests.cur_obj() != "name":
		G.say("%s grazes peacefully." % w.ent("lamb").name, G.SYS); return
	w.hud.name_animal(_lamb_named)


func _lamb_named(n: String) -> void:
	w.ent("lamb").name = n
	_lamb_actor.set_name_text(n)
	G.say("You named the lamb %s." % n, G.SYS)
	w.quests.complete()


func _act_stone() -> void:
	if w.quests.cur_obj() != "read":
		G.say("Words are carved upon the stone.", G.SYS); return
	w.hud.word_study(_stone_read)


func _stone_read() -> void:
	w.hud.motes_to_plate(w.cam.unproject_position(w.ent("stone").pos + Vector3(0, 1.2, 0)))
	G.manna += 5
	G.say("Word Study complete. Manna +5.", G.INFO)
	w.kit._motes(w.player.position)
	w.quests.complete()
	if G.tip_once("manna"):
		w.get_tree().create_timer(1.4).timeout.connect(w.lessons._lesson_manna)


func _act_trees() -> void:
	if w.ending:
		return
	w.ending = true
	G.add_xp(70, 0, "eden")   # E6 The Fall
	w.scene._fall_scene()


func _build_eden_guides() -> void:
	# the Dreamer walks beside you (a vision-guide; never a depiction of God)
	dreamer = w.kit._pilgrim_actor([1, 5, 3], w.lessons.DREAMER, Color("ffe9a0"), false)
	dreamer.position = w.info("start") + Vector3(1.6, 0, 1.0)
	var de := w._add_ent("dreamer", w.lessons.DREAMER, dreamer.position, dreamer, "Talk", "talk", w.lessons._talk_dreamer)
	de["kind"] = "guide"   # tap him to ask what's next; he never steals the Act button
	# three drooping lilies for the first skill
	for lp in [Vector3(0.2, 0, 5.2), Vector3(2.2, 0, 3.4), Vector3(-1.6, 0, 1.8)]:
		var a := SpriteActor.new(); w.add_child(a); a.position = lp
		a.setup({"tex": G.tex("res://assets/sprites/lily.png"), "hframes": 2, "vframes": 1, "pixel": 0.035, "rows": false, "shadow": 0.5,
			"anims": {"idle": [0], "bloom": [1]}}, "", Color.WHITE)
		lilies.append({"actor": a, "pos": lp, "bloomed": false})


func _dreamer_tick(delta: float) -> void:
	if dreamer == null or w.cinema:
		return
	var e := w.ent("dreamer")
	var to := w.player.position - dreamer.position; to.y = 0
	if to.length() > 3.2:
		dreamer.position += to.normalized() * minf(w.SPEED * 0.95 * delta, to.length() - 2.4)
		dreamer.facing = to.normalized(); dreamer.play("walk")
	else:
		dreamer.play("idle"); dreamer.facing = to.normalized() if to.length() > 0.1 else dreamer.facing
	if not e.is_empty():
		e.pos = dreamer.position


## Objectives that finish by themselves (spend points, learn a skill).
func _eden_obj_tick() -> void:
	match w.quests.cur_obj():
		"stats":
			if G.stat_pts == 0:
				w.quests.complete()
		"learn":
			if G.has_skill("tend"):
				w.quests.complete()

## Per-frame hook called by the world loop.
func tick(delta: float) -> void:
	_dreamer_tick(delta)
	_eden_obj_tick()
