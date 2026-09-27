## Selbst erzeugte Klänge – vollständig synthetisiert, ohne Audiodateien.
##
## Jeder Klang wird beim ersten Abruf aus Rauschen, Sinustönen, Filtern und
## Hüllkurven berechnet und danach zwischengespeichert. Alle Klänge sind
## bewusst leise und weich gehalten (gemütlich statt laut).
##
## Verfügbar: rolling (Schleife), clack, brake, door_open, door_close, chime, horn,
## step_snow_0..2 und step_stone_0..2 (Schritte)
class_name SoundLibrary
extends RefCounted

const MIX_RATE := 22050

static var _cache := {}


static func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream: AudioStreamWAV
	if sound_name.begins_with("step_"):
		# step_snow_0 … step_snow_2, step_stone_0 … step_stone_2
		var parts := sound_name.split("_")
		stream = _step(parts[1] == "snow", int(parts[2]) if parts.size() > 2 else 0)
		_cache[sound_name] = stream
		return stream
	match sound_name:
		"rolling":
			stream = _rolling()
		"clack":
			stream = _clack()
		"brake":
			stream = _brake()
		"door_open":
			stream = _door(false)
		"door_close":
			stream = _door(true)
		"chime":
			stream = _chime()
		"horn":
			stream = _horn()
		_:
			push_warning("SoundLibrary: Unbekannter Klang '%s'." % sound_name)
			stream = _to_wav(PackedFloat32Array([0.0]))
	_cache[sound_name] = stream
	return stream


## Zwischenspeicher leeren (beim Beenden).
static func clear_cache() -> void:
	_cache.clear()


## Lautester Ausschlag eines Klangs (für Tests).
static func peak(stream: AudioStreamWAV) -> float:
	var data := stream.data
	var loudest := 0
	for i in range(0, data.size(), 2):
		loudest = maxi(loudest, absi(data.decode_s16(i)))
	return loudest / 32767.0


# --- Klänge --------------------------------------------------------------------

## Leises Rollen: tiefes, gefiltertes Rauschen mit sanftem Pulsieren. Nahtlose Schleife.
static func _rolling() -> AudioStreamWAV:
	var rng := _rng(11)
	var length := int(MIX_RATE * 2.0)
	var fade := int(MIX_RATE * 0.25)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var low := 0.0
	var mid := 0.0
	var mid_low := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.012 * (white - low)
		mid += 0.09 * (white - mid)
		mid_low += 0.03 * (white - mid_low)
		var pulse := 0.85 + 0.15 * sin(TAU * 1.5 * t)
		raw[i] = (low * 9.0 + (mid - mid_low) * 1.4) * pulse
	# Ende weich in den Anfang überblenden → keine Knackser an der Schleifenstelle
	var samples := PackedFloat32Array()
	samples.resize(length)
	for i in length:
		samples[i] = raw[i]
		if i < fade:
			var w := float(i) / fade
			samples[i] = raw[i] * w + raw[length + i] * (1.0 - w)
	_normalize(samples, 0.55)
	return _to_wav(samples, true)


## Schienenstoß: "klack-klack" – dumpfer Schlag mit kurzem metallischem Klick.
static func _clack() -> AudioStreamWAV:
	var rng := _rng(23)
	var samples := _silence(0.36)
	for hit_time: float in [0.0, 0.115]:
		var start := int(hit_time * MIX_RATE)
		var high := 0.0
		for i in range(start, samples.size()):
			var t := float(i - start) / MIX_RATE
			var white := rng.randf_range(-1.0, 1.0)
			high += 0.35 * (white - high)
			var thump := sin(TAU * 58.0 * t) * exp(-t * 32.0)
			var click := (white - high) * exp(-t * 95.0) * 0.55
			var ring := sin(TAU * 1480.0 * t) * exp(-t * 55.0) * 0.08
			samples[i] += thump * 0.8 + click + ring
	_normalize(samples, 0.6)
	return _to_wav(samples)


## Bremsen: rauschendes Schleifen mit leisem, schwebendem Quietschen.
static func _brake() -> AudioStreamWAV:
	var rng := _rng(37)
	var duration := 2.4
	var samples := _silence(duration)
	var low := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var envelope := smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(duration - 0.7, duration, t))
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.25 * (white - low)
		var hiss := (white - low) * 0.35
		phase += TAU * (2650.0 + 35.0 * sin(TAU * 4.5 * t)) / MIX_RATE
		var squeal := sin(phase) * 0.13 * smoothstep(0.6, 1.4, t)
		samples[i] = (hiss + squeal) * envelope
	_normalize(samples, 0.35)
	return _to_wav(samples)


