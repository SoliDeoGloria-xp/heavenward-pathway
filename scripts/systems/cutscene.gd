class_name Cutscene
extends RefCounted
## Plays dialogue scenes from data/dialogue.json inside the world. A line may carry "cam" (an
## anchor named in the map's "anchors", or an entity id) and "fx" (one of the staged effects
## below). Scenes with either run in cinema mode: input and the HUD step aside.
## Content rules held here: God is never shown or voiced; at the Cross only the cross and light appear.

const WAKE_CAM_DIST := 12.0
const DEFAULT_CAM_DIST := 17.0
const GATE_EAST := Vector3(24, 0, 0)        # the cherubim's line, east of Eden
const DUSK := {"sun": Color("ffcf9a"), "sun_e": 0.62, "amb_e": 0.34}
const NIGHT := {"sun": Color("8a7a9a"), "sun_e": 0.32, "amb_e": 0.18}

var w: World
var _serpent: SpriteActor

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ playing scenes
func play(id: String, done: Callable) -> void:
	var lines := G.dialog(id)
	if lines.is_empty():
		done.call(); return
	var staged := false
	for line in lines:
		if line.has("fx") or line.has("cam"):
			staged = true
			line["fn"] = _stage.bind(line)
	w.combat.target = null; w.move_target = null; w.pending = null
	if staged:
		_cinema(true)
	w.hud.run_dialog(lines, func() -> void:
		if staged:
			_cinema(false)
		done.call())

func _cinema(on: bool) -> void:
	w.cinema = on
	w.hud.cinema(on)
	if w.quests.quest_mark:
		w.quests.quest_mark.visible = not on
	if not on:
		w.cam_focus = null

func _stage(line: Dictionary) -> void:
	if line.has("cam"):
		w.cam_focus = _anchor(String(line.cam))
	if line.has("fx") and has_method("_fx_" + String(line.fx)):
		call("_fx_" + String(line.fx))

func _anchor(id: String) -> Vector3:
	var anchors: Dictionary = w.def.get("anchors", {})
	if anchors.has(id):
		return World.v3(anchors[id])
	var e := w.ent(id)
	return e.pos if not e.is_empty() else w.player.position

func _here() -> Vector3:
	return w.player.position

# ------------------------------------------------------------------ Eden: the Fall
## Played in the garden rather than on black cards. The man and the woman are not shown: the
## player is the Dreamer's witness.
func fall() -> void:
	w.cam_focus = Vector3(16, 0, 0.5)
	_serpent = SpriteActor.new(); w.add_child(_serpent); _serpent.position = Vector3(19.2, 0, 1.4)
	_serpent.setup({"tex": G.tex("res://assets/sprites/serpent.png"), "hframes": 2, "vframes": 1, "pixel": 1.0 / G.PX_PER_UNIT, "rows": false, "shadow": 0.7,
		"anims": {"idle": [0, 1]}}, "", Color.WHITE)
	_serpent.visible = false
	play("eden.fall", func() -> void: w.quests.leave("city"))
	w.cam_focus = Vector3(16, 0, 0.5)

func _fx_serpent() -> void:
	_serpent.visible = true; _serpent.squash(0.3)
	Fx.dust(w, _serpent.position, Color(0.3, 0.35, 0.25, 0.6), 6)

func _fx_darken_half() -> void:
	_darken(0.5)

func _fx_hide() -> void:
	_darken(1.0)
	_serpent.visible = false
	w.cam_focus = Vector3(10, 0, -4)
	w.shake(0.25)
	Fx.particles(w, _here() + Vector3(0, 6, 0), {"amount": 40, "life": 4.0, "one_shot": false, "explode": 0.0, "sphere": 10.0,
		"vmin": 0.2, "vmax": 0.6, "gravity": Vector3(0.3, -0.6, 0), "color": Color("8a6a3a"), "size": 0.16, "tex": "res://assets/fx/petal.png", "add": false, "local": false})

