## Spielfigur zum Erkunden – umschaltbar zwischen Third- und First-Person.
##
## Aufbau (siehe scenes/player/player.tscn):
##   Model       – die Low-Poly-Figur, dreht sich in Laufrichtung
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
@export var walk_speed := 3.2
@export var sprint_speed := 6.0
@export var acceleration := 10.0
@export var jump_velocity := 4.6
@export var turn_speed := 10.0

@export_group("Kamera")
@export var mouse_sensitivity := 0.0025
@export var third_person_distance := 4.5
@export var min_distance := 2.0
@export var max_distance := 9.0
@export var zoom_step := 0.6
@export var third_person_fov := 68.0
@export var first_person_fov := 75.0

## Wenn false, reagiert die Figur nicht auf Eingaben (z.B. in der Vogelperspektive).
var input_enabled := true
var first_person := false

var _pitch := -0.3
var _target_distance := 4.5
var _walk_phase := 0.0
var _spawn_point := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model_meshes: Array[MeshInstance3D] = []

@onready var _model: Node3D = $Model
@onready var _hip_left: Node3D = $Model/HipLeft
@onready var _hip_right: Node3D = $Model/HipRight
@onready var _shoulder_left: Node3D = $Model/ShoulderLeft
@onready var _shoulder_right: Node3D = $Model/ShoulderRight
@onready var _camera_yaw: Node3D = $CameraYaw
@onready var _camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var _spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var _camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		_model_meshes.append(node as MeshInstance3D)
	_target_distance = third_person_distance
	_spring_arm.spring_length = _target_distance
	_spring_arm.add_excluded_object(get_rid())
	_camera_pitch.rotation.x = _pitch
	_spawn_point = global_position
	_apply_perspective()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and GameInput.is_mouse_captured():
		var motion := (event as InputEventMouseMotion).screen_relative
		_camera_yaw.rotate_y(-motion.x * mouse_sensitivity)
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
	_animate_walk(delta)


func get_camera() -> Camera3D:
	return _camera


## Horizontale Blickrichtung der Kamera (für den Übergang zur Vogelperspektive).
func get_view_yaw() -> float:
	return _camera_yaw.rotation.y


func set_spawn_point(point: Vector3) -> void:
	_spawn_point = point


func respawn() -> void:
	global_position = _spawn_point + Vector3.UP
	velocity = Vector3.ZERO


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
		"camera_yaw": _camera_yaw.rotation.y,
		"camera_pitch": _pitch,
		"camera_distance": _target_distance,
		"first_person": first_person,
	}


func load_state(data: Dictionary) -> void:
	global_position = SaveUtils.array_to_vec3(data.get("position"), global_position)
	velocity = Vector3.ZERO
	_model.rotation.y = float(data.get("model_yaw", _model.rotation.y))
	_camera_yaw.rotation.y = float(data.get("camera_yaw", _camera_yaw.rotation.y))
	_target_distance = clampf(float(data.get("camera_distance", _target_distance)), min_distance, max_distance)
	set_first_person(bool(data.get("first_person", first_person)))
	_set_pitch(float(data.get("camera_pitch", _pitch)))


# --- Intern ----------------------------------------------------------------

func _apply_perspective() -> void:
	# In First-Person wird die Figur unsichtbar, wirft aber weiter ihren Schatten.
	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in _model_meshes:
		mesh.cast_shadow = shadow_mode
	_camera.fov = first_person_fov if first_person else third_person_fov
	_set_pitch(_pitch)


func _set_pitch(value: float) -> void:
	var limits := Vector2(-1.45, 1.45) if first_person else Vector2(-1.2, 0.45)
	_pitch = clampf(value, limits.x, limits.y)
	_camera_pitch.rotation.x = _pitch


func _turn_model(direction: Vector3, delta: float) -> void:
	var target_yaw := _model.rotation.y
	if first_person:
		target_yaw = _camera_yaw.rotation.y
	elif direction.length_squared() > 0.01:
		target_yaw = atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Einfache prozedurale Laufanimation: Beine und Arme pendeln, Körper wippt.
func _animate_walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(speed / walk_speed, 0.0, 1.0) if is_on_floor() else 0.3
	_walk_phase += delta * speed * 2.4
	var swing := sin(_walk_phase) * 0.55 * amount
	_hip_left.rotation.x = swing
	_hip_right.rotation.x = -swing
	_shoulder_left.rotation.x = -swing * 0.8
	_shoulder_right.rotation.x = swing * 0.8
	_model.position.y = absf(sin(_walk_phase)) * 0.05 * amount
