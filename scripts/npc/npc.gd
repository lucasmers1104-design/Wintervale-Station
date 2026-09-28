## Ein Bewohner (oder Reisender), der durch den Bahnhof läuft.
##
## Zwei Ebenen:
## - Bewegung: läuft einen Weg aus dem [WalkGraph] ab, folgt dabei dem Boden,
##   dreht sich weich, wartet höflich bzw. weicht der Spielfigur aus und steigt
##   über die Trittstufen in Züge ein und aus. Die Figur wird aus der echten
##   Bewegung animiert (Tempo, Anfahren, Abbremsen, Drehen).
## - Verhalten ("Gedanken", alle 0,4 s): Was steht im Tagesablauf an? Zum
##   Bahnhof gehen, sitzen, warten, sich anstellen, heimgehen … Beim Warten
##   gibt es kleine, zufällige Gesten (Uhr, Hände wärmen, Dehnen, Umsehen).
##
## Ein- und Aussteigen organisiert der [NpcDirector] pro Tür mit einer
## Warteschlange: erst aussteigen, dann einsteigen, einer nach dem anderen.
##
## Benannte Bewohner haben einen [NpcProfile]-Steckbrief. Reisende ohne
## Steckbrief setzt der [NpcDirector] ein.
class_name Npc
extends AnimatableBody3D

signal boarded(npc: Npc, train: Train)
signal alighted(npc: Npc, train: Train)

enum State {
	AT_HOME,           ## unsichtbar im Haus
	AT_STATION,        ## unterwegs zum / am Bahnhof (sitzen, stehen, warten …)
	BOARDING,          ## steht an einer Zugtür an und steigt ein
	AWAY,              ## im Zug unterwegs (unsichtbar)
	ALIGHTING,         ## wartet im Zug aufs Aussteigen bzw. steigt aus
	GOING_HOME,        ## auf dem Heimweg
	LEAVING,           ## Reisender geht ins Dorf und verschwindet
	STROLLING,         ## Spaziergang im Dorf (Lieblingsplatz)
}

## Wie weit vor sich die Figur auf die Spielfigur Rücksicht nimmt.
const PERSONAL_SPACE := 0.95
const THINK_INTERVAL := 0.4
const TURN_SPEED := 6.0
## Auf den Trittstufen geht man etwas bedächtiger.
const CLIMB_PACE := 0.75

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
var _idle_timer := 5.0
var _spot: StationSpot
var _seated := false
var _seat_return := Vector3.ZERO
var _routine: NpcRoutine
var _travel_routine: NpcRoutine
var _done_day: Dictionary = {}
var _train: Train
var _used_trains: Dictionary[int, bool] = {}
var _queue_ready := false
var _queue_door := Vector3.ZERO
var _visitor := false
var _favourite_pose := CharacterModel.Pose.STAND
## Gepäck vor dem Zuzug (-1 = zieht gerade nicht ein).
var _arrival_carry := -1

var _path := PackedVector3Array()
var _path_index := 0
var _on_arrive := Callable()
var _moving := false
var _pace := 1.0
var _facing := Vector3.ZERO
var _last_flat := Vector3.ZERO
var _last_speed := 0.0
var _smoothed_accel := 0.0
var _last_yaw := 0.0
var _lane_offset := 0.0
var _think_timer := 0.0
var _blocked_time := 0.0
var _ground_timer := 0
var _busy := false  ## Übergang läuft (Hinsetzen, Trittstufen …) – keine neuen Entscheidungen
# Trittstufen: Punkte mit Höhe, die nacheinander begangen werden
var _climb := PackedVector3Array()
var _climb_index := 0
var _climb_done := Callable()
var _climb_fade := false
var _tween: Tween
var _label: Label3D
var _footsteps: FootstepPlayer
var _rng := RandomNumberGenerator.new()


