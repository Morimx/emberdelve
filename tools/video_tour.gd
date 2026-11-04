extends Node
## Recorrido automático para los videos de vista previa de CrazyGames (15-20 s, sin cursor).
## Se graba con el Movie Maker de Godot, que avanza a fps fijos:
##   godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 res://tools/video_tour.tscn
## Empieza con la portada (lo pide CrazyGames) y juega solo. Respalda y restaura los guardados.

const DURATION := 19.0
const SAVE_FILES: PackedStringArray = ["save.json", "save.json.bak", "run.json", "run.json.bak"]

var main: Control
var _cover: TextureRect
var _elapsed := 0.0


func _ready() -> void:
	seed(20261102)
	_backup()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_add_cover()
	await get_tree().process_frame
	await get_tree().process_frame
	main.meta = _demo_meta()
	Locale.apply("en")  # el video de la ficha va en inglés
	main.speed_index = 1
	main._show_camp("")
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		set_process(false)
		_restore()
		get_tree().quit()


func _run() -> void:
	await _wait(1.4)
	var tw := create_tween()
	tw.tween_property(_cover, "modulate:a", 0.0, 0.5)
	await _wait(1.2)
	main._show_dungeon_select()
	await _wait(1.0)
	main._start_expedition(&"catacombs")
	for room in 3:
		await _wait(0.9)
		var doors: Array = main.expedition.current_doors()
		var pick: StringName = &"combat" if &"combat" in doors else (&"elite" if &"elite" in doors else doors[0])
		main._on_door(pick)
		await _wait(0.4)  # el fundido de la puerta va antes de que empiece la sala
		while main._cards.has_meta("busy"):
			_cast_ready_skills()
			await get_tree().process_frame
		if main.expedition.finished:
			return
		await _wait(1.0)
		if main.expedition.pending_levelups > 0:
			main._on_levelup(0)
			await _wait(1.0)
		if not main.expedition.pending_rewards.is_empty():
			main._on_reward(0)


## Lanza las habilidades apenas están listas, como lo haría un jugador atento.
func _cast_ready_skills() -> void:
	var fight: Combat = main.expedition.fight if main.expedition else null
	if fight == null:
		return
	for u: Unit in fight.party:
		if fight.skill_ready(u):
			fight.request_skill(u)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _add_cover() -> void:
	var size := get_viewport().get_visible_rect().size
	var portrait := size.y > size.x
	var file := "cover_portrait_800x1200.png" if portrait else "cover_landscape_1920x1080.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://").path_join("../release/covers/" + file))
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_cover = TextureRect.new()
	_cover.texture = ImageTexture.create_from_image(image) if image else null
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_cover)


## Un progreso intermedio: el grupo pega fuerte y la pelea luce.
func _demo_meta() -> MetaState:
	var m := MetaState.new()
	m.gold = 340
	m.shards = 6
	m.talents = {"ember": 1, "might": 2, "vitality": 2, "keen_edge": 1}
	m.skill_levels = {"warrior": 2, "cleric": 2, "assassin": 2}
	m.runs = 3
	m.tips_off = true  # sin consejos del tutorial en el video
	return m


func _backup() -> void:
	for f in SAVE_FILES:
		var p := "user://" + f
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(p, p + ".video")


func _restore() -> void:
	for f in SAVE_FILES:
		var p := "user://" + f
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		if FileAccess.file_exists(p + ".video"):
			DirAccess.rename_absolute(p + ".video", p)
