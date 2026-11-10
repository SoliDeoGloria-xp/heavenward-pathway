class_name Combat
extends RefCounted
## Mobs, the player's skills, KO and Weariness, and the Muster boss with AI companions.

var w: World

func _init(world: World) -> void:
	w = world

var allies: Array = []           # Muster party: {actor, name, role, ai, next, slot}

var boss = null                  # Muster boss mob dict

var boss_atk_t := 0.0

var boss_count := 0

var boss_enraged := false

var target = null               # mob dict being attacked

var dead := false

var next_atk := 0.0

var cd := {"steps": 0.0, "refuge": 0.0, "tend": 0.0}

var used_steps := false

var gcd := 0.0

var mobs: Array = []             # {node, actor, hp, max, alive, pos, next, aggro, home, bar, respawn}

var slain := 0

var queued_skill := ""


# ------------------------------------------------------------------ mobs
func _spawn_mob(pos: Vector3) -> void:
	var a := SpriteActor.new(); w.add_child(a); a.position = pos
	a.setup({"tex": G.tex("res://assets/sprites/mob_slothling.png"), "hframes": 7, "vframes": 1, "pixel": 0.04, "rows": false,
		"anims": {"idle": [0, 1], "walk": [2, 3], "hurt": [4], "die": [5, 6]}, "fps": {"idle": 2.0, "walk": 4.0, "die": 3.0}}, "Slothling", Color("ffe0e0"))
	var bg := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.9, 0.09); bg.mesh = q
	var bgm := StandardMaterial3D.new(); bgm.albedo_color = Color(0.1, 0.1, 0.12); bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; bgm.no_depth_test = true; bgm.render_priority = 4
	bg.material_override = bgm; bg.position.y = -0.45; bg.visible = false; a.add_child(bg)
	var fg := MeshInstance3D.new(); var q2 := QuadMesh.new(); q2.size = Vector2(0.86, 0.06); fg.mesh = q2
	var fgm := StandardMaterial3D.new(); fgm.albedo_color = Color("e83b3b"); fgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fgm.no_depth_test = true; fgm.render_priority = 5
	fg.material_override = fgm; bg.add_child(fg)
	var tr := MeshInstance3D.new(); var q3 := QuadMesh.new(); q3.size = Vector2(0.86, 0.06); tr.mesh = q3
	var trm := StandardMaterial3D.new(); trm.albedo_color = Color(1, 1, 1, 0.9); trm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; trm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; trm.no_depth_test = true; trm.render_priority = 4
	tr.material_override = trm; tr.position.z = -0.001; bg.add_child(tr)
	a.set_meta("trail", tr)
	mobs.append({"actor": a, "hp": 60.0, "max": 60.0, "alive": true, "next": 0.0, "home": pos, "wander": pos, "wander_t": randf_range(1, 4), "bg": bg, "fg": fg, "aggro": false, "respawn": 0.0, "tele": false, "tele_pos": Vector3.ZERO, "trail": tr, "trail_v": 1.0, "was_aggro": false})


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
		elif d < 6.0 or m.aggro:
			m.aggro = true
		if m.aggro and not m.was_aggro:
			w.kit._pop_mark(a, "!", Color("ffd400"))
			var hop := w.create_tween(); hop.tween_property(a.sprite, "position:y", a.sprite.position.y + 0.35, 0.1); hop.tween_property(a.sprite, "position:y", a.sprite.position.y, 0.12)
		elif not m.aggro and m.was_aggro and not dead:
			w.kit._pop_mark(a, "?", Color("dff2ff"))
		m.was_aggro = m.aggro
		if d > 14.0 and m.aggro and not dead:
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
		var stop := 1.4 if m.aggro else 0.2
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
				if not m.tele and w.t > m.next - 0.6:
					m.tele = true
					m.tele_pos = p
					Fx.telegraph(w, p, 1.1, 0.6)
				if w.t > m.next:
					m.next = w.t + 2.0; m.tele = false
					a.play_once("walk", 0.3); a.squash(0.12)
					var tp: Vector3 = m.get("tele_pos", p)
					var still_in: bool = Vector2(p.x - tp.x, p.z - tp.z).length() < 1.25
					if not still_in or randf() < 0.12:
						w.kit._float_text(p + Vector3(0, 2.2, 0), "Miss", Color("dff2ff"))
					else:
						var dmg := 7 + randi() % 4
						_hurt_player(dmg)
		a.position.x = clampf(a.position.x, w.bounds.position.x, w.bounds.end.x)
		a.position.z = clampf(a.position.z, w.bounds.position.y, w.bounds.end.y)


