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
	"test_kills_grant_xp_and_levelups",
	"test_levelup_blocks_doors_until_chosen",
	"test_rest_reward_heals",
	"test_talents_require_path_and_currency",
	"test_talent_bonus_reaches_expedition",
	"test_meta_migrates_upgrades_to_talents",
	"test_dungeons_unlock_in_order",
	"test_harder_dungeon_scales_enemies",
	"test_restore_keeps_dungeon",
	"test_skill_levels_strengthen_heroes",
	"test_stash_overflow_salvages_worst",
	"test_meta_v5_migration",
	"test_spanish_covers_every_text",
	"test_settings_roundtrip",
	"test_score_formula",
	"test_score_table",
	"test_run_time_counts_for_score",
	"test_locale_switches_language",
	"test_class_gear_and_charms",
	"test_meta_v6_moves_party_gear_to_heroes",
	"test_run_item_boosts_only_its_hero",
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
	_check(lost.torch == 0 and not lost.pending_rewards.is_empty() and not lost.finished, "ganar con la última luz ofrece recompensa")
	lost.pending_levelups = 0
	lost.levelup_options.clear()
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
	var first := Loot.make_item(&"dagger", 0, 1)
	var second := Loot.make_item(&"twin_daggers", 2, 1)
	var summary := meta.apply_run({"gold": 10, "items": [first, second], "steps": 4, "run_id": "abc"})
	_check(meta.gear(&"assassin", &"weapon") == first and meta.stash == [second] and summary.stashed == 1, "un slot vacío de su héroe se equipa solo; el resto va al depósito")
	_check(meta.gear(&"warrior", &"weapon") == null, "una daga no la equipa el guerrero")
	_check(meta.equip_from_stash(0) and meta.gear(&"assassin", &"weapon") == second and meta.stash == [first], "equipar desde el depósito intercambia con el equipado")
	var gold_before := meta.gold
	_check(meta.salvage_from_stash(0) > 0 and meta.stash.is_empty() and meta.gold > gold_before, "desguazar da oro y vacía el lugar")
	_check(meta.last_run_id == "abc" and meta.best_step == 4, "el progreso recuerda la última expedición cobrada")
	return true


func test_meta_save_roundtrip() -> bool:
	SaveIO.remove(TMP)
	var meta := MetaState.new()
	meta.gold = 321
	meta.talents = {"ember": 1, "torchbearer": 2}
	var item := Loot.make_item(&"robe", 3, 2)
	meta.stash.append(item)
	meta.equip_from_stash(0)
	var err := meta.save(TMP)
	var loaded := MetaState.load_from(TMP)
	var robe := loaded.gear(&"cleric", &"armor")
	_check(err == OK and loaded.gold == 321 and loaded.torch_start(GameData.talents()) == MetaState.BASE_TORCH + 2 and robe != null and robe.max_hp == item.max_hp and robe.base == &"robe", "guardar y cargar conserva el progreso y el equipo por héroe")
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
	_check(loaded.gear(&"warrior", &"weapon") != null and loaded.gear(&"warrior", &"weapon").display_name == "Sword", "los objetos guardados en español pasan a inglés y a su héroe")
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
	original._add_boon(GameData.BOONS[3])
	original.pending_levelups = 0
	original.levelup_options.clear()
	original.choose_reward(1)  # suministros
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
	ex.pending_levelups = 0
	ex.levelup_options.clear()
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


# --- niveles y talentos ------------------------------------------------------------

func test_kills_grant_xp_and_levelups() -> bool:
	var ex := _expedition(5, {"attack": 200, "max_hp": 2000})
	var result := ex.enter(&"combat")
	_check(ex.level > 1 or ex.xp > 0, "matar enemigos da experiencia")
	if ex.pending_levelups > 0:
		_check(ex.levelup_options.size() == Expedition.LEVELUP_CHOICES, "cada subida de nivel ofrece 3 bendiciones")
		var lvl_before := ex.pending_levelups
		_check(ex.choose_levelup(0) and ex.pending_levelups == lvl_before - 1, "elegir una bendición consume la subida de nivel")
	_check(result.get("xp", -1) >= 0, "el resultado del combate informa los niveles ganados")
	return true


func test_levelup_blocks_doors_until_chosen() -> bool:
	var ex := _expedition(5, {"attack": 200, "max_hp": 2000})
	ex.enter(&"combat")
	ex.pending_rewards.clear()
	ex._gain_xp(1000)
	_check(not ex.can_retreat() and not ex.can_enter(ex.current_doors()[0]), "con una subida pendiente no se avanza ni se retira")
	while ex.pending_levelups > 0:
		ex.choose_levelup(0)
	_check(ex.can_retreat(), "elegidas las bendiciones se puede seguir")
	return true


