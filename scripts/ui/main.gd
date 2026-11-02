extends Control
## Prototipo gris: campamento → puertas → combate → recompensa → resultado.
## Toda la lógica vive en scripts/core; esta escena solo muestra y pregunta.

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
const TORCH := Color("ff9a3c")

var meta: MetaState
var expedition: Expedition
var speed_index := 0
var skipping := false
var unit_views := {}

var _torch_label: Label
var _gold_label: Label
var _step_label: Label
var _speed_button: Button
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _info: Label
var _actions: HFlowContainer


func _ready() -> void:
	_build_ui()
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


# --- pantallas ---------------------------------------------------------------

func _show_camp(message: String) -> void:
	_clear_arena()
	_update_hud()
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
	_add_action(tr("Upgrade attack +8%% (%d gold)") % meta.upgrade_cost(&"attack"), _on_upgrade.bind(&"attack"), not meta.can_upgrade(&"attack"))
	_add_action(tr("Upgrade health +10%% (%d gold)") % meta.upgrade_cost(&"hp"), _on_upgrade.bind(&"hp"), not meta.can_upgrade(&"hp"))
	if meta.torch_level < MetaState.MAX_TORCH_LEVEL:
		_add_action(tr("Torch +1 (%d shards)") % meta.upgrade_cost(&"torch"), _on_upgrade.bind(&"torch"), not meta.can_upgrade(&"torch"))
	_add_action(tr("▶ New expedition"), _start_expedition).modulate = TORCH


func _start_expedition() -> void:
	_attach(GameData.new_expedition(meta, randi()))
	_save_run()
	_show_doors(tr("You enter the Catacombs. Every room burns light: get out before it goes dark."))


func _show_doors(message: String) -> void:
	_update_hud()
	_show_party_only()
	_info.text = tr(message) + "\n\n" + tr("Pick the next door, or retreat with all your loot.")
	_clear_actions()
	for kind: StringName in expedition.current_doors():
		var cost: int = Expedition.TORCH_COST[kind]
		var label := tr("%s  (−%d light)") % [tr(DOOR_NAMES[kind]), cost]
		if kind == &"camp":
			label = tr("Camp  (−%d, +%d light, heals)") % [cost, Expedition.CAMP_TORCH]
		_add_action(label, _on_door.bind(kind), not expedition.can_enter(kind))
	_add_action(tr("⟲ Retreat (keep 100%% · %d gold, %d items)") % [expedition.gold, expedition.items.size()], _on_retreat).modulate = TORCH


func _show_rewards() -> void:
	_update_hud()
	var text := tr("Room cleared. Choose a reward.")
	if expedition.torch <= 0:
		text += "\n" + tr("Out of light! Unless you take supplies, the party gets lost in the dark (keep 50%).")
	_info.text = text
	_clear_actions()
	for i in expedition.pending_rewards.size():
		var r: Dictionary = expedition.pending_rewards[i]
		var label := ""
		match r.kind:
			&"item":
				label = tr("Item: %s\n(yours to keep if you make it back)") % r.item.describe()
			&"boon":
				label = tr("Boon: %s\n%s (this expedition only)") % [tr(r.boon.display_name), tr(r.boon.description)]
			&"supplies":
				label = tr("Supplies: +%d light, +%d gold") % [Expedition.SUPPLIES_TORCH, r.gold]
		var button := _add_action(label, _on_reward.bind(i))
		if r.kind == &"item":
			button.modulate = Loot.RARITY_COLORS[r.item.rarity].lightened(0.3)


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
	_add_action(tr("Back to camp"), func() -> void: _show_camp(""))


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
	_add_action(tr("Skip ⏭"), func() -> void: skipping = true)

	var last_t := 0.0
	for e: Dictionary in result.combat.events:
		if not skipping:
			var wait: float = (e.t - last_t) / SPEEDS[speed_index]
			if wait > 0.02:
				await get_tree().create_timer(wait).timeout
			last_t = e.t
		_apply_event(e)
	for u: Unit in result.enemies + result.party:
		_refresh_view(u, u.hp)
	_info.text = tr("Victory") if result.combat.won else tr("Defeat")
	await get_tree().create_timer(0.4 / SPEEDS[speed_index]).timeout
	_actions.remove_meta("busy")