## Richtet den Bewohner ein. [param p_profile] = null für einen Reisenden mit [param look].
func setup(p_director: NpcDirector, p_profile: NpcProfile, look: CharacterAppearance, seed_value: int,
		carry := CharacterModel.Carry.NONE) -> void:
	director = p_director
	profile = p_profile
	_rng.seed = seed_value
	display_name = profile.display_name if profile else ""
	walk_speed = profile.walk_speed if profile else _rng.randf_range(1.0, 1.35)
	_lane_offset = [-0.22, 0.0, 0.22][seed_value % 3]
	# Nicht alle Bewohner denken im selben Frame nach (gleichmäßige Last)
	_think_timer = _rng.randf() * THINK_INTERVAL
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
	model.view_distance = 120.0
	model.carry = profile.carry if profile else carry
	# Jeder geht ein bisschen anders: gemächlich, normal oder munter
	model.gait_energy = clampf(walk_speed * 0.8 + _rng.randf_range(-0.12, 0.12), 0.6, 1.3)
	add_child(model)
	_favourite_pose = CharacterModel.Pose.HANDS_BEHIND if walk_speed < 1.0 or _rng.randf() < 0.3 \
		else CharacterModel.Pose.STAND
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
		_label.visible = false
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


func is_busy() -> bool:
	return _busy or not _climb.is_empty()


func is_moving() -> bool:
	return _moving


## Abstand zum nächsten Wegpunkt (Draufsicht) – wer näher am Ziel ist als ein
## Hindernis, muss ihm nicht ausweichen.
func get_distance_to_waypoint() -> float:
	if not _moving or _path_index >= _path.size():
		return 0.0
	return Vector3(global_position.x, 0.0, global_position.z).distance_to(_path[_path_index])


## Ist der Bewohner schon mit diesem Zug gefahren (angekommen oder abgefahren)?
func has_used_train(train_id: int) -> bool:
	return _used_trains.has(train_id)


## Steht der Bewohner schon an seinem Platz in der Warteschlange?
func is_waiting_in_queue() -> bool:
	return state == State.BOARDING and _queue_ready and _climb.is_empty()


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
	if routine.activity == NpcRoutine.Activity.STROLL:
		# Spaziergang: vom Haus aus neu beginnen (nächster Gedanke)
		_enter_state_home()
		return
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
	if is_busy():
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
			if not is_instance_valid(_train) or _train.state != Train.State.DWELLING:
				boarding_aborted()
			elif _queue_ready:
				_idle_gestures(true)
		State.AWAY:
			_think_away(now)
		State.STROLLING:
			_think_strolling(now)


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
		if train and _start_boarding(train):
			return
		if _approach_incoming(routine.destination, -1):
			return
	_continue_behaviour()


## Fährt der eigene Zug gerade ein, stellt man sich schon an die richtige Bahnsteigkante.
func _approach_incoming(destination: String, entry_index: int) -> bool:
	if _moving or is_busy() or _behaviour == "ready":
		return false
	var train := director.find_incoming_train(destination, entry_index)
	if train == null:
		return false
	var spot := director.claim_spot_near_stop(self, train)
	if spot == null:
		return false
	if _seated:
		_stand_up(func() -> void: _walk_to_ready(spot))
	else:
		_walk_to_ready(spot)
	return true


func _walk_to_ready(spot: StationSpot) -> void:
	_leave_spot()
	spot.reserve(self)
	_spot = spot
	_behaviour = "ready"
	walk_to(spot.get_approach_point(), func() -> void:
		_face(spot.get_facing())
		model.set_pose(_favourite_pose)
		_behaviour_time = 999.0, 1.15)


func _think_traveller(now: float) -> void:
	var train := director.find_departing_train(trip_destination, self, trip_entry_index)
	if train and _start_boarding(train):
		return
	if _approach_incoming(trip_destination, trip_entry_index):
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
	var strolling := routine.activity == NpcRoutine.Activity.STROLL
	state = State.STROLLING if strolling else State.AT_STATION
	var next := _begin_stroll if strolling else _next_behaviour
	if home:
		_walk_path([home.get_inside_point(), home.get_front_point()], next)
	else:
		next.call()


