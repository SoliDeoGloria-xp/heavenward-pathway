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
	anim_t += delta
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
