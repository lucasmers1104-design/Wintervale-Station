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
@export var auto_load_profiles := true
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
var _homes: Dictionary = {}
## Bewohner gebauter Häuser (erfunden, nicht aus assets/npcs).
var _generated: Dictionary = {}
var _set_up := false
var _spots: Array[StationSpot] = []
var _platform_points: Array[Vector3] = []
var _arrivals_seen: Dictionary[int, bool] = {}
var _departures_spawned: Dictionary[int, int] = {}
var _queues: Dictionary[int, Array] = {}
var _queue_trains: Dictionary[int, Train] = {}
var _greeted: Dictionary[String, float] = {}
var _social_timer := 1.0
## Reihenfolge der Stufengänge je Tür: [Zug, Tür, "out" | "in"] (für Tests).
var _door_log: Array = []
var _last_hours := -1.0
var _schedule_timer := 0.0
var _traveller_count := 0
## Weglänge vom Dorfrand zum Bahnsteig (Meter).
var _walk_distance := 55.0
var _exploring := false
var _rng := RandomNumberGenerator.new()
var access_route: Callable
var access_height: Callable

func find_walk_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if access_route.is_valid():
		return access_route.call(from,to)
	return walk_graph.find_path(from,to) if walk_graph else PackedVector3Array([from,to])


func _ready() -> void:
	_rng.seed = 4711
	Events.view_mode_changed.connect(func(mode: GameDefs.ViewMode) -> void:
		_exploring = mode == GameDefs.ViewMode.EXPLORE)
	Events.game_loaded.connect(func(_slot: String) -> void: resume_all())
	if auto_load_profiles:
		_load_profiles()
	# Erst wenn Gleise, Häuser und Bahnsteig stehen
	_setup.call_deferred()


func _setup() -> void:
	# Ein Haltepunkt kann im selben Frame wieder abgerissen werden (Undo/Redo).
	if not is_inside_tree():
		return
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
		_create_npc(profiles[i], i * 7 + 3 if not _generated.has(profiles[i]) else hash(profiles[i].display_name))
	_set_up = true
	resume_all()


## Alle Bewohner passend zur Uhrzeit aufstellen; Reisende verschwinden.
func resume_all() -> void:
	# Loading replaces stations before game_loaded is emitted. Their detached
	# directors still receive the signal until queued deletion is flushed.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	for traveller in _travellers:
		if is_instance_valid(traveller):
			traveller.queue_free()
	_travellers.clear()
	for train_id in _queues.keys():
		_close_queues(train_id, _queue_trains.get(train_id))
	_arrivals_seen.clear()
	for npc in _npcs:
		if is_instance_valid(npc) and npc.is_inside_tree() and not npc.is_queued_for_deletion():
			npc.resume(WorldClock.time_of_day)
	_last_hours = WorldClock.time_of_day


func get_npcs() -> Array[Npc]:
	return _npcs


func get_travellers() -> Array[Npc]:
	_travellers.assign(_travellers.filter(func(npc: Variant) -> bool:
		return is_instance_valid(npc) and not (npc as Npc).is_queued_for_deletion()))
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
	_update_doors(delta)
	_schedule_timer -= delta
	if _schedule_timer <= 0.0:
		_schedule_timer = 0.5
		_watch_trains()
		_spawn_departing_travellers(now)
	_social_timer -= delta
	if _social_timer <= 0.0:
		_social_timer = 1.0
		_update_social()


# --- Begegnungen ----------------------------------------------------------------------

