class_name Folk
extends RefCounted
## Other pilgrims: passers-by on the Way and the people of a House.

var w: World
const FOLLOW_FAR := 3.2
const FOLLOW_NEAR := 2.4

func _init(world: World) -> void:
	w = world

var others: Array = []           # other pilgrims: {actor, path, i, speed, ghost, fade, chat_t, kind}


func _add_passerby(path: Array, nm: String, dest: String, look: Array, ghost: bool, delay: float = 0.0) -> void:
	var a := w.kit._pilgrim_actor(look, "%s · %s" % [nm, dest], Color(0.85, 0.92, 1.0, 0.75), ghost)
	a.position = path[0]
	if a.name_lbl:
		a.name_lbl.font_size = 26
	a.visible = delay <= 0.0
	others.append({"actor": a, "path": path, "i": 1, "speed": 2.3, "ghost": ghost, "wait": delay, "kind": "passer"})


func _others_tick(delta: float) -> void:
	for o in others:
		var a: SpriteActor = o.actor
		if o.wait > 0.0:
			o.wait -= delta
			if o.wait <= 0.0:
				a.visible = true; a.position = o.path[0]; o.i = 1
				if o.kind == "passer":
					w.kit._fade_actor(a, 0.0, 1.0)
			else:
				if o.kind == "house" and a.anim == "walk":
					a.play("sit" if o.get("sitter", false) else "idle")
				_house_chat_tick(o, delta)
				continue
		var goal: Vector3 = o.path[o.i]
		var to := goal - a.position; to.y = 0
		if to.length() > 0.2:
			a.position += to.normalized() * o.speed * delta
			a.facing = to.normalized(); a.play("walk")
		else:
			if o.kind == "passer":
				o.i += 1
				if o.i >= o.path.size():
					w.kit._fade_actor(a, 1.0, 0.0)
					o.wait = randf_range(8.0, 14.0)
			else:
				o.path = [a.position, _house_spot()]
				o.i = 1
				o.wait = randf_range(3.0, 9.0)
		_house_chat_tick(o, delta)


# ------------------------------------------------------------------ the House: Palace Beautiful
const HOUSE_FOLK := [
	["Lumen", [2, 2, 1]], ["Rook", [0, 1, 5]], ["Tabitha", [1, 3, 2]], ["Ebenezer", [0, 4, 3]], ["Wren", [1, 0, 0]],
	["Psalter", [2, 5, 4]], ["Marigold", [1, 2, 2]], ["Honestly", [0, 0, 1]], ["Faithwalker", [2, 1, 0]]]

const HOUSE_CHAT := ["Grace and peace!", "LF 2 for the Lions' Gate (Normal)", "Anyone reading Psalm 23 in the reading room?",
	"Thanks for the Help in the Slough earlier!", "First time at the House. Where is the armory?", "Armory is the west door.",
	"Muster was quick: a Steward filled our last place.", "Waymark at the Hill: rest at the Arbour, but don't sleep there!",
	"Heading out to the Valley meadows later, anyone?", "Welcome, new pilgrim!"]


func _house_spot() -> Vector3:
	return Vector3(randf_range(-11, 11), 0, randf_range(-6, 6))


func _house_chat_tick(o: Dictionary, delta: float) -> void:
	if o.kind != "house":
		return
	o.chat_t -= delta
	if o.chat_t <= 0.0:
		o.chat_t = randf_range(9.0, 20.0)
		var line: String = HOUSE_CHAT[randi() % HOUSE_CHAT.size()]
		G.say("[Local] %s: %s" % [o.name, line], G.CHAT)
		w.kit._bubble(o.actor, line)

## Companions on the road (entities with "follow" in map data) keep a few steps behind the player.
func followers_tick(delta: float) -> void:
	for e in w.ents:
		if not e.get("follow", false) or e.hidden or w.cinema:
			continue
		var a: SpriteActor = e.node
		var to := w.player.position - a.position; to.y = 0
		if to.length() > FOLLOW_FAR:
			a.position += to.normalized() * minf(World.SPEED * 0.95 * delta, to.length() - FOLLOW_NEAR)
			a.facing = to.normalized(); a.play("walk")
		else:
			a.play("idle")
		e.pos = a.position
