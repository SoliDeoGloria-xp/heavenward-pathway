class_name GearUI
extends RefCounted
## Windows for road gear: the Equipment sheet, the vendor (buy, sell, store), the bench
## (refine, Fruit stones) and the Codex (bestiary and daily portion). Built with UIKit so they
## match the rest of the HUD; every button is at least UIKit.MIN_TOUCH tall.

const LIST_HEIGHT := 400.0
const ROW_BTN := 120

static func _row(text: String, sub: String, buttons: Array, icon: String = "") -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/card.png", 4, 8))
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
	var sc := TouchScroll.new(); sc.custom_minimum_size.y = LIST_HEIGHT
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 6)
	sc.add_child(v); parent.add_child(sc)
	return v

static func _purse() -> String:
	return "Denarii %d · Manna %s" % [G.denarii, str(snappedf(G.manna, 0.1))]

# ------------------------------------------------------------------ Equipment sheet (More → Equipment)
## What is worn, as a row of slots; under it the pieces in the Satchel that fit the chosen slot.
## Tap a slot or a piece: its card, with Wear or Take off, stays at the bottom of the sheet.
static func sheet(hud: Node, b: VBoxContainer) -> void:
	var slots: Dictionary = Gear.db().slots
	if hud.equip_sel == "":
		hud.equip_sel = "slot:" + String(slots.keys()[0])
	var pick := Gear.find(int(hud.equip_sel.substr(2))) if hud.equip_sel.begins_with("g:") else {}
	var cur_slot: String = String(Gear.def(pick).slot) if not pick.is_empty() else (hud.equip_sel.substr(5) if hud.equip_sel.begins_with("slot:") else "")
	var head := HBoxContainer.new()
	var t := UIKit.label("Equipment", 26, UIKit.BLUE_INK, true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t); head.add_child(UIKit.button("Wear the best", func() -> void: Gear.equip_best(); hud.open_sheet("equip"), 220))
	b.add_child(head)
	var worn := ItemUI.grid(6)
	for slot in slots.keys():
		var sid: String = slot
		var it := Gear.equipped(sid)
		var chosen: bool = cur_slot == sid and pick.is_empty()
		var tile: Button
		if it.is_empty():
			tile = ItemUI.tile({"caption": String(slots[sid]), "selected": chosen}, func() -> void: hud.equip_sel = "slot:" + sid; hud.open_sheet("equip"))
		else:
			tile = ItemUI.tile({"icon": Gear.def(it).icon, "color": String(Gear.rarity(it).color), "selected": chosen, "caption": String(slots[sid]),
				"corner": ""}, func() -> void: hud.equip_sel = "slot:" + sid; hud.open_sheet("equip"))
		hud.more_tiles["equip_slot_" + sid] = tile
		worn.add_child(tile)
	worn.add_child(ItemUI.tile({"icon": "shield_of_faith", "dim": not G.armor, "caption": "Armor", "selected": hud.equip_sel == "armor"}, func() -> void: hud.equip_sel = "armor"; hud.open_sheet("equip")))
	worn.add_child(ItemUI.tile({"icon": "fruit_stone", "dim": G.fruit_stone == "", "caption": "Stone", "selected": hud.equip_sel == "stone"}, func() -> void: hud.equip_sel = "stone"; hud.open_sheet("equip")))
	b.add_child(worn)
	var total := Gear.stat_text(Gear.totals())
	b.add_child(UIKit.label("From what you wear: %s" % (total if total != "" else "nothing yet"), 16, UIKit.SUB, true, true))
	var spare: Array = G.gear.filter(func(it: Dictionary) -> bool: return not Gear.is_equipped(it) and (cur_slot == "" or String(Gear.def(it).slot) == cur_slot))
	spare.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return Gear.score(x) > Gear.score(y))
	b.add_child(UIKit.label(("In your Satchel for the %s" % String(slots[cur_slot])) if cur_slot != "" else "In your Satchel", 19, UIKit.BLUE_INK, true))
	if spare.is_empty():
		b.add_child(UIKit.label("Nothing spare for this slot. Foes sometimes drop road gear, and Provisioners sell it.", 16, UIKit.SUB, false, true))
	else:
		var grid := ItemUI.grid()
		for it in spare:
			var uid := int(it.uid)
			var tile := ItemUI.gear_tile(it, hud.equip_sel == "g:%d" % uid, func() -> void: hud.equip_sel = "g:%d" % uid; hud.open_sheet("equip"))
			hud.more_tiles["equip_g_%d" % uid] = tile
			grid.add_child(tile)
		b.add_child(grid)
	b.add_child(UIKit.label("Road gear is help for the journey, not a measure of the pilgrim.", 15, UIKit.SUB, false, true))
	# the card
	var foot: VBoxContainer = hud.sheet_footer
	if hud.equip_sel == "armor":
		foot.add_child(ItemUI.card("shield_of_faith", "Armor of God", UIKit.BLUE_INK, ["The whole armor (+%d block), given at the Palace, the same for every pilgrim. Never sold, refined or levelled." % int(G.PROG["armor_guard"]) if G.armor else "Not yet received. It is given whole at the Palace Beautiful."], []))
	elif hud.equip_sel == "stone":
		var stone: String = G.fruit_stone
		foot.add_child(ItemUI.card("fruit_stone", "Fruit stone: %s" % (String(Gear.db().stones[stone].name) if stone != "" else "none set"), UIKit.BLUE_INK,
			[String(Gear.db().stones[stone].text) if stone != "" else "Cut from Manna and set in the garment at the armory bench in the Palace."], []))
	elif not pick.is_empty():
		var uid := int(pick.uid)
		var wear := UIKit.button("Wear", func() -> void: Gear.equip(uid); hud.equip_sel = "slot:" + String(Gear.def(pick).slot); hud.open_sheet("equip"), 150, true)
		hud.more_tiles["equip_wear"] = wear
		foot.add_child(ItemUI.gear_card(pick, [wear]))
	else:
		var it := Gear.equipped(cur_slot)
		if it.is_empty():
			foot.add_child(ItemUI.hint("%s: nothing worn. Tap a piece above to see it, then Wear." % String(slots[cur_slot])))
		else:
			var off := UIKit.button("Take off", func() -> void: Gear.unequip(cur_slot); hud.open_sheet("equip"), 150)
			hud.more_tiles["equip_off"] = off
			foot.add_child(ItemUI.gear_card(it, [off]))

