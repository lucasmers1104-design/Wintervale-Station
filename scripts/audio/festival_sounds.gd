## Selbst komponierte und synthetisierte Festklänge (Etappe 10).
##
## Musik (Schleifen, eigene Melodien):
##   carol    – Spieluhr-Walzer für den Weihnachtsmarkt (3/4, C-Dur, mit Arpeggien)
##   polka    – Akkordeon-Polka fürs Herbstfest (2/4, F-Dur, Umpa-Bass)
##   laterne  – ruhiges Flötenlied für den Laternenumzug (4/4, C-Dur, weiche Flächen)
## Geräusche: crowd_aah (staunende Menge), applause, sparkle (Glockenspiel-Glissando
## beim Aufleuchten des Baums), clink (Becher), sleigh_bells (Schellen am Sonderzug).
##
## Die Instrumente klingen über kleine Wellentabellen (eine Periode mit den
## Obertönen des Instruments) – das ist schnell genug, um die Musik beim Start
## im Hintergrund zu berechnen ([method warm_up]).
class_name FestivalSounds
extends RefCounted

const RATE := 22050
const NAMES: Array[String] = ["carol", "polka", "laterne", "crowd_aah", "applause", "sparkle", "clink", "sleigh_bells"]

static var _cache := {}
static var _mutex := Mutex.new()
static var _tables := {}
static var _task := -1


## Klang holen (wird beim ersten Mal berechnet, falls noch nicht im Hintergrund geschehen).
static func get_sound(sound_name: String) -> AudioStreamWAV:
	_mutex.lock()
	var cached: AudioStreamWAV = _cache.get(sound_name)
	_mutex.unlock()
	if cached:
		return cached
	var stream := _generate(sound_name)
	_mutex.lock()
	_cache[sound_name] = stream
	_mutex.unlock()
	return stream


static func is_ready(sound_name: String) -> bool:
	_mutex.lock()
	var found := _cache.has(sound_name)
	_mutex.unlock()
	return found


## Alle Festklänge im Hintergrund vorbereiten (kein Ruckeln, wenn der Markt öffnet).
static func warm_up() -> void:
	if _task >= 0:
		return
	_tables_for_threads()
	_task = WorkerThreadPool.add_task(func() -> void:
		for sound_name in NAMES:
			get_sound(sound_name))


## Beim Beenden auf die Hintergrundberechnung warten (sonst stürzt das Programm beim Schließen ab).
static func wait_for_warm_up() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


static func clear_cache() -> void:
	_mutex.lock()
	_cache.clear()
	_mutex.unlock()


