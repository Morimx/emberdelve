class_name TutorialRun
extends RefCounted
## Sala de entrenamiento: nivel guiado y corto que enseña a jugar. Cada paso deja una sola
## opción habilitada y espera a que el jugador la use; el combate se congela hasta que
## lance la habilidad que se le pide. No toca la expedición ni el autoguardado: al terminar
## (o al saltarlo) avisa con finished y main sigue.

signal finished(completed: bool)
signal _advanced

const DUMMY := preload("res://data/enemies/dummy.tres")
const ACCENT := Color("5fbf4a")

var main: Control
var party: Array[Unit] = []
var _skipped := false
var _fight: Combat


func _init(p_main: Control) -> void:
	main = p_main


func play() -> void:
	main._backdrop.set_biome(&"training", Color.WHITE, Color("2a2230"))
	main._backdrop.set_campfire(false)
	main._backdrop.set_scene(&"corridor")
	main._backdrop.set_light(1.0)
	Audio.play_music(&"dungeon")
	for h in GameData.heroes():
		party.append(Unit.from_hero(h, {}))
	main._update_hud()

	# 1. Puertas.
	_show_party()
	_step(tr("Training Hall"), tr("Welcome, delver! This short training shows you how to play. Every room is a door: pick one to enter."))
	var door := _card(SpriteBank.icon(&"weapon"), tr("Training room"), tr("Training dummies. They hit softly."), tr("Enter"), _go)
	_card(SpriteBank.icon(&"skull"), tr("Elite"), tr("Not during training."), tr("Locked"), Callable(), false)
	_card(SpriteBank.icon(&"fire"), tr("Skip training"), tr("Go straight to the Catacombs."), "", _skip)
	main._focus_first_card()
	_point(door, tr("Click the door, or press 1."))
	if not await _wait():
		return

	# 2. Combate guiado.
	await main._fade_stage(main._backdrop.set_scene.bind(&"elite"))
	await _guided_fight()
	if _skipped:
		return

	# 3. Recompensa.
	_show_party()
	_step(tr("Room cleared"), tr("After each fight you pick one reward. Items you carry out of the dungeon become permanent gear."))
	var sword := Loot.make_item(&"sword", 1, 2)
	var take := _card(SpriteBank.icon(sword.icon_id()), tr(sword.display_name), main._item_stats(sword), tr(Loot.RARITY_NAMES[sword.rarity]), _go, true, Loot.RARITY_COLORS[1])
	_card(SpriteBank.icon(&"torch"), tr("Supplies"), tr("Not during training."), tr("Locked"), Callable(), false)
	_card(Props.scaled("flask_big_red", 2), tr("Rest"), tr("Not during training."), tr("Locked"), Callable(), false)
	main._focus_first_card()
	_point(take, tr("Take the sword."))
	if not await _wait():
		return
	Audio.play(&"coin")

	# 4. Antorcha y campamento.
	_step(tr("Your torch"), tr("Every door burns torch light. If it goes out, the party gets lost and keeps only half the loot. Camps rekindle it."))
	_card(SpriteBank.icon(&"weapon"), tr("Combat"), tr("Not now: your light is low."), tr("-1 light"), Callable(), false)
	var camp := _card(SpriteBank.icon(&"fire"), tr("Camp"), tr("Rest and rekindle the torch."), tr("+light"), _go, true, UiSkin.TORCH)
	main._focus_first_card()
	_point(camp, tr("Low on light? Pick the camp."))
	if not await _wait():
		return
	Audio.play(&"door")
	await main._fade_stage(func() -> void:
		main._backdrop.set_scene(&"camp")
		main._backdrop.set_campfire(true))
	for u in party:
		u.hp = u.max_hp
	_show_party()

	# 5. Retirada.
	_step(tr("Camp"), tr("You can retreat at any moment and keep 100% of your loot. Falling in battle keeps only half. Finish the training by retreating."))
	_card(SpriteBank.icon(&"lich", 2), tr("Boss"), tr("Too dangerous for now."), tr("Locked"), Callable(), false)
	var retreat := _card(SpriteBank.icon(&"torch"), tr("Retreat"), tr("Leave with everything you found."), tr("Keep 100%"), _go, true, UiSkin.TORCH)
	main._focus_first_card()
	_point(retreat, tr("Retreat to finish the training."))
	if not await _wait():
		return
	main._backdrop.set_campfire(false)
	main._clear_cards()
	finished.emit(true)


