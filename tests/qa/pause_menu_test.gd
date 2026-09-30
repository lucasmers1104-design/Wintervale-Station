## Pausenmenü-Test (Master Debugging V2).
##
## Start: godot --headless --path . -s res://tests/qa/pause_menu_test.gd
## Läuft in der QA-Sandbox (echte Spielstände bleiben unberührt).
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS  ", message)
	else:
		push_error("FAIL  " + message)
		failures += 1


func _press_escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	var clock: Node = root.get_node(^"/root/WorldClock")
	var saves: Node = root.get_node(^"/root/SaveManager")
	var economy: Node = root.get_node(^"/root/Economy")
	settings.get("values")["reduced_motion"] = true
	settings.get("values")["achievement_notifications"] = false
	_check(String(saves.get("save_dir")).contains("qa_sandbox"), "tests write to the QA sandbox")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	saves.set("active_slot", "pause_menu_probe")
	await _frames(20)
	var pause: Node = main.get_node(^"PauseMenu")
	_check(pause != null and not bool(pause.get("is_open")), "pause menu exists and starts closed")

	# Esc ohne Mausfang und ohne Mitfahren öffnet das Menü
	_press_escape()
	await _frames(2)
	_check(bool(pause.get("is_open")) and bool(pause.get("visible")), "Esc opens the pause menu")
	_check(paused and bool(clock.get("paused")), "world and clock are paused")
	var time_before: float = clock.get("time_of_day")
	var trains_before := _train_positions(main)
	await _frames(60)
	_check(is_equal_approx(float(clock.get("time_of_day")), time_before), "clock stands still while paused")
	_check(_train_positions(main) == trains_before, "trains stand still while paused")
	_press_escape()
	await _frames(2)
	_check(not bool(pause.get("is_open")) and not paused and not bool(clock.get("paused")), "Esc resumes the game")

	# Schnell hintereinander öffnen/schließen bleibt stabil
	for i in 6:
		pause.call("open")
		pause.call("open")
		pause.call("close")
	await _frames(2)
	_check(not bool(pause.get("is_open")) and not paused, "rapid open/close leaves the game running")

	# Speichern
	pause.call("open")
	await _frames(1)
	pause.call("get_entry_button", "save").pressed.emit()
	await _frames(6)
	_check(saves.call("has_save", "pause_menu_probe"), "Save writes the active journey")
	_check(bool(pause.get("is_open")) and bool(pause.get("visible")), "menu stays open after saving")

	# Einstellungen öffnen und mit Esc zurück
	pause.call("get_entry_button", "settings").pressed.emit()
	await _frames(3)
	var gallery: Control = pause.find_child("MenuGallery", true, false)
	if gallery == null:
		for child in pause.find_children("*", "Control", true, false):
			if child.has_method("show_page"):
				gallery = child
	_check(gallery != null and gallery.visible, "Settings opens the settings pages in game")
	_press_escape()
	await _frames(4)
	_check(gallery != null and not gallery.visible and bool(pause.get("is_open")), "Esc returns from settings to the pause menu")
	_check(paused, "game still paused after settings")

	# Hauptmenü mit Rückfrage, Abbrechen
	pause.call("get_entry_button", "main_menu").pressed.emit()
	await _frames(2)
	var dialog: Control = pause.find_child("ConfirmDialog", true, false)
	_check(dialog != null, "Main menu asks for confirmation")
	_press_escape()
	await _frames(2)
	_check(pause.find_child("ConfirmDialog", true, false) == null and bool(pause.get("is_open")), "Esc cancels the confirmation")

	# Hauptmenü ohne Speichern
	economy.set("money", 123456)
	clock.call("cycle_time_scale")
	pause.call("get_entry_button", "main_menu").pressed.emit()
	await _frames(2)
	var discard: Button = null
	for button in pause.find_children("*", "Button", true, false):
		if button.text == "Ohne Speichern":
			discard = button
	discard.pressed.emit()
	await _frames(8)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn",
		"returns to the main menu")
	_check(not paused, "tree unpaused in the main menu")
	_check(root.get_node_or_null(^"Main") == null, "game world was freed")

	# Neue Reise übernimmt nichts aus der vorigen
	var menu := current_scene
	menu.call("_on_start_requested", "Pause Probe Journey", 3)
	var waited := 0
	while (current_scene == null or current_scene.scene_file_path != "res://scenes/main/main.tscn") and waited < 3000:
		await process_frame
		waited += 1
	await _frames(10)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main/main.tscn", "new journey opens")
	_check(int(economy.get("money")) == int(economy.get_script().get_script_constant_map()["START_MONEY"]), "money starts fresh (%d)" % economy.get("money"))
	_check(is_equal_approx(float(clock.get("time_scale")), 1.0), "time scale starts at x1")
	for slot in ["pause_menu_probe", String(saves.get("active_slot"))]:
		saves.call("delete_save", slot)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _train_positions(main: Node) -> Array:
	var result := []
	var dispatcher := main.get_node_or_null(^"World/Railway/TrainDispatcher")
	if dispatcher:
		for train: Node3D in dispatcher.call("get_trains"):
			result.append(train.get("front_distance") if train.get("front_distance") != null else train.global_position)
	return result
