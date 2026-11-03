extends SceneTree
## Genera las portadas para CrazyGames con el arte del juego: 1920x1080 (16:9),
## 800x1200 (2:3) y 800x800 (1:1). Sin más texto que el título, como piden.
## Uso (con ventana): godot --path . --script res://tools/make_covers.gd -- <carpeta_salida>

const SIZES := {"cover_landscape_1920x1080": Vector2i(1920, 1080), "cover_portrait_800x1200": Vector2i(800, 1200), "cover_square_800x800": Vector2i(800, 800)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else OS.get_user_data_dir()
	await process_frame
	for name in SIZES:
		await _render(SIZES[name], out.path_join(name + ".png"))
	quit(0)


func _render(px: Vector2i, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = px
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var stage := Control.new()
	stage.size = Vector2(px)
	vp.add_child(stage)

	var backdrop := DungeonBackdrop.new()
	backdrop.size = Vector2(px)
	stage.add_child(backdrop)
	var home: DungeonData = GameData.DUNGEONS[0]
	backdrop.set_palette(home.wall_tint, home.floor_color)
	backdrop.set_light(1.0)

	var unit := minf(px.x, px.y)
	var floor_y := px.y * DungeonBackdrop.FLOOR_RATIO
	# El jefe, grande y detrás; el grupo adelante, mirándolo.
	_sprite(stage, &"lich", Vector2(px.x * 0.5, floor_y - unit * 0.02), unit * 0.5, true, Color(0.85, 0.8, 1.0))
	var heroes := [&"warrior", &"cleric", &"assassin"]
	for i in heroes.size():
		var x := px.x * (0.22 + 0.28 * i) if px.x <= px.y * 1.2 else px.x * (0.62 + 0.11 * i)
		var foot := floor_y + unit * 0.2
		_sprite(stage, heroes[i], Vector2(x, foot), unit * 0.3, false, Color.WHITE)
	if px.x > px.y * 1.2:
		_sprite(stage, &"skeleton", Vector2(px.x * 0.2, floor_y + unit * 0.2), unit * 0.3, true, Color.WHITE)
		_sprite(stage, &"bat", Vector2(px.x * 0.32, floor_y - unit * 0.2), unit * 0.22, true, Color.WHITE)

	var title := Label.new()
	title.text = "Emberdelve"
	title.add_theme_font_override("font", UiSkin.FONT)
	title.add_theme_font_size_override("font_size", int(unit * (0.17 if px.x > px.y * 1.2 else 0.15)))
	title.add_theme_color_override("font_color", UiSkin.GOLD)
	title.add_theme_color_override("font_outline_color", UiSkin.INK)
	title.add_theme_constant_override("outline_size", int(unit * 0.03))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", int(unit * 0.012))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, px.y * 0.05)
	title.size = Vector2(px.x, unit * 0.25)
	title.z_index = 3
	stage.add_child(title)

	for i in 12:
		await process_frame
	var err := vp.get_texture().get_image().save_png(path)
	print("portada %s: %s" % [path, error_string(err)])
	vp.queue_free()


func _sprite(parent: Control, id: StringName, foot: Vector2, side: float, flip: bool, tint: Color) -> void:
	var t := TextureRect.new()
	t.texture = SpriteBank.texture(id)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	t.size = Vector2(side, side)
	t.position = foot - Vector2(side / 2.0, side)
	t.flip_h = flip
	t.modulate = tint
	t.z_index = 2  # por encima de la viñeta del fondo
	parent.add_child(t)
