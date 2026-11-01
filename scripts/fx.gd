class_name Fx
extends RefCounted
## Reusable layered effects (VFX library): bursts, sparks, rings, motes, dust, domes, afterimages,
## telegraphs and light shafts. Every skill or event is assembled from these pieces.
## Effects stay bright, short and allegorical (light, motes, warmth); never gore.

static var quality_high := true

static func _mat(tex: String, additive: bool = true, billboard: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = G.tex(tex)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.no_depth_test = false
	return m

static func _fade_ramp(c: Color) -> Gradient:
	var gr := Gradient.new()
	gr.set_color(0, c)
	gr.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return gr

## Generic one-shot particle builder.
static func particles(parent: Node, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var amount: int = o.get("amount", 16)
	if not quality_high:
		amount = maxi(3, amount / 2)
	p.amount = amount
	p.lifetime = o.get("life", 0.8)
	p.one_shot = o.get("one_shot", true)
	p.explosiveness = o.get("explode", 0.9)
	p.direction = o.get("dir", Vector3.UP)
	p.spread = o.get("spread", 60.0)
	p.initial_velocity_min = o.get("vmin", 1.0)
	p.initial_velocity_max = o.get("vmax", 2.5)
	p.gravity = o.get("gravity", Vector3(0, -2.0, 0))
	p.damping_min = o.get("damp", 0.0); p.damping_max = o.get("damp", 0.0)
	p.scale_amount_min = o.get("smin", 0.8); p.scale_amount_max = o.get("smax", 1.3)
	if o.has("sphere"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = o.sphere
	if o.has("orbit"):
		p.orbit_velocity_min = o.orbit; p.orbit_velocity_max = o.orbit
	if o.has("tangent"):
		p.tangential_accel_min = o.tangent; p.tangential_accel_max = o.tangent
	if o.has("radial"):
		p.radial_accel_min = o.radial; p.radial_accel_max = o.radial
	var c: Color = o.get("color", Color.WHITE)
	p.color_ramp = _fade_ramp(c)
	var q := QuadMesh.new(); var sz: float = o.get("size", 0.2); q.size = Vector2(sz * o.get("stretch", 1.0), sz)
	q.material = _mat(o.get("tex", "res://assets/fx/mote.png"), o.get("add", true))
	p.mesh = q
	p.local_coords = o.get("local", false)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	if p.one_shot:
		parent.get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)
	return p

static func burst(parent: Node, pos: Vector3, color: Color = Color("fff2b0"), amount: int = 18) -> void:
	particles(parent, pos, {"amount": amount, "life": 0.55, "vmin": 2.0, "vmax": 4.0, "spread": 180.0, "gravity": Vector3(0, -3, 0), "color": color, "size": 0.16, "damp": 3.0})
	flash_card(parent, pos, color, 0.9, 0.12)

static func sparks(parent: Node, pos: Vector3, dir: Vector3, color: Color = Color.WHITE) -> void:
	particles(parent, pos, {"amount": 10, "life": 0.35, "dir": (dir.normalized() + Vector3(0, 0.4, 0)).normalized(), "spread": 35.0,
		"vmin": 4.0, "vmax": 7.0, "gravity": Vector3(0, -6, 0), "color": color, "size": 0.14, "stretch": 2.6, "tex": "res://assets/fx/spark.png", "damp": 4.0})

static func dust(parent: Node, pos: Vector3, color: Color = Color(0.85, 0.8, 0.7, 0.55), amount: int = 5) -> void:
	particles(parent, pos + Vector3(0, 0.1, 0), {"amount": amount, "life": 0.6, "vmin": 0.3, "vmax": 0.9, "spread": 80.0, "dir": Vector3.UP,
		"gravity": Vector3(0, 0.2, 0), "color": color, "size": 0.35, "tex": "res://assets/fx/puff.png", "add": false, "damp": 1.5})

static func motes_up(parent: Node, pos: Vector3, color: Color = Color("fff3c0"), amount: int = 20, life: float = 1.6) -> void:
	particles(parent, pos, {"amount": amount, "life": life, "explode": 0.4, "sphere": 0.6, "vmin": 0.6, "vmax": 1.4, "spread": 15.0,
		"gravity": Vector3.ZERO, "color": color, "size": 0.13})

static func spiral(parent: Node, pos: Vector3, color: Color) -> void:
	particles(parent, pos, {"amount": 36, "life": 1.6, "explode": 0.2, "sphere": 0.9, "vmin": 1.2, "vmax": 1.8, "spread": 5.0,
		"gravity": Vector3.ZERO, "tangent": 6.0, "radial": -1.0, "color": color, "size": 0.16})

## A flat ring on the ground that expands and fades.
static func ring(parent: Node, pos: Vector3, color: Color, to_scale: float = 3.0, dur: float = 0.6) -> void:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/fx/ring.png"); s.pixel_size = 0.01
	s.rotation_degrees.x = -90; s.shaded = false; s.modulate = color
	parent.add_child(s); s.global_position = pos + Vector3(0, 0.06, 0)
	s.scale = Vector3.ONE * 0.3
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * to_scale, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)

## Bright billboard card for a quick flash (fake bloom on low-end devices).
static func flash_card(parent: Node, pos: Vector3, color: Color, size: float = 1.0, dur: float = 0.15, tex: String = "res://assets/fx/glow.png") -> Sprite3D:
	var s := Sprite3D.new(); s.texture = G.tex(tex); s.pixel_size = size / 64.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED; s.shaded = false; s.modulate = color; s.no_depth_test = true; s.render_priority = 6
	parent.add_child(s); s.global_position = pos
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 1.5, dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)
	return s