## Bewohner, die sich begegnen, grüßen sich kurz (höchstens einmal pro Spielstunde).
## Wer zusammensteht, nickt und erzählt ab und zu.
func _update_social() -> void:
	var present: Array[Npc] = []
	for npc in _npcs:
		if npc.is_present() and not npc.is_busy():
			present.append(npc)
	for i in present.size():
		for j in range(i + 1, present.size()):
			var a := present[i]
			var b := present[j]
			var distance := a.global_position.distance_to(b.global_position)
			if distance > 3.0 or distance < 0.3:
				continue
			var key := a.name + "|" + b.name
			if _hours_between(float(_greeted.get(key, -99.0)), WorldClock.time_of_day) < 1.0 \
					and _greeted.has(key):
				continue
			_greeted[key] = WorldClock.time_of_day
			a.greet(b)
			b.greet(a)
			# Ein kurzer Plausch in Bildern: Wetter, Jahreszeit, Züge, Herzliches
			if _rng.randf() < 0.4:
				a.show_icon(small_talk_icon(_rng))
				# Gebundene Methode statt Lambda: wird getrennt, falls b vorher verschwindet
				get_tree().create_timer(1.4, false).timeout.connect(b.show_icon.bind(small_talk_icon(_rng)))
	for npc in present:
		if npc.get_behaviour() == "chat" and npc.get_spot() and npc.get_spot().partner \
				and npc.get_spot().partner.occupant is Npc and _rng.randf() < 0.3:
			npc.chat_gesture()
			if _rng.randf() < 0.18:
				npc.show_icon(small_talk_icon(_rng))


## Worüber man gerade plaudert (Bildblase): Wetter, Jahreszeit, Züge, Nettes.
func small_talk_icon(rng: RandomNumberGenerator) -> String:
	var options: Array[String] = ["heart", "train", "clock", "star"]
	match Seasons.get_season():
		Seasons.Season.WINTER:
			options.append_array(["snowflake", "snowflake", "cup", "gift"])
		Seasons.Season.AUTUMN:
			options.append_array(["leaf", "leaf", "cup"])
		_:
			options.append_array(["sun", "sun", "note"])
	var festival := FestivalDirector.find(get_tree())
	if festival and festival.is_active():
		options.append_array(["tree", "note"] if festival.get_active_id() == FestivalDirector.CHRISTMAS else ["lantern", "note"])
	return options[rng.randi() % options.size()]


## Gesprächsplatz: am liebsten gegenüber von jemandem, der dort schon steht.
func claim_chat_spot(npc: Npc, rng: RandomNumberGenerator) -> StationSpot:
	var waiting: Array[StationSpot] = []
	var free_pairs: Array[StationSpot] = []
	for spot in _spots:
		if spot.kind != StationSpot.Kind.CHAT or not spot.is_free() or spot.partner == null:
			continue
		if not spot.partner.is_free():
			waiting.append(spot)
		elif spot.partner.is_free():
			free_pairs.append(spot)
	var pool := waiting if not waiting.is_empty() else free_pairs
	if pool.is_empty():
		return null
	var spot := pool[rng.randi() % pool.size()]
	spot.reserve(npc)
	return spot


## Jemand ist am Gesprächsplatz angekommen – wer gegenüber steht, grüßt.
func on_chat_spot_taken(npc: Npc, spot: StationSpot) -> void:
	var partner := spot.partner.occupant as Npc if spot.partner else null
	if partner and is_instance_valid(partner):
		npc.greet(partner)
		partner.greet(npc)


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


## Ein Zug nach [param destination], der gerade auf den Bahnhof zufährt (letzte ~300 m).
func find_incoming_train(destination: String, entry_index := -1) -> Train:
	if dispatcher == null:
		return null
	for train in dispatcher.get_trains():
		if train.state != Train.State.RUNNING or train.stop_at < 0.0 or train.platform_stop == null \
				or train.platform_stop.station_name != station_name or not train.entry.stops:
			continue
		if train.stop_at - train.head > 300.0:
			continue
		if entry_index >= 0:
			if int(train.get_meta(&"entry_index", -1)) == entry_index:
				return train
		elif train.entry.destination == destination:
			return train
	return null