## Light falls from dusk (k = 0) to night (k = 1).
func _darken(k: float) -> void:
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w.sun, "light_color", (DUSK.sun as Color).lerp(NIGHT.sun, k), 2.0)
	tw.tween_property(w.sun, "light_energy", lerpf(DUSK.sun_e, NIGHT.sun_e, k), 2.0)
	tw.tween_property(w.env, "ambient_light_energy", lerpf(DUSK.amb_e, NIGHT.amb_e, k), 2.0)
	w.post.set_shader_parameter("tint", Vector3(1.0, 0.96, 0.9).lerp(Vector3(0.82, 0.82, 0.95), k))
	for h in w.kit.holy_lights:
		if h is OmniLight3D:
			w.create_tween().tween_property(h, "light_energy", 0.3, 2.0)

## Evening comes on as the pilgrim turns toward the two trees.
func dusk() -> void:
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w.sun, "light_color", DUSK.sun, 4.0)
	tw.tween_property(w.sun, "light_energy", DUSK.sun_e, 4.0)
	tw.tween_property(w.env, "ambient_light_energy", DUSK.amb_e, 4.0)
	w.post.set_shader_parameter("tint", Vector3(1.06, 0.98, 0.88))

func _fx_cherubim() -> void:
	w.cam_focus = GATE_EAST + Vector3(-3, 0, 0)
	for z in [-2.2, 2.2]:
		var c := Sprite3D.new(); c.texture = G.tex("res://assets/fx/cherub.png"); c.pixel_size = 0.03; c.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		c.shaded = false; c.position = GATE_EAST + Vector3(0, 2.2, z); c.modulate = Color(1, 0.96, 0.8, 0.0); w.add_child(c)
		w.create_tween().tween_property(c, "modulate:a", 0.95, 1.2)
	var sword := Sprite3D.new(); sword.texture = G.tex("res://assets/fx/flame_sword.png"); sword.pixel_size = 0.03; sword.shaded = false
	sword.position = GATE_EAST + Vector3(0, 2.0, 0); sword.modulate = Color(1, 1, 1, 0); w.add_child(sword)
	w.create_tween().tween_property(sword, "modulate:a", 1.0, 0.8)
	var spin := w.create_tween().set_loops(); spin.tween_property(sword, "rotation:z", TAU, 1.6).as_relative()
	var fl := OmniLight3D.new(); fl.light_color = Color("ff9a40"); fl.light_energy = 3.0; fl.omni_range = 7.0; fl.position = GATE_EAST + Vector3(0, 2, 0); w.add_child(fl)
	G.haptic(40)

## The lamb will not cross the cherubim's line (the story's personal thread).
func _fx_lamb_stays() -> void:
	var lamb := w.ent("lamb")
	if lamb.is_empty():
		return
	var stay := GATE_EAST + Vector3(-5.5, 0, 1.5)
	lamb.node.position = stay; lamb.pos = stay
	w.cam_focus = stay
	w.kit._sparkle(stay + Vector3(0, 0.8, 0), Color("fff2b0"))

# ------------------------------------------------------------------ City: waking under the burden
func wake() -> void:
	w.pact.play("rest")
	w.cam_dist = WAKE_CAM_DIST
	play("city.wake", func() -> void:
		w.cam_dist = float(w.def.get("cam_dist", DEFAULT_CAM_DIST))
		w.quests.complete())

func _fx_rise() -> void:
	w.pact.play("idle"); Fx.dust(w, _here(), Color(0.7, 0.68, 0.66, 0.5), 4)

# ------------------------------------------------------------------ the road
func _fx_splash() -> void:
	Fx.dust(w, _here(), Color(0.35, 0.4, 0.3, 0.8), 14); w.shake(0.3); w.pact.squash(0.2)

func _fx_pliable_leaves() -> void:
	var p := w.ent("pliable")
	if not p.is_empty():
		p.erase("follow")
		w.kit._fade_actor(p.node, 1.0, 0.0)

func _fx_help_pulls() -> void:
	Fx.ring(w, _here(), Color(0.85, 1, 0.85), 2.0, 0.5); w.pact.squash(0.15)
	w.kit._sparkle(_here() + Vector3(0, 1.0, 0), Color("dff7ff"))

