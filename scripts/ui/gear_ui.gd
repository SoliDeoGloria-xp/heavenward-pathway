class_name GearUI
extends RefCounted
## Windows for road gear: the Equipment sheet, the vendor (buy, sell, store), the bench
## (refine, Fruit stones) and the Codex (bestiary and daily portion). Built with UIKit so they
## match the rest of the HUD; every button is at least UIKit.MIN_TOUCH tall.

const LIST_HEIGHT := 400.0
const ROW_BTN := 120

static func _row(text: String, sub: String, buttons: Array, icon: String = "") -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/slot.png", 8, 8))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
	if icon != "":
		h.add_child(UIKit.icon_rect(icon, 44))
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 0)
	v.add_child(UIKit.label(text, 19, UIKit.INK, true))
	if sub != "":
		v.add_child(UIKit.label(sub, 16, UIKit.SUB, false, true))
	h.add_child(v)
	for b in buttons:
		h.add_child(b)
	p.add_child(h)
	return p

static func _item_row(it: Dictionary, buttons: Array) -> PanelContainer:
	var p := _row(Gear.label(it), "%s · %s" % [Gear.db().slots[Gear.def(it).slot], Gear.stat_text(Gear.stats(it))], buttons, Gear.def(it).icon)
	return p

static func _scroll(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new(); sc.custom_minimum_size.y = LIST_HEIGHT; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 6)
	sc.add_child(v); parent.add_child(sc)
	return v

static func _purse() -> String:
	return "Denarii %d · Manna %s" % [G.denarii, str(snappedf(G.manna, 0.1))]

# ------------------------------------------------------------------ Equipment sheet (More → Equipment)
static func sheet(hud: Node, b: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	var t := UIKit.label("Equipment", 26, UIKit.BLUE_INK, true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t); head.add_child(UIKit.button("Wear the best", func() -> void: Gear.equip_best(); hud.open_sheet("equip"), 220))
	b.add_child(head)
	b.add_child(_row("Armor of God", "The whole armor (+%d block), given at the Palace, the same for every pilgrim. Never sold, refined or levelled." % int(G.PROG["armor_guard"]) if G.armor else "Not yet received. It is given whole at the Palace Beautiful.", [], "shield_of_faith"))
	for slot in Gear.db().slots.keys():
		var it := Gear.equipped(slot)
		if it.is_empty():
			b.add_child(_row("%s: —" % Gear.db().slots[slot], "", []))
		else:
			b.add_child(_item_row(it, [UIKit.button("Take off", func() -> void: Gear.unequip(slot); hud.open_sheet("equip"), ROW_BTN + 20)]))
	var stone: String = G.fruit_stone
	b.add_child(_row("Fruit stone (in the garment): %s" % (Gear.db().stones[stone].name if stone != "" else "—"),
		Gear.db().stones[stone].text if stone != "" else "Cut and set at the armory bench in the Palace.", [], "fruit_stone"))
	b.add_child(UIKit.label("In your satchel (%d of %d) · %s" % [G.gear.size(), int(Gear.db().bag_cap), _purse()], 18, UIKit.SUB, true))
	for it in G.gear:
		if not Gear.is_equipped(it):
			var uid := int(it.uid)
			b.add_child(_item_row(it, [UIKit.button("Wear", func() -> void: Gear.equip(uid); hud.open_sheet("equip"), ROW_BTN, true)]))
	b.add_child(UIKit.label("Road gear is help for the journey, not a measure of the pilgrim. Sell or store spare pieces with a Steward or Provisioner.", 16, UIKit.SUB, false, true))

# ------------------------------------------------------------------ vendor
static func shop(hud: Node, tab: String = "buy") -> void:
	hud._dim(false)
	var w := UIKit.window("Provisions · %s" % _purse(), Vector2(860, 0))
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8)
	for tb in [["buy", "Buy"], ["sell", "Sell"], ["store", "Storage"]]:
		var id: String = tb[0]
		var bt := UIKit.button(tb[1], func() -> void: shop(hud, id), 160, id == tab)
		hud.more_tiles["shop_" + id] = bt
		tabs.add_child(bt)
	var gap := Control.new(); gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(gap)
	tabs.add_child(UIKit.button("Done", func() -> void: hud.clear_overlay(), 140))
	w.body.add_child(tabs)
	var list := _scroll(w.body)
	match tab:
		"buy":
			for id in Gear.db().shop:
				var is_gear: bool = Gear.db().gear.has(id)
				var d: Dictionary = Gear.db().gear[id] if is_gear else Gear.db().consumables[id]
				var sub := Gear.stat_text(d.stats) if is_gear else ("Restores %d Health." % int(d.heal) if d.has("heal") else "Restores %d Zeal." % int(d.zeal))
				var item_id: String = id
				var bt := UIKit.button("%d" % int(d.price), func() -> void:
					if Gear.buy(item_id): shop(hud, "buy"), ROW_BTN, G.denarii >= int(d.price))
				hud.more_tiles["buy_" + id] = bt
				list.add_child(_row(String(d.name) if is_gear else id, sub, [bt], d.icon))
		"sell":
			for it in G.gear:
				if not Gear.is_equipped(it):
					var uid := int(it.uid)
					list.add_child(_item_row(it, [UIKit.button("+%d" % Gear.sell_price(it), func() -> void: Gear.sell(uid); shop(hud, "sell"), ROW_BTN)]))
			if list.get_child_count() == 0:
				list.add_child(UIKit.label("Nothing spare to sell. Worn gear is not listed.", 18, UIKit.SUB))
		"store":
			list.add_child(UIKit.label("Kept safe in the House (%d pieces). Storage is shared by every House you reach." % G.storage.size(), 17, UIKit.SUB, false, true))
			for it in G.storage:
				var uid := int(it.uid)
				list.add_child(_item_row(it, [UIKit.button("Take", func() -> void: Gear.take(uid); shop(hud, "store"), ROW_BTN)]))
			for it in G.gear:
				if not Gear.is_equipped(it):
					var uid := int(it.uid)
					list.add_child(_item_row(it, [UIKit.button("Store", func() -> void: Gear.store(uid); shop(hud, "store"), ROW_BTN)]))
	hud._center(w.root)

