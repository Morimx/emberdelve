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
const SHARD_COLOR := Color("5fd6e8")
## Escenario del fondo según el tipo de sala.
const ROOM_SCENES := {&"combat": &"corridor", &"elite": &"elite", &"event": &"shrine", &"camp": &"camp", &"boss": &"boss"}
const CLOUD_SAVE_KEY := "emberdelve_save"
const CLOUD_RUN_KEY := "emberdelve_run"

## Sacudida por "trauma": cada impacto suma, decae sola y se aplica al escenario, no a la lógica.
const SHAKE_DECAY := 1.6
const SHAKE_MAX := Vector2(10, 6)
const LANES_BOTTOM := -6.0
## Filas de la tabla de puntajes en el resultado (la tabla guarda Score.TABLE_SIZE).
const SCORE_ROWS := 5

var meta: MetaState
var expedition: Expedition
var speed_index := 0
var skipping := false
var unit_views := {}
var trauma := 0.0
var _shake_t := 0.0
var _talents: TalentScreen
## Momento (ms) del último globo de diálogo: evita que hablen todos a la vez.
var _last_bubble := 0
## Héroes que ya se quejaron de poca vida en este combate.
var _complained := {}
## Se ofreció un anuncio recompensado al terminar la expedición: entonces no se pide un
## midgame antes de la siguiente (regla de CrazyGames: no ambos entre los mismos niveles).
var _rewarded_offered := false
var _mute_button: Button
var _volume_slider: HSlider
var _lang_button: Button
## Chips del HUD con los totales del jugador: id -> {chip, value, caption}.
var _chips := {}
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
## Puntajes sobre la escena: la tabla al terminar una expedición o el récord en el campamento.
var _score_panel: Control
var _tip: CoachTip
var _lanes: HBoxContainer
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _fx: Control
var _title: Label
var _info: Label
var _cards: HBoxContainer


func _ready() -> void:
	theme = UiSkin.make_theme()
	Locale.apply("")  # idioma del navegador hasta leer el guardado
	_build_ui()
	SaveIO.import_legacy(["save.json", "save.json.bak", "run.json", "run.json.bak"])
	_set_text(tr("Loading..."), "")
	await Platform.wait_checked()
	_pull_cloud_saves()
	meta = MetaState.load_from()
	Audio.set_muted(meta.muted)
	Audio.set_volume(meta.volume)
	_volume_slider.set_value_no_signal(meta.volume * 100.0)
	Locale.apply(meta.language)
	_update_hud()
	var resumed := RunStore.load_run(meta)
	if resumed == null and meta.runs == 0 and meta.should_tip("start"):
		# Primera vez: directo a la primera mazmorra, sin pasar por el campamento.
		meta.mark_tip("start")
		_rewarded_offered = true  # sin anuncio antes de la primera partida
		_start_expedition(&"catacombs", tr("Welcome, delver! Lead your party through the catacombs and bring back their treasure."))
		return
	if resumed == null:
		_show_camp(tr("This save comes from a newer version of the game and won't be modified.") if meta.newer_save else "")
		return
	_attach(resumed)
	_show_next(tr("Expedition restored: you're right where you left off."))


func _process(delta: float) -> void:
	if expedition != null and not expedition.finished:
		expedition.elapsed += delta
	if trauma <= 0.0:
		return
	trauma = maxf(trauma - SHAKE_DECAY * delta, 0.0)
	_shake_t += delta * 30.0
	var amount := trauma * trauma
	_shake_lanes(Vector2(SHAKE_MAX.x * amount * sin(_shake_t * 1.7), SHAKE_MAX.y * amount * sin(_shake_t * 2.3)))
	if trauma == 0.0:
		_shake_lanes(Vector2.ZERO)


## Desplaza la fila de combatientes sin tocar position: en un Control anclado, asignar
## position fija los offsets con el tamaño de ese momento y descuadra la escena si después cambia.
func _shake_lanes(offset: Vector2) -> void:
	_lanes.offset_left = offset.x
	_lanes.offset_right = offset.x
	_lanes.offset_top = offset.y
	_lanes.offset_bottom = LANES_BOTTOM + offset.y


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
	elif key.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		_nudge_volume(-10.0)
		get_viewport().set_input_as_handled()
	elif key.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		_nudge_volume(10.0)
		get_viewport().set_input_as_handled()


# --- pantallas ---------------------------------------------------------------

