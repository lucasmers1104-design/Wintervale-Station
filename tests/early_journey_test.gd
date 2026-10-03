## First three epochs through paid construction and real scheduled trains.
## No injected passengers, population, completed projects or epoch unlocks.
extends Node
var checks := 0
var failures := 0
var main: Node3D
var region: RegionRailway

func check(ok: bool, label: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("PASS " if ok else "FAIL ",label)

func _ready() -> void:
	_run.call_deferred()

func build_home(station: RegionStation, item: String, local: Vector3, seed_value: int) -> bool:
	var point := station.to_global(local)
	var reason := region.village.check_placement(item,point,station.rotation.y)
	if reason!="":
		print("HOME BLOCKED ",reason)
		return false
	var data := region.village.prepare(item,point,station.rotation.y)
	data["seed"] = seed_value
	data["paid"] = true
	data["build"] = 0.0
	return region.village.build(data)!=null

func _run() -> void:
	# Run identical 1/60-second physics steps faster in wall time.
	Engine.physics_ticks_per_second = 360
	Engine.max_physics_steps_per_frame = 32
	Engine.time_scale = 6.0
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().physics_frame
	region = main.get("region")
	main.get_node("JourneyTutorial").set_process(false)
	main.get_node("JourneyGuide").set_process(false)
	WorldClock.paused = true
	WorldClock.set_time(8)
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.select_tool(&"rail")
	build.set_process(false)
	var rail := build.get_tool(&"rail") as RailPlaceTool
	var portal := region.portals[0]
	var stub := portal.get_stub_end()
	rail.click_at(stub,true)
	var track_ok := rail.click_at(stub+Vector3(0,0,50),true)
	track_ok = rail.click_at(stub+Vector3(0,0,100),true) and track_ok
	rail.cancel()
	check(track_ok,"normal tool builds 100 metres from Nordtal")
	var placement := region.placement(stub+Vector3(4,0,55))
	var station := region.build_station(placement,true)
	check(station!=null,"one halt built with starting money")
	if station==null:
		_finish()
		return
	check(build_home(station,"house_cottage",Vector3(28,0,-9),1),"first cottage paid and started")
	check(build_home(station,"house_cottage",Vector3(28,0,9),3),"second cottage paid and started")
	var line := region.add_line(portal.station_id,station.station_id,"diesel_heritage")
	check(not line.is_empty(),"first regular train assigned")
	WorldClock._set_time_scale_index(1)
	WorldClock.paused = false
	var added_farms := false
	var upgraded := false
	var minimum_cash := Economy.money
	var frames_run := 0
	for i in 24000:
		await get_tree().physics_frame
		frames_run = i+1
		minimum_cash = mini(minimum_cash,Economy.money)
		if region.progression.epoch>=2 and not added_farms:
			check(build_home(station,"house_farmhouse",Vector3(28,0,28),5),"epoch two farmhouse paid and started")
			check(build_home(station,"house_farmhouse",Vector3(43,0,28),7),"second farmhouse paid and started")
			added_farms = true
		if region.progression.epoch>=2 and not upgraded and station.upgrade_reason()=="":
			upgraded = station.upgrade()
		if i%3600==0:
			print("JOURNEY ",i," day ",WorldClock.day," hour ",WorldClock.time_of_day," epoch ",region.progression.epoch," metrics ",region.progression.metrics()," cash ",Economy.money)
		if region.progression.epoch>=3:
			break
	check(added_farms,"epoch two unlocks through ordinary play")
	check(upgraded,"halt upgrades with earned services and normal payment")
	check(region.progression.epoch>=3,"epoch three unlocks through ordinary play with one station")
	check(station.population>=12,"all four families arrive by scheduled train")
	check(region.stations.size()==1 and region.progression.metrics()["connected"]==1,"early village does not require a second station")
	check(minimum_cash>=0 and not region.progression.debug_used,"journey uses starting funds and earned fares without debug progress")
	print("EARLY JOURNEY frames=%d normal_minutes=%.1f metrics=%s funds=%d" % [frames_run,frames_run/60.0*10.0/60.0,region.progression.metrics(),Economy.money])
	_finish()

func _finish() -> void:
	print("EARLY JOURNEY RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