# --- Spaziergang und Zuzug ---------------------------------------------------------------

## Spaziergang: zu einer Bank am Lieblingsplatz (oder einfach dorthin) und eine
## Weile bleiben. Das Ende bestimmt [method _think_strolling].
func _begin_stroll() -> void:
	if state != State.STROLLING:
		return
	var via := profile.favourite_via if profile else Vector3.INF
	var spot := director.claim_stroll_spot(self, via)
	if spot:
		_spot = spot
		walk_to(spot.get_approach_point(), _take_spot.bind(spot, false), 0.9)
		return
	var target := via if via != Vector3.INF else global_position + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
	walk_to(target, func() -> void:
		_behaviour = "stroll_stand"
		model.set_pose(_favourite_pose), 0.9)


func _think_strolling(now: float) -> void:
	if _routine == null or now >= _routine.get_until_hours() or _is_done(_routine):
		if _routine:
			_mark_done(_routine)
		go_home()
		return
	if not _moving:
		_idle_gestures(false)


## Neu zugezogen: kommt mit dem nächsten Zug aus [param origin] an (mit Koffer),
## steigt aus und geht zum ersten Mal in sein neues Zuhause.
func arrive_by_train(origin: String) -> void:
	_stop_everything()
	var arrival := NpcRoutine.new()
	arrival.activity = NpcRoutine.Activity.TRAVEL
	arrival.destination = origin
	arrival.start = TimetableEntry.format_time(WorldClock.time_of_day)
	arrival.return_after = TimetableEntry.format_time(WorldClock.time_of_day)
	_travel_routine = arrival
	_arrival_carry = model.carry
	model.carry = CharacterModel.Carry.SUITCASE
	state = State.AWAY
	_set_present(false)


## Ist der Bewohner gerade auf dem Weg in sein neues Zuhause (noch im Zug oder mit Koffer)?
func is_moving_in() -> bool:
	return _arrival_carry >= 0


## Wohin er gerade mit dem Zug unterwegs ist ("" = nicht unterwegs).
func get_away_destination() -> String:
	return _travel_routine.destination if state == State.AWAY and _travel_routine else ""


## Kurzer Satz, was der Bewohner gerade tut (Notizbuch).
func get_status_text() -> String:
	match state:
		State.AT_HOME:
			return "zu Hause"
		State.AT_STATION:
			return "am Bahnhof" if _routine == null or _routine.activity != NpcRoutine.Activity.TRAVEL else "wartet auf den Zug"
		State.BOARDING:
			return "steigt in den Zug"
		State.AWAY:
			if is_moving_in():
				return "im Zug aus %s – zieht ein" % get_away_destination()
			return "unterwegs in %s" % get_away_destination()
		State.ALIGHTING:
			return "steigt aus dem Zug"
		State.GOING_HOME:
			return "mit Koffer auf dem Weg ins neue Zuhause" if is_moving_in() else "auf dem Heimweg"
		State.STROLLING:
			return "beim Spaziergang im Dorf"
	return "unterwegs"


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


## Kommt mit [param train] an: stellt sich im Zug zum Aussteigen an. Der Director
## ruft [method climb_out], sobald die Tür frei ist.
func alight_from(train: Train, is_visitor: bool) -> void:
	_stop_everything()
	_visitor = is_visitor
	_train = train
	_used_trains[train.train_id] = true
	state = State.ALIGHTING
	_set_present(false)
	if not director.request_alight(self, train):
		alight_cancelled()


## Die Tür ist frei: über die Trittstufen auf den Bahnsteig.
func climb_out(door: Dictionary) -> void:
	var inside: Vector3 = door["inside"]
	var platform: Vector3 = door["platform"]
	global_position = inside
	_face_now(platform - inside)
	_set_present(true)
	model.set_fade(0.0)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(model.set_fade, 0.0, 1.0, 0.35)
	_start_climb([inside, door["door"], door["upper_top"], door["lower_top"], platform], _on_climbed_out, false)


