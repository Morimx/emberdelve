extends SceneTree
## Simulación de balance: juega expediciones con dos políticas y compara resultados.
## Uso: godot --headless --path . --script res://tests/balance_sim.gd
## Si "cauteloso" y "temerario" dan lo mismo, la antorcha no está generando decisiones.

const RUNS := 400


func _initialize() -> void:
	for meta_level in [0, 3]:
		var meta := MetaState.new()
		meta.attack_level = meta_level
		meta.hp_level = meta_level
		print("\n== Progreso permanente Nv %d ==" % meta_level)
		for policy in [&"temerario", &"cauteloso"]:
			_report(policy, _simulate(meta, policy))
	quit()


func _simulate(meta: MetaState, policy: StringName) -> Dictionary:
	var stats := {"victory": 0, "retreat": 0, "defeat": 0, "darkness": 0, "gold": 0, "steps": 0}
	for run in RUNS:
		var ex := GameData.new_expedition(meta, 1000 + run)
		while not ex.finished:
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
	var want := &"supplies" if ex.torch <= 1 or (policy == &"cauteloso" and ex.torch <= 3) else &"boon"
	for i in ex.pending_rewards.size():
		if ex.pending_rewards[i].kind == want:
			return i
	return 0


func _report(policy: StringName, s: Dictionary) -> void:
	print("%-10s victoria %3d%% · retirada %3d%% · caída %3d%% · oscuridad %3d%% · oro medio %4d · salas %.1f" % [
		policy, s.victory * 100 / RUNS, s.retreat * 100 / RUNS, s.defeat * 100 / RUNS,
		s.darkness * 100 / RUNS, s.gold / RUNS, float(s.steps) / RUNS,
	])