static func _generate(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"carol":
			return _carol()
		"polka":
			return _polka()
		"laterne":
			return _laterne()
		"crowd_aah":
			return _crowd_aah()
		"applause":
			return _applause()
		"sparkle":
			return _sparkle()
		"clink":
			return _clink()
		"sleigh_bells":
			return _sleigh_bells()
	push_warning("FestivalSounds: Unbekannter Klang '%s'." % sound_name)
	return SoundLibrary._to_wav(PackedFloat32Array([0.0]))


# --- Musik ---------------------------------------------------------------------------------

## Spieluhr-Walzer (eigene Melodie). Jede Zeile: Takt mit [Midi, Schläge] und Akkord.
static func _carol() -> AudioStreamWAV:
	var bpm := 96.0
	var melody := [
		[[76, 1], [79, 1], [76, 1]], [[84, 2], [81, 1]], [[81, 1], [79, 1], [77, 1]], [[76, 3]],
		[[74, 1], [77, 1], [81, 1]], [[79, 2], [77, 1]], [[76, 1], [74, 1], [72, 1]], [[74, 3]],
		[[76, 1], [79, 1], [84, 1]], [[88, 2], [86, 1]], [[84, 1], [81, 1], [77, 1]], [[79, 3]],
		[[81, 1], [84, 1], [81, 1]], [[79, 1], [76, 1], [72, 1]], [[74, 1.5], [76, 0.5], [77, 1]], [[72, 3]],
	]
	var chords := [[48, 52, 55], [45, 48, 52], [41, 45, 48], [48, 52, 55], [50, 53, 57], [43, 47, 50], [48, 52, 55],
		[43, 47, 50], [48, 52, 55], [45, 48, 52], [41, 45, 48], [48, 52, 55], [41, 45, 48], [48, 52, 55], [43, 47, 50],
		[48, 52, 55]]
	var beat := 60.0 / bpm
	var length := int(melody.size() * 3 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(length + RATE * 2)
	var box := _table("music_box")
	var time := 0.0
	for bar in melody.size():
		var bar_start := time
		for note: Array in melody[bar]:
			_pluck(out, box, float(note[0]), bar_start, 1.9, 0.5, 2.6)
			bar_start += float(note[1]) * beat
		# Begleitung: Grundton auf 1, Arpeggio auf 2 und 3 (eine Oktave höher)
		var chord: Array = chords[bar]
		_pluck(out, box, float(chord[0]) + 12.0, time, 2.6, 0.32, 1.6)
		_pluck(out, box, float(chord[1]) + 24.0, time + beat, 1.4, 0.2, 2.8)
		_pluck(out, box, float(chord[2]) + 24.0, time + beat * 1.5, 1.2, 0.16, 3.0)
		_pluck(out, box, float(chord[1]) + 24.0, time + beat * 2.0, 1.2, 0.18, 2.8)
		time += 3.0 * beat
	return _loop(out, length, 0.8)


## Akkordeon-Polka (eigene Melodie), Umpa-Bass und Nachschlag-Akkorde.
static func _polka() -> AudioStreamWAV:
	var bpm := 112.0
	var a := [[[69, 0.5], [72, 0.5], [77, 0.5], [72, 0.5]], [[81, 1], [79, 0.5], [77, 0.5]],
		[[76, 0.5], [79, 0.5], [82, 0.5], [79, 0.5]], [[81, 1], [77, 1]],
		[[74, 0.5], [77, 0.5], [82, 0.5], [77, 0.5]], [[84, 1], [81, 0.5], [77, 0.5]],
		[[79, 0.5], [81, 0.5], [79, 0.5], [76, 0.5]], [[77, 1], [0, 1]]]
	var b := [[[69, 0.5], [72, 0.5], [77, 0.5], [72, 0.5]], [[81, 1], [79, 0.5], [77, 0.5]],
		[[76, 0.5], [79, 0.5], [82, 0.5], [79, 0.5]], [[81, 1], [77, 1]],
		[[74, 0.5], [77, 0.5], [82, 0.5], [77, 0.5]], [[81, 0.5], [79, 0.5], [77, 0.5], [81, 0.5]],
		[[79, 1], [76, 0.5], [72, 0.5]], [[77, 1], [65, 1]]]
	var melody := a + b
	var chords := [[41, 53, 57, 60], [41, 53, 57, 60], [36, 52, 55, 58], [41, 53, 57, 60], [34, 50, 53, 58], [41, 53, 57, 60],
		[36, 52, 55, 58], [41, 53, 57, 60]]
	var beat := 60.0 / bpm
	var length := int(melody.size() * 2 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(length + RATE)
	var reed := _table("accordion")
	var bass := _table("bass")
	var time := 0.0
	for bar in melody.size():
		var start := time
		for note: Array in melody[bar]:
			if int(note[0]) > 0:
				_sustain(out, reed, float(note[0]), start, float(note[1]) * beat * 0.88, 0.34, true)
			start += float(note[1]) * beat
		var chord: Array = chords[bar % chords.size()]
		# Umpa: Bass auf 1, Akkord auf 2 (kurz)
		_sustain(out, bass, float(chord[0]), time, beat * 0.55, 0.42, false)
		for k in range(1, chord.size()):
			_sustain(out, reed, float(chord[k]), time + beat, beat * 0.32, 0.1, false)
		time += 2.0 * beat
	return _loop(out, length, 0.05)


## Flötenlied für den Laternenumzug (eigene Melodie) über weichen Akkordflächen.
static func _laterne() -> AudioStreamWAV:
	var bpm := 80.0
	var melody := [[[67, 1], [64, 1], [67, 1], [72, 1]], [[69, 2], [67, 2]], [[64, 1], [67, 1], [72, 1], [76, 1]], [[74, 4]],
		[[72, 1], [69, 1], [72, 1], [76, 1]], [[74, 2], [72, 2]], [[71, 1], [74, 1], [67, 2]], [[72, 4]]]
	var chords := [[48, 55, 64], [41, 57, 60], [48, 55, 64], [43, 59, 62], [45, 57, 64], [41, 57, 60], [43, 55, 62], [48, 55, 64]]
	var beat := 60.0 / bpm
	var length := int(melody.size() * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(length + RATE)
	var flute := _table("flute")
	var pad := _table("pad")
	var time := 0.0
	for bar in melody.size():
		var start := time
		for note: Array in melody[bar]:
			_sustain(out, flute, float(note[0]), start, float(note[1]) * beat * 0.95, 0.36, true, 0.07)
			start += float(note[1]) * beat
		for midi: int in chords[bar]:
			_sustain(out, pad, float(midi), time, 4.0 * beat, 0.07, false, 0.5)
		time += 4.0 * beat
	# Ein Hauch Atem in der Flöte
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var low := 0.0
	for i in length:
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		out[i] += low * 0.02
	return _loop(out, length, 0.3)


# --- Geräusche ------------------------------------------------------------------------------

## Staunendes "Ahh" vieler Leute: Vokal-Formanten aus gefiltertem Rauschen und Stimmen.
static func _crowd_aah() -> AudioStreamWAV:
	var seconds := 3.2
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var voices := []
	for v in 14:
		voices.append({"f": rng.randf_range(150.0, 330.0), "phase": 0.0, "delay": rng.randf_range(0.0, 0.35),
			"vib": rng.randf_range(4.0, 6.0)})
	var band1 := 0.0
	var band2 := 0.0
	for i in count:
		var t := float(i) / RATE
		var sample := 0.0
		for voice: Dictionary in voices:
			var local := t - float(voice["delay"])
			if local < 0.0:
				continue
			var env := smoothstep(0.0, 0.5, local) * (1.0 - smoothstep(1.6, seconds - 0.2, local))
			var f := float(voice["f"]) * (1.0 + 0.012 * sin(local * float(voice["vib"]) * TAU) + local * 0.03)
			voice["phase"] = fposmod(float(voice["phase"]) + f / RATE, 1.0)
			var p := float(voice["phase"]) * TAU
			# Vokal "a": viele Obertöne, zweiter und dritter kräftig
			sample += env * (sin(p) * 0.5 + sin(p * 2.0) * 0.35 + sin(p * 3.0) * 0.4 + sin(p * 4.0) * 0.18)
		var noise := rng.randf_range(-1.0, 1.0)
		band1 += (noise - band1) * 0.18
		band2 += (band1 - band2) * 0.3
		var breath := (band1 - band2) * smoothstep(0.0, 0.6, t) * (1.0 - smoothstep(1.8, seconds, t))
		out[i] = sample * 0.05 + breath * 0.35
	SoundLibrary._normalize(out, 0.42)
	return SoundLibrary._to_wav(out)


## Freundlicher Applaus: viele kurze Klatscher, erst dicht, dann weniger.
static func _applause() -> AudioStreamWAV:
	var seconds := 3.6
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 260:
		var start_t := pow(rng.randf(), 1.6) * (seconds - 0.2)
		var start := int(start_t * RATE)
		var length := int(rng.randf_range(0.012, 0.03) * RATE)
		var gain := rng.randf_range(0.3, 1.0) * (1.0 - start_t / seconds * 0.7)
		var tone := rng.randf_range(0.25, 0.6)
		var low := 0.0
		for j in length:
			if start + j >= count:
				break
			low += (rng.randf_range(-1.0, 1.0) - low) * tone
			out[start + j] += low * gain * exp(-float(j) / (length * 0.3))
	SoundLibrary._normalize(out, 0.36)
	return SoundLibrary._to_wav(out)


## Aufsteigendes Glockenspiel (die Lichter gehen an).
static func _sparkle() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(3.6 * RATE))
	var bell := _table("glockenspiel")
	var notes := [72, 76, 79, 84, 88, 91, 96, 100, 103]
	for k in notes.size():
		_pluck(out, bell, float(notes[k]), 0.1 + k * 0.16, 1.6, 0.4 - k * 0.02, 2.2)
	_pluck(out, bell, 96.0, 1.7, 2.2, 0.35, 1.4)
	_pluck(out, bell, 100.0, 1.72, 2.2, 0.25, 1.4)
	SoundLibrary._normalize(out, 0.5)
	return SoundLibrary._to_wav(out)


## Zwei Becher stoßen an.
static func _clink() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(0.9 * RATE))
	for k in 2:
		var start := int((0.02 + k * 0.09) * RATE)
		var f := 1850.0 + k * 410.0
		for i in int(0.7 * RATE):
			if start + i >= out.size():
				break
			var t := float(i) / RATE
			out[start + i] += exp(-t * 11.0) * (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.73 * t) * exp(-t * 20.0)) * 0.5
	SoundLibrary._normalize(out, 0.38)
	return SoundLibrary._to_wav(out)


## Schellenkranz: helle, metallische Glöckchen, rhythmisch geschüttelt.
static func _sleigh_bells() -> AudioStreamWAV:
	var seconds := 2.8
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var shake := 0.0
	while shake < seconds - 0.3:
		for b in 7:
			var start := int((shake + rng.randf_range(0.0, 0.05)) * RATE)
			var f := rng.randf_range(2800.0, 4600.0)
			var gain := rng.randf_range(0.3, 0.8) * (1.0 - shake / seconds * 0.6)
			for i in int(0.35 * RATE):
				if start + i >= out.size():
					break
				var t := float(i) / RATE
				out[start + i] += gain * exp(-t * 14.0) * (sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.51 * t))
		shake += 0.24 if int(shake / 0.24) % 4 != 3 else 0.36
	SoundLibrary._normalize(out, 0.34)
	return SoundLibrary._to_wav(out)


