extends SceneTree
## Hoja con todos los sprites refinados, para revisar el arte sin abrir el juego.
## Uso: godot --headless --path . --script res://tools/sprite_sheet.gd -- <archivo.png> [escala]

const COLUMNS := 8
const CELL := 40


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://sprite_sheet.png"
	var zoom := int(args[1]) if args.size() > 1 else 3
	var limit := int(args[2]) if args.size() > 2 else 0
	var ids: Array = SpriteHD.SPRITES.keys() + SpriteBank.SPRITES.keys().filter(func(k: StringName) -> bool: return not SpriteHD.SPRITES.has(k))
	if limit > 0:
		ids = ids.slice(0, limit)
	var rows := ceili(ids.size() / float(COLUMNS))
	var sheet := Image.create_empty(COLUMNS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1b2252"))
	for i in ids.size():
		var img := SpriteBank.texture(ids[i]).get_image()
		var pos := Vector2i((i % COLUMNS) * CELL + (CELL - img.get_width()) / 2, (i / COLUMNS) * CELL + CELL - img.get_height() - 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)
	sheet.resize(sheet.get_width() * zoom, sheet.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out_path)
	print("hoja: ", out_path)
	quit()
