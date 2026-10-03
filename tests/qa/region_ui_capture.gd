## Actual new-world UI and development comparisons, rendered by the engine.
extends Node
var main: Node3D
var region: RegionRailway
var camera: Camera3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1448,900))
	WorldClock.paused = true
	WorldClock.set_time(15)
	Seasons.set_season(Seasons.Season.SUMMER)
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	region = main.get("region")
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 155
	main.add_child(camera)
	camera.look_at_from_position(Vector3(-95,100,-115),Vector3(16,0,0))
	camera.make_current()
	await _save("world_start")
	Economy.money = 100000
	for part in 4:
		var a := Vector3(-12,0,-100+part*50)
		var b := a+Vector3(0,0,50)
		region.network.restore_segment({"id":part+1,"kind":0,"start_node":part+1,"end_node":part+2,"points":[SaveUtils.vec3_to_array(a),SaveUtils.vec3_to_array(a.lerp(b,0.333333)),SaveUtils.vec3_to_array(a.lerp(b,0.666667)),SaveUtils.vec3_to_array(b)]})
	for side in 2:
		region.build_station({"id":side+1,"name":"Wintervale" if side==0 else "Tannenau","level":1,"pos":[-12,0,-35 if side==0 else 35],"angle":0},false)
	region.add_line(1,2,"diesel_heritage")
	await _save("world_first_line")
	var ui := main.get_node("RegionPanel") as RegionPanel
	for page in ["epochs","stations","fleet","lines","station"]:
		ui._station_id = 1
		ui.open_page(page)
		await _save("ui_"+page)
	ui.close()
	region.progression.set_epoch(6,true)
	for station in region.stations:
		station.level = 6 if station.station_id==1 else 3
		station.services = 50
		station.passenger_total = 240
		station.delivered_goods = 100
		station.rebuild()
		for i in 15:
			region.grow_station(station,true)
	for house in region.village.get_houses():
		house.set_build_progress(1,{},false)
	region.refresh()
	for station in region.stations:
		region._grow_public_space(station)
	await _save("world_developed")
	WorldClock.set_time(22)
	await _save("world_developed_night")
	ui._selected_train = "high_speed"
	ui.open_page("fleet")
	await _save("ui_high_speed")
	DisplayServer.window_set_size(Vector2i(1280,720))
	await _save("ui_fleet_1280")
	print("PERFORMANCE objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()

func _save(label: String) -> void:
	# ViewModeController chooses its startup camera in a deferred callback.
	camera.make_current()
	for i in 18:
		await get_tree().process_frame
	camera.make_current()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/qa/progression")
	print("CAPTURE ",label," ",get_viewport().get_texture().get_image().save_png("res://docs/qa/progression/%s.png" % label))
