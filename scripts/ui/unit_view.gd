class_name UnitView
extends VBoxContainer
## Vista de un combatiente: sprite, nombre y barra de vida, con animaciones de golpe.
## Solo es visual: la vida real vive en Unit y llega por set_hp().

const SIZE_NORMAL := 96.0
const SIZE_BOSS := 136.0
const WINDUP_COLOR := Color(1.6, 0.45, 0.35)
const MARKER_Y := -46.0

## Clic sobre un enemigo: el jugador lo marca como objetivo.
signal clicked(unit: Unit)

var unit: Unit
var _base_x := 0.0
var _idle: Tween
var _windup: Tween
var _marker: TextureRect
var _marker_tw: Tween

@onready var _name: Label = %Name
@onready var _body: Control = %Body
@onready var _sprite: TextureRect = %Sprite
@onready var _bar: ProgressBar = %Bar
@onready var _hp: Label = %Hp


func setup(u: Unit, hp: int) -> void:
	unit = u
	# Solo los jefes se ven grandes; un héroe con mucho equipo también pasa de 300 de vida.
	var side := SIZE_BOSS if u.is_enemy and u.max_hp > 300 else SIZE_NORMAL
	_body.custom_minimum_size = Vector2(side, side)
	_sprite.size = Vector2(side, side)
	_sprite.pivot_offset = Vector2(side / 2.0, side)
	_sprite.texture = SpriteBank.texture(u.id)
	_sprite.flip_h = u.is_enemy  # los sprites miran a la izquierda; los enemigos, a la derecha
	# Los élites llegan como "Elite <nombre>": se traducen las dos partes por separado.
	if u.display_name.begins_with("Elite "):
		_name.text = tr("Elite %s") % tr(u.display_name.trim_prefix("Elite "))
	else:
		_name.text = tr(u.display_name)
	_bar.max_value = u.max_hp
	set_hp(hp)
	if u.is_enemy:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = tr("Click to focus this enemy")
		_marker = TextureRect.new()
		_marker.texture = SpriteBank.texture(&"target")
		_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.size = Vector2(28, 20)
		_marker.visible = false
		_body.add_child(_marker)
		_marker.position = Vector2((_body.custom_minimum_size.x - _marker.size.x) / 2.0, MARKER_Y)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and unit.is_alive():
		clicked.emit(unit)
		accept_event()


## Marca de objetivo (flecha que rebota sobre el enemigo elegido).
func set_targeted(on: bool) -> void:
	if _marker == null:
		return
	_marker.visible = on and unit.is_alive()
	if _marker_tw:
		_marker_tw.kill()
		_marker_tw = null
	_marker.position.y = MARKER_Y
	if _marker.visible:
		_marker_tw = _marker.create_tween().set_loops()
		_marker_tw.tween_property(_marker, "position:y", MARKER_Y + 5.0, 0.3).set_trans(Tween.TRANS_SINE)
		_marker_tw.tween_property(_marker, "position:y", MARKER_Y, 0.3).set_trans(Tween.TRANS_SINE)


## El enemigo carga un golpe fuerte: late en rojo y crece hasta soltarlo.
func wind_up(seconds: float) -> void:
	end_windup()
	_windup = create_tween().set_loops(maxi(1, int(seconds / 0.3)))
	_windup.tween_property(_body, "modulate", WINDUP_COLOR, 0.15)
	_windup.tween_property(_body, "modulate", Color.WHITE, 0.15)


func end_windup() -> void:
	if _windup:
		_windup.kill()
		_windup = null
	_body.modulate = Color.WHITE


func set_hp(hp: int) -> void:
	_bar.max_value = unit.max_hp
	_bar.value = hp
	_hp.text = "%d/%d" % [hp, unit.max_hp]
	var alive := hp > 0
	_sprite.modulate.a = 1.0 if alive else 0.25
	_sprite.rotation = 0.0 if alive else (PI / 2.0 if not unit.is_enemy else -PI / 2.0)
	if alive and _idle == null:
		_breathe()
	elif not alive:
		_stop_idle()


## Respiración en reposo: sube y baja un poco, desfasada entre personajes.
func _breathe() -> void:
	var lift := 5.0 if unit.max_hp > 300 and unit.is_enemy else 3.0
	var period := randf_range(0.7, 0.9)
	_idle = create_tween().set_loops()
	_idle.tween_interval(randf() * 0.4)
	_idle.tween_property(_sprite, "position:y", -lift, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.tween_property(_sprite, "position:y", 0.0, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle() -> void:
	if _idle:
		_idle.kill()
		_idle = null
	_sprite.position.y = 0.0


## Punto de origen para los números flotantes, en coordenadas globales.
func hit_point() -> Vector2:
	return _body.global_position + Vector2(_body.size.x / 2.0, _body.size.y * 0.55)


func lunge() -> void:
	var dir := 1.0 if unit.is_enemy else -1.0
	var tw := create_tween()
	tw.tween_property(_sprite, "position:x", _base_x + 14.0 * dir, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position:x", _base_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func hurt(color: Color, heavy: bool) -> void:
	_sprite.self_modulate = color
	_sprite.scale = Vector2(1.25, 0.8) if heavy else Vector2(1.12, 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "self_modulate", Color.WHITE, 0.2)
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func healed() -> void:
	_sprite.self_modulate = Color(0.5, 1.0, 0.6)
	create_tween().tween_property(_sprite, "self_modulate", Color.WHITE, 0.3)


func die() -> void:
	_stop_idle()
	end_windup()
	set_targeted(false)
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "modulate:a", 0.25, 0.35)
	tw.tween_property(_sprite, "rotation", PI / 2.0 if not unit.is_enemy else -PI / 2.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