## Freier Stehplatz an der Bahnsteigkante des Gleises, auf dem [param train] halten wird –
## möglichst nahe der Zugmitte.
func claim_spot_near_stop(npc: Npc, train: Train) -> StationSpot:
	var stop := train.platform_stop
	var toward_track := -stop.get_platform_direction()
	var best: StationSpot = null
	var best_distance := INF
	for spot in _spots:
		if spot.kind != StationSpot.Kind.STAND or not (spot.is_free() or spot.occupant == npc):
			continue
		if spot.get_facing().dot(toward_track) < 0.5:
			continue
		var distance := RailGeometry.flat(spot.global_position - stop.global_position).length() \
			+ _rng.randf() * 4.0
		if distance < best_distance:
			best_distance = distance
			best = spot
	if best:
		best.reserve(npc)
	return best


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
	# Verspätete Züge (Schnee, Nebel) kommen später – so lange wird gewartet
	return _hours_between(entry.get_departure_hours() + dispatcher.get_delay(entry), now) > 0.25


# --- Türen und Warteschlangen --------------------------------------------------------
#
# Pro haltendem Zug und Tür eine Warteschlange:
#   "alight": wer aussteigen will (noch im Zug, unsichtbar)
#   "board":  wer einsteigen will (steht links/rechts neben der Tür an)
#   "busy":   wer gerade auf den Trittstufen ist
# Regeln: erst alle aussteigen lassen, dann einsteigen – immer nur einer pro Tür.
# Solange sich an einer Tür etwas tut, hält der Director die Türen offen.

## Steigt aus [param train] aus: in die Aussteige-Schlange der ruhigsten Tür.
func request_alight(npc: Npc, train: Train) -> bool:
	var doors := _doors_for(train)
	if doors.is_empty():
		return false
	var best: Dictionary = doors[0]
	for door: Dictionary in doors:
		if (door["alight"] as Array).size() < (best["alight"] as Array).size() \
				or ((door["alight"] as Array).size() == (best["alight"] as Array).size() and _rng.randf() < 0.4):
			best = door
	(best["alight"] as Array).append(npc)
	return true


## Stellt [param npc] zum Einsteigen an einer Tür an (nächste und kürzeste Schlange).
## Rückgabe: {"slot": Wartepunkt, "door": Punkt vor der Tür} oder leer.
func join_boarding(npc: Npc, train: Train) -> Dictionary:
	if not train.doors_open() or train.dwell_phase == Train.Dwell.CLOSING:
		return {}
	var doors := _doors_for(train)
	if doors.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score := INF
	for door: Dictionary in doors:
		var platform: Vector3 = door["platform"]
		var score := RailGeometry.flat(platform - npc.global_position).length() * 0.15 \
			+ (door["board"] as Array).size() * 2.5 + (door["alight"] as Array).size() * 1.0
		if score < best_score:
			best_score = score
			best = door
	(best["board"] as Array).append(npc)
	var index := (best["board"] as Array).size() - 1
	return {"slot": queue_slot(best, index), "door": best["platform"]}


## Wartepunkt Nummer [param index] an einer Tür: abwechselnd links und rechts
## neben der Tür, damit die Mitte für Aussteigende frei bleibt.
func queue_slot(door: Dictionary, index: int) -> Vector3:
	var along: Vector3 = door["along"]
	var side := 1.0 if index % 2 == 0 else -1.0
	var distance := 0.8 + 0.55 * floorf(index / 2.0)
	var point: Vector3 = door["platform"] + along * side * distance
	point.y = ground_height(point, (door["platform"] as Vector3).y)
	return point


## Jemand hat die Trittstufen verlassen – die Tür ist wieder frei.
func door_done(npc: Npc) -> void:
	for train_id in _queues:
		for door: Dictionary in _queues[train_id]:
			if door["busy"] == npc:
				door["busy"] = null
				door["cooldown"] = 0.35


## Aus allen Warteschlangen austragen (Abbruch, Heimweg …).
func leave_queues(npc: Npc) -> void:
	for train_id in _queues:
		for door: Dictionary in _queues[train_id]:
			(door["alight"] as Array).erase(npc)
			(door["board"] as Array).erase(npc)
			if door["busy"] == npc:
				door["busy"] = null