func _show_camp(message: String) -> void:
	expedition = null
	_clear_arena()
	_update_hud()
	Audio.play_music(&"camp")
	Platform.gameplay_stop()
	var home := GameData.dungeon(&"catacombs")
	_backdrop.set_biome(home.biome, home.wall_tint, home.floor_color)
	_backdrop.set_campfire(true)
	_backdrop.set_light(1.0)
	var catalog := GameData.talents()
	for h in GameData.heroes():
		var u := Unit.from_hero(h, meta.hero_bonus(catalog))
		_add_unit_view(u, _party_row, u.hp)
	_show_best_score()
	var keeper := _add_npc(&"keeper", _enemy_row)
	_say_later(keeper, &"keeper", &"camp", UiSkin.TORCH, 0.6)
	_set_text(tr("Camp"), message if message != "" else tr("Choose a dungeon to explore, or spend your shards on talents and skills."))
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
	var talents_card := _add_card(SpriteBank.icon(&"gem"), tr("Constellation"), tr("Spend gold and shards on permanent talents."), tr("%d available") % affordable if affordable > 0 else tr("Save up"), UiSkin.GOLD, _open_talents)
	_add_card(SpriteBank.icon(&"armor"), tr("Armory"), tr("Equip, compare and salvage the loot you brought back."), tr("%d in stash") % meta.stash.size(), Loot.RARITY_COLORS[2], _open_armory)
	var upgradable := 0
	for h: HeroData in GameData.HEROES:
		if meta.can_upgrade_skill(h.id):
			upgradable += 1
	_add_card(SpriteBank.icon(&"cross"), tr("Skills"), tr("Train each hero's skill with shards."), tr("%d ready") % upgradable if upgradable > 0 else tr("Needs shards"), BOON_COLOR, _show_skills)
	_focus_first_card()
	if meta.runs > 0:
		_coach("camp", talents_card, tr("Spend what you brought back on permanent talents, then delve again."))


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
	_set_text(tr("Skills"), tr("Each level: +15%% skill power and 6%% faster cooldown. Shards: %d") % meta.shards)
	_clear_cards()
	for h: HeroData in GameData.HEROES:
		var lvl := meta.skill_level(h.id)
		var maxed := lvl >= MetaState.MAX_SKILL_LEVEL
		var footer := tr("MAX") if maxed else tr("Lv %d  ->  %d shards") % [lvl, meta.skill_cost(h.id)]
		var card := _add_card(SpriteBank.icon(h.id, 2), tr(h.skill_name), "%s. %s" % [tr(h.display_name), tr(h.skill_description)], footer, BOON_COLOR, _on_upgrade_skill.bind(h.id))
		card.disabled = not meta.can_upgrade_skill(h.id)
	_add_card(SpriteBank.icon(&"fire"), tr("Back"), tr("Return to the camp."), "", UiSkin.EDGE, func() -> void: _show_camp(""))
	_focus_first_card()


func _on_upgrade_skill(hero_id: StringName) -> void:
	if meta.upgrade_skill(hero_id):
		_save_meta()
		_show_camp("")
		_show_skills()


func _start_expedition(dungeon_id: StringName = &"catacombs", intro := "") -> void:
	if not _rewarded_offered:
		Platform.request_ad("midgame")
	_rewarded_offered = false
	_attach(GameData.new_expedition(meta, randi(), dungeon_id))
	_save_run()
	_show_doors(intro if intro != "" else tr("You enter the %s. Every room burns light: get out before it goes dark.") % tr(GameData.dungeon(dungeon_id).display_name))


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
	_backdrop.set_scene(&"corridor")
	_show_party_only()
	_set_text(tr(expedition.floor_label()), message if message != "" else tr("Choose the next door, or retreat with all your loot."))
	_clear_cards()
	var boss_card: ChoiceCard
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
		if kind == &"boss":
			boss_card = card
	var retreat := _add_card(SpriteBank.icon(&"torch"), tr("Retreat"), tr("Leave now and keep everything: %d gold, %d items.") % [expedition.gold, expedition.items.size()], tr("Keep 100%"), UiSkin.TORCH, _on_retreat)
	_focus_first_card()
	if expedition.torch <= 2 and meta.should_tip("retreat"):
		_coach("retreat", retreat, tr("Your light is low! Retreat now to keep 100% of your loot."))
	elif boss_card != null and meta.should_tip("boss"):
		_coach("boss", boss_card, tr("The boss waits behind this door. Beat it to open the next dungeon."))
	else:
		_coach("doors", _torch, tr("Every door burns light. If your torch goes out, you keep only half your loot."))


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
	_coach("levelup", _cards, tr("Blessings power up the whole party until this expedition ends."))


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
				_add_card(SpriteBank.icon(item.icon_id()), tr(item.display_name), _item_stats(item), tr(Loot.RARITY_NAMES[item.rarity]), color, _on_reward.bind(i), color.lightened(0.3))
			&"supplies":
				_add_card(SpriteBank.icon(&"torch"), tr("Supplies"), tr("+%d light and %d gold.") % [Expedition.SUPPLIES_TORCH, r.gold], tr("+%d light") % Expedition.SUPPLIES_TORCH, UiSkin.TORCH, _on_reward.bind(i))
			&"rest":
				_add_card(SpriteBank.icon(&"cross"), tr("Rest"), tr("The party heals %d%% of its health.") % int(Expedition.REST_HEAL * 100), tr("Heal"), UiSkin.HEAL, _on_reward.bind(i))
			&"boon":  # autoguardados de versiones anteriores
				_add_card(SpriteBank.icon(&"fire"), tr(r.boon.display_name), tr(r.boon.description), tr("Blessing"), BOON_COLOR, _on_reward.bind(i))
	_focus_first_card()
	_coach("reward", _cards, tr("Pick one reward. Items you carry out become permanent gear."))


