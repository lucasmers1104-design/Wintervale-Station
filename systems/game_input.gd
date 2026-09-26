## Zentrale Eingabe-Verwaltung (Autoload "GameInput").
##
## Trägt beim Start alle Tasten aus [InputConfig] in die Input Map ein.
## Aktionen, die bereits in den Projekteinstellungen (Input Map) Events
## besitzen, werden nicht überschrieben – Anpassungen im Editor haben Vorrang.
## Außerdem: Mausfang und Vollbild.
extends Node


func _enter_tree() -> void:
	for action: StringName in InputConfig.KEY_BINDINGS:
		if not _prepare_action(action):
			continue
		for keycode: int in InputConfig.KEY_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)

	for action: StringName in InputConfig.CTRL_SHORTCUTS:
		if not _prepare_action(action):
			continue
		for keycode: int in InputConfig.CTRL_SHORTCUTS[action]:
			var event := InputEventKey.new()
			event.keycode = keycode as Key
			event.command_or_control_autoremap = true
			InputMap.action_add_event(action, event)

	for action: StringName in InputConfig.MOUSE_BINDINGS:
		if not _prepare_action(action):
			continue
		for button: int in InputConfig.MOUSE_BINDINGS[action]:
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
	GameSettings.set_fullscreen(not GameSettings.fullscreen)


## Legt eine Aktion an, falls nötig. Gibt false zurück, wenn sie schon
## Events besitzt (z.B. aus den Projekteinstellungen).
func _prepare_action(action: StringName) -> bool:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	return InputMap.action_get_events(action).is_empty()
