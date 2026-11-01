extends CanvasLayer
## RO M / Origin phone HUD dressed in classic RO windows.
## Left thumb: floating joystick. Right thumb: Attack + 4-skill arc (2 pages), Auto, quick item, Act.
## Top-left: portrait plate. Top-right: minimap + More. Left edge: quest tracker. Bottom-left: chat ticker.

var world: Node
var root: Control
var joy: FloatingJoystick
var plate_hp: TextureProgressBar
var plate_ze: TextureProgressBar
var hp_txt: Label
var ze_txt: Label
var lv_txt: Label
var status_row: HBoxContainer
var quest_lbl: Label
var quest_box: PanelContainer
var chat_lbl: RichTextLabel
var minimap: Control
var coord_lbl: Label
var exp_bar: TextureProgressBar
var exp_txt: Label
var atk_btn: TouchBtn
var skill_btns: Array = []
var page := 0
var page_btn: TouchBtn
var auto_btn: TouchBtn
var item_btn: TouchBtn
var sit_btn: TouchBtn
var act_btn: TouchBtn
var snap_btn: TouchBtn
var more_btn: TouchBtn
var overlay: Control
var banner_box: VBoxContainer
var toast_lbl: Label
var flash_rect: ColorRect
var hud_nodes: Array = []
var snapshot_ui: Control
var combat_nodes: Array = []
var quick_item := "Bread of Provision"

const SKILLS := [
	[{"id": "steps", "name": "First Steps", "icon": "steps"}, {"id": "refuge", "name": "Take Refuge", "icon": "refuge"}, {"id": "", "name": "Lv 10", "icon": "lock"}, {"id": "", "name": "Lv 15", "icon": "lock"}],
	[{"id": "", "name": "Calling", "icon": "lock"}, {"id": "", "name": "Calling", "icon": "lock"}, {"id": "", "name": "Calling", "icon": "lock"}, {"id": "", "name": "Calling", "icon": "lock"}]]

func _ready() -> void:
	layer = 10
	root = Control.new(); UIKit.full_rect(root); root.theme = G.theme; root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	G.log_added.connect(_on_log)
	G.stats_changed.connect(refresh)
	_on_log("", Color.WHITE)

# ------------------------------------------------------------------ build
func _build() -> void:
	var L: bool = not G.settings.left_handed
	# tap layer (world taps, pinch zoom, two-finger rotate)
	var tl := TapLayer.new(); UIKit.full_rect(tl); tl.hud = self; root.add_child(tl)
	# joystick zone: lower-left (or lower-right when left-handed)
	joy = FloatingJoystick.new()
	joy.anchor_left = 0.0 if L else 0.55; joy.anchor_right = 0.45 if L else 1.0; joy.anchor_top = 0.3; joy.anchor_bottom = 1.0
	joy.offset_bottom = -54
	joy.tapped.connect(func(p): world.tap(p))
	root.add_child(joy); hud_nodes.append(joy)
	_build_plate(L)
	_build_quest(L)
	_build_minimap(L)
	_build_chat(L)
	_build_combat(L)
	_build_exp()
	banner_box = VBoxContainer.new(); banner_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner_box.position = Vector2(-400, 150); banner_box.size = Vector2(800, 120); banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0.0; root.add_child(banner_box)
	toast_lbl = UIKit.outlined("", 26, Color("ffe27a"))
	toast_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.position = Vector2(-450, 92); toast_lbl.size = Vector2(900, 40); toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.modulate.a = 0.0; root.add_child(toast_lbl)
	flash_rect = ColorRect.new(); UIKit.full_rect(flash_rect); flash_rect.color = Color(0.8, 0, 0, 0); flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
	overlay = Control.new(); UIKit.full_rect(overlay); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

func _corner(c: Control, left: bool, top: bool, x: float, y: float) -> void:
	c.anchor_left = 0.0 if left else 1.0; c.anchor_right = c.anchor_left
	c.anchor_top = 0.0 if top else 1.0; c.anchor_bottom = c.anchor_top
	var sz := c.custom_minimum_size if c.size == Vector2.ZERO else c.size
	c.offset_left = x if left else -x - sz.x
	c.offset_top = y if top else -y - sz.y
	c.offset_right = c.offset_left + sz.x
	c.offset_bottom = c.offset_top + sz.y

func _build_plate(L: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/plate.png", 14, 10))
	p.custom_minimum_size = Vector2(390, 0)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); p.add_child(h)
	var face := PanelContainer.new(); face.custom_minimum_size = Vector2(78, 78)
	var fs := StyleBoxFlat.new(); fs.bg_color = Color("e8eefa"); fs.set_corner_radius_all(39); fs.set_border_width_all(3); fs.border_color = Color("5c6e98")
	face.add_theme_stylebox_override("panel", fs)
	var at := AtlasTexture.new(); at.atlas = G.player_sheet if G.player_sheet else G.build_player_sheet(); at.region = Rect2(4, 2, 24, 26)
	var ft := TextureRect.new(); ft.texture = at; ft.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.add_child(ft); h.add_child(face)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var nm := UIKit.label(G.pname, 23, UIKit.BLUE_INK, true); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	lv_txt = UIKit.label("", 19, UIKit.SUB, true); top.add_child(lv_txt)
	v.add_child(top)
	plate_hp = UIKit.gauge("hp", 260, 20)
	hp_txt = UIKit.outlined("", 15); hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; UIKit.full_rect(hp_txt); plate_hp.add_child(hp_txt)
	v.add_child(plate_hp)
	plate_ze = UIKit.gauge("zeal", 260, 16)
	ze_txt = UIKit.outlined("", 13); ze_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; UIKit.full_rect(ze_txt); plate_ze.add_child(ze_txt)
	v.add_child(plate_ze)
	status_row = HBoxContainer.new(); status_row.add_theme_constant_override("separation", 6); v.add_child(status_row)
	h.add_child(v)
	p.gui_input.connect(func(e): if _is_tap(e): open_sheet("status"))
	root.add_child(p)
	_corner(p, L, true, 16, 14)
	hud_nodes.append(p)

