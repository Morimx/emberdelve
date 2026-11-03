class_name Expedition
extends RefCounted
## Una expedición: 2 pisos de 4 salas y un jefe. Cada sala gasta luz de la antorcha.
## Retirarse o vencer al jefe conserva todo el botín; caer o quedarse sin luz, la mitad.

signal torch_changed(value: int)
signal ended(outcome: StringName, kept: Dictionary)
## Estado estable entre salas: buen momento para autoguardar.
signal checkpoint()

const RUN_VERSION := 2
const STEPS := 9
const ROOMS_PER_FLOOR := 4
const TORCH_COST := {&"combat": 1, &"elite": 2, &"event": 1, &"camp": 1, &"boss": 1}
const CAMP_TORCH := 3
const CAMP_HEAL := 0.4
const SUPPLIES_TORCH := 2
const REST_HEAL := 0.3
const DOOR_WEIGHTS := {&"combat": 3.0, &"elite": 1.0, &"event": 2.0}
const LEVELUP_CHOICES := 3
## Cuánto más fuertes son los enemigos por cada sala de profundidad.
const DEPTH_SCALING := 0.23
## Bonos de progreso permanente que afectan al combate (el resto ya está en las stats).
const COMBAT_BONUS_KEYS: PackedStringArray = ["crit_chance", "lifesteal", "speed_pct", "skill_power_pct"]

var rng := RandomNumberGenerator.new()
var run_id := ""
var party: Array[Unit] = []
var torch: int
var torch_max: int
var step := 0
var plan: Array = []
var gold := 0
var shards := 0
var items: Array[ItemData] = []
var boons_taken: Array[BoonData] = []
var mods := {}
var pending_rewards: Array[Dictionary] = []
## Subida de nivel compartida por el grupo: cada nivel ofrece 1 de 3 bendiciones.
var level := 1
var xp := 0
var pending_levelups := 0
var levelup_options: Array[BoonData] = []
var finished := false
var outcome: StringName = &""
var kept := {}
## Segundos reales jugados en esta expedición (los suma la UI); define el bonus de rapidez.
var elapsed := 0.0

var _enemy_pool: Array[EnemyData]
var _boss: EnemyData
var _boon_pool: Array[BoonData]
## gold_pct, xp_pct y luck del progreso permanente.
var _run_bonus := {}
## Mazmorra de la expedición: escala a todos los enemigos y paga más esquirlas en el jefe.
var dungeon_id: StringName = &"catacombs"
var difficulty := 1.0
var boss_shards := 3
## Multiplicador extra del jefe: el pico de dificultad de cada mazmorra.
var boss_power := 1.6


func _init(heroes: Array[HeroData], enemy_pool: Array[EnemyData], boss: EnemyData, boons: Array[BoonData], hero_bonus: Dictionary, torch_start: int, seed_value: int, dungeon_difficulty := 1.0, dungeon := &"catacombs", shards_for_boss := 3, boss_multiplier := 1.6) -> void:
	rng.seed = seed_value
	run_id = str(seed_value)
	difficulty = dungeon_difficulty
	dungeon_id = dungeon
	boss_shards = shards_for_boss
	boss_power = boss_multiplier
	_enemy_pool = enemy_pool
	_boss = boss
	_boon_pool = boons
	for h in heroes:
		party.append(Unit.from_hero(h, hero_bonus))
	for key in COMBAT_BONUS_KEYS:
		if hero_bonus.get(key, 0.0) != 0.0:
			mods[key] = float(hero_bonus[key])
	for key in ["gold_pct", "xp_pct", "luck", "camp_torch"]:
		_run_bonus[key] = float(hero_bonus.get(key, 0.0))
	torch = torch_start
	torch_max = torch_start
	_generate_plan()


func current_doors() -> Array:
	return plan[step] if step < plan.size() else []


func has_pending_choice() -> bool:
	return not pending_rewards.is_empty() or pending_levelups > 0


