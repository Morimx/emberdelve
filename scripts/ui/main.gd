extends Control
## Prototipo jugable: campamento → puertas → combate → recompensa → resultado.
## Toda la lógica vive en scripts/core; esta escena solo muestra, anima y pregunta.

const UNIT_VIEW := preload("res://scenes/components/unit_view.tscn")
const FLOATING_TEXT := preload("res://scenes/components/floating_text.tscn")

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const DOOR_NAMES := {&"combat": "Combat", &"elite": "Elite", &"event": "Event ?", &"camp": "Camp", &"boss": "BOSS"}
const OUTCOME_TEXT := {
	&"victory": "Boss defeated!",
	&"retreat": "Retreated in time",
	&"defeat": "The party fell",
	&"darkness": "Lost in the dark",
}
const BG := Color("0b0e1d")
const PANEL := Color("161b36")
const EDGE := Color("3d4784")
const EDGE_HI := Color("6170b8")
const TEXT := Color("ece6d3")
const TORCH := Color("ff9a3c")
const GOLD := Color("f2c14e")
const HEAL := Color("6fd35a")

## Sacudida por "trauma": cada impacto suma, decae sola y se aplica al escenario, no a la lógica.
const SHAKE_DECAY := 1.6
const SHAKE_MAX := Vector2(10, 6)

var meta: MetaState
var expedition: Expedition
var speed_index := 0
var skipping := false
var unit_views := {}
var trauma := 0.0
var _shake_t := 0.0

var _torch: TorchMeter
var _gold_label: Label
var _step_label: Label
var _speed_button: Button
var _stage: Control
var _lanes: HBoxContainer
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _fx: Control
var _info: Label
var _actions: HFlowContainer


func _ready() -> void:
	theme = _make_theme()
	_build_ui()
	SaveIO.import_legacy(["save.json", "save.json.bak", "run.json", "run.json.bak"])
	meta = MetaState.load_from()
	var resumed := RunStore.load_run(meta)
	if resumed == null:
		_show_camp(tr("This save comes from a newer version of the game and won't be modified.") if meta.newer_save else "")
		return
	_attach(resumed)
	if expedition.pending_rewards.is_empty():
		_show_doors(tr("Expedition restored: you're right where you left off."))
	else:
		_show_rewards()


func _process(delta: float) -> void:
	if trauma <= 0.0:
		return
	trauma = maxf(trauma - SHAKE_DECAY * delta, 0.0)
	_shake_t += delta * 30.0
	var amount := trauma * trauma
	_lanes.position = Vector2(SHAKE_MAX.x * amount * sin(_shake_t * 1.7), SHAKE_MAX.y * amount * sin(_shake_t * 2.3))
	if trauma == 0.0:
		_lanes.position = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	# Teclas 1-9: activan la acción en esa posición; S cambia la velocidad.
	# Enter/Espacio y las flechas usan el foco normal de Godot.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var buttons := _action_buttons()
		var index := key.keycode - KEY_1
		if index < buttons.size() and not buttons[index].disabled:
			buttons[index].pressed.emit()
			get_viewport().set_input_as_handled()
	elif key.keycode == KEY_S:
		_on_speed()
		get_viewport().set_input_as_handled()


# --- pantallas ---------------------------------------------------------------

func _show_camp(message: String) -> void:
	_clear_arena()
	_update_hud()
	# El grupo espera en el campamento con las stats que le dan las mejoras y el equipo.
	for h in GameData.heroes():
		var u := Unit.from_hero(h, meta.hero_bonus())
		_add_unit_view(u, _party_row, u.hp)
	var lines: PackedStringArray = []
	if message != "":
		lines.append(message)
		lines.append("")
	lines.append(tr("CAMP  ·  Gold %d  ·  Shards %d") % [meta.gold, meta.shards])
	lines.append(tr("Expeditions: %d  ·  Deepest room: %d/%d") % [meta.runs, meta.best_step, Expedition.STEPS])
	lines.append(tr("Attack Lv %d  ·  Health Lv %d  ·  Starting torch %d") % [meta.attack_level, meta.hp_level, meta.torch_start()])
	for slot in Loot.SLOTS:
		var item: ItemData = meta.equipped.get(slot)
		lines.append("%s: %s" % [tr(Loot.SLOT_NAMES[slot]), item.describe() if item else "—"])
	_info.text = "\n".join(lines)

	_clear_actions()
	_add_action(tr("▶ New expedition"), _start_expedition, false, SpriteBank.icon(&"door")).modulate = TORCH
	_add_action(tr("Attack +8%% (%d gold)") % meta.upgrade_cost(&"attack"), _on_upgrade.bind(&"attack"), not meta.can_upgrade(&"attack"), SpriteBank.icon(&"weapon"))
	_add_action(tr("Health +10%% (%d gold)") % meta.upgrade_cost(&"hp"), _on_upgrade.bind(&"hp"), not meta.can_upgrade(&"hp"), SpriteBank.icon(&"armor"))
	if meta.torch_level < MetaState.MAX_TORCH_LEVEL:
		_add_action(tr("Torch +1 (%d shards)") % meta.upgrade_cost(&"torch"), _on_upgrade.bind(&"torch"), not meta.can_upgrade(&"torch"), SpriteBank.icon(&"torch"))
	_focus_first_action()


