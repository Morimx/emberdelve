class_name MetaState
extends RefCounted
## Progreso permanente entre expediciones. Se guarda en user:// (IndexedDB en web).

const SAVE_PATH := "user://save.json"
## v1: formato del prototipo inicial. v2: agrega last_run_id. v3: nombres de objetos en inglés.
## v4: las mejoras sueltas (ataque, vida, antorcha) pasan a la constelación de talentos.
## v5: mazmorras vencidas, depósito de objetos, niveles de habilidad y ajustes.
## v6: equipo por héroe (héroe -> slot -> objeto) y tipos de objeto por clase.
const SAVE_VERSION := 6
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
## id de héroe -> slot -> ItemData. Cada héroe tiene su arma, armadura y amuleto.
var equipped := {}
## Objetos conservados sin equipar; se equipan o desguazan en la armería.
var stash: Array[ItemData] = []
## id de mazmorra -> true cuando su jefe fue vencido.
var cleared := {}
## id de héroe -> nivel de su habilidad (1..MAX_SKILL_LEVEL).
var skill_levels := {}
## Mejores puntajes, de mayor a menor: {score, dungeon, steps, seconds, outcome, at}.
var scores: Array[Dictionary] = []
var muted := false
## Volumen general (0 a 1) e idioma elegido ("" = el del navegador).
var volume := 0.8
var language := ""
## Consejos del tutorial ya mostrados (id -> true). tips_off = el jugador los salteó.
var tips_seen := {}
var tips_off := false


func should_tip(id: String) -> bool:
	return not tips_off and not tips_seen.has(id)


func mark_tip(id: String) -> void:
	tips_seen[id] = true


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

func gear(hero_id: StringName, slot: StringName) -> ItemData:
	return equipped.get(hero_id, {}).get(slot)


static func hero_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for h: HeroData in GameData.HEROES:
		ids.append(h.id)
	return ids


## Equipa el objeto del depósito en su héroe (los amuletos, en hero_id); lo que había
## en ese slot vuelve al depósito.
func equip_from_stash(index: int, hero_id: StringName = &"") -> bool:
	if index < 0 or index >= stash.size():
		return false
	var item := stash[index]
	var target := item.hero if item.hero != &"" else hero_id
	if target == &"" or not item.can_equip(target) or not target in hero_ids():
		return false
	var previous := gear(target, item.slot)
	_set_gear(target, item)
	stash.remove_at(index)
	if previous != null:
		stash.insert(index, previous)
	return true


func _set_gear(hero_id: StringName, item: ItemData) -> void:
	if not equipped.has(hero_id):
		equipped[hero_id] = {}
	equipped[hero_id][item.slot] = item


## Héroe con el slot libre para este objeto, o &"" si no hay ninguno.
func _free_hero_for(item: ItemData) -> StringName:
	for id in hero_ids():
		if item.can_equip(id) and gear(id, item.slot) == null:
			return id
	return &""


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
	# Equipo: suma propia de cada héroe (Unit.from_hero la lee con su id).
	var per_hero := {}
	for hero_id in equipped:
		var sum := {"attack": 0, "defense": 0, "max_hp": 0}
		for item: ItemData in equipped[hero_id].values():
			sum.attack += item.attack
			sum.defense += item.defense
			sum.max_hp += item.max_hp
		per_hero[hero_id] = sum
	bonus["gear"] = per_hero
	bonus["skill_levels"] = skill_levels.duplicate()
	return bonus


## Suma lo conservado. Un objeto ocupa el slot libre de su héroe; si no hay, va al depósito.
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
	var rank := add_score(kept)
	var equipped_now: Array[ItemData] = []
	var stashed := 0
	var salvage := 0
	for item: ItemData in kept.get("items", []):
		var target := _free_hero_for(item)
		if target != &"":
			_set_gear(target, item)
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
	return {"equipped": equipped_now, "stashed": stashed, "salvage": salvage, "first_clear": first_clear, "rank": rank}


