class_name CoachTip
extends Control
## Consejo del tutorial: globo con texto corto y una flecha que rebota señalando un
## elemento de la UI. No bloquea el juego: se cierra con "Got it", al saltar los consejos
## o cuando main cambia de pantalla.

signal dismissed(skip_all: bool)

const WIDTH := 300.0
const ARROW := Vector2(22, 14)
const BOUNCE := 6.0

var _target: Control
var _panel := PanelContainer.new()
var _arrow := Control.new()
var _below := true
var _bounce: Tween


## buttons = false: consejo obligatorio del entrenamiento, sin "Got it" ni "Skip tips".
func show_for(target: Control, text: String, layer: Control, buttons := true) -> void:
	_target = target
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiSkin.INK, 0.95)
	box.border_color = UiSkin.TORCH
	box.set_border_width_all(3)
	box.set_corner_radius_all(4)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiSkin.TEXT)
	column.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	row.visible = buttons
	column.add_child(row)
	for entry in [[tr("Skip tips"), true], [tr("Got it"), false]]:
		var b := Button.new()
		b.text = entry[0]
		b.focus_mode = Control.FOCUS_NONE  # el foco de teclado sigue en las cartas
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void: dismissed.emit(entry[1]))
		row.add_child(b)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = ARROW
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)
	layer.add_child(self)
	modulate.a = 0.0
	# Se ubica cuando el layout ya acomodó al objetivo.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_place()
	get_viewport().size_changed.connect(_place)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


## Arriba del objetivo si está en la mitad inferior de la pantalla; si no, debajo.
func _place() -> void:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		visible = false
		return
	var r := _target.get_global_rect()
	_below = r.get_center().y < get_viewport_rect().size.y / 2.0
	_panel.reset_size()
	var ps := _panel.size
	var origin := global_position
	var arrow_y := r.end.y + 4.0 if _below else r.position.y - 4.0 - ARROW.y
	var panel_y := arrow_y + ARROW.y if _below else arrow_y - ps.y
	var panel_x := clampf(r.get_center().x - ps.x / 2.0, 8.0, size.x - ps.x - 8.0)
	_panel.position = Vector2(panel_x, panel_y) - origin
	_arrow.position = Vector2(r.get_center().x - ARROW.x / 2.0, arrow_y) - origin
	_arrow.queue_redraw()
	if _bounce:
		_bounce.kill()
	# El globo y la flecha rebotan hacia el objetivo.
	var away := BOUNCE if _below else -BOUNCE
	_bounce = create_tween().set_loops()
	_bounce.tween_property(self, "position:y", away, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bounce.tween_property(self, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw_arrow() -> void:
	var tip_y := 0.0 if _below else ARROW.y
	var base_y := ARROW.y if _below else 0.0
	_arrow.draw_colored_polygon(PackedVector2Array([
		Vector2(ARROW.x / 2.0, tip_y), Vector2(0, base_y), Vector2(ARROW.x, base_y),
	]), UiSkin.TORCH)