func test_rest_reward_heals() -> bool:
	var ex := _expedition(5, {"attack": 200, "max_hp": 2000})
	ex.enter(&"combat")
	ex.pending_levelups = 0
	ex.levelup_options.clear()
	ex.party[0].hp = 10
	var rest := -1
	for i in ex.pending_rewards.size():
		if ex.pending_rewards[i].kind == &"rest":
			rest = i
	_check(rest >= 0 and ex.choose_reward(rest) and ex.party[0].hp > 10, "descansar cura al grupo")
	return true


func test_talents_require_path_and_currency() -> bool:
	var meta := MetaState.new()
	var might: TalentData = GameData.TALENTS[1]
	var ember: TalentData = GameData.TALENTS[0]
	meta.gold = 1000
	_check(not meta.can_buy(might), "un talento sin su requisito no se puede comprar")
	_check(meta.buy(ember) and meta.can_buy(might), "comprar la raíz desbloquea las ramas")
	meta.gold = 0
	_check(not meta.can_buy(might), "sin oro no se compra")
	meta.gold = 1000
	for i in might.max_level:
		meta.buy(might)
	_check(meta.talent_level(might.id) == might.max_level and not meta.can_buy(might), "no se supera el nivel máximo")
	return true


func test_talent_bonus_reaches_expedition() -> bool:
	var meta := MetaState.new()
	meta.talents = {"ember": 1, "might": 2, "torchbearer": 1, "prospector": 1}
	var bonus := meta.hero_bonus(GameData.talents())
	var ex := GameData.new_expedition(meta, 3)
	var base := Unit.from_hero(GameData.HEROES[0], {})
	_check(is_equal_approx(bonus.attack_pct, 0.12) and ex.party[0].attack > base.attack, "Might sube el ataque de los héroes")
	_check(ex.torch == MetaState.BASE_TORCH + 1, "Torchbearer suma luz inicial")
	_check(is_equal_approx(ex._run_bonus.gold_pct, 0.1), "Prospector llega al oro de la expedición")
	return true


func test_meta_migrates_upgrades_to_talents() -> bool:
	SaveIO.remove(TMP)
	_write_raw(TMP, JSON.stringify({"version": 3, "gold": 5, "attack_level": 2, "hp_level": 1, "torch_level": 3}))
	var loaded := MetaState.load_from(TMP)
	_check(loaded.talent_level(&"might") == 2 and loaded.talent_level(&"vitality") == 1 and loaded.talent_level(&"torchbearer") == 3, "las mejoras viejas pasan a sus talentos")
	_check(loaded.talent_level(&"ember") == 1 and loaded.torch_start(GameData.talents()) == MetaState.BASE_TORCH + 3, "la raíz queda comprada y la luz inicial se conserva")
	return true


# --- mazmorras, depósito y habilidades ------------------------------------------------

func test_dungeons_unlock_in_order() -> bool:
	var meta := MetaState.new()
	var all := GameData.dungeons()
	_check(meta.is_dungeon_unlocked(all[0]) and not meta.is_dungeon_unlocked(all[1]), "solo la primera mazmorra arranca abierta")
	var summary := meta.apply_run({"outcome": "victory", "dungeon": "catacombs", "items": []})
	_check(summary.first_clear and meta.is_dungeon_unlocked(all[1]) and not meta.is_dungeon_unlocked(all[2]), "vencer al jefe abre la siguiente")
	meta.apply_run({"outcome": "retreat", "dungeon": "flooded_crypt", "items": []})
	_check(not meta.is_dungeon_unlocked(all[2]), "retirarse no cuenta como vencer al jefe")
	return true


func test_harder_dungeon_scales_enemies() -> bool:
	var meta := MetaState.new()
	var easy := GameData.new_expedition(meta, 4, &"catacombs")
	var hard := GameData.new_expedition(meta, 4, &"sunken_forge")
	_check(hard.difficulty > easy.difficulty and hard.boss_shards > easy.boss_shards, "la mazmorra difícil escala enemigos y paga más esquirlas")
	var r := hard.enter(&"combat")
	_check(r.enemies[0].id in [&"imp", &"golem", &"magma", &"cultist"], "cada mazmorra usa su propio elenco")
	return true


func test_restore_keeps_dungeon() -> bool:
	var ex := GameData.new_expedition(MetaState.new(), 8, &"flooded_crypt")
	var restored := GameData.restore_expedition(JSON.parse_string(JSON.stringify(ex.to_dict())))
	_check(restored != null and restored.dungeon_id == &"flooded_crypt" and is_equal_approx(restored.difficulty, ex.difficulty), "el autoguardado recuerda la mazmorra")
	return true