func _build_quest(L: bool) -> void:
	quest_box = PanelContainer.new()
	quest_box.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/chip.png", 10, 12))
	quest_box.custom_minimum_size = Vector2(390, 0)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	var t := UIKit.outlined("▸ The Way  ·  tap to auto-path", 16, Color("ffd36a"))
	v.add_child(t)
	quest_lbl = UIKit.outlined("", 21, Color.WHITE); quest_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_lbl.custom_minimum_size = Vector2(360, 0)
	v.add_child(quest_lbl)
	quest_box.add_child(v)
	quest_box.gui_input.connect(func(e): if _is_tap(e): world.auto_path_quest())
	root.add_child(quest_box)
	_corner(quest_box, L, true, 16, 150)
	hud_nodes.append(quest_box)

func _build_minimap(L: bool) -> void:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(200, 240)
	minimap = Minimap.new(); minimap.hud = self; minimap.custom_minimum_size = Vector2(200, 200)
	minimap.gui_input.connect(func(e): if _is_tap(e): open_sheet("way"))
	box.add_child(minimap)
	coord_lbl = UIKit.outlined("", 16, Color.WHITE); coord_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(coord_lbl)
	root.add_child(box)
	_corner(box, not L, true, 14, 12)
	hud_nodes.append(box)
	more_btn = TouchBtn.new(84, "res://assets/ui/btn_small.png", "menu", "More")
	more_btn.caption_size = 15
	more_btn.pressed.connect(open_more)
	root.add_child(more_btn); _corner(more_btn, not L, true, 226, 14); hud_nodes.append(more_btn)
	snap_btn = TouchBtn.new(84, "res://assets/ui/btn_small.png", "camera", "Snap")
	snap_btn.caption_size = 15
	snap_btn.pressed.connect(enter_snapshot)
	root.add_child(snap_btn); _corner(snap_btn, not L, true, 226, 106); hud_nodes.append(snap_btn)

