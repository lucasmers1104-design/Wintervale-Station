## Dezente Klangkulisse: Wind, Bahnsteig-Gemurmel und ferne Vögel.
##
## - Wind: immer leise da, bei Schneefall und nachts etwas stärker.
## - Gemurmel: am Bahnsteig, umso hörbarer, je mehr Leute dort sind.
## - Vögel: tagsüber ab und zu ein ferner Wintervogel aus zufälliger Richtung
##   (nicht bei dichtem Schneefall und nicht im schnellen Zeitraffer).
## Alles ist bewusst leise gemischt – die Züge und Schritte bleiben im Vordergrund.
class_name AmbientSoundscape
extends Node3D

@export var npc_director: NpcDirector
@export var snowfall: Snowfall
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


func _process(delta: float) -> void:
	var weather := snowfall.intensity if snowfall else 0.0
	var night := 1.0 if WorldClock.is_dark() else 0.0
	var wind_strength := clampf(0.3 + weather * 0.5 + night * 0.2, 0.0, 1.0)
	_wind.volume_db = lerpf(_wind.volume_db, lerpf(wind_volume_db.x, wind_volume_db.y, wind_strength), 1.0 - exp(-0.5 * delta))
	_wind.pitch_scale = 0.9 + wind_strength * 0.2

	var people := get_station_people()
	var murmur_target := -80.0 if people == 0 else murmur_volume_db - 10.0 + minf(people, 6.0) / 6.0 * 10.0
	_murmur.volume_db = lerpf(_murmur.volume_db, murmur_target, 1.0 - exp(-0.8 * delta))

	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(bird_interval.x, bird_interval.y)
		if _birds_active(weather) and _audible:
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


func _birds_active(weather: float) -> bool:
	var hour := WorldClock.time_of_day
	return hour > 7.5 and hour < 16.5 and weather < 0.6 and WorldClock.time_scale <= 2.0


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
	bird.stream = SoundLibrary.get_sound("bird_%d" % _rng.randi_range(0, 3))
	bird.volume_db = _rng.randf_range(-14.0, -8.0)
	bird.pitch_scale = _rng.randf_range(0.94, 1.08)
	bird.play()