# --- Instrumente -------------------------------------------------------------------------

const TABLE_SIZE := 512


## Eine Periode eines Instruments mit seinen Obertönen (normiert).
static func _table(instrument: String) -> PackedFloat32Array:
	_mutex.lock()
	var cached: PackedFloat32Array = _tables.get(instrument, PackedFloat32Array())
	_mutex.unlock()
	if not cached.is_empty():
		return cached
	var partials := {
		"music_box": [[1, 1.0], [2, 0.28], [3, 0.1], [4, 0.12], [6, 0.04]],
		"glockenspiel": [[1, 1.0], [3, 0.3], [4, 0.2], [7, 0.08]],
		"accordion": [[1, 1.0], [2, 0.7], [3, 0.55], [4, 0.4], [5, 0.3], [6, 0.2], [7, 0.14], [8, 0.1]],
		"bass": [[1, 1.0], [2, 0.5], [3, 0.2]],
		"flute": [[1, 1.0], [2, 0.18], [3, 0.08]],
		"pad": [[1, 1.0], [2, 0.12]],
	}
	var table := PackedFloat32Array()
	table.resize(TABLE_SIZE)
	var peak := 0.0
	for i in TABLE_SIZE:
		var x := float(i) / TABLE_SIZE * TAU
		var value := 0.0
		for partial: Array in partials.get(instrument, [[1, 1.0]]):
			value += sin(x * float(partial[0])) * float(partial[1])
		table[i] = value
		peak = maxf(peak, absf(value))
	for i in TABLE_SIZE:
		table[i] /= peak
	_mutex.lock()
	_tables[instrument] = table
	_mutex.unlock()
	return table


