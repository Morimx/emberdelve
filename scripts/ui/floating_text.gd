class_name FloatingText
extends Label
## Número o texto que salta, sube y se desvanece. Se libera solo.


func popup(text_value: String, color: Color, big := false) -> void:
	text = text_value
	add_theme_color_override("font_color", color)
	add_theme_font_override("font", UiSkin.NUMBER_FONT)
	add_theme_font_size_override("font_size", 24 if big else 16)
	reset_size()
	pivot_offset = size / 2.0
	position -= size / 2.0
	scale = Vector2(1.6, 1.6) if big else Vector2(1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:y", position.y - 30.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