func _show_result() -> void:
	_show_party_only()
	var kept := expedition.kept
	var summary := meta.apply_run(kept)
	var err := _save_meta()
	# Primero se cobra (save del progreso con last_run_id) y recién después se borra el
	# autoguardado: si se corta en el medio, load_run lo reconoce como cobrado.
	if err == OK:
		RunStore.clear()
		Platform.data_remove(CLOUD_RUN_KEY)
	var lines: PackedStringArray = [
		tr("You keep %d%%.  Rooms %d/%d  ·  Gold +%d  ·  Shards +%d  ·  Items kept %d of %d") % [int(kept.ratio * 100), kept.steps, Expedition.STEPS, kept.gold, kept.shards, kept.items.size(), expedition.items.size()],
	]
	for item: ItemData in summary.equipped:
		lines.append(tr("Equipped: %s") % _item_line(item))
	if summary.stashed > 0:
		lines.append(tr("%d items went to the armory stash.") % summary.stashed)
	if summary.salvage > 0:
		lines.append(tr("Stash full: salvaged the worst for +%d gold") % summary.salvage)
	# La primera vez que se vence la última mazmorra, el resultado agradece por jugar.
	var finale := false
	if summary.first_clear:
		var index := GameData.dungeons().find(GameData.dungeon(expedition.dungeon_id))
		if index + 1 < GameData.DUNGEONS.size():
			lines.append(tr("New dungeon unlocked: %s!") % tr(GameData.DUNGEONS[index + 1].display_name))
		else:
			finale = true
			lines.insert(0, tr("You conquered every dungeon. Thank you so much for playing Emberdelve!"))
			lines.insert(1, tr("Keep delving to grow stronger and beat your best runs."))
	if err != OK:
		lines.append(tr("(Couldn't save: %s)") % error_string(err))
	var good: bool = kept.ratio >= 1.0
	Platform.gameplay_stop()
	Audio.play(&"victory" if good else &"defeat")
	if expedition.outcome == &"victory":
		Platform.happy_time()
	var title := tr("Thank you for playing!") if finale else tr(OUTCOME_TEXT[expedition.outcome])
	_set_text(title, "\n".join(lines), UiSkin.GOLD if good else UiSkin.DANGER)
	_show_scores(int(kept.get("score", 0)), int(summary.rank))
	_clear_cards()
	_add_card(SpriteBank.icon(&"fire"), tr("Back to camp"), tr("Spend your loot on talents and try again."), tr("Continue"), UiSkin.TORCH, func() -> void: _show_camp(""))
	if Platform.rewarded_available() and kept.gold > 0:
		_rewarded_offered = true
		var bonus: int = kept.gold
		var ad_card := _add_card(SpriteBank.icon(&"coin"), tr("Double the gold"), tr("Watch a short ad to get +%d gold. Optional.") % bonus, tr("Watch ad"), UiSkin.GOLD, func() -> void: pass)
		ad_card.pressed.connect(_on_double_gold.bind(ad_card, bonus))
	_focus_first_card()


## Mejor puntaje del jugador, flotando sobre la fogata del campamento.
func _show_best_score() -> void:
	var stage := _backdrop.get_parent() as Control
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 3
	stage.add_child(box)
	_score_panel = box
	var caption := _label(box, tr("Best score"), 14)
	caption.add_theme_color_override("font_color", UiSkin.TEXT)
	var value := _label(box, str(meta.best_score()), 18)
	value.add_theme_color_override("font_color", UiSkin.GOLD)
	for label: Label in [caption, value]:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", UiSkin.INK)
		label.add_theme_constant_override("outline_size", 4)
	# Arriba de todo, en la columna de la fogata (centro de la escena) y sobre los nombres.
	var place := func() -> void:
		box.position = Vector2((stage.size.x - box.size.x) / 2.0, 6.0)
	box.resized.connect(place)
	stage.resized.connect(place)
	box.tree_exiting.connect(func() -> void: stage.resized.disconnect(place))
	place.call_deferred()


## Panel a la izquierda de la escena: puntaje de esta expedición y las mejores marcas.
## rank es la posición que ocupó en la tabla (-1 si no entró).
func _show_scores(score: int, rank: int) -> void:
	var panel := PanelContainer.new()
	var style: StyleBoxTexture = UiSkin.panel(UiSkin.INK, UiSkin.EDGE, true).duplicate()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(10, 8)
	panel.custom_minimum_size = Vector2(250, 0)
	panel.z_index = 3
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.get_parent().add_child(panel)
	_score_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	var head := _label(box, tr("Your score: %d") % score, 17)
	head.add_theme_color_override("font_color", UiSkin.GOLD)
	if rank == 0 and meta.scores.size() > 1:
		var best := _label(box, tr("New best score!"), 13)
		best.add_theme_color_override("font_color", UiSkin.TORCH)
	_label(box, tr("High scores"), 13).add_theme_color_override("font_color", UiSkin.MUTED)
	for i in mini(meta.scores.size(), SCORE_ROWS):
		_score_row(box, i, i == rank)
	if rank >= SCORE_ROWS:
		_score_row(box, rank, true)


func _score_row(parent: Node, index: int, highlight: bool) -> void:
	var entry: Dictionary = meta.scores[index]
	var row := _label(parent, "%d. %d  %s  %s  %s" % [
		index + 1, int(entry.score), tr(GameData.dungeon(StringName(entry.dungeon)).display_name),
		tr("%d rooms") % int(entry.steps), Score.format_time(int(entry.seconds)),
	], 12)
	row.add_theme_color_override("font_color", UiSkin.GOLD if highlight else UiSkin.TEXT)