static func star(parent: Node, pos: Vector3) -> void:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/fx/star.png"); s.pixel_size = 0.012
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED; s.shaded = false; s.no_depth_test = true; s.render_priority = 7
	parent.add_child(s); s.global_position = pos
	s.scale = Vector3.ONE * 0.4
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 1.6, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(s, "rotation:z", 0.6, 0.35)
	tw.tween_property(s, "modulate:a", 0.0, 0.35).set_delay(0.1)
	tw.chain().tween_callback(s.queue_free)

## Take Refuge: a dome of warm light rises around the pilgrim and fades.
static func dome(parent: Node, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.3; sm.height = 2.6; sm.is_hemisphere = true; sm.radial_segments = 24; sm.rings = 8
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.66, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = false
	mi.material_override = m
	parent.add_child(mi); mi.global_position = pos
	mi.scale = Vector3(0.2, 0.05, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.4)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(mi.queue_free)
	ring(parent, pos, Color(1, 0.9, 0.6), 2.6, 0.6)
	motes_up(parent, pos + Vector3(0, 0.3, 0), Color("fff0c0"), 18, 1.2)

## Afterimages along a lunge: translucent copies of the sprite frame that fade.
static func afterimages(parent: Node, actor: SpriteActor, from: Vector3, to: Vector3, n: int = 3) -> void:
	for i in n:
		var g := Sprite3D.new()
		g.texture = actor.sprite.texture; g.hframes = actor.sprite.hframes; g.vframes = actor.sprite.vframes; g.frame = actor.sprite.frame
		g.flip_h = actor.sprite.flip_h; g.pixel_size = actor.sprite.pixel_size; g.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; g.shaded = false; g.transparent = true
		g.modulate = Color(0.75, 0.9, 1.0, 0.55 - i * 0.12)
		parent.add_child(g)
		g.global_position = from.lerp(to, float(i) / n) + Vector3(0, actor.sprite.position.y, 0)
		var tw := g.create_tween(); tw.tween_property(g, "modulate:a", 0.0, 0.3 + i * 0.05); tw.tween_callback(g.queue_free)

## Red ground warning before a strong enemy attack (colourblind-safe: also has rings).
static func telegraph(parent: Node, pos: Vector3, radius: float, dur: float) -> Sprite3D:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/fx/telegraph.png"); s.pixel_size = radius * 2.0 / 256.0
	s.rotation_degrees.x = -90; s.shaded = false; s.modulate = Color(1, 1, 1, 0.0)
	parent.add_child(s); s.global_position = pos + Vector3(0, 0.05, 0)
	s.scale = Vector3.ONE * 0.4
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "modulate:a", 1.0, dur * 0.4)
	tw.tween_property(s, "scale", Vector3.ONE, dur).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(s.queue_free)
	return s

static func shaft(parent: Node, pos: Vector3, height: float = 9.0, width: float = 2.2, rot: float = 0.0) -> Sprite3D:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/fx/shaft.png"); s.pixel_size = height / 256.0
	s.scale = Vector3(width / (64.0 * s.pixel_size), 1, 1)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; s.shaded = false; s.transparent = true; s.modulate = Color(1, 1, 1, 0.55)
	s.rotation.z = rot
	parent.add_child(s); s.global_position = pos + Vector3(0, height * 0.5, 0)
	return s