## Pelea contra dos muñecos con pausas: marcar objetivo, bloquear, curar e interrumpir.
func _guided_fight() -> void:
	main._clear_cards()
	main._clear_arena()
	var dummies: Array[Unit] = []
	for i in 2:
		var d := Unit.from_enemy(DUMMY, 1.0)
		d.heavy_every = 3.5 if i == 0 else 6.0
		dummies.append(d)
	for u in dummies:
		main._add_unit_view(u, main._enemy_row, u.hp)
	for u in party:
		main._add_unit_view(u, main._party_row, u.hp)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Sin lanzamiento automático: en el entrenamiento cada habilidad la lanza el jugador.
	_fight = Combat.new(party, dummies, rng, {}, 1.0e9)
	var buttons: Array[SkillButton] = []
	for u in party:
		var hero := GameData.hero(u.id)
		var b := SkillButton.new()
		b.setup(buttons.size() + 1, u, tr(hero.skill_name))
		b.pressed.connect(func() -> void:
			if _fight.request_skill(u):
				_advanced.emit())
		main._cards.add_child(b)
		buttons.append(b)
	for u in dummies:
		var view: UnitView = main.unit_views.get(u)
		view.clicked.connect(func(target: Unit) -> void:
			if _fight.focus == null:
				main._on_focus_enemy(target, _fight)
				_advanced.emit())
	_refresh(buttons, null)
	await main.get_tree().process_frame

	# a) Marcar un objetivo.
	_step(tr("Combat"), tr("Your heroes attack on their own. Click a training dummy to focus all attacks on it."))
	_point(main.unit_views[dummies[0]], tr("Click a dummy."))
	await _advanced
	main._dismiss_tip()
	_step(tr("Combat"), tr("Watch the dummies: some enemies charge a heavy blow before they strike."))

	# b) Bloquear el primer golpe cargado con Muro de escudos.
	await _run_until(buttons, func(e: Dictionary) -> bool: return e.type == "windup")
	await _ask(buttons, 0, tr("A heavy blow is coming! Press 1 (Shield Wall) to block it."))
	# c) Curar cuando alguien queda herido.
	await _run_until(buttons, func(e: Dictionary) -> bool: return e.type == "hit" and e.get("heavy", false))
	await _run_until(buttons, func(_e: Dictionary) -> bool: return party.any(func(h: Unit) -> bool: return h.hp < h.max_hp))
	await _ask(buttons, 1, tr("A hero is hurt. Press 2 (Healing Light) to heal."))
	# d) Interrumpir el siguiente golpe cargado con Puñalada.
	await _run_until(buttons, func(e: Dictionary) -> bool: return e.type == "windup")
	await _ask(buttons, 2, tr("Another heavy blow! Press 3 (Backstab) to interrupt it."))
	await _run_until(buttons, func(e: Dictionary) -> bool: return e.type == "interrupt")
	_step(tr("Combat"), tr("Well done! Finish them off."))
	# Los muñecos ya enseñaron todo: caen rápido.
	for d in dummies:
		d.hp = mini(d.hp, 40)
		d.heavy_every = 0.0
	await _run_until(buttons, func(_e: Dictionary) -> bool: return _fight.finished)
	main._float_at(main._party_row.get_global_rect().get_center() - Vector2(0, 70), tr("Victory"), UiSkin.GOLD, true)
	await main.get_tree().create_timer(0.8).timeout
	main._clear_cards()  # saca los botones de habilidad antes de las recompensas
	_fight = null


## Avanza la pelea en tiempo real hasta que un evento cumpla la condición (o termine).
func _run_until(buttons: Array[SkillButton], done: Callable) -> void:
	var budget := 0.0
	while not _fight.finished:
		await main.get_tree().process_frame
		budget = minf(budget + main.get_process_delta_time(), 0.5)
		var hit := false
		while budget >= Combat.TICK and not _fight.finished:
			budget -= Combat.TICK
			for e: Dictionary in _fight.step():
				main._apply_event(e, false)
				if done.call(e):
					hit = true
			if hit:
				break
		_refresh(buttons, null)
		if hit:
			return


## Congela la pelea, deja lista solo esa habilidad y espera a que el jugador la lance.
func _ask(buttons: Array[SkillButton], index: int, text: String) -> void:
	var button := buttons[index]
	_fight.charge_skill(button.unit)
	_step(tr("Combat"), text)
	_refresh(buttons, button)
	_point(button, text)
	await _advanced  # solo lo emite un lanzamiento válido del botón pedido
	main._dismiss_tip()
	# Margen para que la Puñalada alcance al muñeco antes de que suelte el golpe.
	_fight.delay_windups(2.0)
	# Que la habilidad se aplique ya, antes de seguir.
	for e: Dictionary in _fight.step():
		main._apply_event(e, false)
	_refresh(buttons, null)


func _refresh(buttons: Array[SkillButton], only: SkillButton) -> void:
	for b in buttons:
		var allowed := only == null or b == only
		b.refresh(_fight.skill_charge(b.unit), allowed and _fight.skill_ready(b.unit), b.unit.is_alive())


func _show_party() -> void:
	main._clear_arena()
	for u in party:
		main._add_unit_view(u, main._party_row, u.hp)


func _step(title: String, body: String) -> void:
	main._set_text(title, body, ACCENT)


func _card(icon: Texture2D, title: String, body: String, footer: String, callback: Callable, enabled := true, accent: Color = ACCENT) -> ChoiceCard:
	var card: ChoiceCard = main._add_card(icon, title, body, footer, accent, callback if callback.is_valid() else func() -> void: pass)
	card.disabled = not enabled
	return card


func _point(target: Control, text: String) -> void:
	main._point(target, text)


func _go() -> void:
	main._dismiss_tip()
	main._clear_cards()
	_advanced.emit()


func _skip() -> void:
	_skipped = true
	main._dismiss_tip()
	main._clear_cards()
	_advanced.emit()
	finished.emit(false)


## Espera el paso; false si el jugador salteó el entrenamiento.
func _wait() -> bool:
	await _advanced
	return not _skipped
