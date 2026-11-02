class_name MetaState
extends RefCounted
## Progreso permanente entre expediciones. Se guarda en user:// (IndexedDB en web).

const SAVE_PATH := "user://save.json"
## v1: formato del prototipo inicial. v2: agrega last_run_id. v3: nombres de objetos en inglés.
## v4: las mejoras sueltas (ataque, vida, antorcha) pasan a la constelación de talentos.
## v5: mazmorras vencidas, depósito de objetos, niveles de habilidad y ajustes.
const SAVE_VERSION := 5
const STASH_MAX := 24
const MAX_SKILL_LEVEL := 5
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
## slot -> ItemData. El objeto de cada slot equipa a todo el grupo.
var equipped := {}
## Objetos conservados sin equipar; se equipan o desguazan en la armería.
var stash: Array[ItemData] = []
## id de mazmorra -> true cuando su jefe fue vencido.
var cleared := {}
## id de héroe -> nivel de su habilidad (1..MAX_SKILL_LEVEL).
var skill_levels := {}
var muted := false


func is_dungeon_unlocked(d: DungeonData) -> bool:
	return d.unlock_after == &"" or cleared.has(String(d.unlock_after))


# --- habilidades -----------------------------------------------------------------

func skill_level(hero_id: StringName) -> int:
	return int(skill_levels.get(String(hero_id), 1))


func skill_cost(hero_id: StringName) -> int:
	return 3 * skill_level(hero_id)


func can_upgrade_skill(hero_id: StringName) -> bool:
	return skill_level(hero_id) < MAX_SKILL_LEVEL and shards >= skill_cost(hero_id)


func upgrade_skill(hero_id: StringName) -> bool:
	if not can_upgrade_skill(hero_id):
		return false
	shards -= skill_cost(hero_id)
	skill_levels[String(hero_id)] = skill_level(hero_id) + 1
	return true


# --- armería ---------------------------------------------------------------------

## Equipa el objeto del depósito; el que estaba en ese slot vuelve al depósito.
func equip_from_stash(index: int) -> bool:
	if index < 0 or index >= stash.size():
		return false
	var item := stash[index]
	var previous: ItemData = equipped.get(item.slot)
	equipped[item.slot] = item
	stash.remove_at(index)
	if previous != null:
		stash.insert(index, previous)
	return true


func salvage_from_stash(index: int) -> int:
	if index < 0 or index >= stash.size():
		return 0
	var value := salvage_value(stash[index])
	stash.remove_at(index)
	gold += value
	return value


## Desguaza todos los comunes del depósito. Devuelve el oro obtenido.
func salvage_commons() -> int:
	var total := 0
	for i in range(stash.size() - 1, -1, -1):
		if stash[i].rarity == 0:
			total += salvage_from_stash(i)
	return total


func salvage_value(item: ItemData) -> int:
	return 5 * (item.rarity + 1)


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
	bonus["skill_levels"] = skill_levels.duplicate()
	return bonus


## Suma lo conservado. Un objeto ocupa su slot si está vacío; si no, va al depósito.
## Con el depósito lleno, el objeto de menor poder se desguaza en oro.
func apply_run(kept: Dictionary) -> Dictionary:
	runs += 1
	last_run_id = kept.get("run_id", "")
	best_step = maxi(best_step, int(kept.get("steps", 0)))
	gold += int(kept.get("gold", 0))
	shards += int(kept.get("shards", 0))
	var first_clear := false
	if kept.get("outcome", "") == "victory":
		var dungeon := str(kept.get("dungeon", "catacombs"))
		first_clear = not cleared.has(dungeon)
		cleared[dungeon] = true
	var equipped_now: Array[ItemData] = []
	var stashed := 0
	var salvage := 0
	for item: ItemData in kept.get("items", []):
		if equipped.get(item.slot) == null:
			equipped[item.slot] = item
			equipped_now.append(item)
		else:
			stash.append(item)
			stashed += 1
	while stash.size() > STASH_MAX:
		var worst := 0
		for i in stash.size():
			if stash[i].power() < stash[worst].power():
				worst = i
		salvage += salvage_from_stash(worst)
	return {"equipped": equipped_now, "stashed": stashed, "salvage": salvage, "first_clear": first_clear}


func to_dict() -> Dictionary:
	var eq := {}
	for slot in equipped:
		eq[String(slot)] = equipped[slot].to_dict()
	return {
		"version": SAVE_VERSION, "gold": gold, "shards": shards, "talents": talents.duplicate(),
		"runs": runs, "best_step": best_step, "last_run_id": last_run_id, "equipped": eq,
		"stash": stash.map(func(i: ItemData) -> Dictionary: return i.to_dict()),
		"cleared": cleared.duplicate(), "skill_levels": skill_levels.duplicate(),
		"settings": {"muted": muted},
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
	if v < 5:
		# Antes, vencer al jefe no se registraba: si alguien llegó a la sala final de las
		# Catacumbas, se lo considera vencido para no bloquearle la segunda mazmorra.
		d["cleared"] = {"catacombs": true} if int(d.get("best_step", 0)) >= 9 else {}
		d["stash"] = []
		d["skill_levels"] = {}
		v = 5
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
	for item_data in d.get("stash", []):
		if item_data is Dictionary:
			m.stash.append(ItemData.from_dict(item_data))
	var saved_cleared = d.get("cleared", {})
	if saved_cleared is Dictionary:
		for id in saved_cleared:
			m.cleared[String(id)] = true
	var saved_skills = d.get("skill_levels", {})
	if saved_skills is Dictionary:
		for id in saved_skills:
			m.skill_levels[String(id)] = clampi(int(saved_skills[id]), 1, MAX_SKILL_LEVEL)
	var settings = d.get("settings", {})
	if settings is Dictionary:
		m.muted = bool(settings.get("muted", false))
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

