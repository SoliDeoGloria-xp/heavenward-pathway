extends RefCounted
## City of Destruction: geometry and Evangelist.

var w: World

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ City of Destruction
func build() -> void:
	w.bounds = Rect2(-24, -14, 48, 28)
	w.kit._plane(Vector2(120, 100), w.kit._mat("res://assets/tiles/cobble.png", Vector2(60, 50), false, Color(0.92, 0.9, 0.92)), Vector3.ZERO)
	w.kit._plane(Vector2(48, 4), w.kit._mat("res://assets/tiles/dirt.png", Vector2(24, 2), false, Color(0.75, 0.72, 0.7)), Vector3(0, 0.01, 0))
	var wall := w.kit._mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(0.8, 0.76, 0.74))
	var roof := w.kit._mat("res://assets/tiles/roof.png", Vector2(0.6, 0.6), true, Color(0.75, 0.7, 0.72))
	var houses := [Vector3(-18, 0, -11), Vector3(-9, 0, -12), Vector3(0, 0, -11.5), Vector3(9, 0, -12), Vector3(18, 0, -11)]
	var fence := w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.55, 0.45, 0.4))
	for i in 12:
		var fx := -22.0 + i * 4.0
		w.kit._box(Vector3(3.6, 0.12, 0.12), fence, Vector3(fx, 0.8, 12.8), false)
		w.kit._box(Vector3(3.6, 0.12, 0.12), fence, Vector3(fx, 0.45, 12.8), false)
		w.kit._box(Vector3(0.16, 1.0, 0.16), fence, Vector3(fx - 1.8, 0.5, 12.8), false)
	w.kit._solid_box(Vector3(48, 2, 0.4), Vector3(0, 1, 12.8))
	for cp in [Vector3(-8, 0, 10.5), Vector3(-7, 0, 11), Vector3(5, 0, 10.8), Vector3(16, 0, 10.2)]:
		w.kit._box(Vector3(1.0, 0.9, 1.0), w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.75, 0.62, 0.48)), cp + Vector3(0, 0.45, 0))
	for hp in houses:
		var hw := randf_range(6.0, 7.5)
		w.kit._box(Vector3(hw, 3.6, 5), wall, hp + Vector3(0, 1.8, 0))
		var pr := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(hw + 0.8, 2.2, 5.6); pr.mesh = pm; pr.material_override = roof
		pr.position = hp + Vector3(0, 4.7, 0); w.add_child(pr)
		var win := StandardMaterial3D.new(); win.albedo_color = Color("e8b048"); win.emission_enabled = true; win.emission = Color("e8a040"); win.emission_energy_multiplier = 0.8
		var zf := 2.52 if hp.z < 0 else -2.52
		w.kit._box(Vector3(0.9, 0.8, 0.05), win, hp + Vector3(-hw * 0.25, 2.2, zf), false)
		w.kit._box(Vector3(1.0, 1.8, 0.06), w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.5, 0.4, 0.35)), hp + Vector3(hw * 0.15, 0.9, zf), false)
		w.kit._smoke(hp + Vector3(hw * 0.3, 5.6, 0))
	for lp in [Vector3(-12, 0, -3), Vector3(0, 0, 3.2), Vector3(12, 0, -3)]:
		w.kit._box(Vector3(0.15, 3, 0.15), w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.3, 0.3, 0.32)), lp + Vector3(0, 1.5, 0))
		var lamp := OmniLight3D.new(); lamp.light_color = Color("ffb060"); lamp.light_energy = 1.6; lamp.omni_range = 5.5; lamp.position = lp + Vector3(0, 3.0, 0); w.add_child(lamp)
		w.kit.lamps.append(lamp)
		var halo := Sprite3D.new(); halo.texture = G.tex("res://assets/fx/glow.png"); halo.pixel_size = 0.03; halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.shaded = false; halo.modulate = Color(1, 0.75, 0.4, 0.7); halo.position = lp + Vector3(0, 3.05, 0); w.add_child(halo)
		var lm := StandardMaterial3D.new(); lm.albedo_color = Color("ffd38a"); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		w.kit._sphere(0.2, lm, lp + Vector3(0, 3.05, 0))
	for bp in [Vector3(-14, 0, 5), Vector3(-13.2, 0, 5.4), Vector3(10, 0, -6), Vector3(14, 0, 6)]:
		var bm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.42; cm.bottom_radius = 0.42; cm.height = 1.0
		bm.mesh = cm; bm.material_override = w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true); bm.position = bp + Vector3(0, 0.5, 0); w.add_child(bm)
		w.kit._solid_cyl(0.45, bp)
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