func _hurt_player(dmg: int) -> void:
	if w.sitting:
		w._stand()
	dmg = maxi(1, dmg - int(G.d.guard))   # Steadfastness blocks a little of every blow
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
	G.zeal = minf(G.zeal_max, G.zeal + 3.0)
	a.play_once("hurt", 0.18)
	a.flash(Color.WHITE, 0.9); a.squash(0.14 if crit else 0.09); w.pact.squash(0.05)
	var dirv := (a.position - w.player.position); dirv.y = 0; dirv = dirv.normalized()
	Fx.sparks(w, a.position + Vector3(0, 0.7, 0), dirv, Color(0.85, 0.85, 0.8))   # Sloth family: grey dust
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
		m.alive = false; m.respawn = 14.0; m.bg.visible = false
		a.play_once("die", 0.7)
		w.get_tree().create_timer(0.35).timeout.connect(func(): Fx.motes_up(w, a.position + Vector3(0, 0.4, 0), Color("fff6d8"), 16, 1.2); Fx.ring(w, a.position, Color(1, 0.95, 0.75), 2.2, 0.5))
		w.get_tree().create_timer(0.7).timeout.connect(func(): if not m.alive: a.visible = false)
		if target == m:
			target = null
		slain += 1
		G.say("You overcame the Slothling.", G.SYS)
		G.add_xp(4, 2)   # 3 + monster level 1
		if randf() < 0.8:
			w.kit._drop("Bread of Provision", "bread", a.position)
		if w.quests.cur_obj() == "fight":
			w.quests.objectives[0].text = "Overcome the Slothlings (%d/3)" % mini(slain, 3)
			if slain >= 3:
				w.get_tree().create_timer(1.6).timeout.connect(w.map._evangelist_arrives)
			w.quests._update_quest()


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
	if not G.has_skill(id):
		G.say("You have not learned %s yet (More → Skills)." % G.SKILL_INFO[id].name, G.WARN); return
	if gcd > 0.0 and gcd < 0.3 and cd.get(id, 0.0) <= 0.0:
		queued_skill = id  # buffer the press; fires when the global cooldown ends
		return
	var info: Dictionary = G.SKILL_INFO[id]
	if cd.get(id, 0.0) > 0.0:
		G.say("%s is recharging." % info.name, G.WARN); return
	if G.zeal < int(info.zeal):
		G.say("Not enough Zeal (the blue bar). It refills over time, faster while sitting.", G.WARN); return
	match id:
		"tend":
			var best = null; var bd := 3.2
			for l in w.map.lilies:
				var dl := Vector2(w.player.position.x - l.pos.x, w.player.position.z - l.pos.z).length()
				if not l.bloomed and dl < bd:
					bd = dl; best = l
			if best == null:
				G.say("Stand next to a drooping lily, then use Tend and Keep.", G.WARN); return
			G.zeal -= int(info.zeal); cd.tend = float(info.cd); gcd = 1.0
			w.pact.play_once("cast", 0.5); w.pact.facing = (best.pos - w.player.position).normalized()
			best.bloomed = true; best.actor.play("bloom")
			best.actor.squash(0.2)
			w.kit._sparkle(best.pos + Vector3(0, 0.6, 0), Color("dff7ff"))
			Fx.ring(w, best.pos, Color(0.85, 1, 0.85), 1.6, 0.5)
			w.map.lilies_done += 1
			G.add_xp(10, 1, "eden")
			G.say("The lily lifts its head and blooms.", G.SYS)
			if w.quests.cur_obj() == "lilies":
				w.quests.objectives[w.quests.obj_idx].text = "Tend the drooping lilies with your skill (%d/3)" % w.map.lilies_done
				w.quests._update_quest()
				if w.map.lilies_done >= 3:
					w.quests.complete()
		"steps":
			var m = target if (target != null and target.alive) else _nearest_mob(10.0)
			if m == null:
				G.say("No target.", G.WARN); return
			target = m
			if m.actor.position.distance_to(w.player.position) > 2.2:
				G.say("Too far. Moving closer…", G.WARN); return
			G.zeal -= int(info.zeal); cd.steps = float(info.cd); gcd = 1.0
			used_steps = true
			var to_m: Vector3 = (m.actor.position - w.player.position); to_m.y = 0
			w.pact.facing = to_m.normalized()
			w.pact.play_once("attack", 0.35)
			var from := w.player.position
			var dest := w.player.position + to_m.normalized() * maxf(0.0, to_m.length() - 1.1)
			Fx.afterimages(w, w.pact, from, dest, 3)
			Fx.dust(w, from, Color(0.8, 0.76, 0.66, 0.6), 6)
			var lunge := w.create_tween(); lunge.tween_property(w.player, "position", dest, 0.09).set_ease(Tween.EASE_OUT)
			Fx.burst(w, m.actor.position + Vector3(0, 0.8, 0), Color("fff2b0"), 22)
			Fx.ring(w, m.actor.position, Color(1, 0.95, 0.7), 1.8, 0.4)
			hit_mob(m, int(G.skill_num("steps").dmg) + randi_range(-2, 2), true)
			G.say("First Steps!", G.SYS)
		"refuge":
			G.zeal -= int(info.zeal); cd.refuge = float(info.cd); gcd = 1.0
			var h := minf(G.hp_max - G.hp, float(G.skill_num("refuge").heal))
			G.hp += h
			w.pact.play_once("cast", 0.5)
			w.pact.flash(Color("fff0b0"), 0.6)
			w.kit._float_text(w.player.position + Vector3(0, 2.2, 0), "+%d" % int(h), Color("7cff7c"))
			Fx.dome(w, w.player.position)
			G.say("Take Refuge. [BSB: Psalm 9:9 · pulled at build time]", G.SYS)
	G.stats_changed.emit()


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
	G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = true
	w.player.position = w.info("start")
	w.pact.play("idle")
	for m in mobs:
		m.aggro = false
		if m.actor.position.distance_to(w.player.position) < 8.0:
			m.actor.position = m.home
	G.say("You rest, and rise again.", G.SYS)
	G.stats_changed.emit()
	w.get_tree().create_timer(25.0).timeout.connect(_weary_end)