func _open_talents() -> void:
	_talents = TalentScreen.new()
	add_child(_talents)
	_talents.open(meta, GameData.talents())
	_talents.purchased.connect(func(_t: TalentData) -> void: _save_meta())
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
	armory.changed.connect(func() -> void: _save_meta())
	armory.closed.connect(_close_armory.bind(armory))


func _close_armory(armory: ArmoryScreen) -> void:
	armory.queue_free()
	_overlay = null
	_show_camp("")


# --- acciones ----------------------------------------------------------------

func _attach(ex: Expedition) -> void:
	expedition = ex
	expedition.manual_combat = true
	expedition.torch_changed.connect(_on_torch_changed)
	expedition.checkpoint.connect(_save_run)
	expedition.ended.connect(_on_expedition_ended)
	_backdrop.set_campfire(false)
	Audio.play_music(&"dungeon")
	Platform.gameplay_start()
	var d := GameData.dungeon(ex.dungeon_id)
	_backdrop.set_biome(d.biome, d.wall_tint, d.floor_color)


func _save_run() -> void:
	var err := RunStore.save_run(expedition)
	if err == OK and not expedition.finished:
		Platform.data_set(CLOUD_RUN_KEY, JSON.stringify(expedition.to_dict()))
	if err != OK:
		push_warning("No se pudo autoguardar la expedición: %s" % error_string(err))


func _on_door(kind: StringName) -> void:
	_clear_cards()
	Audio.play(&"door")
	await _fade_stage(_backdrop.set_scene.bind(ROOM_SCENES.get(kind, &"corridor")))
	var result := expedition.enter(kind)
	if result.has("error"):
		_show_doors(result.error)
		return
	if result.has("fight"):
		await _play_combat(result)
	if expedition.finished:
		return
	if result.has("event"):
		await _play_event(result)
		if expedition.finished:
			return
		_show_event_result(result)
		return
	var text := tr(result.get("text", ""))
	if result.has("text_args"):
		text = text % result.text_args
	_show_next(text)


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

## Pelea a mano: avanza la simulación tick a tick y deja lanzar las habilidades con
## los botones (o las teclas 1-3). Al terminar, la expedición reparte las recompensas.
func _play_combat(result: Dictionary) -> void:
	_cards.set_meta("busy", true)
	_clear_arena()
	for u: Unit in result.enemies:
		_add_unit_view(u, _enemy_row, result.start_hp[u])
	for u: Unit in result.party:
		_add_unit_view(u, _party_row, result.start_hp.get(u, u.hp))
	_set_text(tr(DOORS[result.kind].name), tr("Use each hero's skill when it lights up. Unused skills fire on their own."))
	skipping = false
	var fight: Combat = result.fight
	var skill_buttons: Array[SkillButton] = []
	for u: Unit in fight.party:
		var hero := GameData.hero(u.id)
		var button := SkillButton.new()
		button.setup(skill_buttons.size() + 1, u, tr(hero.skill_name))
		button.tooltip_text = tr(hero.skill_description)
		button.pressed.connect(func() -> void: fight.request_skill(u))
		_cards.add_child(button)
		skill_buttons.append(button)
	var skip := Button.new()
	skip.text = tr("%d  Skip fight") % (skill_buttons.size() + 1)
	skip.custom_minimum_size = Vector2(160, 44)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func() -> void:
		skipping = true
		fight.auto_delay = 0.0)
	_cards.add_child(skip)
	_coach("combat", _cards, tr("Your heroes attack on their own. Click a skill (or press 1-3) when it glows. S changes the speed."))
	await get_tree().process_frame  # que el layout ubique las vistas antes del primer número

	var boss_fight: bool = result.kind == &"boss"
	_complained.clear()
	_combat_banter(result, boss_fight)
	while not fight.finished:
		var pause := 0.0
		for e: Dictionary in fight.step():
			pause = maxf(pause, _apply_event(e, boss_fight))
		if skipping:
			continue
		for button in skill_buttons:
			button.refresh(fight.skill_charge(button.unit), fight.skill_ready(button.unit), button.unit.is_alive())
		await get_tree().create_timer((Combat.TICK + pause) / SPEEDS[speed_index]).timeout
	expedition.finish_combat()
	for button in skill_buttons:
		button.refresh(0.0, false, button.unit.is_alive())
	skip.disabled = true
	for u: Unit in result.enemies + result.party:
		var view: UnitView = unit_views.get(u)
		if view:
			view.set_hp(u.hp)
	if result.combat.won:
		_float_at(_party_row.get_global_rect().get_center() - Vector2(0, 70), tr("Victory"), UiSkin.GOLD, true)
		if not skipping and randf() < 0.5:
			_say_random_hero(&"victory", 1.0)
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
			if target and not e.dst.is_enemy and e.hp > 0 and float(e.hp) / e.dst.max_hp < 0.3 and not _complained.has(e.dst):
				_complained[e.dst] = true
				_say(target, e.dst.id, &"low_hp", UiSkin.DANGER)
			if e.crit:
				if source and not e.src.is_enemy and randf() < 0.15:
					_say(source, e.src.id, &"crit", UiSkin.GOLD)
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


