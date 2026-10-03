## Real renderer captures of station foundations, entrances and guide layouts.
extends Node
var main: Node3D
var region: RegionRailway
var camera: Camera3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	WorldClock.paused = true
	GameSettings.values["achievement_notifications"] = false
	GameSettings.values["fullscreen"] = false
	GameSettings.fullscreen = false
	WorldClock.set_time(15)
	Seasons.set_season(Seasons.Season.SUMMER)
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	region = main.get("region")
	region.progression.tutorial_step = -1
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyTutorial")._canvas.hide()
	main.get_node("HUD").hide()
	var panel := main.get_node("RegionPanel") as RegionPanel
	panel._launcher.hide()
	Economy.money = 100000
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main.add_child(camera)
	for i in 12:
		await get_tree().process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	# A genuine rail corridor and station pad on a raised axis.
	region.network.restore_segment({"id":801,"kind":0,"start_node":801,"end_node":802,"points":[[-30,2,-70],[-30,2,-23],[-30,2,23],[-30,2,70]]})
	var station := region.build_station({"id":71,"name":"Wintervale","level":1,"pos":[-30,2,0],"angle":0},false)
	for level in range(1,7):
		station.level = level
		station.rebuild()
		region.terrain.flush_changes()
		var length := float(EpochCatalog.epoch(level)["length"])
		camera.size = length*0.72+13
		camera.look_at_from_position(Vector3(24,35,-length*0.55),Vector3(-20,4,0))
		if not OS.get_cmdline_user_args().has("--ui-only") and not OS.get_cmdline_user_args().has("--intro-only"):
			await _save("station_%d" % level)
	station.level = 2
	station.rebuild()
	region.terrain.flush_changes()
	var factory := TrainDispatcher.new()
	var materials := {"paint":load("res://assets/materials/train_paint.tres"),"glass":load("res://assets/materials/train_glass.tres"),"cargo":load("res://assets/materials/cargo.tres"),"lamp_white":factory._lamp_material(Color(1,0.92,0.75),2),"lamp_red":factory._lamp_material(Color(1,0.1,0.08),2),"lamp_idle_white":factory._lens_material(Color(0.5,0.5,0.5)),"lamp_idle_red":factory._lens_material(Color(0.2,0.04,0.03)),"snow":factory._snow_material(),"festive":factory._festive_material()}
	factory.free()
	var type := EpochCatalog.train("nostalgic_regional")
	var offset := -EpochCatalog.consist_length(type)/2
	for i in type.consist.size():
		var car := TrainCar.new()
		main.add_child(car)
		car.build(type.consist[i],type,i==0,i==type.consist.size()-1,materials,i)
		car.position = Vector3(-30,2,offset+car.length/2)
		offset += car.length+TrainMeshes.COUPLING_GAP
		car.set_cabin_light(0.8)
		car.set_destination("WINTERVALE")
		if car._exhaust:
			car._exhaust.emitting = false
	camera.size = 48
	camera.look_at_from_position(Vector3(-85,22,-35),Vector3(-28,4,0))
	await _save("epoch_two_train")
	main.get_node("HUD").show()
	panel._launcher.show()
	var guide := main.get_node("JourneyGuide") as JourneyGuide
	if not OS.get_cmdline_user_args().has("--intro-only"):
		guide.start_tour()
		for i in guide._steps.size():
			var page := String(guide._steps[guide._index]["page"])
			await _save("guide_"+page.trim_prefix("_"))
			guide.next()
	region.progression.set_epoch(2,true)
	for i in 8:
		await get_tree().process_frame
	await _save("epoch_introduction")
	guide.start_tour(2)
	guide.next()
	guide.next()
	await _save("epoch_model")
	guide.stop(true)
	main.get_node("HUD").hide()
	panel._launcher.hide()
	camera.size = 42
	camera.look_at_from_position(Vector3(-74,26,-30),Vector3(-28,4,0))
	var feedback := (main.get_node("BuildMode") as BuildMode).context.feedback
	feedback.confirm("path",Vector3(-20,2,22),PackedVector3Array([Vector3(-20,2,8),Vector3(-20,2,15),Vector3(-20,2,22)]),"Kiesweg")
	# Freeze a native effect at 0.2 s solely for its still screenshot.
	for tween in get_tree().get_processed_tweens():
		tween.custom_step(0.2)
		tween.pause()
	await _save("placement_feedback",4)
	get_tree().quit()

func _save(label: String, frames := 26) -> void:
	camera.make_current()
	for i in frames:
		await get_tree().process_frame
	camera.make_current()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/qa/build_experience")
	var result := get_viewport().get_texture().get_image().save_png("res://docs/qa/build_experience/%s.png" % label)
	print("CAPTURE ",label," ",result)
	var guide := main.get_node("JourneyGuide") as JourneyGuide
	if guide._mode!="":
		print("GUIDE RECT ",guide._card.get_global_rect()," minimum=",guide._card.get_combined_minimum_size())
