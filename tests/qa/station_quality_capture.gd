## Unmodified in-engine screenshots for the station regression review.
extends Node

var main: Node3D
var camera: Camera3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	WorldClock.paused = true
	GameSettings.values["achievement_notifications"] = false
	WorldClock.set_time(12)
	Seasons.set_season(Seasons.Season.WINTER)
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyTutorial")._canvas.hide()
	main.get_node("HUD").hide()
	main.get_node("RegionPanel")._launcher.hide()
	main.get_node("Player").hide()
	for portal in (main.get("region") as RegionRailway).portals:
		for label in portal.find_children("*","Label3D",true,false):
			label.hide()
	var region := main.get("region") as RegionRailway
	region.network.restore_segment({"id":850,"kind":0,"start_node":850,"end_node":851,"points":[[-30,0,-75],[-30,0,-25],[-30,0,25],[-30,0,75]]})
	var station := region.build_station({"id":91,"name":"Wintervale","level":1,"pos":[-30,0,0],"angle":0},false)
	camera = Camera3D.new()
	main.add_child(camera)
	camera.make_current()
	for level in range(1,7):
		station.level = level
		station.rebuild()
		region.terrain.flush_changes()
		var length := float(EpochCatalog.epoch(level)["length"])
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = length*0.7+12
		camera.look_at_from_position(station.to_global(Vector3(-length*0.65,length*0.40,-length*0.48)),station.to_global(Vector3(8,2,0)))
		await save("station_%d_overview" % level)
		if level<=2:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 70
			var at := station.to_global(Vector3(3.8,2.45,-2 if level==1 else 4))
			camera.look_at_from_position(at,at+Vector3(0,1.0,-2.0))
			await save("station_%d_ceiling" % level)
			var access := StationAccess.describe(level)
			var target := station.to_global(Vector3(float(access["back"]),0.9,float(access["z"])))
			camera.look_at_from_position(target+Vector3(5.5,3,4.5),target+Vector3(0,0.4,0))
			await save("station_%d_stairs" % level)
	station.level = 3
	station.rebuild()
	region.terrain.flush_changes()
	WorldClock.set_time(21)
	station.set_dark(true)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.look_at_from_position(station.to_global(Vector3(2.7,2.55,6)),station.to_global(Vector3(3.1,2.8,-8)))
	await save("station_3_night_platform")
	get_tree().quit()

func save(label: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/qa/station_quality")
	var result := get_viewport().get_texture().get_image().save_png("res://docs/qa/station_quality/%s.png" % label)
	print("CAPTURE ",label," ",result)
