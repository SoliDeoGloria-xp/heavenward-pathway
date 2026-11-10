class_name Combat
extends RefCounted
## Mobs, the player's attacks and skills, KO and Weariness, field bosses and the Muster boss
## with AI companions. Mob and skill numbers come from data (mobs.json, skills.json, progression.json).

signal mob_slain(mob: Dictionary)

const AGGRO_RANGE := 6.0
const LEASH_RANGE := 14.0
const MOB_REACH := 1.4
const TELEGRAPH_S := 0.6
const MOB_SWING_S := 2.0
const GCD := 1.0
const SKILL_BUFFER_S := 0.3          # a press this close to the end of the global cooldown is queued
const ZEAL_ON_HIT := 3.0
const WEARY_S := 25.0
const DROP_CHANCE := 0.6
const AOE_FALLBACK_RANGE := 10.0
const BOSS_SHADOW := 0.7
const PLACEHOLDER_PIXEL := 0.04
const MOB_ATTACK_S := 0.5
const NO_RESPAWN := -99.0
const BOSS_NAME_SIZE := 36
const MOB_SHEET := {"hframes": 7, "vframes": 1, "rows": false, "anims": {"idle": [0, 1], "walk": [2, 3], "attack": [2, 3], "hurt": [4], "die": [5, 6]}, "fps": {"idle": 2.0, "walk": 4.0, "die": 3.0}}

var w: World
var mobs: Array = []             # {id, name, level, actor, hp, max, atk, xp, alive, home, aggro, ...}
var boss = null                  # the live boss mob dict (field boss or Muster boss)
var boss_atk_t := 0.0
var boss_count := 0
var boss_enraged := false
var allies: Array = []           # Muster party: {actor, name, role, ai, next, slot}
var target = null                # mob dict being attacked
var dead := false
var next_atk := 0.0
var cd := {}                     # skill id -> seconds left
var gcd := 0.0
var queued_skill := ""
var slain := 0
var used_steps := false
var buffs := {}                  # stat -> {"add": float, "until": float}
var regen_until := 0.0           # Prayer of Rest and similar: bonus Zeal per second until this time
var regen_rate := 0.0

func _init(world: World) -> void:
	w = world

# ------------------------------------------------------------------ timers and derived numbers
func tick_cooldowns(delta: float) -> void:
	gcd = maxf(0.0, gcd - delta)
	for k in cd.keys():
		cd[k] = maxf(0.0, cd[k] - delta)

func buff(stat: String) -> float:
	var b: Dictionary = buffs.get(stat, {})
	return float(b.add) if not b.is_empty() and w.t < float(b.until) else 0.0

func zeal_regen_bonus() -> float:
	return regen_rate if w.t < regen_until else 0.0

func ready(id: String) -> bool:
	return G.has_skill(id) and cd.get(id, 0.0) <= 0.0 and gcd <= 0.0 and G.zeal >= int(G.SKILL_INFO[id].zeal)

func fire_queued() -> void:
	if queued_skill != "" and gcd <= 0.0:
		var qs := queued_skill; queued_skill = ""
		skill(qs)

## Basic attack from attributes: Fortitude (damage), Diligence (speed), Sobriety (misses), Hope (crits).
func basic_attack() -> void:
	if w.t <= next_atk or gcd > 0.0:
		return
	next_atk = w.t + float(G.d.interval) / (1.0 + buff("haste"))
	w.pact.play_once("attack", 0.32)
	var crit := randf() < float(G.d.crit) + buff("crit")
	var dmg := int(G.d.atk) + randi_range(-2, 2)
	hit_mob(target, dmg * (2 if crit else 1), crit, randf() < float(G.d.miss))

# ------------------------------------------------------------------ mobs
## Spawn tables live in the map's JSON. A group with "at" appears when that objective starts;
## groups without it are there from the beginning (group id "").
func spawn_group(objective_id: String) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(w.map_id + objective_id)
	for sp in w.def.get("spawns", []):
		if String(sp.get("at", "")) != objective_id:
			continue
		var a: Array = sp.area
		for i in int(sp.count):
			_spawn_mob(String(sp.mob), Vector3(rng.randf_range(a[0], a[0] + a[2]), 0, rng.randf_range(a[1], a[1] + a[3])))