func _on_climbed_out() -> void:
	var train := _train
	_train = null
	director.door_done(self)
	if profile and _travel_routine:
		_mark_done(_travel_routine)
	alighted.emit(self, train)
	# Ein paar Schritte vom Zug weg, kurz umsehen, dann weiter
	var along := RailGeometry.flat(train.get_focus_point() - global_position).normalized() if is_instance_valid(train) \
		else Vector3.FORWARD
	var target := director.spread_point(global_position, along, _rng)
	state = State.ALIGHTING
	walk_to(target, func() -> void:
		_busy = true
		var gesture: CharacterModel.Pose = [CharacterModel.Pose.STRETCH, CharacterModel.Pose.LOOK_UP,
			CharacterModel.Pose.CHECK_WATCH, CharacterModel.Pose.STAND][_rng.randi() % 4]
		model.play_gesture(gesture, 2.0)
		get_tree().create_timer(_rng.randf_range(1.2, 2.6) / director.speed_factor()).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			_busy = false
			if _visitor or profile == null:
				leave_to_village()
			else:
				go_home()), 0.85)


## Aussteigen hat nicht geklappt (Zug fährt schon weiter): Besucher verschwinden,
## Bewohner warten auf die nächste Ankunft.
func alight_cancelled() -> void:
	if _visitor or profile == null:
		queue_free()
	else:
		state = State.AWAY  # nächste Ankunft abwarten


## Stellt sich zum Einsteigen an einer Tür an. Gibt false zurück, wenn es keine gibt.
func _start_boarding(train: Train) -> bool:
	if _seated:
		_stand_up(func() -> void: _start_boarding(train))
		return true
	var slot := director.join_boarding(self, train)
	if slot.is_empty():
		return false
	_leave_spot()
	_train = train
	state = State.BOARDING
	_queue_ready = false
	_behaviour = "queue"
	_queue_door = slot["door"]
	walk_to(slot["slot"], _on_queue_reached, 1.1)
	return true


## Der Director hat die Warteschlange verschoben (jemand ist vorgerückt).
func move_to_queue_slot(slot: Vector3, door_point: Vector3) -> void:
	if state != State.BOARDING or is_busy():
		return
	_queue_door = door_point
	if _queue_ready and RailGeometry.flat(slot - global_position).length() < 0.2:
		return
	_queue_ready = false
	walk_to(slot, _on_queue_reached, 0.8)


func _on_queue_reached() -> void:
	_queue_ready = true
	_face(_queue_door - global_position)
	model.set_pose(_favourite_pose if _rng.randf() < 0.5 else CharacterModel.Pose.STAND)


## Jetzt ist man dran: über die Trittstufen in den Zug.
func climb_in(door: Dictionary) -> void:
	_queue_ready = false
	model.set_pose(CharacterModel.Pose.STAND)
	var platform: Vector3 = door["platform"]
	walk_to(platform, func() -> void:
		_start_climb([global_position, door["lower_top"], door["upper_top"], door["door"], door["inside"]],
			_on_climbed_in, true), 1.0)


func _on_climbed_in() -> void:
	var train := _train
	director.door_done(self)
	_used_trains[train.train_id] = true
	_travel_routine = _routine
	if _routine:
		_mark_done(_routine)
	_train = null
	_set_present(false)
	state = State.AWAY
	boarded.emit(self, train)
	if profile == null:
		queue_free()


## Der Zug fährt ab (oder fällt aus), bevor man dran war: weiter warten.
func boarding_aborted() -> void:
	director.leave_queues(self)
	_train = null
	_queue_ready = false
	_climb = PackedVector3Array()
	_busy = false
	model.set_fade(1.0)
	if state == State.BOARDING:
		state = State.AT_STATION
		_next_behaviour()


