## Render the connected paths, shared paving and actual build preview.
extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	GameSettings.values["achievement_notifications"] = false
	var main := load("res://scenes/main/main.tscn").instantiate() as Node3D
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	WorldClock.paused = true
	WorldClock.set_time(13)
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyTutorial")._canvas.hide()
	main.get_node("JourneyGuide").set_process(false)
	main.get_node("HUD").hide()
	main.get_node("RegionPanel")._launcher.hide()
	main.get_node("Player").hide()
	main.get_node("Weather").set_process(false)
	main.get_node("Snowfall").hide()
	main.get_node("Rainfall").hide()
	var region := main.get("region") as RegionRailway
	region.progression.epoch = 4
	region.build_station({"id":91,"name":"Wintervale","level":3,"pos":[-6,0,-10],"angle":0},false)
	var house := region.village.prepare("house_chalet",Vector3(24,0,-7),0)
	house["build"] = 1.0
	var home := region.village.place(house) as VillageHouse
	region.village.place(region.village.prepare("plaza",Vector3(36,0,16),0))
	var route := PathMeshes.curve_route(home.get_front_point(),Vector3(30.2,0,16))
	var data := region.village.prepare("path_stone",route[0],0,0,route[-1])
	var saved: Array = []
	for point in route:
		saved.append(SaveUtils.vec3_to_array(point))
	data["points"] = saved
	region.village.place(data)
	var gravel := PathMeshes.curve_route(Vector3(23,0,25),Vector3(46,0,25))
	data = region.village.prepare("path_gravel",gravel[0],0,0,gravel[-1])
	saved = []
	for point in gravel:
		saved.append(SaveUtils.vec3_to_array(point))
	data["points"] = saved
	region.village.place(data)
	region.village.place(region.village.prepare("path_gravel",Vector3(36,0,21.8),0,0,Vector3(36,0,32)))
	region.village.nature.refresh_clearings()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.make_current()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 52
	camera.look_at_from_position(Vector3(57,48,62),Vector3(18,0,6))
	for season in [Seasons.Season.SUMMER,Seasons.Season.WINTER]:
		Seasons.set_season(season)
		RenderingServer.global_shader_parameter_set("wetness",0.0)
		await _save("connected_"+("summer" if season==Seasons.Season.SUMMER else "winter"))
	Seasons.set_season(Seasons.Season.SUMMER)
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.set_process(false)
	build.select_tool(&"village_paths")
	var tool := build.get_current_tool() as VillagePlaceTool
	tool.select_item("path_gravel")
	tool.set_path_curved(true)
	tool.click_at(Vector3(23,0,25))
	tool.preview_at(Vector3(14,0,29))
	main.get_node("HUD").show()
	camera.make_current()
	camera.size = 32
	camera.look_at_from_position(Vector3(50,30,52),Vector3(27,0,18))
	await _save("curve_preview")
	get_tree().quit()

func _save(label: String) -> void:
	for i in 16:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/qa/path_build/")
	DirAccess.make_dir_recursive_absolute(folder)
	print("CAPTURE ",label," ",get_viewport().get_texture().get_image().save_png(folder+label+".png"))
