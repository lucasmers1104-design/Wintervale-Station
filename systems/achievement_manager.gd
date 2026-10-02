## Per-journey achievements. Only live gameplay events change progress.
extends Node

signal unlocked(id: String)
signal progress_changed

const SAVE_ID := "achievements"
const DEFINITIONS := [
	{"id":"first_tracks", "name":"First Tracks", "description":"Place your first railway track.", "category":"Railway", "target":1, "icon":"rail"},
	{"id":"getting_connected", "name":"Getting Connected", "description":"Build 100 meters of track.", "category":"Railway", "target":100, "icon":"rail"},
	{"id":"railway_engineer", "name":"Railway Engineer", "description":"Build 1,000 meters of track.", "category":"Railway", "target":1000, "icon":"rail"},
	{"id":"all_aboard", "name":"All Aboard", "description":"Complete your first train arrival.", "category":"Railway", "target":1, "icon":"train"},
	{"id":"full_schedule", "name":"Full Schedule", "description":"Complete 50 train arrivals.", "category":"Railway", "target":50, "icon":"train"},
	{"id":"freight_master", "name":"Freight Master", "description":"Deliver 1,000 units of freight.", "category":"Railway", "target":1000, "icon":"freight"},
	{"id":"home_sweet_home", "name":"Home Sweet Home", "description":"Build your first residential building.", "category":"Village", "target":1, "icon":"home"},
	{"id":"little_village", "name":"Little Village", "description":"Reach a population of 25.", "category":"Village", "target":25, "icon":"village"},
	{"id":"growing_community", "name":"Growing Community", "description":"Reach a population of 100.", "category":"Village", "target":100, "icon":"village"},
	{"id":"village_architect", "name":"Village Architect", "description":"Construct 50 buildings.", "category":"Village", "target":50, "icon":"home"},
	{"id":"bright_nights", "name":"Bright Nights", "description":"Place 25 decorative lanterns.", "category":"Village", "target":25, "icon":"lantern"},
	{"id":"winter_wonderland", "name":"Winter Wonderland", "description":"Experience your first snowfall.", "category":"Cozy", "target":1, "icon":"snow"},
	{"id":"night_owl", "name":"Night Owl", "description":"Experience an entire in-game night.", "category":"Cozy", "target":1, "icon":"moon"},
	{"id":"let_there_be_light", "name":"Let There Be Light", "description":"Place your first decorative string lights.", "category":"Cozy", "target":1, "icon":"lights"},
	{"id":"cozy_evening", "name":"Cozy Evening", "description":"Witness a train arrival during a winter evening.", "category":"Cozy", "target":1, "icon":"train"},
]

var progress: Dictionary = {}
var unlock_times: Dictionary = {}
var _seen_segments: Dictionary = {}
var _seen_buildings: Dictionary = {}
var _seen_lanterns: Dictionary = {}
var _world: Node
var _network: RailNetwork
var _village: VillageManager
var _dispatcher: TrainDispatcher
var _weather: WeatherSystem
var _night_started := false
var _suspended := false
var _save_delay := -1.0


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	WorldClock.darkness_changed.connect(_on_darkness_changed)


func _process(delta: float) -> void:
	if _save_delay < 0.0:
		return
	_save_delay -= delta
	if _save_delay <= 0.0:
		_save_delay = -1.0
		_save_progress()


func attach_world(world: Node) -> void:
	_world = world
	_network = world.get_node_or_null(^"World/Railway/RailNetwork") as RailNetwork
	_village = world.get_node_or_null(^"World/Village") as VillageManager
	_dispatcher = world.get_node_or_null(^"World/Railway/TrainDispatcher") as TrainDispatcher
	_weather = world.get_node_or_null(^"Weather") as WeatherSystem
	if _network:
		_network.segment_added.connect(_on_segment_added)
		for segment in _network.get_segments():
			_seen_segments[segment.id] = true
	if _village:
		_village.changed.connect(_refresh_village)
		_village.construction_finished.connect(_on_house_finished)
		_village.residents_arriving.connect(func(_home: String, _count: int) -> void: _refresh_village())
	if _dispatcher:
		_dispatcher.trains_changed.connect(_connect_trains)
		_connect_trains()
	var yards := get_tree().get_nodes_in_group(&"freight_yard")
	for yard in yards:
		yard.train_serviced.connect(_on_freight_serviced)
	var region := world.get_node_or_null(^"RegionRailway") as RegionRailway
	if region:
		region.freight_delivered.connect(_on_freight_serviced)
	if _weather:
		_weather.weather_changed.connect(_on_weather_changed)
		_on_weather_changed(_weather.current)
	_refresh_village()


func detach_world() -> void:
	_world = null
	_network = null
	_village = null
	_dispatcher = null
	_weather = null


func reset() -> void:
	progress.clear()
	unlock_times.clear()
	_seen_segments.clear()
	_seen_buildings.clear()
	_seen_lanterns.clear()
	_night_started = false
	_save_delay = -1.0
	progress_changed.emit()


func suspend(value: bool) -> void:
	_suspended = value


func refresh_after_load() -> void:
	if _network:
		for segment in _network.get_segments():
			_seen_segments[segment.id] = true
	_refresh_village()


