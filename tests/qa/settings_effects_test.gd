## Prüft, dass Einstellungen echte Engine-Wirkung haben – nicht nur die Anzeige.
##
## Start: godot --headless --path . -s res://tests/qa/settings_effects_test.gd
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
	var clock: Node = root.get_node(^"/root/WorldClock")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10:
		await process_frame
	var original: Dictionary = settings.get("values").duplicate(true)
	var environment: Environment = (main.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	var sun := main.get_node(^"DayNightCycle/Sun") as DirectionalLight3D
	var moon := main.get_node(^"DayNightCycle/Moon") as DirectionalLight3D
	var snowfall: Node = main.get_node(^"Snowfall")
	var rainfall: Node = main.get_node(^"Rainfall")
	var sun_base := sun.directional_shadow_max_distance
	var moon_base := moon.directional_shadow_max_distance
	_check(environment.glow_enabled, "bloom on by default")

	var next := original.duplicate(true)
	next["bloom"] = false
	next["shadow_quality"] = "Low"
	next["particle_density"] = 0.25
	next["master_volume"] = 40
	next["day_speed"] = 2.0
	next["camera_sensitivity"] = 1.5
	settings.call("apply_values", next, false)
	await process_frame
	_check(not environment.glow_enabled, "Bloom off disables glow in the world environment")
	_check(is_equal_approx(sun.directional_shadow_max_distance, sun_base * 0.55), "Low shadows shorten sun shadow range (%.1f m)" % sun.directional_shadow_max_distance)
	_check(is_equal_approx(moon.directional_shadow_max_distance, moon_base * 0.55), "Low shadows shorten moon shadow range")
	_check(is_equal_approx(float(snowfall.get("max_intensity")), 0.25), "particle density scales snowfall")
	_check(is_equal_approx(float(rainfall.get("density")), 0.25), "particle density scales rain")
	var master := AudioServer.get_bus_index("Master")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(master)) - 0.4) < 0.01, "master volume drives the Master bus")
	_check(is_equal_approx(float(clock.get("day_length_minutes")), 24.0), "day speed x2 halves the day length")
	var player: Node = main.get_node(^"Player")
	_check(is_equal_approx(float(player.get("mouse_sensitivity")), 0.0025 * 1.5), "camera sensitivity reaches the player")

	next["shadow_quality"] = "Medium"
	settings.call("apply_values", next, false)
	_check(is_equal_approx(sun.directional_shadow_max_distance, sun_base * 0.78), "Medium shadows")
	settings.call("apply_values", original, false)
	await process_frame
	_check(environment.glow_enabled and is_equal_approx(sun.directional_shadow_max_distance, sun_base),
		"restoring High/Bloom returns to the original look")
	_check(is_equal_approx(float(snowfall.get("max_intensity")), 1.0), "full particle density restored")

	# Settings-Seiten: Zeilen mit Symbolen, echte Schalter
	var gallery: Control = load("res://scenes/ui/menu_gallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	for page in ["settings_graphics", "settings_audio", "settings_controls", "settings_gameplay"]:
		gallery.call("show_page", page)
		await process_frame
		var live: Node = gallery.get_node("LiveContent")
		var icons := 0
		for rect in live.find_children("*", "TextureRect", true, false):
			if (rect as TextureRect).texture and (rect as TextureRect).texture.resource_path.contains("settings_icons"):
				icons += 1
		_check(icons >= 4, "%s rows show reference icons (%d)" % [page, icons])
	gallery.call("show_page", "settings_graphics")
	await process_frame
	var switches := gallery.get_node("LiveContent").find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return b.get_script() != null and (b.get_script() as Script).get_script_constant_map().has("TRACK"))
	_check(switches.size() == 3, "graphics page has three pill switches (fullscreen, vsync, bloom)")
	var labels := gallery.get_node("LiveContent").find_children("*", "OptionButton", true, false)
	var fps: OptionButton = null
	for option: OptionButton in labels:
		for i in option.item_count:
			if option.get_item_text(i) == "Unlimited":
				fps = option
	_check(fps != null, "frame rate choice shows 'Unlimited' instead of 0")
	gallery.call("show_page", "settings_gameplay")
	await process_frame
	var back: Button = gallery.get_node("VisibleControls/Back")
	_check(back.position.y >= 840.0, "gameplay Back button matches its lower artwork position")
	gallery.queue_free()
	main.queue_free()
	await process_frame
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
