class_name Expedition
extends RefCounted
## Una expedición: 2 pisos de 4 salas y un jefe. Cada sala gasta luz de la antorcha.
## Retirarse o vencer al jefe conserva todo el botín; caer o quedarse sin luz, la mitad.

signal torch_changed(value: int)
signal ended(outcome: StringName, kept: Dictionary)

const STEPS := 9
const ROOMS_PER_FLOOR := 4
const TORCH_COST := {&"combat": 1, &"elite": 2, &"event": 1, &"camp": 1, &"boss": 1}
const CAMP_TORCH := 3
const CAMP_HEAL := 0.4
const SUPPLIES_TORCH := 2
const DOOR_WEIGHTS := {&"combat": 3.0, &"elite": 1.0, &"event": 2.0}

var rng := RandomNumberGenerator.new()
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
var finished := false
var outcome: StringName = &""
var kept := {}

var _enemy_pool: Array[EnemyData]
var _boss: EnemyData
var _boon_pool: Array[BoonData]


func _init(heroes: Array[HeroData], enemy_pool: Array[EnemyData], boss: EnemyData, boons: Array[BoonData], hero_bonus: Dictionary, torch_start: int, seed_value: int) -> void:
	rng.seed = seed_value
	_enemy_pool = enemy_pool
	_boss = boss
	_boon_pool = boons
	for h in heroes:
		party.append(Unit.from_hero(h, hero_bonus))
	torch = torch_start
	torch_max = torch_start
	_generate_plan()


func current_doors() -> Array:
	return plan[step] if step < plan.size() else []


func can_enter(kind: StringName) -> bool:
	return not finished and pending_rewards.is_empty() and kind in current_doors() and torch >= TORCH_COST[kind]


func can_retreat() -> bool:
	return not finished and pending_rewards.is_empty()


## Resuelve una sala. Devuelve lo necesario para que la UI la muestre.
func enter(kind: StringName) -> Dictionary:
	assert(can_enter(kind), "No se puede entrar a %s" % kind)
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
			_set_torch(torch + CAMP_TORCH)
			for u in party:
				u.hp = mini(u.max_hp, maxi(u.hp, 1) + int(u.max_hp * CAMP_HEAL))
			result["text"] = "Campamento: +%d de luz y el grupo se recupera." % CAMP_TORCH
	return result


func choose_reward(index: int) -> void:
	assert(index >= 0 and index < pending_rewards.size())
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
	_check_darkness()


func retreat() -> void:
	assert(can_retreat())
	_finish(&"retreat")


func floor_label() -> String:
	if step >= STEPS - 1:
		return "Guarida del jefe"
	return "Piso %d · Sala %d/%d" % [step / ROOMS_PER_FLOOR + 1, step % ROOMS_PER_FLOOR + 1, ROOMS_PER_FLOOR]


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
	var scale := 1.0 + 0.12 * depth
	var enemies: Array[Unit] = []
	match kind:
		&"combat":
			for i in rng.randi_range(2, 3):
				enemies.append(Unit.from_enemy(_random_enemy(), scale))
		&"elite":
			var elite := Unit.from_enemy(_random_enemy(), scale * 1.8)
			elite.display_name += " élite"
			enemies.append(elite)
			enemies.append(Unit.from_enemy(_random_enemy(), scale))
		&"boss":
			enemies.append(Unit.from_enemy(_boss, 1.0))
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
	for e in enemies:
		gold += int(e.gold_reward * scale)
	if kind == &"elite":
		shards += 1
	if kind == &"boss":
		shards += 3
		_finish(&"victory")
		return
	pending_rewards = _roll_rewards(kind, depth)


func _resolve_event(result: Dictionary) -> void:
	match rng.randi_range(0, 2):
		0:
			_set_torch(torch + 1)
			result["text"] = "Santuario: una llama azul aviva la antorcha (+1 de luz)."
		1:
			for u in party:
				if u.is_alive():
					u.hp = maxi(1, u.hp - int(u.max_hp * 0.15))
			result["text"] = "Trampa: el grupo pierde un 15% de vida."
		2:
			var item := Loot.roll_item(rng, step)
			_add_item(item)
			gold += 30
			result["text"] = "Cofre olvidado: %s y 30 de oro." % item.describe()


func _roll_rewards(kind: StringName, depth: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var luck := 1 if kind == &"elite" else 0
	rewards.append({"kind": &"item", "item": Loot.roll_item(rng, depth, luck)})
	var available := _boon_pool.filter(func(b: BoonData) -> bool: return b not in boons_taken)
	if not available.is_empty():
		rewards.append({"kind": &"boon", "boon": available[rng.randi_range(0, available.size() - 1)]})
	rewards.append({"kind": &"supplies", "gold": 40 + 10 * depth})
	return rewards


func _add_item(item: ItemData) -> void:
	items.append(item)
	for u in party:
		u.attack += item.attack
		u.defense += item.defense
		u.max_hp += item.max_hp
		if u.is_alive():
			u.hp += item.max_hp


func _add_boon(boon: BoonData) -> void:
	boons_taken.append(boon)
	mods[boon.stat] = mods.get(boon.stat, 0.0) + boon.value
	if boon.stat == &"max_hp_pct":
		for u in party:
			var extra := int(u.max_hp * boon.value)
			u.max_hp += extra
			if u.is_alive():
				u.hp += extra


func _check_darkness() -> void:
	if not finished and torch <= 0:
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
	}
	ended.emit(outcome, kept)


func _set_torch(value: int) -> void:
	torch = maxi(0, value)
	torch_changed.emit(torch)


func _random_enemy() -> EnemyData:
	return _enemy_pool[rng.randi_range(0, _enemy_pool.size() - 1)]