func _build_chat(L: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/chip.png", 10, 10))
	p.custom_minimum_size = Vector2(470, 64)
	chat_lbl = RichTextLabel.new(); chat_lbl.bbcode_enabled = true; chat_lbl.fit_content = true; chat_lbl.scroll_active = false
	chat_lbl.custom_minimum_size = Vector2(450, 50); chat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_lbl.add_theme_font_size_override("normal_font_size", 17)
	chat_lbl.add_theme_font_override("normal_font", G.font_ui_bold)
	chat_lbl.add_theme_constant_override("outline_size", 4)
	chat_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	p.add_child(chat_lbl)
	p.gui_input.connect(func(e): if _is_tap(e): open_chat())
	root.add_child(p)
	_corner(p, L, false, 16, 22)
	hud_nodes.append(p)

func _build_combat(L: bool) -> void:
	var side := not L  # cluster sits on the opposite side of the joystick
	var cx := 20.0; var cy := 26.0
	atk_btn = TouchBtn.new(176, "res://assets/ui/btn_attack.png", "staff", "Attack")
	atk_btn.caption_size = 22
	atk_btn.pressed.connect(func(): world.attack_pressed())
	root.add_child(atk_btn); _corner(atk_btn, side, false, cx, cy); hud_nodes.append(atk_btn); combat_nodes.append(atk_btn)
	# arc of 4 skills around the attack button
	var arc := [Vector2(204, 10), Vector2(186, 128), Vector2(110, 214), Vector2(12, 226)]
	for i in 4:
		var b := TouchBtn.new(112, "res://assets/ui/btn_skill.png", "", "")
		b.caption_size = 15
		var idx := i
		b.pressed.connect(func(): _skill_pressed(idx))
		root.add_child(b); _corner(b, side, false, cx + arc[i].x, cy + arc[i].y)
		skill_btns.append(b); hud_nodes.append(b); combat_nodes.append(b)
	page_btn = TouchBtn.new(72, "res://assets/ui/btn_small.png", "page", "1/2")
	page_btn.caption_size = 14
	page_btn.pressed.connect(func(): page = 1 - page; _apply_page())
	root.add_child(page_btn); _corner(page_btn, side, false, cx + 236, cy + 270); hud_nodes.append(page_btn); combat_nodes.append(page_btn)
	auto_btn = TouchBtn.new(88, "res://assets/ui/btn_small.png", "auto", "Auto")
	auto_btn.tex_on = G.tex("res://assets/ui/btn_auto_on.png"); auto_btn.caption_size = 15
	auto_btn.pressed.connect(func(): auto_btn.on = not auto_btn.on; auto_btn.queue_redraw(); world.set_auto(auto_btn.on))
	root.add_child(auto_btn); _corner(auto_btn, side, false, cx + 330, cy + 4); hud_nodes.append(auto_btn); combat_nodes.append(auto_btn)
	item_btn = TouchBtn.new(88, "res://assets/ui/btn_small.png", "bread", "")
	item_btn.pressed.connect(func(): world.use_item(quick_item))
	item_btn.long_pressed.connect(func():
		quick_item = "Garden Fig" if quick_item == "Bread of Provision" else "Bread of Provision"
		item_btn.set_icon("fig" if quick_item == "Garden Fig" else "bread"); refresh())
	root.add_child(item_btn); _corner(item_btn, side, false, cx + 300, cy + 112); hud_nodes.append(item_btn)
	sit_btn = TouchBtn.new(72, "res://assets/ui/btn_small.png", "sit", "Sit")
	sit_btn.caption_size = 14
	sit_btn.pressed.connect(func(): world.toggle_sit())
	root.add_child(sit_btn); _corner(sit_btn, side, false, cx + 420, cy + 10); hud_nodes.append(sit_btn)
	act_btn = TouchBtn.new(124, "res://assets/ui/btn_attack.png", "talk", "Act")
	act_btn.caption_size = 20
	act_btn.pressed.connect(func(): world.act_pressed())
	root.add_child(act_btn); _corner(act_btn, side, false, cx + 352, cy + 262); hud_nodes.append(act_btn)
	_apply_page()

func _build_exp() -> void:
	exp_bar = UIKit.gauge("exp", 100, 10)
	exp_bar.anchor_left = 0; exp_bar.anchor_right = 1; exp_bar.anchor_top = 1; exp_bar.anchor_bottom = 1
	exp_bar.offset_top = -10; exp_bar.offset_bottom = 0
	root.add_child(exp_bar); hud_nodes.append(exp_bar)
	exp_txt = UIKit.outlined("", 14, Color("fff3c0"))
	exp_txt.anchor_left = 1; exp_txt.anchor_right = 1; exp_txt.anchor_top = 1; exp_txt.anchor_bottom = 1
	exp_txt.offset_left = -330; exp_txt.offset_top = -30; exp_txt.offset_right = -12; exp_txt.offset_bottom = -10
	exp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(exp_txt); hud_nodes.append(exp_txt)

func _apply_page() -> void:
	for i in 4:
		var s: Dictionary = SKILLS[page][i]
		var b: TouchBtn = skill_btns[i]
		b.set_icon(s.icon); b.caption = s.name; b.disabled = s.id == ""
		b.queue_redraw()
	page_btn.caption = "%d/2" % (page + 1); page_btn.queue_redraw()

func _skill_pressed(i: int) -> void:
	var s: Dictionary = SKILLS[page][i]
	if s.id == "":
		G.say("This skill slot opens with your Calling (job) or a higher Job Level.", G.WARN)
		return
	world.skill(s.id)

func _is_tap(e: InputEvent) -> bool:
	return e is InputEventScreenTouch and not e.pressed

func joy_vec() -> Vector2:
	return joy.vec if joy else Vector2.ZERO

# ------------------------------------------------------------------ updates
func refresh() -> void:
	if not is_instance_valid(plate_hp):
		return
	plate_hp.value = G.hp / G.hp_max * 1000.0
	plate_hp.texture_progress = G.tex("res://assets/ui/gauge_hp_low.png") if G.hp / G.hp_max < 0.25 else G.tex("res://assets/ui/gauge_hp.png")
	plate_ze.value = G.zeal / G.zeal_max * 1000.0
	hp_txt.text = "%d / %d" % [G.hp, G.hp_max]
	ze_txt.text = "%d / %d" % [G.zeal, G.zeal_max]
	lv_txt.text = "Base %d · Job %d" % [G.lvl, G.job]
	exp_bar.value = G.base_pct() * 1000.0
	exp_txt.text = "Base %.1f%%  ·  Job %.1f%%  ·  Manna %s" % [G.base_pct() * 100.0, G.job_pct() * 100.0, str(snappedf(G.manna, 0.1))]
	for c in status_row.get_children():
		c.queue_free()
	if G.burden or (world and world.map_id == "city"):
		status_row.add_child(_chip("Burden", Color("8a6438")))
	if G.weary:
		status_row.add_child(_chip("Weariness", Color("5c6e98")))
	if world and world.sitting:
		status_row.add_child(_chip("Resting", Color("2f7a3a")))
	if item_btn:
		item_btn.badge = str(int(G.bag.get(quick_item, 0)))
		item_btn.queue_redraw()
	if snap_btn:
		snap_btn.visible = world != null and world.snapshot_unlocked and snapshot_ui == null
	var city: bool = world != null and world.map_id == "city"
	for n in combat_nodes:
		n.visible = city and snapshot_ui == null

func _chip(t: String, c: Color) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(6); s.content_margin_left = 8; s.content_margin_right = 8; s.content_margin_top = 1; s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.add_child(UIKit.label(t, 14, Color.WHITE, true))
	return p

func _process(_d: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	# cooldowns
	for i in 4:
		var s: Dictionary = SKILLS[page][i]
		var b: TouchBtn = skill_btns[i]
		if s.id != "":
			var f: float = world.cooldown_frac(s.id)
			var was := b.cd_frac
			b.cd_frac = f
			b.cd_text = str(int(ceil(world.cd[s.id]))) if f > 0.0 else ""
			if was > 0.0 and f <= 0.0:
				b.flash()
			b.queue_redraw()
	# context Act button
	var n = world.nearest_ent()
	if n != null and snapshot_ui == null:
		act_btn.visible = true
		act_btn.caption = n.act
		act_btn.set_icon(n.icon)
	else:
		act_btn.visible = false
	if world.map_id == "eden" and act_btn.visible:
		_corner(act_btn, G.settings.left_handed, false, 40, 40)
	var p: Vector3 = world.player.position
	coord_lbl.text = "%s  %d, %d" % ["eden_isle" if world.map_id == "eden" else "destruction", int(p.x * 4 + 120), int(-p.z * 4 + 80)]
	minimap.queue_redraw()
	root.modulate.a = G.settings.hud_opacity

func _on_log(_t: String, _c: Color) -> void:
	if chat_lbl == null:
		return
	var lines := G.log_lines.slice(maxi(0, G.log_lines.size() - 2))
	var s := ""
	for l in lines:
		s += "[color=#%s]%s[/color]\n" % [l[1].to_html(false), l[0]]
	chat_lbl.text = s.strip_edges()

func banner(title: String, sub: String) -> void:
	for c in banner_box.get_children():
		c.queue_free()
	var t := UIKit.outlined(title, 64, Color("fff1c8"), G.font_title)
	t.add_theme_color_override("font_outline_color", Color("4a2c00")); t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := UIKit.outlined(sub, 24, Color.WHITE); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(t); banner_box.add_child(s)
	var tw := create_tween(); banner_box.modulate.a = 0.0
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.6); tw.tween_interval(2.4); tw.tween_property(banner_box, "modulate:a", 0.0, 0.8)

func quest_toast(text: String) -> void:
	toast_lbl.text = "New quest step: " + text
	var tw := create_tween(); toast_lbl.modulate.a = 0.0
	tw.tween_property(toast_lbl, "modulate:a", 1.0, 0.3); tw.tween_interval(2.2); tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.5)

