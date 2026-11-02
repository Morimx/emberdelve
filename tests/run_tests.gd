extends SceneTree
## Pruebas de lógica. Uso: godot --headless --path . --script res://tests/run_tests.gd
## Sale con código 1 si alguna falla.

var _failures := 0
var _count := 0


func _initialize() -> void:
	_test_combat_is_deterministic()
	_test_strong_party_wins()
	_test_entering_spends_torch()
	_test_cannot_enter_without_light()
	_test_retreat_keeps_everything()
	_test_defeat_keeps_half()
	_test_darkness_unless_supplies()
	_test_camp_restores_light()
	_test_rarity_distribution()
	_test_meta_equips_better_items()
	_test_meta_save_roundtrip()
	print("\n%d pruebas, %d fallidas" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	_count += 1
	if cond:
		print("  ok    ", name)
	else:
		_failures += 1
		printerr("  FALLA ", name)


func _party(bonus: Dictionary = {}) -> Array[Unit]:
	var out: Array[Unit] = []
	for h in GameData.heroes():
		out.append(Unit.from_hero(h, bonus))
	return out


func _enemies(scale: float = 1.0) -> Array[Unit]:
	var out: Array[Unit] = []
	for e in GameData.enemies():
		out.append(Unit.from_enemy(e, scale))
	return out


func _expedition(seed_value: int = 7, bonus: Dictionary = {}) -> Expedition:
	return Expedition.new(GameData.heroes(), GameData.enemies(), GameData.BOSS, GameData.boons(), bonus, 8, seed_value)


func _test_combat_is_deterministic() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	var r1 := Combat.run(_party(), _enemies(), a)
	var r2 := Combat.run(_party(), _enemies(), b)
	_check(r1.won == r2.won and r1.events.size() == r2.events.size(), "combate determinista con la misma semilla")


func _test_strong_party_wins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var weak: Array[Unit] = [Unit.from_enemy(GameData.ENEMIES[1], 0.5)]
	var r := Combat.run(_party(), weak, rng)
	_check(r.won and r.duration < Combat.MAX_TIME, "un grupo fuerte vence a un enemigo débil")


func _test_entering_spends_torch() -> void:
	var ex := _expedition()
	_check(ex.current_doors() == [&"combat"], "la primera sala es siempre un combate")
	ex.enter(&"combat")
	_check(ex.torch == 7 and ex.step == 1, "entrar a un combate gasta 1 de luz")


func _test_cannot_enter_without_light() -> void:
	var ex := _expedition()
	ex.torch = 1
	ex.plan[0] = [&"elite"]
	_check(not ex.can_enter(&"elite"), "no se entra a una élite con 1 de luz")


func _test_retreat_keeps_everything() -> void:
	var ex := _expedition()
	ex.gold = 101
	ex.items.append(Loot.roll_item(ex.rng, 1))
	ex.items.append(Loot.roll_item(ex.rng, 1))
	ex.retreat()
	_check(ex.outcome == &"retreat" and ex.kept.gold == 101 and ex.kept.items.size() == 2, "retirarse conserva el 100%")


func _test_defeat_keeps_half() -> void:
	var ex := _expedition()
	ex.gold = 101
	ex.shards = 3
	for i in 3:
		ex.items.append(Loot.roll_item(ex.rng, 1))
	ex._finish(&"defeat")
	_check(ex.kept.gold == 50 and ex.kept.shards == 1 and ex.kept.items.size() == 1, "caer conserva la mitad (redondeo hacia abajo)")


func _test_darkness_unless_supplies() -> void:
	var strong := {"attack": 200, "max_hp": 2000}
	var lost := _expedition(3, strong)
	lost.torch = 1
	lost.enter(&"combat")
	_check(lost.torch == 0 and not lost.pending_rewards.is_empty(), "ganar con la última luz ofrece recompensa")
	lost.choose_reward(0)
	_check(lost.finished and lost.outcome == &"darkness", "sin luz y sin suministros: perdidos en la oscuridad")

	var saved := _expedition(3, strong)
	saved.torch = 1
	saved.enter(&"combat")
	var supplies := -1
	for i in saved.pending_rewards.size():
		if saved.pending_rewards[i].kind == &"supplies":
			supplies = i
	saved.choose_reward(supplies)
	_check(not saved.finished and saved.torch == Expedition.SUPPLIES_TORCH, "los suministros rescatan la expedición")


func _test_camp_restores_light() -> void:
	var ex := _expedition()
	ex.step = 3
	ex.party[0].hp = 10
	var before := ex.torch
	ex.enter(&"camp")
	_check(ex.torch == before - 1 + Expedition.CAMP_TORCH and ex.party[0].hp > 10, "el campamento devuelve luz y cura")


func _test_rarity_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts := [0, 0, 0, 0, 0]
	for i in 20000:
		counts[Loot.roll_rarity(rng)] += 1
	var common: float = counts[0] / 20000.0
	_check(absf(common - 0.6) < 0.02 and counts[4] > 0, "rarezas cerca de 60/25/11/3.5/0.5 (común %.3f)" % common)


func _test_meta_equips_better_items() -> void:
	var meta := MetaState.new()
	var weak := ItemData.new()
	weak.slot = &"weapon"
	weak.attack = 2
	var strong := ItemData.new()
	strong.slot = &"weapon"
	strong.attack = 9
	strong.rarity = 2
	var summary := meta.apply_run({"gold": 10, "items": [weak, strong], "steps": 4})
	_check(meta.equipped[&"weapon"] == strong and summary.salvage > 0 and meta.best_step == 4, "el progreso equipa el mejor objeto y desguaza el resto")


func _test_meta_save_roundtrip() -> void:
	var path := "user://test_save.json"
	var meta := MetaState.new()
	meta.gold = 321
	meta.torch_level = 2
	var item := ItemData.new()
	item.slot = &"armor"
	item.defense = 4
	item.rarity = 3
	meta.equipped[&"armor"] = item
	var err := meta.save(path)
	var loaded := MetaState.load_from(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(err == OK and loaded.gold == 321 and loaded.torch_start() == MetaState.BASE_TORCH + 2 and loaded.equipped[&"armor"].defense == 4, "guardar y cargar conserva el progreso")
