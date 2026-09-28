## Ein fahrender Zug.
##
## Der Zug bewegt sich entlang eines [TrainPath]: [member head] ist die Strecke
## seiner Spitze ab Wegbeginn. Jeder Simulationsschritt
## 1. sucht voraus nach Haltepunkten (Bahnsteig, rotes Signal, belegtes Gleis),
## 2. berechnet daraus und aus den Kurven eine Zielgeschwindigkeit (Bremskurve),
## 3. beschleunigt bzw. bremst sanft dorthin und meldet seine Belegung.
## Signale werden rechtzeitig beim Stellwerk angefordert – ohne freien Fahrweg
## hält der Zug vor dem Signal. Am Bahnsteig öffnen sich die Türen.
class_name Train
extends Node3D

signal arrived(train: Train)
signal departed(train: Train)

enum State { RUNNING, DWELLING, DONE }
## Reihenfolge am Bahnsteig: UNLOCKING → STEP_OUT → OPENING → WAITING → CLOSING → STEP_IN.
enum Dwell { OPENING, WAITING, CLOSING, UNLOCKING, STEP_OUT, STEP_IN }

## So weit schaut der Zug voraus (Meter).
const LOOKAHEAD := 240.0
## Abstand, mit dem vor einem roten Signal gehalten wird.
const SIGNAL_STOP_MARGIN := 4.0
## Abstand vor einem fremd belegten Gleis (Fahren auf Sicht).
const SIGHT_MARGIN := 14.0
## Zulässige Querbeschleunigung in Kurven (m/s²) – bestimmt die Kurvengeschwindigkeit.
const LATERAL_ACCEL := 0.9
## Auflösung der Geschwindigkeitsgrenzen entlang des Weges.
const LIMIT_STEP := 4.0
const CREEP_SPEED := 0.6
const DOOR_TIME := 1.8
## Türen entriegeln (kurzes Zischen) und Trittstufe aus- bzw. einfahren (Sekunden).
const UNLOCK_TIME := 0.6
const STEP_TIME := 1.2
## Auf den letzten Metern vor einem Halt bremst der Zug nur noch sanft und rollt aus.
const ROLL_OUT_DISTANCE := 10.0
const ROLL_OUT_BRAKING := 0.3
## So lange (Sekunden) steigert der Zug beim Anfahren seine Beschleunigung weich.
const START_RAMP_TIME := 4.0
## So lange (Simulationssekunden, 2 s = 1 Spielminute) halten ein- und aussteigende
## Fahrgäste die Türen höchstens über die Abfahrtszeit hinaus auf.
const MAX_DOOR_HOLD := 8.0

var train_id := 0
var entry: TimetableEntry
var train_type: TrainType
var network: RailNetwork
var interlocking: RailInterlocking
var dispatcher: Node
var path: TrainPath
var cars: Array[TrainCar] = []
var length := 0.0
## Strecke der Zugspitze auf dem Weg.
var head := 0.0
var speed := 0.0
var max_speed := 12.0
var state := State.RUNNING
var dwell_phase := Dwell.OPENING
## Haltepunkt der Zugspitze am Bahnsteig (-1 = kein Halt mehr ausstehend).
var stop_at := -1.0
var platform_number := 0
var platform_stop: PlatformStop
## Ab dieser Strecke ist der Zug ganz im Zieltunnel und verschwindet.
var despawn_at := INF
## Hier verlässt die Zugspitze den Starttunnel.
var emerge_at := -1.0
## Kurzer Zustandstext, z.B. warum der Zug wartet.
var status := ""
var arrived_at := -1.0
var departed_at := -1.0
## Signale, für die ein Fahrweg gewährt wurde.
var granted: Dictionary[int, bool] = {}

var _limits := PackedFloat32Array()
var _occupied: Array[int] = []
var _stop_point := INF
var _phase_time := 0.0
var _waited := 0.0
var _door_side := 1.0
var _horn_pending := false
var _brake_played := false
var _emerged := false
var _visual_head := 0.0
var _replan_cooldown := 0.0
var _rolling: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
## Fahrgäste, die gerade ein- oder aussteigen (Kennung → true).
var _door_holds: Dictionary[int, bool] = {}
var _hold_time := 0.0
var _drive_time := 0.0
var _squeal_played := false
## Lade- und Entladearbeiten (Güterbahnhof): Solange ein Eintrag besteht, fährt der Zug nicht ab.
var _cargo_holds: Dictionary[String, bool] = {}
var _cargo_hold_time := 0.0