## Sheets imported by tools/import_sheets.py are described in data/sprites.json; a mob's "size"
## is its standing height in world units. The old generated placeholder sheet is the fallback.
func _mob_actor(md: Dictionary, scale: float, pos: Vector3, shadow: float = 1.0) -> SpriteActor:
	var a := SpriteActor.new(); w.add_child(a); a.position = pos
	var sheet: Dictionary = G.data("sprites").get(md.sprite, {})
	var cfg := MOB_SHEET.duplicate(true)
	if sheet.is_empty():
		cfg["tex"] = G.tex("res://assets/sprites/mob_slothling.png"); cfg["pixel"] = PLACEHOLDER_PIXEL * scale
	else:
		cfg = {"tex": G.tex(sheet.tex), "hframes": int(sheet.hframes), "vframes": int(sheet.vframes), "rows": false, "anims": sheet.anims, "fps": sheet.fps,
			"pixel": float(md.size) * scale / float(sheet.height)}
	cfg["shadow"] = shadow * float(md.get("size", 1.0))
	a.setup(cfg, md.name, Color("ffe0e0"))
	a.set_tint(Color(String(md.tint)) * G.sprite_tint)
	return a

func _spawn_mob(id: String, pos: Vector3) -> Dictionary:
	var md: Dictionary = G.MOBS[id]
	var rules: Dictionary = G.PROG["mob"]
	var greater: bool = md.get("greater", false)
	var lv := int(md.level)
	var a := _mob_actor(md, float(rules.greater_scale) if greater else 1.0, pos)
	var hp := (float(rules.hp_base) + float(rules.hp_per_lv) * lv) * (float(rules.greater_hp) if greater else 1.0)
	var atk := (float(rules.atk_base) + float(rules.atk_per_lv) * lv) * (float(rules.greater_atk) if greater else 1.0)
	var bars := _hp_bars(a)
	var m := {"id": id, "name": md.name, "level": lv, "greater": greater, "drop": md.get("drop", ""), "actor": a, "hp": hp, "max": hp, "atk": atk,
		"xp": mob_xp(md), "alive": true, "next": 0.0, "home": pos, "wander": pos, "wander_t": randf_range(1, 4),
		"bg": bars[0], "fg": bars[1], "trail": bars[2], "aggro": false, "respawn": 0.0, "tele": false, "tele_pos": Vector3.ZERO, "trail_v": 1.0, "was_aggro": false}
	mobs.append(m)
	return m

## Common monster XP = 3 + level; Greater x4; a boss pays its bonus on top of its objective (150-250 in all).
static func mob_xp(md: Dictionary) -> int:
	var rules: Dictionary = G.PROG["mob_xp"]
	if md.get("boss", false):
		return int(md.get("xp_bonus", 0))
	return (int(rules.base) + int(rules.per_level) * int(md.level)) * (int(rules.greater_mult) if md.get("greater", false) else 1)

func _hp_bars(a: SpriteActor) -> Array:
	var out: Array = []
	for spec in [[Vector2(0.9, 0.09), Color(0.1, 0.1, 0.12), 4], [Vector2(0.86, 0.06), Color("e83b3b"), 5], [Vector2(0.86, 0.06), Color(1, 1, 1, 0.9), 4]]:
		var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = spec[0]; mi.mesh = q
		var mat := StandardMaterial3D.new(); mat.albedo_color = spec[1]; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mat.no_depth_test = true; mat.render_priority = spec[2]
		mi.material_override = mat
		out.append(mi)
	out[0].position.y = -0.45; out[0].visible = false; a.add_child(out[0])
	out[0].add_child(out[1]); out[2].position.z = -0.001; out[0].add_child(out[2])
	return out

