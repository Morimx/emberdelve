class_name Combat
extends RefCounted
## Simulación de combate por ticks. Es pura: recibe unidades y un RNG, las modifica y
## devuelve eventos para que la UI los reproduzca. La UI la avanza con step() y deja que
## el jugador lance las habilidades de los héroes; run() la resuelve entera con
## lanzamiento automático (pruebas y simulación de balance).

const TICK := 0.1
const MAX_TIME := 90.0
const SHIELD_DURATION := 3.0
## Segundos que una habilidad lista espera al jugador antes de lanzarse sola.
const AUTO_CAST_DELAY := 4.0
## Golpe cargado: aviso previo, multiplicador y cada cuánto lo preparan élites y jefes.
## Se bloquea con Muro de escudos o se corta con una Puñalada al que lo está cargando.
const WINDUP := 1.6
const HEAVY_MULT := 2.6
const HEAVY_AREA_MULT := 2.0
const ELITE_HEAVY_EVERY := 7.0
const BOSS_HEAVY_EVERY := 6.0
## Curación automática: solo si alguien bajó de esta fracción de vida.
const AUTO_HEAL_BELOW := 0.75

var party: Array[Unit]
var enemies: Array[Unit]
var t := 0.0
var finished := false
var won := false
## Espera antes del lanzamiento automático (0 = apenas está lista).
var auto_delay := 0.0
## Enemigo que el jugador marcó: los héroes lo atacan primero mientras viva.
var focus: Unit

var _rng: RandomNumberGenerator
var _all: Array[Unit] = []
var _attack_timers := {}
var _skill_timers := {}
var _waiting := {}
var _requested := {}
var _backstab := {}
var _speeds := {}
var _shield_until := -1.0
var _shield_power := 0.0
var _atk_pct := 0.0
var _def_bonus := 0
var _lifesteal := 0.0
var _extra_crit := 0.0
var _skill_mult := 1.0
var _heavy_timers := {}
var _windups := {}


func _init(p_party: Array[Unit], p_enemies: Array[Unit], rng: RandomNumberGenerator, mods: Dictionary = {}, p_auto_delay := 0.0) -> void:
	party = p_party
	enemies = p_enemies
	_rng = rng
	auto_delay = p_auto_delay
	_all.append_array(party)
	_all.append_array(enemies)
	_atk_pct = mods.get("attack_pct", 0.0)
	_def_bonus = int(mods.get("defense", 0))
	_lifesteal = mods.get("lifesteal", 0.0)
	_extra_crit = mods.get("crit_chance", 0.0)
	_skill_mult = 1.0 + mods.get("skill_power_pct", 0.0)
	var speed_mult: float = 1.0 + mods.get("speed_pct", 0.0)
	for u in _all:
		_speeds[u] = u.speed * (speed_mult if not u.is_enemy else 1.0)
		_attack_timers[u] = rng.randf_range(0.3, 1.0) / _speeds[u]
		_skill_timers[u] = u.skill_cooldown
		_waiting[u] = 0.0
		if u.heavy_every > 0.0:
			_heavy_timers[u] = u.heavy_every * 0.6
	_check_end()


## Resuelve el combate completo lanzando cada habilidad apenas está lista.
static func run(p_party: Array[Unit], p_enemies: Array[Unit], rng: RandomNumberGenerator, mods: Dictionary = {}) -> Dictionary:
	var combat := Combat.new(p_party, p_enemies, rng, mods)
	var events: Array[Dictionary] = []
	while not combat.finished:
		events.append_array(combat.step())
	return {"won": combat.won, "events": events, "duration": combat.t}


func skill_ready(u: Unit) -> bool:
	return u.skill != &"" and u.is_alive() and not finished and _skill_timers.get(u, 1.0) <= 0.0


## Carga de la habilidad entre 0 y 1 (1 = lista).
func skill_charge(u: Unit) -> float:
	if u.skill == &"" or u.skill_cooldown <= 0.0:
		return 0.0
	return clampf(1.0 - _skill_timers.get(u, 0.0) / u.skill_cooldown, 0.0, 1.0)