## Richtet den Zug ein und baut seine Fahrzeuge.
func setup(p_id: int, p_entry: TimetableEntry, p_path: TrainPath, p_dispatcher: Node,
		p_network: RailNetwork, p_interlocking: RailInterlocking, materials: Dictionary) -> void:
	train_id = p_id
	entry = p_entry
	train_type = entry.train_type
	path = p_path
	dispatcher = p_dispatcher
	network = p_network
	interlocking = p_interlocking
	max_speed = entry.get_max_speed()
	name = "Train_%s" % entry.train_number.replace(" ", "_")

	var offset := 0.0
	var consist := train_type.consist
	for i in consist.size():
		var car := TrainCar.new()
		add_child(car)
		car.build(consist[i], train_type, i == 0, i == consist.size() - 1, materials, i)
		car.offset_from_head = offset
		offset += car.length + TrainMeshes.COUPLING_GAP
		cars.append(car)
	length = offset - TrainMeshes.COUPLING_GAP

	head = length + 0.5
	_visual_head = head
	emerge_at = path.end_of(0)
	_compute_limits()

	_rolling = _make_player(cars[0], SoundLibrary.get_sound("rolling"), -14.0, 60.0)
	_voice = _make_player(cars[0], null, -6.0, 120.0)


## Setzt den Bahnsteighalt (Strecke der Zugspitze) und das Ziel im Tunnel.
func set_stop(stop_distance: float, stop: PlatformStop, platform: int) -> void:
	stop_at = stop_distance
	platform_stop = stop
	platform_number = platform


func set_despawn(distance: float) -> void:
	despawn_at = distance


## Ein Simulationsschritt (Spielzeit [param dt] in Sekunden).
func simulate(dt: float) -> void:
	if state == State.DONE:
		return
	if not path.is_valid():
		dispatcher.retire(self, "Strecke unterbrochen")
		return
	_replan_cooldown -= dt
	if state == State.DWELLING:
		_update_dwell(dt)
		return

	var target := _target_speed()
	# Anfahren: die Zugkraft setzt weich ein statt schlagartig
	_drive_time = _drive_time + dt if speed > 0.05 or target > speed else 0.0
	var start_ramp := 0.3 + 0.7 * smoothstep(0.0, START_RAMP_TIME, _drive_time)
	var rate := train_type.acceleration * start_ramp if target > speed else train_type.braking * 1.8
	speed = move_toward(speed, target, rate * dt)
	var next_head := head + speed * dt
	if next_head >= _stop_point:
		next_head = maxf(head, _stop_point)
		speed = 0.0
	head = next_head
	update_occupancy()

	if stop_at >= 0.0 and head >= stop_at - 0.02 and speed <= 0.01:
		_arrive()
	_update_sounds(target)
	if head >= despawn_at:
		dispatcher.retire(self, "")


## Wagen positionieren, Räder drehen, Schnee aufwirbeln (einmal pro Bild).
func update_visuals(_delta: float) -> void:
	var moved := head - _visual_head
	var previous := _visual_head
	_visual_head = head
	var clacks := WorldClock.time_scale <= 2.0 and moved > 0.0
	for car in cars:
		var front := head - car.offset_from_head - (car.length * 0.5 - car.bogie_offset)
		var rear := front - car.bogie_offset * 2.0
		car.place(path.position_at(front), path.direction_at(front), path.position_at(rear), path.direction_at(rear))
		car.roll(moved)
		if clacks:
			var old_front := front - moved
			if path.index_at(maxf(old_front, 0.0)) != path.index_at(maxf(front, 0.0)):
				car.play_clack(speed / maxf(max_speed, 1.0))
	cars[0].set_snow_spray(speed)
	cars[0].set_exhaust(speed, speed > 0.05 and _drive_time < START_RAMP_TIME * 1.5)
	if previous < emerge_at + 6.0 and head >= emerge_at + 6.0 and not _emerged:
		_emerged = true
		_play_voice("horn", -12.0, train_type.horn_pitch * 1.05)


func set_dark(dark: bool) -> void:
	for car in cars:
		car.set_light_level(dark)


func get_rear() -> float:
	return head - length


## Zugmitte – dorthin schaut die Kamera beim Mitfahren.
func get_focus_point() -> Vector3:
	return path.position_at(clampf(head - length * 0.5, 0.0, path.total_length))


func get_occupied_segments() -> Array[int]:
	return _occupied


