## Reference GUI exercised in the real Compatibility renderer.
extends Node
var main: Node3D
var region: RegionRailway
var panel: RegionPanel
var camera: Camera3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1672,941))
	GameSettings.values["achievement_notifications"] = false
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	for i in 12:
		await get_tree().process_frame
	WorldClock.paused = true
	WorldClock.set_time(15)
	Seasons.set_season(Seasons.Season.WINTER)
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyTutorial").finish()
	main.get_node("JourneyTutorial")._update_ribbon()
	main.get_node("JourneyTutorial")._canvas.hide()
	main.get_node("JourneyGuide").set_process(false)
	main.get_node("Player").hide()
	region = main.get("region")
	panel = main.get_node("RegionPanel")
	Economy.money = 100000
	region.progression.set_epoch(2,true)
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.select_tool(&"rail")
	build.set_process(false)
	var rail := build.get_tool(&"rail") as RailPlaceTool
	var portal := region.portals[0]
	var stub := portal.get_stub_end()
	rail.click_at(stub,true)
	rail.click_at(stub+Vector3(0,0,50),true)
	rail.click_at(stub+Vector3(0,0,100),true)
	rail.cancel()
	build.set_active(false)
	var station := region.build_station(region.placement(stub+Vector3(4,0,55)),false)
	if station==null:
		push_error("GUI capture station placement failed")
		get_tree().quit(1)
		return
	station.station_name = "Wintervale"
	station.level = 2
	station.population = 10
	station.services = 72
	station.passenger_total = 70
	station.rebuild()
	var line := region.add_line(portal.station_id,station.station_id,"nostalgic_regional")
	if not line.is_empty():
		line["trips"] = 77
		line["passengers"] = 140
	region.progression.set_process(false)
	camera = Camera3D.new()
	main.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 90
	camera.look_at_from_position(station.global_position+Vector3(-40,65,55),station.global_position)
	camera.make_current()
	await _save("launcher")
	var tutorial := main.get_node("JourneyTutorial") as JourneyTutorial
	region.progression.tutorial_step = 0
	tutorial._canvas.show()
	tutorial._show_current()
	await _save("welcome_1672")
	tutorial.finish()
	tutorial._canvas.hide()
	main.get_node("HUD").hide()
	for page in ["epochs","stations","fleet","lines","station"]:
		panel._station_id = station.station_id
		panel._selected_train = "reference_freight"
		panel.open_page(page)
		await _save(page+"_1672")
	DisplayServer.window_set_size(Vector2i(1280,720))
	for page in ["fleet","lines"]:
		panel.open_page(page)
		await _save(page+"_1280")
	panel.close()
	region.progression.tutorial_step = 1
	tutorial._shown_step = -99
	tutorial._canvas.show()
	tutorial._show_current()
	tutorial._update_ribbon()
	await _save("tutorial_1280")
	DisplayServer.window_set_size(Vector2i(1920,1080))
	await _save("tutorial_1920")
	panel.open_page("epochs")
	tutorial._canvas.hide()
	await _save("epochs_1920")
	tutorial.finish()
	panel.set_tutorial_hint("")
	region.progression.set_epoch(6,true)
	panel.show_train("high_speed")
	await _save("fleet_unlocked_1920")
	get_tree().quit()

func _save(label: String) -> void:
	main.get_node("JourneyTutorial")._update_ribbon()
	camera.make_current()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/qa/journey_gui/")
	DirAccess.make_dir_recursive_absolute(folder)
	print("CAPTURE ",label," ",get_viewport().get_texture().get_image().save_png(folder+label+".png"))
