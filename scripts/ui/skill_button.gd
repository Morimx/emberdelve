class_name SkillButton
extends Button
## Botón de la habilidad de un héroe durante el combate: se carga con el tiempo y,
## cuando está lista, brilla hasta que el jugador la lanza (o se lanza sola).

const READY_COLOR := Color("ffd27a")

var unit: Unit
var _bar := ProgressBar.new()
var _glow: Tween
var _was_ready := false


func setup(hotkey: int, u: Unit, skill_name: String) -> void:
	unit = u
	text = "%d  %s" % [hotkey, skill_name]
	icon = SpriteBank.icon(u.id, 2)
	expand_icon = false
	custom_minimum_size = Vector2(200, 56)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_NONE  # se usan las teclas 1-3 o el clic
	add_theme_font_size_override("font_size", 15)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -9
	_bar.offset_bottom = -4
	_bar.offset_left = 6
	_bar.offset_right = -6
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiSkin.TORCH
	_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)


## charge: 0..1. ready: se puede lanzar ahora.
func refresh(charge: float, ready: bool, alive: bool) -> void:
	_bar.value = charge
	disabled = not ready
	modulate = Color.WHITE if alive else Color(1, 1, 1, 0.35)
	if ready == _was_ready:
		return
	_was_ready = ready
	if _glow:
		_glow.kill()
		_glow = null
	self_modulate = Color.WHITE
	if ready:
		pivot_offset = size / 2.0
		scale = Vector2(1.08, 1.08)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_glow = create_tween().set_loops()
		_glow.tween_property(self, "self_modulate", READY_COLOR, 0.35).set_trans(Tween.TRANS_SINE)
		_glow.tween_property(self, "self_modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