## Kurzinfo für die Anzeige, z.B. "RE 201 · Nordtal → Südtal · 42 km/h · Gleis 1".
func get_info_text() -> String:
	var text := "%s · %s · %d km/h" % [entry.train_number, entry.train_name, roundi(speed * 3.6)]
	if entry.stops and platform_number > 0:
		text += " · Gleis %d" % platform_number
	if state == State.DWELLING and is_departure_held():
		text += " · wird be- und entladen"
	elif state == State.DWELLING:
		text += " · hält"
	elif speed < 0.1 and status != "":
		text += " · wartet: " + status
	return text


# --- Fahrdynamik ---------------------------------------------------------------

## Zielgeschwindigkeit aus Höchstgeschwindigkeit, Kurven und Bremskurve zum nächsten Halt.
func _target_speed() -> float:
	var braking := train_type.braking
	var target := max_speed
	# Kurven: auch unter dem Zug (der ganze Zug muss langsam genug sein) und voraus
	var first := maxi(0, int((head - length) / LIMIT_STEP))
	var last := mini(_limits.size() - 1, int((head + LOOKAHEAD) / LIMIT_STEP))
	for i in range(first, last + 1):
		var distance := i * LIMIT_STEP - head
		var allowed := _limits[i]
		if distance > 0.0:
			allowed = sqrt(allowed * allowed + 2.0 * braking * distance)
		target = minf(target, allowed)
	_stop_point = _find_stop_point()
	return minf(target, _approach_speed(_stop_point - head, braking))


## Geschwindigkeit, mit der man in [param distance] Metern gerade noch sanft zum Stehen kommt.
func _approach_speed(distance: float, braking: float) -> float:
	if distance <= 0.0:
		return 0.0
	# Zweistufige Bremskurve: normal bremsen, auf den letzten Metern sanft ausrollen.
	var soft := braking * ROLL_OUT_BRAKING
	var d := maxf(distance - 0.1, 0.0)
	var allowed: float
	if d <= ROLL_OUT_DISTANCE:
		allowed = sqrt(2.0 * soft * d)
	else:
		allowed = sqrt(2.0 * soft * ROLL_OUT_DISTANCE + 2.0 * braking * (d - ROLL_OUT_DISTANCE))
	if distance > 0.4:
		return maxf(allowed, CREEP_SPEED * 0.5)
	return maxf(0.12, distance * 1.2)


## Nächster Punkt, an dem der Zug halten muss (Bahnsteig, Signal, belegtes Gleis, Wegende).
func _find_stop_point() -> float:
	var stop := path.total_length - 0.5
	if stop_at >= 0.0:
		stop = minf(stop, stop_at)
	var index := path.index_at(head)
	for j in range(index, path.segment_ids.size() - 1):
		var node_distance := path.end_of(j)
		if node_distance - head > LOOKAHEAD:
			break
		var next_id := path.segment_ids[j + 1]
		var rail_signal := network.get_signal_for(path.exit_node(j), next_id)
		if rail_signal and not _is_cleared(rail_signal, j + 1, node_distance):
			stop = minf(stop, node_distance - SIGNAL_STOP_MARGIN)
			break
		var other := interlocking.get_train_on_segment(next_id)
		if (other >= 0 and other != train_id) or interlocking.is_segment_test_occupied(next_id):
			status = "Gleis voraus belegt"
			stop = minf(stop, node_distance - SIGHT_MARGIN)
			break
	return stop


## Darf der Zug an diesem Signal vorbei? Fordert bei Bedarf den Fahrweg an.
func _is_cleared(rail_signal: RailSignal, path_index: int, node_distance: float) -> bool:
	var remaining := path.ids_from(path_index)
	if granted.get(rail_signal.id, false) and interlocking.is_route_for_path(rail_signal.id, remaining, train_id):
		return true
	granted.erase(rail_signal.id)
	# Erst am Bahnsteig halten, dann die Ausfahrt anfordern
	if stop_at >= 0.0 and node_distance > stop_at + 0.5:
		return false
	var reason := interlocking.request_route(rail_signal.id, remaining, train_id)
	if reason == "":
		granted[rail_signal.id] = true
		status = ""
		dispatcher.on_route_granted(self, remaining)
		return true
	status = reason
	if (stop_at >= 0.0 or not entry.stops) and _replan_cooldown <= 0.0:
		_replan_cooldown = 3.0
		dispatcher.try_other_platform(self)
	return false


