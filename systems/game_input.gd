## Zentrale Eingabe-Verwaltung (Autoload "GameInput").
##
## Trägt beim Start alle Tasten aus [InputConfig] in die Input Map ein.
## Aktionen, die bereits in den Projekteinstellungen (Input Map) Events
## besitzen, werden nicht überschrieben – Anpassungen im Editor haben Vorrang.
## Außerdem: Mausfang und Vollbild.
extends Node

const BINDINGS_PATH := "user://keybindings.cfg"
var storage_path := QaSandbox.redirect(BINDINGS_PATH)


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
	_load_bindings()


func rebind_key(action: StringName, physical_keycode: Key) -> String:
	if not InputConfig.KEY_BINDINGS.has(action) or physical_keycode == KEY_NONE:
		return "This action cannot be rebound."
	for other: StringName in InputMap.get_actions():
		if other == action:
			continue
		for bound: InputEvent in InputMap.action_get_events(other):
			if bound is InputEventKey and not bound.ctrl_pressed and not bound.alt_pressed \
					and not bound.shift_pressed and not bound.meta_pressed \
					and (bound.physical_keycode == physical_keycode or
						(bound.physical_keycode == KEY_NONE and bound.keycode == physical_keycode)):
				return "Key already used for %s." % String(other).replace("_", " ").capitalize()
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)
	_save_bindings()
	return ""


func restore_default_bindings() -> void:
	for action: StringName in InputConfig.KEY_BINDINGS:
		InputMap.action_erase_events(action)
		for keycode: int in InputConfig.KEY_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
	var config := ConfigFile.new()
	config.save(storage_path)


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	for action_name in config.get_section_keys("keys"):
		var action := StringName(action_name)
		if not InputConfig.KEY_BINDINGS.has(action):
			continue
		var code := int(config.get_value("keys", action_name, 0))
		if code == 0:
			continue
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = code as Key
		InputMap.action_add_event(action, event)


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action: StringName in InputConfig.KEY_BINDINGS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				config.set_value("keys", String(action), event.physical_keycode)
				break
	config.save(storage_path)


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
