## Automatischer Test für Etappe 4: Figuren, Bewohner und Bahnhofsleben.
##
## Prüft Charaktermodelle (alle Presets, Winter/Sommer, Haltungen, Schritte),
## Schrittgeräusche, Wegenetz, Häuser und Plätze, den Tagesablauf der Bewohner,
## einen echten Fußweg vom Dorf über den Bohlenübergang auf den Bahnsteig,
## Sitzen, die Kameras sowie Ein- und Aussteigen im Fahrplanbetrieb.
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/npc_test.tscn
extends Node

var failures := 0
var main: Node3D
var director: NpcDirector
var dispatcher: TrainDispatcher
var terrain: LowPolyTerrain
var player: PlayerController
var graph: WalkGraph


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	WorldClock.set_time(15.0)
	WorldClock.paused = true
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	director = main.get_node("NpcDirector")
	dispatcher = main.get_node("World/Railway/TrainDispatcher")
	terrain = main.get_node("World/Terrain")
	player = main.get_node("Player")
	graph = main.get_node("World/WalkGraph")
	dispatcher.enabled = false
	await frames(10)

	await _test_characters()
	_test_sounds()
	_test_world_setup()
	_test_daily_routine()
	await _test_walk_to_platform()
	await _test_sitting()
	await _test_player()
	await _test_bird_camera()
	await _test_trains_and_passengers()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Figuren -------------------------------------------------------------------------

func _test_characters() -> void:
	print("--- Characters")
	var dir := DirAccess.open("res://assets/characters")
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var model := CharacterModel.new()
		model.appearance = load("res://assets/characters/" + file)
		add_child(model)
		check(model.get_mesh_count() >= 18, "%s builds (%d parts)" % [file, model.get_mesh_count()])
		model.queue_free()
		count += 1
	check(count >= 7, "player and six villager presets (%d)" % count)

	var model := CharacterModel.new()
	model.appearance = load("res://assets/characters/player_appearance.tres")
	add_child(model)
	var winter_parts := model.get_mesh_count()
	model.outfit = CharacterAppearance.Outfit.SUMMER
	check(model.get_mesh_count() < winter_parts, "summer outfit drops beanie and scarf (%d → %d)" % [winter_parts, model.get_mesh_count()])
	model.outfit = CharacterAppearance.Outfit.WINTER
	check(model.get_mesh_count() == winter_parts, "winter outfit restored")

	model.set_pose(CharacterModel.Pose.SIT)
	await get_tree().create_timer(0.6).timeout
	check(model.get_pose_weight(CharacterModel.Pose.SIT) > 0.99, "pose blends smoothly into sitting")
	var head: Node3D = model.find_child("Head", true, false)
	model.set_pose(CharacterModel.Pose.LOOK_UP)
	await get_tree().create_timer(0.6).timeout
	check(model.get_pose_weight(CharacterModel.Pose.SIT) < 0.01 and head.rotation.x > 0.3, "looks up at the clock")

	var steps := [0]
	model.footstep.connect(func() -> void: steps[0] += 1)
	for i in 40:
		model.animate(1.0, i * 0.25)
	check(steps[0] >= 2, "walking emits footsteps (%d)" % steps[0])
	model.queue_free()

	var kid := CharacterModel.new()
	kid.appearance = load("res://assets/characters/mats.tres")
	add_child(kid)
	check(is_equal_approx(kid.get_hip_height(), CharacterModel.HIP_HEIGHT * 0.74), "child has shorter legs")
	kid.queue_free()

	var traveller_model := CharacterModel.new()
	traveller_model.appearance = load("res://assets/characters/lotte.tres")
	traveller_model.carry = CharacterModel.Carry.SUITCASE
	add_child(traveller_model)
	check(traveller_model.find_child("Suitcase", true, false) != null, "travellers can carry a suitcase")
	traveller_model.set_pose(CharacterModel.Pose.HANDS_BEHIND)
	traveller_model.play_gesture(CharacterModel.Pose.STRETCH, 0.6)
	await get_tree().create_timer(0.45).timeout
	var stretching := traveller_model.get_pose_weight(CharacterModel.Pose.STRETCH)
	await get_tree().create_timer(1.0).timeout
	check(stretching > 0.5 and traveller_model.pose == CharacterModel.Pose.HANDS_BEHIND
		and traveller_model.get_pose_weight(CharacterModel.Pose.STRETCH) < 0.05,
		"a short stretch, then back to hands behind the back")
	var eye_min := INF
	for i in 400:
		await get_tree().process_frame
		eye_min = minf(eye_min, traveller_model.get_eye_openness())
	check(eye_min < 0.5, "blinks now and then")
	traveller_model.queue_free()