## Oscurece la escena, aplica el cambio de sala y vuelve a aclarar (sin esperar el final).
func _fade_stage(change: Callable) -> void:
	var stage := _backdrop.get_parent() as Control
	var veil := ColorRect.new()
	veil.color = Color(UiSkin.INK, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = 5
	stage.add_child(veil)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.15)
	await tw.finished
	change.call()
	var out := create_tween()
	out.tween_property(veil, "color:a", 0.0, 0.3).set_delay(0.05)
	out.tween_callback(veil.queue_free)


func _float_at(global_point: Vector2, text: String, color: Color, big := false) -> void:
	var label: FloatingText = FLOATING_TEXT.instantiate()
	_fx.add_child(label)
	label.position = global_point - _fx.global_position + Vector2(randf_range(-10, 10), 0)
	label.popup(text, color, big)


func _add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


# --- eventos de sala ----------------------------------------------------------

## Anima el evento (cofre, trampa o santuario) en la arena antes de mostrar el resultado.
func _play_event(result: Dictionary) -> void:
	_cards.set_meta("busy", true)
	_show_party_only()
	_set_text(tr("Something stirs..."), "")
	_backdrop.set_scene(&"shrine" if result.event == &"shrine" else &"corridor")
	await get_tree().process_frame
	var stage := _lanes.get_global_rect()
	match result.event:
		&"chest":
			await _animate_chest(Vector2(stage.position.x + stage.size.x * 0.27, stage.end.y - 10), result.item, result.gold)
		&"trap":
			await _animate_trap(result.damage)
		&"shrine":
			await _animate_shrine(Vector2(stage.get_center().x, stage.end.y - 10), result.light)
	_update_hud()
	_cards.remove_meta("busy")


