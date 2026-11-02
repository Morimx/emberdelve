extends Control
## Escena principal: campamento → puertas → combate → nivel → recompensa → resultado.
## Toda la lógica vive en scripts/core; esta escena solo muestra, anima y pregunta.

const UNIT_VIEW := preload("res://scenes/components/unit_view.tscn")
const FLOATING_TEXT := preload("res://scenes/components/floating_text.tscn")
const CHOICE_CARD := preload("res://scenes/components/choice_card.tscn")

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const DOORS := {
	&"combat": {"name": "Combat", "desc": "A pack of monsters.", "color": Color("6170b8")},
	&"elite": {"name": "Elite", "desc": "A tough foe. Better loot and a shard.", "color": Color("d94b42")},
	&"event": {"name": "Unknown", "desc": "A shrine, a trap or a chest.", "color": Color("b065ec")},
	&"camp": {"name": "Camp", "desc": "Rest and rekindle the torch.", "color": Color("6fd35a")},
	&"boss": {"name": "The Lich", "desc": "Defeat it to keep everything.", "color": Color("f08a24")},
}
const OUTCOME_TEXT := {
	&"victory": "Boss defeated!",
	&"retreat": "Retreated in time",
	&"defeat": "The party fell",
	&"darkness": "Lost in the dark",
}
const BOON_ICONS := {
	&"attack_pct": &"weapon", &"defense": &"shield", &"lifesteal": &"skull", &"crit_chance": &"gem",
	&"max_hp_pct": &"armor", &"speed_pct": &"weapon", &"skill_power_pct": &"cross",
	&"heal_pct": &"cross", &"torch": &"torch",
}
const BOON_COLOR := Color("b065ec")

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
var _talents: TalentScreen
## Se ofreció un anuncio recompensado al terminar la expedición: entonces no se pide un
## midgame antes de la siguiente (regla de CrazyGames: no ambos entre los mismos niveles).
var _rewarded_offered := false
var _mute_button: Button
## Pantalla superpuesta abierta (armería); bloquea las teclas 1-9 del panel de cartas.
var _overlay: Control

var _step_label: Label
var _torch: TorchMeter
var _gold_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _loot_label: Label
var _speed_button: Button
var _backdrop: DungeonBackdrop
var _lanes: HBoxContainer
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _fx: Control
var _title: Label
var _info: Label
var _cards: HBoxContainer


func _ready() -> void:
	theme = UiSkin.make_theme()
	_build_ui()
	SaveIO.import_legacy(["save.json", "save.json.bak", "run.json", "run.json.bak"])
	meta = MetaState.load_from()
	Audio.set_muted(meta.muted)
	_update_hud()
	var resumed := RunStore.load_run(meta)
	if resumed == null:
		_show_camp(tr("This save comes from a newer version of the game and won't be modified.") if meta.newer_save else "")
		return
	_attach(resumed)
	_show_next(tr("Expedition restored: you're right where you left off."))


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
	# Teclas 1-9: eligen la carta en esa posición; S cambia la velocidad.
	# Enter/Espacio y las flechas usan el foco normal de Godot.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _talents != null or _overlay != null:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var buttons := _choice_buttons()
		var index := key.keycode - KEY_1
		if index < buttons.size() and not buttons[index].disabled:
			buttons[index].pressed.emit()
			get_viewport().set_input_as_handled()
	elif key.keycode == KEY_S:
		_on_speed()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_M:
		_toggle_mute()
		get_viewport().set_input_as_handled()


# --- pantallas ---------------------------------------------------------------

