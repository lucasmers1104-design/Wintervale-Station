## Selbst erzeugte Klänge – vollständig synthetisiert, ohne Audiodateien.
##
## Jeder Klang wird beim ersten Abruf aus Rauschen, Sinustönen, Filtern und
## Hüllkurven berechnet und danach zwischengespeichert. Alle Klänge sind
## bewusst leise und weich gehalten (gemütlich statt laut).
##
## Verfügbar: rolling (Schleife), clack, brake, brake_squeal, door_open, door_close,
## door_unlock, stairs_out, stairs_in (Trittstufe), chime, horn, step_snow_0..2 und
## step_stone_0..2, step_wood_0..2 (Schritte), creak (Holzknarren), wind, station_murmur und
## lamp_hum (Schleifen), bird_0..3 (Vogelrufe)
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
		var variant := int(parts[2]) if parts.size() > 2 else 0
		stream = _wood_step(variant) if parts[1] == "wood" else _step(parts[1] == "snow", variant)
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
		"door_unlock":
			stream = _door_unlock()
		"stairs_out":
			stream = _stairs(true)
		"stairs_in":
			stream = _stairs(false)
		"brake_squeal":
			stream = _brake_squeal()
		"creak":
			stream = _creak()
		"lamp_hum":
			stream = _lamp_hum()
		"wind":
			stream = _wind()
		"station_murmur":
			stream = _murmur()
		"bird_0", "bird_1", "bird_2", "bird_3":
			stream = _bird(int(sound_name.right(1)))
		"crane_motor":
			stream = _crane_motor()
		"clank":
			stream = _clank()
		"gravel":
			stream = _gravel()
		"hammer":
			stream = _hammer()
		"saw":
			stream = _saw()
		"page":
			stream = _page()
		"done_chime":
			stream = _done_chime()
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
		# Drehgestelle: ein weiches, tiefes Wummern im Takt der Räder, dazu leises Schienensingen
		var bogie := sin(TAU * 38.0 * t) * (0.5 + 0.5 * sin(TAU * 2.0 * t)) * 0.25
		var hum := sin(TAU * 310.0 * t + sin(TAU * 0.5 * t) * 2.0) * 0.035
		raw[i] = (low * 9.0 + (mid - mid_low) * 1.4) * pulse + bogie + hum
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


## Tür (gedämpft): weiches Druckluftzischen, tiefes Surren des Antriebs, sanfter Anschlag.
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
				samples[i] += sin(TAU * 1480.0 * t) * sin(PI * t / 0.14) * 0.16
	var low := 0.0
	var soft := 0.0
	for i in range(int(offset * MIX_RATE), samples.size()):
		var t := float(i) / MIX_RATE - offset
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.2 * (white - low)
		soft += 0.3 * ((white - low) - soft)  # gedämpft: die hellen Anteile fehlen
		var hiss := soft * exp(-t * 5.0) * 0.32
		var motor := (sin(TAU * 145.0 * t) + 0.4 * sin(TAU * 290.0 * t)) * 0.06 \
			* smoothstep(0.1, 0.25, t) * (1.0 - smoothstep(0.85, 1.0, t))
		var clunk_t := t - 1.02
		var clunk := sin(TAU * 85.0 * clunk_t) * exp(-clunk_t * 28.0) * 0.5 if clunk_t > 0.0 else 0.0
		samples[i] += hiss + motor + clunk
	_normalize(samples, 0.36)
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


## Türen entriegeln: kurzes, gedämpftes Druckluft-"Pfft" und ein leises Klicken.
static func _door_unlock() -> AudioStreamWAV:
	var rng := _rng(53)
	var samples := _silence(0.5)
	var low := 0.0
	var soft := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.3 * (white - low)
		soft += 0.5 * ((white - low) - soft)
		var hiss := soft * smoothstep(0.0, 0.015, t) * exp(-t * 11.0) * 0.5
		var click_t := t - 0.06
		var click := sin(TAU * 1650.0 * click_t) * exp(-click_t * 90.0) * 0.35 if click_t > 0.0 else 0.0
		var thunk_t := t - 0.09
		var thunk := sin(TAU * 110.0 * thunk_t) * exp(-thunk_t * 30.0) * 0.6 if thunk_t > 0.0 else 0.0
		samples[i] = hiss + click + thunk
	_normalize(samples, 0.3)
	return _to_wav(samples)


