class_name DungeonBackdrop
extends Control
## Fondo de la arena: pared de ladrillo, arco oscuro, piso de adoquines, dos antorchas de
## pared que titilan y una viñeta cuya luz se achica cuando queda poca antorcha.

const FLOOR_RATIO := 0.7

var _light := 1.0
var _target_light := 1.0
var _time := 0.0
var _vignette := TextureRect.new()
var _vignette_tex := GradientTexture2D.new()
var _glows: Array[TextureRect] = []
var _flames: Array[TextureRect] = []
var _campfire := TextureRect.new()
var _wall_tint := Color(0.8, 0.8, 0.95)
var _floor_color := Color("141a3d")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for i in 2:
		var glow := TextureRect.new()
		glow.texture = _radial(Color(1.0, 0.6, 0.25, 0.55))
		glow.size = Vector2(220, 220)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow)
		_glows.append(glow)
		var flame := TextureRect.new()
		flame.texture = SpriteBank.texture(&"torch")
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flame.size = Vector2(24, 30)
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flame)
		_flames.append(flame)
	_campfire.texture = SpriteBank.texture(&"fire")
	_campfire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_campfire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_campfire.size = Vector2(54, 54)
	_campfire.visible = false
	add_child(_campfire)
	_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	_vignette_tex.fill_from = Vector2(0.5, 0.62)
	_vignette_tex.fill_to = Vector2(1.05, 0.62)
	_vignette_tex.gradient = Gradient.new()
	_vignette.texture = _vignette_tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = 1
	add_child(_vignette)
	_apply_light()
	resized.connect(_layout)
	_layout()


## ratio 0..1: cuánta luz queda. La viñeta se cierra con poca luz.
func set_light(ratio: float) -> void:
	_target_light = clampf(ratio, 0.0, 1.0)


## Colores de la mazmorra actual: tinte de la pared y color del piso.
func set_palette(wall_tint: Color, floor_color: Color) -> void:
	_wall_tint = wall_tint
	_floor_color = floor_color
	queue_redraw()


func set_campfire(on: bool) -> void:
	_campfire.visible = on


func _process(delta: float) -> void:
	_time += delta
	if absf(_light - _target_light) > 0.001:
		_light = lerpf(_light, _target_light, minf(1.0, delta * 3.0))
		_apply_light()
	for i in _glows.size():
		var f := 0.85 + 0.15 * sin(_time * 7.0 + i * 2.1) * sin(_time * 3.3 + i)
		_glows[i].modulate.a = f
		_flames[i].scale = Vector2(1.0, 0.92 + 0.08 * f)
	if _campfire.visible:
		_campfire.scale = Vector2(1.0, 0.94 + 0.06 * sin(_time * 9.0))


func _draw() -> void:
	var floor_y := size.y * FLOOR_RATIO
	# El ladrillo se dibuja a mitad de tamaño con transformación x2: pixeles gruesos.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_texture_rect(SpriteBank.brick_texture(), Rect2(Vector2.ZERO, Vector2(size.x / 2.0, floor_y / 2.0)), true, _wall_tint)
	draw_set_transform(Vector2.ZERO)
	_draw_arch(Vector2(size.x * 0.5, floor_y), size.x * 0.14, floor_y * 0.78)
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), _floor_color)
	draw_texture_rect(_cobble_texture(), Rect2(0, floor_y, size.x, size.y - floor_y), true, _wall_tint.lerp(Color.WHITE, 0.2))
	draw_rect(Rect2(0, floor_y - 3, size.x, 4), Color("0a0d26"))


func _draw_arch(base: Vector2, half_width: float, height: float) -> void:
	if half_width < 4.0 or height < half_width * 2.0:
		return  # todavía sin tamaño: un polígono degenerado no se puede triangular
	var points := PackedVector2Array()
	var spring := base.y - height + half_width
	points.append(Vector2(base.x - half_width, base.y))
	for i in 17:
		var a := PI + PI * i / 16.0
		points.append(Vector2(base.x + cos(a) * half_width, spring + sin(a) * half_width))
	points.append(Vector2(base.x + half_width, base.y))
	var rim := PackedVector2Array()
	for p in points:
		rim.append(base + (p - base) * Vector2(1.18, 1.08))
	draw_colored_polygon(rim, Color("2a3470"))
	draw_colored_polygon(points, Color("05071a"))


func _layout() -> void:
	queue_redraw()
	var floor_y := size.y * FLOOR_RATIO
	var xs := [size.x * 0.22, size.x * 0.78]
	for i in _flames.size():
		_flames[i].position = Vector2(xs[i] - 12, floor_y * 0.38)
		_glows[i].position = Vector2(xs[i] - 110, floor_y * 0.38 - 95)
	_campfire.position = Vector2(size.x * 0.5 - 27, floor_y - 30)


func _apply_light() -> void:
	var g := _vignette_tex.gradient
	var inner := lerpf(0.05, 0.5, _light)
	g.offsets = PackedFloat32Array([0.0, inner, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.04, lerpf(0.95, 0.6, _light))])


static func _radial(color: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	return tex


static var _cobble: Texture2D


static func _cobble_texture() -> Texture2D:
	if _cobble:
		return _cobble
	var img := Image.create_empty(24, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color("161c42"))
	for r in [Rect2i(1, 1, 9, 4), Rect2i(12, 1, 11, 4), Rect2i(0, 7, 5, 4), Rect2i(7, 7, 10, 4), Rect2i(19, 7, 5, 4)]:
		img.fill_rect(r, Color("232c5e") if r.position.x % 2 == 1 else Color("1f2756"))
	img.resize(48, 24, Image.INTERPOLATE_NEAREST)
	_cobble = ImageTexture.create_from_image(img)
	return _cobble
