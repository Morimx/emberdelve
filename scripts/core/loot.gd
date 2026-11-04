class_name Loot
extends RefCounted
## Tabla de rarezas y generación procedural de objetos.
## Cada tipo de objeto pertenece a una clase de héroe (o a cualquiera, los amuletos)
## y reparte su valor entre ataque, defensa y vida con sus propios pesos.

const RARITY_NAMES: PackedStringArray = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color("9ea3b0"), Color("5fbf4a"), Color("4a8fe0"), Color("b065ec"), Color("f08a24"),
]
const RARITY_WEIGHTS: PackedFloat32Array = [60.0, 25.0, 11.0, 3.5, 0.5]
const SLOTS: Array[StringName] = [&"weapon", &"armor", &"charm"]
const SLOT_NAMES := {&"weapon": "Weapon", &"armor": "Armor", &"charm": "Charm"}
## Un objeto de un solo héroe vale más que uno que antes equipaba a todo el grupo.
const HERO_ITEM_POWER := 0.6
## Tipo -> nombre, slot, héroe ("" = cualquiera) y pesos de ataque, defensa y vida.
const BASES := {
	&"sword": {"name": "Sword", "slot": &"weapon", "hero": &"warrior", "atk": 1.0, "def": 0.0, "hp": 0.0},
	&"axe": {"name": "Axe", "slot": &"weapon", "hero": &"warrior", "atk": 1.25, "def": 0.0, "hp": 0.0},
	&"mace": {"name": "Mace", "slot": &"weapon", "hero": &"warrior", "atk": 0.8, "def": 0.2, "hp": 0.0},
	&"plate": {"name": "Plate Armor", "slot": &"armor", "hero": &"warrior", "atk": 0.0, "def": 0.6, "hp": 3.0},
	&"mail": {"name": "Chainmail", "slot": &"armor", "hero": &"warrior", "atk": 0.0, "def": 0.4, "hp": 4.5},
	&"staff": {"name": "Staff", "slot": &"weapon", "hero": &"cleric", "atk": 0.6, "def": 0.0, "hp": 2.0},
	&"scepter": {"name": "Scepter", "slot": &"weapon", "hero": &"cleric", "atk": 0.85, "def": 0.0, "hp": 1.0},
	&"robe": {"name": "Robe", "slot": &"armor", "hero": &"cleric", "atk": 0.0, "def": 0.2, "hp": 5.5},
	&"vestments": {"name": "Vestments", "slot": &"armor", "hero": &"cleric", "atk": 0.2, "def": 0.3, "hp": 4.0},
	&"dagger": {"name": "Dagger", "slot": &"weapon", "hero": &"assassin", "atk": 1.1, "def": 0.0, "hp": 0.0},
	&"twin_daggers": {"name": "Twin Daggers", "slot": &"weapon", "hero": &"assassin", "atk": 1.35, "def": 0.0, "hp": 0.0},
	&"crossbow": {"name": "Crossbow", "slot": &"weapon", "hero": &"assassin", "atk": 1.0, "def": 0.1, "hp": 0.0},
	&"leather": {"name": "Leather Vest", "slot": &"armor", "hero": &"assassin", "atk": 0.15, "def": 0.35, "hp": 3.0},
	&"cloak": {"name": "Cloak", "slot": &"armor", "hero": &"assassin", "atk": 0.3, "def": 0.2, "hp": 2.5},
	&"amulet": {"name": "Amulet", "slot": &"charm", "hero": &"", "atk": 0.4, "def": 0.0, "hp": 3.0},
	&"ring": {"name": "Ring", "slot": &"charm", "hero": &"", "atk": 0.6, "def": 0.0, "hp": 1.5},
	&"talisman": {"name": "Talisman", "slot": &"charm", "hero": &"", "atk": 0.0, "def": 0.3, "hp": 3.0},
	&"relic": {"name": "Relic", "slot": &"charm", "hero": &"", "atk": 0.3, "def": 0.15, "hp": 2.0},
}
## Nombres de guardados viejos (equipo de grupo) -> tipo nuevo.
const LEGACY_BASES := {
	"Sword": &"sword", "Axe": &"axe", "Mace": &"mace", "Dagger": &"dagger",
	"Breastplate": &"plate", "Cuirass": &"plate", "Mail": &"mail", "Cloak": &"cloak",
	"Amulet": &"amulet", "Ring": &"ring", "Talisman": &"talisman", "Relic": &"relic",
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
	var rarity := roll_rarity(rng, luck)
	var slot: StringName = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	var options: Array = BASES.keys().filter(func(b: StringName) -> bool: return BASES[b].slot == slot)
	return make_item(options[rng.randi_range(0, options.size() - 1)], rarity, depth)


## Objeto de un tipo y rareza dados, con valores según la profundidad.
static func make_item(base: StringName, rarity: int, depth: int) -> ItemData:
	var def: Dictionary = BASES[base]
	var item := ItemData.new()
	item.base = base
	item.display_name = def.name
	item.slot = def.slot
	item.hero = def.hero
	item.rarity = rarity
	var value := (2.0 + depth * 0.5) * (1.0 + rarity * 0.6) * HERO_ITEM_POWER
	item.attack = maxi(0, int(round(value * def.atk)))
	item.defense = maxi(0, int(round(value * 0.5 * def.def)))
	item.max_hp = maxi(0, int(round(value * def.hp)))
	if def.slot == &"weapon":
		item.attack = maxi(1, item.attack)
	# Hasta el objeto más flojo aporta algo en su stat principal.
	if item.power() == 0:
		if def.hp >= def.atk and def.hp >= def.def:
			item.max_hp = maxi(item.max_hp, 5)
		elif def.def >= def.atk:
			item.defense = 1
		else:
			item.attack = 1
	return item