## A field boss or the Muster boss: one large foe with telegraphed blows and a periodic slam.
func spawn_boss(id: String, pos: Vector3) -> Dictionary:
	var md: Dictionary = G.MOBS[id]
	var a := _mob_actor(md, 1.0, pos, BOSS_SHADOW)
	if a.name_lbl:
		a.name_lbl.font_size = BOSS_NAME_SIZE; a.name_lbl.position.y = -0.3
	var bars := _hp_bars(a)
	boss = {"id": id, "name": md.name, "level": int(md.level), "greater": false, "drop": md.get("drop", ""), "actor": a, "hp": float(md.hp), "max": float(md.hp),
		"atk": float(md.atk), "slam": float(md.slam), "xp": mob_xp(md), "muster": md.get("muster", false), "alive": true, "next": 0.0, "home": pos, "wander": pos,
		"wander_t": 99.0, "bg": bars[0], "fg": bars[1], "trail": bars[2], "aggro": true, "respawn": 0.0, "tele": false, "tele_pos": Vector3.ZERO, "trail_v": 1.0,
		"was_aggro": true, "boss": true, "goal": Vector3.ZERO}
	mobs.append(boss)
	boss_atk_t = 3.0; boss_count = 0; boss_enraged = false
	G.say("%s bars the way!" % md.name, G.WARN)
	return boss

func _mob_tick(delta: float) -> void:
	var p := w.player.position
	for m in mobs:
		if m.get("boss", false):
			continue
		var a: SpriteActor = m.actor
		if not m.alive:
			m.respawn -= delta
			if m.respawn <= 0.0 and m.respawn > -50.0:
				m.respawn = -99.0
				m.alive = true; m.hp = m.max; a.visible = true; a.position = m.home; a.play("idle"); m.bg.visible = false; m.aggro = false
			continue
		var d := a.position.distance_to(p)
		if dead:
			m.aggro = false
		elif (d < AGGRO_RANGE and not w.sitting) or m.aggro:   # a resting pilgrim is not noticed
			m.aggro = true
		if m.aggro and not m.was_aggro:
			w.kit._pop_mark(a, "!", Color("ffd400"))
			var hop := w.create_tween(); hop.tween_property(a.sprite, "position:y", a.sprite.position.y + 0.35, 0.1); hop.tween_property(a.sprite, "position:y", a.sprite.position.y, 0.12)
		elif not m.aggro and m.was_aggro and not dead:
			w.kit._pop_mark(a, "?", Color("dff2ff"))
		m.was_aggro = m.aggro
		if d > LEASH_RANGE and m.aggro and not dead:
			m.aggro = false
		var goal: Vector3
		if m.aggro and not dead:
			goal = p
		else:
			m.wander_t -= delta
			if m.wander_t <= 0.0:
				m.wander_t = randf_range(2, 5); m.wander = m.home + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			goal = m.wander
		var to := goal - a.position; to.y = 0
		var stop := MOB_REACH if m.aggro else 0.2
		if to.length() > stop:
			var v := to.normalized() * (1.9 if m.aggro else 0.9) * delta
			a.position += v
			a.facing = to.normalized()
			a.play("walk")
		else:
			a.play("idle")
			if m.aggro and not dead:
				if m.next == 0.0:
					m.next = w.t + 1.2
				# telegraph 0.6 s before the lunge: step out of the red circle to avoid it
				if not m.tele and w.t > m.next - TELEGRAPH_S:
					m.tele = true
					m.tele_pos = p
					Fx.telegraph(w, p, 1.1, TELEGRAPH_S)
				if w.t > m.next:
					m.next = w.t + MOB_SWING_S; m.tele = false
					a.play_once("attack", MOB_ATTACK_S); a.squash(0.12)
					var tp: Vector3 = m.get("tele_pos", p)
					var still_in: bool = Vector2(p.x - tp.x, p.z - tp.z).length() < 1.25
					if not still_in or randf() < 0.12:
						w.kit._float_text(p + Vector3(0, 2.2, 0), "Miss", Color("dff2ff"))
					else:
						var dmg := int(m.atk) + randi() % 4
						_hurt_player(dmg)
		a.position.x = clampf(a.position.x, w.bounds.position.x, w.bounds.end.x)
		a.position.z = clampf(a.position.z, w.bounds.position.y, w.bounds.end.y)