# --- Verhalten am Bahnsteig ------------------------------------------------------------

func _continue_behaviour() -> void:
	if _moving:
		return
	_behaviour_time -= THINK_INTERVAL * director.speed_factor()
	_idle_gestures(false)
	if _behaviour_time <= 0.0:
		_next_behaviour()


## Kleine, zufällige Bewegungen beim Warten – damit niemand wie ein Roboter dasteht.
func _idle_gestures(queueing: bool) -> void:
	if _moving or model.is_gesturing():
		return
	_idle_timer -= THINK_INTERVAL * director.speed_factor()
	if _idle_timer > 0.0:
		return
	_idle_timer = _rng.randf_range(4.0, 9.0)
	if _seated:
		if _rng.randf() < 0.35:
			model.play_gesture(CharacterModel.Pose.CHECK_WATCH, 2.0)
		return
	var roll := _rng.randf()
	if roll < 0.22:
		model.play_gesture(CharacterModel.Pose.CHECK_WATCH, 2.2)
	elif roll < 0.4 and WorldClock.is_dark() or roll < 0.34:
		model.play_gesture(CharacterModel.Pose.WARM_HANDS, 2.6)
	elif roll < 0.46 and not queueing:
		model.play_gesture(CharacterModel.Pose.STRETCH, 2.6)
	elif roll < 0.7:
		# Hände hinter den Rücken oder wieder locker lassen
		model.set_pose(CharacterModel.Pose.HANDS_BEHIND if model.pose == CharacterModel.Pose.STAND
			else CharacterModel.Pose.STAND)
	elif not queueing:
		# Sich ein wenig umdrehen und umsehen
		_face(_facing.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) if _facing != Vector3.ZERO else Vector3.FORWARD)


## Wählt die nächste ruhige Beschäftigung: sitzen, stehen, Uhr ansehen, Tafel lesen,
## spazieren, mit jemandem zusammenstehen.
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
		"chat": (profile.likes_standing * 0.6 if profile else 0.0),
	}
	var choice := _weighted_choice(weights)
	var kinds := {
		"sit": [StationSpot.Kind.SEAT], "stand": [StationSpot.Kind.STAND],
		"clock": [StationSpot.Kind.CLOCK], "board": [StationSpot.Kind.BOARD],
	}
	var spot: StationSpot = null
	if choice == "chat":
		spot = director.claim_chat_spot(self, _rng)
	elif kinds.has(choice):
		spot = director.claim_spot(self, kinds[choice], _rng)
	if spot:
		_behaviour = choice
		_spot = spot
		walk_to(spot.get_approach_point(), _take_spot.bind(spot, false))
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
	_idle_timer = _rng.randf_range(2.0, 6.0)
	match spot.kind:
		StationSpot.Kind.SEAT:
			_behaviour = "sit"
			_behaviour_time = _rng.randf_range(25.0, 60.0)
			_sit_down(spot, instant)
		StationSpot.Kind.STAND:
			_behaviour = "wait" if (profile == null or (_routine and _routine.activity == NpcRoutine.Activity.TRAVEL)) \
				else "stand"
			_behaviour_time = _rng.randf_range(14.0, 35.0)
			model.set_pose(_favourite_pose)
		StationSpot.Kind.CLOCK:
			_behaviour = "clock"
			_behaviour_time = _rng.randf_range(4.0, 7.0)
			model.set_pose(CharacterModel.Pose.LOOK_UP)
		StationSpot.Kind.BOARD:
			_behaviour = "board"
			_behaviour_time = _rng.randf_range(6.0, 10.0)
			model.set_pose(CharacterModel.Pose.LOOK_UP)
		StationSpot.Kind.CHAT:
			_behaviour = "chat"
			_behaviour_time = _rng.randf_range(25.0, 45.0)
			model.set_pose(CharacterModel.Pose.STAND)
			director.on_chat_spot_taken(self, spot)