## Segundos que le faltan al enemigo para soltar su golpe cargado (-1 si no carga).
func windup_left(u: Unit) -> float:
	return _windups.get(u, -1.0)


## Deja lista ya la habilidad de un héroe (el entrenamiento la pide en el momento justo).
func charge_skill(u: Unit) -> void:
	if _skill_timers.has(u):
		_skill_timers[u] = 0.0
		_waiting[u] = 0.0


## Alarga los golpes que se están cargando (el entrenamiento da tiempo a reaccionar).
func delay_windups(extra: float) -> void:
	for u in _windups:
		_windups[u] += extra


func set_focus(u: Unit) -> void:
	if u != null and u.is_enemy and u.is_alive():
		focus = u


## El jugador pide lanzar la habilidad; se aplica en el próximo tick. false si no está lista.
func request_skill(u: Unit) -> bool:
	if not skill_ready(u) or u.is_enemy:
		return false
	_requested[u] = true
	return true


## Avanza un tick y devuelve los eventos que ocurrieron en él.
func step() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished:
		return events
	t += TICK
	for u in _all:
		if not u.is_alive() or not _any_alive(party) or not _any_alive(enemies):
			continue
		if u.skill != &"":
			_tick_skill(u, events)
		if u.heavy_every > 0.0 and _tick_heavy(u, events):
			continue
		_attack_timers[u] -= TICK
		if _attack_timers[u] > 0.0:
			continue
		_attack_timers[u] += 1.0 / _speeds[u]
		_attack(u, events)
	_check_end()
	return events


func _tick_skill(u: Unit, events: Array[Dictionary]) -> void:
	_skill_timers[u] -= TICK
	if _skill_timers[u] > 0.0:
		return
	var manual: bool = _requested.get(u, false)
	_requested.erase(u)
	if not manual:
		# Los enemigos no esperan; los héroes esperan al jugador un rato.
		_waiting[u] += TICK
		if not u.is_enemy and _waiting[u] < auto_delay - 0.001:
			return
	match u.skill:
		&"shield_wall":
			_shield_until = t + SHIELD_DURATION
			_shield_power = minf(0.8, u.skill_power * _skill_mult)
			events.append({"t": t, "type": "skill", "src": u, "label": "Shield Wall"})
		&"heal":
			# A mano cura a cualquiera herido; sola espera a que alguien esté bastante herido.
			var target := _most_wounded(party, 1.0 if manual else AUTO_HEAL_BELOW)
			if target == null:
				if not manual:
					_skill_timers[u] = 0.5
					_waiting[u] = 0.0
				return
			var amount := int(round(target.max_hp * u.skill_power * _skill_mult))
			target.hp = mini(target.max_hp, target.hp + amount)
			events.append({"t": t, "type": "heal", "src": u, "dst": target, "amount": amount, "hp": target.hp})
		&"backstab":
			_backstab[u] = true
			events.append({"t": t, "type": "skill", "src": u, "label": "Backstab"})
	_skill_timers[u] = u.skill_cooldown
	_waiting[u] = 0.0


