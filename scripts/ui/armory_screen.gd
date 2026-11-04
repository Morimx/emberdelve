class_name ArmoryScreen
extends Control
## Armería: equipo de cada héroe (arma, armadura y amuleto) y depósito de objetos. Permite
## comparar con lo equipado, equipar y desguazar uno o todos los comunes.
## Emite changed (para guardar) y closed.

signal changed()
signal closed()

const TILE := 52.0

var meta: MetaState
var _selected := -1  # índice en el depósito; -1 = nada
var _slot_buttons := {}  # "héroe/slot" -> Button
var _grid := GridContainer.new()
var _detail_name := Label.new()
var _detail_body := Label.new()
var _wallet := Label.new()
## Un botón de equipar por héroe: los objetos de clase muestran solo el de su héroe.
var _equip_buttons := {}
var _salvage := Button.new()
var _stat_labels := {}  # héroe -> Label con sus estadísticas finales
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
	equipped_row.add_theme_constant_override("separation", 18)
	left.add_child(equipped_row)
	for h: HeroData in GameData.HEROES:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		equipped_row.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		col.add_child(head)
		var face := TextureRect.new()
		face.texture = SpriteBank.icon(h.id, 2)
		face.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		head.add_child(face)
		var hero_name := Label.new()
		hero_name.text = tr(h.display_name)
		hero_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(hero_name)
		var tiles := HBoxContainer.new()
		tiles.add_theme_constant_override("separation", 6)
		col.add_child(tiles)
		for slot in Loot.SLOTS:
			var b := _tile(null)
			b.pressed.connect(_on_slot_pressed.bind(h.id, slot))
			tiles.add_child(b)
			_slot_buttons["%s/%s" % [h.id, slot]] = b
		var stats := Label.new()
		stats.add_theme_font_size_override("font_size", 14)
		stats.add_theme_color_override("font_color", UiSkin.MUTED)
		col.add_child(stats)
		_stat_labels[h.id] = stats
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
	box.add_theme_constant_override("separation", 8)
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
	for h: HeroData in GameData.HEROES:
		var eb := Button.new()
		eb.custom_minimum_size = Vector2(0, 34)
		eb.icon = SpriteBank.icon(h.id, 1)
		eb.pressed.connect(_on_equip.bind(h.id))
		box.add_child(eb)
		_equip_buttons[h.id] = eb
	for b in [_salvage, _salvage_all]:
		b.custom_minimum_size = Vector2(0, 34)
		box.add_child(b)
	_salvage.pressed.connect(_on_salvage)
	_salvage_all.pressed.connect(_on_salvage_all)
	var back := Button.new()
	back.text = tr("Back to camp  [B]")
	back.custom_minimum_size = Vector2(0, 34)
	back.pressed.connect(func() -> void: closed.emit())
	box.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	# B vuelve al campamento (en CrazyGames, Esc está reservada para salir de pantalla completa).
	var key := event as InputEventKey
	if (key and key.pressed and not key.echo and key.keycode == KEY_B) or event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _tile(item: ItemData) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var color := UiSkin.EDGE
	if item:
		b.icon = SpriteBank.icon(item.icon_id(), 3)
		b.tooltip_text = _item_label(item)
		color = Loot.RARITY_COLORS[item.rarity]
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, UiSkin.card(color, state))
	b.add_theme_stylebox_override("focus", UiSkin.button("focus"))
	return b


func _refresh() -> void:
	_wallet.text = tr("Gold %d") % meta.gold
	# Estadísticas finales: base + talentos + equipo. El crítico de talentos lo suma Combat aparte.
	var bonus := meta.hero_bonus(GameData.talents())
	for h: HeroData in GameData.HEROES:
		var u := Unit.from_hero(h, bonus)
		var crit := u.crit_chance + float(bonus.get("crit_chance", 0.0))
		_stat_labels[h.id].text = "%s\n%s" % [
			tr("HP %d  ·  ATK %d  ·  DEF %d") % [u.max_hp, u.attack, u.defense],
			tr("Crit %d%%  ·  Skill Lv %d") % [roundi(crit * 100.0), meta.skill_level(h.id)],
		]
	for h: HeroData in GameData.HEROES:
		for slot in Loot.SLOTS:
			var item := meta.gear(h.id, slot)
			var b: Button = _slot_buttons["%s/%s" % [h.id, slot]]
			b.icon = SpriteBank.icon(item.icon_id() if item else slot, 3)
			b.modulate = Color.WHITE if item else Color(0.45, 0.45, 0.6)
			b.tooltip_text = _item_label(item) if item else tr(Loot.SLOT_NAMES[slot])
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
		_show_equipped(GameData.HEROES[0].id, Loot.SLOTS[0])
		if not meta.stash.is_empty():
			(_grid.get_child(0) as Button).grab_focus.call_deferred()


