extends SceneTree
## Renderiza todos los biomas x escenarios del fondo en una grilla (columnas = biomas;
## la última es la sala de entrenamiento del tutorial).
## Uso (con ventana): godot --path . --script res://tools/preview_backdrops.gd -- <archivo.png>

const TILE := Vector2i(480, 240)
const SCENES: Array[StringName] = [&"corridor", &"elite", &"shrine", &"camp", &"boss"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("backdrops.png")
	await process_frame
	var dungeons := GameData.dungeons()
	var vp := SubViewport.new()
	vp.size = Vector2i(TILE.x * (dungeons.size() + 1), TILE.y * SCENES.size())
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	for col in dungeons.size():
		var d: DungeonData = dungeons[col]
		for row in SCENES.size():
			var b := DungeonBackdrop.new()
			b.position = Vector2(col * TILE.x, row * TILE.y)
			b.size = Vector2(TILE)
			vp.add_child(b)
			b.set_biome(d.biome, d.wall_tint, d.floor_color)
			b.set_scene(SCENES[row])
	for row in SCENES.size():
		var t := DungeonBackdrop.new()
		t.position = Vector2(dungeons.size() * TILE.x, row * TILE.y)
		t.size = Vector2(TILE)
		vp.add_child(t)
		t.set_biome(&"training", Color.WHITE, Color("2a2230"))
		t.set_scene(SCENES[row])
		t.set_campfire(SCENES[row] == &"camp")
	# Dejar correr un rato para que aparezcan partículas y animaciones.
	for i in 90:
		await process_frame
	var err := vp.get_texture().get_image().save_png(out)
	print("grilla %s: %s" % [out, error_string(err)])
	quit(0)