func set_quest(text: String) -> void:
	if quest_lbl:
		quest_lbl.text = text if text != "" else "Quest complete."

func hit_flash() -> void:
	if G.settings.reduce_motion:
		return
	flash_rect.color.a = 0.18
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.3)

func ground_marker(_p: Vector2) -> void:
	pass

func item_pop(icon: String, from: Vector2) -> void:
	var t := UIKit.icon_rect(icon, 64)
	t.position = from - Vector2(32, 32); root.add_child(t)
	var dest := more_btn.global_position + Vector2(10, 10)
	var tw := create_tween()
	tw.tween_property(t, "position", from - Vector2(32, 90), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "position", dest, 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(t, "scale", Vector2(0.5, 0.5), 0.5)
	tw.tween_callback(t.queue_free)
	tw.tween_callback(more_btn.flash)

# ------------------------------------------------------------------ overlays
func _dim(close_on_tap: bool = true) -> Control:
	clear_overlay()
	var d := ColorRect.new(); UIKit.full_rect(d); d.color = Color(0.02, 0.03, 0.08, 0.45)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	if close_on_tap:
		d.gui_input.connect(func(e): if e is InputEventScreenTouch and e.pressed: clear_overlay())
	overlay.add_child(d)
	return d

func clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func overlay_open() -> bool:
	return overlay.get_child_count() > 0

func _center(c: Control) -> void:
	var cc := CenterContainer.new(); UIKit.full_rect(cc); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c); overlay.add_child(cc)

func open_more() -> void:
	_dim()
	var w := UIKit.window("Menu", Vector2(720, 0))
	var grid := GridContainer.new(); grid.columns = 5; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	var items := [["bag", "Satchel", "bag"], ["equip", "Equipment", "equip"], ["skills", "Skills", "skills"], ["status", "Status", "status"], ["way", "The Way", "quest"],
		["", "Congregation", "congregation"], ["", "Friends", "friends"], ["", "Veiled Library", "library"], ["chat", "Chat log", "talk"], ["settings", "Settings", "settings"]]
	for it in items:
		var b := Button.new(); b.custom_minimum_size = Vector2(128, 128); b.focus_mode = Control.FOCUS_NONE
		var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; UIKit.full_rect(v); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UIKit.icon_rect(it[2], 60); v.add_child(ic)
		var l := UIKit.label(it[1], 17, UIKit.BLUE_INK, true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l); b.add_child(v)
		var tab: String = it[0]; var nm: String = it[1]
		b.pressed.connect(func():
			if tab == "chat": open_chat()
			elif tab == "": _locked(nm)
			else: open_sheet(tab))
		grid.add_child(b)
	w.body.add_child(grid)
	_center(w.root)

func _locked(nm: String) -> void:
	clear_overlay()
	var msg := {"Congregation": "Congregations open at the Palace Beautiful (vertical slice).", "Friends": "Friends and mentorship need online play, which this offline demo does not include.",
		"Veiled Library": "The Veiled Library (codex, Westminster Shorter Catechism, full Scripture readings) arrives in a later build."}
	G.say(msg.get(nm, "Not in this demo."), G.WARN)

func open_chat() -> void:
	_dim()
	var w := UIKit.window("Chat · Local", Vector2(760, 460))
	var tabs := HBoxContainer.new()
	for t in ["Local", "Party", "Congregation", "System"]:
		var b := UIKit.button(t, func(): pass, 120); tabs.add_child(b)
	w.body.add_child(tabs)
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(720, 300); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.custom_minimum_size = Vector2(700, 0)
	r.add_theme_font_size_override("normal_font_size", 19); r.add_theme_color_override("default_color", UIKit.INK)
	var s := ""
	for l in G.log_lines:
		var c: Color = l[1]
		s += "[color=#%s]%s[/color]\n" % [c.darkened(0.45).to_html(false), l[0]]
	r.text = s; sc.add_child(r); w.body.add_child(sc)
	w.body.add_child(UIKit.label("Local chat and emotes are online-only. There is no world chat (by design).", 16, UIKit.SUB))
	_center(w.root)