func can_enter(kind: StringName) -> bool:
	return not finished and not has_pending_choice() and kind in current_doors() and torch >= TORCH_COST[kind]


func can_retreat() -> bool:
	return not finished and not has_pending_choice()


func xp_to_next() -> int:
	return 40 + 25 * (level - 1)


## Elige una de las bendiciones ofrecidas por la subida de nivel.
func choose_levelup(index: int) -> bool:
	if finished or pending_levelups <= 0 or index < 0 or index >= levelup_options.size():
		push_error("Subida de nivel inválida: %d de %d." % [index, levelup_options.size()])
		return false
	_add_boon(levelup_options[index])
	pending_levelups -= 1
	levelup_options.clear()
	if pending_levelups > 0:
		_roll_levelup_options()
	_check_darkness()
	if not finished:
		checkpoint.emit()
	return true


## Resuelve una sala. Devuelve lo necesario para que la UI la muestre,
## o {"error": ...} sin tocar el estado si la acción no es válida.
func enter(kind: StringName) -> Dictionary:
	if not can_enter(kind):
		push_error("No se puede entrar a %s (paso %d, luz %d)." % [kind, step, torch])
		return {"error": "You can't enter that room."}
	_set_torch(torch - TORCH_COST[kind])
	var result := {"kind": kind, "step": step}
	step += 1
	match kind:
		&"combat", &"elite", &"boss":
			_resolve_combat(kind, result)
		&"event":
			_resolve_event(result)
			_check_darkness()
		&"camp":
			_set_torch(torch + CAMP_TORCH + int(_run_bonus.get("camp_torch", 0.0)))
			for u in party:
				u.hp = mini(u.max_hp, maxi(u.hp, 1) + int(u.max_hp * CAMP_HEAL))
			# Texto con su argumento aparte, para que la UI lo traduzca antes de formatearlo.
			result["text"] = "Camp: +%d light and the party recovers."
			result["text_args"] = [CAMP_TORCH]
	if not finished:
		checkpoint.emit()
	return result


func choose_reward(index: int) -> bool:
	if finished or index < 0 or index >= pending_rewards.size():
		push_error("Recompensa inválida: %d de %d." % [index, pending_rewards.size()])
		return false
	var reward: Dictionary = pending_rewards[index]
	pending_rewards.clear()
	match reward.kind:
		&"item":
			_add_item(reward.item)
		&"boon":
			_add_boon(reward.boon)
		&"supplies":
			_set_torch(torch + SUPPLIES_TORCH)
			gold += reward.gold
		&"rest":
			_heal_party(REST_HEAL)
	_check_darkness()
	if not finished:
		checkpoint.emit()
	return true


func retreat() -> bool:
	if not can_retreat():
		push_error("No se puede retirar ahora.")
		return false
	_finish(&"retreat")
	return true


func floor_label() -> String:
	if step >= STEPS - 1:
		return "Boss lair"
	return "Floor %d · Room %d/%d" % [step / ROOMS_PER_FLOOR + 1, step % ROOMS_PER_FLOOR + 1, ROOMS_PER_FLOOR]


static func keep_ratio(result: StringName) -> float:
	return 1.0 if result in [&"victory", &"retreat"] else 0.5


func _generate_plan() -> void:
	plan.clear()
	for i in STEPS - 1:
		if i == 0:
			plan.append([&"combat"])
		elif i == 3 or i == 6:
			plan.append([&"camp", _weighted_door([])])
		else:
			var first := _weighted_door([])
			plan.append([first, _weighted_door([first])])
	plan.append([&"boss"])


func _weighted_door(exclude: Array) -> StringName:
	var total := 0.0
	for k in DOOR_WEIGHTS:
		if k not in exclude:
			total += DOOR_WEIGHTS[k]
	var roll := rng.randf() * total
	for k in DOOR_WEIGHTS:
		if k in exclude:
			continue
		roll -= DOOR_WEIGHTS[k]
		if roll <= 0.0:
			return k
	return &"combat"


