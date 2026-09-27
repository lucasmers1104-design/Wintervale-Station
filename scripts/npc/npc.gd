## Ein Bewohner (oder Reisender), der durch den Bahnhof läuft.
##
## Zwei Ebenen:
## - Bewegung: läuft einen Weg aus dem [WalkGraph] ab, folgt dabei dem Boden,
##   dreht sich weich und wartet höflich, wenn die Spielfigur im Weg steht.
## - Verhalten ("Gedanken", alle 0,4 s): Was steht im Tagesablauf an? Zum
##   Bahnhof gehen, sitzen, warten, einsteigen, heimgehen …
##
## Benannte Bewohner haben einen [NpcProfile]-Steckbrief. Reisende ohne
## Steckbrief setzt der [NpcDirector] ein: Sie steigen in einen bestimmten
## Zug ein oder kommen mit einem Zug an und gehen ins Dorf.
class_name Npc
extends AnimatableBody3D

signal boarded(npc: Npc, train: Train)
signal alighted(npc: Npc, train: Train)

enum State {
	AT_HOME,           ## unsichtbar im Haus
	AT_STATION,        ## unterwegs zum / am Bahnhof (sitzen, stehen, warten …)
	BOARDING,          ## geht zur Zugtür und steigt ein
	AWAY,              ## im Zug unterwegs (unsichtbar)
	ALIGHTING,         ## steigt aus
	GOING_HOME,        ## auf dem Heimweg
	LEAVING,           ## Reisender geht ins Dorf und verschwindet
}

## Wie weit vor sich die Figur auf die Spielfigur Rücksicht nimmt.
const PERSONAL_SPACE := 0.95
const THINK_INTERVAL := 0.4
const TURN_SPEED := 7.0

var profile: NpcProfile
var director: NpcDirector
var display_name := ""
var walk_speed := 1.1
var state := State.AT_HOME
var model: CharacterModel

## Reisende: Ziel und Fahrplanzeile des Zuges, den sie nehmen wollen (-1 = beliebig).
var trip_destination := ""
var trip_entry_index := -1

var _behaviour := ""
var _behaviour_time := 0.0
var _watch_timer := 6.0
var _spot: StationSpot
var _seated := false
var _seat_return := Vector3.ZERO
var _routine: NpcRoutine
var _travel_routine: NpcRoutine
var _done_day: Dictionary = {}
var _train: Train
var _door := {}
var _used_trains: Dictionary[int, bool] = {}

var _path := PackedVector3Array()
var _path_index := 0
var _on_arrive := Callable()
var _moving := false
var _pace := 1.0
var _facing := Vector3.ZERO
var _walk_phase := 0.0
var _current_speed := 0.0
var _lane_offset := 0.0
var _think_timer := 0.0
var _blocked_time := 0.0
var _busy := false  ## Übergangsanimation läuft (Hinsetzen, Einsteigen …)
var _tween: Tween
var _label: Label3D
var _footsteps: FootstepPlayer
var _rng := RandomNumberGenerator.new()


## Richtet den Bewohner ein. [param p_profile] = null für einen Reisenden mit [param look].
func setup(p_director: NpcDirector, p_profile: NpcProfile, look: CharacterAppearance, seed_value: int) -> void:
	director = p_director
	profile = p_profile
	_rng.seed = seed_value
	display_name = profile.display_name if profile else ""
	walk_speed = profile.walk_speed if profile else _rng.randf_range(1.0, 1.35)
	_lane_offset = [-0.22, 0.0, 0.22][seed_value % 3]
	name = display_name.replace(" ", "") if profile else "Reisender%d" % seed_value

	collision_layer = GameDefs.LAYER_CHARACTERS
	collision_mask = 0
	sync_to_physics = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	var height := 1.4 * (look.height_scale if look else 1.0)
	capsule.radius = 0.26
	capsule.height = height
	shape.shape = capsule
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(shape)

	model = CharacterModel.new()
	model.appearance = look
	add_child(model)
	_footsteps = FootstepPlayer.new()
	_footsteps.base_volume_db = -17.0
	add_child(_footsteps)
	model.footstep.connect(_footsteps.play_step)

	if profile:
		_label = Label3D.new()
		_label.text = display_name
		_label.font_size = 34
		_label.pixel_size = 0.004
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.modulate = Color(1.0, 0.95, 0.85, 0.0)
		_label.outline_modulate = Color(0.12, 0.08, 0.06, 0.0)
		_label.outline_size = 8
		_label.no_depth_test = false
		_label.position = Vector3(0.0, 1.62 * (look.height_scale if look else 1.0) + 0.12, 0.0)
		add_child(_label)
	_set_present(false)