## Trittstufe: leises Surren des Antriebs, ein Klacken beim Aus-/Einklappen und ein
## weicher Anschlag. [param extending] = ausfahren (Tonhöhe steigt) oder einfahren.
static func _stairs(extending: bool) -> AudioStreamWAV:
	var rng := _rng(61 if extending else 67)
	var duration := 1.25
	var samples := _silence(duration)
	var phase := 0.0
	var low := 0.0
	var fold_time := 0.68 if extending else 0.08
	var end_time := 1.15 if extending else 1.1
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var motor_start := 0.02 if extending else 0.16
		var motor_end := 0.7 if extending else 0.95
		var sweep := clampf((t - motor_start) / (motor_end - motor_start), 0.0, 1.0)
		var frequency := lerpf(92.0, 118.0, sweep) if extending else lerpf(118.0, 92.0, sweep)
		phase += TAU * frequency / MIX_RATE
		var motor_env := smoothstep(motor_start, motor_start + 0.08, t) * (1.0 - smoothstep(motor_end - 0.08, motor_end, t))
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.08 * (white - low)
		var motor := (sin(phase) + 0.35 * sin(phase * 2.0) + 0.15 * sin(phase * 3.0) + low * 0.6) * 0.18 * motor_env
		var fold_t := t - fold_time
		var fold := sin(TAU * 420.0 * fold_t) * exp(-fold_t * 60.0) * 0.35 if fold_t > 0.0 else 0.0
		var end_t := t - end_time
		var stop := sin(TAU * 95.0 * end_t) * exp(-end_t * 26.0) * 0.55 if end_t > 0.0 else 0.0
		samples[i] = motor + fold + stop
	_normalize(samples, 0.26)
	return _to_wav(samples)


## Ganz leises, kurzes Quietschen im letzten Moment vor dem Stillstand.
static func _brake_squeal() -> AudioStreamWAV:
	var duration := 0.9
	var samples := _silence(duration)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		phase += TAU * (2380.0 + 28.0 * sin(TAU * 5.5 * t) - 90.0 * t) / MIX_RATE
		var envelope := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.45, duration, t))
		samples[i] = (sin(phase) * 0.7 + sin(phase * 1.5) * 0.12) * envelope
	_normalize(samples, 0.16)
	return _to_wav(samples)


## Wind: tiefes, weiches Rauschen mit langsamen Böen. Nahtlose Schleife (8 s).
static func _wind() -> AudioStreamWAV:
	var rng := _rng(79)
	var length := int(MIX_RATE * 8.0)
	var fade := int(MIX_RATE * 1.0)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var low := 0.0
	var lower := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.02 * (white - low)
		lower += 0.004 * (white - lower)
		var gust := 0.55 + 0.25 * sin(TAU * 0.125 * t) + 0.2 * sin(TAU * 0.31 * t + 1.3)
		raw[i] = (low * 6.0 + lower * 10.0) * gust
	var samples := _crossfade_loop(raw, length, fade)
	_normalize(samples, 0.5)
	return _to_wav(samples, true)


## Bahnsteig-Atmosphäre: fernes, unverständliches Stimmengemurmel. Nahtlose Schleife (6 s).
static func _murmur() -> AudioStreamWAV:
	var rng := _rng(83)
	var length := int(MIX_RATE * 6.0)
	var fade := int(MIX_RATE * 0.8)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var voices := []
	for v in 4:
		voices.append({"low": 0.0, "mid": 0.0, "env": 0.0, "target": 0.0, "timer": 0.0})
	for i in raw.size():
		var white := rng.randf_range(-1.0, 1.0)
		var value := 0.0
		for voice: Dictionary in voices:
			voice["timer"] = float(voice["timer"]) - 1.0 / MIX_RATE
			if float(voice["timer"]) <= 0.0:
				# Silben: kurze Lautstärkebögen mit Pausen dazwischen
				voice["timer"] = rng.randf_range(0.12, 0.3)
				voice["target"] = rng.randf_range(0.3, 1.0) if rng.randf() < 0.7 else 0.0
			voice["env"] = lerpf(float(voice["env"]), float(voice["target"]), 0.0012)
			voice["low"] = float(voice["low"]) + 0.09 * (white - float(voice["low"]))
			voice["mid"] = float(voice["mid"]) + 0.03 * (white - float(voice["mid"]))
			value += (float(voice["low"]) - float(voice["mid"])) * float(voice["env"])
		raw[i] = value
	var samples := _crossfade_loop(raw, length, fade)
	_normalize(samples, 0.35)
	return _to_wav(samples, true)


