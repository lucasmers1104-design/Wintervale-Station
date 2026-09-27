## Regie für das Leben am Bahnhof.
##
## - lädt alle Bewohner-Steckbriefe (assets/npcs/*.tres) und erzeugt die Figuren,
## - setzt Reisende ein: vor Abfahrten kommen sie aus dem Dorf, bei Ankünften
##   steigen sie aus und gehen ins Dorf,
## - vermittelt Züge (wer fährt wohin, welche Tür ist frei), Plätze am Bahnsteig,
##   Wohnhäuser und den Boden unter den Füßen,
## - stellt nach Spielstart, Laden oder Zeitsprung alle Bewohner passend zur Uhrzeit auf.
##
## Die Züge selbst werden hier nicht gesteuert – nur beobachtet. Einzige
## Rückwirkung: Ein- und Aussteigende halten kurz die Türen auf.
class_name NpcDirector
extends Node3D

## Jemand ist in einen Zug eingestiegen bzw. ausgestiegen (benannt oder Reisender).
signal passenger_boarded(npc: Npc, train: Train)
signal passenger_alighted(npc: Npc, train: Train)

@export var dispatcher: TrainDispatcher
@export var walk_graph: WalkGraph
@export var terrain: LowPolyTerrain
@export var player: PlayerController
@export var station_name := "Wintervale"
## Ordner mit den Steckbriefen (.tres). Leer lassen = nur [member profiles].
@export_dir var profiles_dir := "res://assets/npcs"
@export var profiles: Array[NpcProfile] = []
## Wegpunkt, an dem Reisende das Dorf verlassen bzw. betreten.
@export var exit_point := "Dorfausgang"
@export var enabled := true
@export_group("Reisende")
@export var max_travellers := 8
## Wie viele Reisende je Zug ein- bzw. aussteigen (zufällig dazwischen).
@export var travellers_per_train := Vector2i(0, 2)
## In diesem Umkreis werden Namen über den Köpfen eingeblendet (nur zu Fuß).
@export var name_tag_distance := 5.0

var _npcs: Array[Npc] = []
var _travellers: Array[Npc] = []
var _homes: Dictionary[String, NpcHome] = {}
var _spots: Array[StationSpot] = []
var _platform_points: Array[Vector3] = []
var _arrivals_seen: Dictionary[int, bool] = {}
var _departures_spawned: Dictionary[int, int] = {}
var _door_use: Dictionary[String, int] = {}
var _last_hours := -1.0
var _schedule_timer := 0.0
var _traveller_count := 0
## Weglänge vom Dorfrand zum Bahnsteig (Meter).
var _walk_distance := 55.0
var _exploring := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4711
	Events.view_mode_changed.connect(func(mode: GameDefs.ViewMode) -> void:
		_exploring = mode == GameDefs.ViewMode.EXPLORE)
	Events.game_loaded.connect(func(_slot: String) -> void: resume_all())
	_load_profiles()
	# Erst wenn Gleise, Häuser und Bahnsteig stehen
	_setup.call_deferred()


func _setup() -> void:
	for node in get_tree().get_nodes_in_group(NpcHome.GROUP):
		_homes[(node as NpcHome).home_name] = node
	for node in get_tree().get_nodes_in_group(StationSpot.GROUP):
		var spot := node as StationSpot
		if spot.station_name == station_name:
			_spots.append(spot)
	if walk_graph:
		for child in walk_graph.get_children():
			if child is Marker3D and String(child.name).begins_with("Bahnsteig"):
				_platform_points.append((child as Marker3D).global_position)
	if walk_graph and not _platform_points.is_empty():
		var path := walk_graph.find_path(get_exit_point(), _platform_points[0])
		_walk_distance = 0.0
		for i in path.size() - 1:
			_walk_distance += path[i].distance_to(path[i + 1])
	for i in profiles.size():
		var npc := Npc.new()
		add_child(npc)
		npc.setup(self, profiles[i], profiles[i].appearance, i * 7 + 3)
		_npcs.append(npc)
		_relay_signals(npc)
	resume_all()


## Alle Bewohner passend zur Uhrzeit aufstellen; Reisende verschwinden.
func resume_all() -> void:
	for traveller in _travellers:
		if is_instance_valid(traveller):
			traveller.queue_free()
	_travellers.clear()
	_door_use.clear()
	_arrivals_seen.clear()
	for npc in _npcs:
		npc.resume(WorldClock.time_of_day)
	_last_hours = WorldClock.time_of_day


