class_name MapKit
extends RefCounted
## Map-building primitives and world feedback (float text, sparkles, drops, ambience).

var w: World
const STANDEE_HEIGHT := 1.75       # world units
const STANDEE_PX := 96.0
var bobbers: Array = []          # nodes that float gently (tableau orbs)
var spinners: Array = []         # [node, radians per second]

func _init(world: World) -> void:
	w = world

var drops: Array = []

var lamps: Array = []

var sways: Array = []

var holy_lights: Array = []

var target_ring: Sprite3D

var last_target = null

var low_hp_pulse := 0.0

var burden_fx: CPUParticles3D

var weary_fx: CPUParticles3D


func _mat(path: String, scale: Vector2 = Vector2.ONE, triplanar: bool = false, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = G.tex(path)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if triplanar:
		m.uv1_triplanar = true; m.uv1_scale = Vector3(scale.x, scale.y, scale.x)
	else:
		m.uv1_scale = Vector3(scale.x, scale.y, 1)
	m.roughness = 1.0
	return m


func _plane(size: Vector2, mat: Material, pos: Vector3, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = size
	mi.mesh = pm; mi.material_override = mat; mi.position = pos; mi.rotation.y = rot_y
	w.add_child(mi)
	return mi


func _box(size: Vector3, mat: Material, pos: Vector3, solid: bool = true, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos; mi.rotation.y = rot_y
	w.add_child(mi)
	if solid:
		_solid_box(size, pos, rot_y)
	return mi


func _solid_box(size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; sb.add_child(cs); sb.position = pos; sb.rotation.y = rot_y; w.add_child(sb)


func _solid_cyl(r: float, pos: Vector3) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = r; sh.height = 3.0
	cs.shape = sh; sb.add_child(cs); sb.position = pos + Vector3(0, 1.5, 0); w.add_child(sb)


func _sphere(r: float, mat: Material, pos: Vector3, squash: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0 * squash; sm.radial_segments = 10; sm.rings = 6
	mi.mesh = sm; mi.material_override = mat; mi.position = pos
	w.add_child(mi)
	return mi


func _tree(pos: Vector3, s: float = 1.0, leaf_tint: Color = Color.WHITE, fruit: Color = Color(0, 0, 0, 0), solid: bool = true) -> Node3D:
	var root := Node3D.new(); root.position = pos; w.add_child(root)
	var trunk := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.22 * s; cm.bottom_radius = 0.32 * s; cm.height = 2.0 * s; cm.radial_segments = 8
	trunk.mesh = cm; trunk.material_override = _mat("res://assets/tiles/bark.png", Vector2(1, 2)); trunk.position.y = s
	root.add_child(trunk)
	var lm := _mat("res://assets/tiles/leaves.png", Vector2(2, 2), true, leaf_tint)
	for off in [Vector3(0, 2.6, 0), Vector3(-0.8, 2.1, 0.3), Vector3(0.8, 2.15, -0.2), Vector3(0.1, 2.0, 0.8)]:
		var sp := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.1 * s; sm.height = 1.9 * s; sm.radial_segments = 10; sm.rings = 6
		sp.mesh = sm; sp.material_override = lm; sp.position = off * s
		root.add_child(sp)
	if fruit.a > 0.0:
		var fm := StandardMaterial3D.new(); fm.albedo_color = fruit; fm.roughness = 0.5
		for i in 7:
			var a := i * TAU / 7.0
			var f := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.16 * s; fs.height = 0.32 * s
			f.mesh = fs; f.material_override = fm
			f.position = Vector3(cos(a) * 1.2, 2.0 + (i % 3) * 0.35, sin(a) * 1.2) * s
			root.add_child(f)
	if solid:
		_solid_cyl(0.45 * s, pos)
	sways.append([root, randf() * TAU])
	return root


func _walls() -> void:
	var h := 3.0
	_solid_box(Vector3(w.bounds.size.x + 2, h, 1), Vector3(w.bounds.get_center().x, h / 2, w.bounds.position.y - 0.5))
	_solid_box(Vector3(w.bounds.size.x + 2, h, 1), Vector3(w.bounds.get_center().x, h / 2, w.bounds.end.y + 0.5))
	_solid_box(Vector3(1, h, w.bounds.size.y + 2), Vector3(w.bounds.position.x - 0.5, h / 2, w.bounds.get_center().y))
	_solid_box(Vector3(1, h, w.bounds.size.y + 2), Vector3(w.bounds.end.x + 0.5, h / 2, w.bounds.get_center().y))


func _water(size: Vector2, pos: Vector3, tint: Color = Color(0.95, 1.0, 1.05)) -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform vec2 scale = vec2(8.0, 2.0);
uniform vec3 tint = vec3(0.95, 1.0, 1.05);
void fragment(){
	vec2 uv = UV * scale;
	vec3 a = texture(tex, uv + vec2(TIME * 0.05, TIME * 0.02)).rgb;
	vec3 b = texture(tex, uv * 1.3 - vec2(TIME * 0.03, 0.0)).rgb;
	vec2 cell = floor(uv * 7.0);
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float glint = step(0.93, fract(rnd + TIME * 0.35)) * step(0.6, fract(uv.x * 7.0)) * 0.35;
	ALBEDO = mix(a, b, 0.5) * tint + vec3(glint) * tint;
}"""
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("tex", G.tex("res://assets/tiles/water.png"))
	m.set_shader_parameter("scale", Vector2(size.x / 4.0, size.y / 4.0))
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_plane(size, m, pos)


func _label3d(text: String, pos: Vector3, color: Color = Color.WHITE, size: int = 34) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font = G.font_ui_bold; l.font_size = size; l.outline_size = 10
	l.modulate = color; l.outline_modulate = Color(0.06, 0.05, 0.1); l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.render_priority = 5
	l.position = pos; w.add_child(l)
	return l


func _sprite_npc(tex_path: String, hframes: int, vframes: int, rows: bool, pos: Vector3, nm: String, color: Color, pixel: float = 0.042, flip_inv := false) -> SpriteActor:
	var a := SpriteActor.new()
	w.add_child(a)
	a.position = pos
	var idle := [0, 1] if hframes >= 2 else [0]
	a.setup({"tex": G.tex(tex_path), "hframes": hframes, "vframes": vframes, "pixel": pixel, "rows": rows,
		"anims": {"idle": idle}, "fps": {"idle": 1.6}, "flip_inverted": flip_inv}, nm, color)
	return a


func _smoke(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10; p.lifetime = 4.0; p.direction = Vector3(0.3, 1, 0); p.spread = 12.0; p.initial_velocity_min = 0.4; p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.15, 0.05, 0); p.scale_amount_min = 1.5; p.scale_amount_max = 3.0
	var q := QuadMesh.new(); q.size = Vector2(0.8, 0.8)
	var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.albedo_color = Color(0.35, 0.33, 0.38, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m; p.mesh = q; p.position = pos; w.add_child(p)


# ------------------------------------------------------------------ drops and fx
func _drop(item: String, icon: String, pos: Vector3) -> void:
	var s := Sprite3D.new(); s.texture = G.tex("res://assets/icons/%s.png" % icon); s.pixel_size = 0.012
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED; s.shaded = false; s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	w.add_child(s)
	var land := pos + Vector3(randf_range(-0.8, 0.8), 0.4, randf_range(-0.8, 0.8))
	s.position = pos + Vector3(0, 0.8, 0)
	var tw := w.create_tween(); tw.tween_property(s, "position", land + Vector3(0, 0.6, 0), 0.18); tw.tween_property(s, "position", land, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drops.append({"node": s, "item": item, "icon": icon, "pos": land})


func _drop_tick() -> void:
	for d in drops.duplicate():
		var near := Vector2(w.player.position.x - d.pos.x, w.player.position.z - d.pos.z).length() < (2.6 if G.settings.auto_loot else 0.9)
		if near:
			d.node.queue_free(); drops.erase(d)
			G.bag_add(d.item, 1); G.say("You got %s." % d.item, G.INFO); _item_pop(d.icon)


func _item_pop(icon: String) -> void:
	w.hud.item_pop(icon, w.cam.unproject_position(w.player.position + Vector3(0, 1.5, 0)))


var _num_stagger := 0


func _float_text(pos: Vector3, text: String, color: Color, big: bool = false, amount: int = 0) -> void:
	if not G.settings.dmg_numbers and text != "Miss":
		return
	_num_stagger = (_num_stagger + 1) % 3
	pos += Vector3((_num_stagger - 1) * 0.25, _num_stagger * 0.12, 0)
	var l := Label3D.new(); l.text = text; l.font = G.font_ui_bold
	l.font_size = int((66 if big else 46) + clampf(amount, 0, 40) * 0.5)
	l.outline_size = 14; l.modulate = color; l.outline_modulate = Color(0.05, 0.03, 0.08); l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.render_priority = 10
	w.add_child(l); l.position = pos
	var side := randf_range(-0.6, 0.6)
	var tw := w.create_tween().set_parallel(true)
	if G.settings.reduce_motion:
		tw.tween_property(l, "position:y", pos.y + 0.6, 0.8)
	else:
		l.scale = Vector3.ONE * 1.6
		tw.tween_property(l, "scale", Vector3.ONE, 0.15)
		tw.tween_property(l, "position:x", pos.x + side, 0.8)
		tw.tween_property(l, "position:y", pos.y + 0.9, 0.3).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(l, "position:y", pos.y + 0.2, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_method(_label_alpha.bind(l), 1.0, 0.0, 0.3).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


## Fade a Label3D's fill and outline together (fading only the fill leaves a dark outline glyph).
func _label_alpha(a: float, l: Label3D) -> void:
	if is_instance_valid(l):
		l.modulate.a = a; l.outline_modulate.a = a


func _sparkle(pos: Vector3, color: Color = Color("fff2b0")) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.emitting = true; p.amount = 24; p.lifetime = 1.0; p.explosiveness = 0.9
	p.direction = Vector3.UP; p.spread = 70.0; p.initial_velocity_min = 1.5; p.initial_velocity_max = 3.0; p.gravity = Vector3(0, -2, 0)
	var q := QuadMesh.new(); q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m; p.mesh = q; p.position = pos; w.add_child(p)
	w.get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _motes(pos: Vector3) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.emitting = true; p.amount = 20; p.lifetime = 1.8; p.explosiveness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP; p.spread = 15.0; p.initial_velocity_min = 0.8; p.initial_velocity_max = 1.4; p.gravity = Vector3.ZERO
	var q := QuadMesh.new(); q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m; p.mesh = q; p.position = pos + Vector3(0, 0.5, 0); w.add_child(p)
	w.get_tree().create_timer(2.5).timeout.connect(p.queue_free)


func _on_level_up(kind: String) -> void:
	var ring := Sprite3D.new(); ring.texture = G.tex("res://assets/fx/ring.png"); ring.rotation_degrees.x = -90; ring.pixel_size = 0.01; ring.shaded = false
	w.add_child(ring); ring.position = w.player.position + Vector3(0, 0.08, 0)
	var tw2 := w.create_tween(); tw2.tween_property(ring, "scale", Vector3(3, 3, 3), 1.0); tw2.parallel().tween_property(ring, "modulate:a", 0.0, 1.0); tw2.tween_callback(ring.queue_free)
	var col := Sprite3D.new(); col.texture = G.tex("res://assets/fx/glow.png"); col.pixel_size = 0.05; col.scale = Vector3(1, 4, 1)
	col.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; col.shaded = false; col.modulate = Color(1, 0.95, 0.7, 0.8)
	w.add_child(col); col.position = w.player.position + Vector3(0, 1.5, 0)
	var tw3 := w.create_tween(); tw3.tween_property(col, "modulate:a", 0.0, 1.2); tw3.tween_callback(col.queue_free)
	_sparkle(w.player.position + Vector3(0, 1, 0), Color("ffe9a0"))
	Fx.spiral(w, w.player.position + Vector3(0, 0.2, 0), Color("ffe9a0") if kind.begins_with("Base") else Color("b8e0ff"))
	w.hud.level_banner(kind)
	w.lessons._level_lesson(kind)


# ------------------------------------------------------------------ ambience and feedback ticks
func _ambient_tick(delta: float) -> void:
	for sw in sways:
		if is_instance_valid(sw[0]):
			sw[0].rotation.z = sin(w.t * 1.1 + sw[1]) * 0.025
			sw[0].rotation.x = cos(w.t * 0.8 + sw[1]) * 0.015
	for l in lamps:
		l.light_energy = 1.5 + sin(w.t * 9.0 + l.position.x) * 0.12 + randf() * 0.1
	for h in holy_lights:
		if h is OmniLight3D:
			h.light_energy = 2.0 + sin(w.t * 1.6) * 0.5
		elif h is Sprite3D:
			h.modulate.a = 0.45 + sin(w.t * 1.6) * 0.15
	for sp in spinners:
		sp[0].rotation.y += delta * float(sp[1])
	for b in bobbers:
		b.position.y += sin(w.t * 2.0 + b.position.x) * 0.003
	# target ring + outline on the current target
	var tgt = w.combat.target if (w.combat.target != null and w.combat.target.alive) else null
	if tgt != last_target:
		if last_target != null and is_instance_valid(last_target.actor):
			last_target.actor.set_outline(false)
		if tgt != null:
			tgt.actor.set_outline(true)
		last_target = tgt
	if tgt != null:
		if target_ring == null:
			target_ring = Sprite3D.new(); target_ring.texture = G.tex("res://assets/fx/ring.png"); target_ring.pixel_size = 0.011
			target_ring.rotation_degrees.x = -90; target_ring.shaded = false; target_ring.modulate = Color(1, 0.85, 0.3, 0.9); w.add_child(target_ring)
		target_ring.visible = true
		target_ring.position = tgt.actor.position + Vector3(0, 0.05, 0)
		target_ring.rotation.y += delta * 2.0
	elif target_ring:
		target_ring.visible = false
	# mob HP trail
	for m in w.combat.mobs:
		if m.bg.visible:
			var v: float = m.hp / m.max
			m.trail_v = lerpf(m.trail_v, v, delta * 3.0) if m.trail_v > v else v
			m.trail.scale.x = maxf(0.001, m.trail_v); m.trail.position.x = -0.43 * (1.0 - m.trail_v)
	# status visuals on the body
	if burden_fx != null and not G.burden:
		burden_fx.queue_free(); burden_fx = null
	if G.burden and burden_fx == null:
		burden_fx = Fx.particles(w.player, w.player.global_position + Vector3(0.25, 1.1, 0), {"amount": 6, "life": 1.4, "one_shot": false, "explode": 0.0, "sphere": 0.25,
			"vmin": 0.05, "vmax": 0.2, "gravity": Vector3(0, -0.4, 0), "color": Color(0.2, 0.16, 0.12, 0.45), "size": 0.3, "tex": "res://assets/fx/puff.png", "add": false, "local": false})
	if burden_fx:
		burden_fx.global_position = w.player.global_position + Vector3(0.25, 1.1, 0)
	if G.weary and weary_fx == null:
		weary_fx = Fx.particles(w.player, w.player.global_position + Vector3(0, 2.0, 0), {"amount": 3, "life": 0.9, "one_shot": false, "explode": 0.0,
			"dir": Vector3(0.3, 1, 0), "spread": 30.0, "vmin": 0.6, "vmax": 0.9, "gravity": Vector3(0, -3, 0), "color": Color(0.7, 0.85, 1.0, 0.9), "size": 0.18, "tex": "res://assets/fx/drop.png", "add": false, "local": false})
	elif not G.weary and weary_fx != null:
		weary_fx.queue_free(); weary_fx = null
	if weary_fx:
		weary_fx.global_position = w.player.global_position + Vector3(0, 2.0, 0)
	# low-health warning
	var frac := G.hp / G.hp_max
	var target_d := 0.0
	if frac < 0.25 and not w.combat.dead:
		low_hp_pulse += delta * (6.0 if frac < 0.1 else 3.5)
		target_d = 0.45 + 0.35 * sin(low_hp_pulse)
	w.post.set_shader_parameter("danger", target_d)


func _pop_mark(a: SpriteActor, mark: String, col: Color) -> void:
	var l := _label3d(mark, a.position + Vector3(0, 1.9, 0), col, 80)
	l.scale = Vector3.ONE * 0.3
	var tw := w.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.tween_interval(0.6)
	tw.tween_method(_label_alpha.bind(l), 1.0, 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _edge_fade(col: Color) -> void:
	## Soft darkening band at every map border so no hard edge or void is visible.
	var gt := GradientTexture2D.new()
	var gr := Gradient.new(); gr.set_color(0, Color(col.r, col.g, col.b, 0.0)); gr.set_color(1, Color(col.r, col.g, col.b, 0.92))
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1); gt.width = 4; gt.height = 64
	var m := StandardMaterial3D.new(); m.albedo_texture = gt; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var b := w.bounds; var band := 7.0
	var specs := [
		[Vector2(b.size.x + 2 * band, band), Vector3(b.get_center().x, 0.08, b.position.y - band * 0.5 + 1.5), PI],
		[Vector2(b.size.x + 2 * band, band), Vector3(b.get_center().x, 0.08, b.end.y + band * 0.5 - 1.5), 0.0],
		[Vector2(b.size.y + 2 * band, band), Vector3(b.position.x - band * 0.5 + 1.5, 0.08, b.get_center().y), -PI * 0.5],
		[Vector2(b.size.y + 2 * band, band), Vector3(b.end.x + band * 0.5 - 1.5, 0.08, b.get_center().y), PI * 0.5]]
	for sp in specs:
		var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = sp[0]; mi.mesh = pm; mi.material_override = m
		mi.position = sp[1]; mi.rotation.y = sp[2]; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.add_child(mi)


func _weather_petals() -> void:
	var p := Fx.particles(w.cam_rig, w.cam_rig.global_position + Vector3(0, 7, 0), {"amount": 26, "life": 6.0, "one_shot": false, "explode": 0.0, "sphere": 9.0,
		"dir": Vector3(0.4, -1, 0.2), "spread": 25.0, "vmin": 0.6, "vmax": 1.1, "gravity": Vector3(0.3, -0.25, 0.1), "color": Color(1, 1, 1, 0.95),
		"size": 0.16, "tex": "res://assets/fx/petal.png", "add": false, "local": false})
	p.set_meta("follow", true)
	_followers.append([p, Vector3(0, 7, 0)])


func _weather_drizzle() -> void:
	if not G.settings.fx_high:
		return
	var p := Fx.particles(w.cam_rig, w.cam_rig.global_position + Vector3(0, 9, 0), {"amount": 60, "life": 1.0, "one_shot": false, "explode": 0.0, "sphere": 10.0,
		"dir": Vector3(0.15, -1, 0), "spread": 4.0, "vmin": 11.0, "vmax": 13.0, "gravity": Vector3.ZERO, "color": Color(0.8, 0.85, 0.95, 0.45),
		"size": 0.5, "stretch": 0.15, "tex": "res://assets/fx/rain.png", "add": false, "local": false})
	_followers.append([p, Vector3(0, 9, 0)])


var _followers: Array = []


# ------------------------------------------------------------------ other pilgrims (passing ghosts on the Way, real players in Houses)
func _pilgrim_actor(look: Array, nm: String, col: Color, ghost: bool) -> SpriteActor:
	var a := SpriteActor.new(); w.add_child(a)
	a.setup({"tex": G.build_sheet(int(look[0]), int(look[1]), int(look[2])), "hframes": 10, "vframes": 5, "pixel": 0.042, "rows": true, "ghost": ghost,
		"anims": {"idle": [0], "walk": [1, 2, 3, 4], "attack": [5, 6], "sit": [7], "rest": [8], "cast": [9]}, "fps": {"walk": 9.0, "attack": 6.0}}, nm, col)
	return a


func _fade_actor(a: SpriteActor, from: float, to: float) -> void:
	var tw := w.create_tween()
	tw.tween_method(_actor_alpha.bind(a), from, to, 0.8)
	if to <= 0.0:
		tw.tween_callback(_hide_node.bind(a))


func _actor_alpha(v: float, a: SpriteActor) -> void:
	if not is_instance_valid(a):
		return
	var c: Color = G.sprite_tint; c.a = v; a.set_tint(c)
	if a.name_lbl:
		a.name_lbl.modulate.a = v * 0.75; a.name_lbl.outline_modulate.a = v * 0.75


func _hide_node(n: Node3D) -> void:
	if is_instance_valid(n):
		n.visible = false


func _bubble(a: SpriteActor, text: String) -> void:
	var l := _label3d(text, a.position + Vector3(0, 2.45, 0), Color("1d2b52"), 24)
	l.outline_modulate = Color(1, 1, 1, 0.95); l.outline_size = 16; l.width = 360; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.reparent(a); l.position = Vector3(0, 2.45, 0)
	var tw := w.create_tween(); tw.tween_interval(3.2); tw.tween_method(_label_alpha.bind(l), 1.0, 0.0, 0.4); tw.tween_callback(l.queue_free)

## Glowing circle on the ground that marks where an objective wants the player.
func zone_marker(at: Vector3) -> Node3D:
	var n := Node3D.new(); w.add_child(n); n.position = at
	var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/glow.png"); g.pixel_size = 0.07; g.rotation_degrees.x = -90; g.position.y = 0.05; g.shaded = false
	n.add_child(g)
	Fx.particles(n, at + Vector3(0, 0.2, 0), {"amount": 16, "life": 2.0, "one_shot": false, "explode": 0.0, "sphere": 1.0, "vmin": 0.6, "vmax": 1.0, "spread": 10.0,
		"gravity": Vector3.ZERO, "color": Color("fff3c0"), "size": 0.15, "local": true})
	return n

## The shining portal that leads on to the next map.
func warp(at: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = at; w.add_child(n)
	for spec in [[0.014, 0.06, 1.5, Color.WHITE], [0.011, 0.08, -2.4, Color(1, 0.95, 0.7, 0.8)]]:
		var ring := Sprite3D.new(); ring.texture = G.tex("res://assets/fx/warp.png"); ring.pixel_size = spec[0]; ring.rotation_degrees.x = -90
		ring.position.y = spec[1]; ring.shaded = false; ring.transparent = true; ring.modulate = spec[3]; n.add_child(ring)
		spinners.append([ring, spec[2]])
	var beam := Sprite3D.new(); beam.texture = G.tex("res://assets/fx/glow.png"); beam.pixel_size = 0.09; beam.scale = Vector3(1, 3, 1)
	beam.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; beam.shaded = false; beam.position.y = 3.0; beam.modulate = Color(1, 0.95, 0.75, 0.75); n.add_child(beam)
	var wl := OmniLight3D.new(); wl.light_color = Color("fff0c0"); wl.light_energy = 3.0; wl.omni_range = 8.0; wl.position.y = 2.0; n.add_child(wl)
	holy_lights.append(wl)
	Fx.particles(n, at + Vector3(0, 0.2, 0), {"amount": 24, "life": 2.2, "one_shot": false, "explode": 0.0, "sphere": 1.2, "vmin": 0.8, "vmax": 1.6, "spread": 8.0,
		"gravity": Vector3.ZERO, "color": Color("fff0c0"), "size": 0.14, "local": true})
	return n

## A standing character drawn as one picture (assets/sprites/npc/<id>.png, 96x96, feet at the bottom).
func standee(id: String, display_name: String, name_color: Color) -> SpriteActor:
	var a := SpriteActor.new(); w.add_child(a)
	a.setup({"tex": G.tex("res://assets/sprites/npc/%s.png" % id), "hframes": 1, "vframes": 1, "pixel": STANDEE_HEIGHT / STANDEE_PX, "rows": false,
		"anims": {"idle": [0], "walk": [0]}, "fps": {"idle": 1.0}}, display_name, name_color)
	return a