## Wie viele warten an [param train] noch aufs Ein- bzw. Aussteigen (für Tests).
func get_queue_counts(train: Train) -> Vector2i:
	var counts := Vector2i.ZERO
	for door: Dictionary in _queues.get(train.train_id, []):
		counts.x += (door["alight"] as Array).size()
		counts.y += (door["board"] as Array).size()
	return counts


func _doors_for(train: Train) -> Array:
	if not _queues.has(train.train_id):
		var doors := []
		for path in train.get_door_paths():
			var platform: Vector3 = path["platform"]
			platform.y = ground_height(platform, platform.y)
			doors.append({
				"inside": path["inside"], "door": path["door"],
				"upper_top": path["upper"], "lower_top": path["lower"],
				"platform": platform, "along": path["along"],
				"alight": [], "board": [], "busy": null, "cooldown": 0.6,
			})
		if doors.is_empty():
			return []
		_queues[train.train_id] = doors
		_queue_trains[train.train_id] = train
	return _queues[train.train_id]


## Jeden Frame: Türen abarbeiten, Türen aufhalten, abgefahrene Züge aufräumen.
func _update_doors(delta: float) -> void:
	for train_id in _queues.keys():
		var train: Train = _queue_trains.get(train_id)
		var doors: Array = _queues[train_id]
		var gone := train == null or not is_instance_valid(train) or train.state != Train.State.DWELLING
		if gone or train.dwell_phase == Train.Dwell.CLOSING or train.dwell_phase == Train.Dwell.STEP_IN:
			_close_queues(train_id, train if not gone else null)
			continue
		if not train.doors_open():
			continue
		var active := false
		for door_index in doors.size():
			var door: Dictionary = doors[door_index]
			door["cooldown"] = float(door["cooldown"]) - delta * speed_factor()
			var alight: Array = door["alight"]
			var board: Array = door["board"]
			if door["busy"] != null or not alight.is_empty() or not board.is_empty():
				active = true
			if door["busy"] != null and not is_instance_valid(door["busy"]):
				door["busy"] = null
			if door["busy"] != null or float(door["cooldown"]) > 0.0:
				continue
			if not alight.is_empty():
				var npc: Npc = alight.pop_front()
				if is_instance_valid(npc):
					door["busy"] = npc
					npc.climb_out(door)
					_door_log.append([train_id, door_index, "out"])
			elif not board.is_empty():
				var first: Npc = board[0]
				if not is_instance_valid(first):
					board.pop_front()
				elif first.is_waiting_in_queue():
					board.pop_front()
					door["busy"] = first
					first.climb_in(door)
					_door_log.append([train_id, door_index, "in"])
					for i in board.size():
						(board[i] as Npc).move_to_queue_slot(queue_slot(door, i), door["platform"])
		if active:
			train.hold_doors(_hold_id(train))
		else:
			train.release_doors(_hold_id(train))


## Der Zug schließt die Türen: Wer noch wartet, muss auf den nächsten Zug warten.
func _close_queues(train_id: int, train: Train) -> void:
	for door: Dictionary in _queues[train_id]:
		for npc in (door["board"] as Array).duplicate():
			if is_instance_valid(npc):
				(npc as Npc).boarding_aborted()
		for npc in (door["alight"] as Array).duplicate():
			if is_instance_valid(npc):
				(npc as Npc).alight_cancelled()
	if train and is_instance_valid(train):
		train.release_doors(_hold_id(train))
	_queues.erase(train_id)
	_queue_trains.erase(train_id)


func _hold_id(train: Train) -> int:
	return -1000 - train.train_id