func _start_expedition() -> void:
	_attach(GameData.new_expedition(meta, randi()))
	_save_run()
	_show_doors(tr("You enter the Catacombs. Every room burns light: get out before it goes dark."))


func _show_doors(message: String) -> void:
	_update_hud()
	_show_party_only()
	_info.text = (tr(message) + "\n\n" if message != "" else "") + tr("Pick the next door, or retreat with all your loot.")
	_clear_actions()
	for kind: StringName in expedition.current_doors():
		var cost: int = Expedition.TORCH_COST[kind]
		var label := tr("%s  (−%d light)") % [tr(DOOR_NAMES[kind]), cost]
		if kind == &"camp":
			label = tr("Camp  (−%d, +%d light, heals)") % [cost, Expedition.CAMP_TORCH]
		_add_action(label, _on_door.bind(kind), not expedition.can_enter(kind), SpriteBank.icon(SpriteBank.DOOR_ICONS[kind]))
	_add_action(tr("Retreat (keep 100%% · %d gold, %d items)") % [expedition.gold, expedition.items.size()], _on_retreat, false, SpriteBank.icon(&"torch")).modulate = TORCH
	_focus_first_action()


func _show_rewards() -> void:
	_update_hud()
	_show_party_only()
	var text := tr("Room cleared. Choose a reward.")
	if expedition.torch <= 0:
		text += "\n" + tr("Out of light! Unless you take supplies, the party gets lost in the dark (keep 50%).")
	_info.text = text
	_clear_actions()
	for i in expedition.pending_rewards.size():
		var r: Dictionary = expedition.pending_rewards[i]
		var label := ""
		var icon: Texture2D
		match r.kind:
			&"item":
				label = tr("Item: %s\n(yours to keep if you make it back)") % r.item.describe()
				icon = SpriteBank.icon(r.item.slot)
			&"boon":
				label = tr("Boon: %s\n%s (this expedition only)") % [tr(r.boon.display_name), tr(r.boon.description)]
				icon = SpriteBank.icon(&"fire")
			&"supplies":
				label = tr("Supplies: +%d light, +%d gold") % [Expedition.SUPPLIES_TORCH, r.gold]
				icon = SpriteBank.icon(&"torch")
		var button := _add_action(label, _on_reward.bind(i), false, icon)
		if r.kind == &"item":
			button.add_theme_color_override("font_color", Loot.RARITY_COLORS[r.item.rarity].lightened(0.25))
	_focus_first_action()


func _show_result() -> void:
	_show_party_only()
	_update_hud()
	var kept := expedition.kept
	var summary := meta.apply_run(kept)
	var err := meta.save()
	# Primero se cobra (save del progreso con last_run_id) y recién después se borra el
	# autoguardado: si se corta en el medio, load_run lo reconoce como cobrado.
	if err == OK:
		RunStore.clear()
	var lines: PackedStringArray = [
		tr("%s — you keep %d%%") % [tr(OUTCOME_TEXT[expedition.outcome]), int(kept.ratio * 100)],
		tr("Rooms: %d/%d  ·  Gold +%d  ·  Shards +%d") % [kept.steps, Expedition.STEPS, kept.gold, kept.shards],
		tr("Items kept: %d of %d") % [kept.items.size(), expedition.items.size()],
	]
	for item: ItemData in summary.equipped:
		lines.append(tr("Equipped: %s") % item.describe())
	if summary.salvage > 0:
		lines.append(tr("Salvaged: +%d gold") % summary.salvage)
	if err != OK:
		lines.append(tr("(Couldn't save: %s)") % error_string(err))
	_info.text = "\n".join(lines)
	_clear_actions()
	_add_action(tr("Back to camp"), func() -> void: _show_camp(""), false, SpriteBank.icon(&"fire"))
	_focus_first_action()


# --- acciones ----------------------------------------------------------------

