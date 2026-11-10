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
	var ev := w.kit._sprite_npc("res://assets/sprites/npc_evangelist.png", 2, 5, true, Vector3(2, 0, 2), "Evangelist", Color("9fd8ff"))
	w._add_ent("evangelist", "Evangelist", ev.position, ev, "Talk", "talk", _act_evangelist, true)
	var warp := Node3D.new(); warp.position = Vector3(21, 0, 0); w.add_child(warp)
	var ws := Sprite3D.new(); ws.texture = G.tex("res://assets/fx/warp.png"); ws.pixel_size = 0.014; ws.rotation_degrees.x = -90; ws.position.y = 0.06
	ws.shaded = false; ws.transparent = true; warp.add_child(ws); warp.set_meta("spin", ws)
	var beam := Sprite3D.new(); beam.texture = G.tex("res://assets/fx/glow.png"); beam.pixel_size = 0.09; beam.scale = Vector3(1, 3, 1)
	beam.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y; beam.shaded = false; beam.position.y = 3.0; beam.modulate = Color(1, 0.95, 0.75, 0.75); warp.add_child(beam)
	var wl := OmniLight3D.new(); wl.light_color = Color("fff0c0"); wl.light_energy = 3.0; wl.omni_range = 8.0; wl.position.y = 2.0; warp.add_child(wl)
	w._add_ent("warp", "A Shining Light", warp.position, warp, "Enter", "warp", w._finish, true)
	w.quests.objectives = [
		{"id": "fight", "text": "Overcome the Slothlings (0/3)"},
		{"id": "talk", "text": "Speak with Evangelist", "ent": "evangelist"},
		{"id": "light", "text": "Follow the light toward the Wicket Gate", "ent": "warp", "zone": Vector3(21, 0, 0)}]
	for i in 6:
		w.combat._spawn_mob(Vector3(-4.0 + i * 3.8, 0, randf_range(-5, 6)))
	w.kit._edge_fade(Color("2a2832"))
	w.quests._add_secret("almanac", Vector3(-9.6, 0, 11.7), "An Old Almanac", "Pages of fortunes and festivals for the coming year. Not one word about the wrath to come.", {"xp": 15})
	w.quests._add_secret("drawing", Vector3(15.6, 0, 7.4), "A Child's Drawing", "A shining gate, drawn in charcoal by someone in this city who once hoped. You keep it: Charcoal Gate (Snapshot frame).", {"item": "Charcoal Gate frame"})
	w.quests._add_waymark(Vector3(-9.0, 0, 1.6), "Beware: Slothlings ahead. Step out of the red circle!", "Rook", 41)
	w.quests._add_waymark(Vector3(17.5, 0, 2.2), "Keep the light in your eye", "Tabitha", 112)
	w.folk._add_passerby([Vector3(-23, 0, -1), Vector3(-10, 0, -0.5), Vector3(6, 0, 0.8), Vector3(20, 0, 0)], "Ebenezer", "toward the Wicket Gate", [0, 4, 3], true)
	w.folk._add_passerby([Vector3(-23, 0, 2), Vector3(-4, 0, 1.5), Vector3(12, 0, -0.5), Vector3(20, 0, 0.5)], "Lumen", "toward the Wicket Gate", [2, 2, 1], true, 9.0)
	w.kit._weather_drizzle()
	Fx.particles(warp, warp.global_position + Vector3(0, 0.2, 0), {"amount": 24, "life": 2.2, "one_shot": false, "explode": 0.0, "sphere": 1.2, "vmin": 0.8, "vmax": 1.6, "spread": 8.0, "gravity": Vector3.ZERO, "color": Color("fff0c0"), "size": 0.14, "local": true})
	var ws2 := Sprite3D.new(); ws2.texture = G.tex("res://assets/fx/warp.png"); ws2.pixel_size = 0.011; ws2.rotation_degrees.x = -90; ws2.position.y = 0.08
	ws2.shaded = false; ws2.transparent = true; ws2.modulate = Color(1, 0.95, 0.7, 0.8); warp.add_child(ws2); warp.set_meta("spin2", ws2)
	w.kit.holy_lights.append(wl)


# ------------------------------------------------------------------ Evangelist and ending
func after_evangelist() -> void:
	G.bag_add("Parchment Roll", 1)
	G.say("You got Parchment Roll.", G.INFO)
	w.show_ent("warp", true)
	w.snapshot_unlocked = true
	w.quests.complete()
	w.hud.refresh()
	G.say("New: Snapshot mode (camera button by the minimap).", G.INFO)


func _act_evangelist() -> void:
	w.hud.evangelist_dialog()


func _evangelist_arrives() -> void:
	w.show_ent("evangelist", true)
	G.say("Evangelist approaches you.", G.NPC)
	w.quests.complete()