func get_npcs() -> Array[Npc]:
	return _npcs


func get_travellers() -> Array[Npc]:
	_travellers = _travellers.filter(func(npc: Npc) -> bool: return is_instance_valid(npc) and not npc.is_queued_for_deletion())
	return _travellers


func get_npc(display_name: String) -> Npc:
	for npc in _npcs:
		if npc.display_name == display_name:
			return npc
	return null


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var now := WorldClock.time_of_day
	# Zeitsprung (z.B. Uhr gestellt): alle neu aufstellen
	if _last_hours >= 0.0 and absf(_hours_between(_last_hours, now)) > 0.6:
		resume_all()
	_last_hours = now
	_schedule_timer -= delta
	if _schedule_timer <= 0.0:
		_schedule_timer = 0.5
		_watch_trains()
		_spawn_departing_travellers(now)


# --- Züge ---------------------------------------------------------------------------

## Ein Zug nach [param destination], der gerade mit offenen Türen hier hält.
## Mit [param entry_index] ≥ 0 nur genau dieser Fahrplanzug.
func find_departing_train(destination: String, _npc: Npc = null, entry_index := -1) -> Train:
	for train in _station_trains():
		if not train.doors_open() or train.dwell_phase == Train.Dwell.CLOSING:
			continue
		if entry_index >= 0:
			if int(train.get_meta(&"entry_index", -1)) == entry_index:
				return train
		elif destination == "" or train.entry.destination == destination:
			return train
	return null


## Ein Zug aus [param origin], aus dem [param npc] noch nicht ausgestiegen ist.
func find_arriving_train(origin: String, npc: Npc) -> Train:
	for train in _station_trains():
		if train.entry.origin != origin or not train.doors_open() or train.dwell_phase == Train.Dwell.CLOSING:
			continue
		if npc and npc.has_used_train(train.train_id):
			continue
		return train
	return null


## Ist der Fahrplanzug [param entry_index] heute schon abgefahren (oder fällt aus)?
func has_departed(entry_index: int, now: float) -> bool:
	if dispatcher == null or dispatcher.timetable == null or entry_index >= dispatcher.timetable.entries.size():
		return true
	for train in _station_trains():
		if int(train.get_meta(&"entry_index", -1)) == entry_index:
			return false
	var entry := dispatcher.timetable.entries[entry_index]
	return _hours_between(entry.get_departure_hours(), now) > 0.25


## Sucht eine Tür für [param npc] (nahe [param near]; Vector3.INF = gleichmäßig verteilt).
## Rückgabe: {"platform": Stehpunkt am Bahnsteig, "inside": Punkt in der Tür, "floor_y": Wagenboden}.
func assign_door(train: Train, npc: Npc, near: Vector3) -> Dictionary:
	var points := train.get_door_points()
	var outward := train.get_platform_direction()
	if points.is_empty() or outward == Vector3.ZERO:
		return {}
	var best := {}
	var best_score := INF
	for point in points:
		var key := "%d:%d:%d" % [train.train_id, roundi(point.x * 2.0), roundi(point.z * 2.0)]
		var score := float(_door_use.get(key, 0)) * 6.0
		if near != Vector3.INF:
			score += RailGeometry.flat(point - near).length() * 0.2
		else:
			score += _rng.randf() * 3.0
		if score < best_score:
			best_score = score
			var flat_door := Vector3(point.x, 0.0, point.z)
			var platform := flat_door + outward * 0.65
			platform.y = ground_height(platform, point.y)
			var inside := flat_door - outward * 0.35
			inside.y = point.y
			best = {"key": key, "platform": platform, "inside": inside, "floor_y": point.y}
	_door_use[best["key"]] = int(_door_use.get(best["key"], 0)) + 1
	return best


func _station_trains() -> Array[Train]:
	var trains: Array[Train] = []
	if dispatcher == null:
		return trains
	for train in dispatcher.get_trains():
		if train.state == Train.State.DWELLING and train.entry and train.entry.station == station_name \
				and train.platform_stop and train.platform_stop.station_name == station_name:
			trains.append(train)
	return trains


