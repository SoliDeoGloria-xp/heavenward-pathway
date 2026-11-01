class_name SpriteActor
extends Node3D
## Classic-RO style 2D sprite standing in the 3D world: Y-billboard, crisp pixels, blob shadow,
## outlined name plate, facing chosen relative to the camera (5 drawn rows + mirrored = 8 directions).

var sprite: Sprite3D
var shadow: MeshInstance3D
var name_lbl: Label3D
var cfg: Dictionary
var anim := "idle"
var anim_t := 0.0
var facing := Vector3(0, 0, 1)
var one_shot := ""
var one_shot_t := 0.0
var pick_height := 0.9
var pick_radius := 0.8
var mat: ShaderMaterial
var speed_mul := 1.0
var _flash := 0.0
var _flash_col := Color.WHITE
static var _sh: Shader

static func _shader() -> Shader:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.83, 0.25, 1.0);
uniform float outline = 0.0;
uniform float half_h = 1.0;
uniform float shade_top = 1.07;
uniform float shade_bottom = 0.84;
varying float vy;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vy = clamp(VERTEX.y / (2.0 * half_h) + 0.5, 0.0, 1.0);
}
void fragment() {
	vec4 c = texture(tex, UV);
	float a = c.a;
	if (outline > 0.0 && a < 0.5) {
		vec2 px = 1.0 / vec2(textureSize(tex, 0));
		float n = texture(tex, UV + vec2(px.x, 0.0)).a + texture(tex, UV - vec2(px.x, 0.0)).a + texture(tex, UV + vec2(0.0, px.y)).a + texture(tex, UV - vec2(0.0, px.y)).a;
		if (n > 0.5) { c = outline_color; a = outline; }
	}
	float g = mix(shade_bottom, shade_top, vy);
	vec3 col = c.rgb * tint.rgb * g;
	col = mix(col, flash_color.rgb, flash);
	ALBEDO = col;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	return _sh

func flash(col: Color = Color.WHITE, strength: float = 0.85) -> void:
	if G.settings.get("reduce_flashing", false):
		strength *= 0.35
	_flash = strength; _flash_col = col
	mat.set_shader_parameter("flash_color", col)

func squash(amount: float = 0.08) -> void:
	if G.settings.reduce_motion:
		return
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector3(1.0 + amount, 1.0 - amount, 1.0), 0.05)
	tw.tween_property(sprite, "scale", Vector3(1.0 - amount * 0.5, 1.0 + amount * 0.5, 1.0), 0.07)
	tw.tween_property(sprite, "scale", Vector3.ONE, 0.08)

func set_outline(on: bool) -> void:
	mat.set_shader_parameter("outline", 1.0 if on else 0.0)

func set_tint(c: Color) -> void:
	mat.set_shader_parameter("tint", c)

## cfg keys: tex, hframes, vframes, pixel, rows(bool: 5 direction rows), anims {name: [frames], fps}
func setup(c: Dictionary, display_name: String = "", name_color: Color = Color.WHITE) -> void:
	cfg = c
	sprite = Sprite3D.new()
	sprite.texture = c.tex
	sprite.hframes = c.hframes
	sprite.vframes = c.get("vframes", 1)
	sprite.pixel_size = c.get("pixel", 0.04)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.centered = true
	var fh: float = float(c.tex.get_height()) / float(sprite.vframes)
	sprite.position.y = fh * sprite.pixel_size * 0.5
	# lit-sprite shader: map key-light tint, top-to-bottom shading, hit flash, target outline
	mat = ShaderMaterial.new()
	mat.shader = _shader()
	mat.set_shader_parameter("tex", c.tex)
	mat.set_shader_parameter("half_h", fh * sprite.pixel_size * 0.5)
	mat.set_shader_parameter("tint", G.sprite_tint)
	sprite.material_override = mat
	add_child(sprite)
	pick_height = fh * sprite.pixel_size * 0.5
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(1.1, 0.75) * c.get("shadow", 1.0); q.orientation = PlaneMesh.FACE_Y
	shadow.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = G.tex("res://assets/fx/shadow.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = m
	shadow.position.y = 0.02
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	if display_name != "":
		name_lbl = Label3D.new()
		name_lbl.text = display_name
		name_lbl.font = G.font_ui_bold
		name_lbl.font_size = 34
		name_lbl.outline_size = 10
		name_lbl.modulate = name_color
		name_lbl.outline_modulate = Color(0.06, 0.05, 0.1)
		name_lbl.pixel_size = 0.01
		name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_lbl.no_depth_test = true
		name_lbl.position.y = -0.22
		name_lbl.render_priority = 5
		add_child(name_lbl)

func set_name_text(t: String) -> void:
	if name_lbl:
		name_lbl.text = t

func play(a: String) -> void:
	if a != anim:
		anim = a; anim_t = 0.0

func play_once(a: String, dur: float) -> void:
	one_shot = a; one_shot_t = dur; anim_t = 0.0

func _process(delta: float) -> void:
	anim_t += delta * speed_mul
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 7.0)
		mat.set_shader_parameter("flash", _flash)
	var a := anim
	if one_shot != "":
		one_shot_t -= delta
		if one_shot_t <= 0.0:
			one_shot = ""
		else:
			a = one_shot
	var anims: Dictionary = cfg.anims
	if not anims.has(a):
		a = "idle"
	var fr: Array = anims[a]
	var fps: float = cfg.get("fps", {}).get(a, 7.0)
	var col: int = fr[int(anim_t * fps) % fr.size()]
	var row := 0
	var flip := false
	if cfg.get("rows", false):
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cf := -cam.global_transform.basis.z; cf.y = 0
			var cr := cam.global_transform.basis.x; cr.y = 0
			var f := facing; f.y = 0
			if f.length() > 0.01 and cf.length() > 0.01:
				f = f.normalized()
				# angle of facing relative to "towards camera" (south on screen)
				var toward := -cf.normalized()
				var ang := atan2(f.dot(cr.normalized()), f.dot(toward))  # 0 = facing camera, +right
				var oct := int(round(ang / (PI / 4.0)))  # -4..4
				match oct:
					0: row = 0
					-1: row = 1
					-2: row = 2
					-3: row = 3
					4, -4: row = 4
					3: row = 3; flip = true
					2: row = 2; flip = true
					1: row = 1; flip = true
	else:
		var cam2 := get_viewport().get_camera_3d()
		if cam2:
			var cr2 := cam2.global_transform.basis.x
			flip = facing.dot(cr2) > 0.05
	sprite.frame = row * sprite.hframes + col
	sprite.flip_h = flip if not cfg.get("flip_inverted", false) else not flip