## Ein Wintervogel in der Ferne: zwei bis fünf helle, fallende Pfeiftöne.
static func _bird(variant: int) -> AudioStreamWAV:
	var rng := _rng(97 + variant * 7)
	var notes := 2 + variant % 4
	var samples := _silence(0.25 + notes * 0.19)
	var start := 0.02
	var base := rng.randf_range(3200.0, 4600.0)
	for n in notes:
		var length := rng.randf_range(0.07, 0.13)
		var from := base * rng.randf_range(1.0, 1.15)
		var to := base * rng.randf_range(0.7, 0.9)
		var phase := 0.0
		for i in range(int(start * MIX_RATE), mini(int((start + length) * MIX_RATE), samples.size())):
			var t := float(i) / MIX_RATE - start
			var progress := t / length
			phase += TAU * lerpf(from, to, progress) * (1.0 + 0.01 * sin(TAU * 40.0 * t)) / MIX_RATE
			samples[i] += sin(phase) * sin(PI * progress)
		start += length + rng.randf_range(0.06, 0.12)
	_normalize(samples, 0.3)
	return _to_wav(samples)


static func _crossfade_loop(raw: PackedFloat32Array, length: int, fade: int) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(length)
	for i in length:
		samples[i] = raw[i]
		if i < fade:
			var w := float(i) / fade
			samples[i] = raw[i] * w + raw[length + i] * (1.0 - w)
	return samples


## Schritt auf Holz (Bohlenübergang): dumpfes Klopfen mit hohlem Nachklang.
static func _wood_step(variant: int) -> AudioStreamWAV:
	var rng := _rng(131 + variant * 17)
	var samples := _silence(0.22)
	var band := 0.0
	var base := 190.0 + variant * 22.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		band += 0.3 * (white - band)
		var knock := sin(TAU * base * t) * exp(-t * 38.0) + 0.5 * sin(TAU * base * 2.3 * t) * exp(-t * 60.0)
		var click := (white - band) * exp(-t * 120.0) * 0.4
		samples[i] = knock * 0.7 + click
	_normalize(samples, 0.27)
	return _to_wav(samples)


## Holzknarren (Bank beim Hinsetzen): langsam gleitender, rauer Ton.
static func _creak() -> AudioStreamWAV:
	var rng := _rng(137)
	var duration := 0.55
	var samples := _silence(duration)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var frequency := lerpf(210.0, 150.0, t / duration) + sin(TAU * 7.0 * t) * 12.0
		phase += TAU * frequency / MIX_RATE
		# Reibung: ruckelnde Pulse statt glattem Ton
		var grain := 0.6 + 0.4 * absf(sin(TAU * 34.0 * t + rng.randf() * 0.4))
		var envelope := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(duration - 0.2, duration, t))
		samples[i] = (sin(phase) + 0.4 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0)) * grain * envelope
	_normalize(samples, 0.2)
	return _to_wav(samples)


## Laternen-Ambiente: ganz leises, warmes Summen mit gelegentlichem Knistern. Schleife (4 s).
static func _lamp_hum() -> AudioStreamWAV:
	var rng := _rng(149)
	var length := int(MIX_RATE * 4.0)
	var fade := int(MIX_RATE * 0.4)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var low := 0.0
	var crackle := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.05 * (white - low)
		if rng.randf() < 0.0004:
			crackle = rng.randf_range(0.4, 1.0)
		crackle *= 0.985
		var hum := sin(TAU * 100.0 * t) * 0.3 + sin(TAU * 200.0 * t) * 0.1
		raw[i] = hum * (0.8 + 0.2 * sin(TAU * 0.7 * t)) + low * 0.8 + white * crackle * 0.5
	var samples := _crossfade_loop(raw, length, fade)
	_normalize(samples, 0.3)
	return _to_wav(samples, true)


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


# --- Güterbahnhof und Baustelle ---------------------------------------------------

## Kranmotor: tiefes, weiches Brummen mit leisem Getriebesingen. Schleife (3 s).
static func _crane_motor() -> AudioStreamWAV:
	var rng := _rng(211)
	var length := int(MIX_RATE * 3.0)
	var fade := int(MIX_RATE * 0.3)
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var low := 0.0
	for i in raw.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.04 * (white - low)
		var hum := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.0 * t) * 0.25 + sin(TAU * 165.0 * t) * 0.1
		var whine := sin(TAU * 620.0 * t + sin(TAU * 1.3 * t) * 2.0) * 0.05
		raw[i] = (hum + whine) * (0.85 + 0.15 * sin(TAU * 4.0 * t)) + low * 0.9
	var samples := _crossfade_loop(raw, length, fade)
	_normalize(samples, 0.3)
	return _to_wav(samples, true)