## Anota el puntaje de una expedición en la tabla. Devuelve su posición (0 = la mejor)
## o -1 si no entró entre las TABLE_SIZE mejores.
func add_score(kept: Dictionary) -> int:
	var entry := {
		"score": int(kept.get("score", 0)), "dungeon": str(kept.get("dungeon", "catacombs")),
		"steps": int(kept.get("steps", 0)), "seconds": int(kept.get("seconds", 0)),
		"outcome": str(kept.get("outcome", "")), "at": int(Time.get_unix_time_from_system()),
	}
	if entry.score <= 0:
		return -1
	var rank := scores.size()
	for i in scores.size():
		if entry.score > int(scores[i].score):
			rank = i
			break
	if rank >= Score.TABLE_SIZE:
		return -1
	scores.insert(rank, entry)
	if scores.size() > Score.TABLE_SIZE:
		scores.resize(Score.TABLE_SIZE)
	return rank


func best_score() -> int:
	return int(scores[0].score) if not scores.is_empty() else 0


func to_dict() -> Dictionary:
	var eq := {}
	for hero_id in equipped:
		var slots := {}
		for slot in equipped[hero_id]:
			slots[String(slot)] = equipped[hero_id][slot].to_dict()
		eq[String(hero_id)] = slots
	return {
		"version": SAVE_VERSION, "gold": gold, "shards": shards, "talents": talents.duplicate(),
		"runs": runs, "best_step": best_step, "last_run_id": last_run_id, "equipped": eq,
		"stash": stash.map(func(i: ItemData) -> Dictionary: return i.to_dict()),
		"cleared": cleared.duplicate(), "skill_levels": skill_levels.duplicate(),
		"scores": scores.duplicate(true),
		"settings": {"muted": muted, "volume": volume, "language": language},
		"tips": {"seen": tips_seen.keys(), "off": tips_off},
		"saved_at": Time.get_unix_time_from_system(),
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
	if v < 6:
		# El equipo de grupo (slot -> objeto) pasa a su héroe según el tipo del objeto.
		var by_hero := {}
		var old_eq = d.get("equipped", {})
		var leftovers: Array = []
		if old_eq is Dictionary:
			for slot in old_eq:
				if old_eq[slot] is Dictionary:
					var item := ItemData.from_dict(old_eq[slot])
					var hero := String(item.hero) if item.hero != &"" else "warrior"
					if not by_hero.has(hero):
						by_hero[hero] = {}
					if by_hero[hero].has(String(item.slot)):
						leftovers.append(item.to_dict())
					else:
						by_hero[hero][String(item.slot)] = item.to_dict()
		d["equipped"] = by_hero
		var stash_list: Array = []
		for raw in d.get("stash", []):
			if raw is Dictionary:
				stash_list.append(ItemData.from_dict(raw).to_dict())
		d["stash"] = stash_list + leftovers
		v = 6
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
		for hero_id in eq:
			if not eq[hero_id] is Dictionary:
				continue
			for slot in eq[hero_id]:
				if eq[hero_id][slot] is Dictionary:
					var item := ItemData.from_dict(eq[hero_id][slot])
					if item.can_equip(StringName(hero_id)):
						m._set_gear(StringName(hero_id), item)
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
	for entry in d.get("scores", []):
		if entry is Dictionary and m.scores.size() < Score.TABLE_SIZE:
			m.scores.append({
				"score": int(entry.get("score", 0)), "dungeon": str(entry.get("dungeon", "catacombs")),
				"steps": int(entry.get("steps", 0)), "seconds": int(entry.get("seconds", 0)),
				"outcome": str(entry.get("outcome", "")), "at": int(entry.get("at", 0)),
			})
	m.scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var settings = d.get("settings", {})
	if settings is Dictionary:
		m.muted = bool(settings.get("muted", false))
		m.volume = clampf(float(settings.get("volume", 0.8)), 0.0, 1.0)
		m.language = String(settings.get("language", ""))
	# Guardados de antes del tutorial: quien ya jugó no necesita los consejos.
	var tips = d.get("tips", {"off": m.runs > 0})
	if tips is Dictionary:
		m.tips_off = bool(tips.get("off", false))
		var seen = tips.get("seen", [])
		if seen is Array:
			for id in seen:
				m.tips_seen[str(id)] = true
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

