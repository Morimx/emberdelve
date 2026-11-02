class_name GameData
extends RefCounted
## Registro del contenido. Para sumar héroes, enemigos o bendiciones: crear el .tres y listarlo acá.

const HEROES := [
	preload("res://data/heroes/warrior.tres"),
	preload("res://data/heroes/cleric.tres"),
	preload("res://data/heroes/assassin.tres"),
]
const ENEMIES := [
	preload("res://data/enemies/skeleton.tres"),
	preload("res://data/enemies/bat.tres"),
	preload("res://data/enemies/slime.tres"),
]
const BOSS := preload("res://data/enemies/lich.tres")
const BOONS := [
	preload("res://data/boons/blood_edge.tres"),
	preload("res://data/boons/stone_skin.tres"),
	preload("res://data/boons/keen_eye.tres"),
	preload("res://data/boons/war_cry.tres"),
	preload("res://data/boons/vigor.tres"),
]


static func heroes() -> Array[HeroData]:
	var out: Array[HeroData] = []
	out.assign(HEROES)
	return out


static func enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	out.assign(ENEMIES)
	return out


static func boons() -> Array[BoonData]:
	var out: Array[BoonData] = []
	out.assign(BOONS)
	return out


static func new_expedition(meta: MetaState, seed_value: int) -> Expedition:
	return Expedition.new(heroes(), enemies(), BOSS, boons(), meta.hero_bonus(), meta.torch_start(), seed_value)


static func restore_expedition(data: Dictionary) -> Expedition:
	var ex := Expedition.new(heroes(), enemies(), BOSS, boons(), {}, 0, 0)
	return ex if ex.apply_state(data) else null
