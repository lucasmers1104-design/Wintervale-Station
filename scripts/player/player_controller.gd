## Spielfigur zum Erkunden – umschaltbar zwischen Third- und First-Person.
##
## Aufbau (siehe scenes/player/player.tscn):
##   Model       – die Figur ([CharacterModel]), dreht sich in Laufrichtung
##   CameraYaw   – horizontale Blickrichtung (Maus X)
##     CameraPitch – vertikale Blickrichtung (Maus Y)
##       SpringArm3D – Kameraabstand; 0 m = First-Person (Augenhöhe)
##         Camera3D
##
## Bewegung ist bewusst gemächlich und weich beschleunigt (gemütliches Spiel).
class_name PlayerController
extends CharacterBody3D

signal perspective_changed(first_person: bool)

const SAVE_ID := "player"
## Fällt die Figur unter diese Höhe, wird sie zum Startpunkt zurückgesetzt.
const RESPAWN_DEPTH := -40.0

@export_group("Bewegung")
@export var walk_speed := 2.8
@export var sprint_speed := 5.4
@export var acceleration := 10.0
@export var jump_velocity := 4.6
@export var turn_speed := 8.0

@export_group("Kamera")
@export var mouse_sensitivity := 0.0025
@export var third_person_distance := 4.0
@export var min_distance := 2.0
@export var max_distance := 9.0
@export var zoom_step := 0.6
@export var third_person_fov := 68.0
@export var first_person_fov := 75.0
## Wie weich die Kamera der Figur folgt (kleiner = mehr Verzögerung).
@export var camera_follow := 9.0
## Wie weich die Kamera der Maus folgt (groß = direkter).
@export var look_smoothing := 22.0

## Wenn false, reagiert die Figur nicht auf Eingaben (z.B. in der Vogelperspektive).
var input_enabled := true
var first_person := false

var _pitch := -0.3
var _yaw := 0.0
var _smoothed_pitch := -0.3
var _target_distance := 4.5
var _footsteps: FootstepPlayer
var _last_speed := 0.0
var _smoothed_accel := 0.0
var _last_model_yaw := 0.0
var _idle_time := 0.0
var _next_gesture := 8.0
var _spawn_point := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _model: CharacterModel = $Model
@onready var _camera_yaw: Node3D = $CameraYaw
@onready var _camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var _spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var _camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	add_to_group(&"player")
	_target_distance = third_person_distance
	_spring_arm.spring_length = _target_distance
	_spring_arm.add_excluded_object(get_rid())
	_camera_pitch.rotation.x = _pitch
	_spawn_point = global_position
	# Die Kamera hängt nicht starr an der Figur, sondern folgt ihr weich (siehe _process).
	_camera_yaw.top_level = true
	snap_camera()
	_footsteps = FootstepPlayer.new()
	add_child(_footsteps)
	_model.footstep.connect(_footsteps.play_step)
	_apply_perspective()
	# Sprechen, Aufheben, Übergeben (Taste E) – Etappe 10
	var interaction := PlayerInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and GameInput.is_mouse_captured():
		var motion := (event as InputEventMouseMotion).screen_relative
		_yaw -= motion.x * mouse_sensitivity
		_set_pitch(_pitch - motion.y * mouse_sensitivity)
	elif event.is_action_pressed(&"toggle_perspective"):
		set_first_person(not first_person)
	elif event.is_action_pressed(&"zoom_in") and not first_person:
		_target_distance = maxf(min_distance, _target_distance - zoom_step)
	elif event.is_action_pressed(&"zoom_out") and not first_person:
		_target_distance = minf(max_distance, _target_distance + zoom_step)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_vector := Vector2.ZERO
	var wants_sprint := false
	if input_enabled:
		input_vector = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		wants_sprint = Input.is_action_pressed(&"sprint")
		if Input.is_action_just_pressed(&"jump") and is_on_floor():
			velocity.y = jump_velocity

	# Bewegung relativ zur Blickrichtung der Kamera
	var direction := Basis(Vector3.UP, _camera_yaw.rotation.y) * Vector3(input_vector.x, 0.0, input_vector.y)
	var target_velocity := direction * (sprint_speed if wants_sprint else walk_speed)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(target_velocity, 1.0 - exp(-acceleration * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_turn_model(direction, delta)

	if global_position.y < RESPAWN_DEPTH:
		respawn()


func _process(delta: float) -> void:
	var arm_target := 0.0 if first_person else _target_distance
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, arm_target, 1.0 - exp(-8.0 * delta))
	# Blickrichtung: minimal geglättet, damit nichts ruckelt, aber direkt genug zum Umschauen.
	var look := 1.0 - exp(-look_smoothing * delta)
	_camera_yaw.rotation.y = lerp_angle(_camera_yaw.rotation.y, _yaw, look)
	_smoothed_pitch = lerpf(_smoothed_pitch, _pitch, look)
	_camera_pitch.rotation.x = _smoothed_pitch
	# Position: in der Ich-Perspektive fest am Kopf, sonst mit leichter Verzögerung.
	var anchor := _camera_anchor()
	if first_person:
		_camera_yaw.global_position = anchor
	else:
		_camera_yaw.global_position = _camera_yaw.global_position.lerp(anchor, 1.0 - exp(-camera_follow * delta))
	_animate_walk(delta)


func get_camera() -> Camera3D:
	return _camera


func get_model() -> CharacterModel:
	return _model


## Blickrichtung der Figur (waagrecht).
func get_facing() -> Vector3:
	var forward := -_model.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


## Horizontale Blickrichtung der Kamera (für den Übergang zur Vogelperspektive).
func get_view_yaw() -> float:
	return _camera_yaw.rotation.y


func set_spawn_point(point: Vector3) -> void:
	_spawn_point = point


## Kamera ohne Nachziehen direkt an die Figur setzen (Spawn, Laden, Zurücksetzen).
func snap_camera() -> void:
	_camera_yaw.global_position = _camera_anchor()
	_camera_yaw.rotation.y = _yaw
	_smoothed_pitch = _pitch
	_camera_pitch.rotation.x = _pitch


func _camera_anchor() -> Vector3:
	return global_position + Vector3(0.0, CharacterModel.EYE_HEIGHT, 0.0)


func respawn() -> void:
	global_position = _spawn_point + Vector3.UP
	velocity = Vector3.ZERO
	snap_camera()


func set_first_person(enabled: bool) -> void:
	if enabled == first_person:
		return
	first_person = enabled
	_apply_perspective()
	perspective_changed.emit(first_person)


# --- Speichern -------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {
		"position": SaveUtils.vec3_to_array(global_position),
		"model_yaw": _model.rotation.y,
		"camera_yaw": _yaw,
		"camera_pitch": _pitch,
		"camera_distance": _target_distance,
		"first_person": first_person,
	}


