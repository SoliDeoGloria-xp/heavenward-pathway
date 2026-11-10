class_name SkillFx
extends RefCounted
## What each skill looks and sounds like. A skill names a style and a colour in data/skills.json
## ("vfx": {"kind", "color"}), so every skill reads differently without its own code.
## at = the target's position for strikes, the player's for everything else.

const SOUND := {"slash": "hit", "smite": "aoe", "arrow": "arrow", "word": "skill", "wave": "aoe", "shield": "buff", "water": "heal", "gift": "heal",
	"wind": "skill", "watch": "buff", "prayer": "prayer", "lamp": "buff"}

static func play(w: World, id: String, at: Vector3) -> void:
	var v: Dictionary = G.SKILL_INFO[id].get("vfx", {})
	if v.is_empty():
		return
	var c := Color(String(v.color))
	var me := w.player.position
	G.sfx(SOUND.get(v.kind, "skill"))
	match String(v.kind):
		"slash":     # a bright cut across the target
			Fx.flash_card(w, at + Vector3(0, 0.9, 0), c, 1.6, 0.18, "res://assets/fx/star.png")
			Fx.sparks(w, at + Vector3(0, 0.8, 0), (at - me).normalized(), c); Fx.ring(w, at, c, 1.6, 0.3)
		"smite":     # a pillar of light falls on the target
			_fade(w, Fx.shaft(w, at, 8.0, 1.8), 0.7)
			Fx.ring(w, at, c, 2.6, 0.5); Fx.burst(w, at + Vector3(0, 0.6, 0), c, 26); w.shake(0.25)
		"arrow":     # a streak from the pilgrim to the target
			_streak(w, me + Vector3(0, 1.1, 0), at + Vector3(0, 0.8, 0), c)
		"word":      # widening rings of written light
			for i in 3:
				w.get_tree().create_timer(0.09 * i).timeout.connect(Fx.ring.bind(w, at, c.lerp(Color.WHITE, 0.3 * i), 1.4 + i * 0.9, 0.45))
			Fx.motes_up(w, at + Vector3(0, 0.3, 0), c, 22, 1.2); Fx.flash_card(w, at + Vector3(0, 1.0, 0), c, 1.2, 0.2)
		"wave":      # ground waves rolling out from the pilgrim
			for i in 3:
				w.get_tree().create_timer(0.12 * i).timeout.connect(Fx.ring.bind(w, me, c, 2.4 + i * 1.3, 0.5))
			Fx.dust(w, me, Color(c.r, c.g, c.b, 0.6), 14); w.shake(0.22)
		"shield":    # a dome closes over the pilgrim
			Fx.ring(w, me, c, 1.8, 0.5); Fx.ring(w, me, c.lerp(Color.WHITE, 0.4), 1.1, 0.35)
			_orbit(w, me, c)
		"water":     # ripples and rising drops
			for i in 2:
				w.get_tree().create_timer(0.18 * i).timeout.connect(Fx.ring.bind(w, me, c, 1.6 + i, 0.7))
			Fx.particles(w, me + Vector3(0, 0.2, 0), {"amount": 22, "life": 1.1, "sphere": 0.9, "dir": Vector3.UP, "spread": 10.0, "vmin": 1.2, "vmax": 2.2,
				"gravity": Vector3(0, -1.5, 0), "color": c, "size": 0.14, "tex": "res://assets/fx/drop.png", "add": true})
		"gift":      # warm light settles from above
			Fx.particles(w, me + Vector3(0, 3.0, 0), {"amount": 26, "life": 1.3, "sphere": 0.8, "dir": Vector3.DOWN, "spread": 12.0, "vmin": 1.2, "vmax": 2.0,
				"gravity": Vector3(0, -0.6, 0), "color": c, "size": 0.16})
			Fx.star(w, me + Vector3(0, 2.3, 0))
		"wind":      # a rush along the ground
			Fx.spiral(w, me + Vector3(0, 0.2, 0), c); Fx.dust(w, me, Color(c.r, c.g, c.b, 0.5), 10)
			Fx.afterimages(w, w.pact, me - w.pact.facing * 1.4, me, 3)
		"watch":     # a keen glint above the head
			Fx.star(w, me + Vector3(0, 2.5, 0)); Fx.flash_card(w, me + Vector3(0, 2.5, 0), c, 0.9, 0.3)
			Fx.ring(w, me, c, 1.2, 0.35)
		"prayer":    # light from above, and everything near gives way
			_fade(w, Fx.shaft(w, me, 9.0, 2.6), 0.9)
			Fx.motes_up(w, me + Vector3(0, 0.2, 0), c, 30, 1.6)
			for i in 2:
				w.get_tree().create_timer(0.15 * i).timeout.connect(Fx.ring.bind(w, me, c, 3.0 + i * 1.5, 0.6))
		"lamp":      # a lamp flares
			Fx.flash_card(w, me + Vector3(0, 1.4, 0), c, 2.6, 0.4); Fx.motes_up(w, me + Vector3(0, 0.4, 0), c, 16, 1.4)

static func _fade(w: World, node: Sprite3D, secs: float) -> void:
	var tw := w.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, secs)
	tw.tween_callback(node.queue_free)

static func _streak(w: World, from: Vector3, to: Vector3, c: Color) -> void:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/fx/glow.png"); s.pixel_size = 0.012; s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false; s.modulate = c; s.position = from; w.add_child(s)
	var tw := w.create_tween()
	tw.tween_property(s, "position", to, 0.12)
	tw.tween_callback(func() -> void:
		Fx.burst(w, to, c, 16); Fx.ring(w, to - Vector3(0, 0.8, 0), c, 1.4, 0.3); s.queue_free())
	Fx.sparks(w, from, (to - from).normalized(), c)

static func _orbit(w: World, at: Vector3, c: Color) -> void:
	Fx.particles(w, at + Vector3(0, 1.0, 0), {"amount": 14, "life": 1.0, "sphere": 1.1, "explode": 0.6, "dir": Vector3.UP, "spread": 80.0, "vmin": 0.3, "vmax": 0.8,
		"gravity": Vector3.ZERO, "color": c, "size": 0.13})