func _test_sounds() -> void:
	print("--- Footstep sounds")
	for sound_name in ["door_unlock", "stairs_out", "stairs_in", "brake_squeal", "wind", "station_murmur", "bird_0", "bird_3"]:
		var sound := SoundLibrary.get_sound(sound_name)
		var sound_peak := SoundLibrary.peak(sound)
		check(sound_peak > 0.1 and sound_peak < 0.55, "%s is subtle (peak %.2f)" % [sound_name, sound_peak])
	check(SoundLibrary.get_sound("wind").loop_mode == AudioStreamWAV.LOOP_FORWARD, "wind loops seamlessly")
	var ambience: AmbientSoundscape = main.get_node("AmbientSoundscape")
	check(ambience != null, "ambient soundscape in the scene")
	for surface in ["snow", "stone"]:
		for variant in 3:
			var stream := SoundLibrary.get_sound("step_%s_%d" % [surface, variant])
			var peak := SoundLibrary.peak(stream)
			check(peak > 0.15 and peak < 0.45 and stream.data.size() > 1000,
				"step_%s_%d is soft (peak %.2f)" % [surface, variant, peak])


# --- Welt ----------------------------------------------------------------------------

func _test_world_setup() -> void:
	print("--- Village, paths and spots")
	check(director.get_npcs().size() == 6, "six villagers loaded from assets/npcs (%d)" % director.get_npcs().size())
	for npc in director.get_npcs():
		check(npc.profile.appearance != null and director.get_home(npc.profile.home_name) != null,
			"%s has a look and a home" % npc.display_name)
	check(graph.get_point_count() >= 26, "walk graph has its waypoints (%d)" % graph.get_point_count())
	check(graph.is_connected_between("Dorfausgang", "BahnsteigW8") and graph.is_connected_between("Dorfausgang", "BahnsteigO8"),
		"village connected to both sides of the platform")
	for npc in director.get_npcs():
		var home := director.get_home(npc.profile.home_name)
		var path := graph.find_path(home.get_front_point(), Vector3(1.2, 0.0, -12.5))
		var length := 0.0
		for i in path.size() - 1:
			length += path[i].distance_to(path[i + 1])
		check(path.size() >= 5 and length < 80.0, "%s finds the way to the platform (%.0f m)" % [npc.display_name, length])

	var kinds := {}
	for spot in director.get_spots():
		kinds[spot.kind] = int(kinds.get(spot.kind, 0)) + 1
	var platform_seats := director.get_spots().filter(func(spot: StationSpot) -> bool:
		return spot.kind == StationSpot.Kind.SEAT and absf(spot.global_position.x) < 2.2).size()
	check(platform_seats == 12, "six platform benches with two seats each (%d)" % platform_seats)
	check(kinds.get(StationSpot.Kind.SEAT, 0) == 20, "plus two seating groups with four seats (%d)" % kinds.get(StationSpot.Kind.SEAT, 0))
	check(kinds.get(StationSpot.Kind.CHAT, 0) == 4, "two pairs of chat spots")
	check(kinds.get(StationSpot.Kind.STAND, 0) == 10 and kinds.get(StationSpot.Kind.CLOCK, 0) == 4
		and kinds.get(StationSpot.Kind.BOARD, 0) == 3, "waiting, clock and board spots")
	var platform_top := terrain.get_height(0.0, -9.0) + 0.55
	var seat_error := 0.0
	for spot in director.get_spots():
		if spot.kind == StationSpot.Kind.SEAT and absf(spot.global_position.x) < 2.2:
			seat_error = maxf(seat_error, absf(spot.global_position.y - platform_top - StationPropMeshes.BENCH_SEAT_HEIGHT))
	check(seat_error < 0.08, "seats at bench height (error %.2f m)" % seat_error)

	var network: RailNetwork = main.get_node("World/Railway/RailNetwork")
	var axis := network.find_segment_near(Vector3(-3.8, 0.0, 17.5), 3.0).closest_point(Vector3(-3.8, 0.0, 17.5))
	var ground := director.ground_height(Vector3(-3.8, 0.0, 17.5), axis.y)
	var rail_top := axis.y + RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT
	check(absf(ground - rail_top) < 0.15, "plank crossing is walkable at rail height (%.2f / %.2f)" % [ground, rail_top])
	var props := 0
	for child in main.get_node("World/TestArea").get_children():
		if child is StationProp:
			props += 1
	check(props >= 15, "station details placed (%d)" % props)