func open_sheet(tab: String) -> void:
	_dim()
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/window.png", 12, 16))
	sheet.anchor_left = 1; sheet.anchor_right = 1; sheet.anchor_top = 0; sheet.anchor_bottom = 1
	sheet.offset_left = -700; sheet.offset_right = -8; sheet.offset_top = 8; sheet.offset_bottom = -8
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(sheet)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); sheet.add_child(v)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 4)
	for t in [["bag", "Satchel"], ["equip", "Equip"], ["skills", "Skills"], ["status", "Status"], ["way", "The Way"], ["settings", "Settings"]]:
		var key: String = t[0]
		var b := UIKit.button(t[1], func(): open_sheet(key), 0)
		b.custom_minimum_size = Vector2(0, 52)
		if key == tab:
			b.add_theme_stylebox_override("normal", UIKit.sb("res://assets/ui/btn_gold.png", 10, 12))
		tabs.add_child(b)
	var close := UIKit.button("✕", clear_overlay, 56)
	tabs.add_child(close)
	v.add_child(tabs)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 10); body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	match tab:
		"bag": _sheet_bag(body)
		"equip": _sheet_equip(body)
		"skills": _sheet_skills(body)
		"status": _sheet_status(body)
		"way": _sheet_way(body)
		"settings": _sheet_settings(body)
	sheet.position.x += 60
	sheet.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sheet, "modulate:a", 1.0, 0.18)

func _sheet_bag(b: VBoxContainer) -> void:
	b.add_child(UIKit.label("Satchel", 26, UIKit.BLUE_INK, true))
	var grid := GridContainer.new(); grid.columns = 6; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	var keys := []
	for k in G.bag.keys():
		if int(G.bag[k]) > 0: keys.append(k)
	var icons := {"Bread of Provision": "bread", "Garden Fig": "fig", "Parchment Roll": "scroll"}
	for i in 18:
		var p := PanelContainer.new(); p.custom_minimum_size = Vector2(96, 96)
		p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/slot.png", 8, 4))
		if i < keys.size():
			var vb := VBoxContainer.new(); vb.alignment = BoxContainer.ALIGNMENT_CENTER
			vb.add_child(UIKit.icon_rect(icons.get(keys[i], "scroll"), 52))
			var l := UIKit.label("%s ×%d" % [keys[i].split(" ")[0], G.bag[keys[i]]], 14, UIKit.INK, true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(l); p.add_child(vb)
			p.tooltip_text = "%s · Clay ○ · %s" % [keys[i], "Restores health." if keys[i] != "Parchment Roll" else "“Fly from the wrath to come.”"]
		grid.add_child(p)
	b.add_child(grid)
	b.add_child(UIKit.label("18 of 60 slots shown · Weight %d / 800 · Denarii 0" % _weight(), 17, UIKit.SUB))
	b.add_child(UIKit.label("Tip: long-press the quick-item button to switch between Bread and Figs.", 17, UIKit.SUB, false, true))

func _weight() -> int:
	var w := 0
	for k in G.bag: w += int(G.bag[k])
	return w

func _sheet_equip(b: VBoxContainer) -> void:
	b.add_child(UIKit.label("Equipment", 26, UIKit.BLUE_INK, true))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 20)
	var slots := VBoxContainer.new(); slots.add_theme_constant_override("separation", 8)
	for s in ["Head (upper): —", "Head (mid): —", "Body: Pilgrim's robe ○", "Hand: Walking staff ○", "Garment: —", "Fruit socket: — (crafted only)"]:
		var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/slot.png", 8, 10)); p.custom_minimum_size = Vector2(330, 0)
		p.add_child(UIKit.label(s, 18)); slots.add_child(p)
	h.add_child(slots)
	var at := AtlasTexture.new(); at.atlas = G.player_sheet; at.region = Rect2(0, 0, 32, 48)
	var tr := TextureRect.new(); tr.texture = at; tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; tr.custom_minimum_size = Vector2(160, 240)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(tr)
	b.add_child(h)
	b.add_child(UIKit.label("The whole Armor of God is given at the Palace Beautiful armory, the same for every pilgrim. It is never sold, refined or levelled.", 17, UIKit.SUB, false, true))

func _sheet_skills(b: VBoxContainer) -> void:
	b.add_child(UIKit.label("Skills · Pilgrim (Job %d)" % G.job, 26, UIKit.BLUE_INK, true))
	for s in [["steps", "First Steps", "A sure first blow (20–24 damage). 10 Zeal · 6 s cooldown. Auto-slot: on."],
		["refuge", "Take Refuge", "Restores 30 health. 15 Zeal · 12 s cooldown. Auto-slot: below 45% health. [BSB: Psalm 9:9]"],
		["lock", "More skills", "Open with Job Level and your Calling (Valiant, Watcher, Shepherd) at the Interpreter's House."]]:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12)
		h.add_child(UIKit.icon_rect(s[0], 64))
		var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(s[1], 21, UIKit.INK, true)); v.add_child(UIKit.label(s[2], 17, UIKit.SUB, false, true))
		h.add_child(v); b.add_child(h)
	b.add_child(UIKit.label("Skill points: %d (2 per Job Level)" % ((G.job - 1) * 2), 17, UIKit.SUB))

func _sheet_status(b: VBoxContainer) -> void:
	b.add_child(UIKit.label("Status · %s" % G.pname, 26, UIKit.BLUE_INK, true))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 16)
	var hexc: Control = load("res://scripts/screens/create.gd").Hexagon.new(); hexc.custom_minimum_size = Vector2(220, 220)
	h.add_child(hexc)
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 24); grid.add_theme_constant_override("v_separation", 6)
	for s in ["Fortitude", "Diligence", "Steadfastness", "Wisdom", "Sobriety", "Hope"]:
		grid.add_child(UIKit.label(s, 19)); grid.add_child(UIKit.label("1", 19, UIKit.INK, true))
	h.add_child(grid); b.add_child(h)
	b.add_child(UIKit.label("Status points to spend: %d (allocation arrives in the next build)" % ((G.lvl - 1) * 2), 17, UIKit.SUB, false, true))
	b.add_child(UIKit.label("Base Lv %d · Job Lv %d · Health %d/%d · Zeal %d/%d · Manna %s" % [G.lvl, G.job, G.hp, G.hp_max, G.zeal, G.zeal_max, str(snappedf(G.manna, 0.1))], 18))

