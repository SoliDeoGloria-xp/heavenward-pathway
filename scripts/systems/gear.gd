class_name Gear
extends RefCounted
## Road gear, Denarii, Fruit stones, refinement and drops. All numbers are in data/items.json.
## Rules held here: the Armor of God is never gear (it is given whole, the same for everyone);
## nothing is sold for real money; refining never destroys an item; Fruit stones are cut only
## from Manna, which comes through the means of grace, never from kills or coin.

const STAT_NAMES := {"atk": "Attack", "hp": "Health", "zeal": "Zeal", "guard": "Block", "crit": "Critical", "miss": "Miss", "regen": "Zeal/s", "haste": "Speed", "power": "Skills"}
const PERCENT_STATS := ["crit", "miss", "haste", "power"]

static func db() -> Dictionary:
	return G.data("items")

static func def(item: Dictionary) -> Dictionary:
	return db().gear[item.id]

static func rarity(item: Dictionary) -> Dictionary:
	return db().rarities[int(item.rarity)]

static func find(uid: int) -> Dictionary:
	for it in G.gear:
		if int(it.uid) == uid:
			return it
	return {}

static func equipped(slot: String) -> Dictionary:
	return find(int(G.equipped.get(slot, -1)))

static func is_equipped(item: Dictionary) -> bool:
	return int(G.equipped.get(def(item).slot, -1)) == int(item.uid)

## An item's stats after rarity and refinement.
static func stats(item: Dictionary) -> Dictionary:
	var mult: float = float(rarity(item).mult) * (1.0 + float(db().refine.step) * int(item.plus))
	var out := {}
	for k in def(item).stats.keys():
		var v: float = float(def(item).stats[k]) * mult
		out[k] = v if k in PERCENT_STATS else roundf(v)
	return out

static func label(item: Dictionary) -> String:
	var r := rarity(item)
	return "%s %s%s" % [r.mark, def(item).name, " +%d" % int(item.plus) if int(item.plus) > 0 else ""]

static func stat_text(st: Dictionary) -> String:
	var parts: Array = []
	for k in st.keys():
		var v: float = st[k]
		parts.append("%s %+d%%" % [STAT_NAMES[k], int(round(v * 100))] if k in PERCENT_STATS else "%s %+d" % [STAT_NAMES[k], int(v)] if k != "regen" else "%s %+.1f" % [STAT_NAMES[k], v])
	return " · ".join(parts)

## Everything worn, plus the Fruit stone set in the garment. Read by G.calc_for.
static func totals() -> Dictionary:
	var out := {}
	for slot in G.equipped.keys():
		var it := equipped(slot)
		if it.is_empty():
			continue
		var st := stats(it)
		for k in st.keys():
			out[k] = float(out.get(k, 0.0)) + float(st[k])
	if G.fruit_stone != "" and not equipped("garment").is_empty():
		var stone: Dictionary = db().stones[G.fruit_stone]
		out[stone.stat] = float(out.get(stone.stat, 0.0)) + float(stone.add)
	return out

# ------------------------------------------------------------------ owning and wearing
static func add(id: String, rarity_idx: int = 0) -> Dictionary:
	if G.gear.size() >= int(db().bag_cap):
		G.say("Your satchel is full. Sell or store some gear.", G.WARN)
		return {}
	G.gear_uid += 1
	var it := {"uid": G.gear_uid, "id": id, "rarity": rarity_idx, "plus": 0}
	G.gear.append(it)
	return it

static func equip(uid: int) -> void:
	var it := find(uid)
	if it.is_empty():
		return
	G.equipped[def(it).slot] = uid
	G.recalc(); G.sfx("equip")

static func unequip(slot: String) -> void:
	G.equipped.erase(slot)
	G.recalc()

## Wear the strongest piece owned for every slot (sum of an item's stats, percentages weighted).
static func equip_best() -> void:
	for slot in db().slots.keys():
		var best := {}; var best_score := -1.0
		for it in G.gear:
			if def(it).slot == slot and score(it) > best_score:
				best = it; best_score = score(it)
		if not best.is_empty():
			G.equipped[slot] = int(best.uid)
	G.recalc()

static func score(item: Dictionary) -> float:
	var s := 0.0
	var st := stats(item)
	for k in st.keys():
		s += absf(float(st[k])) * (100.0 if k in PERCENT_STATS else (0.4 if k in ["hp", "zeal"] else 4.0))
	return s

