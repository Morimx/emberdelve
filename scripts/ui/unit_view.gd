class_name UnitView
extends VBoxContainer
## Vista de un combatiente: sprite, nombre y barra de vida, con animaciones de golpe.
## Solo es visual: la vida real vive en Unit y llega por set_hp().

const SIZE_NORMAL := 96.0
const SIZE_BOSS := 136.0

var unit: Unit
var _base_x := 0.0

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


func set_hp(hp: int) -> void:
	_bar.max_value = unit.max_hp
	_bar.value = hp
	_hp.text = "%d/%d" % [hp, unit.max_hp]
	var alive := hp > 0
	_sprite.modulate.a = 1.0 if alive else 0.25
	_sprite.rotation = 0.0 if alive else (PI / 2.0 if not unit.is_enemy else -PI / 2.0)


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
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "modulate:a", 0.25, 0.35)
	tw.tween_property(_sprite, "rotation", PI / 2.0 if not unit.is_enemy else -PI / 2.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
