class_name ItemData
extends Resource
## Objeto de botín generado en tiempo de ejecución. En el prototipo equipa al grupo entero.

@export var display_name: String
@export var rarity: int = 0
@export var slot: StringName
@export var attack: int = 0
@export var defense: int = 0
@export var max_hp: int = 0


func power() -> int:
	return attack * 2 + defense * 2 + max_hp / 5


func describe() -> String:
	var parts: PackedStringArray = []
	if attack > 0:
		parts.append("+%d ATQ" % attack)
	if defense > 0:
		parts.append("+%d DEF" % defense)
	if max_hp > 0:
		parts.append("+%d VIDA" % max_hp)
	return "[%s] %s (%s)" % [Loot.RARITY_NAMES[rarity], display_name, ", ".join(parts)]


func to_dict() -> Dictionary:
	return {
		"display_name": display_name, "rarity": rarity, "slot": String(slot),
		"attack": attack, "defense": defense, "max_hp": max_hp,
	}


static func from_dict(d: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.display_name = d.get("display_name", "")
	item.rarity = int(d.get("rarity", 0))
	item.slot = StringName(d.get("slot", "weapon"))
	item.attack = int(d.get("attack", 0))
	item.defense = int(d.get("defense", 0))
	item.max_hp = int(d.get("max_hp", 0))
	return item