func _hurt_player(dmg: int) -> void:
	if w.sitting:
		w._stand()
	dmg = maxi(1, dmg - int(G.d.guard) - int(buff("guard")))   # Steadfastness blocks a little of every blow
	G.hp = maxf(0.0, G.hp - dmg)
	w.kit._float_text(w.player.position + Vector3(0, 2.2, 0), str(dmg), Color("ff6a6a"), false, dmg)
	if G.hp < G.hp_max * 0.5 and w.is_combat() and G.tip_once("low_hp"):
		w.hud.coach.tip("Health is low! Tap Take Refuge if you have learned it, or tap your Bread to eat it.", func(): return w.hud.item_btn, 6.0)
	w.pact.flash(Color("ff5050"), 0.8); w.pact.squash(0.06)
	w.shake(0.18)
	G.haptic(25)
	w.hud.hit_flash()
	if G.hp <= 0.0:
		_ko()
	G.stats_changed.emit()


func hit_mob(m: Dictionary, dmg: int, crit: bool = false, miss: bool = false) -> void:
	var a: SpriteActor = m.actor
	if miss:
		w.kit._float_text(a.position + Vector3(0, 1.6, 0), "Miss", Color("dff2ff")); return
	m.hp = maxf(0.0, m.hp - dmg)
	m.aggro = true
	var kill: bool = m.hp <= 0.0
	w.kit._float_text(a.position + Vector3(0, 1.6, 0), str(dmg), Color("ffe25a") if crit else Color.WHITE, crit or kill, dmg)
	G.zeal = minf(G.zeal_max, G.zeal + ZEAL_ON_HIT)
	a.play_once("hurt", 0.18)
	a.flash(Color.WHITE, 0.9); a.squash(0.14 if crit else 0.09); w.pact.squash(0.05)
	var dirv := (a.position - w.player.position); dirv.y = 0; dirv = dirv.normalized()
	Fx.sparks(w, a.position + Vector3(0, 0.7, 0), dirv, Color(0.85, 0.85, 0.8))
	Fx.dust(w, a.position, Color(0.7, 0.72, 0.66, 0.5), 3)
	if crit:
		Fx.star(w, a.position + Vector3(0, 0.9, 0)); w.shake(0.35); G.haptic(30)
		w.hitstop(0.1)
	elif kill:
		w.hitstop(0.1); w.shake(0.25)
	else:
		w.hitstop(0.05)
	var tw := w.create_tween(); tw.tween_property(a, "position", a.position + dirv * ((0.4 if crit else 0.25) * (0.15 if m.get("boss", false) else 1.0)), 0.08)
	m.bg.visible = not m.get("boss", false)
	m.fg.scale.x = maxf(0.001, m.hp / m.max); m.fg.position.x = -0.43 * (1.0 - m.hp / m.max)
	if m.hp <= 0.0 and m.get("boss", false):
		_boss_down(m)
		return
	if m.hp <= 0.0:
		_mob_down(m)

func _mob_down(m: Dictionary) -> void:
	var a: SpriteActor = m.actor
	m.alive = false; m.bg.visible = false
	m.respawn = NO_RESPAWN if m.greater else float(G.PROG["mob"].respawn)   # Greater foes are set pieces: once each
	a.play_once("die", 0.7)
	w.get_tree().create_timer(0.35).timeout.connect(func() -> void:
		Fx.motes_up(w, a.position + Vector3(0, 0.4, 0), Color("fff6d8"), 16, 1.2); Fx.ring(w, a.position, Color(1, 0.95, 0.75), 2.2, 0.5))
	w.get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if not m.alive: a.visible = false)
	if target == m:
		target = null
	slain += 1
	G.say("You overcame the %s." % m.name, G.SYS)
	_pay_kill(m)
	if m.drop != "" and randf() < DROP_CHANCE:
		w.kit._drop(m.drop, "bread" if m.drop == "Bread of Provision" else "equip", a.position)
	w.quests.on_kill(m)
	mob_slain.emit(m)

