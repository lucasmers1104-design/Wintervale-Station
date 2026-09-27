## Fahrdienstleiter: setzt Züge nach Fahrplan ein und lenkt sie.
##
## - Prüft laufend den [Timetable] und lässt Züge rechtzeitig aus ihrem
##   Herkunftsportal einfahren (Fahrzeit wird geschätzt).
## - Plant den Weg Portal → Bahnsteig → Zielportal ([RailPathfinder]).
## - Ist das geplante Gleis belegt, wird automatisch ein freies gewählt.
## - Liefert die Daten für Anzeigetafeln (Abfahrt, Ziel, Gleis, Verspätung).
## - Simuliert alle Züge mit der Spielzeit (Zeitraffer beschleunigt auch die Züge).
class_name TrainDispatcher
extends Node

signal trains_changed

const SAVE_ID := "train_dispatcher"
const BOARD_GROUP := &"departure_board"
## Größter Simulationsschritt (Sekunden) – bei Zeitraffer wird unterteilt.
const MAX_STEP := 0.05
## Wäre ein Zug mehr als so viele Stunden zu spät, fällt er für heute aus.
const MAX_LATE_HOURS := 0.5

@export var network: RailNetwork
@export var interlocking: RailInterlocking
@export var timetable: Timetable
@export var enabled := true
@export_group("Materialien")
@export var paint_material: Material
@export var glass_material: StandardMaterial3D
## Leuchtstärke der Fenster bei Nacht (warmes Licht von innen).
@export var window_glow := 1.2
## Auch tagsüber brennt drinnen ein wenig Licht – die Fenster wirken warm statt grau.
@export var day_window_glow := 0.07

var _trains: Array[Train] = []
var _next_id := 1
var _served_day: Dictionary[int, int] = {}
var _travel_hours: Dictionary[int, float] = {}
var _materials := {}
var _schedule_timer := 0.0
var _dark := false
var _glow_tween: Tween


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_materials = {
		"paint": paint_material,
		"glass": glass_material,
		"lamp_white": _lamp_material(Color(1.0, 0.92, 0.75), 6.0),
		"lamp_red": _lamp_material(Color(1.0, 0.12, 0.08), 4.0),
		"snow": _snow_material(),
	}
	WorldClock.darkness_changed.connect(_on_darkness_changed)
	_on_darkness_changed(WorldClock.is_dark())
	network.topology_changed.connect(func() -> void: _travel_hours.clear())


func _exit_tree() -> void:
	TrainMeshes.clear_cache()
	SoundLibrary.clear_cache()


func _physics_process(delta: float) -> void:
	if not enabled or WorldClock.paused:
		return
	var sim_time := delta * WorldClock.time_scale
	var steps := clampi(ceili(sim_time / MAX_STEP), 1, 40)
	var dt := sim_time / steps
	for i in steps:
		for train in _trains.duplicate():
			train.simulate(dt)
	_schedule_timer -= delta
	if _schedule_timer <= 0.0:
		_schedule_timer = 0.5
		check_timetable()


func _process(delta: float) -> void:
	for train in _trains:
		train.update_visuals(delta)


func get_trains() -> Array[Train]:
	return _trains


# --- Fahrplan -------------------------------------------------------------------------

## Setzt fällige Züge ein. Wird regelmäßig aufgerufen.
func check_timetable() -> void:
	if timetable == null:
		return
	for i in timetable.entries.size():
		var entry := timetable.entries[i]
		if entry == null or entry.train_type == null:
			continue
		if _served_day.get(i, -1) == WorldClock.day or _train_for_entry(i):
			continue
		var late := _hours_since(get_spawn_hours(i))
		if late < 0.0:
			continue
		if late > MAX_LATE_HOURS:
			_served_day[i] = WorldClock.day  # heute verpasst
			continue
		if spawn_train(i):
			_served_day[i] = WorldClock.day


## Einsetzzeit: Ankunft minus geschätzte Fahrzeit vom Portal zum Bahnsteig.
func get_spawn_hours(index: int) -> float:
	return timetable.entries[index].get_arrival_hours() - _estimate_travel_hours(index)


