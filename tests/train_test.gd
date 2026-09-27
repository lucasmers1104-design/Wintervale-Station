## Automatischer Test für Etappe 3: Startstrecke, Fahrplan, Zugmodelle,
## Klänge, Zugfahrten nach Fahrplan (Halt, Türen, Kreuzung), Gleiswahl,
## Signalbeachtung, Anzeigetafel, Speichern und Kamera-Mitfahrt.
##
## Während der Fahrten wird in JEDEM Frame geprüft:
## - kein Zug fährt an einem Signal ohne gewährten Fahrweg vorbei
## - nie zwei Züge auf demselben Gleis
## - keine Überschreitung der Höchstgeschwindigkeit, keine ruckartigen Sprünge
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/train_test.tscn
extends Node

var failures := 0
var main: Node3D
var network: RailNetwork
var interlocking: RailInterlocking
var dispatcher: TrainDispatcher
var starter: StarterRailway

# Laufende Überwachung
var violations := {"signal": 0, "overlap": 0, "overspeed": 0, "jerk": 0}
var _last_head := {}
var _last_speed := {}
var arrivals := {}
var departures := {}
var dwelled := {}
var max_door := {}
var retired := {}


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func _ready() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	network = main.get_node("World/Railway/RailNetwork")
	interlocking = main.get_node("World/Railway/RailInterlocking")
	dispatcher = main.get_node("World/Railway/TrainDispatcher")
	starter = main.get_node("World/Railway/StarterRailway")
	dispatcher.enabled = false
	for i in 5:
		await get_tree().physics_frame

	_test_layout()
	_test_timetable()
	_test_models()
	_test_sounds()
	await _test_scheduled_run()
	await _test_freight_passes()
	await _test_platform_choice()
	await _test_red_signal()
	await _test_save_and_camera()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Anlage -------------------------------------------------------------------------

func _test_layout() -> void:
	print("--- Layout")
	check(network.get_segment_count() == 12, "starter railway built (%d segments)" % network.get_segment_count())
	check(network.get_switches().size() == 2, "two switches")
	var signals := network.get_signals()
	check(signals.size() == 6, "six signals")
	var all_route := true
	for rail_signal in signals:
		all_route = all_route and rail_signal.mode == RailSignal.Mode.ROUTE
	check(all_route, "station signals wait for trains (ROUTE mode)")
	check(network.get_block_ids().size() == 6, "six blocks (%d)" % network.get_block_ids().size())
	var tunnels := 0
	var steepest := 0.0
	var tightest := INF
	for segment in network.get_segments():
		if segment.tunnel:
			tunnels += 1
		steepest = maxf(steepest, RailGeometry.max_grade(segment.curve))
		tightest = minf(tightest, RailGeometry.min_radius(segment.curve))
	check(tunnels == 2, "two tunnel segments")
	check(steepest <= RailConfig.MAX_GRADE * 1.15, "gentle grades (max %.3f)" % steepest)
	check(tightest >= RailConfig.MIN_RADIUS, "curves not tighter than %d m (min %.1f)" % [RailConfig.MIN_RADIUS, tightest])
	for portal_name in ["Nordtal", "Südtal"]:
		var portal := dispatcher.get_portal(portal_name)
		check(portal != null and portal.get_end_node(network) != null, "portal %s bound to track end" % portal_name)
	check(dispatcher.get_platform_stops("Wintervale").size() == 2, "two platform tracks")
	var nature: PropScatter = main.get_node("World/Nature")
	check(nature.get_cleared_count() > 0, "trees cleared along the line (%d)" % nature.get_cleared_count())


func _test_timetable() -> void:
	print("--- Timetable")
	var timetable := dispatcher.timetable
	check(timetable.entries.size() == 24, "24 timetable entries")
	var example: TimetableEntry = null
	for entry in timetable.entries:
		if entry.train_number == "RE 209":
			example = entry
	check(example != null and is_equal_approx(example.get_arrival_hours(), 17.7), "RE 209 arrives 17:42")
	check(TimetableEntry.format_time(17.7) == "17:42", "time formatting")
	for i in timetable.entries.size():
		var plan := dispatcher._plan(timetable.entries[i], timetable.entries[i].platform)
		if plan.is_empty():
			check(false, "path for %s" % timetable.entries[i].train_number)
	check(true, "every timetable entry has a path")
	var southbound := dispatcher._plan(example, 1)
	check((southbound["ids"] as Array).has(starter.built["track_1"]), "southbound RE uses track 1")