func load_state(data: Dictionary) -> void:
	global_position = SaveUtils.array_to_vec3(data.get("position"), global_position)
	velocity = Vector3.ZERO
	_model.rotation.y = float(data.get("model_yaw", _model.rotation.y))
	_yaw = float(data.get("camera_yaw", _yaw))
	_camera_yaw.rotation.y = _yaw
	_target_distance = clampf(float(data.get("camera_distance", _target_distance)), min_distance, max_distance)
	set_first_person(bool(data.get("first_person", first_person)))
	_set_pitch(float(data.get("camera_pitch", _pitch)))
	snap_camera()


# --- Intern ----------------------------------------------------------------

func _apply_perspective() -> void:
	# In First-Person wird die Figur unsichtbar, wirft aber weiter ihren Schatten.
	_model.set_shadows_only(first_person)
	_camera.fov = first_person_fov if first_person else third_person_fov
	_set_pitch(_pitch)


func _set_pitch(value: float) -> void:
	var limits := Vector2(-1.45, 1.45) if first_person else Vector2(-1.2, 0.45)
	_pitch = clampf(value, limits.x, limits.y)


func _turn_model(direction: Vector3, delta: float) -> void:
	var target_yaw := _model.rotation.y
	if first_person:
		target_yaw = _camera_yaw.rotation.y
	elif direction.length_squared() > 0.01:
		target_yaw = atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Animation aus der echten Bewegung: Tempo, Sprintanteil, Beschleunigung und
## Drehung werden an die Figur gegeben – sie federt Start, Stopp und Kurven selbst weich ab.
## Steht die Figur eine Weile still, macht sie ab und zu eine kleine Geste.
func _animate_walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		speed *= 0.3
	var accel := (speed - _last_speed) / maxf(delta, 0.0001)
	_smoothed_accel = lerpf(_smoothed_accel, accel, 1.0 - exp(-6.0 * delta))
	_last_speed = speed
	var turn_rate := angle_difference(_last_model_yaw, _model.rotation.y) / maxf(delta, 0.0001)
	_last_model_yaw = _model.rotation.y
	var sprint := clampf((speed - walk_speed) / maxf(sprint_speed - walk_speed, 0.1), 0.0, 1.0)
	_model.move(speed, delta, sprint, _smoothed_accel, turn_rate if not first_person else 0.0)
	_update_idle_gestures(delta, speed)


func _update_idle_gestures(delta: float, speed: float) -> void:
	if speed > 0.2 or not input_enabled or first_person:
		_idle_time = 0.0
		_next_gesture = randf_range(7.0, 11.0)
		return
	_idle_time += delta
	if _idle_time >= _next_gesture:
		_next_gesture = _idle_time + randf_range(10.0, 18.0)
		var gestures := [CharacterModel.Pose.WARM_HANDS, CharacterModel.Pose.CHECK_WATCH, CharacterModel.Pose.STRETCH]
		var gesture: CharacterModel.Pose = gestures[randi() % gestures.size()]
		_model.play_gesture(gesture, 2.6 if gesture == CharacterModel.Pose.STRETCH else 2.2)