## Setzt den Zug zur Fahrplanzeile [param index] ein (sofern die Einfahrt frei ist).
func spawn_train(index: int) -> Train:
	var entry := timetable.entries[index]
	var plan := _plan(entry, entry.platform)
	if plan.is_empty():
		return null
	var first := network.get_segment(plan["ids"][0])
	if interlocking.is_block_occupied(first.block_id) or interlocking.is_block_reserved(first.block_id):
		return null
	# Nie mehr Züge Richtung Bahnhof schicken, als es Bahnsteiggleise gibt –
	# sonst könnten sich Züge auf der eingleisigen Strecke gegenseitig blockieren.
	if _trains_before_station(entry.station) >= get_platform_stops(entry.station).size():
		return null
	var ids: Array[int] = []
	ids.assign(plan["ids"])
	var forwards: Array[bool] = []
	forwards.assign(plan["forwards"])
	var train := Train.new()
	add_child(train)
	train.setup(_next_id, entry, TrainPath.new(network, ids, forwards), self, network, interlocking, _materials)
	train.set_meta(&"entry_index", index)
	_next_id += 1
	_apply_plan(train, plan)
	train.set_dark(_dark)
	train.update_occupancy()  # sofort melden, damit kein anderer Zug einen Fahrweg hierher bekommt
	train.update_visuals(0.0)
	_trains.append(train)
	trains_changed.emit()
	return train


## Zug entfernen (angekommen im Zieltunnel oder Strecke unterbrochen).
func retire(train: Train, reason: String) -> void:
	if train.state == Train.State.DONE:
		return
	train.state = Train.State.DONE
	interlocking.clear_train_occupancy(train.train_id)
	_trains.erase(train)
	train.queue_free()
	if reason != "":
		Events.notification_requested.emit("%s: %s" % [train.entry.train_number, reason])
	trains_changed.emit()


func clear_trains() -> void:
	for train in _trains.duplicate():
		retire(train, "")


# --- Wegplanung -----------------------------------------------------------------------

## Weg Portal → Bahnsteig → Zielportal. Rückgabe {"ids", "forwards", "stop", "platform"} oder {}.
func _plan(entry: TimetableEntry, platform: int) -> Dictionary:
	var origin := get_portal(entry.origin)
	var destination := get_portal(entry.destination)
	var stop := get_platform_stop(entry.station, platform)
	if origin == null or destination == null or stop == null:
		return {}
	var start := origin.get_end_segment(network)
	var start_node := origin.get_end_node(network)
	var goal := destination.get_end_segment(network)
	var goal_node := destination.get_end_node(network)
	var platform_segment := stop.get_segment(network)
	if start == null or goal == null or platform_segment == null:
		return {}
	var to_platform := RailPathfinder.find(network, start.id, start.start_node_id == start_node.id, platform_segment.id)
	if to_platform.is_empty():
		return {}
	var goal_forward := 1 if goal.end_node_id == goal_node.id else 0
	var to_goal := RailPathfinder.find(network, platform_segment.id, to_platform["forwards"][-1], goal.id, goal_forward)
	var joined := RailPathfinder.join(to_platform, to_goal)
	if joined.is_empty():
		return {}
	joined["stop"] = stop
	joined["platform"] = platform
	return joined


## Haltepunkt und Verschwinde-Punkt aus der Planung übernehmen.
func _apply_plan(train: Train, plan: Dictionary) -> void:
	var stop: PlatformStop = plan["stop"]
	var path := train.path
	var platform_segment := stop.get_segment(network)
	var index := path.segment_ids.find(platform_segment.id)
	if train.entry.stops:
		var center := path.distance_near(stop.global_position, platform_segment.id)
		var stop_distance := minf(center + train.length * 0.5, path.end_of(index) - Train.SIGNAL_STOP_MARGIN - 1.5)
		train.set_stop(stop_distance, stop, plan["platform"])
	else:
		train.platform_number = plan["platform"]
		train.platform_stop = stop
	var last := path.segment_ids.size() - 1
	train.set_despawn(minf(path.starts[last] + train.length + 1.5, path.total_length - 0.6))


