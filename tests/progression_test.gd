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
	# Neues Spiel: nur der Tunnelanschluss Nordtal liegt schon da.
	check(region.portals.size()==1 and region.portals[0].station_name=="Nordtal","new game opens the Nordtal tunnel")
	var portal: RegionPortal = region.portals[0] if region.portals.size()>0 else null
	if portal==null:
		_finish()
		return
	check(region.network.get_segment_count()==portal.track_ids.size() and portal.track_ids.size()==2,"only the tunnel connection exists at start")
	check(region.stations.is_empty(),"new game starts without stations")
	check(region.village.get_object_count()==0,"new game starts without a city")
	check(region.dispatcher.get_trains().is_empty(),"new game starts without traffic")
	check(float(region.progression.metrics()["rail_length"])==0.0,"tunnel connection does not count as own track")
	check(region.progression.epoch==1,"epoch one at start")
	check(region.progression.is_train_unlocked("diesel_heritage") and not region.progression.is_train_unlocked("high_speed"),"initial unlocks")
	check(not region.progression.tool_unlocked(&"switch"),"later tools gated")
	check(region.progression.tool_unlocked(&"village_houses") and region.progression.tool_unlocked(&"village_paths"),"town building available from the start")
	check(main.get_node("World/FreightYard").get_child_count()==0,"no premade freight yard")
	_test_models()
	# Real rail tool: connect to the stub in front of the tunnel and build into the valley.
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.select_tool(&"rail")
	var tool := build.get_tool(&"rail") as RailPlaceTool
	var stub := portal.get_stub_end()
	tool.click_at(stub,true)
	var built := tool.click_at(Vector3(stub.x,0,stub.z+50),true)
	built = tool.click_at(Vector3(stub.x,0,stub.z+100),true) and built
	check(built,"own track connected to the tunnel with the existing tool: "+tool.get_status())
	tool.cancel()
	build.set_process(false)
	await frames(4)
	if not built:
		_finish()
		return
	check(region.connected_length(portal)>=95.0,"connected length measured from the tunnel")
	var remover := build.get_tool(&"remove") as RailRemoveTool
	var before_segments := region.network.get_segment_count()
	check(not remover.remove_at(portal.get_mouth()+portal.global_basis.z*5.0) and region.network.get_segment_count()==before_segments,"tunnel connection cannot be demolished")
	var station_tool := build.get_tool(&"station") as StationBuildTool
	var p0 := Vector3(stub.x+4,0,stub.z+42)
	var p1 := Vector3(stub.x+4,0,stub.z+86)
	check(region.placement(Vector3(stub.x+4,0,stub.z+4)).get("reason","")!="","halts keep a distance to the tunnel")
	check(region.village.check_placement("house_cottage",Vector3(stub.x+30,0,stub.z+40),0)!="","houses need a halt first")
	check(station_tool.click_at(p0),"first wooden halt built: "+station_tool.get_status())
	check(station_tool.click_at(p1),"second wooden halt built: "+station_tool.get_status())
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
	var first := region.stations[0]
	check(region.line_reason(portal.station_id,portal.station_id,"diesel_heritage")!="","no line from a tunnel to itself")
	var line := region.add_line(portal.station_id,first.station_id,"diesel_heritage")
	check(not line.is_empty(),"first train assigned from the tunnel: "+region.line_reason(portal.station_id,first.station_id,"diesel_heritage"))
	if line.is_empty():
		_finish()
		return
	var train := region.train_for_line(int(line["id"]))
	check(train!=null,"first train appears immediately")
	check(train!=null and train.path.segment_ids[0]==portal.get_end_segment().id,"train starts deep inside the tunnel, not out of nothing")
	check(train!=null and not train.cars[0].visible,"cars deep in the tunnel are hidden")
	check(float(Achievements.progress.get("all_aboard",0))==0,"no arrival before the train reaches the halt")
	# A player-built house; its family arrives with a train from the tunnel.
	var house_point := first.to_global(Vector3(28,0,0))
	check(region.village.check_placement("house_cottage",house_point,first.rotation.y+PI/2)=="","player can place a house near the halt")
	var house_data := region.village.prepare("house_cottage",house_point,first.rotation.y+PI/2)
	house_data["paid"] = true
	house_data["build"] = 0.9999
	var house: VillageHouse = region.village.build(house_data)
	var saw_step := false
	var saw_open := false
	var arrived := false
	var vanished := false
	var unsafe := false
	var max_passengers := 0
	var houses_before := region.village.get_houses().size()
	var family_waited := false
	for i in 24000:
		await get_tree().physics_frame
		if not is_instance_valid(train):
			vanished = true
			train = region.train_for_line(int(line["id"]))
			if train==null:
				continue
		saw_step = saw_step or train.get_step_amount()>0.5
		saw_open = saw_open or train.doors_open()
		for car in train.cars:
			unsafe = unsafe or (train.speed>0.02 and (car.get_door_amount()>0.001 or car.get_step_amount()>0.001))
		arrived = arrived or region.progression.services>=1
		family_waited = family_waited or first.waiting_houses.has(house.object_id)
		max_passengers = maxi(max_passengers,region.progression.passengers)
		if vanished and max_passengers>=4 and region.progression.services>=3 and first.population>0:
			break
	check(saw_step and saw_open,"steps extend before boarding, doors animate")
	check(not unsafe,"train never moves with open doors or extended steps")
	check(arrived,"first successful arrival")
	check(float(Achievements.progress.get("all_aboard",0))>=1,"completed regional arrival awards existing achievement")
	check(max_passengers>0,"guests and travellers count as transport")
	check(vanished,"train returns into the tunnel and disappears there")
	check(house.is_finished(),"player house finishes")
	check(family_waited,"finished house waits for its family")
	check(first.population>0 and first.waiting_houses.is_empty(),"family arrives by train and counts as residents")
	check(region.village.get_houses().size()==houses_before,"no automatic town growth")
	region.progression.passengers = 20
	region.progression.services = 5
	first.population = 4
	region.progression.refresh()
	check(region.progression.epoch==2,"actual network and transport unlock epoch two")
	check(region.progression.is_train_unlocked("diesel_heritage") and region.progression.is_train_unlocked("nostalgic_regional"),"new epoch preserves old trains")
	first.services = 3
	check(first.upgrade(),"station upgrade independently available")
	check(region.stations[1].level==1,"other halt remains small")
	# A line between two own halts first travels in through the tunnel.
	var local := region.add_line(first.station_id,region.stations[1].station_id,"diesel_heritage")
	check(not local.is_empty() and not bool(local.get("delivered",true)),"own-station line starts with a delivery run")
	region.remove_line(int(local.get("id",-1)))
	var state := region.save_state()
	var progress_state := region.progression.save_state()
	check(SaveManager.save_game("progression_roundtrip"),"save new progression journey")
	region.progression.passengers = 9999
	region.remove_line(int(line["id"]))
	check(SaveManager.load_game("progression_roundtrip"),"load progression journey")
	await frames(4)
	check(region.progression.passengers==int(progress_state["passengers"]),"transport counters restored exactly")
	check(region.lines.size()==state["lines"].size(),"train assignments and lines restored")
	check(region.stations[0].level==2 and region.stations[1].level==1,"mixed station stages saved")
	check(region.stations[0].house_ids==state["stations"][0]["houses"],"house links restored")
	check(region.portals.size()==1 and region.portals[0].passenger_total==int(state["portals"][0]["passengers"]),"tunnel counters restored")
	check(region.network.find_node_near(region.portals[0].get_deep_end(),3.0)!=null,"tunnel track restored with the network")
	region.progression.set_epoch(3,true)
	await frames(2)
	check(region.portals.size()==2 and region.station_by_name("Südtal")!=null,"epoch three opens the Südtal tunnel")
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
			if type.category==TrainType.Category.PASSENGER and not kind.trim_suffix("_rear").ends_with("loco"):
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