## Kill XP is optional extra on top of the quest budget (ledger source "mob").
func _pay_kill(m: Dictionary) -> void:
	var xp := int(m.xp)
	if xp > 0:
		G.add_xp(xp, int(round(xp * float(G.PROG["mob"].job_share))), w.map_id, "mob")

func _attack_pressed() -> void:
	if dead:
		return
	if target == null or not target.alive:
		target = _nearest_mob(28.0)
	if target == null:
		G.say("There is nothing to attack nearby.", G.WARN)


func attack_pressed() -> void:
	_attack_pressed()


func _nearest_mob(r: float) -> Variant:
	var best = null; var bd := r
	for m in mobs:
		if m.alive:
			var d: float = m.actor.position.distance_to(w.player.position)
			if d < bd:
				bd = d; best = m
	return best


func skill(id: String) -> void:
	if dead or w.cinema:
		return
	var info: Dictionary = G.SKILL_INFO[id]
	var lent: bool = G.trial_job != "" and G.JOBS[G.trial_job].skills[0] == id
	if not (G.has_skill(id) or lent):
		G.say("You have not learned %s yet (More → Skills)." % info.name, G.WARN); return
	if gcd > 0.0 and gcd < SKILL_BUFFER_S and cd.get(id, 0.0) <= 0.0:
		queued_skill = id
		return
	if cd.get(id, 0.0) > 0.0:
		G.say("%s is recharging." % info.name, G.WARN); return
	if G.zeal < int(info.zeal):
		G.say("Not enough Zeal (the blue bar). It refills over time, faster while sitting.", G.WARN); return
	var fx: Dictionary = info.fx
	var num := G.skill_num(id)
	var done := false
	match String(fx.type):
		"tend": done = _cast_tend()
		"strike": done = _cast_strike(info, fx, int(num.dmg))
		"aoe": done = _cast_aoe(fx, int(num.dmg))
		"heal": done = _cast_heal(float(num.heal))
		"regen": done = _cast_regen(fx, float(num.zeal))
		"buff": done = _cast_buff(fx, float(num.add))
	if not done:
		return
	G.zeal -= int(info.zeal); cd[id] = float(info.cd); gcd = GCD
	G.say("%s!" % info.name, G.SYS); G.sfx("skill")
	G.stats_changed.emit()

func _cast_tend() -> bool:
	if not w.map.has_method("tend_lily"):
		return false
	return w.map.tend_lily()

func _cast_strike(info: Dictionary, fx: Dictionary, dmg: int) -> bool:
	var m = target if (target != null and target.alive) else _nearest_mob(maxf(AOE_FALLBACK_RANGE, float(fx.range)))
	if m == null:
		G.say("No target.", G.WARN); return false
	target = m
	var to_m: Vector3 = m.actor.position - w.player.position; to_m.y = 0
	if to_m.length() > float(fx.range):
		G.say("Too far. Moving closer…", G.WARN); return false
	used_steps = used_steps or info.job == G.PILGRIM
	w.pact.facing = to_m.normalized()
	w.pact.play_once("attack", 0.35)
	if fx.get("lunge", false):
		var from := w.player.position
		var dest := from + to_m.normalized() * maxf(0.0, to_m.length() - 1.1)
		Fx.afterimages(w, w.pact, from, dest, 3)
		Fx.dust(w, from, Color(0.8, 0.76, 0.66, 0.6), 6)
		w.create_tween().tween_property(w.player, "position", dest, 0.09).set_ease(Tween.EASE_OUT)
	Fx.burst(w, m.actor.position + Vector3(0, 0.8, 0), Color("fff2b0"), 22)
	Fx.ring(w, m.actor.position, Color(1, 0.95, 0.7), 1.8, 0.4)
	hit_mob(m, dmg + randi_range(-2, 2), true)
	return true