func _select(index: int) -> void:
	_selected = index
	var item := meta.stash[index]
	_detail_name.text = _item_label(item)
	_detail_name.add_theme_color_override("font_color", Loot.RARITY_COLORS[item.rarity].lightened(0.25))
	var lines: PackedStringArray = ["%s · %s" % [tr(Loot.SLOT_NAMES[item.slot]), _owner(item)]]
	# Los objetos de clase se comparan con lo que lleva su héroe; los amuletos, con nadie.
	var current: ItemData = meta.gear(item.hero, item.slot) if item.hero != &"" else null
	for stat in [["attack", "Attack"], ["defense", "Defense"], ["max_hp", "Health"]]:
		var new_value: int = item.get(stat[0])
		var old_value: int = current.get(stat[0]) if current else 0
		if new_value == 0 and old_value == 0:
			continue
		var delta := new_value - old_value
		var arrow := ("  (+%d)" % delta) if delta > 0 else (("  (-%d)" % -delta) if delta < 0 else "")
		lines.append("%s: %d%s" % [tr(stat[1]), new_value, arrow])
	lines.append("")
	if item.hero != &"":
		lines.append(tr("Equipped: %s") % (tr(current.display_name) if current else "-"))
	else:
		for h: HeroData in GameData.HEROES:
			var worn := meta.gear(h.id, item.slot)
			lines.append("%s: %s" % [tr(h.display_name), _item_label(worn) if worn else "-"])
	_detail_body.text = "\n".join(lines)
	for h: HeroData in GameData.HEROES:
		var eb: Button = _equip_buttons[h.id]
		eb.visible = item.can_equip(h.id)
		eb.text = tr("Equip on %s") % tr(h.display_name)
	_salvage.text = tr("Salvage  (+%d gold)") % meta.salvage_value(item)
	_salvage.disabled = false


func _on_slot_pressed(hero_id: StringName, slot: StringName) -> void:
	_selected = -1
	_show_equipped(hero_id, slot)


func _show_equipped(hero_id: StringName, slot: StringName) -> void:
	var item := meta.gear(hero_id, slot)
	_detail_name.text = "%s · %s" % [tr(GameData.hero(hero_id).display_name), tr(Loot.SLOT_NAMES[slot])]
	_detail_name.add_theme_color_override("font_color", UiSkin.TEXT)
	if item:
		_detail_body.text = (tr("Equipped: %s") % _item_label(item)) + "\n" + _stats_text(item)
	else:
		_detail_body.text = tr("Empty slot. Loot you bring back fills it.")
	_detail_body.text += "\n\n" + tr("Each hero uses gear of their class; charms fit anyone. Pick an item from the stash to compare.")
	for eb: Button in _equip_buttons.values():
		eb.visible = false
	_salvage.text = tr("Salvage")
	_salvage.disabled = true


func _owner(item: ItemData) -> String:
	return tr(GameData.hero(item.hero).display_name) if item.hero != &"" else tr("Any hero")


func _item_label(item: ItemData) -> String:
	return "%s · %s" % [tr(item.display_name), tr(Loot.RARITY_NAMES[item.rarity])]


func _stats_text(item: ItemData) -> String:
	var parts: PackedStringArray = []
	for stat in [["attack", "Attack"], ["defense", "Defense"], ["max_hp", "Health"]]:
		var value: int = item.get(stat[0])
		if value > 0:
			parts.append("%s +%d" % [tr(stat[1]), value])
	return ", ".join(parts)


func _on_equip(hero_id: StringName) -> void:
	if _selected >= 0 and meta.equip_from_stash(_selected, hero_id):
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
