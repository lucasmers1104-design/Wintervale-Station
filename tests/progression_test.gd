extends Node

var failures := 0
var checks := 0
var main: Node3D
var region: RegionRailway

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PROGRESSION TEST START")
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	region = main.get("region")
	await frames(12)
	check(region!=null,"new region exists")
	if region==null:
		get_tree().quit(1)
		return
	check(region.network.get_segment_count()==0,"new game starts without rails")
	check(region.stations.is_empty(),"new game starts without stations")
	check(region.village.get_object_count()==0,"new game starts without a city")
	check(region.dispatcher.get_trains().is_empty(),"new game starts without traffic")
	check(region.progression.epoch==1,"epoch one at start")
	check(region.progression.is_train_unlocked("diesel_heritage") and not region.progression.is_train_unlocked("high_speed"),"initial unlocks")
	check(not region.progression.tool_unlocked(&"switch"),"later tools gated")
	check(main.get_node("World/FreightYard").get_child_count()==0,"no premade freight yard")
	_test_models()
	# Exercise the real rail tool on the flat central terrain, no fixture prebuild.
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.select_tool(&"rail")
	var tool := build.get_tool(&"rail") as RailPlaceTool
	tool.click_at(Vector3(-12,0,-50),true)
	var built := tool.click_at(Vector3(-12,0,0),true)
	built = tool.click_at(Vector3(-12,0,50),true) and built
	check(built,"first straight track built with existing tool: "+tool.get_status())
	tool.cancel()
	build.set_process(false)
	await frames(4)
	if not built:
		_finish()
		return
	var segment := region.network.get_segments()[0]
	var p0 := segment.curve.sample_baked(15,true)
	var last := region.network.get_segments()[-1]
	var p1 := last.curve.sample_baked(last.length-15,true)
	var station_tool := build.get_tool(&"station") as StationBuildTool
	check(station_tool.click_at(p0+Vector3(4,0,0)),"first wooden halt built: "+station_tool.get_status())
	check(station_tool.click_at(p1+Vector3(4,0,0)),"second wooden halt built: "+station_tool.get_status())
	await frames(4)
	check(region.stations.size()==2,"two independent stations")
	if region.stations.size()!=2:
		_finish()
		return
	build.undo()
	check(region.stations.size()==1,"station undo removes halt")
	build.redo()
	check(region.stations.size()==2,"station redo rebuilds halt")
	await frames(4)
	var line := region.add_line(region.stations[0].station_id,region.stations[1].station_id,"diesel_heritage")
	check(not line.is_empty(),"first train assigned to local line")
	if line.is_empty():
		_finish()
		return
	var train := region.train_for_line(int(line["id"]))
	check(train!=null,"first train appears immediately")
	check(float(Achievements.progress.get("all_aboard",0))==0,"initial boarding halt does not count as completed arrival")
	var saw_step := false
	var saw_open := false
	var arrived := false
	var reversed := false
	var unsafe := false
	var max_passengers := 0
	var before_reverse := Vector3.ZERO
	var previous_side := false
	for i in 18000:
		await get_tree().physics_frame
		if not is_instance_valid(train):
			break
		saw_step = saw_step or train.get_step_amount()>0.5
		saw_open = saw_open or train.doors_open()
		for car in train.cars:
			unsafe = unsafe or (train.speed>0.02 and (car.get_door_amount()>0.001 or car.get_step_amount()>0.001))
		arrived = arrived or region.progression.services>=1
		var this_side := train.cars[0].travel_reversed
		if this_side != previous_side:
			reversed = true
			check(train.cars[0].global_position.distance_to(before_reverse)<0.25,"turnaround keeps car at the same location")
			previous_side = this_side
		before_reverse = train.cars[0].global_position
		max_passengers = maxi(max_passengers,region.progression.passengers)
		if reversed and max_passengers>=4 and region.progression.services>=3:
			break
	check(saw_step and saw_open,"steps extend before boarding, doors animate")
	check(not unsafe,"train never moves with open doors or extended steps")
	check(arrived,"first successful arrival")
	check(float(Achievements.progress.get("all_aboard",0))>=1,"completed regional arrival awards existing achievement")
	check(max_passengers>0,"actual NPC alighting counts as transport")
	check(reversed,"service returns without disappearing")
	check(region.village.get_houses().size()>0,"rail service creates organic construction")
	region.progression.passengers = 12
	region.progression.services = 3
	region.progression.refresh()
	check(region.progression.epoch==2,"actual network and transport unlock epoch two")
	check(region.progression.is_train_unlocked("diesel_heritage") and region.progression.is_train_unlocked("nostalgic_regional"),"new epoch preserves old trains")
	region.stations[0].services = 3
	check(region.stations[0].upgrade(),"station upgrade independently available")
	check(region.stations[1].level==1,"other halt remains small")
	var state := region.save_state()
	var progress_state := region.progression.save_state()
	check(SaveManager.save_game("progression_roundtrip"),"save new progression journey")
	region.progression.passengers = 9999
	region.remove_line(int(line["id"]))
	check(SaveManager.load_game("progression_roundtrip"),"load progression journey")
	check(region.progression.passengers==int(progress_state["passengers"]),"transport counters restored exactly")
	check(region.lines.size()==state["lines"].size(),"train assignments and lines restored")
	check(region.stations[0].level==2 and region.stations[1].level==1,"mixed station stages saved")
	check(region.stations[0].house_ids==state["stations"][0]["houses"],"local growth links restored")
	var ui := main.get_node("RegionPanel") as RegionPanel
	for page in ["epochs","stations","station","lines","fleet"]:
		ui.open_page(page)
		await frames(2)
		check(ui._panel.visible,"UI opens: "+page)
	ui.close()
	check(not WorldClock.paused,"UI restores simulation pause state")
	SaveManager.delete_save("progression_roundtrip")
	_finish()

func _test_models() -> void:
	for id in EpochCatalog.TRAIN_IDS:
		var type := EpochCatalog.train(id)
		check(type!=null,"train definition: "+id)
		var total_triangles := 0
		var capacity := 0
		for i in type.consist.size():
			var kind := type.consist[i]
			var cargo: Dictionary = TrainMeshes.CARGO.get(kind,{})
			if not cargo.is_empty():
				capacity += int(cargo["amount"])*cargo["slots"].size()*maxi(1,int(cargo.get("bulk",0)))
			var parts := TrainMeshes.build_car(kind,type.get_livery(),i)
			var valid := true
			for key in ["paint","glass","interior","light_front","light_rear"]:
				var mesh: ArrayMesh = parts.get(key)
				if mesh==null:
					continue
				for surface in mesh.get_surface_count():
					var arrays := mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					total_triangles += vertices.size()/3
					for vertex in vertices:
						valid = valid and vertex.is_finite()
					for normal in normals:
						valid = valid and normal.is_finite() and normal.length()>0.8
			check(valid,"finite authored geometry: "+kind)
			if type.category==TrainType.Category.PASSENGER and not kind.ends_with("loco"):
				check(parts["doors"].size()>=4,"separate paired doors: "+kind)
				check(parts.get("interior")!=null,"real cabin furniture: "+kind)
		check(total_triangles<100000,"whole train geometry budget: %s (%d triangles)" % [id,total_triangles])
		if type.category==TrainType.Category.FREIGHT:
			check(capacity==type.cargo_capacity,"advertised capacity matches actual wagon load: "+id)
	for level in range(1,7):
		var parts := EpochStationMeshes.build(level)
		check(parts["paint"]!=null and parts["glow"]!=null,"station architecture: stage %d" % level)

func _finish() -> void:
	print("PROGRESSION RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
