extends SceneTree
## Pruebas de lógica. Uso: godot --headless --path . --script res://tests/run_tests.gd
## Sale con código 1 si alguna falla. Cada prueba devuelve true al terminar: si un error
## de ejecución la aborta, devuelve otro valor y se cuenta como fallida.

const TESTS: PackedStringArray = [
	"test_combat_is_deterministic",
	"test_strong_party_wins",
	"test_entering_spends_torch",
	"test_cannot_enter_without_light",
	"test_invalid_actions_leave_state_untouched",
	"test_retreat_keeps_everything",
	"test_defeat_keeps_half",
	"test_darkness_unless_supplies",
	"test_camp_restores_light",
	"test_boon_modifies_combat",
	"test_rarity_distribution",
	"test_meta_equips_better_items",
	"test_meta_save_roundtrip",
	"test_save_falls_back_to_backup",
	"test_meta_migrates_v1",
	"test_newer_save_is_not_overwritten",
	"test_run_roundtrip_resumes_identically",
	"test_checkpoint_fires_between_rooms",
	"test_collected_run_is_not_resumed",
]
const TMP := "user://test_tmp.json"

var _failures := 0
var _count := 0


func _initialize() -> void:
	for t in TESTS:
		if call(t) != true:
			_failures += 1
			printerr("  FALLA %s: no terminó (¿error de ejecución?)" % t)
	SaveIO.remove(TMP)
	print("\n%d comprobaciones en %d pruebas, %d fallidas" % [_count, TESTS.size(), _failures])
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


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- combate y expedición ------------------------------------------------------

func test_combat_is_deterministic() -> bool:
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	var r1 := Combat.run(_party(), _enemies(), a)
	var r2 := Combat.run(_party(), _enemies(), b)
	_check(r1.won == r2.won and r1.events.size() == r2.events.size(), "combate determinista con la misma semilla")
	return true


func test_strong_party_wins() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var weak: Array[Unit] = [Unit.from_enemy(GameData.ENEMIES[1], 0.5)]
	var r := Combat.run(_party(), weak, rng)
	_check(r.won and r.duration < Combat.MAX_TIME, "un grupo fuerte vence a un enemigo débil")
	return true


func test_entering_spends_torch() -> bool:
	var ex := _expedition()
	_check(ex.current_doors() == [&"combat"], "la primera sala es siempre un combate")
	ex.enter(&"combat")
	_check(ex.torch == 7 and ex.step == 1, "entrar a un combate gasta 1 de luz")
	return true


func test_cannot_enter_without_light() -> bool:
	var ex := _expedition()
	ex.torch = 1
	ex.plan[0] = [&"elite"]
	_check(not ex.can_enter(&"elite"), "no se entra a una élite con 1 de luz")
	return true


func test_invalid_actions_leave_state_untouched() -> bool:
	var ex := _expedition()
	var result := ex.enter(&"boss")
	_check(result.has("error") and ex.torch == 8 and ex.step == 0, "entrar a una puerta que no está devuelve error sin gastar luz")
	_check(not ex.choose_reward(0), "elegir recompensa sin recompensas pendientes falla")
	var strong := _expedition(3, {"attack": 200, "max_hp": 2000})
	strong.enter(&"combat")
	_check(not strong.retreat() and not strong.finished, "no se puede retirar con una recompensa pendiente")
	_check(not strong.choose_reward(9) and strong.pending_rewards.size() > 0, "un índice de recompensa inválido no consume la elección")
	return true


func test_retreat_keeps_everything() -> bool:
	var ex := _expedition()
	ex.gold = 101
	ex.items.append(Loot.roll_item(ex.rng, 1))
	ex.items.append(Loot.roll_item(ex.rng, 1))
	ex.retreat()
	_check(ex.outcome == &"retreat" and ex.kept.gold == 101 and ex.kept.items.size() == 2, "retirarse conserva el 100%")
	return true


func test_defeat_keeps_half() -> bool:
	var ex := _expedition()
	ex.gold = 101
	ex.shards = 3
	for i in 3:
		ex.items.append(Loot.roll_item(ex.rng, 1))
	ex._finish(&"defeat")
	_check(ex.kept.gold == 50 and ex.kept.shards == 1 and ex.kept.items.size() == 1, "caer conserva la mitad (redondeo hacia abajo)")
	return true


func test_darkness_unless_supplies() -> bool:
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
	return true


func test_camp_restores_light() -> bool:
	var ex := _expedition()
	ex.step = 3
	ex.party[0].hp = 10
	var before := ex.torch
	ex.enter(&"camp")
	_check(ex.torch == before - 1 + Expedition.CAMP_TORCH and ex.party[0].hp > 10, "el campamento devuelve luz y cura")
	return true


func test_boon_modifies_combat() -> bool:
	var ex := _expedition()
	ex._add_boon(GameData.BOONS[3])  # Grito de guerra: attack_pct
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var b := RandomNumberGenerator.new()
	b.seed = 5
	var base := Combat.run(_party(), _enemies(), a)
	var boosted := Combat.run(_party(), _enemies(), b, ex.mods)
	_check(ex.mods.has("attack_pct") and boosted.duration < base.duration, "las bendiciones llegan al combate (gana más rápido)")
	return true