func _sheet_way(b: VBoxContainer) -> void:
	b.add_child(UIKit.label("The Way · Quest log", 26, UIKit.BLUE_INK, true))
	for i in world.objectives.size():
		var o: Dictionary = world.objectives[i]
		var done: bool = i < world.obj_idx
		var cur: bool = i == world.obj_idx
		var txt: String = ("✓  " if done else ("▸  " if cur else "·  ")) + (o.text if i <= world.obj_idx else "???")
		var l := UIKit.label(txt, 20, Color("b85a00") if cur else (Color("8a93a8") if done else Color("aab0c0")), cur)
		b.add_child(l)
	if world.obj_idx < world.objectives.size():
		b.add_child(UIKit.button("Auto-path to current step", func(): clear_overlay(); world.auto_path_quest(), 0, true))

func _sheet_settings(b: VBoxContainer) -> void:
	b.add_child(UIKit.label("Settings", 26, UIKit.BLUE_INK, true))
	for s in [["auto_loot", "Auto-loot nearby drops"], ["dmg_numbers", "Show damage numbers"], ["reduce_motion", "Reduce motion (no bounce, shake or flash)"], ["left_handed", "Left-handed layout (mirror the HUD)"]]:
		var key: String = s[0]
		var cb := CheckButton.new(); cb.text = s[1]; cb.button_pressed = bool(G.settings[key]); cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 21); cb.add_theme_color_override("font_color", UIKit.INK); cb.add_theme_color_override("font_pressed_color", UIKit.INK)
		cb.toggled.connect(func(on): G.settings[key] = on; if key == "left_handed": _rebuild())
		b.add_child(cb)
	var row := HBoxContainer.new(); row.add_child(UIKit.label("HUD opacity", 20)); var sl := HSlider.new(); sl.min_value = 0.4; sl.max_value = 1.0; sl.step = 0.05; sl.value = G.settings.hud_opacity
	sl.custom_minimum_size = Vector2(300, 40); sl.value_changed.connect(func(v): G.settings.hud_opacity = v); row.add_child(sl); b.add_child(row)
	b.add_child(UIKit.label("Camera: pinch to zoom, two-finger swipe to rotate. Lord's Day Mode turns on automatically on Sundays (not in this demo). Music and sound arrive with the composer pass.", 16, UIKit.SUB, false, true))
	b.add_child(UIKit.button("Return to title", func(): G.goto("title"), 0))

func _rebuild() -> void:
	clear_overlay()
	for c in root.get_children():
		c.queue_free()
	skill_btns.clear(); hud_nodes.clear(); combat_nodes.clear()
	await get_tree().process_frame
	_build(); refresh(); set_quest(world.objectives[world.obj_idx].text if world.obj_idx < world.objectives.size() else "")
	_on_log("", Color.WHITE)

# ------------------------------------------------------------------ dialogs
func _dialog_window(who: String, text: String, src: String, portrait: String) -> Dictionary:
	var d := ColorRect.new(); UIKit.full_rect(d); d.color = Color(0.02, 0.03, 0.08, 0.25); d.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(d)
	if portrait != "":
		var pt := TextureRect.new(); pt.texture = G.tex(portrait); pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		pt.anchor_top = 1; pt.anchor_bottom = 1; pt.offset_left = 30; pt.offset_right = 330; pt.offset_top = -420; pt.offset_bottom = -40
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(pt)
	var w := UIKit.window("", Vector2(820, 210))
	w.root.anchor_left = 0.5; w.root.anchor_right = 0.5; w.root.anchor_top = 1; w.root.anchor_bottom = 1
	w.root.offset_left = -330; w.root.offset_right = 520; w.root.offset_top = -270; w.root.offset_bottom = -30
	w.body.add_child(UIKit.label("[%s]" % who, 23, Color("1d4fb8"), true))
	w.body.add_child(UIKit.label(text, 24, UIKit.INK, false, true))
	if src != "":
		w.body.add_child(UIKit.label(src, 15, UIKit.SUB, false, true))
	overlay.add_child(w.root)
	return w

func run_dialog(lines: Array, done: Callable, i: int = 0) -> void:
	clear_overlay()
	if i >= lines.size():
		done.call(); return
	var L: Dictionary = lines[i]
	var w := _dialog_window(L.get("who", ""), L.text, L.get("src", ""), L.get("portrait", ""))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; row.add_theme_constant_override("separation", 8)
	if L.has("choices"):
		for c in L.choices:
			var cc: Dictionary = c
			row.add_child(UIKit.button(cc.t, func():
				if cc.has("fn"): cc.fn.call()
				run_dialog(lines, done, i + 1), 220))
	else:
		row.add_child(UIKit.button("Next ▶", func(): run_dialog(lines, done, i + 1), 160))
	w.body.add_child(row)