func _test_models() -> void:
	print("--- Models")
	var livery := (load("res://assets/trains/regional_express.tres") as TrainType).get_livery()
	for kind: String in TrainMeshes.SPECS:
		var parts := TrainMeshes.build_car(kind, livery)
		var paint: ArrayMesh = parts["paint"]
		var box := paint.get_aabb()
		var triangles := paint.surface_get_array_len(0) / 3
		var spec := TrainMeshes.get_spec(kind)
		check(box.size.x <= 2.9 and box.end.y <= 4.3 and box.position.y >= -0.05,
			"%s fits the loading gauge (%s)" % [kind, box])
		check(absf(box.size.z - float(spec["length"])) < 1.6, "%s length matches spec" % kind)
		check(triangles > 300 and triangles < 20000, "%s triangle count reasonable (%d)" % [kind, triangles])
	var coach := TrainMeshes.build_car("coach", livery)
	check(coach["glass"] != null and (coach["doors"] as Array).size() == 8, "coach has windows and 8 door leaves")
	var loco := TrainMeshes.build_car("loco_regional", livery)
	check((loco["lamps_front"] as Array).size() == 3, "regional loco has three headlights")


func _test_sounds() -> void:
	print("--- Sounds")
	for sound_name in ["rolling", "clack", "brake", "door_open", "door_close", "chime", "horn"]:
		var stream := SoundLibrary.get_sound(sound_name)
		var peak := SoundLibrary.peak(stream)
		check(peak > 0.2 and peak < 0.75, "%s generated, gentle level (peak %.2f)" % [sound_name, peak])
	check(SoundLibrary.get_sound("rolling").loop_mode == AudioStreamWAV.LOOP_FORWARD, "rolling sound loops")


# --- Fahrten ------------------------------------------------------------------------

## Echter Fahrplanbetrieb 15:00 → 15:50: RB 315 (Gleis 1) und RB 316 (Gleis 2) kreuzen sich.
func _test_scheduled_run() -> void:
	print("--- Scheduled run")
	WorldClock.set_time(15.0)
	WorldClock.paused = false
	dispatcher.enabled = true
	dispatcher.check_timetable()
	check(dispatcher.get_trains().size() == 2, "two trains spawned for 15:06 / 15:10 (%d)" % dispatcher.get_trains().size())
	await get_tree().physics_frame
	var board: DepartureBoard = main.get_node("World/TestArea/DepartureBoard")
	board.refresh()
	var rows := board.get_row_texts()
	check(rows[0].contains("RB 315") and rows[0].contains("Südtal"), "board shows RB 315 to Südtal (%s)" % rows[0])
	check(rows[1].contains("RB 316") and rows[1].contains("Gl. 2"), "board shows RB 316 on platform 2 (%s)" % rows[1])

	WorldClock.time_scale = 10.0
	var both_in_station := false
	var elapsed := 0
	while WorldClock.time_of_day < 15.85 and elapsed < 20000:
		await get_tree().physics_frame
		elapsed += 1
		_monitor()
		var dwelling := 0
		for train in dispatcher.get_trains():
			if train.state == Train.State.DWELLING:
				dwelling += 1
		both_in_station = both_in_station or dwelling == 2
	WorldClock.time_scale = 1.0

	for number in ["RB 315", "RB 316"]:
		check(arrivals.has(number), "%s arrived at the station" % number)
		check(max_door.get(number, 0.0) > 0.99, "%s opened its doors" % number)
		check(departures.has(number), "%s departed" % number)
		check(retired.has(number), "%s left through the tunnel" % number)
	check(arrivals.get("RB 315", {}).get("platform", 0) == 1, "RB 315 stopped at platform 1")
	check(arrivals.get("RB 316", {}).get("platform", 0) == 2, "RB 316 stopped at platform 2")
	check(float(arrivals.get("RB 315", {}).get("error", 9.0)) < 0.1, "stopped precisely at the stop marker")
	check(both_in_station, "trains crossed in the station (both dwelling at once)")
	check(float(departures.get("RB 315", 0.0)) >= 15.2 - 0.001, "RB 315 did not leave before 15:12")
	check(float(departures.get("RB 316", 0.0)) >= 15.2667 - 0.001, "RB 316 did not leave before 15:16")
	_check_safety()


func _test_freight_passes() -> void:
	print("--- Freight")
	dispatcher.enabled = false
	var index := _entry_index("GZ 803")
	WorldClock.set_time(14.1)
	var train := dispatcher.spawn_train(index)
	check(train != null, "freight train spawned")
	check(train.cars.size() == 4, "freight consist: loco + timber + container + hopper")
	dispatcher.enabled = true
	WorldClock.time_scale = 10.0
	var frames := 0
	while is_instance_valid(train) and train.state != Train.State.DONE and frames < 20000:
		await get_tree().physics_frame
		frames += 1
		_monitor()
		if is_instance_valid(train) and train.state == Train.State.DWELLING:
			dwelled["GZ 803"] = true
	WorldClock.time_scale = 1.0
	check(retired.has("GZ 803"), "freight train passed through and left")
	check(not dwelled.has("GZ 803"), "freight train did not stop at the platform")
	_check_safety()