func _show_camp(message: String) -> void:
	expedition = null
	_clear_arena()
	_update_hud()
	Audio.play_music(&"camp")
	Platform.gameplay_stop()
	var home := GameData.dungeon(&"catacombs")
	_backdrop.set_palette(home.wall_tint, home.floor_color)
	_backdrop.set_campfire(true)
	_backdrop.set_light(1.0)
	var catalog := GameData.talents()
	for h in GameData.heroes():
		var u := Unit.from_hero(h, meta.hero_bonus(catalog))
		_add_unit_view(u, _party_row, u.hp)
	_set_text(tr("Camp"), message if message != "" else tr("Gold %d  ·  Shards %d  ·  Expeditions %d  ·  Deepest room %d/%d") % [meta.gold, meta.shards, meta.runs, meta.best_step, Expedition.STEPS])
	_clear_cards()
	var open_count := 0
	for d in GameData.dungeons():
		if meta.is_dungeon_unlocked(d):
			open_count += 1
	_add_card(SpriteBank.icon(&"door"), tr("Descend"), tr("Choose a dungeon. You start with %d light.") % meta.torch_start(catalog), tr("%d of %d open") % [open_count, GameData.DUNGEONS.size()], UiSkin.TORCH, _show_dungeon_select)
	var affordable := 0
	for t in catalog:
		if meta.can_buy(t):
			affordable += 1
	_add_card(SpriteBank.icon(&"gem"), tr("Constellation"), tr("Spend gold and shards on permanent talents."), tr("%d available") % affordable if affordable > 0 else tr("Save up"), UiSkin.GOLD, _open_talents)
	_add_card(SpriteBank.icon(&"armor"), tr("Armory"), tr("Equip, compare and salvage the loot you brought back."), tr("%d in stash") % meta.stash.size(), Loot.RARITY_COLORS[2], _open_armory)
	var upgradable := 0
	for h: HeroData in GameData.HEROES:
		if meta.can_upgrade_skill(h.id):
			upgradable += 1
	_add_card(SpriteBank.icon(&"cross"), tr("Skills"), tr("Train each hero's skill with shards."), tr("%d ready") % upgradable if upgradable > 0 else tr("Needs shards"), BOON_COLOR, _show_skills)
	_focus_first_card()


func _show_dungeon_select() -> void:
	_set_text(tr("Choose a dungeon"), tr("Beat a dungeon's boss to open the next one."))
	_clear_cards()
	for d in GameData.dungeons():
		var open := meta.is_dungeon_unlocked(d)
		var footer := tr("Cleared") if meta.cleared.has(String(d.id)) else (tr("Open") if open else tr("Locked"))
		var body := tr(d.description) if open else tr("Defeat the boss of %s first.") % tr(GameData.dungeon(d.unlock_after).display_name)
		var card := _add_card(SpriteBank.icon(d.boss.id, 2), tr(d.display_name), body, footer, d.wall_tint, _start_expedition.bind(d.id))
		card.disabled = not open
	_add_card(SpriteBank.icon(&"fire"), tr("Back"), tr("Return to the camp."), "", UiSkin.EDGE, func() -> void: _show_camp(""))
	_focus_first_card()


func _show_skills() -> void:
	_set_text(tr("Skills"), tr("Each level: +20%% skill power and 8%% faster cooldown. Shards: %d") % meta.shards)
	_clear_cards()
	for h: HeroData in GameData.HEROES:
		var lvl := meta.skill_level(h.id)
		var maxed := lvl >= MetaState.MAX_SKILL_LEVEL
		var footer := tr("MAX") if maxed else tr("Lv %d  ->  %d shards") % [lvl, meta.skill_cost(h.id)]
		var card := _add_card(SpriteBank.icon(h.id, 2), "%s: %s" % [tr(h.display_name), tr(h.skill_name)], tr(h.skill_description), footer, BOON_COLOR, _on_upgrade_skill.bind(h.id))
		card.disabled = not meta.can_upgrade_skill(h.id)
	_add_card(SpriteBank.icon(&"fire"), tr("Back"), tr("Return to the camp."), "", UiSkin.EDGE, func() -> void: _show_camp(""))
	_focus_first_card()


func _on_upgrade_skill(hero_id: StringName) -> void:
	if meta.upgrade_skill(hero_id):
		meta.save()
		_show_camp("")
		_show_skills()


func _start_expedition(dungeon_id: StringName = &"catacombs") -> void:
	if not _rewarded_offered:
		Platform.request_ad("midgame")
	_rewarded_offered = false
	_attach(GameData.new_expedition(meta, randi(), dungeon_id))
	_save_run()
	_show_doors(tr("You enter the %s. Every room burns light: get out before it goes dark.") % tr(GameData.dungeon(dungeon_id).display_name))


## Muestra la elección pendiente que corresponda: nivel, recompensa o puertas.
func _show_next(message: String = "") -> void:
	if expedition.pending_levelups > 0:
		_show_levelup()
	elif not expedition.pending_rewards.is_empty():
		_show_rewards()
	else:
		_show_doors(message)


