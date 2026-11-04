class_name SpeechBubble
extends PanelContainer
## Globo de diálogo que aparece sobre un punto, se queda un momento y se desvanece solo.
## Siempre queda dentro de bounds (la escena): si no entra arriba del personaje, va abajo.

const HOLD := 2.4
const MAX_WIDTH := 230.0
const MARGIN := 6.0


func say(text: String, anchor: Vector2, accent: Color, layer: Control, bounds := Rect2()) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f2ead3")
	box.border_color = accent
	box.set_border_width_all(3)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	add_theme_stylebox_override("panel", box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("1a1530"))
	label.add_theme_font_size_override("font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Ancho según el largo del texto, con tope: los textos largos pasan a dos líneas.
	var font := label.get_theme_font("font")
	var one_line := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	label.custom_minimum_size.x = minf(MAX_WIDTH, one_line + 4.0)
	add_child(label)
	modulate.a = 0.0
	layer.add_child(self)
	# Con autowrap el alto real se conoce recién después de un cuadro de layout.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	reset_size()
	var area := bounds if bounds.has_area() else layer.get_global_rect()
	var local_area := Rect2(area.position - layer.global_position, area.size)
	var pos := anchor - layer.global_position - Vector2(size.x / 2.0, size.y + 8.0)
	if pos.y < local_area.position.y + MARGIN:
		pos.y = anchor.y - layer.global_position.y + 24.0  # no entra arriba: debajo de la cabeza
	pos.x = clampf(pos.x, local_area.position.x + MARGIN, local_area.end.x - size.x - MARGIN)
	pos.y = clampf(pos.y, local_area.position.y + MARGIN, local_area.end.y - size.y - MARGIN)
	position = pos
	pivot_offset = Vector2(size.x / 2.0, size.y)
	scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_interval(HOLD)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
