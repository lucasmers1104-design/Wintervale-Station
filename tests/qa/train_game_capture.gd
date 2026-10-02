## Screenshots of the real dispatcher-built reference trains at the game platform.
extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1448, 900))
	WorldClock.paused = true
	WorldClock.set_time(15.0)
	Seasons.set_season(Seasons.Season.WINTER)
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	main.legacy_world = true
	add_child(main)
	var dispatcher: TrainDispatcher = main.get_node("World/Railway/TrainDispatcher")
	dispatcher.enabled = false
	(main.get_node("TrainEvents") as TrainEvents).enabled = false
	var festivals: FestivalDirector = main.get_node("Festivals")
	festivals.forced_festival = "none"
	festivals.tick()
	main.get_node("HUD").hide()
	(main.get_node("AchievementToast") as CanvasLayer).hide()
	var camera := Camera3D.new()
	camera.fov = 52.0
	main.add_child(camera)
	for i in 10:
		await get_tree().process_frame
	var source: TimetableEntry
	for entry in dispatcher.timetable.entries:
		if entry.train_number == "RE 209":
			source = entry
	for design in ["regional_express", "special_winter"]:
		dispatcher.clear_trains()
		await get_tree().process_frame
		var entry := source.duplicate(true) as TimetableEntry
		entry.train_type = load("res://assets/trains/%s.tres" % design)
		entry.train_number = "SZ 1" if design == "special_winter" else "RE 209"
		dispatcher.timetable.entries.append(entry)
		var train := dispatcher.spawn_train(dispatcher.timetable.entries.size() - 1)
		if train == null:
			push_error("Could not spawn capture train")
			get_tree().quit(1)
			return
		train.head = train.stop_at
		train.state = Train.State.DWELLING
		train.speed = 0
		train.update_visuals(0)
		train._door_side = train._platform_side()
		train._set_steps(1)
		train._set_doors(1)
		for car in train.cars:
			car.set_cabin_light(1)
		var first := train.cars[0]
		camera.look_at_from_position(first.to_global(Vector3(-8, 3.5, -8.5)), first.to_global(Vector3(0, 1.5, 1.5)))
		camera.make_current()
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/%s_in_game.png" % design
		print("CAPTURE ", path, " ", get_viewport().get_texture().get_image().save_png(path))
		# Opposite camera checks the actual platform-facing doors and steps.
		camera.look_at_from_position(first.to_global(Vector3(train._door_side * 6.0, 2.8, 4.5)), first.to_global(Vector3(0, 1.3, 3.55)))
		camera.make_current()
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		path = "res://docs/%s_platform.png" % design
		print("CAPTURE ", path, " ", get_viewport().get_texture().get_image().save_png(path))
	dispatcher.clear_trains()
	get_tree().quit()
