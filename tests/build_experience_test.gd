## Regression coverage for real stair walking, station grading, clamped construction
## and the interactive guide. Uses the existing save-manager QA sandbox.
extends Node
var failures := 0
var checks := 0
var main: Node3D
var region: RegionRailway

func check(ok: bool, title: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("PASS " if ok else "FAIL ",title)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	region = main.get("region")
	await frames(10)
	WorldClock.paused = true
	Economy.money = 100000
	main.get_node("JourneyTutorial").set_process(false)
	_test_deformer()
	var station := region.build_station({"id":71,"name":"Treppenprobe","level":1,"pos":[-30,2,-15],"angle":0},false)
	for level in range(1,7):
		station.level = level
		station.rebuild()
		region.terrain.flush_changes()
		await frames(3)
		var data := StationAccess.describe(level)
		var ground := station.to_global(Vector3(12,0,0))
		check(absf(region.terrain.get_height(ground.x,ground.z)-1.95)<0.02,"station %d grades full building footprint to rail-axis level" % level)
		var path := station.walk_route(station.to_global(Vector3(24,0,0)),station.to_global(Vector3(2.65,1.33,0)))
		var uses_stairs := false
		for point in path:
			var p := station.to_local(point)
			uses_stairs = uses_stairs or (absf(p.z-float(data["z"]))<0.1 and absf(p.x-(float(data["back"])-0.25))<0.1)
		check(uses_stairs,"station %d routes guests through the official entrance" % level)
		var heights := true
		for step in StationAccess.RISERS:
			var p := station.to_global(Vector3(float(data["back"])+(step+0.5)*StationAccess.TREAD,0,float(data["z"])))
			var expected := 2+1.33*(StationAccess.RISERS-step)/StationAccess.RISERS
			heights = heights and absf(station.director.ground_height(p,2)-expected)<0.02
		check(heights,"station %d uses seven correct stair heights instead of roofs or props" % level)
		var entrance := station.path_entrances()[0]
		check(region.village.snap_path_point(entrance+Vector3(0.4,0,0.25)).distance_to(entrance)<0.02,"station %d entrance is a real path snapping anchor" % level)
		if level in [1,6]:
			await _walk_stairs(station)
	_test_upgrade_repath(station)
	_test_platform_placement(station)
	_test_paths()
	await _test_guide()
	var train := EpochCatalog.train("nostalgic_regional")
	check(train.consist[0]=="heritage_loco" and train.consist[-1]=="heritage_loco_rear","epoch-two train has a locomotive at each physical end")
	var rear := TrainMeshes.build_car(train.consist[-1],train.get_livery(),3)
	check(rear["light_rear"].get_surface_count()>0 and rear["light_front"].get_surface_count()==0,"rear locomotive has outward-facing service lights")
	var original := region.terrain.get_base_height(-18,-15)
	region.remove_station(71)
	region.terrain.flush_changes()
	check(absf(region.terrain.get_height(-18,-15)-original)<0.01,"station removal restores terrain without leaving a saved deformation")
	print("BUILD EXPERIENCE RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _test_deformer() -> void:
	var terrain := TerrainDeformer.new()
	var fp := VillageFootprint.make(Vector3(0,0,0),Vector2(4,6),PI/4)
	terrain.set_pad(1,fp,2)
	check(is_equal_approx(terrain.sample(0,0,12).x,2),"rotated foundation flattens the interior")
	check(is_equal_approx(terrain.sample(30,30,12).x,12),"station grading preserves distant terrain")
	var bank := terrain.sample(6,6,12).x
	check(bank>2 and bank<12,"station grading blends softly into surrounding terrain")
	terrain.set_corridor(2,PackedVector3Array([Vector3(-10,1,0),Vector3(10,1,0)]))
	check(absf(terrain.sample(0,0,12).x-0.95)<0.001,"track core retains its own height beside a station pad")
	terrain.remove_pad(1)
	terrain.remove_corridor(2)
	check(is_equal_approx(terrain.sample(0,0,12).x,12),"removing all foundations restores natural ground")

func _walk_stairs(station: RegionStation) -> void:
	station.director.enabled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 902+station.level
	var npc := station.director.spawn_traveller(rng)
	var data := StationAccess.describe(station.level)
	npc.visible = true
	npc.state = Npc.State.AT_STATION
	npc._think_timer = 100000
	npc._busy = false
	npc.global_position = station.to_global(Vector3(20.8,-0.05,float(data["z"])))
	var result := {"done":false}
	npc.walk_to(station.to_global(Vector3(2.65,1.33,0)),func() -> void: result["done"] = true)
	WorldClock.paused = false
	var seen := {}
	var in_bounds := true
	for i in 4500:
		await get_tree().physics_frame
		var p := station.to_local(npc.global_position)
		if p.x>=float(data["back"]) and p.x<float(data["back"])+StationAccess.RISERS*StationAccess.TREAD:
			in_bounds = in_bounds and absf(p.z-float(data["z"]))<StationAccess.WIDTH/2
			seen[clampi(floori((p.x-float(data["back"]))/StationAccess.TREAD),0,6)] = true
		if bool(result["done"]):
			break
	check(bool(result["done"]) and seen.size()>=6 and in_bounds,"live NPC at station %d walks up the actual stair run" % station.level)
	check(absf(npc.global_position.y-(station.global_position.y+1.33))<0.10,"live NPC reaches platform at the correct elevation")
	WorldClock.paused = true
	station.director._travellers.erase(npc)
	npc.queue_free()
	station.director.enabled = true
	await frames(2)

func _test_upgrade_repath(station: RegionStation) -> void:
	station.level = 1
	station.rebuild()
	var rng := RandomNumberGenerator.new()
	rng.seed = 440
	var npc := station.director.spawn_traveller(rng)
	npc.visible = true
	npc.global_position = station.to_global(Vector3(20.8,0,7.4))
	var callback := func() -> void: pass
	npc.walk_to(station.to_global(Vector3(2.65,1.33,0)),callback,0.9)
	station.upgrade(true)
	var access := StationAccess.describe(2)
	var uses_new_stairs := false
	for point in npc._path:
		var p := station.to_local(point)
		uses_new_stairs = uses_new_stairs or (absf(p.z-float(access["z"]))<0.1 and absf(p.x-(float(access["back"])-0.25))<0.1)
	check(uses_new_stairs,"an upgrade reroutes an already walking traveller to the new stairs")
	check(npc._on_arrive==callback and is_equal_approx(npc._pace,0.9),"rerouting preserves the traveller's destination callback and walking pace")
	station.director._travellers.erase(npc)
	npc.queue_free()
	station.level = 6
	station.rebuild()

func _test_platform_placement(station: RegionStation) -> void:
	for x in [-20,-44]:
		var id := 900+absi(x)
		region.network.restore_segment({"id":id,"kind":0,"start_node":id,"end_node":id+1,"points":[[x,2,-65],[x,2,-22],[x,2,22],[x,2,65]]})
	var blocked := region.platform_placement(station.station_id,Vector3(-16,2,0))
	check(String(blocked["reason"]).contains("überlappt"),"extra platform cannot be placed through the main station building")
	var clear := region.platform_placement(station.station_id,Vector3(-40,2,0))
	check(String(clear["reason"])=="","extra platform remains available on a clear parallel track")
	region.network.remove_segment(920)
	region.network.remove_segment(944)

func _test_paths() -> void:
	var build := main.get_node("BuildMode") as BuildMode
	build.set_process(false)
	build.set_active(true)
	build.select_tool(&"village_paths")
	var tool := build.get_current_tool() as VillagePlaceTool
	tool.select_item("path_gravel")
	var start := Vector3(24,0,-10)
	tool.click_at(start)
	var built := tool.click_at(Vector3(24,0,110))
	check(built,"long pointer drag builds the bounded path shown in its preview")
	if built:
		var path: VillagePath = region.village.get_objects().filter(func(object: Node3D) -> bool: return object is VillagePath)[-1]
		var limit := float(VillageCatalog.get_item("path_gravel")["max_length"])
		check(absf(path.start_point.distance_to(path.end_point)-limit)<0.10,"placed path endpoint and charged length agree with the maximum preview length")
		check(tool._start.distance_to(path.end_point)<0.10,"continuing a path starts from its actual endpoint")
		build.undo()
		check(region.village.get_object_count("path")==0,"path feedback preserves undo semantics")
		build.redo()
		check(region.village.get_object_count("path")==1,"path feedback preserves redo semantics")
	check(not tool.click_at(Vector3.INF),"invalid mouse hit cannot create corrupt building coordinates")
	for i in 18:
		build.context.feedback.confirm("path",start)
	check(build.context.feedback._effects.size()<=12,"placement effects remain bounded during rapid building")
	build.set_active(false)

func _test_guide() -> void:
	var guide := main.get_node("JourneyGuide") as JourneyGuide
	WorldClock.paused = false
	guide._notebook().open("storage")
	guide.start_tour()
	check(not guide._notebook().is_open,"manual help closes an already open notebook before starting its tour")
	check(guide._steps.size()==13,"guide covers management tabs, all six notebook pages and world controls")
	for i in guide._steps.size():
		await frames(8)
		var page := String(guide._steps[guide._index]["page"])
		var card := guide._card.get_global_rect()
		check(get_viewport().get_visible_rect().grow(1).encloses(card),"guide card stays fully inside the viewport: "+page)
		if page.begins_with("_notebook_"):
			check(guide._notebook().is_open and guide._notebook()._page==page.trim_prefix("_notebook_"),"tour shows real notebook page: "+page)
		elif not page.begins_with("_"):
			check(guide.panel.is_open(),"tour shows real management page: "+page)
		guide.next()
	check(guide._mode=="" and not guide.panel.is_open() and not WorldClock.paused,"guide restores the world and closes its menus")
	guide._notebook().open("storage")
	region.progression.set_epoch(2,true)
	await frames(4)
	check(guide._mode=="" and guide._state()["pending"].has(2),"epoch introduction waits until the notebook is closed")
	guide._notebook().close()
	# The guide checks pending introductions in _process, not physics.
	# Heavy UI layouts may run several catch-up physics ticks in one frame.
	await get_tree().process_frame
	await get_tree().process_frame
	await frames(4)
	check(guide._mode=="epoch" and guide._epoch==2,"unlock presents a concise epoch introduction: %s / %d, %s" % [guide._mode,guide._epoch,str(guide._state())])
	guide.start_tour(2)
	guide.next()
	guide.next()
	await frames(3)
	check(guide.panel._selected_train=="nostalgic_regional" and guide.panel.get_page()=="fleet","epoch guide shows the newly unlocked model")
	var snapshot := region.progression.save_state()
	check(int(snapshot["guide"]["active_index"])==2,"guide stage is saved with the journey")
	guide.stop(true,false)
	region.progression.load_state(snapshot)
	guide._resume()
	await frames(8)
	check(guide._mode=="tour" and guide._index==2 and guide.panel._selected_train=="nostalgic_regional","saved guide resumes at the real vehicle page")
	guide.stop(true)
	check(int(guide._state()["epoch_seen"])==2 and guide._state()["pending"].is_empty(),"dismissed unlock introduction does not repeat")
	var legacy := RegionProgression.new()
	legacy.load_state({"epoch":4})
	check(int(legacy.guide_state["epoch_seen"])==4 and legacy.guide_state["pending"].is_empty(),"old saves do not replay previously reached epochs")
	legacy.free()
