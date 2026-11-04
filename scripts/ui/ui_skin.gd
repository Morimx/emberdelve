class_name UiSkin
extends RefCounted
## Estilo visual pixel art generado por código: paneles de piedra, botones y el tema global.
## Las texturas se dibujan a resolución de pixel y se amplían x2 sin suavizado.

const FONT_FILE := preload("res://assets/fonts/PixelifySans.ttf")
## Sin ligaduras: la de "fi" de la fuente se lee mal en pantalla.
static var FONT: Font = _make_font()
## Silkscreen (OFL) para números y etiquetas cortas: sus dígitos se distinguen bien
## (en Pixelify Sans el 5 se confunde con la S). Nítida en múltiplos de 8 px.
const NUMBER_FONT := preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const NUMBER_VARIATION := &"NumberLabel"

const INK := Color("07081a")
const STONE := Color("1c2246")
const STONE_DARK := Color("12162e")
const STONE_LIGHT := Color("2a3366")
const EDGE := Color("3d4784")
const EDGE_HI := Color("6170b8")
const GOLD := Color("f2c14e")
const GOLD_DARK := Color("8a6a2a")
const TEXT := Color("ece6d3")
const MUTED := Color("b3b9db")
const TORCH := Color("ff9a3c")
const HEAL := Color("6fd35a")
const DANGER := Color("d94b42")

const PIXEL := 2  # cada pixel del arte ocupa 2x2 en pantalla

static var _cache := {}


## Panel de piedra biselado. border: color del marco; corners: remaches dorados.
static func panel(fill: Color = STONE, border: Color = EDGE, corners := true) -> StyleBoxTexture:
	var key := "panel_%s_%s_%s" % [fill.to_html(), border.to_html(), corners]
	if _cache.has(key):
		return _cache[key]
	var size := 12
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for i in size:
		# contorno oscuro, marco de color y bisel claro arriba / oscuro abajo
		img.set_pixel(i, 0, INK); img.set_pixel(i, size - 1, INK)
		img.set_pixel(0, i, INK); img.set_pixel(size - 1, i, INK)
		if i > 0 and i < size - 1:
			img.set_pixel(i, 1, border); img.set_pixel(i, size - 2, border.darkened(0.35))
			img.set_pixel(1, i, border); img.set_pixel(size - 2, i, border.darkened(0.35))
			if i > 1 and i < size - 2:
				img.set_pixel(i, 2, fill.lightened(0.12))
				img.set_pixel(i, size - 3, fill.darkened(0.25))
	# esquinas recortadas
	for c in [Vector2i(0, 0), Vector2i(size - 1, 0), Vector2i(0, size - 1), Vector2i(size - 1, size - 1)]:
		img.set_pixel(c.x, c.y, Color.TRANSPARENT)
	if corners:
		for c in [Vector2i(1, 1), Vector2i(size - 2, 1), Vector2i(1, size - 2), Vector2i(size - 2, size - 2)]:
			img.set_pixel(c.x, c.y, GOLD)
	var box := _box_from(img, 4)
	_cache[key] = box
	return box


static func button(state: String) -> StyleBoxTexture:
	match state:
		"hover":
			return panel(STONE_LIGHT, EDGE_HI, false)
		"pressed":
			return panel(STONE_DARK, EDGE, false)
		"focus":
			var box: StyleBoxTexture = panel(STONE_LIGHT, GOLD, true).duplicate()
			box.draw_center = false
			return box
		"disabled":
			return panel(Color("15192f"), Color("262b4c"), false)
	return panel(STONE, EDGE, false)


## Carta: panel con marco del color dado (rareza, tipo de puerta, etc.).
static func card(border: Color, state: String = "normal") -> StyleBoxTexture:
	match state:
		"hover":
			return panel(STONE_LIGHT, border.lightened(0.25), true)
		"pressed":
			return panel(STONE_DARK, border, true)
		"focus":
			var box: StyleBoxTexture = panel(STONE_LIGHT, GOLD, true).duplicate()
			box.draw_center = false
			return box
		"disabled":
			return panel(Color("15192f"), border.darkened(0.6), false)
	return panel(STONE, border, true)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", INK)
	t.set_type_variation(NUMBER_VARIATION, "Label")
	t.set_font("font", NUMBER_VARIATION, NUMBER_FONT)
	t.set_font_size("font_size", NUMBER_VARIATION, 16)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "Button", button(state))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("5c6290"))
	t.set_constant("h_separation", "Button", 8)
	t.set_stylebox("panel", "PanelContainer", panel())
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = INK
	bar_bg.set_border_width_all(2)
	bar_bg.border_color = Color.BLACK
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = DANGER
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


static func _make_font() -> Font:
	var font := FontVariation.new()
	font.base_font = FONT_FILE
	font.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
	return font


static func _box_from(img: Image, margin: int) -> StyleBoxTexture:
	img.resize(img.get_width() * PIXEL, img.get_height() * PIXEL, Image.INTERPOLATE_NEAREST)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(img)
	var m := margin * PIXEL
	box.texture_margin_left = m
	box.texture_margin_right = m
	box.texture_margin_top = m
	box.texture_margin_bottom = m
	box.content_margin_left = m + 4
	box.content_margin_right = m + 4
	box.content_margin_top = m + 2
	box.content_margin_bottom = m + 2
	return box