func _test_daily_routine() -> void:
	print("--- Daily routine")
	var expected := {
		15.0: {"Greta Berger": Npc.State.AT_STATION, "Emil Hofer": Npc.State.AT_STATION, "Mats Hofer": Npc.State.AT_STATION,
			"Jonas Kellner": Npc.State.AWAY, "Lotte Winter": Npc.State.AT_HOME, "Ida Sommer": Npc.State.AT_HOME},
		12.0: {"Greta Berger": Npc.State.AT_HOME, "Emil Hofer": Npc.State.AT_STATION, "Ida Sommer": Npc.State.AWAY,
			"Jonas Kellner": Npc.State.AWAY, "Lotte Winter": Npc.State.AT_HOME},
		3.0: {"Greta Berger": Npc.State.AT_HOME, "Emil Hofer": Npc.State.AT_HOME, "Jonas Kellner": Npc.State.AT_HOME,
			"Lotte Winter": Npc.State.AT_HOME, "Mats Hofer": Npc.State.AT_HOME, "Ida Sommer": Npc.State.AT_HOME},
	}
	for hours: float in expected:
		WorldClock.set_time(hours)
		director.resume_all()
		var ok := true
		var wrong := ""
		for npc_name: String in expected[hours]:
			var npc := director.get_npc(npc_name)
			if npc.state != expected[hours][npc_name]:
				ok = false
				wrong += " %s=%s" % [npc_name, Npc.State.keys()[npc.state]]
		check(ok, "villagers where they belong at %s%s" % [TimetableEntry.format_time(hours), wrong])
	for npc in director.get_npcs():
		if npc.state == Npc.State.AT_HOME and npc.is_present():
			check(false, "%s at home but visible" % npc.display_name)
	WorldClock.set_time(15.0)
	director.resume_all()
	var at_station := 0
	for npc in director.get_npcs():
		if npc.state == Npc.State.AT_STATION:
			at_station += 1
			check(npc.is_present() and npc.get_spot() != null and npc.global_position.distance_to(Vector3(-5.0, npc.global_position.y, 0.0)) < 30.0,
				"%s placed at the station (%s)" % [npc.display_name, npc.get_behaviour()])
	check(at_station == 3, "three villagers at the station at 15:00")


# --- Wege ----------------------------------------------------------------------------

## Ein Reisender geht vom Dorfrand über den Bohlenübergang und die Rampe auf den Bahnsteig.
func _test_walk_to_platform() -> void:
	print("--- Walk from the village to the platform")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var traveller := director.spawn_traveller(rng)
	traveller.begin_trip("Nordtal", -1, director.get_exit_point())
	var platform_top := terrain.get_height(0.0, -9.0) + 0.55
	var reached := false
	var crossed_height := -INF
	var lowest := INF
	for i in 3600:
		await get_tree().physics_frame
		var p := traveller.global_position
		lowest = minf(lowest, p.y - terrain.get_height(p.x, p.z))
		if absf(p.x + 3.8) < 0.6 and absf(p.z - 17.5) < 1.2:
			crossed_height = maxf(crossed_height, p.y - terrain.get_height(p.x, p.z))
		if absf(p.x) < 2.0 and p.z < 10.0 and absf(p.y - platform_top) < 0.1:
			reached = true
			break
	check(reached, "traveller reached the platform on foot")
	check(crossed_height > 0.45, "walked over the plank crossing, not through the rails (%.2f m)" % crossed_height)
	check(lowest > -0.15, "never sank into the ground (%.2f m)" % lowest)
	traveller.queue_free()


func _test_sitting() -> void:
	print("--- Sitting on a bench")
	var npc := director.get_npc("Emil Hofer")
	var seat: StationSpot = null
	for spot in director.get_spots():
		if spot.kind == StationSpot.Kind.SEAT and spot.is_free() and (seat == null
				or spot.global_position.distance_to(npc.global_position) < seat.global_position.distance_to(npc.global_position)):
			seat = spot
	check(seat != null and npc.use_spot(seat), "Emil walks to a free bench")
	for i in 2400:
		await get_tree().physics_frame
		if npc.is_seated() and absf(npc.global_position.y - seat.global_position.y) < 0.02:
			break
	check(npc.is_seated(), "Emil sits down")
	check(absf(npc.global_position.y - seat.global_position.y) < 0.02
		and RailGeometry.flat(npc.global_position - seat.global_position).length() < 0.05, "sits exactly on the seat")
	check(npc.model.get_pose_weight(CharacterModel.Pose.SIT) > 0.99, "sitting pose")
	check(not seat.is_free() and seat.occupant == npc, "seat is taken")