## Metallisches Klacken (Traverse setzt auf, Greifer schließt): kurz, gedämpft.
static func _clank() -> AudioStreamWAV:
	var rng := _rng(223)
	var samples := _silence(0.45)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var ring := sin(TAU * 410.0 * t) * 0.5 + sin(TAU * 1130.0 * t) * 0.25 + sin(TAU * 1720.0 * t) * 0.12
		var knock := rng.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		samples[i] = ring * exp(-t * 11.0) + knock * 0.6
	_normalize(samples, 0.32)
	return _to_wav(samples)


## Schotter rieselt aus dem Greifer: prasselndes Rauschen, das ausläuft.
static func _gravel() -> AudioStreamWAV:
	var rng := _rng(227)
	var duration := 1.6
	var samples := _silence(duration)
	var band := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		band += 0.45 * (white - band)
		var grains := 1.0 if rng.randf() < 0.08 else 0.25
		var envelope := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.3, duration, t))
		samples[i] = (white - band * 0.6) * grains * envelope
	_normalize(samples, 0.3)
	return _to_wav(samples)


## Drei gedämpfte Hammerschläge auf Holz (Baustelle).
static func _hammer() -> AudioStreamWAV:
	var rng := _rng(229)
	var samples := _silence(1.4)
	for hit in 3:
		var start := int((0.05 + hit * 0.42) * MIX_RATE)
		var pitch := 1.0 + rng.randf_range(-0.06, 0.06)
		for j in int(0.25 * MIX_RATE):
			var i := start + j
			if i >= samples.size():
				break
			var t := float(j) / MIX_RATE
			var knock := sin(TAU * 240.0 * pitch * t) * exp(-t * 30.0) + sin(TAU * 610.0 * pitch * t) * 0.4 * exp(-t * 55.0)
			samples[i] += knock + rng.randf_range(-1.0, 1.0) * exp(-t * 150.0) * 0.5
	_normalize(samples, 0.28)
	return _to_wav(samples)


## Handsäge: rhythmisches, gefiltertes Rauschen (vier Züge).
static func _saw() -> AudioStreamWAV:
	var rng := _rng(233)
	var duration := 1.8
	var samples := _silence(duration)
	var band := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		band += 0.3 * (white - band)
		var stroke := absf(sin(TAU * 1.1 * t))
		var teeth := 0.6 + 0.4 * sin(TAU * (90.0 + 50.0 * stroke) * t)
		samples[i] = (white - band) * stroke * teeth * (1.0 - smoothstep(duration - 0.2, duration, t))
	_normalize(samples, 0.16)
	return _to_wav(samples)


## Seite umblättern (Notizbuch): kurzes, weiches Papierrascheln.
static func _page() -> AudioStreamWAV:
	var rng := _rng(239)
	var duration := 0.38
	var samples := _silence(duration)
	var band := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		band += 0.18 * (white - band)
		var envelope := sin(PI * clampf(t / duration, 0.0, 1.0)) * (0.7 + 0.3 * sin(TAU * 23.0 * t))
		samples[i] = (white - band) * envelope * 0.6 + band * envelope
	_normalize(samples, 0.2)
	return _to_wav(samples)


## Haus fertig: zwei helle, warme Glöckchen (Quinte), sanft ausklingend.
static func _done_chime() -> AudioStreamWAV:
	var samples := _silence(1.8)
	for note in 2:
		var start := int(note * 0.22 * MIX_RATE)
		var frequency: float = [784.0, 1174.66][note]
		for j in samples.size() - start:
			var t := float(j) / MIX_RATE
			var bell := sin(TAU * frequency * t) + 0.35 * sin(TAU * frequency * 2.76 * t) * exp(-t * 4.0)
			samples[start + j] += bell * exp(-t * 2.6) * smoothstep(0.0, 0.01, t)
	_normalize(samples, 0.35)
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


## Einen Player beim Verlassen des Szenenbaums anhalten und freigeben
## (sonst bleiben laufende Klänge beim Beenden im Audioserver hängen).
static func stop_on_exit(player: Node) -> void:
	player.tree_exiting.connect(func() -> void:
		player.call(&"stop")
		player.set(&"stream", null))


## Ohne Audioausgabe (headless, z.B. automatische Tests) wird nichts abgespielt –
## sonst hielte der Audioserver beim Beenden laufende Klänge fest.
static var audible := DisplayServer.get_name() != "headless"


## Spielt [param player] ab, sofern es eine Audioausgabe gibt.
static func play(player: Node) -> void:
	if audible:
		player.call(&"play")