func test_rarity_distribution() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts := [0, 0, 0, 0, 0]
	for i in 20000:
		counts[Loot.roll_rarity(rng)] += 1
	var common: float = counts[0] / 20000.0
	_check(absf(common - 0.6) < 0.02 and counts[4] > 0, "rarezas cerca de 60/25/11/3.5/0.5 (común %.3f)" % common)
	return true


# --- progreso y guardado ---------------------------------------------------------

func test_meta_equips_better_items() -> bool:
	var meta := MetaState.new()
	var weak := ItemData.new()
	weak.slot = &"weapon"
	weak.attack = 2
	var strong := ItemData.new()
	strong.slot = &"weapon"
	strong.attack = 9
	strong.rarity = 2
	var summary := meta.apply_run({"gold": 10, "items": [weak, strong], "steps": 4, "run_id": "abc"})
	_check(meta.equipped[&"weapon"] == strong and summary.salvage > 0 and meta.best_step == 4, "el progreso equipa el mejor objeto y desguaza el resto")
	_check(meta.last_run_id == "abc", "el progreso recuerda la última expedición cobrada")
	return true


func test_meta_save_roundtrip() -> bool:
	SaveIO.remove(TMP)
	var meta := MetaState.new()
	meta.gold = 321
	meta.torch_level = 2
	var item := ItemData.new()
	item.slot = &"armor"
	item.defense = 4
	item.rarity = 3
	meta.equipped[&"armor"] = item
	var err := meta.save(TMP)
	var loaded := MetaState.load_from(TMP)
	_check(err == OK and loaded.gold == 321 and loaded.torch_start() == MetaState.BASE_TORCH + 2 and loaded.equipped[&"armor"].defense == 4, "guardar y cargar conserva el progreso")
	_check(not FileAccess.file_exists(TMP + ".tmp"), "no queda archivo temporal tras guardar")
	return true


func test_save_falls_back_to_backup() -> bool:
	SaveIO.remove(TMP)
	var meta := MetaState.new()
	meta.gold = 10
	meta.save(TMP)
	meta.gold = 20
	meta.save(TMP)
	_check(FileAccess.file_exists(TMP + ".bak"), "el segundo guardado deja una copia .bak")
	_write_raw(TMP, "{ roto")
	var loaded := MetaState.load_from(TMP)
	_check(loaded.gold == 10, "con el principal corrupto se recupera el .bak")
	return true


func test_meta_migrates_v1() -> bool:
	SaveIO.remove(TMP)
	var legacy_sword := {"display_name": "Espada", "rarity": 1, "slot": "weapon", "attack": 3, "defense": 0, "max_hp": 0}
	_write_raw(TMP, JSON.stringify({"version": 1, "gold": 77, "runs": 3, "equipped": {"weapon": legacy_sword}}))
	var loaded := MetaState.load_from(TMP)
	_check(loaded.gold == 77 and loaded.runs == 3 and loaded.last_run_id == "" and loaded.to_dict().version == MetaState.SAVE_VERSION, "un guardado v1 migra a la versión actual")
	_check(loaded.equipped[&"weapon"].display_name == "Sword", "los objetos guardados en español pasan a inglés")
	return true


func test_newer_save_is_not_overwritten() -> bool:
	SaveIO.remove(TMP)
	_write_raw(TMP, JSON.stringify({"version": 99, "gold": 5}))
	var loaded := MetaState.load_from(TMP)
	var err := loaded.save(TMP)
	var still := SaveIO.load_json(TMP)
	_check(loaded.newer_save and err != OK and still.version == 99, "un guardado de una versión más nueva no se sobrescribe")
	return true


func test_run_roundtrip_resumes_identically() -> bool:
	var original := _expedition(11, {"attack": 200, "max_hp": 2000})
	original.enter(&"combat")
	original.choose_reward(1)  # bendición
	original.party[1].hp = 33
	var restored := GameData.restore_expedition(JSON.parse_string(JSON.stringify(original.to_dict())))
	_check(restored != null, "la expedición guardada se puede restaurar")
	if restored == null:
		return true
	_check(restored.torch == original.torch and restored.step == original.step and restored.gold == original.gold, "luz, paso y oro se restauran")
	_check(restored.party[1].hp == 33 and restored.party[0].attack == original.party[0].attack, "vida y stats del grupo se restauran")
	_check(restored.boons_taken.size() == original.boons_taken.size() and restored.mods == original.mods, "bendiciones y modificadores se restauran")
	_check(restored.plan == original.plan and restored.rng.randi() == original.rng.randi(), "plan y generador aleatorio siguen idénticos")
	return true


func test_checkpoint_fires_between_rooms() -> bool:
	var ex := _expedition(3, {"attack": 200, "max_hp": 2000})
	var hits := [0]
	ex.checkpoint.connect(func() -> void: hits[0] += 1)
	ex.enter(&"combat")
	ex.choose_reward(0)
	_check(hits[0] == 2, "hay punto de autoguardado tras la sala y tras la recompensa")
	return true


func test_collected_run_is_not_resumed() -> bool:
	SaveIO.remove(TMP)
	var ex := _expedition(21)
	RunStore.save_run(ex, TMP)
	var meta := MetaState.new()
	_check(RunStore.load_run(meta, TMP) != null, "una expedición sin cobrar se reanuda")
	meta.last_run_id = ex.run_id
	_check(RunStore.load_run(meta, TMP) == null and not FileAccess.file_exists(TMP), "una expedición ya cobrada se descarta")
	return true
