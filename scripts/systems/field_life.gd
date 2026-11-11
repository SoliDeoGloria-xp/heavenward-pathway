class_name FieldLife
extends RefCounted
## What makes a field more than a spawn table (0.6.0, phase 5):
##   a named wandering foe that comes after a while and is marked on the minimap
##   things to gather, which grow back
##   Faithful, who walks and fights beside the pilgrim in the fields once he has been met
##   day and night
## A field's map data names its wanderer ("wanderer": {mob, name, lv}) and its gathering spots
## ("gather": [{id, at, name, item, prop}]).

const WANDER_AFTER_S := 40.0       # the wanderer comes this long after the pilgrim enters
const WANDER_BACK_S := 480.0       # and returns this long after it is overcome
const WANDER_ROAM_S := 9.0
const WANDER_COIN_PER_LV := 10
const GATHER_BACK_S := 180.0
const COMPANION_FLAG := "done_shadow"   # Faithful is met at the far end of the Valley of the Shadow
const COMPANION_HIT_S := 1.8
const COMPANION_SHARE := 0.4       # of the pilgrim's own Attack
const COMPANION_REACH := 2.2
const DAY_S := 2880.0              # one day and night: 48 minutes
const NIGHT_FROM := 0.62           # the part of that time when it is night
const DUSK := 0.06
const NIGHT_SUN := 0.55            # how much of the sun, and of the ambient light, night takes away
const NIGHT_AMB := 0.3
const NIGHT_COLOR := Color("7080c0")

var w: World
var wander_in := INF
var wanderer: Dictionary = {}
var roam_t := 0.0
var companion: SpriteActor
var hit_t := 0.0
var slow_t := 0.0
var night := -1.0
var fixed_day := false

func _init(world: World) -> void:
	w = world
	fixed_day = OS.get_cmdline_user_args().has("--autotest")   # pictures must not depend on the clock

func begin() -> void:
	_daylight()
	if w.kind != "field":
		return
	var wd: Dictionary = w.def.get("wanderer", {})
	if not wd.is_empty() and Time.get_unix_time_from_system() - float(G.wanderers.get(w.map_id, 0.0)) >= WANDER_BACK_S:
		wander_in = WANDER_AFTER_S
	for g in w.def.get("gather", []):
		_gather_spot(g)
	w.combat.mob_slain.connect(_on_slain)
	if G.flags.has(COMPANION_FLAG):
		companion = w.kit.standee("faithful", "Faithful", Color("9ff5a0"))
		companion.position = w.player.position + Vector3(-1.4, 0, 1.0)
		G.say("Faithful walks with you here.", G.INFO)

func tick(delta: float) -> void:
	slow_t -= delta
	if slow_t <= 0.0:
		slow_t = 4.0
		_daylight(); _regrow()
	if w.kind != "field":
		return
	if wander_in < INF:
		wander_in -= delta
		if wander_in <= 0.0:
			_wanderer_comes()
	if not wanderer.is_empty() and wanderer.alive and not wanderer.aggro:
		roam_t -= delta
		if roam_t <= 0.0:   # it does not keep to one corner
			roam_t = WANDER_ROAM_S
			var b: Rect2 = w.bounds.grow(-6.0)
			wanderer.home = Vector3(randf_range(b.position.x, b.end.x), 0, randf_range(b.position.y, b.end.y))
	if companion != null:
		_companion(delta)

# ------------------------------------------------------------------ the wandering foe
func _wanderer_comes() -> void:
	wander_in = INF
	var wd: Dictionary = w.def.wanderer
	var b: Rect2 = w.bounds.grow(-8.0)
	var at := Vector3(b.end.x, 0, b.position.y) if w.player.position.x < 0 else Vector3(b.position.x, 0, b.position.y)
	wanderer = w.combat._spawn_mob(String(wd.mob), at, {"lv": [wd.lv, wd.lv], "greater": true, "aggro": "aggressive", "respawn": Combat.NO_RESPAWN}, int(wd.lv))
	wanderer.name = String(wd.name); wanderer["wanderer"] = true
	w.combat._nameplate(wanderer)
	G.say("%s is abroad in this field (marked on the map)." % String(wd.name), G.WARN)