func _on_upgrade(kind: StringName) -> void:
	if meta.upgrade(kind):
		meta.save()
	_show_camp("")


func _attach(ex: Expedition) -> void:
	expedition = ex
	expedition.torch_changed.connect(func(_v: int) -> void: _update_hud())
	expedition.checkpoint.connect(_save_run)
	expedition.ended.connect(_on_expedition_ended)


func _save_run() -> void:
	var err := RunStore.save_run(expedition)
	if err != OK:
		push_warning("No se pudo autoguardar la expedición: %s" % error_string(err))


func _on_door(kind: StringName) -> void:
	_clear_actions()
	var result := expedition.enter(kind)
	if result.has("error"):
		_show_doors(result.error)
		return
	if result.has("combat"):
		await _play_combat(result)
	if expedition.finished:
		return
	if not expedition.pending_rewards.is_empty():
		_show_rewards()
	else:
		_show_doors(result.get("text", ""))


func _on_reward(index: int) -> void:
	if not expedition.choose_reward(index):
		return
	if not expedition.finished:
		_show_doors("")


func _on_retreat() -> void:
	expedition.retreat()


func _on_expedition_ended(_outcome: StringName, _kept: Dictionary) -> void:
	# El combate puede terminar la expedición mientras se reproduce; esperamos a que acabe.
	await get_tree().process_frame
	while _actions.has_meta("busy"):
		await get_tree().process_frame
	_show_result()


# --- combate -----------------------------------------------------------------

func _play_combat(result: Dictionary) -> void:
	_actions.set_meta("busy", true)
	_clear_arena()
	for u: Unit in result.enemies:
		_add_unit_view(u, _enemy_row, result.start_hp[u])
	for u: Unit in result.party:
		_add_unit_view(u, _party_row, result.start_hp.get(u, u.hp))
	_info.text = tr(DOOR_NAMES[result.kind]) + "…"
	skipping = false
	_add_action(tr("Skip"), func() -> void: skipping = true)
	_focus_first_action()
	await get_tree().process_frame  # que el layout ubique las vistas antes del primer número

	var boss_fight: bool = result.kind == &"boss"
	var last_t := 0.0
	for e: Dictionary in result.combat.events:
		if not skipping:
			var wait: float = (e.t - last_t) / SPEEDS[speed_index]
			if wait > 0.02:
				await get_tree().create_timer(wait).timeout
			last_t = e.t
		var pause := _apply_event(e, boss_fight)
		if pause > 0.0 and not skipping:
			await get_tree().create_timer(pause / SPEEDS[speed_index]).timeout
	for u: Unit in result.enemies + result.party:
		var view: UnitView = unit_views.get(u)
		if view:
			view.set_hp(u.hp)
	_info.text = tr("Victory") if result.combat.won else tr("Defeat")
	if result.combat.won:
		_float_at(_party_row.get_global_rect().get_center() - Vector2(0, 60), tr("Victory"), GOLD, true)
	await get_tree().create_timer(0.6 / SPEEDS[speed_index]).timeout
	_actions.remove_meta("busy")


## Aplica un evento a las vistas. Devuelve una pausa extra (hit-stop) para impactos fuertes.
func _apply_event(e: Dictionary, boss_fight: bool) -> float:
	var target: UnitView = unit_views.get(e.get("dst"))
	var source: UnitView = unit_views.get(e.get("src"))
	match e.type:
		"hit":
			if target:
				target.set_hp(e.hp)
			if skipping:
				return 0.0
			if source:
				source.lunge()
			if target:
				target.hurt(Color(1, 0.85, 0.3) if e.crit else Color(1, 0.4, 0.4), e.crit)
				_float_at(target.hit_point(), ("%d!" if e.crit else "%d") % e.amount, GOLD if e.crit else TEXT, e.crit)
			if e.crit:
				_add_trauma(0.4)
				return 0.08
			_add_trauma(0.22 if boss_fight and e.src.is_enemy else 0.08)
		"heal":
			if target:
				target.set_hp(e.hp)
				if not skipping:
					target.healed()
					_float_at(target.hit_point(), "+%d" % e.amount, HEAL)
		"skill":
			if source and not skipping:
				_float_at(source.hit_point() - Vector2(0, 30), tr(e.label), TORCH)
				_info.text = tr("%s uses %s") % [tr(e.src.display_name), tr(e.label)]
		"death":
			if target:
				target.set_hp(0)
				if not skipping:
					target.die()
					_add_trauma(0.5 if e.dst.max_hp > 300 else 0.3)
					return 0.12
	return 0.0