# --- Spielfigur und Kameras ------------------------------------------------------------

func _test_player() -> void:
	print("--- Player")
	var vmc: ViewModeController = main.get_node("ViewModeController")
	vmc.set_mode(GameDefs.ViewMode.EXPLORE, true)
	player.load_state({"position": [-11.0, terrain.get_height(-11.0, 10.0) + 0.3, 10.0], "camera_yaw": 0.0})
	await frames(60)
	var model: CharacterModel = player.get_node("Model")
	var steps := [0]
	model.footstep.connect(func() -> void: steps[0] += 1)
	var pivot: Node3D = player.get_node("CameraYaw")
	var max_lag := 0.0
	var start_lean := 0.0
	Input.action_press(&"move_forward")
	for i in 60:
		await get_tree().physics_frame
		max_lag = maxf(max_lag, pivot.global_position.distance_to(player.global_position + Vector3.UP * CharacterModel.EYE_HEIGHT))
		if i < 25:
			start_lean = maxf(start_lean, model.get_lean())
	var walk_lean := model.get_lean()
	Input.action_release(&"move_forward")
	var stop_lean := INF
	for i in 30:
		await get_tree().physics_frame
		stop_lean = minf(stop_lean, model.get_lean())
	check(start_lean > walk_lean + 0.01, "leans into the first steps (%.3f vs %.3f)" % [start_lean, walk_lean])
	check(stop_lean < walk_lean - 0.02, "leans back gently when stopping (%.3f)" % stop_lean)
	check(steps[0] >= 3, "footsteps while walking (%d)" % steps[0])
	check(max_lag > 0.05 and max_lag < 1.0, "camera follows with a gentle delay (%.2f m)" % max_lag)
	await frames(60)
	var rest := pivot.global_position.distance_to(player.global_position + Vector3.UP * CharacterModel.EYE_HEIGHT)
	check(rest < 0.05, "camera settles behind the player (%.3f m)" % rest)
	var footsteps: FootstepPlayer = null
	for child in player.get_children():
		if child is FootstepPlayer:
			footsteps = child
	check(footsteps != null and footsteps.get_surface() == "snow", "snow underfoot in the village")
	player.load_state({"position": [1.3, terrain.get_height(1.3, -3.5) + 0.8, -3.5]})
	await frames(30)
	check(footsteps.get_surface() == "stone", "stone underfoot on the platform")
	var sprint_start := player.global_position
	Input.action_press(&"move_back")
	Input.action_press(&"sprint")
	await frames(60)
	var sprint_lean := model.get_lean()
	check(sprint_lean > walk_lean + 0.05, "sprinting leans further forward (%.3f)" % sprint_lean)
	Input.action_release(&"move_back")
	Input.action_release(&"sprint")
	check(player.global_position.distance_to(sprint_start) > 3.5, "sprinting is faster than walking")
	vmc.set_mode(GameDefs.ViewMode.BIRD_EYE, true)


func _test_bird_camera() -> void:
	print("--- Bird camera")
	var bird: BirdEyeCamera = main.get_node("BirdEyeCamera")
	bird.set_active(true)
	bird.load_state({"focus": [0.0, 0.0, 0.0], "yaw": 0.0, "pitch": 0.9, "distance": 40.0})
	await frames(5)
	Input.action_press(&"move_right")
	await frames(3)
	var early := bird.save_state()["focus"][0] as float
	await frames(40)
	Input.action_release(&"move_right")
	var at_release := bird.save_state()["focus"][0] as float
	await frames(60)
	var after := bird.save_state()["focus"][0] as float
	check(early < 1.0, "panning starts softly (%.2f m)" % early)
	check(after - at_release > 0.5, "panning rolls out after releasing the key (%.2f m)" % (after - at_release))
	await frames(60)
	check(absf(bird.save_state()["focus"][0] - after) < 0.05, "and then comes to rest")


# --- Züge ------------------------------------------------------------------------------