## Gleis 1 belegt → der Zug fährt automatisch auf Gleis 2.
func _test_platform_choice() -> void:
	print("--- Automatic platform choice")
	dispatcher.enabled = false
	var track_1: int = starter.built["track_1"]
	interlocking.set_segment_occupied(track_1, true)
	var index := _entry_index("RE 209")
	WorldClock.set_time(17.45)
	var train := dispatcher.spawn_train(index)
	dispatcher.enabled = true
	WorldClock.time_scale = 10.0
	var frames := 0
	while is_instance_valid(train) and train.state == Train.State.RUNNING and frames < 20000:
		await get_tree().physics_frame
		frames += 1
		_monitor()
	check(is_instance_valid(train) and train.state == Train.State.DWELLING, "RE 209 reached a platform")
	check(is_instance_valid(train) and train.platform_number == 2, "switched to free platform 2 automatically")
	interlocking.set_segment_occupied(track_1, false)
	while is_instance_valid(train) and train.state != Train.State.DONE and frames < 40000:
		await get_tree().physics_frame
		frames += 1
		_monitor()
	WorldClock.time_scale = 1.0
	check(retired.has("RE 209"), "RE 209 continued its journey")
	_check_safety()


## Einfahrsignal auf Halt → der Zug bleibt davor stehen.
func _test_red_signal() -> void:
	print("--- Red signal")
	dispatcher.enabled = false
	var entry_signal := network.get_signal_for(_signal_node("north"), _signal_segment("north"))
	network.set_signal_mode(entry_signal.id, RailSignal.Mode.HALT)
	WorldClock.set_time(20.0)
	var train := dispatcher.spawn_train(_entry_index("RB 317"))
	dispatcher.enabled = true
	WorldClock.time_scale = 10.0
	for i in 900:
		await get_tree().physics_frame
		_monitor()
	var node := network.get_rail_node(entry_signal.node_id)
	var signal_distance := train.path.end_of(train.path.segment_ids.find(entry_signal.segment_id) - 1)
	check(train.speed == 0.0 and train.head <= signal_distance - Train.SIGNAL_STOP_MARGIN + 0.01,
		"train waits in front of the red signal (%.1f m before)" % (signal_distance - train.head))
	check(train.head > signal_distance - Train.SIGNAL_STOP_MARGIN - 0.5, "stopped close to the signal, not early")
	check(train.status.contains("Halt"), "train knows why it waits (%s)" % train.status)
	check(node != null, "signal node exists")
	network.set_signal_mode(entry_signal.id, RailSignal.Mode.ROUTE)
	var passed := false
	for i in 600:
		await get_tree().physics_frame
		_monitor()
		if not is_instance_valid(train) or train.head > signal_distance + 5.0:
			passed = true
			break
	check(passed, "train continues after the signal is released")
	if not passed:
		for other in dispatcher.get_trains():
			var index := other.path.index_at(other.head)
			print("      %s head=%.1f seg=%d occupied=%s path=%s granted=%s" % [other.entry.train_number, other.head,
				other.path.segment_ids[index], other.get_occupied_segments(), other.path.segment_ids, other.granted.keys()])
		for rail_signal in network.get_signals():
			var r := interlocking.get_route(rail_signal.id)
			print("      signal %d node %d seg %d mode %d route %s blocks %s entered %s" % [rail_signal.id, rail_signal.node_id,
				rail_signal.segment_id, rail_signal.mode, r.segments if r else [], r.blocks if r else [], r.entered if r else false])
		for segment in network.get_segments():
			print("      seg %d block %d z %.0f..%.0f x %.1f" % [segment.id, segment.block_id, segment.get_start_position().z,
				segment.get_end_position().z, segment.get_end_position().x])
		var route := interlocking.get_route(entry_signal.id)
		print("      status: %s | route: %s | other trains: %s" % [train.status,
			route.segments if route else "keiner", dispatcher.get_trains().map(func(t: Train) -> String: return t.get_info_text())])
	WorldClock.time_scale = 1.0
	# Nachtbeleuchtung
	await get_tree().create_timer(3.5).timeout
	var glass: StandardMaterial3D = dispatcher.glass_material
	check(glass.emission_energy_multiplier > 0.5, "windows glow warm at night")
	_check_safety()


