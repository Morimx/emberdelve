class_name ItemData
extends Resource
## Objeto de botín generado en tiempo de ejecución. Lo usa un solo héroe: el de su clase
## (hero) o, si es un amuleto (hero vacío), el que lo equipe.

@export var display_name: String
@export var rarity: int = 0
@export var slot: StringName
## Tipo de objeto (clave de Loot.BASES); también es el id de su icono.
@export var base: StringName
## Héroe que puede usarlo; vacío = cualquiera.
@export var hero: StringName
@export var attack: int = 0
@export var defense: int = 0
@export var max_hp: int = 0


func can_equip(hero_id: StringName) -> bool:
	return hero == &"" or hero == hero_id


## Icono propio del tipo si existe; si no, el genérico del slot.
func icon_id() -> StringName:
	return base if SpriteBank.has_sprite(base) else slot


func power() -> int:
	return attack * 2 + defense * 2 + max_hp / 5


func describe() -> String:
	var parts: PackedStringArray = []
	if attack > 0:
		parts.append("+%d ATK" % attack)
	if defense > 0:
		parts.append("+%d DEF" % defense)
	if max_hp > 0:
		parts.append("+%d HP" % max_hp)
	return "[%s] %s (%s)" % [Loot.RARITY_NAMES[rarity], display_name, ", ".join(parts)]


func to_dict() -> Dictionary:
	return {
		"display_name": display_name, "rarity": rarity, "slot": String(slot),
		"attack": attack, "defense": defense, "max_hp": max_hp,
		"base": String(base), "hero": String(hero),
	}


static func from_dict(d: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.display_name = d.get("display_name", "")
	item.rarity = int(d.get("rarity", 0))
	item.slot = StringName(d.get("slot", "weapon"))
	item.attack = int(d.get("attack", 0))
	item.defense = int(d.get("defense", 0))
	item.max_hp = int(d.get("max_hp", 0))
	if d.has("base"):
		item.base = StringName(d.base)
		item.hero = StringName(d.get("hero", ""))
	else:
		# Objeto de antes del equipo por héroe: se deduce el tipo por su nombre.
		item.base = Loot.LEGACY_BASES.get(item.display_name, &"amulet" if item.slot == &"charm" else (&"sword" if item.slot == &"weapon" else &"plate"))
		var def: Dictionary = Loot.BASES[item.base]
		item.hero = def.hero
		item.slot = def.slot
		item.display_name = def.name
	return item
