class_name Combat
extends RefCounted
## Simulación de combate automático por ticks. Es pura: recibe unidades y un RNG,
## las modifica y devuelve la lista de eventos para que la UI los reproduzca.

const TICK := 0.1
const MAX_TIME := 90.0
const SHIELD_DURATION := 3.0


static func run(party: Array[Unit], enemies: Array[Unit], rng: RandomNumberGenerator, mods: Dictionary = {}) -> Dictionary:
	var events: Array[Dictionary] = []
	var all: Array[Unit] = []
	all.append_array(party)
	all.append_array(enemies)

	var attack_timers := {}
	var skill_timers := {}
	var backstab := {}
	var atk_pct: float = mods.get("attack_pct", 0.0)
	var def_bonus: int = int(mods.get("defense", 0))
	var lifesteal: float = mods.get("lifesteal", 0.0)
	var extra_crit: float = mods.get("crit_chance", 0.0)
	var speed_mult: float = 1.0 + mods.get("speed_pct", 0.0)
	var skill_mult: float = 1.0 + mods.get("skill_power_pct", 0.0)

	var speeds := {}
	for u in all:
		speeds[u] = u.speed * (speed_mult if not u.is_enemy else 1.0)
		attack_timers[u] = rng.randf_range(0.3, 1.0) / speeds[u]
		skill_timers[u] = u.skill_cooldown
	var shield_until := -1.0
	var shield_power := 0.0

	var t := 0.0
	while t < MAX_TIME and _any_alive(party) and _any_alive(enemies):
		t += TICK
		for u in all:
			if not u.is_alive() or not _any_alive(party) or not _any_alive(enemies):
				continue

			if u.skill != &"":
				skill_timers[u] -= TICK
				if skill_timers[u] <= 0.0:
					match u.skill:
						&"shield_wall":
							shield_until = t + SHIELD_DURATION
							shield_power = minf(0.8, u.skill_power * skill_mult)
							events.append({"t": t, "type": "skill", "src": u, "label": "Shield Wall"})
							skill_timers[u] = u.skill_cooldown
						&"heal":
							var target := _most_wounded(party)
							if target == null:
								skill_timers[u] = 0.5
							else:
								var amount := int(round(target.max_hp * u.skill_power * skill_mult))
								target.hp = mini(target.max_hp, target.hp + amount)
								events.append({"t": t, "type": "heal", "src": u, "dst": target, "amount": amount, "hp": target.hp})
								skill_timers[u] = u.skill_cooldown
						&"backstab":
							backstab[u] = true
							events.append({"t": t, "type": "skill", "src": u, "label": "Backstab"})
							skill_timers[u] = u.skill_cooldown

			attack_timers[u] -= TICK
			if attack_timers[u] > 0.0:
				continue
			attack_timers[u] += 1.0 / speeds[u]

			var foe := _pick_target(u, enemies if not u.is_enemy else party)
			if foe == null:
				continue
			var atk := float(u.attack) * (1.0 + (atk_pct if not u.is_enemy else 0.0))
			var def := float(foe.defense + (def_bonus if not foe.is_enemy else 0))
			var dmg := atk * rng.randf_range(0.9, 1.1) - def * 0.5
			var crit := rng.randf() < u.crit_chance + (extra_crit if not u.is_enemy else 0.0)
			if crit:
				dmg *= 2.0
			if backstab.get(u, false):
				dmg *= 3.0 * skill_mult
				backstab[u] = false
			if not foe.is_enemy and t < shield_until:
				dmg *= 1.0 - shield_power
			var amount := maxi(1, int(round(dmg)))
			foe.hp = maxi(0, foe.hp - amount)
			events.append({"t": t, "type": "hit", "src": u, "dst": foe, "amount": amount, "crit": crit, "hp": foe.hp})

			if not u.is_enemy and lifesteal > 0.0 and u.hp < u.max_hp:
				var heal := int(round(amount * lifesteal))
				if heal > 0:
					u.hp = mini(u.max_hp, u.hp + heal)
					events.append({"t": t, "type": "heal", "src": u, "dst": u, "amount": heal, "hp": u.hp})
			if not foe.is_alive():
				events.append({"t": t, "type": "death", "dst": foe})

	var won := not _any_alive(enemies) and _any_alive(party)
	return {"won": won, "events": events, "duration": t}


static func _any_alive(units: Array[Unit]) -> bool:
	for u in units:
		if u.is_alive():
			return true
	return false


static func _pick_target(attacker: Unit, foes: Array[Unit]) -> Unit:
	var best: Unit = null
	for f in foes:
		if not f.is_alive():
			continue
		if best == null:
			best = f
		elif attacker.is_enemy and f.front and not best.front:
			best = f
		elif attacker.skill == &"backstab" and f.hp < best.hp:
			best = f
	return best


static func _most_wounded(units: Array[Unit]) -> Unit:
	var best: Unit = null
	var best_ratio := 0.75
	for u in units:
		if not u.is_alive():
			continue
		var ratio := float(u.hp) / u.max_hp
		if ratio < best_ratio:
			best = u
			best_ratio = ratio
	return best
