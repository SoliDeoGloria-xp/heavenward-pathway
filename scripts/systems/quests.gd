class_name Quests
extends RefCounted
## Objective runner, secrets and Waymarks.

var w: World

func _init(world: World) -> void:
	w = world

var secret_ids: Array = []

var objectives: Array = []

var obj_idx := 0

var quest_mark: Label3D

var zone_fx: Node3D


# ------------------------------------------------------------------ objectives
func cur_obj() -> String:
	return objectives[obj_idx].id if obj_idx < objectives.size() else ""


func complete() -> void:
	if obj_idx < objectives.size() and objectives[obj_idx].has("xp"):
		var xv: Array = objectives[obj_idx].xp
		G.add_xp(int(xv[0]), int(xv[1]), w.map_id)
	obj_idx += 1
	if obj_idx < objectives.size() and objectives[obj_idx].has("chapter") and w.map_id == "eden":
		G.say("Chapter: %s" % objectives[obj_idx].chapter, G.INFO)
	if cur_obj() == "trees":
		w.show_ent("trees", true)
		var tw := w.create_tween().set_parallel(true)
		tw.tween_property(w.sun, "light_color", Color("ffcf9a"), 4.0)
		tw.tween_property(w.sun, "light_energy", 0.62, 4.0)
		tw.tween_property(w.env, "ambient_light_energy", 0.34, 4.0)
		w.post.set_shader_parameter("tint", Vector3(1.06, 0.98, 0.88))
	_update_quest()
	if obj_idx < objectives.size():
		G.say("Quest: " + objectives[obj_idx].text, G.INFO)
		w.hud.quest_toast(objectives[obj_idx].text)
	G.haptic(18)
	w.lessons._on_new_obj()


func _update_quest() -> void:
	if quest_mark:
		quest_mark.queue_free(); quest_mark = null
	if zone_fx:
		zone_fx.queue_free(); zone_fx = null
	if obj_idx >= objectives.size():
		w.hud.set_quest(""); return
	var o: Dictionary = objectives[obj_idx]
	w.hud.set_quest(o.text)
	if o.has("ent"):
		var e := w.ent(o.ent)
		if not e.is_empty() and not e.hidden:
			quest_mark = w.kit._label3d("!", e.pos + Vector3(0, 3.3 if o.ent in ["fig", "trees"] else 2.6, 0), Color("ffd400"), 90)
			quest_mark.outline_modulate = Color("3a2a00")
	if o.has("zone"):
		zone_fx = Node3D.new(); w.add_child(zone_fx); zone_fx.position = o.zone
		var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/glow.png"); g.pixel_size = 0.07; g.rotation_degrees.x = -90; g.position.y = 0.05; g.shaded = false
		zone_fx.add_child(g)
		var p := CPUParticles3D.new(); p.amount = 16; p.lifetime = 2.0; p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 1.0
		p.direction = Vector3.UP; p.spread = 10; p.initial_velocity_min = 0.6; p.initial_velocity_max = 1.0; p.gravity = Vector3.ZERO
		var q := QuadMesh.new(); q.size = Vector2(0.15, 0.15)
		var m := StandardMaterial3D.new(); m.albedo_texture = G.tex("res://assets/fx/mote.png"); m.albedo_color = Color("fff3c0"); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = m; p.mesh = q; zone_fx.add_child(p)


func quest_target() -> Variant:
	if obj_idx >= objectives.size():
		return null
	var o: Dictionary = objectives[obj_idx]
	if o.has("ent") and not w.ent(o.ent).is_empty() and not w.ent(o.ent).hidden:
		return w.ent(o.ent)
	if o.has("zone"):
		return o.zone
	return null


func auto_path_quest() -> void:
	var q = quest_target()
	if q is Dictionary:
		w.pending = q; w.move_target = w._approach_point(q.pos)
		G.say("Auto-path: %s" % q.name, G.SYS)
	elif q is Vector3:
		w.move_target = q; w.pending = null
	elif cur_obj() in ["fight", "boss"]:
		w.combat._attack_pressed()


# ======================================================================
# World model (GDD v0.3): Way traces, the House, the Muster
# ======================================================================

