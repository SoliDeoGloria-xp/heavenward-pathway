class_name Cutscene
extends RefCounted
## Story scenes played in-world (the Fall, waking in the City).

var w: World

func _init(world: World) -> void:
	w = world

var _serpent: SpriteActor

var _cherub_nodes: Array = []


# ------------------------------------------------------------------ cinema
func _cinema(on: bool) -> void:
	w.cinema = on
	w.hud.cinema(on)
	if w.quests.quest_mark:
		w.quests.quest_mark.visible = not on
	if not on:
		w.cam_focus = null


## The Fall, played out in the garden rather than on black cards. The man and the woman are
## not shown: the player is the Dreamer's witness. God is never shown or voiced.
func _fall_scene() -> void:
	_cinema(true)
	w.combat.target = null; w.move_target = null; w.pending = null
	w.cam_focus = Vector3(16, 0, 0.5)
	_serpent = SpriteActor.new(); w.add_child(_serpent); _serpent.position = Vector3(19.2, 0, 1.4)
	_serpent.setup({"tex": G.tex("res://assets/sprites/serpent.png"), "hframes": 2, "vframes": 1, "pixel": 0.04, "rows": false, "shadow": 0.7,
		"anims": {"idle": [0, 1]}, "fps": {"idle": 2.0}}, "", Color.WHITE)
	_serpent.visible = false
	w.hud.run_dialog([
		{"who": w.lessons.DREAMER, "text": "Behold the two trees in the midst of the garden: the tree of life, and the tree of the knowledge of good and evil.", "src": "[BSB: Genesis 2:9" + w.lessons.BSB},
		{"who": w.lessons.DREAMER, "text": "The man was told he could eat freely of every tree but one. In the day he ate of that tree, he would surely die.", "src": "[BSB: Genesis 2:16–17" + w.lessons.BSB},
		{"who": w.lessons.DREAMER, "text": "And I saw in my dream that the serpent spoke in the garden, and questioned the word that had been given.", "src": "[BSB: Genesis 3:1" + w.lessons.BSB,
			"fn": _fall_serpent},
		{"who": w.lessons.DREAMER, "text": "The fruit was taken and eaten. The man, the head of all his kind, broke the covenant, and all his children fell with him.", "src": "[BSB: Genesis 3:6 · Romans 5:12" + w.lessons.BSB,
			"fn": func(): _fall_darken(0.5)},
		{"who": w.lessons.DREAMER, "text": "Their eyes were opened, and they knew shame. They hid themselves among the trees of the garden.", "src": "[BSB: Genesis 3:7–8" + w.lessons.BSB,
			"fn": _fall_hide},
		{"who": w.lessons.DREAMER, "text": "So the man was driven out, east of Eden. Cherubim and a flaming sword, turning every way, guarded the way back to the tree of life.", "src": "[BSB: Genesis 3:24" + w.lessons.BSB,
			"fn": func(): _show_cherubim()},
		{"who": w.lessons.DREAMER, "text": "Now my dream turns, pilgrim. Wake… and remember the garden."}],
		func(): G.goto("world", {"map": "city", "wake": true}))


func _fall_serpent() -> void:
	_serpent.visible = true; _serpent.squash(0.3)
	Fx.dust(w, _serpent.position, Color(0.3, 0.35, 0.25, 0.6), 6)


func _fall_hide() -> void:
	_fall_darken(1.0)
	_serpent.visible = false
	w.cam_focus = Vector3(10, 0, -4)


func _fall_darken(k: float) -> void:
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w.sun, "light_color", Color("ffcf9a").lerp(Color("8a7a9a"), k), 2.0)
	tw.tween_property(w.sun, "light_energy", lerpf(0.62, 0.32, k), 2.0)
	tw.tween_property(w.env, "ambient_light_energy", lerpf(0.34, 0.18, k), 2.0)
	w.post.set_shader_parameter("tint", Vector3(1.0, 0.96, 0.9).lerp(Vector3(0.82, 0.82, 0.95), k))
	for h in w.kit.holy_lights:
		if h is OmniLight3D:
			w.create_tween().tween_property(h, "light_energy", 0.3, 2.0)
	if k >= 1.0:
		w.shake(0.25)
		Fx.particles(w, w.player.position + Vector3(0, 6, 0), {"amount": 40, "life": 4.0, "one_shot": false, "explode": 0.0, "sphere": 10.0,
			"vmin": 0.2, "vmax": 0.6, "gravity": Vector3(0.3, -0.6, 0), "color": Color("8a6a3a"), "size": 0.16, "tex": "res://assets/fx/petal.png", "add": false, "local": false})


func _show_cherubim() -> void:
	var gate := Vector3(24, 0, 0)
	w.cam_focus = gate + Vector3(-3, 0, 0)
	for z in [-2.2, 2.2]:
		var c := Sprite3D.new(); c.texture = G.tex("res://assets/fx/cherub.png"); c.pixel_size = 0.03; c.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		c.shaded = false; c.position = gate + Vector3(0, 2.2, z); c.modulate = Color(1, 0.96, 0.8, 0.0); w.add_child(c)
		w.create_tween().tween_property(c, "modulate:a", 0.95, 1.2)
		_cherub_nodes.append(c)
	var sword := Sprite3D.new(); sword.texture = G.tex("res://assets/fx/flame_sword.png"); sword.pixel_size = 0.03; sword.shaded = false
	sword.position = gate + Vector3(0, 2.0, 0); sword.modulate = Color(1, 1, 1, 0); w.add_child(sword)
	w.create_tween().tween_property(sword, "modulate:a", 1.0, 0.8)
	var spin := w.create_tween().set_loops(); spin.tween_property(sword, "rotation:z", TAU, 1.6).as_relative()
	var fl := OmniLight3D.new(); fl.light_color = Color("ff9a40"); fl.light_energy = 3.0; fl.omni_range = 7.0; fl.position = gate + Vector3(0, 2, 0); w.add_child(fl)
	_cherub_nodes.append(sword)
	G.haptic(40)


# ------------------------------------------------------------------ City of Destruction
func _wake_scene() -> void:
	_cinema(true)
	w.pact.play("rest")
	w.cam_dist = 12.0
	w.hud.run_dialog([
		{"who": w.lessons.DREAMER, "text": "I saw a man clothed with rags, standing in a certain place, with his face from his own house, a book in his hand, and a great burden upon his back.",
			"src": "John Bunyan, The Pilgrim's Progress (1678) · public domain"},
		{"who": w.lessons.DREAMER, "text": "That man is you, pilgrim. This is the City of Destruction. You were born in Adam, and the burden is your sin. It slows you, and you cannot put it down by yourself."},
		{"who": G.pname, "text": "What shall I do?", "fn": _wake_rise},
		{"who": w.lessons.DREAMER, "text": "First, rise. Slothlings crowd these streets: the sins of sloth that would keep you sitting still. Overcome them, and someone will come to show you the way."}],
		_wake_done)


func _wake_rise() -> void:
	w.pact.play("idle"); Fx.dust(w, w.player.position, Color(0.7, 0.68, 0.66, 0.5), 4)


func _wake_done() -> void:
	_cinema(false)
	w.cam_dist = 17.0
	w.lessons._city_lessons()
