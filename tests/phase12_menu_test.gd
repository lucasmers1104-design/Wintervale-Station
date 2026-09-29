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


func _run() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	var saves: Node = root.get_node(^"/root/SaveManager")
	var input: Node = root.get_node(^"/root/GameInput")
	settings.get("values")["reduced_motion"] = true
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var gallery: Control = menu.get_node("ReferenceCanvas/MenuGallery")
	for page in ["new_game", "load_save", "achievements", "settings_graphics", "settings_audio", "settings_controls", "settings_gameplay", "credits"]:
		gallery.call("show_page", page)
		_check(gallery.visible and gallery.get_node("LiveContent").get_child_count() > 0, page + " builds live content")
	_check((menu.get_node("ReferenceCanvas/Continue") as Button).disabled == (saves.call("most_recent_valid_slot") == ""), "Continue state reflects valid saves")
	var slot := "phase12_probe_%d" % Time.get_ticks_msec()
	saves.set("journey_name", "Phase 12 Probe")
	_check(saves.call("save_game", slot), "create named save")
	var data: Dictionary = saves.call("read_save_data", slot)
	_check(not data.is_empty() and data.get("metadata", {}).get("name", "") == "Phase 12 Probe", "read real save metadata")
	var listed := false
	for entry in saves.call("list_saves", true):
		if entry["slot"] == slot:
			listed = true
	_check(listed, "list named save")
	_check(saves.call("read_save_data", "../escape").is_empty(), "reject unsafe save path")
	var corrupt_slot := "phase12_corrupt_%d" % Time.get_ticks_msec()
	var corrupt_path: String = saves.call("get_save_path", corrupt_slot)
	var damaged := FileAccess.open(corrupt_path, FileAccess.WRITE)
	damaged.store_string("{broken json")
	damaged.close()
	_check(saves.call("read_save_data", corrupt_slot).is_empty(), "corrupted JSON rejected")
	var corrupt_listed := false
	for entry in saves.call("list_saves", true):
		if entry["slot"] == corrupt_slot:
			corrupt_listed = not bool(entry["valid"])
	_check(corrupt_listed, "corrupt save shown as unavailable")
	saves.call("delete_save", corrupt_slot)
	gallery.call("show_page", "load_save")
	_check(gallery.get_node("LiveContent").find_child("*", true, false) != null, "save page rebuilds")
	var live: Node = gallery.get_node("LiveContent")
	live.call("_confirm_delete", slot, "Phase 12 Probe")
	_check(saves.call("has_save", slot), "delete requires explicit confirmation")
	var keep_button: Button
	for button in live.find_children("*", "Button", true, false):
		if button.text == "Keep Save":
			keep_button = button
	if keep_button:
		keep_button.pressed.emit()
	_check(saves.call("has_save", slot), "cancel deletion preserves save")
	await process_frame
	live.call("_confirm_delete", slot, "Phase 12 Probe")
	var delete_button: Button
	for button in live.find_children("*", "Button", true, false):
		if button.text == "Delete Save":
			delete_button = button
	if delete_button:
		delete_button.pressed.emit()
	_check(not saves.call("has_save", slot), "confirmed delete removes named save")
	gallery.call("close_page")
	_check(not gallery.visible, "return to menu")
	var old_values: Dictionary = settings.get("values").duplicate(true)
	var old_path: String = settings.get("storage_path")
	var settings_test_path := "user://phase12_settings_probe.cfg"
	settings.set("storage_path", settings_test_path)
	settings.call("set_pref", "ui_volume", 37)
	var config := ConfigFile.new()
	_check(config.load(settings_test_path) == OK and int(config.get_value("preferences", "ui_volume", -1)) == 37, "setting persists to global preferences file")
	var preview_values: Dictionary = settings.get("values").duplicate(true)
	preview_values["fullscreen"] = not bool(preview_values["fullscreen"])
	settings.call("apply_values", preview_values, false)
	config.load(settings_test_path)
	_check(bool(config.get_value("preferences", "fullscreen", false)) != bool(preview_values["fullscreen"]), "unconfirmed display preview is not persisted")
	settings.call("apply_values", old_values)
	settings.set("storage_path", old_path)
	DirAccess.remove_absolute(settings_test_path)
	var old_bindings_path: String = input.get("storage_path")
	var bindings_test_path := "user://phase12_bindings_probe.cfg"
	input.set("storage_path", bindings_test_path)
	_check(input.call("rebind_key", &"build_mode", KEY_N) != "", "key conflict rejected")
	_check(input.call("rebind_key", &"build_mode", KEY_U) == "", "free key rebound")
	var bind_config := ConfigFile.new()
	_check(bind_config.load(bindings_test_path) == OK and int(bind_config.get_value("keys", "build_mode", 0)) == KEY_U, "keybinding persists")
	input.call("restore_default_bindings")
	input.set("storage_path", old_bindings_path)
	DirAccess.remove_absolute(bindings_test_path)
	settings.get("values")["reduced_motion"] = false
	gallery.call("show_page", "settings_graphics")
	gallery.call("show_page", "settings_audio")
	for i in 55:
		await process_frame
	_check(gallery.get_node("PageArt").texture == load("res://assets/ui/menu_screens/settings_graphics.png"), "rapid tab click does not overlap transition")
	gallery.call("show_page", "settings_audio")
	for i in 55:
		await process_frame
	_check(gallery.get_node("PageArt").texture == load("res://assets/ui/menu_screens/settings_audio.png"), "tab transition reaches Audio")
	gallery.call("close_page")
	for i in 35:
		await process_frame
	_check(not gallery.visible, "reverse transition returns to menu")
	settings.get("values")["reduced_motion"] = old_values["reduced_motion"]
	print("Phase 12 menu failures: ", failures)
	menu.queue_free()
	await process_frame
	quit(1 if failures else 0)