# ------------------------------------------------------------------ Denarii: buying, selling, storing
static func price(item: Dictionary) -> int:
	return int(round(float(def(item).price) * float(rarity(item).mult)))

static func sell_price(item: Dictionary) -> int:
	return maxi(1, int(price(item) * float(db().sell_share)))

static func sell(uid: int) -> void:
	var it := find(uid)
	if it.is_empty() or is_equipped(it):
		return
	G.denarii += sell_price(it)
	G.gear.erase(it); G.sfx("coin")
	G.stats_changed.emit()

## id is a gear id or a consumable's name.
static func buy(id: String) -> bool:
	var is_gear: bool = db().gear.has(id)
	var cost := int(db().gear[id].price) if is_gear else int(db().consumables[id].price)
	if G.denarii < cost:
		G.say("Not enough Denarii.", G.WARN); return false
	if is_gear:
		if add(id).is_empty():
			return false
	else:
		G.bag_add(id, 1)
	G.denarii -= cost; G.sfx("coin")
	G.stats_changed.emit()
	return true

static func store(uid: int) -> void:
	var it := find(uid)
	if not it.is_empty() and not is_equipped(it):
		G.gear.erase(it); G.storage.append(it)

static func take(uid: int) -> void:
	for it in G.storage:
		if int(it.uid) == uid and G.gear.size() < int(db().bag_cap):
			G.storage.erase(it); G.gear.append(it)
			return

# ------------------------------------------------------------------ the bench: refining and Fruit stones
static func refine_cost(item: Dictionary) -> int:
	var costs: Array = db().refine.cost
	return int(costs[int(item.plus)]) if int(item.plus) < costs.size() else -1

## Refining always succeeds and never harms the item: no gambling.
static func refine(uid: int) -> bool:
	var it := find(uid)
	var cost := refine_cost(it) if not it.is_empty() else -1
	if cost < 0 or G.denarii < cost:
		G.say("Not enough Denarii." if cost >= 0 else "This piece is refined as far as it can be here.", G.WARN)
		return false
	G.denarii -= cost; it.plus = int(it.plus) + 1
	G.recalc(); G.sfx("equip")
	G.say("%s refined." % label(it), G.INFO)
	return true

static func cut_stone(id: String) -> bool:
	var cost := float(db().stone_cost_manna)
	if G.manna < cost:
		G.say("A Fruit stone is cut from %d Manna. Manna comes through the means of grace: Word Study and rest." % int(cost), G.WARN)
		return false
	G.manna -= cost
	G.stones[id] = int(G.stones.get(id, 0)) + 1
	G.stats_changed.emit()
	return true

static func set_stone(id: String) -> void:
	if int(G.stones.get(id, 0)) <= 0:
		return
	if G.fruit_stone != "":
		G.stones[G.fruit_stone] = int(G.stones.get(G.fruit_stone, 0)) + 1
	G.stones[id] = int(G.stones[id]) - 1
	G.fruit_stone = id
	G.recalc(); G.sfx("equip")

# ------------------------------------------------------------------ drops
## Called when a foe is overcome: a few Denarii, and sometimes a piece of road gear.
static func roll_drop(mob: Dictionary) -> Dictionary:
	var rules: Dictionary = db().drops
	var lv := int(mob.level)
	var coins := int(ceil(lv * float(rules.denarii_per_level) * (4.0 if mob.get("boss", false) else (2.0 if mob.get("greater", false) else 1.0))))
	G.denarii += coins
	var chance: float = 1.0 if mob.get("boss", false) else float(rules.greater_gear_chance if mob.get("greater", false) else rules.gear_chance)
	if randf() >= chance:
		return {}
	var pool: Array = []
	for id in db().gear.keys():
		if int(db().gear[id].level) <= lv:
			pool.append(id)
	if pool.is_empty():
		return {}
	var it := add(pool[randi() % pool.size()], maxi(_roll_rarity(lv), int(rules.boss_rarity) if mob.get("boss", false) else 0))
	if not it.is_empty():
		G.say("You found %s. (More → Equipment)" % label(it), G.INFO)
	return it

static func _roll_rarity(lv: int) -> int:
	for band in db().drops.rarity_weights:
		if lv < int(band.below):
			var total := 0.0
			for wgt in band.w: total += float(wgt)
			var roll := randf() * total
			for i in band.w.size():
				roll -= float(band.w[i])
				if roll <= 0.0:
					return i
	return 0
