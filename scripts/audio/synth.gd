class_name Synth
extends RefCounted
## Sintetizador chiptune mínimo: genera AudioStreamWAV en memoria (sin archivos ni licencias).

const RATE := 22050


## Un sonido: forma de onda que barre de f0 a f1 Hz, con mezcla de ruido y caída exponencial.
## notes: si no está vacío, en lugar de barrer toca esas frecuencias en secuencia (arpegio).
static func sfx(wave: String, f0: float, f1: float, duration: float, volume := 0.4, noise := 0.0, notes: PackedFloat32Array = PackedFloat32Array()) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 1000 + duration * 77)
	var held := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(f0, f1, t)
		if not notes.is_empty():
			freq = notes[mini(int(t * notes.size()), notes.size() - 1)]
		phase = fmod(phase + freq / RATE, 1.0)
		var v := _wave(wave, phase)
		if noise > 0.0:
			if i % 3 == 0:
				held = rng.randf_range(-1.0, 1.0)
			v = lerpf(v, held, noise)
		var env := minf(1.0, i / (RATE * 0.004)) * pow(1.0 - t, 1.6)
		data.encode_s16(i * 2, int(clampf(v * env * volume, -1.0, 1.0) * 32767))
	return _stream(data, RATE, false)


## Música en bucle: bajo en triángulo, arpegio en cuadrada y un pulso de percusión.
## chords: lista de acordes (cada uno, frecuencias en Hz); un compás por acorde.
static func music(chords: Array, bpm: float, rate := 16000, lead_volume := 0.09, bass_volume := 0.22) -> AudioStreamWAV:
	var step_len := 60.0 / bpm / 4.0  # semicorchea
	var steps_per_bar := 16
	var total_steps: int = chords.size() * steps_per_bar
	var n := int(total_steps * step_len * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var bass_phase := 0.0
	var lead_phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var noise_held := 0.0
	var samples_per_step := step_len * rate
	for i in n:
		var step := int(i / samples_per_step)
		var in_step := fmod(i, samples_per_step) / samples_per_step
		var chord: Array = chords[step / steps_per_bar]
		var beat := step % steps_per_bar
		# bajo: raíz una octava abajo, en corcheas
		var bass_f: float = chord[0] / 2.0
		bass_phase = fmod(bass_phase + bass_f / rate, 1.0)
		var bass_env := pow(1.0 - fmod(i, samples_per_step * 2.0) / (samples_per_step * 2.0), 0.6)
		var v: float = _wave("tri", bass_phase) * bass_volume * bass_env
		# arpegio: recorre el acorde, una nota por semicorchea, con una octava arriba cada tanto
		var lead_f: float = chord[beat % chord.size()] * (2.0 if beat % 8 >= 6 else 1.0)
		lead_phase = fmod(lead_phase + lead_f / rate, 1.0)
		v += _wave("pulse", lead_phase) * lead_volume * pow(1.0 - in_step, 2.0)
		# percusión: ruido corto en los tiempos 1 y 3, más suave en el 2 y 4
		if beat % 4 == 0:
			if i % 2 == 0:
				noise_held = rng.randf_range(-1.0, 1.0)
			var hat := 0.08 if beat % 8 == 0 else 0.04
			v += noise_held * hat * pow(maxf(0.0, 1.0 - in_step * 3.0), 3.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767))
	return _stream(data, rate, true)


static func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"pulse":
			return 1.0 if phase < 0.25 else -1.0
		"tri":
			return 4.0 * absf(phase - 0.5) - 1.0
		"saw":
			return 2.0 * phase - 1.0
	return sin(phase * TAU)


static func _stream(data: PackedByteArray, rate: int, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = data.size() / 2
	return s