## Kurvengeschwindigkeit entlang des Weges vorausberechnen (v = √(a·r)).
func _compute_limits() -> void:
	_limits = PackedFloat32Array()
	var count := int(path.total_length / LIMIT_STEP) + 2
	for i in count:
		var s := i * LIMIT_STEP
		var a := RailGeometry.flat(path.position_at(clampf(s - LIMIT_STEP, 0.0, path.total_length)))
		var b := RailGeometry.flat(path.position_at(clampf(s, 0.0, path.total_length)))
		var c := RailGeometry.flat(path.position_at(clampf(s + LIMIT_STEP, 0.0, path.total_length)))
		var area := (b - a).cross(c - a).length() * 0.5
		var limit := max_speed
		if area > 0.0005:
			var radius := a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (4.0 * area)
			limit = minf(limit, sqrt(LATERAL_ACCEL * radius))
		_limits.append(limit)


## Nach einem Gleiswechsel (anderer Bahnsteig) die Grenzen neu berechnen.
func path_changed() -> void:
	_compute_limits()


## Meldet dem Stellwerk die Gleise unter dem Zug (auch sofort beim Einsetzen).
func update_occupancy() -> void:
	var segments := path.segments_between(head - length, head)
	if segments != _occupied:
		_occupied = segments
		interlocking.set_train_occupancy(train_id, segments)


# --- Bahnhofshalt -------------------------------------------------------------------

## Halt am Bahnsteig. Ablauf: entriegeln → Trittstufe fährt aus → Türen öffnen →
## ein-/aussteigen → Türen schließen → Trittstufe fährt ein → sanft anfahren.
func _arrive() -> void:
	state = State.DWELLING
	dwell_phase = Dwell.UNLOCKING
	_phase_time = 0.0
	stop_at = -1.0
	speed = 0.0
	arrived_at = WorldClock.time_of_day
	_door_side = _platform_side()
	_play_on_door_cars("door_unlock")
	arrived.emit(self)


func _update_dwell(dt: float) -> void:
	_phase_time += dt
	match dwell_phase:
		Dwell.UNLOCKING:
			if _phase_time >= UNLOCK_TIME:
				_next_dwell_phase(Dwell.STEP_OUT)
				_play_on_door_cars("stairs_out")
		Dwell.STEP_OUT:
			_set_steps(_phase_time / STEP_TIME)
			if _phase_time >= STEP_TIME:
				_set_steps(1.0)
				_next_dwell_phase(Dwell.OPENING)
				for car in cars:
					if car.has_doors():
						car.play_door_sound(true)
		Dwell.OPENING:
			_set_doors(_phase_time / DOOR_TIME)
			if _phase_time >= DOOR_TIME:
				dwell_phase = Dwell.WAITING
				_waited = 0.0
		Dwell.WAITING:
			_waited += dt
			if _waited >= train_type.min_dwell_seconds and _departure_due() and not _doors_held(dt) \
					and not _cargo_held(dt):
				_next_dwell_phase(Dwell.CLOSING)
				for car in cars:
					if car.has_doors():
						car.play_door_sound(false)
		Dwell.CLOSING:
			_set_doors(1.0 - _phase_time / DOOR_TIME)
			if _phase_time >= DOOR_TIME:
				_set_doors(0.0)
				_next_dwell_phase(Dwell.STEP_IN)
				_play_on_door_cars("stairs_in")
		Dwell.STEP_IN:
			_set_steps(1.0 - _phase_time / STEP_TIME)
			if _phase_time >= STEP_TIME:
				_set_steps(0.0)
				state = State.RUNNING
				departed_at = WorldClock.time_of_day
				_horn_pending = true
				_brake_played = false
				_drive_time = 0.0
				_squeal_played = false
				departed.emit(self)


func _next_dwell_phase(phase: Dwell) -> void:
	dwell_phase = phase
	_phase_time = 0.0


func _set_steps(amount: float) -> void:
	for car in cars:
		if car.has_doors():
			car.set_steps(amount, _door_side)


func _play_on_door_cars(sound_name: String) -> void:
	for car in cars:
		if car.has_doors():
			car.play_mechanism_sound(sound_name)


## Sind die Türen zum Bahnsteig so weit offen, dass man ein- und aussteigen kann?
func doors_open() -> bool:
	if state != State.DWELLING or platform_stop == null:
		return false
	return dwell_phase == Dwell.WAITING or (dwell_phase == Dwell.OPENING and _phase_time > DOOR_TIME * 0.6)


## Mitten aller Türen auf der Bahnsteigseite (Weltkoordinaten, auf Wagenbodenhöhe).
func get_door_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if state != State.DWELLING:
		return points
	for car in cars:
		points.append_array(car.get_door_centers(_door_side))
	return points


## Wege durch alle Türen auf der Bahnsteigseite über die Trittstufen (siehe
## [method TrainCar.get_boarding_paths]); dazu "along" = Richtung entlang des Zuges.
func get_door_paths() -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	if state != State.DWELLING:
		return paths
	for car in cars:
		if not car.has_doors():
			continue
		var along := RailGeometry.flat(car.global_basis.z).normalized()
		for door in car.get_boarding_paths(_door_side):
			door["along"] = along
			paths.append(door)
	return paths