## Tür: Druckluftzischen, Surren des Antriebs, weicher Anschlag.
## Beim Schließen vorher zwei sanfte Warntöne.
static func _door(closing: bool) -> AudioStreamWAV:
	var rng := _rng(41 if closing else 43)
	var offset := 0.55 if closing else 0.0
	var duration := 1.3 + offset
	var samples := _silence(duration)
	if closing:
		for beep_start: float in [0.0, 0.26]:
			for i in range(int(beep_start * MIX_RATE), int((beep_start + 0.14) * MIX_RATE)):
				var t := float(i) / MIX_RATE - beep_start
				samples[i] += sin(TAU * 1870.0 * t) * sin(PI * t / 0.14) * 0.22
	var low := 0.0
	for i in range(int(offset * MIX_RATE), samples.size()):
		var t := float(i) / MIX_RATE - offset
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.2 * (white - low)
		var hiss := (white - low) * exp(-t * 4.5) * 0.4
		var motor := (sin(TAU * 170.0 * t) + 0.4 * sin(TAU * 340.0 * t)) * 0.07 \
			* smoothstep(0.1, 0.25, t) * (1.0 - smoothstep(0.85, 1.0, t))
		var clunk_t := t - 1.02
		var clunk := sin(TAU * 85.0 * clunk_t) * exp(-clunk_t * 28.0) * 0.5 if clunk_t > 0.0 else 0.0
		samples[i] += hiss + motor + clunk
	_normalize(samples, 0.45)
	return _to_wav(samples)


## Bahnhofsgong (Signalton): zwei weiche Glockentöne.
static func _chime() -> AudioStreamWAV:
	var duration := 2.6
	var samples := _silence(duration)
	for note: Array in [[0.0, 659.25], [0.55, 523.25]]:
		var start := int(float(note[0]) * MIX_RATE)
		var frequency: float = note[1]
		for i in range(start, samples.size()):
			var t := float(i - start) / MIX_RATE
			var attack := smoothstep(0.0, 0.012, t)
			var tone := sin(TAU * frequency * t) * exp(-t * 2.0) \
				+ 0.35 * sin(TAU * frequency * 2.0 * t) * exp(-t * 3.5) \
				+ 0.18 * sin(TAU * frequency * 2.76 * t) * exp(-t * 5.0) \
				+ 0.06 * sin(TAU * frequency * 5.4 * t) * exp(-t * 9.0)
			samples[i] += tone * attack
	_normalize(samples, 0.42)
	return _to_wav(samples)


## Schritt: im Schnee ein weiches Knirschen aus vielen kleinen Körnern,
## auf Stein ein kurzes, dumpfes Klopfen. [param variant] 0–2 klingt jeweils etwas anders.
static func _step(snow: bool, variant: int) -> AudioStreamWAV:
	var rng := _rng(71 + variant * 13 + (0 if snow else 5))
	var duration := 0.24 if snow else 0.15
	var samples := _silence(duration)
	var low := 0.0
	var band := 0.0
	var grain := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.06 * (white - low)
		band += 0.4 * (white - band)
		if snow:
			# Knirschen: zufällige Körner, die in den ersten ~120 ms dicht fallen
			if rng.randf() < 0.012 * exp(-t * 14.0) * (1.0 + variant * 0.2):
				grain = rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			grain *= 0.93
			var envelope := smoothstep(0.0, 0.012, t) * exp(-t * 16.0)
			var body := (band - low) * 0.5 + grain * 0.8
			var thump := sin(TAU * (70.0 + variant * 6.0) * t) * exp(-t * 38.0) * 0.35
			samples[i] = body * envelope + thump
		else:
			var envelope := smoothstep(0.0, 0.004, t) * exp(-t * 45.0)
			var knock := sin(TAU * (135.0 + variant * 12.0) * t) * exp(-t * 55.0) * 0.8
			samples[i] = (white - band) * envelope * 0.35 + knock
	_normalize(samples, 0.32 if snow else 0.28)
	return _to_wav(samples)


## Sanftes Zweiklang-Horn (große Terz) mit weichem Ein- und Ausschwingen.
static func _horn() -> AudioStreamWAV:
	var duration := 1.25
	var samples := _silence(duration)
	var smooth := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var envelope := smoothstep(0.0, 0.09, t) * (1.0 - smoothstep(duration - 0.38, duration, t))
		var vibrato := 1.0 + 0.004 * sin(TAU * 5.0 * t)
		var value := 0.0
		for frequency: float in [440.0, 554.37]:
			var f: float = frequency * vibrato
			value += sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) + 0.22 * sin(TAU * f * 3.0 * t)
		smooth += 0.35 * (value - smooth)
		samples[i] = smooth * envelope
	_normalize(samples, 0.5)
	return _to_wav(samples)


# --- Hilfen --------------------------------------------------------------------

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	return samples


static func _normalize(samples: PackedFloat32Array, target_peak: float) -> void:
	var loudest := 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	if loudest <= 0.0:
		return
	var gain := target_peak / loudest
	for i in samples.size():
		samples[i] *= gain


static func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
