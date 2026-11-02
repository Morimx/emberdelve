class_name HeroData
extends Resource
## Datos base de una clase de héroe. Las clases nuevas son archivos .tres, no código.

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 2
## Ataques por segundo.
@export var speed: float = 1.0
@export_range(0.0, 1.0) var crit_chance: float = 0.05
## Habilidad automática: &"shield_wall", &"heal" o &"backstab".
@export var skill: StringName
@export var skill_name: String
@export_multiline var skill_description: String
@export var skill_cooldown: float = 6.0
@export var skill_power: float = 0.3
## Los héroes de vanguardia reciben los golpes primero.
@export var front: bool = true