func _animate_chest(foot: Vector2, item: ItemData, gold_amount: int) -> void:
	var chest := _fx_sprite(&"chest", foot, 84.0)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(chest, "rotation", 0.12, 0.06)
		tw.tween_property(chest, "rotation", -0.12, 0.06)
	tw.tween_property(chest, "rotation", 0.0, 0.05)
	await tw.finished
	chest.texture = SpriteBank.texture(&"chest_open")
	chest.scale = Vector2(1.2, 0.85)
	create_tween().tween_property(chest, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play(&"coin")
	_add_trauma(0.2)
	# Monedas que vuelan hacia el contador de oro del HUD.
	var target := _gold_label.get_global_rect().get_center()
	for i in 7:
		var coin := _fx_sprite(&"coin", foot - Vector2(0, 50), 18.0)
		var mid := foot + Vector2(randf_range(-70, 70), randf_range(-130, -90))
		var ctw := create_tween()
		ctw.tween_interval(i * 0.05)
		ctw.tween_property(coin, "position", mid - _fx.global_position, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		ctw.tween_property(coin, "position", target - _fx.global_position, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		ctw.tween_callback(coin.queue_free)
	# El objeto sube con el brillo de su rareza.
	var color: Color = Loot.RARITY_COLORS[item.rarity]
	var glow := TextureRect.new()
	glow.texture = DungeonBackdrop._radial(Color(color.r, color.g, color.b, 0.8))
	glow.size = Vector2(150, 150)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = foot - Vector2(75, 160) - _fx.global_position
	_fx.add_child(glow)
	var icon := _fx_sprite(item.icon_id(), foot - Vector2(0, 60), 52.0)
	create_tween().tween_property(icon, "position:y", icon.position.y - 40.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_float_at(foot - Vector2(0, 150), "%s · %s" % [tr(item.display_name), tr(Loot.RARITY_NAMES[item.rarity])], color.lightened(0.3), true)
	_float_at(foot - Vector2(-90, 60), "+%d" % gold_amount, UiSkin.GOLD)
	await get_tree().create_timer(1.3).timeout
	for n: Control in [chest, glow, icon]:
		var fade := create_tween()
		fade.tween_property(n, "modulate:a", 0.0, 0.25)
		fade.tween_callback(n.queue_free)


func _animate_trap(damage: Dictionary) -> void:
	var party_rect := _party_row.get_global_rect()
	var spikes := _fx_sprite(&"spikes", party_rect.end, 0.0)
	spikes.stretch_mode = TextureRect.STRETCH_TILE
	spikes.size = Vector2(party_rect.size.x, 40)
	# A la altura de los pies (por encima de las barras de vida y los números).
	spikes.position = Vector2(party_rect.position.x, party_rect.end.y - 20) - _fx.global_position
	var tw := create_tween()
	tw.tween_property(spikes, "position:y", spikes.position.y - 34.0, 0.08).set_ease(Tween.EASE_OUT)
	await tw.finished
	Audio.play(&"crit")
	_add_trauma(0.55)
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.1, 0.1, 0.35)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = _lanes.get_global_rect().position - _fx.global_position
	flash.size = _lanes.get_global_rect().size
	_fx.add_child(flash)
	var ftw := create_tween()
	ftw.tween_property(flash, "color:a", 0.0, 0.4)
	ftw.tween_callback(flash.queue_free)
	for u in damage:
		var view: UnitView = unit_views.get(u)
		if view:
			view.set_hp(u.hp)
			view.hurt(Color(1, 0.35, 0.35), true)
			_float_at(view.hit_point(), "%d" % damage[u], UiSkin.DANGER, true)
	_say_random_hero(&"low_hp", 0.35)
	await get_tree().create_timer(1.2).timeout
	var stw := create_tween()
	stw.tween_property(spikes, "modulate:a", 0.0, 0.3)
	stw.tween_callback(spikes.queue_free)


func _animate_shrine(foot: Vector2, light: int) -> void:
	var spirit := _fx_sprite(&"spirit", foot - Vector2(0, 70), 64.0)
	spirit.modulate = Color(0.7, 0.9, 1.4, 0.0)
	var tw := create_tween()
	tw.tween_property(spirit, "modulate:a", 0.9, 0.4)
	tw.parallel().tween_property(spirit, "position:y", spirit.position.y - 16.0, 0.8).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.3).timeout
	_say(spirit, &"spirit", &"shrine", Color("5fd6e8"), true)
	Audio.play(&"levelup")
	var torch_rect := _torch.get_global_rect()
	_float_at(Vector2(torch_rect.get_center().x, torch_rect.end.y + 40), tr("+%d LIGHT") % light, UiSkin.TORCH, true)
	_torch.pivot_offset = _torch.size / 2.0
	var torch_tw := create_tween()
	torch_tw.tween_property(_torch, "scale", Vector2(1.25, 1.25), 0.15)
	torch_tw.tween_property(_torch, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(1.6).timeout
	var stw := create_tween()
	stw.tween_property(spirit, "modulate:a", 0.0, 0.4)
	stw.tween_callback(spirit.queue_free)


## Carta de resultado del evento: deja claro qué pasó antes de seguir.
func _show_event_result(result: Dictionary) -> void:
	_clear_cards()
	match result.event:
		&"chest":
			var item: ItemData = result.item
			var color: Color = Loot.RARITY_COLORS[item.rarity]
			_set_text(tr("Forgotten chest!"), tr("You found an item and %d gold.") % result.gold, UiSkin.GOLD)
			_add_card(SpriteBank.icon(item.icon_id()), tr(item.display_name), _item_stats(item), tr(Loot.RARITY_NAMES[item.rarity]), color, _show_next.bind(""), color.lightened(0.3))
		&"trap":
			_set_text(tr("It's a trap!"), tr("Hidden spikes: the party loses 15% of its health."), UiSkin.DANGER)
			_add_card(SpriteBank.icon(&"skull"), tr("Ouch"), tr("Patch up and keep moving. A rest or a camp will help."), tr("Continue"), UiSkin.DANGER, _show_next.bind(""))
		&"shrine":
			_set_text(tr("A quiet shrine"), tr("A blue flame rekindles your torch: +%d light.") % result.light, Color("5fd6e8"))
			_add_card(SpriteBank.icon(&"torch"), tr("Rekindled"), tr("The spirit of the shrine lends you its flame."), tr("+%d LIGHT") % result.light, UiSkin.TORCH, _show_next.bind(""))
	_focus_first_card()


# --- tutorial -----------------------------------------------------------------

## Consejo del tutorial señalando target, solo la primera vez y si no se saltearon.
func _coach(id: String, target: Control, text: String) -> void:
	if meta == null or not meta.should_tip(id) or not is_instance_valid(target):
		return
	_dismiss_tip()
	meta.mark_tip(id)
	_save_meta()
	_tip = CoachTip.new()
	_tip.dismissed.connect(_on_tip_dismissed)
	_tip.show_for(target, text, _fx)


func _on_tip_dismissed(skip_all: bool) -> void:
	if skip_all:
		meta.tips_off = true
		_save_meta()
	_dismiss_tip()
	_focus_first_card()


func _dismiss_tip() -> void:
	if is_instance_valid(_tip):
		_tip.queue_free()
	_tip = null


# --- diálogos ----------------------------------------------------------------

func _combat_banter(result: Dictionary, boss_fight: bool) -> void:
	if boss_fight:
		var boss_view: UnitView = unit_views.get(result.enemies[0])
		if boss_view:
			_say(boss_view, result.enemies[0].id, &"boss", UiSkin.DANGER, true)
		_say_random_hero(&"boss", 1.0, 1.4)
	elif randf() < 0.55:
		if randf() < 0.35 and not result.enemies.is_empty():
			var view: UnitView = unit_views.get(result.enemies[0])
			if view:
				_say(view, &"any", &"enter", UiSkin.DANGER)
		else:
			_say_random_hero(&"enter", 1.0)


## Un héroe vivo al azar dice algo de ese contexto (con probabilidad chance).
func _say_random_hero(context: StringName, chance: float, delay := 0.0) -> void:
	if randf() > chance or expedition == null:
		return
	var alive: Array = expedition.party.filter(func(u: Unit) -> bool: return u.is_alive())
	if alive.is_empty():
		return
	var u: Unit = alive[randi() % alive.size()]
	var view: UnitView = unit_views.get(u)
	if view == null:
		return
	if delay > 0.0:
		_say_later(view, u.id, context, UiSkin.GOLD, delay)
	else:
		_say(view, u.id, context, UiSkin.GOLD)


func _say_later(anchor: Control, speaker: StringName, context: StringName, accent: Color, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(anchor) and anchor.is_inside_tree():
		_say(anchor, speaker, context, accent, true)


## Globo de diálogo sobre un personaje. force ignora la pausa mínima entre globos.
func _say(anchor: Control, speaker: StringName, context: StringName, accent: Color, force := false) -> void:
	if skipping:
		return
	var now := Time.get_ticks_msec()
	if not force and now - _last_bubble < 1400:
		return
	var text := Dialogue.line(speaker, context)
	if text == "":
		return
	_last_bubble = now
	var rect := anchor.get_global_rect()
	SpeechBubble.new().say(tr(text), Vector2(rect.get_center().x, rect.position.y), accent, _fx)


func _add_npc(id: StringName, row: HBoxContainer) -> Control:
	var npc := TextureRect.new()
	npc.texture = SpriteBank.texture(id)
	npc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	npc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc.custom_minimum_size = Vector2(96, 96)
	npc.size_flags_vertical = Control.SIZE_SHRINK_END
	npc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(npc)
	return npc


## Sprite temporal en la capa de efectos, con los pies en el punto dado (coordenadas globales).
func _fx_sprite(id: StringName, foot: Vector2, side: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = SpriteBank.texture(id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if side > 0.0:
		r.size = Vector2(side, side)
		r.position = foot - Vector2(side / 2.0, side) - _fx.global_position
		r.pivot_offset = Vector2(side / 2.0, side)
	_fx.add_child(r)
	return r


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
	hud.add_theme_constant_override("separation", 10)
	hud_panel.add_child(hud)
	_step_label = _label(hud, "", 17)
	_torch = TorchMeter.new()
	hud.add_child(_torch)
	_gold_label = _stat_chip(hud, &"gold", &"coin", UiSkin.GOLD)
	_stat_chip(hud, &"shards", &"gem", SHARD_COLOR)
	_stat_chip(hud, &"runs", &"torch", UiSkin.TORCH)
	_stat_chip(hud, &"deepest", &"door", UiSkin.HEAL)
	_level_label = _label(hud, "")
	_as_number(_level_label)
	_level_label.add_theme_color_override("font_color", BOON_COLOR.lightened(0.3))
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(70, 10)
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
	_lang_button = Button.new()
	_lang_button.focus_mode = Control.FOCUS_NONE
	_lang_button.pressed.connect(_toggle_language)
	hud.add_child(_lang_button)
	_mute_button = Button.new()
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.pressed.connect(_toggle_mute)
	hud.add_child(_mute_button)
	_volume_slider = HSlider.new()
	_volume_slider.custom_minimum_size = Vector2(64, 0)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.focus_mode = Control.FOCUS_NONE
	_volume_slider.max_value = 100
	_volume_slider.step = 5
	_volume_slider.value = Audio.get_volume() * 100.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	_volume_slider.drag_ended.connect(func(_changed: bool) -> void: _save_settings())
	hud.add_child(_volume_slider)
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
	_lanes.offset_bottom = LANES_BOTTOM
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
	_speed_button.text = "x%d  [S]" % int(SPEEDS[speed_index])
	_speed_button.tooltip_text = tr("Combat speed")
	var silent := Audio.is_muted() or Audio.get_volume() <= 0.0
	_mute_button.text = tr("Muted") if silent else tr("Sound")
	_mute_button.tooltip_text = tr("Mute or unmute  [M]. Volume: - and +")
	_mute_button.add_theme_color_override("font_color", UiSkin.DANGER if silent else UiSkin.TEXT)
	_lang_button.text = "Español" if TranslationServer.get_locale().begins_with("es") else "English"
	_lang_button.tooltip_text = tr("Language")
	var in_run := expedition != null and not expedition.finished
	_lang_button.visible = not in_run
	_speed_button.visible = in_run
	for id in [&"shards", &"runs", &"deepest"]:
		_chips[id].chip.visible = not in_run and meta != null
	_chips[&"gold"].caption.text = tr("Gold")
	_chips[&"shards"].caption.text = tr("Shards")
	_chips[&"runs"].caption.text = tr("Expeditions")
	_chips[&"deepest"].caption.text = tr("Deepest room")
	if meta:
		_chips[&"shards"].value.text = "%d" % meta.shards
		_chips[&"runs"].value.text = "%d" % meta.runs
		_chips[&"deepest"].value.text = "%d/%d" % [meta.best_step, Expedition.STEPS]
	_torch.visible = in_run
	_xp_bar.visible = in_run
	_level_label.visible = in_run
	_loot_label.visible = in_run
	if not in_run:
		_step_label.text = tr("Emberdelve")
		_gold_label.text = "%d" % meta.gold if meta else ""
		return
	_step_label.text = _floor_text()
	_torch.set_value(expedition.torch, expedition.torch_max)
	_backdrop.set_light(float(expedition.torch) / maxf(1.0, expedition.torch_max))
	_gold_label.text = "%d" % expedition.gold
	_level_label.text = tr("Lv %d") % expedition.level
	_xp_bar.max_value = expedition.xp_to_next()
	_xp_bar.value = expedition.xp
	_loot_label.text = tr("Items %d · Blessings %d") % [expedition.items.size(), expedition.boons_taken.size()]


## Piso y sala traducidos (floor_label() devuelve el texto ya armado, en inglés).
func _floor_text() -> String:
	if expedition.step >= Expedition.STEPS - 1:
		return tr("Boss lair")
	var per := Expedition.ROOMS_PER_FLOOR
	return tr("Floor %d · Room %d/%d") % [expedition.step / per + 1, expedition.step % per + 1, per]


func _set_text(title: String, body: String, title_color := UiSkin.GOLD) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	_info.text = body
	_info.visible = body != ""


## Nombre del objeto y quién lo usa, traducidos.
func _item_line(item: ItemData) -> String:
	return "%s (%s)" % [tr(item.display_name), _item_owner(item)]


func _item_owner(item: ItemData) -> String:
	return tr(GameData.hero(item.hero).display_name) if item.hero != &"" else tr("Any hero")


func _item_stats(item: ItemData) -> String:
	var parts: PackedStringArray = []
	if item.attack > 0:
		parts.append(tr("+%d attack") % item.attack)
	if item.defense > 0:
		parts.append(tr("+%d defense") % item.defense)
	if item.max_hp > 0:
		parts.append(tr("+%d health") % item.max_hp)
	return "%s: %s\n%s" % [_item_owner(item), ", ".join(parts), tr("Kept if you make it back.")]


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
	for child in _fx.get_children():
		if child is SpeechBubble:
			child.queue_free()
	trauma = 0.0
	_shake_lanes(Vector2.ZERO)
	if _score_panel != null:
		_score_panel.queue_free()
		_score_panel = null
	for row in [_enemy_row, _party_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()


func _clear_cards() -> void:
	_dismiss_tip()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


func _add_card(icon: Texture2D, title: String, body: String, footer: String, accent: Color, callback: Callable, title_color := UiSkin.TEXT) -> ChoiceCard:
	var card: ChoiceCard = CHOICE_CARD.instantiate()
	_cards.add_child(card)
	card.setup(_cards.get_child_count(), icon, title, body, footer, accent, title_color)
	# Entrada escalonada: cada carta aparece un instante después de la anterior.
	card.modulate.a = 0.0
	card.pivot_offset = card.custom_minimum_size / 2.0
	card.scale = Vector2(0.85, 0.85)
	var tw := card.create_tween()
	tw.tween_interval(0.06 * (_cards.get_child_count() - 1))
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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


## Chip del HUD: icono, número grande en el color del recurso y su nombre debajo.
func _stat_chip(parent: Node, id: StringName, icon_id: StringName, color: Color) -> Label:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.13)
	box.border_color = color.darkened(0.25)
	box.set_border_width_all(2)
	box.content_margin_left = 6
	box.content_margin_right = 8
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", box)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = SpriteBank.icon(icon_id, 3)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	row.add_child(col)
	var value := Label.new()
	value.theme_type_variation = UiSkin.NUMBER_VARIATION
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", color.lightened(0.15))
	col.add_child(value)
	var caption := _label(col, "", 11)
	caption.add_theme_color_override("font_color", color.lerp(UiSkin.MUTED, 0.5))
	_chips[id] = {"chip": chip, "value": value, "caption": caption}
	return value


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


## Guarda el progreso en el navegador y, en CrazyGames, también en su Data Module.
func _save_meta() -> Error:
	var err := meta.save()
	if err == OK:
		Platform.data_set(CLOUD_SAVE_KEY, JSON.stringify(meta.to_dict()))
	return err


## Si CrazyGames tiene una copia más nueva que la local (otro dispositivo, sesión
## iniciada), la escribe en user:// antes de cargar. Sin SDK, data_get devuelve "".
func _pull_cloud_saves() -> void:
	for pair in [[MetaState.SAVE_PATH, CLOUD_SAVE_KEY], [RunStore.PATH, CLOUD_RUN_KEY]]:
		var raw := Platform.data_get(pair[1])
		if raw == "":
			continue
		var cloud = JSON.parse_string(raw)
		if not (cloud is Dictionary) or not cloud.has("version"):
			continue
		var local := SaveIO.load_json(pair[0])
		if local.is_empty() or float(cloud.get("saved_at", 0)) > float(local.get("saved_at", 0)):
			SaveIO.save_json(pair[0], cloud)


func _toggle_mute() -> void:
	if not Audio.is_muted() and Audio.get_volume() <= 0.0:
		# Con el volumen en cero, el botón vuelve a dar sonido en lugar de "silenciar".
		_volume_slider.value = 50
	else:
		Audio.set_muted(not Audio.is_muted())
	_save_settings()
	_update_hud()


func _on_volume_changed(value: float) -> void:
	Audio.set_volume(value / 100.0)
	if value > 0.0 and Audio.is_muted():
		Audio.set_muted(false)
	_update_hud()


func _nudge_volume(delta: float) -> void:
	_volume_slider.value = clampf(_volume_slider.value + delta, 0.0, 100.0)
	_save_settings()


func _save_settings() -> void:
	if meta == null:
		return
	meta.muted = Audio.is_muted()
	meta.volume = Audio.get_volume()
	meta.language = Locale.current()
	_save_meta()


func _toggle_language() -> void:
	Locale.apply("en" if Locale.current() == "es" else "es")
	_save_settings()
	# Las pantallas arman sus textos con tr() al mostrarse: se vuelve a dibujar el campamento.
	_show_camp("")


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
		_save_meta()
		Audio.play(&"coin")
		card.queue_free()
		_set_text(_title.text, tr("+%d gold added. Thanks!") % bonus))


func _on_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	_update_hud()
