class_name DungeonData
extends Resource
## Una mazmorra: su elenco de enemigos, su jefe, su dificultad y su paleta.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var enemies: Array[EnemyData] = []
@export var boss: EnemyData
## Multiplica vida y ataque de todos los enemigos (y por lo tanto el oro que sueltan).
@export var difficulty: float = 1.0
## Esquirlas extra al vencer al jefe.
@export var boss_shards: int = 3
## Mazmorra cuyo jefe hay que vencer para desbloquear esta. Vacío = abierta.
@export var unlock_after: StringName
@export var wall_tint: Color = Color(0.8, 0.8, 0.95)
@export var floor_color: Color = Color("141a3d")