func is_present() -> bool:
	return visible


func get_behaviour() -> String:
	return _behaviour


func get_spot() -> StationSpot:
	return _spot


func is_seated() -> bool:
	return _seated


## Ist der Bewohner schon mit diesem Zug gefahren (angekommen oder abgefahren)?
func has_used_train(train_id: int) -> bool:
	return _used_trains.has(train_id)


## Geht zu einem Platz und nimmt ihn ein (sitzen, stehen, Uhr ansehen …).
## Gibt false zurück, wenn der Platz schon belegt ist.
func use_spot(spot: StationSpot) -> bool:
	if not spot.reserve(self):
		return false
	_leave_spot()
	spot.reserve(self)
	_spot = spot
	walk_to(spot.get_approach_point(), _take_spot.bind(spot, false))
	return true


## Reisender: taucht bei [param start] auf und will mit dem Fahrplanzug
## [param entry_index] nach [param destination].
func begin_trip(destination: String, entry_index: int, start: Vector3) -> void:
	trip_destination = destination
	trip_entry_index = entry_index
	state = State.AT_STATION
	_place_at(start)
	_set_present(true, true)
	_next_behaviour()


# --- Tagesablauf ------------------------------------------------------------------

## Setzt den Bewohner passend zur Uhrzeit (Spielstart, Laden, Zeitsprung).
func resume(hours: float) -> void:
	_stop_everything()
	_done_day.clear()
	if profile == null:
		return
	var routine := _pending_routine(hours)
	if routine == null:
		_enter_state_home()
		return
	_routine = routine
	if routine.activity == NpcRoutine.Activity.STATION_VISIT or hours < routine.get_until_hours():
		# Steht schon am Bahnhof – direkt an einem Platz beginnen.
		state = State.AT_STATION
		var spot := director.claim_spot(self, [StationSpot.Kind.SEAT, StationSpot.Kind.STAND], _rng)
		if spot:
			_place_at(spot.get_approach_point())
			_set_present(true)
			_take_spot(spot, true)
		else:
			_place_at(director.random_platform_point(_rng))
			_set_present(true)
			_next_behaviour()
	elif hours < routine.get_return_hours() + 0.75:
		_travel_routine = routine
		state = State.AWAY
		_set_present(false)
	else:
		_mark_done(routine)
		_enter_state_home()


func _think() -> void:
	if _busy:
		return
	var now := WorldClock.time_of_day
	match state:
		State.AT_HOME:
			var routine := _pending_routine(now)
			if routine == null:
				return
			if routine.activity == NpcRoutine.Activity.TRAVEL and now >= routine.get_until_hours():
				_mark_done(routine)  # heute verpasst
				return
			_leave_home(routine)
		State.AT_STATION:
			_think_at_station(now)
		State.BOARDING:
			if not _train_usable(_train):
				_abort_boarding()
		State.AWAY:
			_think_away(now)


func _think_at_station(now: float) -> void:
	if profile == null:
		_think_traveller(now)
		return
	var routine := _routine
	var over := routine == null or _is_done(routine) \
		or (routine.activity == NpcRoutine.Activity.STATION_VISIT and now >= routine.get_until_hours()) \
		or (routine.activity == NpcRoutine.Activity.TRAVEL and now >= routine.get_until_hours())
	if over:
		if routine:
			_mark_done(routine)
		go_home()
		return
	if routine.activity == NpcRoutine.Activity.TRAVEL:
		var train := director.find_departing_train(routine.destination, self)
		if train:
			_start_boarding(train)
			return
	_continue_behaviour()


func _think_traveller(now: float) -> void:
	var train := director.find_departing_train(trip_destination, self, trip_entry_index)
	if train:
		_start_boarding(train)
		return
	# Zug verpasst oder ausgefallen: wieder ins Dorf
	if trip_entry_index >= 0 and director.has_departed(trip_entry_index, now):
		leave_to_village()
		return
	_continue_behaviour()