# ------------------------------------------------------------------ the armory bench: refine and Fruit stones
static func bench(hud: Node) -> void:
	hud._dim(false)
	var w := UIKit.window("The Armory Bench · %s" % _purse(), Vector2(900, 0))
	var list := _scroll(w.body)
	list.add_child(UIKit.label("Refine your road gear (up to +%d here). Refining always succeeds and never harms the piece." % int(Gear.db().refine.max), 17, UIKit.SUB, false, true))
	for slot in Gear.db().slots.keys():
		var it := Gear.equipped(slot)
		if it.is_empty():
			continue
		var uid := int(it.uid); var cost := Gear.refine_cost(it)
		var bt := UIKit.button("Refine · %d" % cost if cost >= 0 else "Max", func() -> void:
			if Gear.refine(uid): bench(hud), 190, cost >= 0 and G.denarii >= cost)
		bt.disabled = cost < 0
		hud.more_tiles["refine_" + slot] = bt
		list.add_child(_item_row(it, [bt]))
	list.add_child(UIKit.parchment(String(Gear.db().stone_note)))
	var set_now: String = G.fruit_stone
	for id in Gear.db().stones.keys():
		var stone: Dictionary = Gear.db().stones[id]
		var sid: String = id
		var have := int(G.stones.get(id, 0))
		var cut := UIKit.button("Cut · %d Manna" % int(Gear.db().stone_cost_manna), func() -> void:
			if Gear.cut_stone(sid): bench(hud), 190, G.manna >= float(Gear.db().stone_cost_manna))
		var put := UIKit.button("Set", func() -> void: Gear.set_stone(sid); bench(hud), 90, have > 0)
		put.disabled = have <= 0
		hud.more_tiles["cut_" + id] = cut; hud.more_tiles["set_" + id] = put
		list.add_child(_row("%s%s" % [stone.name, "  (set)" if id == set_now else ("  ×%d" % have if have > 0 else "")], String(stone.text), [cut, put], "fruit_stone"))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIKit.button("Done", func() -> void: hud.clear_overlay(), 160, true)); w.body.add_child(row)
	hud._center(w.root)

# ------------------------------------------------------------------ Codex sheet: daily portion and bestiary
static func codex(hud: Node, b: VBoxContainer) -> void:
	b.add_child(UIKit.label("Codex", 26, UIKit.BLUE_INK, true))
	var st := G.daily_state()
	var rules: Dictionary = Gear.db().daily
	var readings: Array = G.data("lords_day").readings
	var ref: String = readings[hash(G.today()) % readings.size()]
	var read_bt := UIKit.button("I have read it" if not st.read else "Read ✓", func() -> void: G.daily_state().read = true; hud.open_sheet("codex"), 200, not st.read)
	read_bt.disabled = st.read
	b.add_child(_row("Daily portion: read today's passage", "[BSB: %s]" % ref, [read_bt], "library"))
	var claim := UIKit.button("Receive" if not st.claimed else "Received ✓", func() -> void: G.daily_claim(); hud.open_sheet("codex"), 200, G.daily_done() and not st.claimed)
	claim.disabled = not G.daily_done() or st.claimed
	hud.more_tiles["daily_claim"] = claim
	b.add_child(_row("Daily portion: overcome %d foes (%d/%d)" % [int(rules.kills), mini(int(st.kills), int(rules.kills)), int(rules.kills)],
		"Manna +%d and Denarii +%d. There are no streaks; a missed day costs nothing." % [int(rules.reward_manna), int(rules.reward_denarii)], [claim], "bread"))
	b.add_child(UIKit.label("Bestiary: what you have met on the road", 20, UIKit.INK, true))
	var why: Dictionary = G.PROG["weakness"].why
	var any := false
	for id in G.MOBS.keys():
		var n := int(G.bestiary.get(id, 0))
		if n <= 0:
			continue
		any = true
		var m: Dictionary = G.MOBS[id]
		b.add_child(_row("%s · Lv %d%s" % [m.name, int(m.level), " · Boss" if m.get("boss", false) else ""],
			"Family: %s · gives way to %s · overcome %d" % [String(m.family).capitalize(), why.get(m.family, "—"), n], []))
	if not any:
		b.add_child(UIKit.label("Nothing yet. Each foe you overcome is written here with the virtue it gives way to.", 17, UIKit.SUB, false, true))