## Im Gespräch: ab und zu nicken oder mit der Hand erzählen.
func chat_gesture() -> void:
	if _moving or is_busy() or model.is_gesturing():
		return
	model.play_gesture(CharacterModel.Pose.NOD if _rng.randf() < 0.5 else CharacterModel.Pose.TALK,
		_rng.randf_range(1.4, 2.4))


## Kurz begrüßen: Kopf zum anderen, nicken oder winken.
func greet(other: Npc) -> void:
	if not is_present() or is_busy() or _seated:
		if _seated:
			model.play_gesture(CharacterModel.Pose.NOD, 1.2)
		return
	if not _moving:
		_face(other.global_position - global_position)
	var far := global_position.distance_to(other.global_position) > 2.2
	model.play_gesture(CharacterModel.Pose.WAVE if far else CharacterModel.Pose.NOD, 1.6 if far else 1.2)


## Hinsetzen: umdrehen, dann rückwärts auf die Bank sinken (mit Vorbeugen).
func _sit_down(spot: StationSpot, instant: bool) -> void:
	_seated = true
	_seat_return = spot.get_approach_point()
	var seat := spot.global_position
	if instant:
		model.set_pose(CharacterModel.Pose.SIT)
		global_position = seat
		_busy = false
		return
	_busy = true
	var start := global_position
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(0.45 / director.speed_factor())  # erst zur Bank umdrehen
	_tween.tween_callback(func() -> void:
		model.set_pose(CharacterModel.Pose.SIT)
		_footsteps.play_named("creak", 2.0))
	_tween.tween_method(func(t: float) -> void:
		var eased := ease(t, -1.8)
		global_position = start.lerp(seat, eased) + Vector3.UP * sin(eased * PI) * 0.04,
		0.0, 1.0, 0.75 / director.speed_factor())
	_tween.tween_callback(func() -> void: _busy = false)


## Aufstehen: vorbeugen, abstützen, nach vorne hochkommen.
func _stand_up(then: Callable) -> void:
	_seated = false
	model.set_pose(CharacterModel.Pose.STAND)
	var target := _seat_return
	target.y = director.ground_height(target, target.y)
	var start := global_position
	_busy = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(0.2 / director.speed_factor())
	_tween.tween_method(func(t: float) -> void:
		var eased := ease(t, -1.6)
		global_position = start.lerp(target, eased) + Vector3.UP * sin(eased * PI) * 0.05,
		0.0, 1.0, 0.7 / director.speed_factor())
	_tween.tween_interval(0.15 / director.speed_factor())
	_tween.tween_callback(func() -> void:
		_busy = false
		then.call())


## Ein Zug fährt ein: Wer frei steht, winkt manchmal kurz.
func react_to_arrival(train: Train) -> void:
	if state != State.AT_STATION or _seated or is_busy() or _moving:
		return
	if global_position.distance_to(train.get_focus_point()) > 45.0 or _rng.randf() > 0.3:
		return
	_face(RailGeometry.flat(train.get_focus_point() - global_position))
	model.play_gesture(CharacterModel.Pose.WAVE, 2.0)


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
	if director.walk_graph == null:
		_walk_path(PackedVector3Array([global_position, target]), on_arrive, pace)
		return
	var path := director.walk_graph.find_path(global_position, target)
	# Lieblingsweg: auf längeren Wegen (Haus ↔ Bahnhof) gern über den Lieblingsplatz,
	# solange der Umweg nicht zu groß ist
	var via := profile.favourite_via if profile else Vector3.INF
	if via != Vector3.INF and global_position.distance_to(target) > 22.0 \
			and via.distance_to(global_position) > 4.0 and via.distance_to(target) > 4.0:
		var first := director.walk_graph.find_path(global_position, via)
		var second := director.walk_graph.find_path(via, target)
		var combined := first.duplicate()
		for i in range(1, second.size()):
			combined.append(second[i])
		if _path_length(combined) < _path_length(path) * 1.5:
			path = combined
	_walk_path(path, on_arrive, pace)


