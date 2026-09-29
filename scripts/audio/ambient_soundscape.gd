## Dezente Klangkulisse: Wind, Bahnsteig-Gemurmel und ferne Vögel.
##
## - Wind: immer leise da, bei Schneefall und nachts etwas stärker.
## - Gemurmel: am Bahnsteig, umso hörbarer, je mehr Leute dort sind.
## - Vögel: tagsüber ab und zu ein ferner Wintervogel aus zufälliger Richtung
##   (nicht bei dichtem Schneefall und nicht im schnellen Zeitraffer).
## Alles ist bewusst leise gemischt – die Züge und Schritte bleiben im Vordergrund.
##
## Ab Etappe 9 reagiert alles auf Wetter, Jahreszeit und Tageszeit:
## - Wind (Wetter), Wind in den Bäumen (Wind × Laub der Jahreszeit)
## - rieselnder Schnee bei Schneefall, Regen auf Dächern bei Regen
## - Kaminfeuer am nächsten Haus, wenn es kalt ist (abends lauter)
## - Vögel je nach Jahreszeit, im Winter Meise und Rotkehlchen; Grillen in Sommernächten
## - ferne Kirchenglocke um 8, 12 und 18 Uhr
## - bei Nebel am Bahnhof ab und zu ein gedämpftes Horn aus der Ferne
class_name AmbientSoundscape
extends Node3D

@export var npc_director: NpcDirector
@export var snowfall: Snowfall
@export var weather: WeatherSystem
## Aus dieser Richtung (weit weg im Tal) klingt die Kirchenglocke.
@export var church_position := Vector3(-160.0, 20.0, 60.0)
## Mitte des Bahnsteigs (Quelle des Gemurmels).
@export var station_center := Vector3(0.0, 1.2, -9.0)
@export var wind_volume_db := Vector2(-32.0, -19.0)
@export var murmur_volume_db := -15.0
@export var bird_interval := Vector2(7.0, 20.0)

var _wind: AudioStreamPlayer
var _murmur: AudioStreamPlayer3D
var _birds: Array[AudioStreamPlayer3D] = []
var _bird_timer := 5.0
var _rng := RandomNumberGenerator.new()
## Ohne Audioausgabe (z.B. automatische Tests) keine Dauerschleifen starten.
var _audible := SoundLibrary.audible


func _ready() -> void:
	_rng.randomize()
	_wind = AudioStreamPlayer.new()
	_wind.stream = SoundLibrary.get_sound("wind")
	_wind.volume_db = wind_volume_db.x
	add_child(_wind)
	SoundLibrary.stop_on_exit(_wind)
	if _audible:
		_wind.play()
	_murmur = AudioStreamPlayer3D.new()
	_murmur.stream = SoundLibrary.get_sound("station_murmur")
	_murmur.volume_db = -80.0
	_murmur.unit_size = 9.0
	_murmur.max_distance = 55.0
	add_child(_murmur)
	SoundLibrary.stop_on_exit(_murmur)
	_murmur.global_position = station_center
	if _audible:
		_murmur.play()
	for i in 2:
		var bird := AudioStreamPlayer3D.new()
		bird.unit_size = 14.0
		bird.max_distance = 110.0
		add_child(bird)
		SoundLibrary.stop_on_exit(bird)
		_birds.append(bird)
	_trees = _loop("tree_wind")
	_snow_hiss = _loop("snow_hiss")
	_rain = _loop("rain_roof")
	_crickets = _loop("crickets")
	_fire = AudioStreamPlayer3D.new()
	_fire.stream = SoundLibrary.get_sound("fireplace")
	_fire.volume_db = -80.0
	_fire.unit_size = 4.0
	_fire.max_distance = 30.0
	add_child(_fire)
	SoundLibrary.stop_on_exit(_fire)
	if _audible:
		_fire.play()
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = SoundLibrary.get_sound("church_bell")
	_bell.unit_size = 60.0
	_bell.max_distance = 600.0
	_bell.volume_db = -14.0
	add_child(_bell)
	SoundLibrary.stop_on_exit(_bell)
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = SoundLibrary.get_sound("fog_horn")
	_horn.unit_size = 40.0
	_horn.max_distance = 400.0
	_horn.volume_db = -16.0
	add_child(_horn)
	SoundLibrary.stop_on_exit(_horn)
	WorldClock.hour_changed.connect(_on_hour_changed)