func _resolve_combat(kind: StringName, result: Dictionary) -> void:
	var depth := step - 1
	var scale := (1.0 + DEPTH_SCALING * depth) * difficulty
	var enemies: Array[Unit] = []
	match kind:
		&"combat":
			for i in rng.randi_range(2, 3):
				enemies.append(Unit.from_enemy(_random_enemy(), scale))
		&"elite":
			var elite := Unit.from_enemy(_random_enemy(), scale * 1.8)
			elite.display_name = "Elite " + elite.display_name
			enemies.append(elite)
			enemies.append(Unit.from_enemy(_random_enemy(), scale))
		&"boss":
			enemies.append(Unit.from_enemy(_boss, difficulty * boss_power))
			enemies.append(Unit.from_enemy(_random_enemy(), scale))

	var fighters: Array[Unit] = []
	for u in party:
		if u.is_alive():
			fighters.append(u)
	var start_hp := {}
	for u in fighters + enemies:
		start_hp[u] = u.hp
	var combat := Combat.run(fighters, enemies, rng, mods)
	result["party"] = party
	result["enemies"] = enemies
	result["start_hp"] = start_hp
	result["combat"] = combat

	if not combat.won:
		_finish(&"defeat")
		return
	var gained_xp := 0
	for e in enemies:
		gold += int(e.gold_reward * scale * (1.0 + _run_bonus.get("gold_pct", 0.0)))
		gained_xp += maxi(1, e.max_hp / 8)
	if kind == &"elite":
		shards += 1
	if kind == &"boss":
		shards += boss_shards
		_finish(&"victory")
		return
	result["xp"] = _gain_xp(int(gained_xp * (1.0 + _run_bonus.get("xp_pct", 0.0))))
	pending_rewards = _roll_rewards(kind, depth)


## Suma experiencia; devuelve cuántos niveles se subieron.
func _gain_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	if gained > 0:
		pending_levelups += gained
		if levelup_options.is_empty():
			_roll_levelup_options()
	return gained


func _roll_levelup_options() -> void:
	var pool := _boon_pool.duplicate()
	levelup_options.clear()
	while levelup_options.size() < LEVELUP_CHOICES and not pool.is_empty():
		levelup_options.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))


func _resolve_event(result: Dictionary) -> void:
	# result["event"] y los datos de cada caso los usa la UI para animar el evento.
	match rng.randi_range(0, 2):
		0:
			_set_torch(torch + 1)
			result["event"] = &"shrine"
			result["light"] = 1
			result["text"] = "Shrine: a blue flame rekindles the torch (+1 light)."
		1:
			var damage := {}
			for u in party:
				if u.is_alive():
					var before := u.hp
					u.hp = maxi(1, u.hp - int(u.max_hp * 0.15))
					damage[u] = before - u.hp
			result["event"] = &"trap"
			result["damage"] = damage
			result["text"] = "Trap: the party loses 15% of its health."
		2:
			var item := Loot.roll_item(rng, step)
			_add_item(item)
			gold += 30
			result["event"] = &"chest"
			result["item"] = item
			result["gold"] = 30
			result["text"] = "Forgotten chest: %s and 30 gold." % item.describe()


