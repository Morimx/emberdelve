class_name SpeechBubble
extends PanelContainer
## Globo de diálogo que aparece sobre un punto, se queda un momento y se desvanece solo.

const HOLD := 2.2


func say(text: String, anchor: Vector2, accent: Color, layer: Control) -> void:
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
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("1a1530"))
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = mini(220, 14 + text.length() * 8)
	add_child(label)
	layer.add_child(self)
	reset_size()
	# Centrado sobre el punto, sin salirse de la pantalla.
	var pos := anchor - layer.global_position - Vector2(size.x / 2.0, size.y + 8)
	pos.x = clampf(pos.x, 4.0, layer.size.x - size.x - 4.0)
	pos.y = maxf(pos.y, 4.0)
	position = pos
	pivot_offset = Vector2(size.x / 2.0, size.y)
	scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_interval(HOLD)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
