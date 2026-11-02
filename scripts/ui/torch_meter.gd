class_name TorchMeter
extends HBoxContainer
## Medidor de antorcha: un segmento por punto de luz. Con poca luz, los segmentos titilan.

const LIT := Color("ff9a3c")
const UNLIT := Color("2a1d12")
const LOW_LIGHT := 2

var _icon := TextureRect.new()
var _segments: Array[ColorRect] = []
var _flicker: Tween


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	_icon.texture = SpriteBank.texture(&"torch")
	_icon.custom_minimum_size = Vector2(20, 25)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)


func set_value(value: int, maximum: int) -> void:
	var count := maxi(value, maximum)
	while _segments.size() < count:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(12, 20)
		add_child(seg)
		_segments.append(seg)
	for i in _segments.size():
		_segments[i].visible = i < count
		_segments[i].color = LIT if i < value else UNLIT
	visible = maximum > 0
	if _flicker:
		_flicker.kill()
		_flicker = null
	modulate = Color.WHITE
	if value > 0 and value <= LOW_LIGHT:
		_flicker = create_tween().set_loops()
		_flicker.tween_property(self, "modulate", Color(1, 1, 1, 0.45), 0.35).set_trans(Tween.TRANS_SINE)
		_flicker.tween_property(self, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