func _roll_rewards(kind: StringName, depth: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var luck := 1 if kind == &"elite" else 0
	if rng.randf() < _run_bonus.get("luck", 0.0):
		luck += 1
	rewards.append({"kind": &"item", "item": Loot.roll_item(rng, depth, luck)})
	rewards.append({"kind": &"supplies", "gold": int((40 + 10 * depth) * (1.0 + _run_bonus.get("gold_pct", 0.0)))})
	rewards.append({"kind": &"rest"})
	return rewards


func _heal_party(fraction: float) -> void:
	for u in party:
		if u.is_alive():
			u.hp = mini(u.max_hp, u.hp + int(u.max_hp * fraction))


## El objeto potencia durante la expedición solo a su héroe; un amuleto, al héroe
## con menos vida máxima (el más frágil).
func _add_item(item: ItemData) -> void:
	items.append(item)
	var u := wearer_of(item)
	if u == null:
		return
	u.attack += item.attack
	u.defense += item.defense
	u.max_hp += item.max_hp
	if u.is_alive():
		u.hp += item.max_hp


func wearer_of(item: ItemData) -> Unit:
	var best: Unit = null
	for u in party:
		if item.hero != &"" and u.id == item.hero:
			return u
		if item.hero == &"" and (best == null or u.max_hp < best.max_hp):
			best = u
	return best


func _add_boon(boon: BoonData) -> void:
	boons_taken.append(boon)
	# Efectos instantáneos: no quedan como modificador.
	match boon.stat:
		&"torch":
			_set_torch(torch + int(boon.value))
			return
		&"heal_pct":
			_heal_party(boon.value)
			return
	var key := String(boon.stat)
	mods[key] = mods.get(key, 0.0) + boon.value
	if boon.stat == &"max_hp_pct":
		for u in party:
			var extra := int(u.max_hp * boon.value)
			u.max_hp += extra
			if u.is_alive():
				u.hp += extra


func _check_darkness() -> void:
	# Se evalúa cuando no quedan elecciones: una recompensa de luz todavía puede salvar.
	if not finished and torch <= 0 and not has_pending_choice():
		_finish(&"darkness")


func _finish(result: StringName) -> void:
	finished = true
	outcome = result
	var ratio := keep_ratio(result)
	var sorted_items := items.duplicate()
	sorted_items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.rarity > b.rarity)
	kept = {
		"ratio": ratio,
		"gold": int(gold * ratio),
		"shards": int(shards * ratio),
		"items": sorted_items.slice(0, int(items.size() * ratio)),
		"steps": step,
		"run_id": run_id,
		"dungeon": String(dungeon_id),
		"outcome": String(result),
		"seconds": int(elapsed),
		"score": Score.compute(step, result == &"victory", int(elapsed), dungeon_id),
	}
	ended.emit(outcome, kept)


func _set_torch(value: int) -> void:
	torch = maxi(0, value)
	torch_changed.emit(torch)


func _random_enemy() -> EnemyData:
	return _enemy_pool[rng.randi_range(0, _enemy_pool.size() - 1)]


# --- autoguardado --------------------------------------------------------------

## Estado completo entre salas. Semilla y estado del RNG van como texto: son int64 y
## JSON los pasaría a float perdiendo dígitos.
func to_dict() -> Dictionary:
	var party_data: Array = []
	for u in party:
		party_data.append({"id": String(u.id), "hp": u.hp, "max_hp": u.max_hp, "attack": u.attack, "defense": u.defense})
	var plan_data: Array = []
	for doors in plan:
		plan_data.append(doors.map(func(k: StringName) -> String: return String(k)))
	var pending_data: Array = []
	for r in pending_rewards:
		match r.kind:
			&"item":
				pending_data.append({"kind": "item", "item": r.item.to_dict()})
			&"boon":
				pending_data.append({"kind": "boon", "boon": String(r.boon.id)})
			&"supplies":
				pending_data.append({"kind": "supplies", "gold": r.gold})
			&"rest":
				pending_data.append({"kind": "rest"})
	return {
		"version": RUN_VERSION, "run_id": run_id,
		"seed": str(rng.seed), "rng_state": str(rng.state),
		"torch": torch, "torch_max": torch_max, "step": step, "plan": plan_data,
		"gold": gold, "shards": shards, "mods": mods.duplicate(),
		"items": items.map(func(i: ItemData) -> Dictionary: return i.to_dict()),
		"boons": boons_taken.map(func(b: BoonData) -> String: return String(b.id)),
		"party": party_data, "pending": pending_data,
		"level": level, "xp": xp, "pending_levelups": pending_levelups,
		"levelup_options": levelup_options.map(func(b: BoonData) -> String: return String(b.id)),
		"run_bonus": _run_bonus.duplicate(),
		"saved_at": Time.get_unix_time_from_system(), "elapsed": elapsed,
		"dungeon": String(dungeon_id), "difficulty": difficulty, "boss_shards": boss_shards, "boss_power": boss_power,
	}