## Leise Dauerschleife (startet stumm, die Lautstärke folgt dem Wetter).
func _loop(sound: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = SoundLibrary.get_sound(sound)
	player.volume_db = -80.0
	add_child(player)
	SoundLibrary.stop_on_exit(player)
	if _audible:
		player.play()
	return player


var _trees: AudioStreamPlayer
var _snow_hiss: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _fire: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _bell_strikes := 0
var _bell_timer := 0.0
var _horn_timer := 30.0
var _fire_timer := 0.0


func _process(delta: float) -> void:
	var snow := weather.get_value("snow") if weather else (snowfall.intensity if snowfall else 0.0)
	var rain := weather.get_value("rain") if weather else 0.0
	var fog := weather.get_value("fog") if weather else 1.0
	var night := 1.0 if WorldClock.is_dark() else 0.0
	var wind_strength := weather.get_value("wind") if weather else clampf(0.3 + snow * 0.5 + night * 0.2, 0.0, 1.0)
	_wind.volume_db = lerpf(_wind.volume_db, lerpf(wind_volume_db.x, wind_volume_db.y, wind_strength), 1.0 - exp(-0.5 * delta))
	_wind.pitch_scale = 0.9 + wind_strength * 0.2
	var fade := 1.0 - exp(-0.6 * delta)
	var leaves := float(Seasons.get_value("leaves"))
	_trees.volume_db = lerpf(_trees.volume_db, _db(wind_strength * leaves, -34.0, -20.0), fade)
	_snow_hiss.volume_db = lerpf(_snow_hiss.volume_db, _db(snow, -40.0, -24.0), fade)
	_rain.volume_db = lerpf(_rain.volume_db, _db(rain, -34.0, -14.0), fade)
	var cricket_time := 1.0 if WorldClock.time_of_day > 20.5 or WorldClock.time_of_day < 4.0 else 0.0
	_crickets.volume_db = lerpf(_crickets.volume_db, _db(float(Seasons.get_value("crickets")) * cricket_time * (1.0 - rain), -36.0, -24.0), fade)
	_update_fire(delta)
	_update_bell(delta)
	# Bahnhof bei Nebel: ab und zu ein gedämpftes Horn aus der Ferne
	_horn_timer -= delta
	if _horn_timer <= 0.0:
		_horn_timer = _rng.randf_range(35.0, 80.0)
		if fog > 2.5 and _audible and WorldClock.time_scale <= 2.0:
			_horn.global_position = station_center + Vector3(_rng.randf_range(-20.0, 20.0), 10.0, -140.0 if _rng.randf() < 0.5 else 140.0)
			_horn.pitch_scale = _rng.randf_range(0.92, 1.0)
			_horn.play()
	var weather_amount := maxf(snow, rain)

	var people := get_station_people()
	var murmur_target := -80.0 if people == 0 else murmur_volume_db - 10.0 + minf(people, 6.0) / 6.0 * 10.0
	murmur_target -= clampf((fog - 1.0) * 1.5, 0.0, 6.0)  # im Nebel klingt alles gedämpfter
	_murmur.volume_db = lerpf(_murmur.volume_db, murmur_target, 1.0 - exp(-0.8 * delta))

	_bird_timer -= delta
	if _bird_timer <= 0.0:
		# Im Frühling singen viel mehr Vögel als im Winter
		var season_birds := maxf(float(Seasons.get_value("birds")), 0.2)
		_bird_timer = _rng.randf_range(bird_interval.x, bird_interval.y) / season_birds
		if _birds_active(weather_amount) and _audible:
			_play_bird()


## Wie viele Leute gerade am Bahnhof sind (bestimmt das Gemurmel).
func get_station_people() -> int:
	if npc_director == null:
		return 0
	var count := 0
	for npc in npc_director.get_npcs() + npc_director.get_travellers():
		if npc.is_present() and npc.global_position.distance_to(station_center) < 30.0:
			count += 1
	return count


func _birds_active(amount: float) -> bool:
	var hour := WorldClock.time_of_day
	return hour > WorldClock.get_sunrise() + 0.5 and hour < WorldClock.get_sunset() - 0.5 and amount < 0.6 \
		and WorldClock.time_scale <= 2.0


func _play_bird() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var bird: AudioStreamPlayer3D = _birds[0] if not _birds[0].playing else _birds[1]
	if bird.playing:
		return
	var angle := _rng.randf() * TAU
	var distance := _rng.randf_range(25.0, 60.0)
	bird.global_position = camera.global_position + Vector3(cos(angle) * distance, _rng.randf_range(4.0, 9.0), sin(angle) * distance)
	# Im Winter rufen Meise und Rotkehlchen, sonst die übrigen Vogelstimmen
	if Seasons.get_snow_cover() > 0.5 and _rng.randf() < 0.7:
		bird.stream = SoundLibrary.get_sound("winter_bird_%d" % _rng.randi_range(0, 1))
	else:
		bird.stream = SoundLibrary.get_sound("bird_%d" % _rng.randi_range(0, 3))
	bird.volume_db = _rng.randf_range(-14.0, -8.0)
	bird.pitch_scale = _rng.randf_range(0.94, 1.08)
	bird.play()


## Lautstärke (dB) für eine Stärke 0..1 (unter 0,02 stumm).
func _db(amount: float, quiet: float, loud: float) -> float:
	return -80.0 if amount < 0.02 else lerpf(quiet, loud, clampf(amount, 0.0, 1.0))


## Kaminfeuer: am Haus, das der Kamera am nächsten ist – nur wenn es kalt ist.
func _update_fire(delta: float) -> void:
	_fire_timer -= delta
	var camera := get_viewport().get_camera_3d()
	if _fire_timer <= 0.0 and camera:
		_fire_timer = 1.0
		var best := INF
		for node in get_tree().get_nodes_in_group(NpcHome.GROUP):
			var home := node as Node3D
			var d := home.global_position.distance_to(camera.global_position)
			if d < best:
				best = d
				_fire.global_position = home.global_position + Vector3(0, 2.0, 0)
	var cold := clampf(Seasons.get_snow_cover() + (0.3 if Seasons.get_season() == Seasons.Season.AUTUMN else 0.0), 0.0, 1.0)
	var evening := 1.0 if WorldClock.is_dark() else 0.45
	var target := _db(cold * evening, -30.0, -16.0)
	_fire.volume_db = lerpf(_fire.volume_db, target, 1.0 - exp(-0.8 * delta))


## Kirchenglocke: um 8, 12 und 18 Uhr drei ferne Schläge.
func _on_hour_changed(hour: int) -> void:
	if hour in [8, 12, 18] and WorldClock.time_scale <= 10.0:
		_bell_strikes = 3
		_bell_timer = 0.0


func _update_bell(delta: float) -> void:
	if _bell_strikes <= 0:
		return
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		_bell_strikes -= 1
		_bell_timer = 2.4
		_bell.global_position = church_position
		if _audible:
			_bell.play()


## Für Tests: wie laut die Wetterschleifen gerade sind.
func get_loop_volumes() -> Dictionary:
	return {"trees": _trees.volume_db, "snow": _snow_hiss.volume_db, "rain": _rain.volume_db,
		"crickets": _crickets.volume_db, "fire": _fire.volume_db, "wind": _wind.volume_db}