static func _path_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


func _walk_path(points: Array, on_arrive: Callable, pace := 1.0) -> void:
	if _seated:
		_stand_up(_walk_path.bind(points, on_arrive, pace))
		return
	_path = PackedVector3Array()
	for point: Vector3 in points:
		_path.append(Vector3(point.x, 0.0, point.z))  # gegangen wird in der Ebene, die Höhe folgt dem Boden
	_path_index = 1 if _path.size() > 1 else 0
	_on_arrive = on_arrive
	_pace = pace
	_moving = true
	if model.pose != CharacterModel.Pose.HANDS_BEHIND or _rng.randf() < 0.5:
		model.set_pose(CharacterModel.Pose.STAND)


## Über Trittstufen gehen: Punkte mit Höhe nacheinander ablaufen.
func _start_climb(points: Array, on_done: Callable, fade_out: bool) -> void:
	_climb = PackedVector3Array(points)
	_climb_index = 1
	_climb_done = on_done
	_climb_fade = fade_out
	_moving = false
	_busy = true


func _physics_process(delta: float) -> void:
	if director == null:
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_think()
	if not visible:
		return
	if not _climb.is_empty():
		_step_climb(delta)
	elif _moving and not _busy:
		_step_along_path(delta)
		# Boden nur neu abtasten, wenn man sich bewegt (spart Strahltests)
		_ground_timer -= 1
		if _ground_timer <= 0:
			_ground_timer = 2
			global_position.y = lerpf(global_position.y, director.ground_height(global_position, global_position.y),
				1.0 - exp(-30.0 * delta * 2.0))
	if _facing != Vector3.ZERO and _climb.is_empty():
		var yaw := atan2(-_facing.x, -_facing.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-TURN_SPEED * delta))
	_animate(delta)


## Figur aus der echten Bewegung animieren: Tempo, Beschleunigung, Drehung.
func _animate(delta: float) -> void:
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var speed := flat.distance_to(_last_flat) / maxf(delta, 0.0001)
	_last_flat = flat
	if _busy and _climb.is_empty():
		speed = 0.0  # Hinsetzen/Aufstehen: die Beine bleiben ruhig
	speed = lerpf(_last_speed, speed, 1.0 - exp(-10.0 * delta))
	_smoothed_accel = lerpf(_smoothed_accel, (speed - _last_speed) / maxf(delta, 0.0001), 1.0 - exp(-5.0 * delta))
	_last_speed = speed
	var turn := angle_difference(_last_yaw, rotation.y) / maxf(delta, 0.0001)
	_last_yaw = rotation.y
	model.move(speed, delta, 0.0, _smoothed_accel, turn)


func _process(delta: float) -> void:
	if _label and visible:
		var alpha := director.get_name_tag_alpha(self)
		if alpha <= 0.0 and not _label.visible:
			return
		var current := lerpf(_label.modulate.a, alpha, 1.0 - exp(-5.0 * delta))
		_label.modulate.a = current
		_label.outline_modulate.a = current * 0.8
		_label.visible = current > 0.02


## Ein Stück weitergehen.
func _step_along_path(delta: float) -> void:
	var target := _lane_point(_path_index)
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var to_target := target - flat_pos
	var distance := to_target.length()
	# Sanft anlaufen und vor dem Ziel etwas langsamer werden
	var ease_in := clampf(0.4 + _last_speed / maxf(walk_speed, 0.1), 0.4, 1.0)
	var remaining := distance + _remaining_path_length()
	var ease_out := clampf(remaining / 0.8, 0.35, 1.0)
	var speed := walk_speed * _pace * director.speed_factor() * minf(ease_in, ease_out)
	if distance > 0.001 and director.is_path_blocked(self, to_target / distance, PERSONAL_SPACE):
		# Höflich warten – und nach einem Moment seitlich ausweichen.
		_blocked_time += delta * director.speed_factor()
		if _blocked_time > 1.2:
			_blocked_time = 0.0
			_detour(to_target / distance)
		return
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
		return
	var direction := to_target / distance
	global_position += direction * step
	_facing = direction


