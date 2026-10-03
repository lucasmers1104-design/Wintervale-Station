## Integration of long consists, parallel platforms, shared tracks, freight and restart.
extends Node
var failures := 0
var checks := 0
var main: Node3D
var region: RegionRailway

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
	await frames(10)
	Economy.money = 100000
	region.progression.set_epoch(6,true)
	for route in 4:
		var x: float = [-60,-15,30,-50][route]
		for part in 4:
			var a := Vector3(x,0,-120+part*60)
			var b := a+Vector3(0,0,60)
			region.network.restore_segment({"id":100+route*10+part+1,"kind":0,"start_node":100+route*10+part+1,"end_node":100+route*10+part+2,"points":[SaveUtils.vec3_to_array(a),SaveUtils.vec3_to_array(a.lerp(b,0.333333)),SaveUtils.vec3_to_array(a.lerp(b,0.666667)),SaveUtils.vec3_to_array(b)]})
	for pair in 3:
		for side in 2:
			region.build_station({"id":pair*2+side+1,"name":"Ort %d" % (pair*2+side+1),"level":[6,3,1][pair],"pos":[[-60,-15,30][pair],0,-65 if side==0 else 65],"angle":0},false)
	await frames(6)
	var a := region.stations[0]
	var b := region.stations[1]
	check(String(region.placement(Vector3(-57,0,-15)).get("reason","")).contains("Bahnhofsfläche"),"new halt respects footprint of longer existing station")
	region.stations[4].position.z = -35
	region.stations[5].position.z = -5
	check(region.stations[4].upgrade_reason().contains("Abstand"),"normal upgrade rejects overlapping neighboring platforms")
	region.stations[4].position.z = -65
	region.stations[5].position.z = 65
	check(region.plan_between(a,b,EpochCatalog.train("high_speed")).size()>0,"97 m high-speed consist fits real route and terminal margins")
	a.position.z = -55
	b.position.z = 55
	var extended := region.plan_between(a,b,EpochCatalog.train("high_speed"))
	check(not extended.is_empty() and extended["path"].segment_ids.size()==4,"terminal extensions beyond stop segments support longer consists")
	a.position.z = -65
	b.position.z = 65
	check(region.village.check_placement("house_cottage",a.to_global(Vector3(10,0,0)),0,0,Vector3.INF,true)!="","building placement preserves future station footprint")
	check(region.line_reason(5,6,"high_speed").contains("Stufe"),"long train gated by small halt stage")
	check(region.platform_placement(5,Vector3(30,0,-65)).get("reason","")!="","small halt cannot add platforms")
	check(region.add_platform(1,{"pos":[-50,0,-65],"angle":0},false),"parallel platform added")
	check(region.add_platform(2,{"pos":[-50,0,65],"angle":0},false),"parallel destination platform added")
	check(a.get_stops().size()==2,"two selectable platform stops")
	var stable_stop := a.get_stops()[1]
	a.rebuild()
	check(is_instance_valid(stable_stop) and a.get_stops().has(stable_stop),"architecture rebuild keeps operating platform references")
	check(a.rename_station("Wintervale Zentrum"),"station rename updates stop/director/spot identity")
	for stop in a.get_stops():
		check(stop.station_name==a.station_name,"renamed platform identity")
	var high := _line(1,2,"high_speed")
	var old := _line(1,2,"nostalgic_regional")
	var freight := _line(3,4,"reference_freight")
	var local := _line(5,6,"diesel_heritage")
	check(not high.is_empty() and not old.is_empty() and not freight.is_empty() and not local.is_empty(),"mixed fleet assignments accepted")
	check(region.dispatcher.get_trains().size()==4,"four independent services run concurrently")
	var high_train := region.train_for_line(int(high.get("id",-1)))
	var old_train := region.train_for_line(int(old.get("id",-1)))
	if high_train and old_train:
		check(high_train.platform_stop!=old_train.platform_stop,"busy main platform selects free parallel route")
	WorldClock.paused = false
	var unsafe := false
	var freight_hold := false
	var reversed := false
	for tick in 15000:
		await get_tree().physics_frame
		for train in region.dispatcher.get_trains():
			freight_hold = freight_hold or (train.train_type.category==TrainType.Category.FREIGHT and train.is_departure_held())
			for car in train.cars:
				unsafe = unsafe or (train.speed>0.02 and (car.get_step_amount()>0.001 or car.get_door_amount()>0.001))
		if is_instance_valid(high_train):
			reversed = reversed or high_train.cars[0].travel_reversed
		if int(freight.get("goods",0))>=24 and int(high.get("trips",0))>=2 and int(old.get("passengers",0))>0 and int(local.get("passengers",0))>0:
			break
	check(not unsafe,"all consist types keep closed doors and steps during movement")
	check(reversed,"long high-speed service turns around")
	check(freight_hold,"freight arrival waits for actual cargo transfer")
	check(int(freight.get("goods",0))>=24,"ordered cargo delivered into economy and line statistics")
	check(region.progression.goods==int(freight.get("goods",0)),"cargo milestone counts deliveries once")
	check(int(Achievements.progress.get("freight_master",0))==region.progression.goods,"regional cargo contributes once to existing freight achievement")
	check(int(high.get("passengers",0))>0 and int(old.get("passengers",0))>0 and int(local.get("passengers",0))>0,"old and modern passenger services complete NPC exchange")
	check(region.stations[3].delivered_goods>0,"freight supports destination growth")
	if is_instance_valid(high_train):
		check(high_train.cars[0]._headlight!=null and high_train.cars[0]._headlight.visible,"leading end has headlamp after reversal")
	# A second service on the same single track must get a turn.
	region.progression.unlocked.append("special_winter") if not region.progression.unlocked.has("special_winter") else null
	region.stations[4].level = 2
	region.stations[5].level = 2
	var shared := _line(5,6,"special_winter")
	check(not shared.is_empty(),"shared-track special service stays in roster")
	for tick in 10000:
		await get_tree().physics_frame
		if int(shared.get("trips",0))>0:
			break
	check(int(shared.get("trips",0))>0,"waiting service on shared track receives a turn")
	WorldClock.paused = true
	var goods_before := region.progression.goods
	check(SaveManager.save_game("regional_restart"),"save simultaneous regional operations")
	check(region._deliveries.is_empty(),"save closes in-flight cargo transactions")
	var saved := region.save_state()
	remove_child(main)
	main.queue_free()
	await frames(2)
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	region = main.get("region")
	await frames(8)
	check(SaveManager.load_game("regional_restart"),"restart and restore region")
	check(region.stations.size()==6 and region.lines.size()==5,"six settlements and mixed line roster survive restart")
	check(region.stations[0].get_stops().size()==2,"parallel platforms survive restart")
	check(region.progression.goods>=goods_before,"paid deliveries survive restart")
	check(region.stations[0].station_name=="Wintervale Zentrum","renamed station survives restart")
	check(region.lines[0]["passengers"]==saved["lines"][0]["passengers"],"completed transport counters restored without duplication")
	# Requirements progress in sequence from measurable metrics, not a timer.
	region.progression.epoch = 1
	region.progression.passengers = 19
	region.progression.goods = 120
	region.progression.services = 50
	for station in region.stations:
		station.population = 16 # deterministic census fixture for milestone boundary tests
	region.progression.refresh()
	check(region.progression.epoch==1,"one missing passenger keeps epoch two locked")
	for milestone in [[20,2],[60,3],[100,4],[220,5],[450,6]]:
		region.progression.passengers = milestone[0]
		region.progression.refresh()
		check(region.progression.epoch==milestone[1],"milestone boundary unlocks epoch %d" % milestone[1])
	check(region.progression.is_train_unlocked("diesel_heritage") and region.progression.is_train_unlocked("high_speed"),"all earlier vehicles persist at final epoch")
	SaveManager.delete_save("regional_restart")
	print("REGIONAL OPERATIONS RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)


## Linie zwischen eigenen Orten, deren Zug schon durch den Tunnel angereist ist
## (so steht sie nach dem Laden im Spielstand). Die Prüfregeln von add_line
## gelten weiter; nur die Anreise aus dem Tunnel entfällt im Testaufbau.
func _line(a_id: int, b_id: int, train_id: String) -> Dictionary:
	var reason := region.line_reason(a_id,b_id,train_id)
	if reason != "" and not reason.contains("Tunnel"):
		return {}
	var line := {"id":region._next_line,"a":a_id,"b":b_id,"train":train_id,"enabled":true,"trips":0,"passengers":0,"goods":0,"cooldown":0.0,"delivered":true}
	region._next_line += 1
	region.lines.append(line)
	region._try_dispatch(line)
	region.refresh()
	return line