## Restaura un estado guardado con to_dict(). Devuelve false si no es compatible.
## Acepta v1 (sin niveles): arranca en nivel 1.
func apply_state(d: Dictionary) -> bool:
	var version := int(d.get("version", 0))
	if version < 1 or version > RUN_VERSION or not (d.get("party") is Array):
		return false
	level = int(d.get("level", 1))
	dungeon_id = StringName(str(d.get("dungeon", "catacombs")))
	difficulty = float(d.get("difficulty", 1.0))
	boss_shards = int(d.get("boss_shards", 3))
	boss_power = float(d.get("boss_power", 1.0))
	xp = int(d.get("xp", 0))
	elapsed = maxf(0.0, float(d.get("elapsed", 0.0)))
	pending_levelups = int(d.get("pending_levelups", 0))
	levelup_options.clear()
	for id in d.get("levelup_options", []):
		var option := _boon_by_id(id)
		if option != null:
			levelup_options.append(option)
	var saved_bonus = d.get("run_bonus", {})
	if saved_bonus is Dictionary:
		for k in saved_bonus:
			_run_bonus[String(k)] = float(saved_bonus[k])
	run_id = str(d.get("run_id", ""))
	rng.seed = str(d.get("seed", "0")).to_int()
	rng.state = str(d.get("rng_state", "0")).to_int()
	torch = int(d.get("torch", 0))
	torch_max = int(d.get("torch_max", torch))
	step = int(d.get("step", 0))
	gold = int(d.get("gold", 0))
	shards = int(d.get("shards", 0))
	plan.clear()
	for doors in d.get("plan", []):
		plan.append(doors.map(func(k: String) -> StringName: return StringName(k)))
	mods.clear()
	var saved_mods = d.get("mods", {})
	if saved_mods is Dictionary:
		for k in saved_mods:
			mods[String(k)] = float(saved_mods[k])
	items.clear()
	for item_data in d.get("items", []):
		items.append(ItemData.from_dict(item_data))
	boons_taken.clear()
	for id in d.get("boons", []):
		var boon := _boon_by_id(id)
		if boon != null:
			boons_taken.append(boon)
	for saved in d.party:
		for u in party:
			if String(u.id) == saved.get("id", ""):
				u.max_hp = int(saved.get("max_hp", u.max_hp))
				u.hp = clampi(int(saved.get("hp", u.hp)), 0, u.max_hp)
				u.attack = int(saved.get("attack", u.attack))
				u.defense = int(saved.get("defense", u.defense))
	pending_rewards.clear()
	for r in d.get("pending", []):
		match str(r.get("kind", "")):
			"item":
				pending_rewards.append({"kind": &"item", "item": ItemData.from_dict(r.item)})
			"boon":
				var boon := _boon_by_id(r.get("boon", ""))
				if boon != null:
					pending_rewards.append({"kind": &"boon", "boon": boon})
			"supplies":
				pending_rewards.append({"kind": &"supplies", "gold": int(r.get("gold", 0))})
			"rest":
				pending_rewards.append({"kind": &"rest"})
	if pending_levelups > 0 and levelup_options.is_empty():
		_roll_levelup_options()
	return plan.size() == STEPS and step < STEPS


func _boon_by_id(id: String) -> BoonData:
	for b in _boon_pool:
		if String(b.id) == id:
			return b
	return null