func _remaining_path_length() -> float:
	var length := 0.0
	for i in range(_path_index, _path.size() - 1):
		length += _path[i].distance_to(_path[i + 1])
	return length


## Trittstufen: jede Stufe mit einem kleinen Schritt nach oben bzw. unten.
func _step_climb(delta: float) -> void:
	var from := _climb[_climb_index - 1]
	var to := _climb[_climb_index]
	var flat_to := Vector3(to.x, 0.0, to.z)
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var total := maxf(Vector3(from.x, 0.0, from.z).distance_to(flat_to), 0.05)
	var step := walk_speed * CLIMB_PACE * director.speed_factor() * delta
	var remaining := flat_pos.distance_to(flat_to)
	var direction := (flat_to - flat_pos).normalized() if remaining > 0.001 else Vector3.ZERO
	if direction != Vector3.ZERO:
		_facing = direction
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-10.0 * delta))
	if remaining <= step:
		global_position = to
		_climb_index += 1
		if _climb_fade and _climb_index == _climb.size() - 1:
			_kill_tween()
			_tween = create_tween()
			_tween.tween_method(model.set_fade, 1.0, 0.0, 0.45 / director.speed_factor())
		if _climb_index >= _climb.size():
			_climb = PackedVector3Array()
			_busy = false
			var callback := _climb_done
			_climb_done = Callable()
			if callback.is_valid():
				callback.call()
		return
	flat_pos += direction * step
	var progress := clampf(1.0 - (remaining - step) / total, 0.0, 1.0)
	# Stufen: Höhe wird früh im Schritt gewonnen (Fuß hoch, dann nachziehen)
	var rise := ease(progress, 0.6)
	global_position = Vector3(flat_pos.x, lerpf(from.y, to.y, rise) + sin(progress * PI) * 0.04, flat_pos.z)


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


func _face(direction: Vector3) -> void:
	var flat := RailGeometry.flat(direction)
	if flat.length_squared() > 0.0001:
		_facing = flat.normalized()


func _face_now(direction: Vector3) -> void:
	_face(direction)
	if _facing != Vector3.ZERO:
		rotation.y = atan2(-_facing.x, -_facing.z)
		_last_yaw = rotation.y


func _place_at(point: Vector3, snap := true) -> void:
	global_position = Vector3(point.x, point.y, point.z)
	if snap:
		global_position.y = director.ground_height(point, point.y)
	_last_flat = Vector3(point.x, 0.0, point.z)


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
	if _arrival_carry >= 0:
		# Angekommen im neuen Zuhause: Koffer abgestellt
		model.carry = _arrival_carry as CharacterModel.Carry
		_arrival_carry = -1


func _set_present(present: bool, fade_in := false) -> void:
	visible = present
	collision_layer = GameDefs.LAYER_CHARACTERS if present else 0
	if present:
		model.set_fade(0.0 if fade_in else 1.0)
		_last_flat = Vector3(global_position.x, 0.0, global_position.z)
		if fade_in:
			_kill_tween()
			_tween = create_tween()
			_tween.tween_method(model.set_fade, 0.0, 1.0, 0.8)


func _stop_everything() -> void:
	_kill_tween()
	_leave_spot()
	if director:
		director.leave_queues(self)
	_train = null
	_queue_ready = false
	_moving = false
	_busy = false
	_seated = false
	_behaviour = ""
	_path = PackedVector3Array()
	_climb = PackedVector3Array()
	if model:
		model.set_pose(CharacterModel.Pose.STAND)
		model.set_fade(1.0)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_leave_spot()
	if director and is_instance_valid(director):
		director.leave_queues(self)