func _think_away(now: float) -> void:
	if _travel_routine == null:
		_enter_state_home()
		return
	if now < _travel_routine.get_return_hours():
		return
	var train := director.find_arriving_train(_travel_routine.destination, self)
	if train:
		_mark_done(_travel_routine)
		alight_from(train, false)
	elif now > _travel_routine.get_return_hours() + 4.0:
		_mark_done(_travel_routine)  # spät nachts mit dem Bus heimgekommen …
		_enter_state_home()


func _pending_routine(hours: float) -> NpcRoutine:
	if profile == null:
		return null
	for routine in profile.routines:
		if routine and routine.covers(hours) and not _is_done(routine):
			return routine
	return null


func _is_done(routine: NpcRoutine) -> bool:
	return _done_day.get(routine, -1) == WorldClock.day


func _mark_done(routine: NpcRoutine) -> void:
	_done_day[routine] = WorldClock.day


# --- Handlungen ----------------------------------------------------------------------

func _leave_home(routine: NpcRoutine) -> void:
	_routine = routine
	var home := director.get_home(profile.home_name)
	_place_at(home.get_inside_point() if home else director.get_exit_point())
	_set_present(true, true)
	state = State.AT_STATION
	if home:
		_walk_path([home.get_inside_point(), home.get_front_point()], _next_behaviour)
	else:
		_next_behaviour()


## Nach Hause gehen (benannte Bewohner) bzw. ins Dorf (Reisende).
func go_home() -> void:
	if profile == null:
		leave_to_village()
		return
	_leave_spot()
	state = State.GOING_HOME
	var home := director.get_home(profile.home_name)
	if home == null:
		walk_to(director.get_exit_point(), _vanish.bind(State.AT_HOME))
		return
	walk_to(home.get_front_point(), func() -> void:
		_walk_path([home.get_front_point(), home.get_inside_point()], _vanish.bind(State.AT_HOME)))


## Reisender geht ins Dorf und verschwindet dort.
func leave_to_village() -> void:
	_leave_spot()
	state = State.LEAVING
	walk_to(director.get_exit_point(), _vanish.bind(State.LEAVING), 1.0)


## Kommt mit [param train] an: erscheint in einer Tür und steigt aus.
func alight_from(train: Train, is_visitor: bool) -> void:
	_stop_everything()
	var door := director.assign_door(train, self, Vector3.INF)
	if door.is_empty():
		if is_visitor:
			queue_free()
		else:
			_enter_state_home()
		return
	_train = train
	_used_trains[train.train_id] = true
	train.hold_doors(get_instance_id())
	state = State.ALIGHTING
	var inside: Vector3 = door["inside"]
	var outside: Vector3 = door["platform"]
	_place_at(inside, false)
	global_position.y = door["floor_y"]
	_face_now(outside - inside)
	_set_present(true, true)
	_busy = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(0.25)
	_tween.tween_method(_hop.bind(inside, door["floor_y"], outside), 0.0, 1.0, 0.7 / director.speed_factor())
	_tween.tween_callback(func() -> void:
		_busy = false
		train.release_doors(get_instance_id())
		alighted.emit(self, train)
		_train = null
		if is_visitor or profile == null:
			leave_to_village()
		else:
			go_home())


func _start_boarding(train: Train) -> void:
	var door := director.assign_door(train, self, global_position)
	if door.is_empty():
		return
	if _seated:
		_stand_up(_start_boarding.bind(train))
		return
	_leave_spot()
	_train = train
	_door = door
	state = State.BOARDING
	train.hold_doors(get_instance_id())
	walk_to(door["platform"], _enter_train, 1.25)


func _enter_train() -> void:
	if not _train_usable(_train):
		_abort_boarding()
		return
	var inside: Vector3 = _door["inside"]
	var start := global_position
	_face_now(inside - start)
	_busy = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_hop.bind(start, _door["floor_y"], inside), 0.0, 1.0, 0.6 / director.speed_factor())
	_tween.parallel().tween_method(model.set_fade, 1.0, 0.0, 0.6 / director.speed_factor()).set_delay(0.25 / director.speed_factor())
	_tween.tween_callback(func() -> void:
		_busy = false
		var train := _train
		train.release_doors(get_instance_id())
		_used_trains[train.train_id] = true
		_travel_routine = _routine
		if _routine:
			_mark_done(_routine)
		_train = null
		_set_present(false)
		state = State.AWAY
		boarded.emit(self, train)
		if profile == null:
			queue_free())