## Wie weit die Trittstufen ausgefahren sind (0..1, erster Wagen mit Türen).
func get_step_amount() -> float:
	for car in cars:
		if car.has_doors():
			return car.get_step_amount()
	return 0.0


## Richtung vom Gleis zum Bahnsteig (Draufsicht), oder ZERO ohne Bahnsteig.
func get_platform_direction() -> Vector3:
	return platform_stop.get_platform_direction() if platform_stop else Vector3.ZERO


## Ein Fahrgast steigt ein oder aus: Die Türen bleiben offen, bis er
## [method release_doors] ruft (höchstens [constant MAX_DOOR_HOLD] Sekunden).
func hold_doors(passenger_id: int) -> void:
	_door_holds[passenger_id] = true


func release_doors(passenger_id: int) -> void:
	_door_holds.erase(passenger_id)


func is_held() -> bool:
	return not _door_holds.is_empty()


## Wie lange Fahrgäste die Türen schon über die Abfahrtszeit hinaus aufhalten (Simulationssekunden).
func get_hold_time() -> float:
	return _hold_time


func _doors_held(dt: float) -> bool:
	if _door_holds.is_empty():
		_hold_time = 0.0
		return false
	_hold_time += dt
	return _hold_time < MAX_DOOR_HOLD


## Der Güterbahnhof lädt: Der Zug wartet mit der Abfahrt, bis [method release_departure]
## gerufen wird (Sicherheitsgrenze [constant MAX_CARGO_HOLD]).
func hold_departure(key: String) -> void:
	_cargo_holds[key] = true


func release_departure(key: String) -> void:
	_cargo_holds.erase(key)


func is_departure_held() -> bool:
	return not _cargo_holds.is_empty()


## Höchstens so lange (Simulationssekunden, ≈ 3 Spielstunden) wartet ein Zug auf Ladearbeiten.
const MAX_CARGO_HOLD := 360.0


func _cargo_held(dt: float) -> bool:
	if _cargo_holds.is_empty():
		return false
	_cargo_hold_time += dt
	return _cargo_hold_time < MAX_CARGO_HOLD


func _departure_due() -> bool:
	var hours_left := fposmod(entry.get_departure_hours() - WorldClock.time_of_day + 12.0, 24.0) - 12.0
	return hours_left <= 0.0


func _set_doors(amount: float) -> void:
	for car in cars:
		car.set_doors(amount, _door_side)


## Auf welcher Seite (±1, in Fahrtrichtung) liegt der Bahnsteig?
func _platform_side() -> float:
	if platform_stop == null:
		return 1.0
	var direction := path.direction_at(head)
	var right := direction.cross(Vector3.UP)
	return 1.0 if right.dot(platform_stop.get_platform_direction()) >= 0.0 else -1.0


# --- Klang --------------------------------------------------------------------

func _update_sounds(target: float) -> void:
	var level := clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)
	if speed > 0.3:
		if not _rolling.playing:
			SoundLibrary.play(_rolling)
		_rolling.volume_db = -20.0 + level * 12.0
		_rolling.pitch_scale = 0.75 + level * 0.45
	elif _rolling.playing:
		_rolling.stop()
	if _horn_pending and speed > 0.4:
		_horn_pending = false
		_play_voice("horn", -7.0, train_type.horn_pitch)
	if not _brake_played and speed > 2.0 and speed < 9.0 and target < speed - 0.3 and _stop_point - head < 35.0:
		_brake_played = true
		_play_voice("brake", -12.0, randf_range(0.95, 1.05))
	# Ganz zum Schluss ein leises, kurzes Quietschen der Bremsen
	if not _squeal_played and speed > 0.15 and speed < 1.3 and target < speed and _stop_point - head < 4.0:
		_squeal_played = true
		_play_voice("brake_squeal", -19.0, randf_range(0.96, 1.05))


func _play_voice(sound_name: String, volume: float, pitch: float) -> void:
	if WorldClock.time_scale > 2.0:
		return
	_voice.stream = SoundLibrary.get_sound(sound_name)
	_voice.volume_db = volume
	_voice.pitch_scale = pitch
	SoundLibrary.play(_voice)


func _make_player(parent: Node3D, stream: AudioStream, volume: float, distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume
	player.max_distance = distance
	player.unit_size = 8.0
	parent.add_child(player)
	SoundLibrary.stop_on_exit(player)
	return player
