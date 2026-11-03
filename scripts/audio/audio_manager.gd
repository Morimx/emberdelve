extends Node
## Autoload "Audio": efectos sintetizados, música en bucle, buses y silencio.
## El silencio del jugador (muted) y el de los anuncios (ad_mute) se combinan: basta uno.

const POOL := 8
## Notas (Hz)
const A2 := 110.0
const C3 := 130.81
const D3 := 146.83
const E3 := 164.81
const F3 := 174.61
const G3 := 196.0
const A3 := 220.0
const B3 := 246.94
const C4 := 261.63
const D4 := 293.66
const E4 := 329.63
const G4 := 392.0
const A4 := 440.0

var _sfx := {}
var _music := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player := AudioStreamPlayer.new()
var _current_music: StringName = &""
var _muted := false
var _ad_mute := false
var _volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -6.0)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_player.bus = "Music"
	add_child(_music_player)
	_build_sfx()


func play(id: StringName, pitch_jitter := 0.06) -> void:
	var stream: AudioStream = _sfx.get(id)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(id: StringName) -> void:
	if id == _current_music:
		return
	_current_music = id
	if not _music.has(id):
		_music[id] = _build_music(id)
	_music_player.stream = _music[id]
	_music_player.play()


func is_muted() -> bool:
	return _muted


func set_muted(value: bool) -> void:
	_muted = value
	_apply_mute()


## Silencio temporal mientras se muestra un anuncio (pedido por CrazyGames).
func set_ad_mute(value: bool) -> void:
	_ad_mute = value
	_apply_mute()


## Volumen general en escala lineal (0 a 1); 0 equivale a silencio.
func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.001)))
	_apply_mute()


func get_volume() -> float:
	return _volume


func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, _muted or _ad_mute or _volume <= 0.0)


func _build_sfx() -> void:
	_sfx[&"click"] = Synth.sfx("square", 660, 620, 0.05, 0.18)
	_sfx[&"hit"] = Synth.sfx("square", 180, 70, 0.09, 0.28, 0.55)
	_sfx[&"crit"] = Synth.sfx("square", 520, 120, 0.16, 0.34, 0.45)
	_sfx[&"heal"] = Synth.sfx("tri", 0, 0, 0.22, 0.32, 0.0, PackedFloat32Array([C4 * 2, E4 * 2, G4 * 2]))
	_sfx[&"death"] = Synth.sfx("square", 220, 40, 0.35, 0.3, 0.6)
	_sfx[&"skill"] = Synth.sfx("pulse", 300, 900, 0.14, 0.22)
	_sfx[&"coin"] = Synth.sfx("square", 0, 0, 0.14, 0.22, 0.0, PackedFloat32Array([988.0, 1319.0]))
	_sfx[&"door"] = Synth.sfx("tri", 120, 60, 0.18, 0.45, 0.25)
	_sfx[&"levelup"] = Synth.sfx("pulse", 0, 0, 0.45, 0.26, 0.0, PackedFloat32Array([C4 * 2, E4 * 2, G4 * 2, C4 * 4]))
	_sfx[&"victory"] = Synth.sfx("square", 0, 0, 0.7, 0.24, 0.0, PackedFloat32Array([G4, C4 * 2, E4 * 2, G4 * 2, G4 * 2]))
	_sfx[&"defeat"] = Synth.sfx("tri", 0, 0, 0.9, 0.36, 0.0, PackedFloat32Array([A3, F3, D3, A2]))
	_sfx[&"torch_low"] = Synth.sfx("sine", 300, 140, 0.4, 0.25, 0.7)


func _build_music(id: StringName) -> AudioStreamWAV:
	match id:
		&"camp":
			# Do mayor tranquilo: C - Am - F - G
			return Synth.music([[C4, E4, G4], [A3, C4, E4], [F3, A3, C4], [G3, B3, D4]], 84.0)
	# Mazmorra en La menor: Am - F - C - E
	return Synth.music([[A3, C4, E4], [F3, A3, C4], [C4, E4, G4], [E3, G3 * 1.0595, B3]], 104.0)
