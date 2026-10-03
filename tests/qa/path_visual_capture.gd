## Actual renderer review: all path surfaces in dry summer, rain and winter.
extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	WorldClock.paused = true
	WorldClock.set_time(13)
	GameSettings.values["achievement_notifications"] = false
	var main := load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyTutorial")._canvas.hide()
	main.get_node("HUD").hide()
	main.get_node("RegionPanel")._launcher.hide()
	main.get_node("Player").hide()
	main.get_node("Weather").set_process(false)
	# Inspect the material itself without precipitation covering the close-up.
	main.get_node("Snowfall").hide()
	main.get_node("Rainfall").hide()
	var region := main.get("region") as RegionRailway
	for i in 3:
		var item: String = ["path_gravel","path_stone","path_road"][i]
		region.village.place(region.village.prepare(item,Vector3(16+i*5,0,-12),0,0,Vector3(16+i*5,0,12)))
	region.village.nature.refresh_clearings()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.make_current()
	var suffix := "before" if OS.get_cmdline_user_args().has("before") else "after"
	for season in [Seasons.Season.SUMMER,Seasons.Season.WINTER]:
		Seasons.set_season(season)
		RenderingServer.global_shader_parameter_set("wetness",0.0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 22
		camera.look_at_from_position(Vector3(33,21,24),Vector3(21,0,0))
		await _save("paths_%s_%s" % ["summer" if season==Seasons.Season.SUMMER else "winter",suffix])
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 60
		camera.look_at_from_position(Vector3(18.6,2.6,7),Vector3(16,0,2))
		await _save("gravel_%s_%s" % ["summer" if season==Seasons.Season.SUMMER else "winter",suffix])
	Seasons.set_season(Seasons.Season.SUMMER)
	RenderingServer.global_shader_parameter_set("wetness",0.85)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22
	camera.look_at_from_position(Vector3(33,21,24),Vector3(21,0,0))
	await _save("paths_rain_"+suffix)
	get_tree().quit()

func _save(label: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/qa/paths/")
	DirAccess.make_dir_recursive_absolute(folder)
	print("CAPTURE ",label," ",get_viewport().get_texture().get_image().save_png(folder+label+".png"))