func _cast_aoe(fx: Dictionary, dmg: int) -> bool:
	var hit := false
	for m in mobs:
		if m.alive and m.actor.position.distance_to(w.player.position) <= float(fx.radius):
			hit_mob(m, dmg + randi_range(-2, 2), false)
			hit = true
	if not hit:
		G.say("No foe is close enough.", G.WARN); return false
	w.pact.play_once("cast", 0.5)
	Fx.ring(w, w.player.position, Color(1, 0.95, 0.7), float(fx.radius), 0.5)
	w.shake(0.2)
	return true

func _cast_heal(amount: float) -> bool:
	var h := minf(G.hp_max - G.hp, amount)
	G.hp += h
	w.pact.play_once("cast", 0.5)
	w.pact.flash(Color("fff0b0"), 0.6)
	w.kit._float_text(w.player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
	Fx.dome(w, w.player.position)
	return true

func _cast_regen(fx: Dictionary, zeal: float) -> bool:
	regen_until = w.t + float(fx.secs); regen_rate = zeal / float(fx.secs)
	w.pact.play_once("cast", 0.5)
	Fx.ring(w, w.player.position, Color(0.7, 0.85, 1.0), 1.8, 0.6)
	return true

func _cast_buff(fx: Dictionary, add: float) -> bool:
	buffs[String(fx.stat)] = {"add": add, "until": w.t + float(fx.secs)}
	w.pact.play_once("cast", 0.5)
	w.pact.flash(Color("bfe4ff"), 0.6)
	Fx.spiral(w, w.player.position + Vector3(0, 0.2, 0), Color("b8e0ff"))
	return true

# ------------------------------------------------------------------ KO
func _ko() -> void:
	if dead:
		return
	dead = true; target = null; w.auto_on = false; w.move_target = null
	w.pact.play("rest")
	G.kos += 1
	G.haptic_pattern("ko")
	var spoil: float = snappedf(G.manna * 0.05, 0.1)
	G.manna = maxf(0.0, G.manna - spoil)
	w.hud.show_ko(spoil)


func rise() -> void:
	dead = false
	G.hp = G.hp_max; G.zeal = G.zeal_max
	w.player.position = w.info("start")
	w.pact.play("idle")
	for m in mobs:
		m.aggro = false
		if m.actor.position.distance_to(w.player.position) < 8.0:
			m.actor.position = m.home
	G.say("You rest, and rise again.", G.SYS)
	make_weary()

## Every foe loses interest and goes home (used when a quiet moment begins).
func calm() -> void:
	target = null
	for m in mobs:
		if not m.get("boss", false):
			m.aggro = false

## Weariness replaces death penalties: a short slowdown, never lost XP.
func make_weary() -> void:
	G.weary = true
	G.stats_changed.emit()
	w.get_tree().create_timer(WEARY_S).timeout.connect(_weary_end)


func _any_aggro() -> bool:
	for m in mobs:
		if m.alive and m.aggro:
			return true
	return false


func in_combat() -> bool:
	return target != null or _any_aggro()


func cooldown_frac(id: String) -> float:
	var total := float(G.SKILL_INFO[id].cd)
	return cd.get(id, 0.0) / total if total > 0.0 else 0.0

func _weary_end() -> void:
	if not G.weary:
		return
	G.weary = false
	G.say("Your weariness has passed.", G.SYS)
	G.stats_changed.emit()


func _boss_targets() -> Array:
	## Weighted: the defender draws the Giant most; the player is never ignored.
	var t: Array = [{"pos": w.player.position, "who": "player", "w": 1.6}]
	for al in allies:
		t.append({"pos": al.actor.position, "who": al, "w": 3.0 if al.role == "defender" else 1.0})
	return t


func _pick_target() -> Dictionary:
	var ts := _boss_targets()
	var total := 0.0
	for x in ts: total += float(x.w)
	var r := randf() * total
	for x in ts:
		r -= float(x.w)
		if r <= 0.0:
			return x
	return ts[0]


func _boss_tick(delta: float) -> void:
	if not boss.alive or w.ending:
		return
	var a: SpriteActor = boss.actor
	w.hud.boss_bar(boss.name, boss.hp / boss.max)
	if not boss_enraged and boss.hp < boss.max * 0.5:
		boss_enraged = true
		G.say("%s rages and strikes faster!" % boss.name, G.WARN)
		w.kit._pop_mark(a, "!!", Color("ff6a3a")); w.shake(0.4); a.flash(Color("ff6a3a"), 0.7)
	boss_atk_t -= delta * (1.35 if boss_enraged else 1.0)
	var goal: Vector3 = boss.goal if boss.goal != Vector3.ZERO else w.player.position
	var to := goal - a.position; to.y = 0
	if to.length() > 2.6 and boss_atk_t > 1.2:
		a.position += to.normalized() * 1.25 * delta
		a.facing = to.normalized(); a.play("walk")
	else:
		a.play("idle")
	a.position.x = clampf(a.position.x, w.bounds.position.x + 1, w.bounds.end.x - 1)
	a.position.z = clampf(a.position.z, w.bounds.position.y + 1, w.bounds.end.y - 1)
	if boss_atk_t <= 0.0:
		boss_count += 1
		boss_atk_t = 3.4
		if boss_count % 4 == 0:
			# wide slam around the Giant: everyone must step out
			var c := a.position
			Fx.telegraph(w, c, 3.3, 1.5)
			G.say("%s gathers for a great blow!" % boss.name, G.WARN)
			w.get_tree().create_timer(1.5).timeout.connect(_boss_resolve.bind(c, 3.3, int(boss.slam), true))
			for al in allies:
				var away: Vector3 = al.actor.position - c; away.y = 0
				al["dodge"] = c + (away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)) * 4.4
		else:
			var tg := _pick_target()
			boss.goal = tg.pos
			var pos: Vector3 = tg.pos
			Fx.telegraph(w, pos, 1.8, 1.1)
			w.get_tree().create_timer(1.1).timeout.connect(_boss_resolve.bind(pos, 1.8, int(boss.atk), false))
			if tg.who is Dictionary and randf() < 0.75:
				var al2: Dictionary = tg.who
				var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				al2["dodge"] = pos + side * 2.6