func _abort_boarding() -> void:
	if _train and is_instance_valid(_train):
		_train.release_doors(get_instance_id())
	_train = null
	_door = {}
	_busy = false
	model.set_fade(1.0)
	state = State.AT_STATION
	_next_behaviour()


func _train_usable(train: Train) -> bool:
	return train != null and is_instance_valid(train) and train.state == Train.State.DWELLING \
		and (train.doors_open() or train.is_held())


# --- Verhalten am Bahnsteig ------------------------------------------------------------

func _continue_behaviour() -> void:
	if _moving:
		return
	_behaviour_time -= THINK_INTERVAL * director.speed_factor()
	if _behaviour == "stand" or _behaviour == "wait":
		_watch_timer -= THINK_INTERVAL * director.speed_factor()
		if _watch_timer <= 0.0:
			_watch_timer = _rng.randf_range(7.0, 14.0)
			_glance_at_watch()
	if _behaviour_time <= 0.0:
		_next_behaviour()


## Wählt die nächste ruhige Beschäftigung: sitzen, stehen, Uhr ansehen, Tafel lesen, spazieren.
func _next_behaviour() -> void:
	if state != State.AT_STATION:
		return
	if _seated:
		_stand_up(_next_behaviour)
		return
	_leave_spot()
	var weights := {
		"sit": profile.likes_sitting if profile else 0.45,
		"stand": profile.likes_standing if profile else 0.6,
		"stroll": profile.likes_strolling if profile else 0.15,
		"clock": profile.likes_clock if profile else 0.2,
		"board": profile.likes_board if profile else 0.25,
	}
	var choice := _weighted_choice(weights)
	var kinds := {
		"sit": [StationSpot.Kind.SEAT], "stand": [StationSpot.Kind.STAND],
		"clock": [StationSpot.Kind.CLOCK], "board": [StationSpot.Kind.BOARD],
	}
	if kinds.has(choice):
		var spot := director.claim_spot(self, kinds[choice], _rng)
		if spot:
			_behaviour = choice
			walk_to(spot.get_approach_point(), _take_spot.bind(spot, false))
			_spot = spot
			return
	# Langsam den Bahnsteig entlang schlendern
	_behaviour = "stroll"
	_behaviour_time = 0.0
	walk_to(director.random_platform_point(_rng), func() -> void: _behaviour_time = _rng.randf_range(1.0, 3.0), 0.7)


func _take_spot(spot: StationSpot, instant: bool) -> void:
	_spot = spot
	if instant:
		_face_now(spot.get_facing())
	else:
		_face(spot.get_facing())
	match spot.kind:
		StationSpot.Kind.SEAT:
			_behaviour = "sit"
			_behaviour_time = _rng.randf_range(25.0, 60.0)
			_sit_down(spot, instant)
		StationSpot.Kind.STAND:
			_behaviour = "wait" if (profile == null or (_routine and _routine.activity == NpcRoutine.Activity.TRAVEL)) \
				else "stand"
			_behaviour_time = _rng.randf_range(14.0, 35.0)
			_watch_timer = _rng.randf_range(3.0, 9.0)
			model.set_pose(CharacterModel.Pose.STAND)
		StationSpot.Kind.CLOCK:
			_behaviour = "clock"
			_behaviour_time = _rng.randf_range(4.0, 7.0)
			model.set_pose(CharacterModel.Pose.LOOK_UP)
		StationSpot.Kind.BOARD:
			_behaviour = "board"
			_behaviour_time = _rng.randf_range(6.0, 10.0)
			model.set_pose(CharacterModel.Pose.LOOK_UP)


func _sit_down(spot: StationSpot, instant: bool) -> void:
	_seated = true
	_seat_return = spot.get_approach_point()
	model.set_pose(CharacterModel.Pose.SIT)
	var seat := spot.global_position
	if instant:
		global_position = seat
		_busy = false
		return
	_busy = true
	var start := global_position
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(0.35 / director.speed_factor())
	_tween.tween_method(func(t: float) -> void: global_position = start.lerp(seat, ease(t, -1.6)),
		0.0, 1.0, 0.55 / director.speed_factor())
	_tween.tween_callback(func() -> void: _busy = false)