## Nach dem Aussteigen ein paar Schritte auf den Bahnsteig – jeder etwas woanders hin.
func spread_point(from: Vector3, along: Vector3, rng: RandomNumberGenerator) -> Vector3:
	for attempt in 6:
		var inward := along.cross(Vector3.UP).normalized()
		var candidate := from + along * rng.randf_range(-3.0, 3.0) + inward * rng.randf_range(-0.6, 0.6)
		if absf(ground_height(candidate, from.y) - from.y) < 0.12:
			return candidate
	return from


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
			if regular_traveller_count() >= max_travellers:
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
			if regular_traveller_count() >= max_travellers:
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
	# Reisende haben meist Gepäck dabei: Koffer, Rucksack oder Einkaufstasche
	var roll := rng.randf()
	var carry := CharacterModel.Carry.SUITCASE if roll < 0.45 else (CharacterModel.Carry.BACKPACK if roll < 0.7
		else (CharacterModel.Carry.SHOPPING_BAG if roll < 0.85 else CharacterModel.Carry.NONE))
	npc.setup(self, null, random_appearance(rng), 1000 + _traveller_count, carry)
	_relay_signals(npc)
	_travellers.append(npc)
	return npc


## Reisende ohne Festgäste (die Gäste der Feste zählen nicht zur Obergrenze).
func regular_traveller_count() -> int:
	var count := 0
	for npc in _travellers:
		if is_instance_valid(npc) and not npc.has_meta(&"festival_guest"):
			count += 1
	return count


func _relay_signals(npc: Npc) -> void:
	npc.boarded.connect(func(who: Npc, train: Train) -> void: passenger_boarded.emit(who, train))
	npc.alighted.connect(func(who: Npc, train: Train) -> void: passenger_alighted.emit(who, train))


## Aussehen für Reisende: eine der freigegebenen Figuren (CharacterDesigns).
static func random_appearance(rng: RandomNumberGenerator) -> CharacterAppearance:
	return CharacterDesigns.random(rng)


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
	var cached = _homes.get(home_name)
	if is_instance_valid(cached) and not (cached as NpcHome).is_queued_for_deletion() \
			and (cached as NpcHome).home_name == home_name:
		return cached as NpcHome
	# Häuser können gebaut und abgerissen werden: im Zweifel neu suchen
	_homes.erase(home_name)
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(NpcHome.GROUP):
		var candidate := node as NpcHome
		if candidate.home_name == home_name and not candidate.is_queued_for_deletion():
			_homes[home_name] = candidate
			return candidate
	return null


# --- Bewohner der Dorfhäuser ------------------------------------------------------------

## Gibt es für diese Familie Steckbriefe (z.B. Berger aus assets/npcs)?
func has_family(home_name: String) -> bool:
	for profile in profiles:
		if profile.home_name == home_name and not _generated.has(profile):
			return true
	return false


## Familiennamen aller bekannten Bewohner.
func get_family_names() -> Array[String]:
	var names: Array[String] = []
	for profile in profiles:
		if not names.has(profile.home_name):
			names.append(profile.home_name)
	return names


## Bekannte Familien, deren Haus es gerade nicht gibt – sie ziehen gern in ein neues Haus.
func get_homeless_families() -> Array[String]:
	var homeless: Array[String] = []
	for profile in profiles:
		if not _generated.has(profile) and not homeless.has(profile.home_name) and get_home(profile.home_name) == null:
			homeless.append(profile.home_name)
	return homeless


## Neuer Bewohner eines gebauten Hauses. Vor dem Start wird er vorgemerkt.
## Mit [param arriving_from] (Tunnelportal) kommt er gerade mit dem Zug an –
## keine zufälligen Spawnpunkte: Er steigt aus dem nächsten Zug von dort aus.
func add_resident(profile: NpcProfile, arriving_from := "") -> Npc:
	profiles.append(profile)
	_generated[profile] = true
	if not _set_up:
		return null
	var npc := _create_npc(profile, hash(profile.display_name))
	if arriving_from != "":
		npc.arrive_by_train(arriving_from)
	return npc