# ------------------------------------------------------------------ secrets on the Way
func _add_secret(id: String, pos: Vector3, title: String, text: String, reward: Dictionary) -> void:
	secret_ids.append(id)
	if G.secret_found(w.map_id, id):
		return
	var n := Node3D.new(); n.position = pos; w.add_child(n)
	var g := Sprite3D.new(); g.texture = G.tex("res://assets/fx/star.png"); g.pixel_size = 0.004; g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.shaded = false; g.transparent = true; g.modulate = Color(1, 0.97, 0.8, 0.0); g.position.y = 0.55; n.add_child(g)
	n.set_meta("glint", g)
	var e := w._add_ent("secret_" + id, "Something glints", pos, n, "Search", "eye", _find_secret.bind(id, title, text, reward))
	e["kind"] = "secret"


func _find_secret(id: String, title: String, text: String, reward: Dictionary) -> void:
	var e := w.ent("secret_" + id)
	if e.is_empty() or e.hidden:
		return
	w.show_ent("secret_" + id, false)
	var found: Array = G.secrets.get(w.map_id, [])
	found.append(id); G.secrets[w.map_id] = found
	w.kit._sparkle(e.pos + Vector3(0, 0.6, 0), Color("fff2b0"))
	Fx.ring(w, e.pos, Color(1, 0.95, 0.7), 2.0, 0.5)
	if reward.has("item"):
		G.bag_add(reward.item, 1); w.kit._item_pop("scroll")
	if reward.has("xp"):
		G.add_xp(int(reward.xp), int(reward.get("jxp", -1)), w.map_id)
	G.say("Secret found (%d/%d): %s" % [found.size(), secret_ids.size(), title], G.INFO)
	w.hud.secret_card(title, text, found.size(), secret_ids.size())
	G.haptic(30)


func secrets_text() -> String:
	if secret_ids.is_empty():
		return ""
	return "✦ %d/%d" % [G.secrets.get(w.map_id, []).size(), secret_ids.size()]


# ------------------------------------------------------------------ Waymarks (after the pillar at the By-path stile)
var waymark_phrases := ["Beware: danger ahead", "Rest here", "Look closely here", "Keep to the narrow way", "Well done, pilgrim!",
	"Remember [BSB: Psalm 46:1]", "Read slowly [BSB: Psalm 119:105]"]


func _add_waymark(pos: Vector3, phrase: String, author: String, thanks: int) -> Dictionary:
	var n := Node3D.new(); n.position = pos; w.add_child(n)
	var wood := w.kit._mat("res://assets/tiles/bark.png", Vector2(1, 1), true, Color(0.85, 0.75, 0.6))
	var post_m := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.12, 1.2, 0.12); post_m.mesh = pb; post_m.material_override = wood; post_m.position.y = 0.6; n.add_child(post_m)
	var plank := MeshInstance3D.new(); var pk := BoxMesh.new(); pk.size = Vector3(0.7, 0.32, 0.06); plank.mesh = pk; plank.material_override = wood; plank.position.y = 1.08; n.add_child(plank)
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color("9ad0ff"); stone.emission_enabled = true; stone.emission = Color("6ab8ff"); stone.emission_energy_multiplier = 1.2
	var gem := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.14; gem.mesh = sm; gem.material_override = stone; gem.position = Vector3(0, 1.32, 0); n.add_child(gem)
	var wm := {"phrase": phrase, "author": author, "thanks": thanks, "thanked": false, "mine": author == G.pname}
	var e := w._add_ent("waymark_%d" % w.ents.size(), "Waymark", pos, n, "Read", "scroll", func(): w.hud.waymark_read(wm))
	e["kind"] = "waymark"
	return wm


func place_waymark(phrase: String) -> void:
	var p := w.player.position + w.pact.facing.normalized() * 1.3
	p.y = 0.0
	_add_waymark(p, phrase, G.pname, 0)
	G.my_waymarks.append({"map": w.map_id, "pos": p, "phrase": phrase})
	w.kit._sparkle(p + Vector3(0, 1.2, 0), Color("bfe4ff"))
	G.say("You raised a Waymark: \"%s\". Pilgrims who pass this way will see it." % phrase, G.INFO)


func _glint_tick() -> void:
	for e in w.ents:
		if e.get("kind", "") != "secret" or e.hidden or e.node == null:
			continue
		var g: Sprite3D = e.node.get_meta("glint")
		var d := Vector2(w.player.position.x - e.pos.x, w.player.position.z - e.pos.z).length()
		var near := clampf(1.0 - (d - 2.0) / 6.0, 0.0, 1.0)
		g.modulate.a = near * (0.55 + 0.45 * sin(w.t * 4.0 + e.pos.x))
		g.rotation.z = w.t * 0.8
