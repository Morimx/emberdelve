class_name TalentScreen
extends Control
## Constelación de talentos: mapa de nodos unidos por líneas y panel de detalle con compra.
## Emite purchased al comprar (para guardar) y closed al volver.

signal purchased(talent: TalentData)
signal closed()

const BRANCH_COLORS := {&"root": Color("b065ec"), &"steel": Color("e07a6a"), &"fortune": Color("f2c14e"), &"path": Color("6fd3e6")}
const BRANCH_NAMES := {&"steel": "STEEL", &"fortune": "FORTUNE", &"path": "PATH"}
const NODE_SIZE := 46.0
const KEY_SIZE := 58.0

var meta: MetaState
var catalog: Array[TalentData] = []
var _selected: TalentData
var _map := Control.new()
var _buttons := {}
var _stars := PackedVector2Array()
var _wallet: Label
var _detail_icon := TextureRect.new()
var _detail_name := Label.new()
var _detail_desc := Label.new()
var _detail_level := Label.new()
var _detail_cost := Label.new()
var _buy := Button.new()


func open(meta_state: MetaState, talents: Array[TalentData]) -> void:
	meta = meta_state
	catalog = talents
	_selected = catalog[0]
	_build_nodes()
	_refresh()
	(_buttons[_selected.id] as Button).grab_focus.call_deferred()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20  # por encima de la arena (que usa z_index para quedar sobre la viñeta)
	var sky := ColorRect.new()
	sky.color = Color("080a1c")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		_stars.append(Vector2(rng.randf(), rng.randf()))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var title := Label.new()
	title.text = tr("The Torch Constellation")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiSkin.GOLD)
	left.add_child(title)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.draw.connect(_draw_map)
	_map.resized.connect(_layout_nodes)
	left.add_child(_map)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(270, 0)
	side.add_theme_stylebox_override("panel", UiSkin.panel(UiSkin.STONE, UiSkin.GOLD_DARK))
	row.add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	side.add_child(box)
	_wallet = Label.new()
	_wallet.add_theme_color_override("font_color", UiSkin.GOLD)
	box.add_child(_wallet)
	var head := HBoxContainer.new()
	box.add_child(head)
	_detail_icon.custom_minimum_size = Vector2(48, 48)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_detail_icon)
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_detail_name)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_color_override("font_color", UiSkin.MUTED)
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_detail_desc)
	_detail_level.add_theme_font_size_override("font_size", 18)
	box.add_child(_detail_level)
	box.add_child(_detail_cost)
	_buy.custom_minimum_size = Vector2(0, 44)
	_buy.pressed.connect(_on_buy)
	box.add_child(_buy)
	var back := Button.new()
	back.text = tr("Back to camp  [Esc]")
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_nodes() -> void:
	for b in _buttons.values():
		b.queue_free()
	_buttons.clear()
	for t in catalog:
		var b := Button.new()
		b.icon = SpriteBank.icon(t.icon, 2)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2.ONE * (KEY_SIZE if t.key else NODE_SIZE)
		b.size = b.custom_minimum_size
		b.focus_entered.connect(_select.bind(t))
		b.mouse_entered.connect(_select.bind(t))
		b.pressed.connect(_on_node_pressed.bind(t))
		var lvl := Label.new()
		lvl.name = "Level"
		lvl.add_theme_font_size_override("font_size", 13)
		lvl.add_theme_constant_override("outline_size", 4)
		lvl.position = Vector2(0, b.custom_minimum_size.y - 2)
		lvl.size = Vector2(b.custom_minimum_size.x, 16)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lvl)
		_map.add_child(b)
		_buttons[t.id] = b
	_layout_nodes()


func _layout_nodes() -> void:
	for t in catalog:
		var b: Button = _buttons.get(t.id)
		if b:
			b.position = _node_center(t) - b.size / 2.0
	_map.queue_redraw()


func _node_center(t: TalentData) -> Vector2:
	var pad := Vector2(40, 30)
	return pad + t.pos * (_map.size - pad * 2.0)


