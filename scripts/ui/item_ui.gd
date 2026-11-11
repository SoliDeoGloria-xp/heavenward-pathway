class_name ItemUI
extends RefCounted
## Item tiles and the detail card under them: the bag, the Equipment sheet and the vendor all use
## these, so an item looks and behaves the same wherever it is shown. A tile is a square slot with
## the item's picture, a border in its rarity's colour, a count or refinement in the corner and an
## "E" when it is worn. Tapping a tile selects it; what can be done with it is on the detail card.

const TILE := 92.0
const COLS := 6
const GAP := 8

static func grid(cols: int = COLS) -> GridContainer:
	var g := GridContainer.new(); g.columns = cols
	g.add_theme_constant_override("h_separation", GAP); g.add_theme_constant_override("v_separation", GAP)
	return g

static func _corner(text: String, size: int, color: Color, right: bool, bottom: bool) -> Label:
	var l := UIKit.outlined(text, size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.full_rect(l)
	l.offset_left = 7; l.offset_right = -7; l.offset_top = 3; l.offset_bottom = -3
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if bottom else VERTICAL_ALIGNMENT_TOP
	return l

## opts: icon, corner (bottom-right text), badge (top-left text), color (border), selected, dim, caption
static func tile(opts: Dictionary, on_tap: Callable = Callable()) -> Button:
	var b := Button.new(); b.focus_mode = Control.FOCUS_NONE; b.theme = G.theme
	b.custom_minimum_size = Vector2(TILE, TILE)
	var slot := UIKit.sb("res://assets/ui/slot.png", 5, 4)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, slot)
	if opts.has("icon"):
		var ic := UIKit.icon_rect(String(opts.icon), 60)
		UIKit.full_rect(ic); ic.offset_left = 14; ic.offset_right = -14; ic.offset_top = 12; ic.offset_bottom = -16
		if opts.get("dim", false):
			ic.modulate = Color(1, 1, 1, 0.35)
		b.add_child(ic)
	if opts.has("color") or opts.get("selected", false):
		var frame := Panel.new(); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; UIKit.full_rect(frame)
		var fs := StyleBoxFlat.new(); fs.draw_center = false
		fs.border_color = UIKit.GLOW if opts.get("selected", false) else Color(String(opts.color)) if opts.color is String else opts.color
		fs.set_border_width_all(5 if opts.get("selected", false) else 3)
		frame.add_theme_stylebox_override("panel", fs); b.add_child(frame)
	if String(opts.get("corner", "")) != "":
		b.add_child(_corner(String(opts.corner), 17, Color.WHITE, true, true))
	if String(opts.get("badge", "")) != "":
		b.add_child(_corner(String(opts.badge), 16, Color("7cff7c"), false, false))
	if String(opts.get("caption", "")) != "":
		var c := _corner(String(opts.caption), 13, Color("e8dcc0"), false, true)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; b.add_child(c)
	if on_tap.is_valid():
		b.pressed.connect(func() -> void: G.sfx("tap"))
		b.pressed.connect(on_tap)
	return b

static func gear_tile(it: Dictionary, selected: bool, on_tap: Callable) -> Button:
	return tile({"icon": Gear.def(it).icon, "color": String(Gear.rarity(it).color), "selected": selected,
		"corner": ("+%d" % int(it.plus)) if int(it.plus) > 0 else "", "badge": "E" if Gear.is_equipped(it) else ""}, on_tap)

## The card that says what the selected thing is and holds the buttons for it.
static func card(icon: String, title: String, title_color: Color, lines: Array, buttons: Array) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/card.png", 4, 10))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12)
	if icon != "":
		var slot := PanelContainer.new(); slot.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/slot.png", 5, 6))
		slot.add_child(UIKit.icon_rect(icon, 64)); slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(slot)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 1)
	v.add_child(UIKit.label(title, 21, title_color, true, true))
	for line in lines:
		if String(line) != "":
			v.add_child(UIKit.label(String(line), 16, UIKit.SUB, false, true))
	h.add_child(v)
	var bv := VBoxContainer.new(); bv.alignment = BoxContainer.ALIGNMENT_CENTER; bv.add_theme_constant_override("separation", 6)
	for b in buttons:
		bv.add_child(b)
	if not buttons.is_empty():
		h.add_child(bv)
	p.add_child(h)
	return p

## "Attack +2 · Health +25", and how that differs from what is worn in the same slot.
static func gear_lines(it: Dictionary) -> Array:
	var d: Dictionary = Gear.def(it)
	var lines: Array = ["%s · %s%s" % [String(Gear.rarity(it).name), String(Gear.db().slots[d.slot]), " · worn" if Gear.is_equipped(it) else ""], Gear.stat_text(Gear.stats(it))]
	var worn := Gear.equipped(String(d.slot))
	if not Gear.is_equipped(it):
		if worn.is_empty():
			lines.append("Nothing is worn there now.")
		else:
			var diff := Gear.score(it) - Gear.score(worn)
			lines.append("%s than the %s you wear." % ["Better" if diff > 0.01 else ("Worse" if diff < -0.01 else "No better or worse"), String(Gear.def(worn).name)])
	return lines

static func gear_card(it: Dictionary, buttons: Array) -> PanelContainer:
	return card(String(Gear.def(it).icon), Gear.label(it), Color(String(Gear.rarity(it).color)).darkened(0.25), gear_lines(it), buttons)

static func hint(text: String) -> PanelContainer:
	return card("", text, UIKit.SUB, [], [])
