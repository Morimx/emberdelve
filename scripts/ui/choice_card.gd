class_name ChoiceCard
extends Button
## Carta elegible: icono grande, título, descripción y pie (coste o etiqueta).
## Sirve para puertas, recompensas, bendiciones y acciones del campamento.

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


func _pop() -> void:
	if disabled:
		return
	pivot_offset = size / 2.0
	scale = Vector2(1.04, 1.04)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