## Freier Sitzplatz im Dorf (Dorfplatz, Bänke) möglichst nahe [param near].
func claim_stroll_spot(npc: Npc, near: Vector3) -> StationSpot:
	var best: StationSpot = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(StationSpot.GROUP):
		var spot := node as StationSpot
		if spot.station_name == station_name or spot.kind != StationSpot.Kind.SEAT or not spot.is_free():
			continue
		var d := spot.global_position.distance_to(near) if near != Vector3.INF else 0.0
		if d < best_distance:
			best_distance = d
			best = spot
	if best and best_distance < 60.0:
		best.reserve(npc)
		return best
	return null


## Bewohner zieht aus (sein Haus wurde abgerissen).
func remove_resident(profile: NpcProfile) -> void:
	profiles.erase(profile)
	_generated.erase(profile)
	for npc in _npcs.duplicate():
		if npc.profile == profile:
			_npcs.erase(npc)
			leave_queues(npc)
			npc.queue_free()


func _create_npc(profile: NpcProfile, seed_value: int) -> Npc:
	var npc := Npc.new()
	add_child(npc)
	npc.setup(self, profile, profile.appearance, seed_value)
	_npcs.append(npc)
	_relay_signals(npc)
	if _set_up:
		npc.resume(WorldClock.time_of_day)
	return npc


func get_exit_point() -> Vector3:
	if walk_graph and walk_graph.has_point(exit_point):
		return walk_graph.get_point(exit_point)
	return Vector3(-40.0, 0.0, 14.0)


## Bodenhöhe unter [param point]: Gelände, Bahnsteig oder Holzübergang.
## Gesucht wird knapp über [param reference_y], damit Dächer nicht zählen.
func ground_height(point: Vector3, reference_y: float) -> float:
	if access_height.is_valid():
		var access_y: float = access_height.call(point)
		if not is_nan(access_y):
			return access_y
	var base := terrain.get_height(point.x, point.z) if terrain else 0.0
	# Ein abgerissener Haltepunkt (Undo, Laden) räumt seine Bewohner erst im
	# nächsten Frame ab – bis dahin gibt es keine Physikwelt mehr.
	if not is_inside_tree():
		return base
	var from := Vector3(point.x, maxf(reference_y, base) + 1.2, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(point.x, base - 1.0, point.z),
		GameDefs.LAYER_WORLD | GameDefs.LAYER_OBJECTS)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else base


## Steht die Spielfigur (oder ein stehender Bewohner) direkt im Weg?
func is_path_blocked(npc: Npc, direction: Vector3, space: float) -> bool:
	if player and player.visible and player.is_inside_tree() and absf(player.global_position.y-npc.global_position.y)<0.8:
		var to_player := RailGeometry.flat(player.global_position - npc.global_position)
		if to_player.length() < space and to_player.normalized().dot(direction) > 0.55:
			return true
	# Stehende Bewohner werden nicht durchlaufen, sondern umgangen (nur wer steht –
	# zwei Gehende blockieren sich so nie gegenseitig)
	var reach := minf(space * 0.75, npc.get_distance_to_waypoint())
	for other in _npcs:
		if _blocks(npc, other, direction, reach):
			return true
	for other in _travellers:
		if is_instance_valid(other) and _blocks(npc, other, direction, reach):
			return true
	return false


func _blocks(npc: Npc, other: Npc, direction: Vector3, reach: float) -> bool:
	if other == npc or not other.is_present() or other.is_moving() or other.is_seated() or other.is_busy() or absf(other.global_position.y-npc.global_position.y)>0.8:
		return false
	var to_other := RailGeometry.flat(other.global_position - npc.global_position)
	var distance := to_other.length()
	return distance > 0.05 and distance < reach and to_other.dot(direction) / distance > 0.8


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


## Alle bisherigen Stufengänge [Zug, Tür, "out" | "in"] – für Tests.
func get_door_log() -> Array:
	return _door_log
