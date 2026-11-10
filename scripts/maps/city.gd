extends RefCounted
## City of Destruction: geometry and Evangelist.

var w: World

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ City of Destruction
func build() -> void:
	w.bounds = Rect2(-24, -14, 48, 28)
	w.kit.flora = "dark"
	w.kit.ground("cobble_dark", "cobble", 0.4)
	w.kit.path(Vector2(48, 4), "dirt_dark", Vector3(0, 0.012, 0))
	for i in 30:
		w.kit.prop("fence", Vector3(-23.2 + i * 1.6, 0, 12.8), {"yaw": 0.0})
	w.kit._solid_box(Vector3(48, 2, 0.4), Vector3(0, 1, 12.8))
	for cp in [Vector3(-8, 0, 10.5), Vector3(-7, 0, 11), Vector3(5, 0, 10.8), Vector3(16, 0, 10.2)]:
		w.kit.prop("crate", cp)
	var kinds := ["a", "dark", "c", "b", "dark"]
	var houses := [Vector3(-18, 0, -11), Vector3(-9, 0, -12), Vector3(0, 0, -11.5), Vector3(9, 0, -12), Vector3(18, 0, -11)]
	for i in houses.size():
		var hp: Vector3 = houses[i]
		w.kit.prop("house_%s" % kinds[i], hp, {"flip": i % 2 == 1})
		w.kit._solid_box(Vector3(6.0, 3.0, 2.4), hp + Vector3(0, 1.5, -0.6))
		w.kit._smoke(hp + Vector3(1.3 if i % 2 == 0 else -1.3, 5.2, 0))
	for lp in [Vector3(-12, 0, -3), Vector3(0, 0, 3.2), Vector3(12, 0, -3)]:
		w.kit.lamp(lp, Color("ffb060"), 1.6)
	for bp in [Vector3(-14, 0, 5), Vector3(-13.2, 0, 5.4), Vector3(10, 0, -6), Vector3(14, 0, 6)]:
		w.kit.prop("barrel", bp)
	w.kit._walls()
	var ev := w.kit.standee("evangelist", "Evangelist", Color("9fd8ff")); ev.position = Vector3(2, 0, 2)
	w._add_ent("evangelist", "Evangelist", ev.position, ev, "Talk", "talk", Callable(), true)
	var warp := w.kit.warp(Vector3(21, 0, 0))
	w._add_ent("warp", "A Shining Light", warp.position, warp, "Enter", "warp", Callable(), true)
	w.kit._edge_fade(Color("2a2832"))
	w.quests._add_secret("almanac", Vector3(-9.6, 0, 11.7), "An Old Almanac", "Pages of fortunes and festivals for the coming year. Not one word about the wrath to come. You read it and put it down: Manna +2.", {"manna": 2})
	w.quests._add_secret("drawing", Vector3(15.6, 0, 7.4), "A Child's Drawing", "A shining gate, drawn in charcoal by someone in this city who once hoped. You keep it: Charcoal Gate (Snapshot frame).", {"item": "Charcoal Gate frame"})
	w.quests._add_waymark(Vector3(-9.0, 0, 1.6), "Beware: Slothlings ahead. Step out of the red circle!", "Rook", 41)
	w.quests._add_waymark(Vector3(17.5, 0, 2.2), "Keep the light in your eye", "Tabitha", 112)
	w.folk._add_passerby([Vector3(-23, 0, -1), Vector3(-10, 0, -0.5), Vector3(6, 0, 0.8), Vector3(20, 0, 0)], "Ebenezer", "toward the Wicket Gate", [0, 4, 3], true)
	w.folk._add_passerby([Vector3(-23, 0, 2), Vector3(-4, 0, 1.5), Vector3(12, 0, -0.5), Vector3(20, 0, 0.5)], "Lumen", "toward the Wicket Gate", [2, 2, 1], true, 9.0)
	w.kit._weather_drizzle()

