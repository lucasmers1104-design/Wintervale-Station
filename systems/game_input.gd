## Zentrale Eingabe-Verwaltung (Autoload "GameInput").
##
## Registriert beim Start alle Eingabe-Aktionen des Spiels. Aktionen, die
## bereits in den Projekteinstellungen (Input Map) Events besitzen, werden
## nicht überschrieben – Anpassungen im Editor haben also Vorrang.
## Tasten werden über ihre physische Position gebunden, damit WASD auf
## QWERTZ, QWERTY und AZERTY gleich liegt.
extends Node

const KEY_BINDINGS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"sprint": [KEY_SHIFT],
	&"jump": [KEY_SPACE],
	&"toggle_view": [KEY_TAB],
	&"toggle_perspective": [KEY_V],
	&"camera_rotate_left": [KEY_Q],
	&"camera_rotate_right": [KEY_E],
	&"time_speed": [KEY_T],
	&"quick_save": [KEY_F5],
	&"quick_load": [KEY_F9],
	&"toggle_help": [KEY_F1],
	&"toggle_fullscreen": [KEY_F11],
	&"release_mouse": [KEY_ESCAPE],
	&"build_mode": [KEY_B],
	&"build_tool_rail": [KEY_1],
	&"build_tool_remove": [KEY_2],
	&"build_cancel": [KEY_ESCAPE],
}

## Tastenkürzel mit Strg. Diese nutzen die Tastenbeschriftung statt der
## Position, damit Strg+Z auch auf QWERTZ-Tastaturen auf dem "Z" liegt.
const CTRL_SHORTCUTS := {
	&"undo": [KEY_Z],
	&"redo": [KEY_Y],
}

const MOUSE_BINDINGS := {
	&"zoom_in": [MOUSE_BUTTON_WHEEL_UP],
	&"zoom_out": [MOUSE_BUTTON_WHEEL_DOWN],
	&"camera_drag_rotate": [MOUSE_BUTTON_MIDDLE],
	&"camera_drag_pan": [MOUSE_BUTTON_RIGHT],
	&"interact_primary": [MOUSE_BUTTON_LEFT],
}


func _enter_tree() -> void:
	for action: StringName in KEY_BINDINGS:
		if not _prepare_action(action):
			continue
		for keycode: int in KEY_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)

	for action: StringName in CTRL_SHORTCUTS:
		if not _prepare_action(action):
			continue
		for keycode: int in CTRL_SHORTCUTS[action]:
			var event := InputEventKey.new()
			event.keycode = keycode as Key
			event.command_or_control_autoremap = true
			InputMap.action_add_event(action, event)

	for action: StringName in MOUSE_BINDINGS:
		if not _prepare_action(action):
			continue
		for button: int in MOUSE_BINDINGS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button as MouseButton
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Fängt die Maus (für Umsehen) oder gibt sie frei (für UI/Bauen).
func capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Legt eine Aktion an, falls nötig. Gibt false zurück, wenn sie schon
## Events besitzt (z.B. aus den Projekteinstellungen).
func _prepare_action(action: StringName) -> bool:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	return InputMap.action_get_events(action).is_empty()
