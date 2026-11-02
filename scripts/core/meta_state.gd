class_name MetaState
extends RefCounted
## Progreso permanente entre expediciones. Se guarda en user:// (IndexedDB en web).

const SAVE_PATH := "user://save.json"
const BASE_TORCH := 5
const MAX_TORCH_LEVEL := 3

var gold := 0
var shards := 0
var attack_level := 0
var hp_level := 0
var torch_level := 0
var runs := 0
var best_step := 0
## slot -> ItemData. El mejor objeto de cada slot equipa a todo el grupo.
var equipped := {}


func upgrade_cost(kind: StringName) -> int:
	match kind:
		&"attack":
			return int(40 * pow(1.6, attack_level))
		&"hp":
			return int(40 * pow(1.6, hp_level))
		&"torch":
			return 4 * (torch_level + 1)
	return 0


func can_upgrade(kind: StringName) -> bool:
	if kind == &"torch":
		return torch_level < MAX_TORCH_LEVEL and shards >= upgrade_cost(kind)
	return gold >= upgrade_cost(kind)


func upgrade(kind: StringName) -> bool:
	if not can_upgrade(kind):
		return false
	var cost := upgrade_cost(kind)
	match kind:
		&"attack":
			gold -= cost
			attack_level += 1
		&"hp":
			gold -= cost
			hp_level += 1
		&"torch":
			shards -= cost
			torch_level += 1
	return true


func torch_start() -> int:
	return BASE_TORCH + torch_level


func hero_bonus() -> Dictionary:
	var bonus := {"attack_pct": 0.08 * attack_level, "max_hp_pct": 0.10 * hp_level, "attack": 0, "defense": 0, "max_hp": 0}
	for item: ItemData in equipped.values():
		bonus.attack += item.attack
		bonus.defense += item.defense
		bonus.max_hp += item.max_hp
	return bonus


## Suma lo conservado. Los objetos peores que el equipado se desguazan en oro.
func apply_run(kept: Dictionary) -> Dictionary:
	runs += 1
	best_step = maxi(best_step, int(kept.get("steps", 0)))
	gold += int(kept.get("gold", 0))
	shards += int(kept.get("shards", 0))
	var equipped_now: Array[ItemData] = []
	var salvage := 0
	for item: ItemData in kept.get("items", []):
		var current: ItemData = equipped.get(item.slot)
		if current == null or item.power() > current.power():
			if current != null:
				salvage += _salvage_value(current)
			equipped[item.slot] = item
			equipped_now.append(item)
		else:
			salvage += _salvage_value(item)
	gold += salvage
	return {"equipped": equipped_now, "salvage": salvage}


func to_dict() -> Dictionary:
	var eq := {}
	for slot in equipped:
		eq[String(slot)] = equipped[slot].to_dict()
	return {
		"version": 1, "gold": gold, "shards": shards, "attack_level": attack_level,
		"hp_level": hp_level, "torch_level": torch_level, "runs": runs,
		"best_step": best_step, "equipped": eq,
	}


static func from_dict(d: Dictionary) -> MetaState:
	var m := MetaState.new()
	m.gold = int(d.get("gold", 0))
	m.shards = int(d.get("shards", 0))
	m.attack_level = int(d.get("attack_level", 0))
	m.hp_level = int(d.get("hp_level", 0))
	m.torch_level = int(d.get("torch_level", 0))
	m.runs = int(d.get("runs", 0))
	m.best_step = int(d.get("best_step", 0))
	var eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		m.equipped[StringName(slot)] = ItemData.from_dict(eq[slot])
	return m


func save(path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict()))
	return OK


static func load_from(path: String = SAVE_PATH) -> MetaState:
	if not FileAccess.file_exists(path):
		return MetaState.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return from_dict(data)
	push_warning("Guardado ilegible en %s; se empieza de cero." % path)
	return MetaState.new()


func _salvage_value(item: ItemData) -> int:
	return 5 * (item.rarity + 1)
