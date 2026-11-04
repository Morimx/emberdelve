extends Node
## Prueba de humo de la sala de entrenamiento: abre el juego con un guardado vacío y la
## juega sola (cartas habilitadas, clic al muñeco, habilidades pedidas) hasta que empieza
## la primera expedición. Respalda y restaura los guardados del jugador.
## Uso: godot --headless --path . res://tests/tutorial_smoke.tscn (sale con 1 si falla).
## Va como escena y no con --script para que existan los autoloads (Audio, Platform).

const SAVE_FILES: PackedStringArray = ["save.json", "save.json.bak", "run.json", "run.json.bak"]
const TIMEOUT := 90.0

var _stray_buttons := false


func _ready() -> void:
	_backup()
	var ok := await _run()
	_restore()
	print("entrenamiento: ", "OK" if ok else "FALLA")
	get_tree().quit(0 if ok else 1)


func _run() -> bool:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t := 0.0
	var started := false
	while t < TIMEOUT:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if main._training != null:
			started = true
			_drive(main)
		elif started:
			break
	if not started:
		printerr("  no arrancó la sala de entrenamiento")
		return false
	var ex: Expedition = main.expedition
	var ok: bool = ex != null and ex.dungeon_id == &"catacombs" and main.meta.tutorial_done and main.meta.gold > 0 and not _stray_buttons
	if _stray_buttons:
		printerr("  quedaron botones de habilidad fuera del combate")
	if not ok:
		printerr("  al terminar no empezó la expedición (t=%.1f)" % t)
	main.queue_free()
	return ok


## Hace lo que el entrenamiento pide en ese momento.
func _drive(main: Control) -> void:
	var run: TutorialRun = main._training
	var fight := run._fight
	if fight != null and not fight.finished:
		if fight.focus == null:
			for u in fight.enemies:
				var view: UnitView = main.unit_views.get(u)
				if view:
					view.clicked.emit(u)
					return
		for b in main._cards.get_children():
			if b is SkillButton and not b.disabled:
				b.pressed.emit()
				return
		return
	# Botones de habilidad junto a cartas = quedaron colgados de la pelea anterior.
	var kids: Array = main._cards.get_children()
	if kids.any(func(c: Node) -> bool: return c is SkillButton) and kids.any(func(c: Node) -> bool: return c is ChoiceCard):
		_stray_buttons = true
	for card in main._cards.get_children():
		if card is ChoiceCard and not card.disabled and not card.get_node("%Title").text.contains(tr("Skip training")):
			card.pressed.emit()
			return


func _backup() -> void:
	for f in SAVE_FILES:
		var p := "user://" + f
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(p, p + ".smoke")


func _restore() -> void:
	for f in SAVE_FILES:
		var p := "user://" + f
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		if FileAccess.file_exists(p + ".smoke"):
			DirAccess.rename_absolute(p + ".smoke", p)
