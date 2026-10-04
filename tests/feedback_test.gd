## Regression of photographed path seams, missing lights and playable waiting time.
extends Node
var checks := 0
var failures := 0
var main: Node3D
var region: RegionRailway
var activities: VillageActivities
var player: PlayerController

func check(ok: bool,label: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("PASS " if ok else "FAIL ",label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await frames(12)
	WorldClock.paused = true
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyGuide").set_process(false)
	main.get_node("BuildMode").set_process(false)
	region = main.get("region")
	activities = main.get_node("VillageActivities")
	player = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	region.progression.epoch = 2
	var station := region.build_station({"id":91,"name":"Wintervale","level":2,"pos":[-55,0,-25],"angle":0},false)
	station.set_dark(true)
	var forecourt_lights := 0
	for light in station._platform_lights:
		if light.position.x>17 and light.light_energy>0:
			forecourt_lights += 1
	check(forecourt_lights==2,"both glowing forecourt lanterns have active real lights")
	station.set_dark(false)
	check(station._platform_lights.all(func(light: OmniLight3D) -> bool: return light.light_energy==0),"daytime turns every forecourt light off")
	_test_polygons()
	var a := region.village.prepare("path_gravel",Vector3(25,0,25),0,0,Vector3(45,0,25))
	var b := region.village.prepare("path_gravel",Vector3(35,0,25),0,0,Vector3(35,0,42))
	region.village.place(a)
	region.village.place(b)
	region.village.rebuild_path_surfaces()
	check(region.village._path_surface_root.get_child_count()==1,"connected same-style paths render as one surface")
	check(not (region.village.get_object(int(a["id"])) as VillagePath)._mesh.visible,"old coplanar strip is hidden")
	region.village.remove(int(b["id"]))
	region.village.rebuild_path_surfaces()
	check(region.village._path_surface_root.get_child_count()==1,"removing a branch regenerates the remaining surface")
	_test_shop()
	var home_data := region.village.prepare("house_cottage",station.to_global(Vector3(28,0,9)),0)
	home_data["since"] = 1
	home_data["seed"] = 3
	var home := region.village.place(home_data) as VillageHouse
	activities._sync_boards()
	check(activities._boards.size()==1,"station has an interactive activity board")
	var cash := Economy.money
	check(activities.start_job("cleanup",91),"cleanup available from the first station")
	var buried := SaveUtils.array_to_vec3(activities.active["points"][0])
	var obstacle := region.village.prepare("house_cottage",buried,0)
	region.village.place(obstacle)
	check(not activities.active.is_empty() and SaveUtils.array_to_vec3(activities.active["points"][0]).distance_to(buried)>0.1,"building a house relocates a task item to reachable ground")
	region.village.remove(int(obstacle["id"]))
	check(not activities.act(0,player),"distant player cannot complete a task")
	for i in 3:
		player.global_position = SaveUtils.array_to_vec3(activities.active["points"][i])
		check(activities.act(i,player),"character collects paper %d" % (i+1))
		check(not activities.act(i,player),"paper cannot be credited twice")
	check(int(activities.completed["cleanup"])==1 and activities.active.is_empty(),"one completed cleanup enters the journal")
	check(not activities.start_job("cleanup",91),"same daily round does not respawn repeatedly")
	check(activities.start_job("mail",91),"inhabited home unlocks a postal round")
	player.global_position = SaveUtils.array_to_vec3(activities.active["points"][1])
	check(not activities.act(1,player),"mail must be collected before delivery")
	player.global_position = SaveUtils.array_to_vec3(activities.active["points"][0])
	check(activities.act(0,player) and player.get_model().carry==CharacterModel.Carry.SHOPPING_BAG,"character visibly carries the postal bag")
	check(SaveManager.save_game("feedback_activity"),"save an unfinished postal round")
	activities.cancel_job()
	check(player.get_model().carry==CharacterModel.Carry.NONE,"cancelling releases the postal bag")
	check(SaveManager.load_game("feedback_activity"),"load the unfinished round")
	await frames(6)
	check(not activities.active.is_empty() and bool(activities.active["done"][0]) and player.get_model().carry==CharacterModel.Carry.SHOPPING_BAG,"progress and postal bag survive save/load")
	player.global_position = SaveUtils.array_to_vec3(activities.active["points"][1])
	check(activities.act(1,player) and int(activities.completed["mail"])==1,"post reaches the saved household")
	check(activities.start_job("walk",91),"discovery walk supplies three reachable points")
	for i in 3:
		player.global_position = SaveUtils.array_to_vec3(activities.active["points"][i])
		check(activities.act(i,player),"character discovers viewpoint %d" % (i+1))
	check(int(activities.completed["walk"])==1 and activities.history.size()==3,"three different activities leave saved memories")
	check(Economy.money==cash,"activities never accelerate money income")
	WorldClock.day += 1
	check(activities.start_job("cleanup",91),"a new day unlocks another character round")
	check(SaveManager.save_game("feedback_old"),"prepare compatibility fixture")
	var old := SaveManager.read_save_data("feedback_old")
	old["objects"].erase(VillageActivities.SAVE_ID)
	var file := FileAccess.open(SaveManager.get_save_path("feedback_old"),FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(SaveManager.load_game("feedback_old"),"load a journey created before character rounds")
	await frames(6)
	check(activities.active.is_empty() and activities.history.is_empty() and int(activities.completed["cleanup"])==0,"old journey never inherits another save's active round or journal")
	var notebook := main.get_node("Notebook") as Notebook
	notebook.open("activities")
	await frames(4)
	check(notebook.get_page()=="activities" and notebook.find_children("*","Label",true,false).size()>6,"activity page contains jobs, status and journal")
	notebook.open("storage")
	await frames(4)
	var buttons := notebook.find_children("*","Button",true,false).filter(func(node: Node) -> bool: return node is Button and (node as Button).text.contains("kaufen"))
	check(buttons.size()==5,"stock page exposes early purchase buttons for all materials")
	notebook.close()
	SaveManager.delete_save("feedback_activity")
	SaveManager.delete_save("feedback_old")
	print("FEEDBACK RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _test_polygons() -> void:
	var height := func(_x: float,_z: float) -> float: return 0.0
	var a := PackedVector3Array([Vector3.ZERO,Vector3(10,0,0)])
	var b := PackedVector3Array([Vector3(5,0,0),Vector3(5,0,8)])
	var shape := PathSurface.contours([a,b],0.8)
	check(shape["outer"].size()==1,"T junction has a unified outline")
	check(shape["outer"][0].size()>8,"junction inner corners are rounded")
	var mesh := PathMeshes.build_network("path_gravel",[a,b],height)
	check(mesh.get_surface_count()==1,"merged path has one surface and no snow-wall geometry")
	check(mesh.get_aabb().position.x>=-0.2 and mesh.get_aabb().end.x<=10.2,"free ends have no protruding circular cap")
	check(mesh.get_aabb().end.y<0.08,"path verges remain flat")
	var loop: Array = []
	var corners := [Vector3.ZERO,Vector3(10,0,0),Vector3(10,0,10),Vector3(0,0,10)]
	for i in 4:
		loop.append(PackedVector3Array([corners[i],corners[(i+1)%4]]))
	shape = PathSurface.contours(loop,0.8)
	check(shape["holes"].size()==1 and Geometry2D.is_point_in_polygon(Vector2(5,5),shape["holes"][0]),"closed path loop preserves its garden")
	mesh = PathMeshes.build_network("path_gravel",loop,height)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var covered := false
	for i in range(0,vertices.size(),3):
		covered = covered or Geometry2D.point_is_inside_triangle(Vector2(5,5),Vector2(vertices[i].x,vertices[i].z),Vector2(vertices[i+1].x,vertices[i+1].z),Vector2(vertices[i+2].x,vertices[i+2].z))
	check(not covered,"loop triangulation does not pave over the garden")

func _test_shop() -> void:
	Economy.money = 3000
	var before := Economy.get_stock("wood")
	check(Economy.buy_material("wood",5),"Nordtal sells materials before freight unlock")
	check(Economy.get_stock("wood")==before+5 and Economy.money==2985,"purchase charges the displayed trade price")
	Economy.money = 0
	before = Economy.get_stock("wood")
	check(not Economy.buy_material("wood",5) and Economy.get_stock("wood")==before,"unaffordable purchase changes no stock")
	check(not Economy.buy_material("unknown",5) and not Economy.buy_material("wood",-5),"invalid purchases are rejected")
	Economy.money = 3000