func test_skill_levels_strengthen_heroes() -> bool:
	var meta := MetaState.new()
	meta.shards = 100
	var base := Unit.from_hero(GameData.HEROES[0], meta.hero_bonus(GameData.talents()))
	_check(meta.upgrade_skill(&"warrior") and meta.skill_level(&"warrior") == 2, "mejorar una habilidad cuesta esquirlas y sube su nivel")
	var better := Unit.from_hero(GameData.HEROES[0], meta.hero_bonus(GameData.talents()))
	_check(better.skill_power > base.skill_power and better.skill_cooldown < base.skill_cooldown, "más nivel: más poder y menos enfriamiento")
	meta.shards = 0
	_check(not meta.can_upgrade_skill(&"warrior"), "sin esquirlas no se mejora")
	return true


func test_stash_overflow_salvages_worst() -> bool:
	var meta := MetaState.new()
	var items: Array = []
	for i in MetaState.STASH_MAX + 4:
		var it := ItemData.new()
		it.slot = &"armor"
		it.defense = i + 1
		items.append(it)
	var summary := meta.apply_run({"items": items})
	_check(meta.stash.size() == MetaState.STASH_MAX and summary.salvage > 0, "con el depósito lleno se desguaza lo peor")
	return true


func test_meta_v5_migration() -> bool:
	SaveIO.remove(TMP)
	_write_raw(TMP, JSON.stringify({"version": 4, "gold": 3, "best_step": 9, "talents": {"ember": 1}}))
	var loaded := MetaState.load_from(TMP)
	_check(loaded.cleared.has("catacombs") and loaded.stash.is_empty() and loaded.skill_level(&"cleric") == 1, "v4 a v5: quien llegó al jefe tiene abierta la segunda mazmorra")
	return true


func test_spanish_covers_every_text() -> bool:
	var fmt := RegEx.create_from_string("%[ds%]")
	var missing: PackedStringArray = []
	var bad_format: PackedStringArray = []
	for key in I18nKeys.collect():
		if not LocaleEs.TEXT.has(key):
			missing.append(key)
			continue
		var a := fmt.search_all(key).map(func(m: RegExMatch) -> String: return m.get_string())
		var b := fmt.search_all(LocaleEs.TEXT[key]).map(func(m: RegExMatch) -> String: return m.get_string())
		if a != b:
			bad_format.append(key)
	if not missing.is_empty():
		printerr("    sin traducir: ", missing)
	if not bad_format.is_empty():
		printerr("    marcadores distintos: ", bad_format)
	_check(missing.is_empty(), "todos los textos visibles tienen traducción al español")
	_check(bad_format.is_empty(), "las traducciones conservan los marcadores %d/%s/%%")
	return true


func test_settings_roundtrip() -> bool:
	var meta := MetaState.new()
	meta.volume = 0.35
	meta.language = "es"
	var loaded := MetaState.from_dict(meta.to_dict())
	_check(is_equal_approx(loaded.volume, 0.35) and loaded.language == "es", "volumen e idioma se guardan")
	_check(is_equal_approx(MetaState.from_dict({"version": 5}).volume, 0.8), "guardado viejo: volumen por defecto")
	return true


func test_score_formula() -> bool:
	var defeat := Score.compute(5, false, 100, &"catacombs")
	var slow := Score.compute(9, true, 900, &"catacombs")
	var fast := Score.compute(9, true, 200, &"catacombs")
	_check(defeat == 500 and slow == 1900, "salas y victoria suman puntos")
	_check(fast > slow and Score.compute(5, false, 10, &"catacombs") == defeat, "la rapidez solo suma al vencer")
	_check(Score.compute(9, true, 200, &"sunken_forge") > fast, "una mazmorra más difícil vale más")
	return true


func test_score_table() -> bool:
	var meta := MetaState.new()
	for points in [300, 1200, 800]:
		meta.add_score({"score": points, "dungeon": "catacombs", "steps": 3})
	_check(meta.best_score() == 1200 and int(meta.scores[2].score) == 300, "la tabla queda ordenada")
	_check(meta.add_score({"score": 0}) == -1, "un puntaje de 0 no entra")
	for i in Score.TABLE_SIZE:
		meta.add_score({"score": 2000 + i})
	_check(meta.scores.size() == Score.TABLE_SIZE and meta.add_score({"score": 5}) == -1, "la tabla guarda solo las mejores")
	var loaded := MetaState.from_dict(meta.to_dict())
	_check(loaded.scores.size() == Score.TABLE_SIZE and loaded.best_score() == meta.best_score(), "la tabla se guarda y carga")
	return true