# ------------------------------------------------------------------ vendor
## Buy, Sell and Storage as shelves of tiles. Tap one: its card, with the price and the button, is below.
const SHOP_COLS := 8

static func shop(hud: Node, tab: String = "buy") -> void:
	var same: bool = hud.get("shop_tab") == tab and is_instance_valid(hud.get("shop_scroll"))
	var keep: int = hud.shop_scroll.scroll_vertical if same else 0
	if not same:
		hud.shop_sel = ""
	hud._dim(false)
	hud.shop_tab = tab
	var w := UIKit.window("Provisions", Vector2(minf(880.0, hud.get_viewport().get_visible_rect().size.x - 24.0), 0))
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8)
	for tb in [["buy", "Buy"], ["sell", "Sell"], ["store", "Storage"]]:
		var id: String = tb[0]
		var bt := UIKit.button(tb[1], func() -> void: shop(hud, id), 150, id == tab)
		hud.more_tiles["shop_" + id] = bt
		tabs.add_child(bt)
	var purse := UIKit.label(_purse(), 19, UIKit.BLUE_INK, true); purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL; purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(purse)
	tabs.add_child(UIKit.button("Done", func() -> void: hud.shop_tab = ""; hud.clear_overlay(), 120))
	w.body.add_child(tabs)
	var sc := TouchScroll.new(); sc.custom_minimum_size.y = 300
	hud.shop_scroll = sc
	var cols: int = SHOP_COLS if hud.get_viewport().get_visible_rect().size.x >= 900.0 else ItemUI.COLS
	var grid := ItemUI.grid(cols)
	sc.add_child(grid); w.body.add_child(sc)
	var pick_tile := func(key: String) -> Callable:
		return func() -> void: hud.shop_sel = key; shop(hud, tab)
	var card: Control = null
	var n := 0
	match tab:
		"buy":
			for id in Gear.db().shop:
				var is_gear: bool = Gear.db().gear.has(id)
				var d: Dictionary = Gear.db().gear[id] if is_gear else Gear.db().consumables[id]
				var item_id: String = id
				var can: bool = G.denarii >= int(d.price)
				var tile := ItemUI.tile({"icon": d.icon, "corner": "%d" % int(d.price), "selected": hud.shop_sel == item_id, "dim": not can}, pick_tile.call(item_id))
				hud.more_tiles["shop_item_" + item_id] = tile
				grid.add_child(tile); n += 1
				if hud.shop_sel == item_id:
					var sub := Gear.stat_text(d.stats) if is_gear else ("Restores %d Health." % int(d.heal) if d.has("heal") else "Restores %d Zeal." % int(d.zeal))
					var have: String = ("You carry %d." % int(G.bag.get(item_id, 0))) if not is_gear else String(Gear.db().slots[d.slot])
					var bt := UIKit.button("Buy · %d" % int(d.price), func() -> void:
						if Gear.buy(item_id): shop(hud, "buy"), 190, can)
					bt.disabled = not can
					hud.more_tiles["buy_" + item_id] = bt
					card = ItemUI.card(String(d.icon), String(d.name) if is_gear else item_id, UIKit.INK, [sub, have, "" if can else "Not enough Denarii."], [bt])
		"sell":
			for it in G.gear:
				if Gear.is_equipped(it):
					continue
				var uid := int(it.uid); var key := "g:%d" % uid
				grid.add_child(ItemUI.gear_tile(it, hud.shop_sel == key, pick_tile.call(key))); n += 1
				if hud.shop_sel == key:
					card = ItemUI.gear_card(it, [UIKit.button("Sell · +%d" % Gear.sell_price(it), func() -> void: Gear.sell(uid); hud.shop_sel = ""; shop(hud, "sell"), 190, true)])
		"store":
			for it in G.storage:
				var uid := int(it.uid); var key := "s:%d" % uid
				var tile := ItemUI.tile({"icon": Gear.def(it).icon, "color": String(Gear.rarity(it).color), "selected": hud.shop_sel == key, "badge": "kept",
					"corner": ("+%d" % int(it.plus)) if int(it.plus) > 0 else ""}, pick_tile.call(key))
				grid.add_child(tile); n += 1
				if hud.shop_sel == key:
					card = ItemUI.card(String(Gear.def(it).icon), Gear.label(it), Color(String(Gear.rarity(it).color)).darkened(0.25), ["In storage · " + Gear.stat_text(Gear.stats(it))],
						[UIKit.button("Take", func() -> void: Gear.take(uid); hud.shop_sel = ""; shop(hud, "store"), 190, true)])
			for it in G.gear:
				if Gear.is_equipped(it):
					continue
				var uid := int(it.uid); var key := "g:%d" % uid
				grid.add_child(ItemUI.gear_tile(it, hud.shop_sel == key, pick_tile.call(key))); n += 1
				if hud.shop_sel == key:
					card = ItemUI.gear_card(it, [UIKit.button("Store", func() -> void: Gear.store(uid); hud.shop_sel = ""; shop(hud, "store"), 190, true)])
	while n < cols * 2 or n % cols != 0:
		grid.add_child(ItemUI.tile({})); n += 1
	var hints := {"buy": "Tap something on the shelf to see it and its price.", "sell": "Tap a spare piece to sell it. Worn gear is not shown." if G.gear.size() > G.equipped.size() else "Nothing spare to sell. Worn gear is not shown.",
		"store": "Tiles marked \"kept\" are in storage (%d pieces), shared by every town and House. Tap a piece to store it or take it back." % G.storage.size()}
	w.body.add_child(card if card != null else ItemUI.hint(String(hints[tab])))
	hud._center(w.root)
	if same:
		sc.set_deferred("scroll_vertical", keep)

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

## The objective that holds a map's Dreamer's Page, or {} when the map has none.
static func _page_of(map_id: String) -> Dictionary:
	var def: Dictionary = G.data("maps/" + map_id)
	for o in def.get("side", []) + def.get("objectives", []):
		if o.get("page", false):
			return o
	return {}

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
	b.add_child(UIKit.label("The Dreamer's Pages (%d found)" % Quests.pages_found(), 20, UIKit.INK, true))
	for map_id in G.data("world").nodes.keys():
		var page := _page_of(map_id)
		if page.is_empty() or not G.flags.has("page_" + map_id):
			continue
		var dlg: String = page.dialog
		b.add_child(_row(String(G.data("maps/" + map_id).name), "", [UIKit.button("Read", func() -> void:
			hud.clear_overlay(); hud.world.scene.play(dlg, func() -> void: pass), ROW_BTN)], "page"))
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
