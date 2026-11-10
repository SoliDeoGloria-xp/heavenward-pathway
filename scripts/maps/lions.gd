extends RefCounted
## The Lions' Gate Muster arena.

var w: World

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ the Muster: Giant Grim at the Lions' Gate
func build() -> void:
	w.bounds = Rect2(-9, -12, 18, 24)
	w.kit._plane(Vector2(120, 100), w.kit._mat("res://assets/tiles/grass.png", Vector2(60, 50), false, Color(0.78, 0.76, 0.62)), Vector3.ZERO)
	w.kit._plane(Vector2(8, 40), w.kit._mat("res://assets/tiles/dirt.png", Vector2(4, 20), false, Color(0.9, 0.82, 0.68)), Vector3(0, 0.01, 0))
	var wallm := w.kit._mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(0.82, 0.78, 0.72))
	for x in [-10.0, 10.0]:
		w.kit._box(Vector3(1.2, 2.2, 30), wallm, Vector3(x, 1.1, 0))
	# the chained lions
	var lionm := w.kit._mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.62, 0.55, 0.45))
	var mane := w.kit._mat("res://assets/tiles/wall.png", Vector2(1, 1), true, Color(0.5, 0.4, 0.3))
	var chainm := StandardMaterial3D.new(); chainm.albedo_color = Color(0.3, 0.3, 0.34); chainm.metallic = 0.6
	for sx in [-1.0, 1.0]:
		var lp := Vector3(sx * 6.4, 0, -5.0)
		w.kit._box(Vector3(2.2, 1.1, 1.0), lionm, lp + Vector3(0, 0.75, 0))
		w.kit._sphere(0.75, mane, lp + Vector3(-sx * 1.1, 1.45, 0))
		w.kit._sphere(0.45, lionm, lp + Vector3(-sx * 1.5, 1.4, 0))
		w.kit._box(Vector3(2.4, 0.08, 0.08), chainm, lp + Vector3(sx * 1.9, 1.2, 0), false)
	# the palace gate beyond
	w.kit._box(Vector3(9, 5, 1.2), w.kit._mat("res://assets/tiles/wall.png", Vector2(0.5, 0.5), true, Color(1.0, 0.97, 0.9)), Vector3(0, 2.5, -13.5))
	var gl := OmniLight3D.new(); gl.light_color = Color("ffe9b0"); gl.light_energy = 2.4; gl.omni_range = 8.0; gl.position = Vector3(0, 3, -12); w.add_child(gl); w.kit.holy_lights.append(gl)
	w.kit._walls()
	w.kit._edge_fade(Color("342c24"))
	# the company
	var party: Array = G.muster_party
	if party.is_empty():
		party = [{"name": "Lumen", "role": "support", "ai": false, "look": [2, 2, 1]}, {"name": "Rook", "role": "defender", "ai": false, "look": [0, 1, 5]},
			{"name": "Steward of the House", "role": "damage", "ai": true, "look": [0, 4, 5]}]
	var k := 0
	for m in party:
		var md: Dictionary = m
		var label: String = md.name + (" (AI)" if md.ai else "")
		var a := w.kit._pilgrim_actor(md.look, label, Color("9ff5a0") if not md.ai else Color("cfe8cf"), false)
		a.position = w.info("start") + Vector3(-2.0 + k * 2.0, 0, 1.2)
		w.combat.allies.append({"actor": a, "name": md.name, "role": md.role, "ai": md.ai, "next": 1.0 + k * 0.4, "slot": k, "heal_t": 4.0})
		k += 1
	w.combat.spawn_boss("grim", Vector3(0, 0, -2.5))
	var warp := w.kit.warp(Vector3(0, 0, -10.5))
	w._add_ent("warp", "Return to the House", warp.position, warp, "Enter", "warp", Callable(), true)