func _on_slain(m: Dictionary) -> void:
	if not m.get("wanderer", false):
		return
	G.wanderers[w.map_id] = Time.get_unix_time_from_system()
	G.wanderers_down[w.map_id] = int(G.wanderers_down.get(w.map_id, 0)) + 1
	var coin: int = WANDER_COIN_PER_LV * int(m.level)
	G.denarii += coin
	G.say("%s is overcome. Denarii +%d." % [m.name, coin], G.INFO)
	wanderer = {}

# ------------------------------------------------------------------ gathering
func _gather_spot(g: Dictionary) -> void:
	var at := World.v3(g.at)
	var n: Node3D = w.kit.prop(String(g.prop), at)
	var id := "gather_" + String(g.id)
	w._add_ent(id, String(g.name), at, n, "Gather", "hand", _gather.bind(g), not _grown(g))
	w.ent(id)["kind"] = "gather"

func _key(g: Dictionary) -> String:
	return "%s:%s" % [w.map_id, String(g.id)]

func _grown(g: Dictionary) -> bool:
	return Time.get_unix_time_from_system() - float(G.gathered.get(_key(g), 0.0)) >= GATHER_BACK_S

func _gather(g: Dictionary) -> void:
	G.gathered[_key(g)] = Time.get_unix_time_from_system()
	G.bag_add(String(g.item), 1)
	w.show_ent("gather_" + String(g.id), false)
	w.kit._sparkle(World.v3(g.at) + Vector3(0, 1.0, 0), Color("fff0a0"))
	G.sfx("drop")
	G.say("You gathered %s. It will be here again in a few minutes." % String(g.item), G.INFO)

func _regrow() -> void:
	for g in w.def.get("gather", []):
		var e: Dictionary = w.ent("gather_" + String(g.id))
		if not e.is_empty() and e.hidden and _grown(g):
			w.show_ent(e.id, true)

# ------------------------------------------------------------------ Faithful
func _companion(delta: float) -> void:
	var t = w.combat.target
	var fight: bool = t != null and t.alive
	var goal: Vector3 = (t.actor.position + Vector3(1.2, 0, 0.6)) if fight else (w.player.position + Vector3(-1.4, 0, 1.0))
	var to := goal - companion.position; to.y = 0
	if to.length() > 0.35:
		companion.position += to.normalized() * minf(to.length(), 4.4 * delta)
		companion.facing = to.normalized()
	hit_t -= delta
	if fight and hit_t <= 0.0 and companion.position.distance_to(t.actor.position) < COMPANION_REACH:
		hit_t = COMPANION_HIT_S
		companion.squash(0.08)
		w.combat.hit_mob(t, maxi(1, int(round(float(G.d.atk) * COMPANION_SHARE))), false, false)

# ------------------------------------------------------------------ day and night
static func night_at(unix: float) -> float:
	var t := fmod(unix, DAY_S) / DAY_S
	return clampf(minf((t - NIGHT_FROM) / DUSK, (1.0 - t) / DUSK), 0.0, 1.0)

func _daylight() -> void:
	if not w.kind in ["field", "town"] or w.sun == null:
		return
	var n := 0.0 if fixed_day else night_at(Time.get_unix_time_from_system())
	if absf(n - night) < 0.02:
		return
	if night >= 0.0 and n >= 0.5 and night < 0.5:
		G.say("Night falls.", G.SYS)
	elif night >= 0.5 and n < 0.5:
		G.say("Morning comes.", G.SYS)
	night = n
	w.sun.light_energy = float(w.info("sun_e")) * (1.0 - NIGHT_SUN * n)
	w.env.ambient_light_energy = float(w.info("amb_e")) * (1.0 - NIGHT_AMB * n)
	w.env.ambient_light_color = (w.info("amb") as Color).lerp(NIGHT_COLOR, 0.5 * n)
