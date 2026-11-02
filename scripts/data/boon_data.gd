class_name BoonData
extends Resource
## Bendición temporal: dura solo la expedición en curso.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Clave del modificador: attack_pct, defense, lifesteal, crit_chance o max_hp_pct.
@export var stat: StringName
@export var value: float = 0.1