func _refresh() -> void:
	_wallet.text = tr("Gold %d   ·   Shards %d") % [meta.gold, meta.shards]
	for t in catalog:
		var b: Button = _buttons[t.id]
		var lvl := meta.talent_level(t.id)
		var color: Color = BRANCH_COLORS.get(t.branch, UiSkin.EDGE)
		var unlocked := meta.is_unlocked(t)
		var border := UiSkin.GOLD if lvl >= t.max_level else (color if unlocked else Color("2b3054"))
		var fill := UiSkin.STONE_LIGHT if lvl > 0 else (UiSkin.STONE if unlocked else Color("0e1126"))
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, UiSkin.panel(fill.lightened(0.08) if state == "hover" else fill, border, t.key))
		b.add_theme_stylebox_override("focus", UiSkin.button("focus"))
		b.modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.7)
		var label: Label = b.get_node("Level")
		label.text = "MAX" if lvl >= t.max_level else "%d/%d" % [lvl, t.max_level]
		label.add_theme_color_override("font_color", UiSkin.GOLD if lvl >= t.max_level else UiSkin.TEXT)
	_show_detail()
	_map.queue_redraw()


func _select(t: TalentData) -> void:
	_selected = t
	_show_detail()


func _show_detail() -> void:
	var t := _selected
	var lvl := meta.talent_level(t.id)
	_detail_icon.texture = SpriteBank.texture(t.icon)
	_detail_name.text = tr(t.display_name)
	_detail_name.add_theme_color_override("font_color", BRANCH_COLORS.get(t.branch, UiSkin.TEXT))
	_detail_desc.text = tr(t.description)
	_detail_level.text = tr("Level %d / %d") % [lvl, t.max_level]
	var currency := tr("shards") if t.currency == &"shards" else tr("gold")
	if lvl >= t.max_level:
		_detail_cost.text = tr("Fully upgraded")
		_buy.text = tr("Maxed")
	elif not meta.is_unlocked(t):
		_detail_cost.text = tr("Requires a connected talent")
		_buy.text = tr("Locked")
	else:
		_detail_cost.text = tr("Cost: %d %s") % [t.cost(lvl), currency]
		_buy.text = tr("Upgrade  [Enter]")
	_buy.disabled = not meta.can_buy(t)


func _on_node_pressed(t: TalentData) -> void:
	_select(t)
	_on_buy()


func _on_buy() -> void:
	if meta.buy(_selected):
		purchased.emit(_selected)
		var b: Button = _buttons[_selected.id]
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(1.3, 1.3)
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_refresh()


func _draw_map() -> void:
	for s in _stars:
		var p := s * _map.size
		_map.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.75, 0.8, 1.0, 0.35 + 0.4 * fmod(s.x * 13.0, 1.0)))
	for t in catalog:
		for req in t.requires:
			var other := _find(req)
			if other == null:
				continue
			var lit := meta.talent_level(t.id) > 0 and meta.talent_level(other.id) > 0
			var reachable := meta.is_unlocked(t)
			var color := UiSkin.GOLD if lit else (Color("7c86c9") if reachable else Color("2b3160"))
			_map.draw_line(_node_center(other), _node_center(t), color, 3.0 if lit else 2.0)
	for branch in BRANCH_NAMES:
		var xs := []
		for t in catalog:
			if t.branch == branch:
				xs.append(_node_center(t).x)
		if xs.is_empty():
			continue
		var x: float = xs.reduce(func(a, b): return a + b) / xs.size()
		var y := 30.0 + 0.61 * (_map.size.y - 60.0) + 5.0  # entre la primera y la segunda fila
		_map.draw_string(UiSkin.FONT, Vector2(x - 40, y), tr(BRANCH_NAMES[branch]), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, BRANCH_COLORS[branch])


func _find(id: StringName) -> TalentData:
	for t in catalog:
		if t.id == id:
			return t
	return null
