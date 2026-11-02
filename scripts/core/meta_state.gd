class_name MetaState
extends RefCounted
## Progreso permanente entre expediciones. Se guarda en user:// (IndexedDB en web).

const SAVE_PATH := "user://save.json"
## v1: formato del prototipo inicial. v2: agrega last_run_id. v3: nombres de objetos en inglés.
## v4: las mejoras sueltas (ataque, vida, antorcha) pasan a la constelación de talentos.
const SAVE_VERSION := 4
const LEGACY_ITEM_NAMES := {
	"Espada": "Sword", "Hacha": "Axe", "Daga": "Dagger", "Maza": "Mace",
	"Coraza": "Breastplate", "Cota": "Mail", "Capa": "Cloak", "Peto": "Cuirass",
	"Amuleto": "Amulet", "Anillo": "Ring", "Talismán": "Talisman", "Reliquia": "Relic",
}
const BASE_TORCH := 5

var gold := 0
var shards := 0
## id de talento -> nivel comprado.
var talents := {}
var runs := 0
var best_step := 0
## Última expedición ya cobrada; evita cobrarla dos veces si se reanuda su autoguardado.
var last_run_id := ""
## true si el guardado en disco es de una versión más nueva del juego: no se sobrescribe.
var newer_save := false
## slot -> ItemData. El mejor objeto de cada slot equipa a todo el grupo.
var equipped := {}


func talent_level(id: StringName) -> int:
	return int(talents.get(String(id), 0))


## Desbloqueado si no tiene requisitos o si ya se compró alguno de ellos.
func is_unlocked(t: TalentData) -> bool:
	if t.requires.is_empty():
		return true
	for req in t.requires:
		if talent_level(req) > 0:
			return true
	return false


func can_buy(t: TalentData) -> bool:
	var lvl := talent_level(t.id)
	if lvl >= t.max_level or not is_unlocked(t):
		return false
	var wallet := shards if t.currency == &"shards" else gold
	return wallet >= t.cost(lvl)


func buy(t: TalentData) -> bool:
	if not can_buy(t):
		return false
	var cost := t.cost(talent_level(t.id))
	if t.currency == &"shards":
		shards -= cost
	else:
		gold -= cost
	talents[String(t.id)] = talent_level(t.id) + 1
	return true


func torch_start(catalog: Array[TalentData]) -> int:
	return BASE_TORCH + int(hero_bonus(catalog).get("torch", 0.0))


## Suma de talentos comprados y equipo. Las claves las leen Unit, Combat y Expedition.
func hero_bonus(catalog: Array[TalentData]) -> Dictionary:
	var bonus := {"attack": 0, "defense": 0, "max_hp": 0}
	for t in catalog:
		var lvl := talent_level(t.id)
		if lvl > 0:
			var key := String(t.stat)
			bonus[key] = bonus.get(key, 0.0) + t.value * lvl
	bonus.defense = int(bonus.defense)
	for item: ItemData in equipped.values():
		bonus.attack += item.attack
		bonus.defense += item.defense
		bonus.max_hp += item.max_hp
	return bonus


## Suma lo conservado. Los objetos peores que el equipado se desguazan en oro.
func apply_run(kept: Dictionary) -> Dictionary:
	runs += 1
	last_run_id = kept.get("run_id", "")
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
		"version": SAVE_VERSION, "gold": gold, "shards": shards, "talents": talents.duplicate(),
		"runs": runs, "best_step": best_step, "last_run_id": last_run_id, "equipped": eq,
	}


## Lleva un guardado de cualquier versión anterior a SAVE_VERSION, paso a paso.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2:
		d["last_run_id"] = ""
		v = 2
	if v < 3:
		var eq = d.get("equipped", {})
		if eq is Dictionary:
			for slot in eq:
				if eq[slot] is Dictionary:
					var old_name: String = eq[slot].get("display_name", "")
					eq[slot]["display_name"] = LEGACY_ITEM_NAMES.get(old_name, old_name)
		v = 3
	if v < 4:
		var migrated := {}
		for pair in [["attack_level", "might"], ["hp_level", "vitality"], ["torch_level", "torchbearer"]]:
			var lvl := int(d.get(pair[0], 0))
			if lvl > 0:
				migrated[pair[1]] = lvl
			d.erase(pair[0])
		if not migrated.is_empty():
			migrated["ember"] = 1  # raíz: requisito de los tres nodos migrados
		d["talents"] = migrated
		v = 4
	d["version"] = v
	return d


static func from_dict(d: Dictionary) -> MetaState:
	var m := MetaState.new()
	m.gold = int(d.get("gold", 0))
	m.shards = int(d.get("shards", 0))
	var saved_talents = d.get("talents", {})
	if saved_talents is Dictionary:
		for id in saved_talents:
			m.talents[String(id)] = maxi(0, int(saved_talents[id]))
	m.runs = int(d.get("runs", 0))
	m.best_step = int(d.get("best_step", 0))
	m.last_run_id = str(d.get("last_run_id", ""))
	var eq = d.get("equipped", {})
	if eq is Dictionary:
		for slot in eq:
			if eq[slot] is Dictionary:
				m.equipped[StringName(slot)] = ItemData.from_dict(eq[slot])
	return m


func save(path: String = SAVE_PATH) -> Error:
	if newer_save:
		return ERR_UNAVAILABLE
	return SaveIO.save_json(path, to_dict())


static func load_from(path: String = SAVE_PATH) -> MetaState:
	var data := SaveIO.load_json(path)
	if data.is_empty():
		return MetaState.new()
	if data.version > SAVE_VERSION:
		push_warning("El guardado es de una versión más nueva (%d); no se sobrescribe." % data.version)
		var fresh := MetaState.new()
		fresh.newer_save = true
		return fresh
	return from_dict(migrate(data))


func _salvage_value(item: ItemData) -> int:
	return 5 * (item.rarity + 1)
