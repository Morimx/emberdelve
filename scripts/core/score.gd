class_name Score
extends RefCounted
## Puntaje de una expedición: salas recorridas, bonus por vencer al jefe y por terminar
## rápido, multiplicado según la mazmorra (las más difíciles valen más).

const PER_ROOM := 100
const VICTORY_BONUS := 1000
## Segundos de referencia: terminar antes da puntos extra; después, ninguno.
const PAR_SECONDS := 600
const PER_SECOND_SAVED := 2
## Cuántas posiciones guarda la tabla local.
const TABLE_SIZE := 10


## El bonus por rapidez solo cuenta si se venció al jefe: morir rápido no suma.
static func compute(steps: int, victory: bool, seconds: int, dungeon: StringName) -> int:
	var points := steps * PER_ROOM
	if victory:
		points += VICTORY_BONUS + maxi(0, PAR_SECONDS - seconds) * PER_SECOND_SAVED
	return int(round(points * multiplier(dungeon)))


static func multiplier(dungeon: StringName) -> float:
	var index := maxi(0, GameData.dungeons().find(GameData.dungeon(dungeon)))
	return 1.0 + index * 0.5


## "m:ss" para mostrar el tiempo de una expedición.
static func format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
