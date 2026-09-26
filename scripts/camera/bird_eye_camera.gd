## Kamera für die Vogelperspektive (Bauen & Management).
##
## Die Kamera kreist um einen Fokuspunkt auf dem Boden. Alle Bewegungen
## laufen über Zielwerte, denen die Kamera weich folgt – nichts ruckelt.
##
## Steuerung: WASD verschieben, Q/E drehen, Mausrad zoomen,
## mittlere Maustaste ziehen = drehen & neigen, rechte Maustaste ziehen = verschieben.
class_name BirdEyeCamera
extends Node3D

const SAVE_ID := "bird_eye_camera"

@export var terrain: LowPolyTerrain

@export_group("Bewegung")
## Verschiebegeschwindigkeit als Anteil der Zoomdistanz pro Sekunde.
@export var pan_speed := 1.0
@export var rotate_speed := 1.6
@export var drag_sensitivity := 0.005
@export var smoothing := 8.0

@export_group("Zoom")
@export var min_distance := 12.0
@export var max_distance := 110.0
@export var zoom_factor := 1.15

@export_group("Neigung")
@export_range(10.0, 89.0) var min_pitch_degrees := 25.0
@export_range(10.0, 89.0) var max_pitch_degrees := 80.0

## Nur wenn aktiv, reagiert die Kamera auf Eingaben.
var active := false

var _focus := Vector3.ZERO
var _target_focus := Vector3.ZERO
var _yaw := 0.0
var _target_yaw := 0.0
var _pitch := deg_to_rad(52.0)
var _target_pitch := deg_to_rad(52.0)
var _distance := 45.0
var _target_distance := 45.0
var _drag_rotating := false
var _drag_panning := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"zoom_in"):
		_target_distance = maxf(min_distance, _target_distance / zoom_factor)
	elif event.is_action_pressed(&"zoom_out"):
		_target_distance = minf(max_distance, _target_distance * zoom_factor)
	elif event.is_action(&"camera_drag_rotate"):
		_drag_rotating = event.is_pressed()
	elif event.is_action(&"camera_drag_pan"):
		_drag_panning = event.is_pressed()
	elif event is InputEventMouseMotion:
		var relative := (event as InputEventMouseMotion).relative
		if _drag_rotating:
			_target_yaw -= relative.x * drag_sensitivity
			_target_pitch = clampf(_target_pitch + relative.y * drag_sensitivity,
				deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
		elif _drag_panning:
			# "Boden greifen": der Boden folgt der Maus.
			var meters_per_pixel := _distance * 0.0016
			_target_focus -= Basis(Vector3.UP, _yaw) * Vector3(relative.x, 0.0, relative.y) * meters_per_pixel


func _process(delta: float) -> void:
	if active:
		var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		_target_focus += Basis(Vector3.UP, _target_yaw) * Vector3(input_vector.x, 0.0, input_vector.y) \
			* _distance * pan_speed * delta
		_target_yaw += Input.get_axis(&"camera_rotate_right", &"camera_rotate_left") * rotate_speed * delta

	if terrain:
		var limit := terrain.get_half_extent() * 0.7
		_target_focus.x = clampf(_target_focus.x, -limit, limit)
		_target_focus.z = clampf(_target_focus.z, -limit, limit)

	var weight := 1.0 - exp(-smoothing * delta)
	_focus.x = lerpf(_focus.x, _target_focus.x, weight)
	_focus.z = lerpf(_focus.z, _target_focus.z, weight)
	_focus.y = lerpf(_focus.y, _ground_height(_focus.x, _focus.z), weight)
	_yaw = lerpf(_yaw, _target_yaw, weight)
	_pitch = lerpf(_pitch, _target_pitch, weight)
	_distance = lerpf(_distance, _target_distance, weight)
	_update_camera_transform()


func set_active(value: bool) -> void:
	active = value
	_drag_rotating = false
	_drag_panning = false


## Richtet den Fokus auf einen Weltpunkt. Mit [param snap] ohne Übergang.
func focus_on(point: Vector3, snap := false) -> void:
	_target_focus = Vector3(point.x, 0.0, point.z)
	if snap:
		_focus = Vector3(point.x, _ground_height(point.x, point.z), point.z)
		_update_camera_transform()


func set_yaw(yaw: float, snap := false) -> void:
	_target_yaw = yaw
	if snap:
		_yaw = yaw
		_update_camera_transform()


# --- Speichern -------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {
		"focus": SaveUtils.vec3_to_array(_target_focus),
		"yaw": _target_yaw,
		"pitch": _target_pitch,
		"distance": _target_distance,
	}


func load_state(data: Dictionary) -> void:
	_target_focus = SaveUtils.array_to_vec3(data.get("focus"), _target_focus)
	_target_yaw = float(data.get("yaw", _target_yaw))
	_target_pitch = float(data.get("pitch", _target_pitch))
	_target_distance = clampf(float(data.get("distance", _target_distance)), min_distance, max_distance)
	_focus = _target_focus
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance


# --- Intern ----------------------------------------------------------------

func _update_camera_transform() -> void:
	if camera == null:
		return
	var offset := Basis(Vector3.UP, _yaw) * (Vector3(0.0, sin(_pitch), cos(_pitch)) * _distance)
	var camera_position := _focus + offset
	# Nie unter das Gelände tauchen (z.B. vor Bergen).
	camera_position.y = maxf(camera_position.y, _ground_height(camera_position.x, camera_position.z) + 3.0)
	global_position = _focus
	camera.global_transform = Transform3D(Basis.looking_at(_focus - camera_position, Vector3.UP), camera_position)


func _ground_height(x: float, z: float) -> float:
	return terrain.get_height(x, z) if terrain else 0.0