## Neue Ankünfte: Reisende steigen aus, Wartende winken manchmal.
func _watch_trains() -> void:
	for train in _station_trains():
		if _arrivals_seen.has(train.train_id) or not train.doors_open():
			continue
		_arrivals_seen[train.train_id] = true
		for npc in _npcs:
			npc.react_to_arrival(train)
		var rng := RandomNumberGenerator.new()
		rng.seed = train.train_id * 131 + WorldClock.day * 17
		var count := rng.randi_range(travellers_per_train.x, travellers_per_train.y)
		for i in count:
			if get_travellers().size() >= max_travellers:
				break
			var visitor := spawn_traveller(rng)
			visitor.alight_from(train, true)


## Kurz vor einer Abfahrt kommen Reisende aus dem Dorf zum Bahnsteig.
func _spawn_departing_travellers(now: float) -> void:
	if dispatcher == null or dispatcher.timetable == null or not dispatcher.enabled:
		return
	var entries := dispatcher.timetable.entries
	for index in entries.size():
		var entry := entries[index]
		if entry == null or not entry.stops or entry.station != station_name:
			continue
		if _departures_spawned.get(index, -1) == WorldClock.day:
			continue
		var until_arrival := _hours_between(now, entry.get_arrival_hours())
		var walk_hours := walk_hours_to_platform()
		if until_arrival > walk_hours + 0.05:
			continue
		_departures_spawned[index] = WorldClock.day
		# Nicht mehr zu schaffen (z.B. nach einem Zeitsprung) – dann bleiben sie zu Hause.
		if _hours_between(now, entry.get_departure_hours()) < walk_hours * 0.8:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = index * 977 + WorldClock.day * 31
		var count := rng.randi_range(travellers_per_train.x, travellers_per_train.y)
		for i in count:
			if get_travellers().size() >= max_travellers:
				break
			var traveller := spawn_traveller(rng)
			var start := get_exit_point() + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			traveller.begin_trip(entry.destination, index, start)


## So lange (Spielstunden) braucht ein Reisender vom Dorfrand zum Bahnsteig.
func walk_hours_to_platform() -> float:
	var seconds := _walk_distance / (1.1 * speed_factor()) + 8.0
	return WorldClock.seconds_to_hours(seconds) * WorldClock.time_scale


## Setzt einen Reisenden ohne Steckbrief ein (Aussehen zufällig aus [param rng]).
func spawn_traveller(rng: RandomNumberGenerator) -> Npc:
	_traveller_count += 1
	var npc := Npc.new()
	add_child(npc)
	npc.setup(self, null, random_appearance(rng), 1000 + _traveller_count)
	_relay_signals(npc)
	_travellers.append(npc)
	return npc


func _relay_signals(npc: Npc) -> void:
	npc.boarded.connect(func(who: Npc, train: Train) -> void: passenger_boarded.emit(who, train))
	npc.alighted.connect(func(who: Npc, train: Train) -> void: passenger_alighted.emit(who, train))


## Zufälliges, aber stimmiges Aussehen für Reisende (warme Winterpalette).
static func random_appearance(rng: RandomNumberGenerator) -> CharacterAppearance:
	var look := CharacterAppearance.new()
	var skins := [Color(0.97, 0.82, 0.72), Color(0.93, 0.76, 0.63), Color(0.86, 0.65, 0.5),
		Color(0.72, 0.5, 0.36), Color(0.56, 0.38, 0.28), Color(0.4, 0.27, 0.2)]
	var warm := [Color(0.72, 0.3, 0.2), Color(0.82, 0.62, 0.3), Color(0.3, 0.44, 0.36), Color(0.72, 0.42, 0.42),
		Color(0.66, 0.5, 0.33), Color(0.92, 0.85, 0.72), Color(0.28, 0.34, 0.5), Color(0.55, 0.36, 0.5)]
	var hair := [Color(0.16, 0.11, 0.08), Color(0.36, 0.22, 0.13), Color(0.58, 0.27, 0.16),
		Color(0.86, 0.68, 0.4), Color(0.72, 0.7, 0.73)]
	look.skin_color = skins[rng.randi() % skins.size()]
	look.top_style = rng.randi_range(0, 2) as CharacterAppearance.TopStyle
	look.shirt_color = warm[rng.randi() % warm.size()]
	look.shirt_stripe_color = Color(0.1, 0.08, 0.09)
	look.accent_color = Color(0.92, 0.86, 0.72)
	look.pants_color = [Color(0.22, 0.24, 0.3), Color(0.32, 0.27, 0.24), Color(0.28, 0.34, 0.48)][rng.randi() % 3]
	look.shoe_color = Color(0.26, 0.18, 0.13)
	look.hat_style = rng.randi_range(0, 3) as CharacterAppearance.HatStyle
	look.hat_color = warm[rng.randi() % warm.size()]
	look.hair_style = rng.randi_range(1, 6) as CharacterAppearance.HairStyle
	look.hair_color = hair[rng.randi() % hair.size()]
	look.glasses = rng.randf() < 0.25
	look.beard = rng.randf() < 0.15
	look.scarf = rng.randf() < 0.8
	look.scarf_color = warm[rng.randi() % warm.size()]
	look.height_scale = rng.randf_range(0.94, 1.06)
	look.width_scale = rng.randf_range(0.95, 1.12)
	return look