func _test_save_and_camera() -> void:
	print("--- Save & camera")
	var bird: BirdEyeCamera = main.get_node("BirdEyeCamera")
	var trains := dispatcher.get_trains()
	if not trains.is_empty():
		bird.set_active(true)
		bird.follow(trains[0])
		for i in 120:
			await get_tree().physics_frame
		var focus := trains[0].get_focus_point()
		check(RailGeometry.flat(bird.global_position - focus).length() < 12.0, "camera follows the train smoothly")
	SaveManager.delete_save("traintest")
	check(SaveManager.save_game("traintest"), "save with running trains")
	check(SaveManager.load_game("traintest"), "load")
	await get_tree().physics_frame
	check(dispatcher.get_trains().is_empty(), "running trains are cleared on load (respawn by timetable)")
	check(network.get_segment_count() == 12 and network.get_switches().size() == 2, "railway restored after load")
	var served := dispatcher.save_state()["served"] as Dictionary
	check(served.has(str(_entry_index("RB 315"))), "timetable progress restored")
	SaveManager.delete_save("traintest")


# --- Überwachung ---------------------------------------------------------------------

func _monitor() -> void:
	var owners := {}
	for train in dispatcher.get_trains():
		var key := train.train_id
		var number := train.entry.train_number
		# Signale: nie ohne gewährten Fahrweg vorbei
		if _last_head.has(key):
			var old: float = _last_head[key]
			var path := train.path
			for j in range(path.index_at(maxf(old, 0.0)), path.segment_ids.size() - 1):
				var node_distance := path.end_of(j)
				if node_distance > train.head:
					break
				if node_distance <= old:
					continue
				var rail_signal := network.get_signal_for(path.exit_node(j), path.segment_ids[j + 1])
				if rail_signal:
					var route := interlocking.get_route(rail_signal.id)
					if not train.granted.has(rail_signal.id) or route == null or route.owner_id != train.train_id:
						violations["signal"] += 1
						print("      signal violation %s at signal %d" % [number, rail_signal.id])
			var dt := get_physics_process_delta_time() * WorldClock.time_scale
			var accel := absf(train.speed - float(_last_speed[key])) / maxf(dt, 0.0001)
			if accel > train.train_type.braking * 1.8 + 0.05 and maxf(train.speed, float(_last_speed[key])) > 0.3:
				violations["jerk"] += 1
				print("      jerk %s: %.2f → %.2f m/s (%s)" % [number, _last_speed[key], train.speed, train.status])
		if train.speed > train.max_speed * 1.01:
			violations["overspeed"] += 1
		_last_head[key] = train.head
		_last_speed[key] = train.speed
		for segment_id in train.get_occupied_segments():
			if owners.has(segment_id) and owners[segment_id] != key:
				violations["overlap"] += 1
			owners[segment_id] = key
		# Ereignisse
		if train.state == Train.State.RUNNING and train.stop_at >= 0.0:
			_last_stop[key] = train.stop_at
		if train.state == Train.State.DWELLING and not arrivals.has(number):
			var stop_error := absf(train.head - float(_last_stop.get(key, -100.0)))
			arrivals[number] = {"platform": train.platform_number, "error": stop_error}
		if train.state == Train.State.DWELLING:
			var door := 0.0
			for car in train.cars:
				door = maxf(door, car.get_door_amount())
			max_door[number] = maxf(float(max_door.get(number, 0.0)), door)
		if train.departed_at >= 0.0 and not departures.has(number):
			departures[number] = train.departed_at
	# Verschwunden = im Zieltunnel angekommen (die Strecke ist intakt)
	var present := {}
	for train in dispatcher.get_trains():
		present[train.entry.train_number] = true
	for number: String in _present_before:
		if not present.has(number):
			retired[number] = true
	_present_before = present


var _present_before := {}
var _last_stop := {}


func _check_safety() -> void:
	check(violations["signal"] == 0, "no train passed a signal without a granted route")
	check(violations["overlap"] == 0, "never two trains on the same track")
	check(violations["overspeed"] == 0, "no overspeed")
	check(violations["jerk"] == 0, "smooth acceleration and braking")


func _entry_index(number: String) -> int:
	for i in dispatcher.timetable.entries.size():
		if dispatcher.timetable.entries[i].train_number == number:
			return i
	return -1


## Knoten und Gleis des nördlichen Einfahrsignals.
func _signal_node(side: String) -> int:
	for rail_signal in network.get_signals():
		var node := network.get_rail_node(rail_signal.node_id)
		if side == "north" and node.position.z < -75.0:
			return rail_signal.node_id
	return -1


func _signal_segment(side: String) -> int:
	for rail_signal in network.get_signals():
		var node := network.get_rail_node(rail_signal.node_id)
		if side == "north" and node.position.z < -75.0:
			return rail_signal.segment_id
	return -1
