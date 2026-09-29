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
	var clock: Node = root.get_node(^"/root/WorldClock")
	var achievements: Node = root.get_node(^"/root/Achievements")
	settings.get("values")["reduced_motion"] = true
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var gallery: Control = menu.get_node("ReferenceCanvas/MenuGallery")
	gallery.call("show_page", "new_game")
	var journey_name := "Phase 12 Journey Probe %d" % Time.get_ticks_msec()
	var content: Control = gallery.get_node("LiveContent")
	var name_input := content.find_child("JourneyName", true, false) as LineEdit
	name_input.text = journey_name
	var start: Button = null
	for button in content.find_children("*", "Button", true, false):
		if button.text == "Start Your Journey":
			start = button
			break
	_check(start != null, "New Game start control exists")
	start.pressed.emit()
	_check(root.get_children().any(func(node: Node) -> bool: return node is MenuLoadingScreen),
		"illustrated loading screen appears during world loading")
	var slot: String = saves.get("active_slot")
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if current_scene and current_scene.scene_file_path == "res://scenes/main/main.tscn" \
				and saves.call("has_save", slot):
			break
		await process_frame
	var world: Node = current_scene
	_check(world != null and world.scene_file_path == "res://scenes/main/main.tscn", "New Game opens real world")
	if world == null or world.scene_file_path != "res://scenes/main/main.tscn":
		print("Phase 12 journey failures: ", failures)
		quit(1)
		return
	_check(slot != "" and slot != "quicksave", "unique journey slot selected")
	var data: Dictionary = saves.call("read_save_data", slot)
	_check(not data.is_empty(), "new journey saved")
	_check(data.get("metadata", {}).get("name", "") == journey_name, "journey name saved in metadata")
	_check(data.get("objects", {}).has("rail_network") and data.get("objects", {}).has("village"), "world state saved")
	_check(data.get("objects", {}).has("achievements"), "achievement state saved per journey")
	_check(saves.call("make_unique_slot", journey_name) != slot, "new journey name cannot overwrite save")
	var second_slot := slot + "_second"
	_check(saves.call("save_game", second_slot), "second save created")
	_check(saves.call("most_recent_valid_slot") == second_slot, "Continue selects newest valid save")
	saves.call("delete_save", second_slot)
	saves.set("active_slot", slot)
	var network: Node = world.get_node(^"World/Railway/RailNetwork")
	var first_segment = network.call("get_segments")[0]
	var segment_data: Dictionary = network.call("get_segment_data", first_segment.id, false)
	var test_id := int(network.get("_next_segment_id")) + 1000
	segment_data["id"] = test_id
	segment_data["start_node"] = int(network.get("_next_node_id")) + 1000
	segment_data["end_node"] = int(network.get("_next_node_id")) + 1001
	for point in segment_data["points"]:
		point[0] += 120.0
		point[2] += 120.0
	network.call("restore_segment", segment_data)
	_check(achievements.call("is_unlocked", "first_tracks"), "real rail addition unlocks First Tracks")
	var progress_before := float(achievements.get("progress").get("getting_connected", 0.0))
	_check(progress_before > 0.0, "track length contributes real progress")
	network.call("remove_segment", test_id)
	network.call("restore_segment", segment_data)
	_check(is_equal_approx(float(achievements.get("progress").get("getting_connected", 0.0)), progress_before), "restoring same track cannot farm progress")
	network.call("remove_segment", test_id)
	_check(saves.call("save_game", slot), "save achievement progress")
	clock.set("day", 9)
	_check(saves.call("load_game", slot), "named journey loads")
	_check(int(clock.get("day")) == int(data["objects"]["world_clock"]["day"]), "game day restored")
	_check(achievements.call("is_unlocked", "first_tracks"), "achievement unlock persists in save")
	current_scene = null
	world.queue_free()
	await process_frame
	var load_menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(load_menu)
	current_scene = load_menu
	await process_frame
	var continue_button := load_menu.get_node("ReferenceCanvas/Continue") as Button
	_check(not continue_button.disabled, "Continue is available for valid named save")
	continue_button.pressed.emit()
	_check(root.get_children().any(func(node: Node) -> bool: return node is MenuLoadingScreen),
		"Continue displays illustrated loading screen")
	deadline = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if current_scene and current_scene.scene_file_path == "res://scenes/main/main.tscn":
			break
		await process_frame
	world = current_scene
	_check(world != null and world.scene_file_path == "res://scenes/main/main.tscn",
		"Continue restores the real world")
	_check(achievements.call("is_unlocked", "first_tracks"), "Continue restores saved achievement")
	while Time.get_ticks_msec() < deadline and root.get_children().any(
		func(node: Node) -> bool: return node is MenuLoadingScreen):
		await process_frame
	saves.call("delete_save", slot)
	_check(not saves.call("has_save", slot), "probe save removed")
	print("Phase 12 journey failures: ", failures)
	current_scene = null
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