func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"progress": progress.duplicate(true), "unlocked": unlock_times.duplicate(true),
		"seen_segments": _seen_segments.keys(), "seen_buildings": _seen_buildings.keys(),
		"seen_lanterns": _seen_lanterns.keys()}


func load_state(data: Dictionary) -> void:
	reset()
	for definition in DEFINITIONS:
		var id: String = definition["id"]
		if data.get("progress", {}) is Dictionary:
			progress[id] = maxf(0.0, float(data["progress"].get(id, 0.0)))
		if data.get("unlocked", {}) is Dictionary and data["unlocked"].has(id):
			unlock_times[id] = String(data["unlocked"][id])
	for segment_id in data.get("seen_segments", []):
		_seen_segments[int(segment_id)] = true
	for building_id in data.get("seen_buildings", []):
		_seen_buildings[int(building_id)] = true
	for lantern_id in data.get("seen_lanterns", []):
		_seen_lanterns[int(lantern_id)] = true
	progress_changed.emit()


func get_definition(id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if definition["id"] == id:
			return definition
	return {}


func is_unlocked(id: String) -> bool:
	return unlock_times.has(id)


func unlocked_count() -> int:
	return unlock_times.size()


func _set_progress(id: String, amount: float) -> void:
	if _suspended or _world == null or not is_instance_valid(_world) or is_unlocked(id):
		return
	var definition := get_definition(id)
	if definition.is_empty():
		return
	var prior := float(progress.get(id, 0.0))
	var next := maxf(prior, amount)
	if next <= prior:
		return
	progress[id] = next
	progress_changed.emit()
	if next >= float(definition["target"]):
		unlock_times[id] = Time.get_datetime_string_from_system()
		unlocked.emit(id)
		# Fortschritt gehört zum Spielstand und wird mit ihm gespeichert. Nur wenn
		# der Spieler Autosave erlaubt, sichert eine Freischaltung die Reise sofort –
		# sonst würde ein Achievement ungefragt den Spielstand überschreiben.
		if GameSettings.get_pref("autosave"):
			_save_delay = 0.5


func _save_progress() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == "res://scenes/main/main.tscn":
		SaveManager.save_game(SaveManager.active_slot)


func _on_segment_added(segment: RailSegment) -> void:
	if _suspended or _seen_segments.has(segment.id):
		return
	_seen_segments[segment.id] = true
	_set_progress("first_tracks", 1)
	var length := float(progress.get("getting_connected", 0.0)) + segment.length
	_set_progress("getting_connected", length)
	_set_progress("railway_engineer", float(progress.get("railway_engineer", 0.0)) + segment.length)


func _refresh_village() -> void:
	if _village == null or _suspended:
		return
	var population := _village.get_population()
	_set_progress("little_village", population)
	_set_progress("growing_community", population)
	var lights := 0
	for object in _village.get_objects():
		var data: Dictionary = _village.get_object_data(object.object_id)
		if not bool(data.get("paid", false)):
			continue
		if object is VillageHouse and object.is_finished() and not _seen_buildings.has(object.object_id):
			_seen_buildings[object.object_id] = true
			_set_progress("home_sweet_home", 1)
			_set_progress("village_architect", float(progress.get("village_architect", 0.0)) + 1)
		if object.item_id == "lantern" and not _seen_lanterns.has(object.object_id):
			_seen_lanterns[object.object_id] = true
			_set_progress("bright_nights", float(progress.get("bright_nights", 0.0)) + 1)
		elif object.item_id == "string_lights":
			lights += 1
	_set_progress("let_there_be_light", lights)


func _on_house_finished(house: VillageHouse) -> void:
	if _village and bool(_village.get_object_data(house.object_id).get("paid", false)):
		_set_progress("home_sweet_home", 1)
	_refresh_village()


func _connect_trains() -> void:
	if _dispatcher == null:
		return
	for train in _dispatcher.get_trains():
		if not train.arrived.is_connected(_on_train_arrived):
			train.arrived.connect(_on_train_arrived)


func _on_train_arrived(_train: Train) -> void:
	if _train.has_meta("region_line") and bool(_train.get_meta("origin_dwell",false)):
		return
	_set_progress("all_aboard", 1)
	_set_progress("full_schedule", float(progress.get("full_schedule", 0.0)) + 1)
	if Seasons.get_season() == Seasons.Season.WINTER and WorldClock.is_dark() \
			and WorldClock.get_hour() >= 17 and WorldClock.get_hour() < 22:
		_set_progress("cozy_evening", 1)


func _on_freight_serviced(_number: String, delivered: Dictionary) -> void:
	var amount := 0
	for value in delivered.values():
		amount += int(value)
	_set_progress("freight_master", float(progress.get("freight_master", 0.0)) + amount)


func _on_weather_changed(weather: WeatherSystem.Weather) -> void:
	if weather == WeatherSystem.Weather.LIGHT_SNOW or weather == WeatherSystem.Weather.HEAVY_SNOW:
		_set_progress("winter_wonderland", 1)


func _on_darkness_changed(dark: bool) -> void:
	if _world == null or _suspended:
		return
	if dark and WorldClock.get_hour() >= 16:
		_night_started = true
	elif not dark and _night_started:
		_night_started = false
		_set_progress("night_owl", 1)