func evangelist_dialog() -> void:
	var src := "John Bunyan, The Pilgrim's Progress (1678) · public domain"
	var por := "res://assets/portraits/evangelist.png"
	run_dialog([
		{"who": "Evangelist", "text": "Wherefore dost thou cry?", "src": src, "portrait": por},
		{"who": G.pname, "text": "I am weighed down by this burden, and I fear what is to come."},
		{"who": "Evangelist", "text": "If this be thy condition, why standest thou still?", "src": src, "portrait": por},
		{"who": G.pname, "text": "Because I know not whither to go.", "src": src},
		{"who": "Evangelist", "text": "He gives you a parchment roll. Written within: “Fly from the wrath to come.”", "src": src + " · alluding to Matthew 3:7 [BSB pulled at build time]", "portrait": por},
		{"who": "Evangelist", "text": "Do you see yonder wicket-gate?", "src": src, "portrait": por, "choices": [{"t": "No."}]},
		{"who": "Evangelist", "text": "Do you see yonder shining light?", "src": src, "portrait": por, "choices": [{"t": "I think I do."}]},
		{"who": "Evangelist", "text": "Keep that light in your eye, and go up directly thereto: so shalt thou see the gate; at which, when thou knockest, it shall be told thee what thou shalt do.", "src": src, "portrait": por}],
		func(): world.after_evangelist())

func word_study(done: Callable) -> void:
	var qs := [{"p": "Where is this passage found?", "o": ["Genesis 2", "Exodus 16", "Psalm 23"], "a": 0},
		{"p": "Why was the man placed in the garden?", "o": ["To build a great city", "To tend it and keep it", "To rest and do nothing"], "a": 1}]
	_word_q(qs, 0, -1, done)

func _word_q(qs: Array, qi: int, picked: int, done: Callable) -> void:
	_dim(false)
	var w := UIKit.window("Word Study · Stone Tablet", Vector2(980, 0))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.parchment("[BSB: Genesis 2:15 · text pulled at build time]\n\n▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬\n▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬\n▬▬▬▬▬▬▬▬▬▬▬▬"))
	left.add_child(UIKit.label("Read slowly. The passage stays visible while you answer.", 17, UIKit.SUB, false, true))
	h.add_child(left)
	var right := VBoxContainer.new(); right.custom_minimum_size = Vector2(420, 0); right.add_theme_constant_override("separation", 8)
	var q: Dictionary = qs[qi]
	right.add_child(UIKit.label("Recall %d of %d" % [qi + 1, qs.size()], 17, UIKit.SUB))
	right.add_child(UIKit.label(q.p, 23, UIKit.INK, true, true))
	for i in q.o.size():
		var idx: int = i
		var b := UIKit.button(q.o[i], func(): _word_q(qs, qi, idx, done))
		if picked != -1:
			b.disabled = true
			if i == q.a:
				b.add_theme_stylebox_override("disabled", UIKit.sb("res://assets/ui/btn_gold.png", 10, 14))
		right.add_child(b)
	if picked != -1:
		var ok: bool = picked == q.a
		right.add_child(UIKit.label("Well remembered." if ok else "Look again at the passage.", 20, Color("2f7a3a") if ok else Color("a8342a"), true))
		right.add_child(UIKit.button(("Next" if qi < qs.size() - 1 else "Finish") if ok else "Try again", func():
			if not ok: _word_q(qs, qi, -1, done)
			elif qi < qs.size() - 1: _word_q(qs, qi + 1, -1, done)
			else:
				clear_overlay(); done.call(), 0, true))
	h.add_child(right)
	w.body.add_child(h)
	_center(w.root)

func name_animal(done: Callable) -> void:
	_dim(false)
	var w := UIKit.window("Name the lamb", Vector2(620, 0))
	w.body.add_child(UIKit.label("The man gave names to every living creature [BSB: Genesis 2:19–20]. What will you call this one?", 19, UIKit.SUB, false, true))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	for n in ["Meadow", "Snowfleece", "Patience"]:
		var nn: String = n
		row.add_child(UIKit.button(n, func(): clear_overlay(); done.call(nn), 180))
	w.body.add_child(row)
	var row2 := HBoxContainer.new()
	var le := LineEdit.new(); le.placeholder_text = "Or type a name"; le.max_length = 14; le.custom_minimum_size = Vector2(380, 56)
	row2.add_child(le)
	var msg := UIKit.label("", 16, Color("a8342a"))
	row2.add_child(UIKit.button("OK", func():
		var err := G.name_ok(le.text)
		if err != "": msg.text = err
		else:
			clear_overlay(); done.call(le.text.strip_edges()), 120))
	w.body.add_child(row2); w.body.add_child(msg)
	_center(w.root)

func show_ko(spoil: float) -> void:
	clear_overlay()
	var w := UIKit.window("Rest", Vector2(720, 0))
	w.body.add_child(UIKit.label("Rest, then rise and continue the way.", 30, UIKit.BLUE_INK, true))
	w.body.add_child(UIKit.parchment("[BSB: Proverbs 24:16 · text pulled at build time]\nYour standing before God does not rest on this battle."))
	w.body.add_child(UIKit.label("•  Weariness: you move a little slower for a short while.\n•  Manna spoiled: %s (5%% of unspent). Gather again within 24 h to recover half.\n•  No experience was lost." % str(spoil), 19, UIKit.INK, false, true))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIKit.button("Rise at the nearest safe site", func(): clear_overlay(); world.rise(), 0, true))
	w.body.add_child(row)
	w.root.anchor_left = 0.5; w.root.anchor_right = 0.5; w.root.anchor_top = 1; w.root.anchor_bottom = 1
	w.root.offset_left = -360; w.root.offset_right = 360; w.root.offset_top = -380; w.root.offset_bottom = -30
	overlay.add_child(w.root)