func _stand_up(then: Callable) -> void:
	_seated = false
	model.set_pose(CharacterModel.Pose.STAND)
	var target := _seat_return
	target.y = director.ground_height(target, target.y)
	var start := global_position
	_busy = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void: global_position = start.lerp(target, ease(t, -1.6)),
		0.0, 1.0, 0.5 / director.speed_factor())
	_tween.tween_callback(func() -> void:
		_busy = false
		then.call())


func _glance_at_watch() -> void:
	if _seated or _busy:
		return
	model.set_pose(CharacterModel.Pose.CHECK_WATCH)
	get_tree().create_timer(2.2 / director.speed_factor()).timeout.connect(func() -> void:
		if is_instance_valid(self) and model.pose == CharacterModel.Pose.CHECK_WATCH:
			model.set_pose(CharacterModel.Pose.STAND))


## Ein Zug fährt ein: Wer frei steht, winkt manchmal kurz.
func react_to_arrival(train: Train) -> void:
	if state != State.AT_STATION or _seated or _busy or _moving:
		return
	if global_position.distance_to(train.get_focus_point()) > 45.0 or _rng.randf() > 0.3:
		return
	_face(RailGeometry.flat(train.get_focus_point() - global_position))
	model.set_pose(CharacterModel.Pose.WAVE)
	get_tree().create_timer(2.0 / director.speed_factor()).timeout.connect(func() -> void:
		if is_instance_valid(self) and model.pose == CharacterModel.Pose.WAVE:
			model.set_pose(CharacterModel.Pose.STAND))


func _weighted_choice(weights: Dictionary) -> String:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	var pick := _rng.randf() * total
	for key: String in weights:
		pick -= float(weights[key])
		if pick <= 0.0:
			return key
	return "stroll"


# --- Bewegung -------------------------------------------------------------------

## Geht über das Wegenetz zu [param target]; danach wird [param on_arrive] gerufen.
func walk_to(target: Vector3, on_arrive := Callable(), pace := 1.0) -> void:
	_walk_path(director.walk_graph.find_path(global_position, target) if director.walk_graph \
		else PackedVector3Array([global_position, target]), on_arrive, pace)


func _walk_path(points: Array, on_arrive: Callable, pace := 1.0) -> void:
	if _seated:
		_stand_up(_walk_path.bind(points, on_arrive, pace))
		return
	_path = PackedVector3Array(points)
	_path_index = 1 if _path.size() > 1 else 0
	_on_arrive = on_arrive
	_pace = pace
	_moving = true
	model.set_pose(CharacterModel.Pose.STAND)


func _physics_process(delta: float) -> void:
	if director == null:
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_think()
	if not visible:
		return
	var target_speed := 0.0
	if _moving and not _busy:
		target_speed = _step_along_path(delta)
	_current_speed = lerpf(_current_speed, target_speed, 1.0 - exp(-8.0 * delta))
	if not _busy and not _seated:
		global_position.y = director.ground_height(global_position, global_position.y)
	if _facing != Vector3.ZERO:
		var yaw := atan2(-_facing.x, -_facing.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-TURN_SPEED * delta))
	var amount := clampf(_current_speed / 1.1, 0.0, 1.0)
	_walk_phase += delta * _current_speed * 4.2
	model.animate(amount, _walk_phase)


func _process(delta: float) -> void:
	if _label and visible:
		var alpha := director.get_name_tag_alpha(self)
		var current := lerpf(_label.modulate.a, alpha, 1.0 - exp(-5.0 * delta))
		_label.modulate.a = current
		_label.outline_modulate.a = current * 0.8
		_label.visible = current > 0.02


## Ein Stück weitergehen; Rückgabe: aktuelle Geschwindigkeit.
func _step_along_path(delta: float) -> float:
	var target := _lane_point(_path_index)
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var to_target := target - flat_pos
	var distance := to_target.length()
	var speed := walk_speed * _pace * director.speed_factor()
	if distance > 0.001 and director.is_path_blocked(self, to_target / distance, PERSONAL_SPACE):
		# Höflich warten – und nach einem Moment seitlich ausweichen.
		_blocked_time += delta * director.speed_factor()
		if _blocked_time > 1.2:
			_blocked_time = 0.0
			_detour(to_target / distance)
		return 0.0
	_blocked_time = 0.0
	var step := speed * delta
	if distance <= step:
		global_position.x = target.x
		global_position.z = target.z
		_path_index += 1
		if _path_index >= _path.size():
			_moving = false
			var callback := _on_arrive
			_on_arrive = Callable()
			if callback.is_valid():
				callback.call()
		return speed
	var direction := to_target / distance
	global_position += direction * step
	_facing = direction
	return speed