func _fx_sinai() -> void:
	w.shake(0.5); w.hud.hit_flash()
	Fx.burst(w, _here() + Vector3(1.5, 3.0, -1.0), Color("ff7a30"), 26)

func _fx_gate_opens() -> void:
	var gate := w.ent("knock")
	if not gate.is_empty():
		w.kit._sparkle(gate.pos + Vector3(0, 1.6, 0), Color("fff0c0"))
		Fx.ring(w, gate.pos, Color(1, 0.95, 0.75), 3.0, 0.6)

func _fx_dust() -> void:
	Fx.dust(w, _here(), Color(0.7, 0.62, 0.5, 0.8), 18)

func _fx_sprinkle() -> void:
	Fx.particles(w, _here() + Vector3(0, 2.4, 0), {"amount": 22, "life": 0.9, "sphere": 1.4, "dir": Vector3.DOWN, "spread": 12.0, "vmin": 2.0, "vmax": 3.0,
		"gravity": Vector3(0, -4, 0), "color": Color(0.8, 0.92, 1.0, 0.9), "size": 0.12, "tex": "res://assets/fx/drop.png", "add": false})

func _fx_coins() -> void:
	Fx.burst(w, _here() + Vector3(0, 0.6, -1.2), Color("ffd84a"), 20)

func _fx_fire_up() -> void:
	var f := w.ent("fire")
	var at: Vector3 = f.pos if not f.is_empty() else _here()
	Fx.motes_up(w, at + Vector3(0, 0.8, 0), Color("ffb048"), 30, 2.0)

func _fx_clash() -> void:
	w.shake(0.3); Fx.star(w, _here() + Vector3(0, 1.2, -1.0))

## The burden loosens, tumbles and is seen no more. Nothing but the cross, the tomb and light is shown.
func _fx_burden_fall() -> void:
	G.burden = false
	var ball := w.kit.prop("burden", _here() + Vector3(0.3, 0.7, 0))
	var tomb := _anchor("tomb")
	var tw := w.create_tween()
	tw.tween_property(ball, "position", _here() + Vector3(0.8, 0.35, 0.6), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "position", tomb + Vector3(0, 0.3, -0.8), 2.2)
	tw.tween_property(ball, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_callback(ball.queue_free)
	Fx.spiral(w, _here() + Vector3(0, 0.2, 0), Color("fff2c8"))
	w.pact.squash(0.18); G.haptic_pattern("level")
	G.stats_changed.emit(); w.hud.refresh()

func _fx_garment() -> void:
	w.pact.flash(Color("fff6e0"), 0.9); Fx.dome(w, _here())
	w.kit._sparkle(_here() + Vector3(0, 1.2, 0), Color("fff6d8"))

func _fx_sleep() -> void:
	w.pact.play("rest")
	var tw := w.create_tween()
	tw.tween_method(func(v: float) -> void: w.post.set_shader_parameter("vignette", v), 0.32, 0.9, 1.2)
	tw.tween_interval(1.2)
	tw.tween_method(func(v: float) -> void: w.post.set_shader_parameter("vignette", v), 0.9, 0.32, 1.0)
	tw.tween_callback(func() -> void: w.pact.play("idle"))

## Day breaks in the dark valley.
func _fx_dawn() -> void:
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w.sun, "light_energy", 0.7, 3.0)
	tw.tween_property(w.sun, "light_color", Color("ffe0b0"), 3.0)
	tw.tween_property(w.env, "ambient_light_energy", 0.42, 3.0)
	w.post.set_shader_parameter("tint", Vector3(1.04, 1.0, 0.92))
	w.post.set_shader_parameter("saturation", 0.95)

func _fx_armor() -> void:
	w.pact.flash(Color("dfe9ff"), 0.9); Fx.dome(w, _here()); G.haptic_pattern("level")

func _fx_bell() -> void:
	w.kit._sparkle(_here() + Vector3(0, 1.4, 0), Color("fff2b0")); G.sfx("bell")