## Automatische Gleiswahl: Ist das geplante Gleis belegt, wird ein freies gesucht.
func try_other_platform(train: Train) -> bool:
	if train.path == null or (train.entry.stops and train.stop_at < 0.0):
		return false
	if not train.entry.stops and train.head >= _platform_end_distance(train) - train.length:
		return false
	for stop in get_platform_stops(train.entry.station):
		if stop.platform_number == train.platform_number:
			continue
		var segment := stop.get_segment(network)
		if segment == null or interlocking.is_block_occupied(segment.block_id) \
				or interlocking.is_block_reserved(segment.block_id):
			continue
		var index := train.path.index_at(train.head)
		var here := train.path.segment_ids[index]
		var to_platform := RailPathfinder.find(network, here, train.path.forwards[index], segment.id)
		var destination := get_portal(train.entry.destination)
		if to_platform.is_empty() or destination == null:
			continue
		var goal := destination.get_end_segment(network)
		var goal_forward := 1 if goal.end_node_id == destination.get_end_node(network).id else 0
		var joined := RailPathfinder.join(to_platform,
			RailPathfinder.find(network, segment.id, to_platform["forwards"][-1], goal.id, goal_forward))
		if joined.is_empty():
			continue
		var ids: Array[int] = []
		ids.assign(joined["ids"])
		var forwards: Array[bool] = []
		forwards.assign(joined["forwards"])
		train.path.replace_from(index, ids, forwards)
		train.path_changed()
		_apply_plan(train, {"stop": stop, "platform": stop.platform_number})
		return true
	return false


## Fahrweg gewährt: Fährt der Zug damit in den Bahnsteig ein, ertönt der Gong.
func on_route_granted(train: Train, route_ids: Array[int]) -> void:
	if train.stop_at < 0.0 or train.platform_stop == null or train.has_meta(&"announced"):
		return
	var platform_segment := train.platform_stop.get_segment(network)
	if platform_segment and route_ids.has(platform_segment.id):
		train.set_meta(&"announced", true)
		get_tree().call_group(BOARD_GROUP, "announce", train)


# --- Bahnhöfe & Portale ----------------------------------------------------------------

func get_portal(portal_name: String) -> TrainPortal:
	for node in get_tree().get_nodes_in_group(TrainPortal.GROUP):
		if (node as TrainPortal).portal_name == portal_name:
			return node
	return null


func get_platform_stops(station: String) -> Array[PlatformStop]:
	var list: Array[PlatformStop] = []
	for node in get_tree().get_nodes_in_group(PlatformStop.GROUP):
		var stop := node as PlatformStop
		if stop.station_name == station:
			list.append(stop)
	list.sort_custom(func(a: PlatformStop, b: PlatformStop) -> bool: return a.platform_number < b.platform_number)
	return list


func get_platform_stop(station: String, platform: int) -> PlatformStop:
	for stop in get_platform_stops(station):
		if stop.platform_number == platform:
			return stop
	return null


# --- Anzeigetafel ----------------------------------------------------------------------

