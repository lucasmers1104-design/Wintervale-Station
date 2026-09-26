## Wechselt zwischen Erkunden (Spielfigur) und Vogelperspektive.
##
## Beim Wechsel fliegt eine eigene Übergangskamera weich von der alten zur
## neuen Kameraposition. Außerdem verwaltet der Controller den Mausfang:
## Erkunden = Maus gefangen, Vogelperspektive = Mauszeiger sichtbar.
class_name ViewModeController
extends Node

const SAVE_ID := "view_mode"

@export var player: PlayerController
@export var bird_eye: BirdEyeCamera
@export var transition_camera: Camera3D
@export var transition_time := 0.9
## Ansicht beim Spielstart.
@export var start_mode := GameDefs.ViewMode.BIRD_EYE

var mode := GameDefs.ViewMode.EXPLORE

var _tween: Tween


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	# Erst nach dem Aufbau der Szene, damit die Spielfigur schon am Startpunkt steht.
	set_mode.call_deferred(start_mode, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_view"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"release_mouse"):
		GameInput.capture_mouse(false)
		get_viewport().set_input_as_handled()
	elif mode == GameDefs.ViewMode.EXPLORE and event.is_action_pressed(&"interact_primary") \
			and not GameInput.is_mouse_captured():
		GameInput.capture_mouse(true)
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if mode == GameDefs.ViewMode.EXPLORE:
		set_mode(GameDefs.ViewMode.BIRD_EYE)
	else:
		set_mode(GameDefs.ViewMode.EXPLORE)


## Wechselt die Ansicht. [param instant] überspringt den Kameraflug,
## [param refocus] richtet die Vogelperspektive auf die Spielfigur aus.
func set_mode(new_mode: GameDefs.ViewMode, instant := false, refocus := true) -> void:
	var from_camera := get_viewport().get_camera_3d()
	mode = new_mode
	var exploring := mode == GameDefs.ViewMode.EXPLORE

	player.input_enabled = exploring
	bird_eye.set_active(not exploring)
	if not exploring and refocus:
		bird_eye.focus_on(player.global_position, true)
		bird_eye.set_yaw(player.get_view_yaw(), true)
	GameInput.capture_mouse(exploring)

	var target := player.get_camera() if exploring else bird_eye.camera
	if instant or from_camera == null or from_camera == target:
		_stop_transition()
		target.make_current()
	else:
		_blend_cameras(from_camera, target)

	Events.view_mode_changed.emit(mode)


# --- Speichern -------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"mode": mode}


func load_state(data: Dictionary) -> void:
	var saved := int(data.get("mode", GameDefs.ViewMode.EXPLORE))
	set_mode(saved as GameDefs.ViewMode, true, false)


# --- Intern ----------------------------------------------------------------

func _blend_cameras(from_camera: Camera3D, target: Camera3D) -> void:
	_stop_transition()
	var start := from_camera.global_transform
	var start_fov := from_camera.fov
	transition_camera.global_transform = start
	transition_camera.fov = start_fov
	transition_camera.make_current()

	_tween = create_tween()
	_tween.tween_method(_apply_blend.bind(start, start_fov, target), 0.0, 1.0, transition_time)
	_tween.tween_callback(target.make_current)


## Das Ziel bewegt sich evtl. noch (weiches Nachziehen), daher wird jeden
## Frame neu zwischen Start und aktueller Zielposition interpoliert.
func _apply_blend(t: float, start: Transform3D, start_fov: float, target: Camera3D) -> void:
	var weight := ease(t, -2.2)
	transition_camera.global_transform = start.interpolate_with(target.global_transform, weight)
	transition_camera.fov = lerpf(start_fov, target.fov, weight)


func _stop_transition() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