func _show_doors(message: String) -> void:
	_update_hud()
	_show_party_only()
	_set_text(tr(expedition.floor_label()), message if message != "" else tr("Choose the next door, or retreat with all your loot."))
	_clear_cards()
	for kind: StringName in expedition.current_doors():
		var door: Dictionary = DOORS[kind]
		var cost: int = Expedition.TORCH_COST[kind]
		var footer := tr("-%d light") % cost
		if kind == &"camp":
			footer = tr("-%d light, then +%d") % [cost, Expedition.CAMP_TORCH]
		var door_name := tr(door.name)
		var icon := SpriteBank.icon(SpriteBank.DOOR_ICONS[kind])
		if kind == &"boss":
			var boss: EnemyData = GameData.dungeon(expedition.dungeon_id).boss
			door_name = tr(boss.display_name)
			icon = SpriteBank.icon(boss.id, 2)
		var card := _add_card(icon, door_name, tr(door.desc), footer, door.color, _on_door.bind(kind))
		card.disabled = not expedition.can_enter(kind)
	_add_card(SpriteBank.icon(&"torch"), tr("Retreat"), tr("Leave now and keep everything: %d gold, %d items.") % [expedition.gold, expedition.items.size()], tr("Keep 100%"), UiSkin.TORCH, _on_retreat)
	_focus_first_card()


func _show_levelup() -> void:
	_update_hud()
	Audio.play(&"levelup")
	_show_party_only()
	var remaining := expedition.pending_levelups
	_set_text(tr("Level up! Level %d") % (expedition.level - remaining + 1), tr("Choose a blessing for this expedition.") + ("  " + tr("(%d more to choose)") % (remaining - 1) if remaining > 1 else ""))
	_clear_cards()
	for i in expedition.levelup_options.size():
		var boon: BoonData = expedition.levelup_options[i]
		_add_card(SpriteBank.icon(BOON_ICONS.get(boon.stat, &"fire")), tr(boon.display_name), tr(boon.description), tr("Blessing"), BOON_COLOR, _on_levelup.bind(i))
	_focus_first_card()


func _show_rewards() -> void:
	_update_hud()
	_show_party_only()
	var text := tr("Take one reward.")
	if expedition.torch <= 0:
		text = tr("Out of light! Take supplies or the party gets lost in the dark (keep 50%).")
	_set_text(tr("Room cleared"), text)
	_clear_cards()
	for i in expedition.pending_rewards.size():
		var r: Dictionary = expedition.pending_rewards[i]
		match r.kind:
			&"item":
				var item: ItemData = r.item
				var color: Color = Loot.RARITY_COLORS[item.rarity]
				_add_card(SpriteBank.icon(item.slot), tr(item.display_name), _item_stats(item), tr(Loot.RARITY_NAMES[item.rarity]), color, _on_reward.bind(i), color.lightened(0.3))
			&"supplies":
				_add_card(SpriteBank.icon(&"torch"), tr("Supplies"), tr("+%d light and %d gold.") % [Expedition.SUPPLIES_TORCH, r.gold], tr("+%d light") % Expedition.SUPPLIES_TORCH, UiSkin.TORCH, _on_reward.bind(i))
			&"rest":
				_add_card(SpriteBank.icon(&"cross"), tr("Rest"), tr("The party heals %d%% of its health.") % int(Expedition.REST_HEAL * 100), tr("Heal"), UiSkin.HEAL, _on_reward.bind(i))
			&"boon":  # autoguardados de versiones anteriores
				_add_card(SpriteBank.icon(&"fire"), tr(r.boon.display_name), tr(r.boon.description), tr("Blessing"), BOON_COLOR, _on_reward.bind(i))
	_focus_first_card()