func _apply_event(e: Dictionary) -> void:
	match e.type:
		"hit":
			_refresh_view(e.dst, e.hp)
			_flash(e.dst, Color(1, 0.4, 0.4) if not e.crit else Color(1, 0.85, 0.3))
			if not skipping:
				_info.text = "%s → %s  −%d%s" % [tr(e.src.display_name), tr(e.dst.display_name), e.amount, "  " + tr("CRITICAL!") if e.crit else ""]
		"heal":
			_refresh_view(e.dst, e.hp)
			_flash(e.dst, Color(0.4, 1, 0.5))
		"skill":
			if not skipping:
				_info.text = tr("%s uses %s") % [tr(e.src.display_name), tr(e.label)]
		"death":
			_refresh_view(e.dst, 0)


# --- vistas ------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 24)
	root.add_child(hud)
	_step_label = _label(hud, "")
	_torch_label = _label(hud, "")
	_torch_label.add_theme_color_override("font_color", TORCH)
	_gold_label = _label(hud, "")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)
	_speed_button = Button.new()
	_speed_button.pressed.connect(_on_speed)
	hud.add_child(_speed_button)

	var arena := PanelContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_border_width_all(3)
	style.border_color = Color("3d4784")
	arena.add_theme_stylebox_override("panel", style)
	root.add_child(arena)
	var lanes := HBoxContainer.new()
	lanes.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes.add_theme_constant_override("separation", 80)
	arena.add_child(lanes)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 16)
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes.add_child(_enemy_row)
	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 16)
	_party_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes.add_child(_party_row)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.y = 96
	root.add_child(_info)

	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 10)
	root.add_child(_actions)
	_update_hud()


func _update_hud() -> void:
	_speed_button.text = tr("Speed x%d") % int(SPEEDS[speed_index])
	if expedition == null or expedition.finished:
		_step_label.text = tr("Torchbound · prototype")
		_torch_label.text = ""
		_gold_label.text = ""
		return
	_step_label.text = tr(expedition.floor_label())
	var bar := ""
	for i in maxi(expedition.torch_max, expedition.torch):
		bar += "■" if i < expedition.torch else "□"
	_torch_label.text = tr("LIGHT %s %d") % [bar, expedition.torch]
	_gold_label.text = tr("Gold %d · Items %d · Boons %d") % [expedition.gold, expedition.items.size(), expedition.boons_taken.size()]


func _show_party_only() -> void:
	_clear_arena()
	if expedition == null:
		return
	for u in expedition.party:
		_add_unit_view(u, _party_row, u.hp)


func _add_unit_view(u: Unit, row: HBoxContainer, hp: int) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	var name_label := _label(box, tr(u.display_name))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := ColorRect.new()
	body.color = u.color
	body.custom_minimum_size = Vector2(56, 96 if u.max_hp > 300 else 72)
	box.add_child(body)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(90, 12)
	bar.show_percentage = false
	bar.max_value = u.max_hp
	box.add_child(bar)
	var hp_label := _label(box, "")
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(box)
	unit_views[u] = {"body": body, "bar": bar, "hp": hp_label}
	_refresh_view(u, hp)


func _refresh_view(u: Unit, hp: int) -> void:
	var view: Dictionary = unit_views.get(u, {})
	if view.is_empty():
		return
	view.bar.max_value = u.max_hp
	view.bar.value = hp
	view.hp.text = "%d/%d" % [hp, u.max_hp]
	view.body.modulate.a = 1.0 if hp > 0 else 0.2


func _flash(u: Unit, color: Color) -> void:
	var view: Dictionary = unit_views.get(u, {})
	if view.is_empty() or skipping:
		return
	var body: ColorRect = view.body
	body.self_modulate = color
	create_tween().tween_property(body, "self_modulate", Color.WHITE, 0.25)


func _clear_arena() -> void:
	unit_views.clear()
	for row in [_enemy_row, _party_row]:
		for child in row.get_children():
			child.queue_free()


func _clear_actions() -> void:
	for child in _actions.get_children():
		child.queue_free()


func _add_action(text: String, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	_actions.add_child(button)
	return button


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _on_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	_update_hud()
