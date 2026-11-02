class_name TalentData
extends Resource
## Nodo de la constelación de talentos (progreso permanente).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Sprite de SpriteBank para el icono.
@export var icon: StringName = &"gem"
## Región visual: &"steel", &"fortune", &"path" o &"root".
@export var branch: StringName = &"root"
## Posición en el mapa, normalizada 0..1 (y crece hacia abajo).
@export var pos: Vector2 = Vector2(0.5, 0.5)
@export var max_level: int = 1
## &"gold" o &"shards".
@export var currency: StringName = &"gold"
@export var base_cost: int = 40
@export var cost_growth: float = 1.6
## Clave del bono: attack_pct, max_hp_pct, defense, crit_chance, lifesteal, speed_pct,
## skill_power_pct, gold_pct, xp_pct, luck, torch o camp_torch.
@export var stat: StringName
## Valor por nivel.
@export var value: float = 0.0
## Basta con tener uno de estos nodos para desbloquear este.
@export var requires: Array[StringName] = []
## Nodo clave: se dibuja más grande.
@export var key: bool = false


func cost(current_level: int) -> int:
	return int(round(base_cost * pow(cost_growth, current_level)))