func _show_result() -> void:
	_show_party_only()
	var kept := expedition.kept
	var summary := meta.apply_run(kept)
	var err := meta.save()
	# Primero se cobra (save del progreso con last_run_id) y recién después se borra el
	# autoguardado: si se corta en el medio, load_run lo reconoce como cobrado.
	if err == OK:
		RunStore.clear()
	var lines: PackedStringArray = [
		tr("You keep %d%%.  Rooms %d/%d  ·  Gold +%d  ·  Shards +%d  ·  Items kept %d of %d") % [int(kept.ratio * 100), kept.steps, Expedition.STEPS, kept.gold, kept.shards, kept.items.size(), expedition.items.size()],
	]
	for item: ItemData in summary.equipped:
		lines.append(tr("Equipped: %s") % item.describe())
	if summary.stashed > 0:
		lines.append(tr("%d items went to the armory stash.") % summary.stashed)
	if summary.salvage > 0:
		lines.append(tr("Stash full: salvaged the worst for +%d gold") % summary.salvage)
	if summary.first_clear:
		var index := GameData.dungeons().find(GameData.dungeon(expedition.dungeon_id))
		if index + 1 < GameData.DUNGEONS.size():
			lines.append(tr("New dungeon unlocked: %s!") % tr(GameData.DUNGEONS[index + 1].display_name))
	if err != OK:
		lines.append(tr("(Couldn't save: %s)") % error_string(err))
	var good: bool = kept.ratio >= 1.0
	Platform.gameplay_stop()
	Audio.play(&"victory" if good else &"defeat")
	if expedition.outcome == &"victory":
		Platform.happy_time()
	_set_text(tr(OUTCOME_TEXT[expedition.outcome]), "\n".join(lines), UiSkin.GOLD if good else UiSkin.DANGER)
	_clear_cards()
	_add_card(SpriteBank.icon(&"fire"), tr("Back to camp"), tr("Spend your loot on talents and try again."), tr("Continue"), UiSkin.TORCH, func() -> void: _show_camp(""))
	if Platform.rewarded_available() and kept.gold > 0:
		_rewarded_offered = true
		var bonus: int = kept.gold
		var ad_card := _add_card(SpriteBank.icon(&"coin"), tr("Double the gold"), tr("Watch a short ad to get +%d gold. Optional.") % bonus, tr("Watch ad"), UiSkin.GOLD, func() -> void: pass)
		ad_card.pressed.connect(_on_double_gold.bind(ad_card, bonus))
	_focus_first_card()


func _open_talents() -> void:
	_talents = TalentScreen.new()
	add_child(_talents)
	_talents.open(meta, GameData.talents())
	_talents.purchased.connect(func(_t: TalentData) -> void: meta.save())
	_talents.closed.connect(_close_talents)


func _close_talents() -> void:
	_talents.queue_free()
	_talents = null
	_show_camp("")


func _open_armory() -> void:
	var armory := ArmoryScreen.new()
	add_child(armory)
	armory.open(meta)
	_overlay = armory
	armory.changed.connect(func() -> void: meta.save())
	armory.closed.connect(_close_armory.bind(armory))


func _close_armory(armory: ArmoryScreen) -> void:
	armory.queue_free()
	_overlay = null
	_show_camp("")


# --- acciones ----------------------------------------------------------------

func _attach(ex: Expedition) -> void:
	expedition = ex
	expedition.torch_changed.connect(_on_torch_changed)
	expedition.checkpoint.connect(_save_run)
	expedition.ended.connect(_on_expedition_ended)
	_backdrop.set_campfire(false)
	Audio.play_music(&"dungeon")
	Platform.gameplay_start()
	var d := GameData.dungeon(ex.dungeon_id)
	_backdrop.set_palette(d.wall_tint, d.floor_color)


func _save_run() -> void:
	var err := RunStore.save_run(expedition)
	if err != OK:
		push_warning("No se pudo autoguardar la expedición: %s" % error_string(err))


func _on_door(kind: StringName) -> void:
	_clear_cards()
	Audio.play(&"door")
	var result := expedition.enter(kind)
	if result.has("error"):
		_show_doors(result.error)
		return
	if result.has("combat"):
		await _play_combat(result)
	if expedition.finished:
		return
	_show_next(tr(result.get("text", "")))


func _on_levelup(index: int) -> void:
	if expedition.choose_levelup(index) and not expedition.finished:
		_show_next()


func _on_reward(index: int) -> void:
	Audio.play(&"coin")
	if expedition.choose_reward(index) and not expedition.finished:
		_show_next()


func _on_retreat() -> void:
	expedition.retreat()


func _on_expedition_ended(_outcome: StringName, _kept: Dictionary) -> void:
	# El combate puede terminar la expedición mientras se reproduce; esperamos a que acabe.
	await get_tree().process_frame
	while _cards.has_meta("busy"):
		await get_tree().process_frame
	_show_result()