func _test_trains_and_passengers() -> void:
	print("--- Passengers and trains")
	var boarded: Array = []
	var alighted: Array = []
	director.passenger_boarded.connect(func(npc: Npc, train: Train) -> void: boarded.append([npc, train.entry.train_number, train.entry.destination]))
	director.passenger_alighted.connect(func(npc: Npc, train: Train) -> void: alighted.append([npc, train.entry.train_number]))
	WorldClock.set_time(14.4)
	director.resume_all()
	WorldClock.paused = false
	dispatcher.enabled = true
	dispatcher.check_timetable()
	WorldClock.time_scale = 2.0
	var departed := {}
	var greta := director.get_npc("Greta Berger")
	var max_held_after_departure := 0.0
	var phases := {}
	var steps_ok := {}
	var last_state := {}
	var end_speed := {}
	var luggage := 0
	while WorldClock.time_of_day < 15.6:
		await get_tree().physics_frame
		for npc in director.get_travellers():
			if npc.model.carry != CharacterModel.Carry.NONE:
				luggage += 1
		for train in dispatcher.get_trains():
			var key := train.entry.train_number
			if train.state == Train.State.DWELLING:
				var list: Array = phases.get(key, [])
				if list.is_empty() or list[-1] != train.dwell_phase:
					list.append(train.dwell_phase)
				phases[key] = list
				# Türen erst öffnen, wenn die Trittstufe ganz draußen ist
				if train.cars[1].get_door_amount() > 0.01 and train.get_step_amount() < 0.99:
					steps_ok[key] = false
			elif last_state.get(key, -1) == Train.State.DWELLING and train.get_step_amount() > 0.01:
				steps_ok[key] = false  # abgefahren, obwohl die Stufe noch draußen ist
			last_state[key] = train.state
			if train.state == Train.State.RUNNING and train.stop_at >= 0.0 and train.stop_at - train.head < 1.5:
				end_speed[key] = maxf(float(end_speed.get(key, 0.0)), train.speed)
			if train.entry.station == "Wintervale" and train.departed_at >= 0.0:
				departed[train.entry.train_number] = train.departed_at
			max_held_after_departure = maxf(max_held_after_departure, train.get_hold_time())
	WorldClock.time_scale = 1.0
	WorldClock.paused = true
	var travellers_boarded := boarded.filter(func(row: Array) -> bool: return row[0] == null or not is_instance_valid(row[0]) or (row[0] as Npc).profile == null)
	check(departed.has("RB 315") and departed.has("RB 316"), "both trains still departed (%s)" % str(departed.keys()))
	check(max_held_after_departure <= Train.MAX_DOOR_HOLD + 0.1,
		"passengers hold the doors only briefly (%.1f s beyond departure)" % max_held_after_departure)
	check(boarded.any(func(row: Array) -> bool: return is_instance_valid(row[0]) and row[0] == greta and row[2] == "Nordtal"),
		"Greta boarded a train to Nordtal")
	check(greta.state == Npc.State.AWAY and not greta.is_present(), "Greta is away on her trip")
	check(travellers_boarded.size() >= 1, "travellers from the village boarded (%d)" % travellers_boarded.size())
	check(alighted.size() >= 1, "visitors got off the arriving trains (%d)" % alighted.size())
	var still_held := false
	for train in dispatcher.get_trains():
		still_held = still_held or train.is_held()
	check(not still_held, "no train is left with held doors")
	var expected := [Train.Dwell.UNLOCKING, Train.Dwell.STEP_OUT, Train.Dwell.OPENING, Train.Dwell.WAITING,
		Train.Dwell.CLOSING, Train.Dwell.STEP_IN]
	for number in ["RB 315", "RB 316"]:
		check(phases.get(number, []) == expected, "%s: unlock, step out, doors open, wait, close, step in" % number)
		check(steps_ok.get(number, true), "%s: doors only open with the step extended, departs with it retracted" % number)
		check(float(end_speed.get(number, 9.0)) < 1.0, "%s: rolls in gently (%.2f m/s on the last 1.5 m)" % [number, end_speed.get(number, 9.0)])
	var order_ok := true
	var seen_in := {}
	for row: Array in director.get_door_log():
		var door_key := "%d:%d" % [row[0], row[1]]
		if row[2] == "in":
			seen_in[door_key] = true
		elif seen_in.has(door_key):
			order_ok = false
	check(order_ok and director.get_door_log().size() >= 3, "at every door: first off, then on (%d step walks)" % director.get_door_log().size())
	check(luggage > 0, "travellers carry luggage")
	dispatcher.enabled = false
	dispatcher.clear_trains()