# --- Plätze, Wege, Häuser --------------------------------------------------------------

## Reserviert einen freien Platz der gewünschten Art (zufällig gewählt).
func claim_spot(npc: Npc, kinds: Array, rng: RandomNumberGenerator) -> StationSpot:
	var free: Array[StationSpot] = []
	for spot in _spots:
		if is_instance_valid(spot) and spot.is_free() and spot.kind in kinds:
			free.append(spot)
	if free.is_empty():
		return null
	var spot := free[rng.randi() % free.size()]
	spot.reserve(npc)
	return spot


func get_spots() -> Array[StationSpot]:
	return _spots


func random_platform_point(rng: RandomNumberGenerator) -> Vector3:
	if _platform_points.is_empty():
		return get_exit_point()
	var point := _platform_points[rng.randi() % _platform_points.size()]
	return point + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-1.5, 1.5))


func get_home(home_name: String) -> NpcHome:
	var home: NpcHome = _homes.get(home_name)
	return home if is_instance_valid(home) else null


func get_exit_point() -> Vector3:
	if walk_graph and walk_graph.has_point(exit_point):
		return walk_graph.get_point(exit_point)
	return Vector3(-40.0, 0.0, 14.0)


## Bodenhöhe unter [param point]: Gelände, Bahnsteig oder Holzübergang.
## Gesucht wird knapp über [param reference_y], damit Dächer nicht zählen.
func ground_height(point: Vector3, reference_y: float) -> float:
	var base := terrain.get_height(point.x, point.z) if terrain else 0.0
	var from := Vector3(point.x, maxf(reference_y, base) + 1.2, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(point.x, base - 1.0, point.z),
		GameDefs.LAYER_WORLD | GameDefs.LAYER_OBJECTS)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else base


## Steht die Spielfigur (oder ein stehender Bewohner) direkt im Weg?
func is_path_blocked(npc: Npc, direction: Vector3, space: float) -> bool:
	if player and player.visible and player.is_inside_tree():
		var to_player := RailGeometry.flat(player.global_position - npc.global_position)
		if to_player.length() < space and to_player.normalized().dot(direction) > 0.55:
			return true
	return false


## Namensschild über dem Kopf: nur zu Fuß und nur in der Nähe.
func get_name_tag_alpha(npc: Npc) -> float:
	if not _exploring or player == null:
		return 0.0
	var distance := npc.global_position.distance_to(player.global_position)
	return 1.0 - smoothstep(name_tag_distance * 0.6, name_tag_distance, distance)


## Im Zeitraffer gehen alle etwas schneller (höchstens dreifach – sonst wirkt es hektisch).
func speed_factor() -> float:
	return clampf(WorldClock.time_scale, 1.0, 3.0)


func _load_profiles() -> void:
	if profiles_dir == "":
		return
	var dir := DirAccess.open(profiles_dir)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file in files:
		var path := profiles_dir.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var profile := load(path) as NpcProfile
		if profile and not profiles.has(profile):
			profiles.append(profile)


func _hours_between(from: float, to: float) -> float:
	return fposmod(to - from + 12.0, 24.0) - 12.0


func _exit_tree() -> void:
	CharacterModel.clear_cache()
