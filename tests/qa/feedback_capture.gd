## Real Compatibility-renderer views of photographed issues and the new notebook.
extends Node
var main: Node3D
var camera: Camera3D
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	GameSettings.values["achievement_notifications"] = false
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	for i in 12:
		await get_tree().process_frame
	WorldClock.paused = true
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
	region.progression.epoch = 2
	var station := region.build_station({"id":91,"name":"Wintervale","level":2,"pos":[-30,0,0],"angle":0},false)
	camera = Camera3D.new()
	main.add_child(camera)
	camera.make_current()
	Seasons.set_season(Seasons.Season.WINTER)
	WorldClock.set_time(21)
	RenderingServer.global_shader_parameter_set("wetness",0.0)
	var z := float(StationAccess.describe(2)["z"])
	camera.look_at_from_position(station.to_global(Vector3(26,6,z+11)),station.to_global(Vector3(17,0,z)))
	station.set_dark(true)
	for light in station._platform_lights:
		if light.position.x>17:
			light.light_energy = 0
	await _save("forecourt_before")
	station.set_dark(true)
	await _save("forecourt_after")
	WorldClock.set_time(13)
	station.set_dark(false)
	var home := region.village.prepare("house_cottage",Vector3(24,0,-7),0)
	home["since"] = 1
	region.village.place(home)
	for pair in [[Vector3(18,0,8),Vector3(46,0,8)],[Vector3(32,0,8),Vector3(32,0,22)],[Vector3(21,0,8),Vector3(21,0,-3)]]:
		region.village.place(region.village.prepare("path_gravel",pair[0],0,0,pair[1]))
	region.village.nature.refresh_clearings()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 38
	camera.look_at_from_position(Vector3(49,38,37),Vector3(30,0,8))
	await _save("junction_winter")
	Seasons.set_season(Seasons.Season.SUMMER)
	await _save("junction_summer")
	var notebook := main.get_node("Notebook") as Notebook
	notebook.open("storage")
	await _save("materials")
	notebook.open("activities")
	await _save("village_life")
	notebook.close()
	var activities := main.get_node("VillageActivities") as VillageActivities
	activities.start_job("cleanup",91)
	notebook.open("activities")
	await _save("active_round")
	notebook.close()
	var player := main.get_node("Player") as PlayerController
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = SaveUtils.array_to_vec3(activities.active["points"][0])+Vector3(0,0,1)
	player.show()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.look_at_from_position(player.global_position+Vector3(5,4,6),player.global_position+Vector3.UP)
	await _save("character_round")
	get_tree().quit()
func _save(label: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/qa/feedback/")
	DirAccess.make_dir_recursive_absolute(folder)
	print("CAPTURE ",label," ",get_viewport().get_texture().get_image().save_png(folder+label+".png"))