## Carga y suelta el golpe pesado. true mientras carga (ese tick no ataca normal).
func _tick_heavy(u: Unit, events: Array[Dictionary]) -> bool:
	if _windups.has(u):
		_windups[u] -= TICK
		if _windups[u] > 0.0:
			return true
		_windups.erase(u)
		_heavy_timers[u] = u.heavy_every
		var targets: Array[Unit] = []
		if u.heavy_area:
			for h in party:
				if h.is_alive():
					targets.append(h)
		else:
			var one := _pick_target(u, party)
			if one != null:
				targets.append(one)
		for foe in targets:
			var mult := HEAVY_AREA_MULT if u.heavy_area else HEAVY_MULT
			var dmg := float(u.attack) * mult * _rng.randf_range(0.9, 1.1) - float(foe.defense + _def_bonus) * 0.5
			var shielded := t < _shield_until
			if shielded:
				dmg *= 1.0 - _shield_power
			var amount := maxi(1, int(round(dmg)))
			foe.hp = maxi(0, foe.hp - amount)
			events.append({"t": t, "type": "hit", "src": u, "dst": foe, "amount": amount, "crit": false, "heavy": true, "blocked": shielded, "hp": foe.hp})
			if not foe.is_alive():
				events.append({"t": t, "type": "death", "dst": foe})
		return true
	_heavy_timers[u] -= TICK
	if _heavy_timers[u] <= 0.0:
		_windups[u] = WINDUP
		events.append({"t": t, "type": "windup", "src": u, "time": WINDUP})
		return true
	return false


func _attack(u: Unit, events: Array[Dictionary]) -> void:
	var foe := _pick_target(u, enemies if not u.is_enemy else party)
	if foe == null:
		return
	var atk := float(u.attack) * (1.0 + (_atk_pct if not u.is_enemy else 0.0))
	var def := float(foe.defense + (_def_bonus if not foe.is_enemy else 0))
	var dmg := atk * _rng.randf_range(0.9, 1.1) - def * 0.5
	var crit := _rng.randf() < u.crit_chance + (_extra_crit if not u.is_enemy else 0.0)
	if crit:
		dmg *= 2.0
	var interrupted := false
	if _backstab.get(u, false):
		dmg *= 3.0 * _skill_mult * u.skill_power
		_backstab[u] = false
		# La puñalada corta el golpe cargado del enemigo.
		if _windups.has(foe):
			_windups.erase(foe)
			_heavy_timers[foe] = foe.heavy_every
			interrupted = true
	if not foe.is_enemy and t < _shield_until:
		dmg *= 1.0 - _shield_power
	var amount := maxi(1, int(round(dmg)))
	foe.hp = maxi(0, foe.hp - amount)
	events.append({"t": t, "type": "hit", "src": u, "dst": foe, "amount": amount, "crit": crit, "hp": foe.hp})
	if interrupted:
		events.append({"t": t, "type": "interrupt", "src": u, "dst": foe})
	if not u.is_enemy and _lifesteal > 0.0 and u.hp < u.max_hp:
		var heal := int(round(amount * _lifesteal))
		if heal > 0:
			u.hp = mini(u.max_hp, u.hp + heal)
			events.append({"t": t, "type": "heal", "src": u, "dst": u, "amount": heal, "hp": u.hp})
	if not foe.is_alive():
		events.append({"t": t, "type": "death", "dst": foe})


func _check_end() -> void:
	if t >= MAX_TIME - 0.0001 or not _any_alive(party) or not _any_alive(enemies):
		finished = true
		won = not _any_alive(enemies) and _any_alive(party)


static func _any_alive(units: Array[Unit]) -> bool:
	for u in units:
		if u.is_alive():
			return true
	return false


func _pick_target(attacker: Unit, foes: Array[Unit]) -> Unit:
	if not attacker.is_enemy:
		# La puñalada busca al que está cargando; si no, todos siguen la marca del jugador.
		if _backstab.get(attacker, false):
			for f in foes:
				if f.is_alive() and _windups.has(f):
					return f
		if focus != null and focus.is_alive():
			return focus
	var best: Unit = null
	for f in foes:
		if not f.is_alive():
			continue
		if best == null:
			best = f
		elif attacker.is_enemy and f.front and not best.front:
			best = f
		elif attacker.skill == &"backstab" and f.hp < best.hp:
			best = f
	return best


static func _most_wounded(units: Array[Unit], below: float) -> Unit:
	var best: Unit = null
	var best_ratio := below
	for u in units:
		if not u.is_alive():
			continue
		var ratio := float(u.hp) / u.max_hp
		if ratio < best_ratio:
			best = u
			best_ratio = ratio
	return best
