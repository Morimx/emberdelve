extends SceneTree
## Simulación de balance: juega expediciones con dos políticas y compara resultados.
## Uso: godot --headless --path . --script res://tests/balance_sim.gd
## Si "cauteloso" y "temerario" dan lo mismo, la antorcha no está generando decisiones.

const RUNS := 400


func _initialize() -> void:
	# Cada mazmorra se prueba con el progreso que un jugador tendría al llegar a ella.
	for setup in [[&"catacombs", 0], [&"catacombs", 3], [&"flooded_crypt", 3], [&"flooded_crypt", 5], [&"sunken_forge", 5]]:
		var meta := MetaState.new()
		var lvl: int = setup[1]
		if lvl > 0:
			meta.talents = {"ember": 1, "might": lvl, "vitality": lvl, "bulwark": mini(lvl, 3), "keen_edge": mini(lvl, 3)}
			meta.skill_levels = {"warrior": mini(lvl, 5), "cleric": mini(lvl, 5), "assassin": mini(lvl, 5)}
			_equip(meta, lvl)
		print("\n== %s · progreso Nv %d ==" % [setup[0], lvl])
		for policy in [&"temerario", &"cauteloso"]:
			_report(policy, _simulate(meta, policy, setup[0]))
	quit()


## Equipo que un jugador suele tener con ese progreso: los 9 espacios llenos, de rareza
## y profundidad según el nivel (los objetos se guardan al volver con vida).
func _equip(meta: MetaState, lvl: int) -> void:
	var rarity := 1 if lvl < 5 else 2
	var depth := lvl + 2
	for hero_id in MetaState.hero_ids():
		var gear := {}
		for base: StringName in Loot.BASES:
			var def: Dictionary = Loot.BASES[base]
			if (def.hero == hero_id or def.hero == &"") and not gear.has(def.slot):
				gear[def.slot] = Loot.make_item(base, rarity, depth)
		meta.equipped[hero_id] = gear


func _simulate(meta: MetaState, policy: StringName, dungeon: StringName) -> Dictionary:
	var stats := {"victory": 0, "retreat": 0, "defeat": 0, "darkness": 0, "gold": 0, "steps": 0}
	for run in RUNS:
		var ex := GameData.new_expedition(meta, 1000 + run, dungeon)
		while not ex.finished:
			if ex.pending_levelups > 0:
				ex.choose_levelup(0)
				continue
			if not ex.pending_rewards.is_empty():
				ex.choose_reward(_pick_reward(ex, policy))
				continue
			if policy == &"cauteloso" and _should_retreat(ex):
				ex.retreat()
				continue
			var door := _pick_door(ex)
			if door == &"":
				ex.retreat()
			else:
				ex.enter(door)
		stats[String(ex.outcome)] += 1
		stats.gold += ex.kept.gold
		stats.steps += ex.kept.steps
	return stats


func _should_retreat(ex: Expedition) -> bool:
	var hp := 0
	var max_hp := 0
	for u in ex.party:
		hp += u.hp
		max_hp += u.max_hp
	var low_light := ex.torch <= 1 and &"camp" not in ex.current_doors()
	return low_light or float(hp) / max_hp < 0.3


func _pick_door(ex: Expedition) -> StringName:
	var doors: Array = ex.current_doors()
	if &"camp" in doors and ex.can_enter(&"camp") and ex.torch <= 4:
		return &"camp"
	for preferred in [&"elite", &"combat", &"event", &"boss", &"camp"]:
		if preferred in doors and ex.can_enter(preferred):
			return preferred
	return &""


func _pick_reward(ex: Expedition, policy: StringName) -> int:
	var want := &"supplies" if ex.torch <= 1 or (policy == &"cauteloso" and ex.torch <= 3) else &"item"
	for i in ex.pending_rewards.size():
		if ex.pending_rewards[i].kind == want:
			return i
	return 0


func _report(policy: StringName, s: Dictionary) -> void:
	print("%-10s victoria %3d%% · retirada %3d%% · caída %3d%% · oscuridad %3d%% · oro medio %4d · salas %.1f" % [
		policy, s.victory * 100 / RUNS, s.retreat * 100 / RUNS, s.defeat * 100 / RUNS,
		s.darkness * 100 / RUNS, s.gold / RUNS, float(s.steps) / RUNS,
	])
