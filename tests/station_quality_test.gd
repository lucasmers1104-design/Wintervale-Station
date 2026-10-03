## Physics regressions from the October screenshots: real player movement,
## roofs, furniture clearance, permanent households and the early game.
extends Node

var failures := 0
var checks := 0
var main: Node3D
var region: RegionRailway
var player: PlayerController

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
	WorldClock.paused = true
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	region = main.get("region")
	player = main.get_node("Player")
	await frames(10)
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("ViewModeController").set_mode(GameDefs.ViewMode.EXPLORE,true)
	var station := region.build_station({"id":81,"name":"Qualitätsprobe","level":1,"pos":[-35,0,0],"angle":0},false)
	await frames(4)
	station.director.enabled = false
	for level in range(1,7):
		station.level = level
		station.rotation.y = PI/2 if level%2==0 else 0.0
		station.rebuild()
		region.terrain.flush_changes()
		await frames(4)
		var data := StationAccess.describe(level)
		var back := float(data["back"])
		var z := float(data["z"])
		var height := float(data["height"])
		player.set_first_person(level%2==0)
		await walk(station,Vector3(back+3.2,0.2,z),Vector3(back-0.7,height,z),PI/2,"station %d: walk up stairs without jumping" % level)
		await walk(station,Vector3(back-0.7,height+0.1,z),Vector3(back+3.2,0,z),-PI/2,"station %d: walk down stairs without sticking" % level)
		await walk(station,Vector3(2.65,height+0.05,-7),Vector3(2.65,height,7),PI,"station %d: platform lane clear of benches, carts and supports" % level)
		var edge := float(data["length"])/2
		var center_x := 1.78+float(data["width"])/2
		if level==1:
			for end: float in [-1,1]:
				await walk(station,Vector3(center_x,0.2,end*(edge+3.2)),Vector3(center_x,height,end*(edge-0.8)),0.0 if end>0 else PI,"timber halt: end stairs %s remain walkable" % end)
		else:
			await walk(station,Vector3(center_x,0.2,edge+0.4),Vector3(center_x,height,edge-3.1),0.0,"station %d: end ramp connects smoothly to platform" % level)
		var start := station.to_global(Vector3(20,0,z))
		var query := PhysicsRayQueryParameters3D.create(start+Vector3.UP*3,start+Vector3.DOWN,GameDefs.LAYER_OBJECTS|GameDefs.LAYER_WORLD)
		var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),"station %d: approach has a physical floor" % level)
		if level<=2:
			var roof_point := Vector3(float(data["back"])-0.85,height+1.8,-2.0) if level==1 else Vector3(1.78+float(data["width"])/2+0.55,height+1.8,4)
			var below := station.to_global(roof_point)
			query = PhysicsRayQueryParameters3D.create(below,below+Vector3.UP*2,GameDefs.LAYER_OBJECTS)
			hit = get_viewport().world_3d.direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and (hit["normal"] as Vector3).y < -0.8,"station %d: closed roof visible and solid from below" % level)
	await test_households(station)
	test_early_progression(station)
	test_snow_collision()
	await test_vehicle_and_walls()
	test_clearings(station)
	check(region.terrain.flat_radius>=70 and region.terrain.hill_height<=1.5,"broad, gently rolling buildable valley")
	Input.action_release(&"move_forward")
	print("STATION QUALITY RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func walk(station: RegionStation, start: Vector3, goal: Vector3, yaw: float, label: String) -> void:
	Input.action_release(&"move_forward")
	player.global_position = station.to_global(start)
	player.velocity = Vector3.ZERO
	player._yaw = station.rotation.y+yaw
	player.snap_camera()
	await frames(15)
	Input.action_press(&"move_forward")
	var reached := false
	for i in 320:
		await get_tree().physics_frame
		var p := station.to_local(player.global_position)
		if Vector2(p.x-goal.x,p.z-goal.z).length()<0.18:
			reached = absf(p.y-goal.y)<0.13
			break
	Input.action_release(&"move_forward")
	check(reached,label+" ("+str(station.to_local(player.global_position))+")")
	if not reached and label.contains("up stairs"):
		var m := Basis(Vector3.UP,player._yaw)*Vector3(0,0,-0.047)
		var r := KinematicCollision3D.new()
		var up := Vector3.UP*player.max_step_height
		var raised := player.global_transform
		raised.origin += up
		print("STEP DEBUG floor=",player.is_on_floor()," velocity=",player.velocity," horizontal=",player.test_move(player.global_transform,m,r)," normal=",r.get_normal()," up=",player.test_move(player.global_transform,up)," raised=",player.test_move(raised,m))
		raised.origin += m
		print("STEP DOWN ",player.test_move(raised,-up,r)," travel=",r.get_travel()," normal=",r.get_normal())
	await frames(8)

func test_households(station: RegionStation) -> void:
	var data := region.village.prepare("house_cottage",Vector3(30,0,30),0)
	data["build"] = 1.0
	data["since"] = 1
	var house := region.village.place(data) as VillageHouse
	region.refresh()
	var before := station.population
	var profiles := station.director.profiles.duplicate()
	check(before>0,"settled family counted")
	for day in range(2,8):
		region.village._on_day_changed(day)
		region.refresh()
		check(station.population==before and not station.waiting_houses.has(house.object_id),"day %d: settled family remains at home" % day)
	check(station.director.profiles==profiles,"daily update does not duplicate residents")
	station.waiting_houses.append(house.object_id)
	region.village._on_day_changed(8)
	check(station.waiting_houses.has(house.object_id),"genuinely waiting family still needs an arriving train")
	var freight := Train.new()
	freight.train_type = EpochCatalog.train("reference_freight")
	region.deliver_families(station,freight)
	check(station.waiting_houses.has(house.object_id),"freight cannot deliver passenger households")
	freight.free()
	station.waiting_houses.erase(house.object_id)
	var residents := station.director.get_npcs()
	if not residents.is_empty():
		var npc := residents[0]
		npc.leave_to_village()
		check(npc.state==Npc.State.GOING_HOME,"named residents go home instead of being deleted as visitors")
	region.village.remove(house.object_id)
	await frames(2)

func test_early_progression(station: RegionStation) -> void:
	region.progression.epoch = 2
	region.progression.passengers = 60
	region.progression.services = 12
	station.population = 12
	region.lines.append({"id":900,"a":1001,"b":81,"train":"diesel_heritage","enabled":true})
	# Real topology validity is covered by progression_test. Check every early
	# requirement here with exactly one connected town at the design boundary.
	var requirements: Dictionary = EpochCatalog.epoch(3)["requirements"]
	check(int(requirements.get("connected",0))==1,"epoch two can finish with one served station")
	check(int(EpochCatalog.epoch(4)["requirements"].get("connected",0))>1,"later regional expansion retains its purpose")
	region.lines.clear()

func test_snow_collision() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyBuilder.add_box(st,Vector3.ZERO,Vector3.ONE,Color.WHITE)
	LowPolyBuilder.add_box(st,Vector3(0,0.6,0),Vector3(1,0.2,1),StationMeshes.SNOW)
	var mesh := st.commit()
	check(LowPolyBuilder.solid_collision(mesh).get_faces().size()==36,"seasonal snow adds no invisible collision after melting")

func test_clearings(station: RegionStation) -> void:
	region.village.nature.refresh_clearings()
	var safe := true
	for record in region.village.nature._records:
		if bool(record.get("cleared",false)):
			# The headless dummy renderer cannot read MultiMesh transforms back.
			var shown: Transform3D = record["render_transform"]
			safe = safe and shown.origin.y < -400 and not is_zero_approx(shown.basis.x.length()) and (record["collider"] as CollisionShape3D).disabled
	check(safe,"cleared trees have no singular transform, visible fragments or collision")
	station.platform_tracks.append({"pos":[30,0,-20],"angle":0})
	check(station.clears(34,-20),"parallel platforms clear their own vegetation")
	station.platform_tracks.clear()

func test_vehicle_and_walls() -> void:
	var factory := TrainDispatcher.new()
	var materials := {"paint":load("res://assets/materials/train_paint.tres"),"glass":load("res://assets/materials/train_glass.tres"),"cargo":load("res://assets/materials/cargo.tres"),"lamp_white":factory._lamp_material(Color.WHITE,1),"lamp_red":factory._lamp_material(Color.RED,1),"lamp_idle_white":factory._lens_material(Color.WHITE),"lamp_idle_red":factory._lens_material(Color.RED),"snow":factory._snow_material(),"festive":factory._festive_material()}
	factory.free()
	var type := EpochCatalog.train("diesel_heritage")
	var car := TrainCar.new()
	main.add_child(car)
	car.build(type.consist[0],type,true,true,materials,0)
	car.position = Vector3(40,0,0)
	player.input_enabled = false
	player.set_physics_process(false)
	player.global_position = Vector3(43,1.33,0)
	await frames(3)
	check(player.test_move(player.global_transform,Vector3(-4,0,0)),"real train body stops the player")
	check((player.get_node("CameraYaw/CameraPitch/SpringArm3D") as SpringArm3D).collision_mask & GameDefs.LAYER_TRAINS != 0,"third-person camera avoids trains")
	player.velocity = Vector3(-2.8,0,0)
	var before := player.global_position
	player._try_step_up(0.5)
	check(player.global_position.is_equal_approx(before),"step assistance cannot lift the player through a train wall")
	car.queue_free()
	await frames(2)
	player.set_physics_process(true)