func _float_at(global_point: Vector2, text: String, color: Color, big := false) -> void:
	var label: FloatingText = FLOATING_TEXT.instantiate()
	_fx.add_child(label)
	label.position = global_point - _fx.global_position + Vector2(randf_range(-10, 10), 0)
	label.popup(text, color, big)


func _add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


# --- vistas ------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 20)
	root.add_child(hud)
	_step_label = _label(hud, "")
	_torch = TorchMeter.new()
	hud.add_child(_torch)
	_gold_label = _label(hud, "")
	_gold_label.add_theme_color_override("font_color", GOLD)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)
	_speed_button = Button.new()
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.pressed.connect(_on_speed)
	hud.add_child(_speed_button)

	var arena := PanelContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.clip_contents = true
	var frame := StyleBoxFlat.new()
	frame.bg_color = PANEL
	frame.set_border_width_all(3)
	frame.border_color = EDGE
	arena.add_theme_stylebox_override("panel", frame)
	root.add_child(arena)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(_stage)
	var wall := TextureRect.new()
	wall.texture = SpriteBank.brick_texture()
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.modulate = Color(0.75, 0.75, 0.85)
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.scale = Vector2(2, 2)
	_stage.add_child(wall)
	var floor_band := ColorRect.new()
	floor_band.color = Color("10142e")
	floor_band.anchor_left = 0.0
	floor_band.anchor_right = 1.0
	floor_band.anchor_top = 0.72
	floor_band.anchor_bottom = 1.0
	_stage.add_child(floor_band)

	_lanes = HBoxContainer.new()
	_lanes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lanes.alignment = BoxContainer.ALIGNMENT_CENTER
	_lanes.add_theme_constant_override("separation", 90)
	_stage.add_child(_lanes)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 14)
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lanes.add_child(_enemy_row)
	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 14)
	_party_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lanes.add_child(_party_row)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.y = 84
	root.add_child(_info)

	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 10)
	root.add_child(_actions)

	# Capa de efectos por encima de todo: números flotantes. No intercepta clics.
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_update_hud()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color("1f2648"), "hover": Color("2a3366"), "pressed": Color("12162e"), "focus": Color("2a3366"), "disabled": Color("14182e")}[state]
		box.set_border_width_all(3)
		box.border_color = {"normal": EDGE, "hover": EDGE_HI, "pressed": EDGE, "focus": GOLD, "disabled": Color("232848")}[state]
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		if state == "focus":
			box.draw_center = false
		t.set_stylebox(state, "Button", box)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("5c6290"))
	t.set_constant("icon_max_width", "Button", 28)
	t.set_constant("h_separation", "Button", 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("05060f")
	bar_bg.set_border_width_all(2)
	bar_bg.border_color = Color.BLACK
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("d94b42")
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


func _update_hud() -> void:
	_speed_button.text = tr("Speed x%d") % int(SPEEDS[speed_index])
	if expedition == null or expedition.finished:
		_step_label.text = tr("Torchbound")
		_torch.set_value(0, 0)
		_gold_label.text = ""
		return
	_step_label.text = tr(expedition.floor_label())
	_torch.set_value(expedition.torch, expedition.torch_max)
	_gold_label.text = tr("Gold %d · Items %d · Boons %d") % [expedition.gold, expedition.items.size(), expedition.boons_taken.size()]


func _show_party_only() -> void:
	_clear_arena()
	if expedition == null:
		return
	for u in expedition.party:
		_add_unit_view(u, _party_row, u.hp)


func _add_unit_view(u: Unit, row: HBoxContainer, hp: int) -> void:
	var view: UnitView = UNIT_VIEW.instantiate()
	row.add_child(view)
	view.setup(u, hp)
	unit_views[u] = view


func _clear_arena() -> void:
	unit_views.clear()
	trauma = 0.0
	_lanes.position = Vector2.ZERO
	for row in [_enemy_row, _party_row]:
		for child in row.get_children():
			child.queue_free()


func _clear_actions() -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()


func _add_action(text: String, callback: Callable, disabled := false, icon: Texture2D = null) -> Button:
	var button := Button.new()
	var index := _actions.get_child_count() + 1
	button.text = ("%d  %s" % [index, text]) if index <= 9 else text
	button.disabled = disabled
	button.icon = icon
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(callback)
	_actions.add_child(button)
	return button


func _action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _actions.get_children():
		if child is Button:
			out.append(child)
	return out


func _focus_first_action() -> void:
	for button in _action_buttons():
		if not button.disabled:
			button.grab_focus.call_deferred()
			return


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _on_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	_update_hud()