static func _tables_for_threads() -> void:
	for instrument in ["music_box", "glockenspiel", "accordion", "bass", "flute", "pad"]:
		_table(instrument)


static func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Gezupfter/angeschlagener Ton (Spieluhr, Glockenspiel): schneller Anschlag, abklingend.
static func _pluck(out: PackedFloat32Array, table: PackedFloat32Array, midi: float, at: float, seconds: float, gain: float,
		decay: float) -> void:
	var start := int(at * RATE)
	var count := mini(int(seconds * RATE), out.size() - start)
	var step := _freq(midi) / RATE * TABLE_SIZE
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := minf(t * 400.0, 1.0) * exp(-t * decay)
		out[start + i] += table[int(phase) % TABLE_SIZE] * env * gain
		phase += step


## Gehaltener Ton (Akkordeon, Flöte, Fläche) mit sanftem Ein- und Ausklang, optional Vibrato.
static func _sustain(out: PackedFloat32Array, table: PackedFloat32Array, midi: float, at: float, seconds: float, gain: float,
		vibrato: bool, attack := 0.02) -> void:
	if seconds <= 0.0 or gain <= 0.0:
		return
	var start := int(at * RATE)
	var release := 0.06
	var count := mini(int((seconds + release) * RATE), out.size() - start)
	var base := _freq(midi) / RATE * TABLE_SIZE
	var phase := 0.0
	var phase2 := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := minf(t / attack, 1.0) * (1.0 - clampf((t - seconds) / release, 0.0, 1.0))
		var vib := 1.0 + (0.004 * sin(t * 5.5 * TAU) * minf(t * 3.0, 1.0) if vibrato else 0.0)
		# Akkordeon und Flöte: zwei leicht verstimmte Stimmen (Schwebung, "Musette")
		out[start + i] += (table[int(phase) % TABLE_SIZE] + table[int(phase2) % TABLE_SIZE] * 0.6) * env * gain * 0.62
		phase += base * vib
		phase2 += base * vib * 1.0035


## Schleife: Ende weich in den Anfang überblenden, dann auf Lautstärke bringen.
static func _loop(out: PackedFloat32Array, length: int, fade_seconds: float) -> AudioStreamWAV:
	var fade := int(fade_seconds * RATE)
	for i in mini(fade, out.size() - length):
		out[i] += out[length + i]
	out.resize(length)
	SoundLibrary._normalize(out, 0.5)
	var stream := SoundLibrary._to_wav(out, true)
	return stream