## Nächste Abfahrten eines Bahnhofs: [{"time","number","destination","platform","delay"}].
func get_departure_rows(station: String, count: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if timetable == null:
		return rows
	for i in timetable.entries.size():
		var entry := timetable.entries[i]
		if entry == null or entry.station != station or not entry.stops:
			continue
		var train := _train_for_entry(i)
		if train and train.departed_at >= 0.0:
			continue
		var ahead := fposmod(entry.get_departure_hours() - WorldClock.time_of_day + 3.0, 24.0) - 3.0
		if train == null and (ahead < -0.02 or _served_day.get(i, -1) == WorldClock.day):
			continue
		rows.append({
			"time": TimetableEntry.format_time(entry.get_departure_hours()),
			"number": entry.train_number,
			"destination": entry.destination,
			"platform": train.platform_number if train else entry.platform,
			"delay": _estimate_delay(entry, train),
			"sort": ahead,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["sort"] < b["sort"])
	return rows.slice(0, count)


## Voraussichtliche Verspätung in Minuten.
func _estimate_delay(entry: TimetableEntry, train: Train) -> int:
	var departure := entry.get_departure_hours()
	var dwell := WorldClock.seconds_to_hours(entry.train_type.min_dwell_seconds + Train.DOOR_TIME * 2.0)
	var expected := departure
	if train and train.state == Train.State.DWELLING:
		expected = maxf(departure, train.arrived_at + dwell)
	elif train and train.stop_at >= 0.0:
		var seconds := (train.stop_at - train.head) / maxf(train.max_speed * 0.6, 1.0) + 8.0
		expected = maxf(departure, WorldClock.time_of_day + WorldClock.seconds_to_hours(seconds) + dwell)
	var late := fposmod(expected - departure + 12.0, 24.0) - 12.0
	return maxi(0, roundi(late * 60.0))


# --- Intern ------------------------------------------------------------------------

## Züge, die den Bahnhof noch nicht wieder verlassen haben (fahren hin oder halten dort).
func _trains_before_station(station: String) -> int:
	var count := 0
	for train in _trains:
		if train.entry.station != station:
			continue
		if train.entry.stops:
			if train.departed_at < 0.0:
				count += 1
		elif train.head < _platform_end_distance(train):
			count += 1
	return count


## Strecke, an der ein durchfahrender Zug das Bahnsteiggleis hinter sich hat.
func _platform_end_distance(train: Train) -> float:
	for stop in get_platform_stops(train.entry.station):
		var segment := stop.get_segment(network)
		var index := train.path.segment_ids.find(segment.id) if segment else -1
		if index >= 0:
			return train.path.end_of(index) + train.length
	return 0.0


func _train_for_entry(index: int) -> Train:
	for train in _trains:
		if int(train.get_meta(&"entry_index", -1)) == index:
			return train
	return null


## Geschätzte Fahrzeit vom Portal bis zum Bahnsteig (Spielstunden, zwischengespeichert).
func _estimate_travel_hours(index: int) -> float:
	if _travel_hours.has(index):
		return _travel_hours[index]
	var entry := timetable.entries[index]
	var plan := _plan(entry, entry.platform)
	var hours := 0.1
	if not plan.is_empty():
		var ids: Array[int] = []
		ids.assign(plan["ids"])
		var forwards: Array[bool] = []
		forwards.assign(plan["forwards"])
		var path := TrainPath.new(network, ids, forwards)
		var stop: PlatformStop = plan["stop"]
		var distance := path.distance_near(stop.global_position, stop.get_segment(network).id)
		var seconds := distance / maxf(entry.get_max_speed() * 0.6, 1.0) + 14.0
		hours = WorldClock.seconds_to_hours(seconds)
	_travel_hours[index] = hours
	return hours


## Wie viele Stunden [param hours] schon vorbei ist (negativ = liegt noch vor uns).
func _hours_since(hours: float) -> float:
	return fposmod(WorldClock.time_of_day - hours + 12.0, 24.0) - 12.0


func _on_darkness_changed(dark: bool) -> void:
	_dark = dark
	for train in _trains:
		train.set_dark(dark)
	if glass_material and is_inside_tree():
		if _glow_tween and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween()
		_glow_tween.tween_property(glass_material, "emission_energy_multiplier", window_glow if dark else day_window_glow, 3.0)


func _lamp_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _snow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.95, 0.97, 1.0, 0.7)
	material.vertex_color_use_as_albedo = true
	return material


# --- Speichern ----------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


## Züge selbst werden nicht gespeichert – nur, welche Fahrplanzeilen heute schon gefahren sind.
func save_state() -> Dictionary:
	var served := {}
	for index: int in _served_day:
		served[str(index)] = _served_day[index]
	for train in _trains:
		served[str(train.get_meta(&"entry_index", -1))] = WorldClock.day
	return {"served": served}


func load_state(data: Dictionary) -> void:
	clear_trains()
	_served_day.clear()
	var served: Dictionary = data.get("served", {})
	for key: Variant in served:
		_served_day[int(key)] = int(served[key])
	_travel_hours.clear()