# --- combate -----------------------------------------------------------------

func _play_combat(result: Dictionary) -> void:
	_cards.set_meta("busy", true)
	_clear_arena()
	for u: Unit in result.enemies:
		_add_unit_view(u, _enemy_row, result.start_hp[u])
	for u: Unit in result.party:
		_add_unit_view(u, _party_row, result.start_hp.get(u, u.hp))
	_set_text(tr(DOORS[result.kind].name), tr("Fighting..."))
	skipping = false
	var skip := Button.new()
	skip.text = tr("1  Skip fight")
	skip.custom_minimum_size = Vector2(180, 44)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void: skipping = true)
	_cards.add_child(skip)
	skip.grab_focus.call_deferred()
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
	if result.combat.won:
		_float_at(_party_row.get_global_rect().get_center() - Vector2(0, 70), tr("Victory"), UiSkin.GOLD, true)
		if result.get("xp", 0) > 0:
			_float_at(_party_row.get_global_rect().get_center() - Vector2(0, 30), tr("LEVEL UP!"), BOON_COLOR, true)
	_set_text(tr("Victory") if result.combat.won else tr("Defeat"), "")
	_update_hud()
	await get_tree().create_timer(0.7 / SPEEDS[speed_index]).timeout
	_cards.remove_meta("busy")


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
			Audio.play(&"crit" if e.crit else &"hit")
			if source:
				source.lunge()
			if target:
				target.hurt(Color(1, 0.85, 0.3) if e.crit else Color(1, 0.4, 0.4), e.crit)
				_float_at(target.hit_point(), ("%d!" if e.crit else "%d") % e.amount, UiSkin.GOLD if e.crit else UiSkin.TEXT, e.crit)
			if e.crit:
				_add_trauma(0.4)
				return 0.08
			_add_trauma(0.22 if boss_fight and e.src.is_enemy else 0.08)
		"heal":
			if target:
				target.set_hp(e.hp)
				if not skipping:
					if e.src != e.dst:
						Audio.play(&"heal")
					target.healed()
					_float_at(target.hit_point(), "+%d" % e.amount, UiSkin.HEAL)
		"skill":
			if source and not skipping:
				Audio.play(&"skill")
				_float_at(source.hit_point() - Vector2(0, 34), tr(e.label), UiSkin.TORCH)
		"death":
			if target:
				target.set_hp(0)
				if not skipping:
					Audio.play(&"death")
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
	bg.color = UiSkin.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# HUD
	var hud_panel := PanelContainer.new()
	root.add_child(hud_panel)
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 16)
	hud_panel.add_child(hud)
	_step_label = _label(hud, "", 17)
	_torch = TorchMeter.new()
	hud.add_child(_torch)
	_gold_label = _icon_label(hud, &"coin", UiSkin.GOLD)
	_as_number(_gold_label)
	_level_label = _label(hud, "")
	_as_number(_level_label)
	_level_label.add_theme_color_override("font_color", BOON_COLOR.lightened(0.3))
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(90, 10)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = BOON_COLOR
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	hud.add_child(_xp_bar)
	_loot_label = _label(hud, "", 14)
	_loot_label.add_theme_color_override("font_color", UiSkin.MUTED)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)
	_mute_button = Button.new()
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.pressed.connect(_toggle_mute)
	hud.add_child(_mute_button)
	_speed_button = Button.new()
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.pressed.connect(_on_speed)
	hud.add_child(_speed_button)

	# Arena
	var arena := PanelContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame: StyleBoxTexture = UiSkin.panel(UiSkin.INK, UiSkin.EDGE, true).duplicate()
	frame.content_margin_left = 6
	frame.content_margin_right = 6
	frame.content_margin_top = 6
	frame.content_margin_bottom = 6
	arena.add_theme_stylebox_override("panel", frame)
	root.add_child(arena)
	var stage := Control.new()
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(stage)
	_backdrop = DungeonBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_backdrop)
	_lanes = HBoxContainer.new()
	_lanes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lanes.offset_bottom = -6
	_lanes.alignment = BoxContainer.ALIGNMENT_CENTER
	_lanes.add_theme_constant_override("separation", 110)
	_lanes.z_index = 2
	stage.add_child(_lanes)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 14)
	_lanes.add_child(_enemy_row)
	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 14)
	_lanes.add_child(_party_row)

	# Panel inferior: título, texto y cartas
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 228)
	root.add_child(bottom)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bottom.add_child(box)
	_title = _label(box, "", 20)
	_info = _label(box, "", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UiSkin.MUTED)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 12)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_cards)

	# Capa de efectos por encima de todo: números flotantes. No intercepta clics.
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_update_hud()


