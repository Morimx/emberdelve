class_name Loot
extends RefCounted
## Tabla de rarezas y generación procedural de objetos.

const RARITY_NAMES: PackedStringArray = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color("9ea3b0"), Color("5fbf4a"), Color("4a8fe0"), Color("b065ec"), Color("f08a24"),
]
const RARITY_WEIGHTS: PackedFloat32Array = [60.0, 25.0, 11.0, 3.5, 0.5]
const SLOTS: Array[StringName] = [&"weapon", &"armor", &"charm"]
const SLOT_NAMES := {&"weapon": "Weapon", &"armor": "Armor", &"charm": "Charm"}
const BASE_NAMES := {
	&"weapon": ["Sword", "Axe", "Dagger", "Mace"],
	&"armor": ["Breastplate", "Mail", "Cloak", "Cuirass"],
	&"charm": ["Amulet", "Ring", "Talisman", "Relic"],
}


## luck desplaza la tirada hacia rarezas más altas (élites y jefes usan 1 o 2).
static func roll_rarity(rng: RandomNumberGenerator, luck: int = 0) -> int:
	var total := 0.0
	for w in RARITY_WEIGHTS:
		total += w
	var roll := rng.randf() * total
	var rarity := RARITY_WEIGHTS.size() - 1
	for i in RARITY_WEIGHTS.size():
		roll -= RARITY_WEIGHTS[i]
		if roll <= 0.0:
			rarity = i
			break
	return mini(rarity + luck, RARITY_WEIGHTS.size() - 1)


static func roll_item(rng: RandomNumberGenerator, depth: int, luck: int = 0) -> ItemData:
	var item := ItemData.new()
	item.rarity = roll_rarity(rng, luck)
	item.slot = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	var names: Array = BASE_NAMES[item.slot]
	item.display_name = names[rng.randi_range(0, names.size() - 1)]
	var value := (2.0 + depth * 0.5) * (1.0 + item.rarity * 0.6)
	match item.slot:
		&"weapon":
			item.attack = maxi(1, int(round(value)))
		&"armor":
			item.defense = maxi(1, int(round(value * 0.5)))
			item.max_hp = int(round(value * 4.0))
		&"charm":
			item.attack = int(round(value * 0.4))
			item.max_hp = int(round(value * 3.0))
	return item
