## Curves, true junctions, budgets, upgrade safety and camera physics in the real world.
extends Node
var main: Node3D
var region: RegionRailway
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("PASS " if ok else "FAIL ",label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	WorldClock.paused = true
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("BuildMode").set_process(false)
	region = main.get("region")
	region.progression.epoch = 4
	Economy.money = 10000
	Economy.add_stock("stone",200)
	var station := region.build_station({"id":91,"name":"Dorfprobe","level":1,"pos":[-55,0,-25],"angle":0},false)
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.select_tool(&"village_paths")
	var tool := build.get_current_tool() as VillagePlaceTool
	tool.select_item("path_gravel")
	var before := Economy.money
	var stone_before := Economy.get_stock("stone")
	tool.click_at(Vector3(25,0,25))
	check(tool.has_start() and tool._marker.visible,"first-click anchor remains visible")
	var mode_key := InputEventAction.new()
	mode_key.action = &"build_variant"
	mode_key.pressed = true
	tool.handle_input(mode_key)
	check(tool._path_curved,"variant key switches to a curve")
	tool.preview_at(Vector3(45,0,25))
	var quoted := tool.get_cost_at(Vector3(45,0,25))
	check(tool.is_valid() and tool._path_label.visible and tool._path_label.text.contains("m ·"),"curve preview shows length and price")
	check(tool.click_at(Vector3(45,0,25)),"curved path builds as one action")
	var paths: Array = region.village.get_objects().filter(func(obj: Node3D) -> bool: return obj is VillagePath)
	var path: VillagePath = paths[0]
	var route := path.route_points.duplicate()
	var id := path.object_id
	check(paths.size()==1 and route.size()>2,"one saved object contains the whole bend")
	check(path.get_length()>20 and path.get_length()<=30.01,"curved length measures the bend, not its chord")
	check(before-Economy.money==int(quoted["money"]) and stone_before-Economy.get_stock("stone")==int(quoted["stone"]),"preview and charged resources agree exactly")
	check(path.distance_to(route[route.size()/2])<0.01,"picking and footsteps follow the curved centreline")
	check(region.village.check_path_route("path_gravel",PackedVector3Array([route[0],route[-1]]))=="","same endpoints may form a different straight route")
	check(region.village.check_path_route("path_gravel",route).contains("bereits"),"duplicate path rejected before charging")
	build.undo()
	check(region.village.get_object_count("path")==0 and Economy.money==before and Economy.get_stock("stone")==stone_before,"one undo removes the entire bend and refunds exactly")
	build.redo()
	path = region.village.get_object(id) as VillagePath
	check(path!=null and path.route_points==route,"redo restores the curve")
	tool.cancel()
	tool.set_path_curved(false)
	var middle := route[route.size()/2]
	var snapped := region.village.snap_path_point(middle+Vector3(0,0,0.2))
	check(path.distance_to(snapped)<0.01,"branches snap to curved paths")
	tool.click_at(middle)
	check(tool.click_at(Vector3(35,0,42)),"T branch builds on the curved path")
	var branch: VillagePath = region.village.get_objects().filter(func(obj: Node3D) -> bool: return obj is VillagePath)[-1]
	var old_branch_mesh := branch._mesh.mesh
	tool.cancel()
	tool.click_at(Vector3(25,0,36))
	check(tool.click_at(Vector3(45,0,36)),"crossing path builds")
	check(branch._mesh.mesh!=old_branch_mesh,"crossing clears old snow banks even when all endpoints are distant")
	region.village.rebuild_walk_network()
	var graph := region.village.walk_graph
	var crossing_path := graph.find_path(Vector3(35,0,42),Vector3(45,0,36))
	var junction := false
	for point in crossing_path:
		junction = junction or point.distance_to(Vector3(35,0,36))<0.15
	check(junction,"X crossing becomes an actual route junction")
	check(station.director.walk_graph.get_dynamic_point_count()>0,"regional residents receive the village path network")
	tool.cancel()
	tool.set_path_curved(true)
	tool.click_at(Vector3(65,0,15))
	tool.preview_at(Vector3(65,0,110))
	check(PathMeshes.route_length(tool._preview_route)<=30.01,"curve limit includes its real arc length")
	tool.cancel()
	var house_data := region.village.prepare("house_cottage",station.to_global(Vector3(12,0,18)),0)
	var house := region.village.place(house_data) as VillageHouse
	check(station.upgrade_space_reason().contains("Häuschen"),"station enlargement protects an existing house")
	var funds := Economy.money
	station.services = 100
	check(not station.upgrade() and station.level==1 and Economy.money==funds,"blocked upgrade changes neither building nor money")
	var door := house.get_front_point()
	check(RailGeometry.flat(region.village.snap_path_point(door+Vector3(0.3,0,0))-door).length()<0.01,"paths snap to house entrances")
	region.village.remove(house.object_id)
	await frames(3)
	var conflict := region.village.prepare("path_gravel",station.to_global(Vector3(-2,0,18)),0,0,station.to_global(Vector3(24,0,18)))
	var road := region.village.place(conflict) as VillagePath
	check(station.upgrade_space_reason().contains("Weg"),"station enlargement detects a path crossing between its endpoints")
	region.village.remove(road.object_id)
	await frames(3)
	check(station.upgrade_space_reason()=="" and station.upgrade(),"clear enlargement succeeds")
	check(station.resident_visual_limit()==8 and station.director.max_travellers==8,"larger stations increase resident and traveller capacity")
	check(station._visual.get_node_or_null("ForecourtPaving")!=null,"station approach uses the shared natural paving")
	for i in 6:
		var data := region.village.prepare("house_chalet",Vector3(-18+i*8,0,-50),0)
		data["seed"] = i*2+1
		data["build"] = 1.0
		data["since"] = 1
		region.village.place(data)
	region.refresh()
	check(station.population>8 and station.director.get_npcs().size()==8,"visual budget leaves every household in the census")
	station.level = 6
	station.rebuild()
	region.village.refresh_station_residents(station)
	check(station.director.get_npcs().size()>8 and station.director.get_npcs().size()<=20,"city upgrade shows more existing residents without replacing families")
	var plaza_data := region.village.prepare("plaza",Vector3(65,0,-5),0)
	var plaza := region.village.place(plaza_data) as VillageObject
	check(plaza.get_node_or_null("Paving")!=null,"plaza shares the path paving material")
	var rim := Vector3(70.8,0,-5)
	check(RailGeometry.flat(region.village.snap_path_point(rim+Vector3(0.4,0,0))-rim).length()<0.03,"paths snap to the plaza rim")
	check(region.village.check_placement("path_gravel",Vector3(80,0,-5),0,0,rim)=="","plaza rim accepts a path connection")
	check(region.village.check_placement("path_gravel",Vector3(70,0,-5),0,0,Vector3(60,0,-5)).contains("Brunnen"),"paths cannot run through the fountain")
	check(region.village.is_walkable(rim,Vector3(69.6,0,-5)),"free plaza paving is walkable")
	check(not region.village.is_walkable(Vector3(70,0,-5),Vector3(60,0,-5)),"walk connectors avoid the plaza fountain")
	region.village.place(region.village.prepare("path_gravel",Vector3(80,0,-5),0,0,rim))
	region.village.place(region.village.prepare("path_gravel",Vector3(50,0,-5),0,0,Vector3(59.2,0,-5)))
	region.village.rebuild_walk_network()
	var plaza_route := region.village.walk_graph.find_path(Vector3(80,0,-5),Vector3(50,0,-5))
	var uses_plaza_ring := false
	var through_fountain := false
	for point in plaza_route:
		var radius := RailGeometry.flat(point-plaza.position).length()
		uses_plaza_ring = uses_plaza_ring or absf(radius-4.6)<0.05
		through_fountain = through_fountain or radius<1.95
	check(uses_plaza_ring and not through_fountain,"opposite approaches connect around the plaza fountain")
	await test_camera()
	check(SaveManager.save_game("polish_routes"),"curves save with the normal save manager")
	check(SaveManager.load_game("polish_routes"),"curves load with the normal save manager")
	await frames(6)
	path = region.village.get_object(id) as VillagePath
	check(path!=null and path.route_points==route,"save/load retains curve points and endpoints")
	check(path!=null and absf(path.get_length()-PathMeshes.route_length(route))<0.001,"save/load retains actual curve cost length")
	print("PATH POLISH RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func test_camera() -> void:
	var player := main.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.set_process(false)
	var wall := StaticBody3D.new()
	wall.collision_layer = GameDefs.LAYER_OBJECTS
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2,4,4)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.position = Vector3(80,2,10)
	await frames(3)
	var anchor := Vector3(82,1.5,10)
	var safe := player._safe_camera_anchor(anchor,Vector3(78,1.5,10))
	check(safe.x>80.2,"smoothed camera pivot cannot lag through a wall")
	wall.queue_free()
	await frames(2)