func _any_aggro() -> bool:
	for m in mobs:
		if m.alive and m.aggro:
			return true
	return false


func in_combat() -> bool:
	return target != null or _any_aggro()


func cooldown_frac(id: String) -> float:
	return cd.get(id, 0.0) / float(G.SKILL_INFO[id].cd)


func _weary_end() -> void:
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
	w.hud.boss_bar("Giant Grim", boss.hp / boss.max)
	if not boss_enraged and boss.hp < boss.max * 0.5:
		boss_enraged = true
		G.say("Giant Grim roars and lays about him faster!", G.WARN)
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
			G.say("Giant Grim raises his club high!", G.WARN)
			w.get_tree().create_timer(1.5).timeout.connect(_boss_resolve.bind(c, 3.3, 20, true))
			for al in allies:
				var away: Vector3 = al.actor.position - c; away.y = 0
				al["dodge"] = c + (away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)) * 4.4
		else:
			var tg := _pick_target()
			boss.goal = tg.pos
			var pos: Vector3 = tg.pos
			Fx.telegraph(w, pos, 1.8, 1.1)
			w.get_tree().create_timer(1.1).timeout.connect(_boss_resolve.bind(pos, 1.8, 14, false))
			if tg.who is Dictionary and randf() < 0.75:
				var al2: Dictionary = tg.who
				var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				al2["dodge"] = pos + side * 2.6


func _boss_resolve(c: Vector3, r: float, dmg: int, slam: bool) -> void:
	if boss == null or not boss.alive or w.ending:
		return
	var a: SpriteActor = boss.actor
	a.play_once("walk", 0.3); a.squash(0.16 if slam else 0.1)
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
	var humans := 0
	for al in allies:
		if not al.ai: humans += 1
	G.marks += humans
	G.add_xp(200, 60)
	G.bag_add("Grim's Broken Chain", 1)
	G.say("Muster cleared! Giant Grim is driven from the way.", G.INFO)
	G.say("Rewards: Grim's Broken Chain · Fellowship Marks +%d (one per pilgrim in your company)." % humans, G.INFO)
	w.hud.muster_cleared(humans)
	for al in allies:
		al.actor.play_once("cast", 0.8)
	w.get_tree().create_timer(1.6).timeout.connect(func(): G.say("Lumen: Well fought, all! See you at the hearth.", G.CHAT))
	w.show_ent("warp", true)
	w.quests.complete()


func _boss_fade_fx(p: Vector3) -> void:
	Fx.motes_up(w, p + Vector3(0, 1.0, 0), Color("fff6d8"), 40, 1.8)
	Fx.ring(w, p, Color(1, 0.95, 0.75), 5.0, 0.7)
