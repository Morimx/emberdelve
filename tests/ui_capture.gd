extends SceneTree
## Recorre la UI sola y guarda capturas: campamento, puertas, combate y recompensa.
## Uso (con ventana, no headless): godot --path . --script res://tests/ui_capture.gd -- <carpeta_salida>
## Respalda los guardados del jugador antes de empezar y los restaura al terminar.

const SAVE_FILES: PackedStringArray = ["save.json", "save.json.bak", "run.json", "run.json.bak"]

var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	await process_frame
	_backup()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	_shot("1_camp")
	main._open_talents()
	await _frames(10)
	_shot("1b_talents")
	main._close_talents()
	await _frames(5)
	main._open_armory()
	await _frames(10)
	_shot("1c_armory")
	main._close_armory(main._overlay)
	await _frames(5)
	main._show_skills()
	await _frames(5)
	_shot("1d_skills")
	main._show_dungeon_select()
	await _frames(5)
	_shot("1e_dungeons")

	main.speed_index = 1
	main._start_expedition()
	await _frames(10)
	_shot("2_doors")

	main._on_door(&"combat")
	await create_timer(1.4).timeout
	_shot("3_combat")
	var waited := 0.0
	while main._cards.has_meta("busy") and waited < 30.0:
		await create_timer(0.25).timeout
		waited += 0.25
	await _frames(10)
	_shot("4_after_combat")
	if main.expedition.pending_levelups > 0:
		main._on_levelup(0)
		await _frames(10)
		_shot("5_reward")

	main.queue_free()
	await _frames(2)
	_restore()
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	var path := _out.path_join("%s.png" % name)
	var err := root.get_texture().get_image().save_png(path)
	print("captura %s: %s" % [path, error_string(err)])


func _backup() -> void:
	for f in SAVE_FILES:
		var p := "user://" + f
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(p, p + ".capture")


func _restore() -> void:
	for f in SAVE_FILES:
		var p := "user://" + f
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		if FileAccess.file_exists(p + ".capture"):
			DirAccess.rename_absolute(p + ".capture", p)
