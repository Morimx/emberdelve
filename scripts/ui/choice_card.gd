class_name ChoiceCard
extends Button
## Carta elegible: icono grande, título, descripción y pie (coste o etiqueta).
## Sirve para puertas, recompensas, bendiciones y acciones del campamento.

const TITLE_SIZE := 17
const TITLE_MIN := 14
const BODY_SIZE := 14
const BODY_MIN := 13
const MARGIN_H := 24.0  # márgenes de los lados de Margin
const MARGIN_V := 12.0  # márgenes de arriba y abajo de Margin
const SEPARATION := 4.0

@onready var _hotkey: Label = %Hotkey
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _footer: Label = %Footer


func setup(hotkey: int, icon_tex: Texture2D, title: String, body: String, footer: String, accent: Color, title_color := UiSkin.TEXT) -> void:
	_hotkey.text = str(hotkey) if hotkey > 0 else ""
	_icon.texture = icon_tex
	_icon.visible = icon_tex != null
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	_body.text = body
	_body.visible = body != ""
	_footer.text = footer
	_footer.visible = footer != ""
	_footer.add_theme_color_override("font_color", accent.lightened(0.2))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, UiSkin.card(accent, state))
	focus_entered.connect(_pop)
	mouse_entered.connect(_pop)
	_fit()


## Achica las letras si el texto (más largo en español) no entra en la carta. Mide con
## los anchos fijos de la plantilla, sin esperar a que se acomode el layout.
func _fit() -> void:
	var width := custom_minimum_size.x - MARGIN_H
	var title_width := width - _icon.custom_minimum_size.x - _hotkey.get_minimum_size().x - 2.0 * _top_separation()
	var title_size := TITLE_SIZE
	var body_size := BODY_SIZE
	while _content_height(title_width, title_size, width, body_size) > custom_minimum_size.y - MARGIN_V:
		if title_size > TITLE_MIN:
			title_size -= 1
		elif body_size > BODY_MIN:
			body_size -= 1
		else:
			break
	# Deja las etiquetas con el tamaño elegido (medir las fue cambiando).
	_text_height(_title, title_width, title_size)
	_text_height(_body, width, body_size)


func _content_height(title_width: float, title_size: int, body_width: float, body_size: int) -> float:
	var total := maxf(_icon.custom_minimum_size.y, _text_height(_title, title_width, title_size))
	if _body.visible:
		total += SEPARATION + _text_height(_body, body_width, body_size)
	if _footer.visible:
		total += SEPARATION + _footer.get_minimum_size().y
	return total


## Alto que ocupa la etiqueta con ese ancho y tamaño: usa el mismo autowrap de Label.
func _text_height(label: Label, width: float, font_size: int) -> float:
	label.size.x = width
	label.add_theme_font_size_override("font_size", font_size)
	return label.get_minimum_size().y


func _top_separation() -> float:
	return float(_title.get_parent().get_theme_constant("separation"))


func _pop() -> void:
	if disabled:
		return
	pivot_offset = size / 2.0
	scale = Vector2(1.04, 1.04)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