# ------------------------------------------------------------------ snapshot mode
func enter_snapshot() -> void:
	for n in hud_nodes:
		if is_instance_valid(n): n.visible = false
	snapshot_ui = Control.new(); UIKit.full_rect(snapshot_ui); snapshot_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(snapshot_ui)
	var cap := VBoxContainer.new(); cap.anchor_left = 0; cap.anchor_right = 1; cap.anchor_top = 1; cap.anchor_bottom = 1
	cap.offset_top = -130; cap.offset_bottom = -30; cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c1 := UIKit.outlined("“And I saw in my dream…”", 40, Color("fff1c8"), G.font_title); c1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c2 := UIKit.outlined("%s  ·  %s" % [G.pname.to_upper(), "THE CITY OF DESTRUCTION" if world.map_id == "city" else "EDEN ISLE"], 18, Color.WHITE); c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(c1); cap.add_child(c2); snapshot_ui.add_child(cap)
	var bar := HBoxContainer.new(); bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); bar.position = Vector2(-300, 20); bar.add_theme_constant_override("separation", 10)
	bar.add_child(UIKit.button("Close", exit_snapshot, 140))
	bar.add_child(UIKit.button("Caption", func(): cap.visible = not cap.visible, 140))
	var note := UIKit.outlined("Other players' names are hidden by default. Sharing is always your choice.", 16, Color.WHITE)
	bar.add_child(UIKit.button("Take snapshot", func():
		var f := ColorRect.new(); UIKit.full_rect(f); f.color = Color(1, 1, 1, 0.9); f.mouse_filter = Control.MOUSE_FILTER_IGNORE; snapshot_ui.add_child(f)
		create_tween().tween_property(f, "color:a", 0.0, 0.5)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "user://snapshot_%d.png" % Time.get_unix_time_from_system()
		img.save_png(path); G.snaps += 1
		note.text = "Saved to the game's folder (%s)." % path.get_file(), 220, true))
	snapshot_ui.add_child(bar)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); note.position = Vector2(-380, 96); note.size = Vector2(760, 30); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	snapshot_ui.add_child(note)

func exit_snapshot() -> void:
	if snapshot_ui:
		snapshot_ui.queue_free(); snapshot_ui = null
	for n in hud_nodes:
		if is_instance_valid(n): n.visible = true
	refresh()


# ======================================================================
class TapLayer extends Control:
	## Full-screen layer under the HUD: world taps, pinch zoom, two-finger rotate, mouse wheel zoom.
	var hud
	var touches := {}
	var start := {}
	var pinch_d := 0.0
	var pinch_x := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed:
				touches[e.index] = e.position; start[e.index] = [e.position, Time.get_ticks_msec()]
				if touches.size() == 2:
					var p := touches.values(); pinch_d = p[0].distance_to(p[1]); pinch_x = (p[0].x + p[1].x) * 0.5
			else:
				if touches.size() == 1 and start.has(e.index):
					var s: Array = start[e.index]
					if s[0].distance_to(e.position) < 24.0 and Time.get_ticks_msec() - s[1] < 400:
						hud.world.tap(get_global_transform_with_canvas() * e.position)
				touches.erase(e.index); start.erase(e.index)
			accept_event()
		elif e is InputEventScreenDrag and touches.has(e.index):
			touches[e.index] = e.position
			if touches.size() == 2:
				var p := touches.values()
				var d: float = p[0].distance_to(p[1]); var mx: float = (p[0].x + p[1].x) * 0.5
				if pinch_d > 0.0:
					hud.world.zoom_by(pinch_d / maxf(d, 1.0))
				if absf(mx - pinch_x) > 90.0:
					hud.world.rotate_cam(1 if mx > pinch_x else -1); pinch_x = mx
				pinch_d = d
			accept_event()
		elif e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP: hud.world.zoom_by(0.92)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: hud.world.zoom_by(1.08)
			elif e.button_index == MOUSE_BUTTON_RIGHT: hud.world.rotate_cam(1)


class Minimap extends Control:
	var hud
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var w = hud.world
		if w == null: return
		var r := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		var sb := StyleBoxFlat.new(); sb.bg_color = Color("8cc062") if w.map_id == "eden" else Color("9c9484"); sb.set_corner_radius_all(26)
		draw_style_box(sb, r)
		var b: Rect2 = w.bounds
		var to_map := func(p: Vector3) -> Vector2:
			return r.position + Vector2((p.x - b.position.x) / b.size.x, (p.z - b.position.y) / b.size.y) * r.size
		if w.map_id == "eden":
			draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 8)), Color("6aaee0"))
		for e in w.ents:
			if e.hidden: continue
			draw_circle(to_map.call(e.pos), 5, Color("2f7ae0") if e.id in ["evangelist", "lamb"] else Color("e0a020"))
		for m in w.mobs:
			if m.alive: draw_circle(to_map.call(m.actor.position), 4, Color("e83b3b"))
		var q = w.quest_target()
		if q != null:
			var qp: Vector2 = to_map.call(q.pos if q is Dictionary else q)
			draw_string(G.font_ui_bold, qp + Vector2(-6, 8), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd400"))
		var pp: Vector2 = to_map.call(w.player.position)
		var f: Vector3 = w.pact.facing
		var ang := atan2(f.x, f.z)
		var tri := PackedVector2Array([Vector2(0, 9), Vector2(-6, -6), Vector2(6, -6)])
		var rt := PackedVector2Array()
		for v in tri: rt.append(pp + v.rotated(-ang))
		draw_colored_polygon(rt, Color.WHITE)
		draw_polyline(PackedVector2Array([rt[0], rt[1], rt[2], rt[0]]), Color("1d2b52"), 2.0)
		draw_texture_rect(G.tex("res://assets/ui/minimap_frame.png"), Rect2(Vector2.ZERO, size), false)
		var nm := "Eden Isle" if w.map_id == "eden" else "City of Destruction"
		var tw := G.font_ui_bold.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(G.font_ui_bold, Vector2((size.x - tw) * 0.5, 30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0.05, 0.05, 0.1))
		draw_string(G.font_ui_bold, Vector2((size.x - tw) * 0.5, 30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