func _boss_resolve(c: Vector3, r: float, dmg: int, slam: bool) -> void:
	if boss == null or not boss.alive or w.ending:
		return
	var a: SpriteActor = boss.actor
	a.play_once("attack", MOB_ATTACK_S); a.squash(0.16 if slam else 0.1)
	Fx.dust(w, c, Color(0.75, 0.68, 0.55, 0.7), 14 if slam else 6)
	Fx.ring(w, c, Color(1, 0.8, 0.6), r * 0.9, 0.35)
	w.shake(0.45 if slam else 0.22)
	if not dead and Vector2(w.player.position.x - c.x, w.player.position.z - c.z).length() < r + 0.1:
		_hurt_player(dmg + randi() % 4)
	for al in allies:
		var ap: Vector3 = al.actor.position
		if Vector2(ap.x - c.x, ap.z - c.z).length() < r + 0.1:
			al.actor.flash(Color("ff5050"), 0.7); al.actor.squash(0.06)
			w.kit._float_text(ap + Vector3(0, 2.2, 0), str(dmg + randi() % 4), Color("ffb0b0"))


func _allies_tick(delta: float) -> void:
	if allies.is_empty():
		return
	var fighting: bool = boss != null and boss.alive and not w.ending
	for al in allies:
		var a: SpriteActor = al.actor
		var goal: Vector3
		if al.has("dodge"):
			goal = al.dodge
		elif fighting:
			var ang: float = PI * 0.5 + (al.slot - 1) * 0.9 + (PI if al.role == "support" else 0.0)
			var dist := 4.4 if al.role == "support" else 2.5
			goal = boss.actor.position + Vector3(cos(ang), 0, sin(ang)) * dist
		else:
			goal = w.player.position + Vector3(-1.6 + al.slot * 1.6, 0, 1.4)
		var to := goal - a.position; to.y = 0
		if to.length() > 0.3:
			a.position += to.normalized() * (4.0 if al.has("dodge") else 3.0) * delta
			a.facing = to.normalized(); a.play("walk")
		else:
			if al.has("dodge"):
				al.erase("dodge")
			a.play("idle")
			if fighting:
				var tb: Vector3 = boss.actor.position - a.position; tb.y = 0
				a.facing = tb.normalized()
		if not fighting:
			continue
		al.next -= delta
		if al.next <= 0.0 and not al.has("dodge"):
			al.next = randf_range(1.2, 1.6)
			if al.role == "support":
				a.play_once("cast", 0.4)
				_ally_hit(al, 6 + randi() % 4)
			elif a.position.distance_to(boss.actor.position) < 3.0:
				a.play_once("attack", 0.32)
				_ally_hit(al, (9 if al.role == "damage" else 7) + randi() % 5)
		if al.role == "support":
			al.heal_t -= delta
			if al.heal_t <= 0.0 and G.hp < G.hp_max * 0.7 and not dead:
				al.heal_t = 6.0
				var h := minf(G.hp_max - G.hp, 22.0)
				G.hp += h; G.stats_changed.emit()
				a.play_once("cast", 0.5)
				w.kit._float_text(w.player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
				Fx.ring(w, w.player.position, Color(0.6, 1.0, 0.6), 1.6, 0.4)
				G.say("%s: Hold on, I've got you." % al.name, G.CHAT)


func _ally_hit(al: Dictionary, dmg: int) -> void:
	var b: SpriteActor = boss.actor
	boss.hp = maxf(0.0, boss.hp - dmg)
	w.kit._float_text(b.position + Vector3(0, 2.6, 0), str(dmg), Color("bfe4ff"))
	b.flash(Color.WHITE, 0.45)
	var dirv: Vector3 = b.position - al.actor.position; dirv.y = 0
	Fx.sparks(w, b.position + Vector3(0, 1.4, 0), dirv.normalized(), Color(0.85, 0.9, 1.0))
	if boss.hp <= 0.0:
		_boss_down(boss)


func _boss_down(m: Dictionary) -> void:
	if not m.alive:
		return
	m.alive = false
	var a: SpriteActor = m.actor
	a.play_once("die", 1.2)
	w.hud.boss_bar("", -1.0)
	w.shake(0.6); w.hitstop(0.18)
	w.get_tree().create_timer(0.6).timeout.connect(_boss_fade_fx.bind(a.position))
	w.get_tree().create_timer(1.2).timeout.connect(w.kit._hide_node.bind(a))
	if target == m:
		target = null
	_pay_kill(m)
	if m.drop != "":
		G.bag_add(m.drop, 1)
	if m.muster:
		_muster_cleared(m)
	else:
		G.say("%s is overcome. The way is clear." % m.name, G.INFO)
	if w.quests.cur().get("type", "") == "script":
		w.quests.complete()     # the Muster arena's objective is finished by this fight
	else:
		w.quests.on_kill(m)

func _muster_cleared(m: Dictionary) -> void:
	var companions := 0
	for al in allies:
		if not al.ai: companions += 1
	G.marks += companions
	G.say("Muster cleared! %s is driven from the way." % m.name, G.INFO)
	G.say("Rewards: %s · Fellowship Marks +%d (one per named companion)." % [m.drop, companions], G.INFO)
	w.hud.muster_cleared(companions)
	for al in allies:
		al.actor.play_once("cast", 0.8)
	w.get_tree().create_timer(1.6).timeout.connect(func() -> void: G.say("Lumen: Well fought, all! See you at the hearth.", G.CHAT))

func _boss_fade_fx(p: Vector3) -> void:
	Fx.motes_up(w, p + Vector3(0, 1.0, 0), Color("fff6d8"), 40, 1.8)
	Fx.ring(w, p, Color(1, 0.95, 0.75), 5.0, 0.7)