func test_run_time_counts_for_score() -> bool:
	var ex := GameData.new_expedition(MetaState.new(), 7)
	ex.elapsed = 75.0
	var restored := GameData.new_expedition(MetaState.new(), 7)
	restored.apply_state(ex.to_dict())
	_check(is_equal_approx(restored.elapsed, 75.0), "el tiempo de la expedición se guarda")
	ex.retreat()
	_check(int(ex.kept.seconds) == 75 and int(ex.kept.score) == Score.compute(ex.step, false, 75, ex.dungeon_id), "el resultado trae tiempo y puntaje")
	var meta := MetaState.new()
	_check(int(meta.apply_run(ex.kept).rank) == (0 if int(ex.kept.score) > 0 else -1), "cobrar la expedición anota el puntaje")
	return true


func test_locale_switches_language() -> bool:
	Locale.apply("es")
	var es := TranslationServer.translate("Floor %d · Room %d/%d") == "Piso %d · Sala %d/%d"
	Locale.apply("en")
	var en := TranslationServer.translate("Camp") == "Camp"
	_check(es and en and Locale.current() == "en", "el idioma cambia entre español e inglés")
	return true


func test_class_gear_and_charms() -> bool:
	var meta := MetaState.new()
	meta.stash.append(Loot.make_item(&"staff", 1, 2))
	_check(not meta.equip_from_stash(0, &"warrior") or meta.gear(&"cleric", &"weapon") != null, "un bastón va siempre al clérigo")
	_check(meta.gear(&"cleric", &"weapon") != null and meta.gear(&"warrior", &"weapon") == null, "el bastón quedó en el clérigo")
	meta.stash.append(Loot.make_item(&"ring", 1, 2))
	_check(not meta.equip_from_stash(0), "un amuleto necesita elegir héroe")
	_check(meta.equip_from_stash(0, &"assassin") and meta.gear(&"assassin", &"charm") != null, "un amuleto lo equipa cualquiera")
	var bonus := meta.hero_bonus(GameData.talents())
	var cleric := Unit.from_hero(GameData.hero(&"cleric"), bonus)
	var warrior := Unit.from_hero(GameData.hero(&"warrior"), bonus)
	var bare := meta.hero_bonus(GameData.talents())
	bare.erase("gear")
	_check(cleric.max_hp > Unit.from_hero(GameData.hero(&"cleric"), bare).max_hp and warrior.max_hp == Unit.from_hero(GameData.hero(&"warrior"), bare).max_hp, "el equipo solo potencia a quien lo lleva")
	for base in Loot.BASES:
		var it := Loot.make_item(base, 0, 0)
		_check(it.power() > 0 and SpriteBank.has_sprite(base), "el tipo %s da algo y tiene icono" % base)
	return true


func test_meta_v6_moves_party_gear_to_heroes() -> bool:
	SaveIO.remove(TMP)
	var old_dagger := {"display_name": "Dagger", "rarity": 1, "slot": "weapon", "attack": 3, "defense": 0, "max_hp": 0}
	var old_cuirass := {"display_name": "Cuirass", "rarity": 0, "slot": "armor", "attack": 0, "defense": 2, "max_hp": 8}
	var old_ring := {"display_name": "Ring", "rarity": 2, "slot": "charm", "attack": 1, "defense": 0, "max_hp": 6}
	_write_raw(TMP, JSON.stringify({"version": 5, "gold": 5, "equipped": {"weapon": old_dagger, "armor": old_cuirass, "charm": old_ring}, "stash": [old_dagger]}))
	var loaded := MetaState.load_from(TMP)
	_check(loaded.gear(&"assassin", &"weapon") != null and loaded.gear(&"assassin", &"weapon").attack == 3, "v5 a v6: la daga pasa al asesino con sus valores")
	_check(loaded.gear(&"warrior", &"armor") != null and loaded.gear(&"warrior", &"charm") != null, "v5 a v6: coraza y amuleto pasan al guerrero")
	_check(loaded.stash.size() == 1 and loaded.stash[0].hero == &"assassin", "v5 a v6: el depósito también se convierte")
	return true


func test_run_item_boosts_only_its_hero() -> bool:
	var ex := GameData.new_expedition(MetaState.new(), 11)
	var before := {}
	for u in ex.party:
		before[u.id] = u.attack
	ex._add_item(Loot.make_item(&"axe", 2, 3))
	var changed := ex.party.filter(func(u: Unit) -> bool: return u.attack != before[u.id])
	_check(changed.size() == 1 and changed[0].id == &"warrior", "un hacha en la expedición solo potencia al guerrero")
	return true
