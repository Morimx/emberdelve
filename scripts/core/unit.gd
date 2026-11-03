class_name Unit
extends RefCounted
## Combatiente en tiempo de ejecución (héroe o enemigo). Conserva la vida entre salas.

var id: StringName
var display_name: String
var color: Color
var max_hp: int
var hp: int
var attack: int
var defense: int
var speed: float
var crit_chance: float
var skill: StringName = &""
var skill_cooldown: float = 0.0
var skill_power: float = 0.0
var front: bool = true
var is_enemy: bool = false
var gold_reward: int = 0


func is_alive() -> bool:
	return hp > 0


static func from_hero(data: HeroData, bonus: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = data.id
	u.display_name = data.display_name
	u.color = data.color
	u.max_hp = int(round(data.max_hp * (1.0 + bonus.get("max_hp_pct", 0.0)))) + int(bonus.get("max_hp", 0))
	u.hp = u.max_hp
	u.attack = int(round(data.attack * (1.0 + bonus.get("attack_pct", 0.0)))) + int(bonus.get("attack", 0))
	u.defense = data.defense + int(bonus.get("defense", 0))
	u.speed = data.speed
	u.crit_chance = data.crit_chance
	u.skill = data.skill
	# Cada nivel de habilidad: +20% de poder y -8% de enfriamiento.
	var lvl := int(bonus.get("skill_levels", {}).get(String(data.id), 1))
	u.skill_cooldown = data.skill_cooldown * (1.0 - 0.06 * (lvl - 1))
	u.skill_power = data.skill_power * (1.0 + 0.15 * (lvl - 1))
	u.front = data.front
	return u


static func from_enemy(data: EnemyData, scale: float) -> Unit:
	var u := Unit.new()
	u.id = data.id
	u.display_name = data.display_name
	u.color = data.color
	u.max_hp = int(round(data.max_hp * scale))
	u.hp = u.max_hp
	u.attack = int(round(data.attack * scale))
	u.defense = data.defense
	u.speed = data.speed
	u.crit_chance = 0.05
	u.is_enemy = true
	u.gold_reward = data.gold_reward
	return u