## Um die Spielfigur herumgehen: ein Umweg-Punkt seitlich vorbei – nur auf eine
## Seite, auf der der Boden gleich hoch ist (nicht von der Bahnsteigkante!).
func _detour(direction: Vector3) -> void:
	var side := direction.cross(Vector3.UP).normalized()
	var here := global_position.y
	for sign_value: float in [1.0, -1.0]:
		var point := Vector3(global_position.x, 0.0, global_position.z) + side * sign_value * 0.95 + direction * 0.9
		var ground := director.ground_height(point, here)
		if absf(ground - here) < 0.15:
			var beside := Vector3(global_position.x, 0.0, global_position.z) + side * sign_value * 0.95
			if absf(director.ground_height(beside, here) - here) < 0.15:
				_path.insert(_path_index, point)
				_path.insert(_path_index, beside)
				return


## Zwischenpunkte leicht versetzt, damit nicht alle exakt auf derselben Linie laufen.
func _lane_point(index: int) -> Vector3:
	var point := _path[index]
	if index == 0 or index >= _path.size() - 1 or _lane_offset == 0.0:
		return point
	var direction := RailGeometry.flat(_path[index + 1] - _path[index - 1]).normalized()
	return point + direction.cross(Vector3.UP) * _lane_offset


func _hop(t: float, from: Vector3, floor_y: float, to: Vector3) -> void:
	var eased := ease(t, -1.8)
	var pos := from.lerp(to, eased)
	var low := minf(from.y, to.y)
	var high := maxf(floor_y, maxf(from.y, to.y)) + 0.12
	pos.y = lerpf(from.y, to.y, eased) + sin(eased * PI) * (high - low) * 0.35
	global_position = pos
	_walk_phase += 0.12
	model.animate(0.6 * sin(t * PI), _walk_phase)


func _face(direction: Vector3) -> void:
	var flat := RailGeometry.flat(direction)
	if flat.length_squared() > 0.0001:
		_facing = flat.normalized()


func _face_now(direction: Vector3) -> void:
	_face(direction)
	if _facing != Vector3.ZERO:
		rotation.y = atan2(-_facing.x, -_facing.z)


func _place_at(point: Vector3, snap := true) -> void:
	global_position = Vector3(point.x, point.y, point.z)
	if snap:
		global_position.y = director.ground_height(point, point.y)


# --- Hilfen -----------------------------------------------------------------------

func _leave_spot() -> void:
	if _spot:
		_spot.release(self)
	_spot = null


func _vanish(final_state: State) -> void:
	_busy = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(model.set_fade, 1.0, 0.0, 0.8 / director.speed_factor())
	_tween.tween_callback(func() -> void:
		_busy = false
		if final_state == State.LEAVING:
			queue_free()
		else:
			_enter_state_home())


func _enter_state_home() -> void:
	_stop_everything()
	state = State.AT_HOME
	_set_present(false)


func _set_present(present: bool, fade_in := false) -> void:
	visible = present
	collision_layer = GameDefs.LAYER_CHARACTERS if present else 0
	if present:
		model.set_fade(0.0 if fade_in else 1.0)
		if fade_in:
			_kill_tween()
			_tween = create_tween()
			_tween.tween_method(model.set_fade, 0.0, 1.0, 0.8)


func _stop_everything() -> void:
	_kill_tween()
	_leave_spot()
	if _train and is_instance_valid(_train):
		_train.release_doors(get_instance_id())
	_train = null
	_door = {}
	_moving = false
	_busy = false
	_seated = false
	_behaviour = ""
	_path = PackedVector3Array()
	_current_speed = 0.0
	if model:
		model.set_pose(CharacterModel.Pose.STAND)
		model.set_fade(1.0)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_leave_spot()
	if _train and is_instance_valid(_train):
		_train.release_doors(get_instance_id())