func _update_hud() -> void:
	_speed_button.text = tr("Speed x%d  [S]") % int(SPEEDS[speed_index])
	_mute_button.text = tr("Sound off  [M]") if Audio.is_muted() else tr("Sound on  [M]")
	var in_run := expedition != null and not expedition.finished
	_torch.visible = in_run
	_xp_bar.visible = in_run
	_level_label.visible = in_run
	_loot_label.visible = in_run
	if not in_run:
		_step_label.text = tr("Torchbound")
		_gold_label.text = "%d" % meta.gold if meta else ""
		return
	_step_label.text = tr(expedition.floor_label())
	_torch.set_value(expedition.torch, expedition.torch_max)
	_backdrop.set_light(float(expedition.torch) / maxf(1.0, expedition.torch_max))
	_gold_label.text = "%d" % expedition.gold
	_level_label.text = tr("Lv %d") % expedition.level
	_xp_bar.max_value = expedition.xp_to_next()
	_xp_bar.value = expedition.xp
	_loot_label.text = tr("Items %d · Blessings %d") % [expedition.items.size(), expedition.boons_taken.size()]


func _set_text(title: String, body: String, title_color := UiSkin.GOLD) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	_info.text = body
	_info.visible = body != ""


func _item_stats(item: ItemData) -> String:
	var parts: PackedStringArray = []
	if item.attack > 0:
		parts.append(tr("+%d attack") % item.attack)
	if item.defense > 0:
		parts.append(tr("+%d defense") % item.defense)
	if item.max_hp > 0:
		parts.append(tr("+%d health") % item.max_hp)
	return ", ".join(parts) + "\n" + tr("Kept if you make it back.")


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
			row.remove_child(child)
			child.queue_free()


func _clear_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


func _add_card(icon: Texture2D, title: String, body: String, footer: String, accent: Color, callback: Callable, title_color := UiSkin.TEXT) -> ChoiceCard:
	var card: ChoiceCard = CHOICE_CARD.instantiate()
	_cards.add_child(card)
	card.setup(_cards.get_child_count(), icon, title, body, footer, accent, title_color)
	card.pressed.connect(func() -> void: Audio.play(&"click"))
	card.pressed.connect(callback)
	return card


func _choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _cards.get_children():
		if child is Button:
			out.append(child)
	return out


func _focus_first_card() -> void:
	for button in _choice_buttons():
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus.call_deferred()
			return


func _label(parent: Node, text: String, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


## Usa la fuente de números (Silkscreen) en lugar del tamaño fijo de _label.
func _as_number(label: Label) -> void:
	label.remove_theme_font_size_override("font_size")
	label.theme_type_variation = UiSkin.NUMBER_VARIATION


func _icon_label(parent: Node, icon_id: StringName, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = SpriteBank.icon(icon_id, 2)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var label := _label(row, "", 17)
	label.add_theme_color_override("font_color", color)
	return label


func _toggle_mute() -> void:
	Audio.set_muted(not Audio.is_muted())
	if meta:
		meta.muted = Audio.is_muted()
		meta.save()
	_update_hud()


func _on_torch_changed(value: int) -> void:
	_update_hud()
	if value > 0 and value <= TorchMeter.LOW_LIGHT:
		Audio.play(&"torch_low", 0.0)


func _on_double_gold(card: ChoiceCard, bonus: int) -> void:
	card.disabled = true
	Platform.request_ad("rewarded", func(ok: bool) -> void:
		if not ok:
			card.disabled = false
			_set_text(_title.text, tr("The ad couldn't play. No problem, your loot is safe."))
			return
		meta.gold += bonus
		meta.save()
		Audio.play(&"coin")
		card.queue_free()
		_set_text(_title.text, tr("+%d gold added. Thanks!") % bonus))


func _on_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	_update_hud()
