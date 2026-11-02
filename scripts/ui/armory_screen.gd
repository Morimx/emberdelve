class_name ArmoryScreen
extends Control
## Armería: equipo del grupo (3 slots) y depósito de objetos. Permite comparar con lo
## equipado, equipar, desguazar uno o todos los comunes. Emite changed (para guardar) y closed.

signal changed()
signal closed()

const TILE := 52.0

var meta: MetaState
var _selected := -1  # índice en el depósito; -1 = nada
var _slot_buttons := {}
var _grid := GridContainer.new()
var _detail_name := Label.new()
var _detail_body := Label.new()
var _wallet := Label.new()
var _equip := Button.new()
var _salvage := Button.new()
var _salvage_all := Button.new()


func open(meta_state: MetaState) -> void:
	meta = meta_state
	_refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20
	var bg := ColorRect.new()
	bg.color = UiSkin.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var title := Label.new()
	title.text = tr("Armory")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiSkin.GOLD)
	left.add_child(title)
	var equipped_row := HBoxContainer.new()
	equipped_row.add_theme_constant_override("separation", 10)
	left.add_child(equipped_row)
	for slot in Loot.SLOTS:
		var b := _tile(null)
		b.custom_minimum_size = Vector2(64, 64)
		b.pressed.connect(_on_slot_pressed.bind(slot))
		equipped_row.add_child(b)
		_slot_buttons[slot] = b
	var stash_label := Label.new()
	stash_label.text = tr("Stash")
	stash_label.add_theme_color_override("font_color", UiSkin.MUTED)
	left.add_child(stash_label)
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.add_theme_stylebox_override("panel", UiSkin.panel(UiSkin.STONE, UiSkin.GOLD_DARK))
	row.add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	side.add_child(box)
	_wallet.theme_type_variation = UiSkin.NUMBER_VARIATION
	_wallet.add_theme_color_override("font_color", UiSkin.GOLD)
	box.add_child(_wallet)
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_name)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_theme_color_override("font_color", UiSkin.MUTED)
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_detail_body)
	for b in [_equip, _salvage, _salvage_all]:
		b.custom_minimum_size = Vector2(0, 40)
		box.add_child(b)
	_equip.pressed.connect(_on_equip)
	_salvage.pressed.connect(_on_salvage)
	_salvage_all.pressed.connect(_on_salvage_all)
	var back := Button.new()
	back.text = tr("Back to camp  [Esc]")
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _tile(item: ItemData) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var color := UiSkin.EDGE
	if item:
		b.icon = SpriteBank.icon(item.slot, 3)
		color = Loot.RARITY_COLORS[item.rarity]
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, UiSkin.card(color, state))
	b.add_theme_stylebox_override("focus", UiSkin.button("focus"))
	return b


func _refresh() -> void:
	_wallet.text = tr("Gold %d") % meta.gold
	for slot in Loot.SLOTS:
		var item: ItemData = meta.equipped.get(slot)
		var b: Button = _slot_buttons[slot]
		b.icon = SpriteBank.icon(slot, 3)
		b.modulate = Color.WHITE if item else Color(0.45, 0.45, 0.6)
		var color: Color = Loot.RARITY_COLORS[item.rarity] if item else UiSkin.EDGE
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, UiSkin.card(color, state))
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for i in MetaState.STASH_MAX:
		var item: ItemData = meta.stash[i] if i < meta.stash.size() else null
		var b := _tile(item)
		b.disabled = item == null
		if item:
			b.pressed.connect(_select.bind(i))
			b.focus_entered.connect(_select.bind(i))
		_grid.add_child(b)
	_selected = mini(_selected, meta.stash.size() - 1)
	var commons := meta.stash.filter(func(it: ItemData) -> bool: return it.rarity == 0).size()
	_salvage_all.text = tr("Salvage all commons (%d)") % commons
	_salvage_all.disabled = commons == 0
	if _selected >= 0:
		_select(_selected)
	else:
		_show_equipped(Loot.SLOTS[0])
		if not meta.stash.is_empty():
			(_grid.get_child(0) as Button).grab_focus.call_deferred()


func _select(index: int) -> void:
	_selected = index
	var item := meta.stash[index]
	var current: ItemData = meta.equipped.get(item.slot)
	_detail_name.text = "%s · %s" % [tr(item.display_name), tr(Loot.RARITY_NAMES[item.rarity])]
	_detail_name.add_theme_color_override("font_color", Loot.RARITY_COLORS[item.rarity].lightened(0.25))
	var lines: PackedStringArray = [tr(Loot.SLOT_NAMES[item.slot])]
	for stat in [["attack", "Attack"], ["defense", "Defense"], ["max_hp", "Health"]]:
		var new_value: int = item.get(stat[0])
		var old_value: int = current.get(stat[0]) if current else 0
		if new_value == 0 and old_value == 0:
			continue
		var delta := new_value - old_value
		var arrow := ("  (+%d)" % delta) if delta > 0 else (("  (-%d)" % -delta) if delta < 0 else "")
		lines.append("%s: %d%s" % [tr(stat[1]), new_value, arrow])
	lines.append("")
	lines.append(tr("Equipped: %s") % (tr(current.display_name) if current else "-"))
	_detail_body.text = "\n".join(lines)
	_equip.text = tr("Equip")
	_equip.disabled = false
	_salvage.text = tr("Salvage  (+%d gold)") % meta.salvage_value(item)
	_salvage.disabled = false


func _on_slot_pressed(slot: StringName) -> void:
	_selected = -1
	_show_equipped(slot)


func _show_equipped(slot: StringName) -> void:
	var item: ItemData = meta.equipped.get(slot)
	_detail_name.text = tr(Loot.SLOT_NAMES[slot])
	_detail_name.add_theme_color_override("font_color", UiSkin.TEXT)
	_detail_body.text = (tr("Equipped: %s") % item.describe()) if item else tr("Empty slot. Loot you bring back fills it.")
	_detail_body.text += "\n\n" + tr("Every item equips the whole party. Pick an item from the stash to compare.")
	_equip.text = tr("Equip")
	_equip.disabled = true
	_salvage.text = tr("Salvage")
	_salvage.disabled = true


func _on_equip() -> void:
	if _selected >= 0 and meta.equip_from_stash(_selected):
		changed.emit()
		_refresh()


func _on_salvage() -> void:
	if _selected >= 0 and meta.salvage_from_stash(_selected) > 0:
		changed.emit()
		_refresh()


func _on_salvage_all() -> void:
	if meta.salvage_commons() > 0:
		_selected = -1
		changed.emit()
		_refresh()
