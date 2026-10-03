## Stations and player-assigned services extend TrainDispatcher, never a second simulator.
class_name RegionRailway
extends Node3D

signal changed
signal freight_delivered(number: String, delivered: Dictionary)
const SAVE_ID := "region_railway"
var network: RailNetwork
var dispatcher: TrainDispatcher
var terrain: LowPolyTerrain
var village: VillageManager
var progression: RegionProgression
var stations: Array[RegionStation] = []
var lines: Array[Dictionary] = []
var _next_station := 1
var _next_line := 1
var _timer := 0.0
var _loading := false
var _growth_timer := 0.0
var _deliveries: Array[Dictionary] = []
var _validity_cache := {}
## Tunnel in den Bergen: Nordtal ab Start, Südtal öffnet sich mit Epoche 3.
const PORTALS := [
	{"id":1001,"name":"Nordtal","mouth":Vector3(3.8,0,-78),"yaw":0.0,"epoch":1},
	{"id":1002,"name":"Südtal","mouth":Vector3(3.8,0,78),"yaw":PI,"epoch":3},
]
## Pause zwischen zwei Zügen derselben Tunnel-Linie (Spielsekunden).
const PORTAL_HEADWAY := 24.0
var portals: Array[RegionPortal] = []

func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	network.topology_changed.connect(func() -> void:
		_validity_cache.clear()
		refresh())
	Events.game_loaded.connect(_after_load)
	# Nach der laufenden Fortschrittsprüfung öffnen (keine verschachtelte Neuzählung).
	progression.epoch_unlocked.connect(func(_level: int) -> void: open_portals.call_deferred(true))
	open_portals.call_deferred(false)

## Öffnet alle Tunnel, die zur aktuellen Epoche gehören, samt Anschlussgleis.
func open_portals(announce: bool, with_track := true) -> void:
	for definition: Dictionary in PORTALS:
		if int(definition["epoch"]) > progression.epoch:
			continue
		var portal := station_by_id(int(definition["id"])) as RegionPortal
		if portal == null:
			portal = RegionPortal.new()
			portal.configure_portal(int(definition["id"]),String(definition["name"]),definition["mouth"],float(definition["yaw"]),self)
			portals.append(portal)
			add_child(portal)
			if announce:
				Events.event_banner_requested.emit("Ein neuer Tunnel: %s" % portal.station_name,"Schließe dein Netz an – von dort kommen weitere Gäste und Familien","train")
		if with_track:
			portal.ensure_track()
	_validity_cache.clear()
	if with_track:
		refresh()

func _portal_epoch(id: int) -> int:
	for definition: Dictionary in PORTALS:
		if int(definition["id"]) == id:
			return int(definition["epoch"])
	return 1

## Eigene Gleislänge, die mit dem Tunnel [param portal] verbunden ist (Meter).
func connected_length(portal: RegionPortal) -> float:
	var start := network.find_node_near(portal.get_mouth(),2.0)
	if start == null:
		return 0.0
	var seen_nodes := {start.id: true}
	var seen_segments := {}
	var open: Array[int] = [start.id]
	var total := 0.0
	while not open.is_empty():
		var node := network.get_rail_node(open.pop_back())
		for id in node.segment_ids:
			if seen_segments.has(id):
				continue
			seen_segments[id] = true
			var segment := network.get_segment(id)
			if segment == null or segment.tunnel:
				continue
			if not portal.track_ids.has(id):
				total += segment.length
			for next in [segment.start_node_id,segment.end_node_id]:
				if not seen_nodes.has(next):
					seen_nodes[next] = true
					open.append(next)
	return total

func is_portal_track(segment_id: int) -> bool:
	for portal in portals:
		if portal.track_ids.has(segment_id):
			return true
	return false

func refresh() -> void:
	if _loading or progression.loading:
		return
	for station in stations:
		station.population = 0
		station.waiting_houses.assign(station.waiting_houses.filter(func(id: int) -> bool: return village.get_object(id) != null))
		for id in station.house_ids:
			var house := village.get_object(id) as VillageHouse
			# Einwohner zählen erst, wenn die Familie mit dem Zug angekommen ist.
			if house and house.is_finished() and not station.waiting_houses.has(id):
				station.population += VillageManager.household_size(house)
	progression.refresh()
	changed.emit()
	if village.nature:
		village.nature.refresh_clearings.call_deferred()

func station_by_id(id: int) -> RegionStation:
	for station in stations:
		if station.station_id == id:
			return station
	for portal in portals:
		if portal.station_id == id:
			return portal
	return null

func station_by_name(label: String) -> RegionStation:
	for station in stations:
		if station.station_name == label:
			return station
	for portal in portals:
		if portal.station_name == label:
			return portal
	return null

## Nächstgelegener Haltepunkt (für neue Häuser); null = es gibt noch keinen.
func nearest_station(point: Vector3) -> RegionStation:
	var best: RegionStation = null
	var best_distance := INF
	for station in stations:
		var distance := RailGeometry.flat(point-station.global_position).length()
		if distance < best_distance:
			best_distance = distance
			best = station
	return best

## Station whose platform or buildings lie under [param point] (null = none).
func station_at(point: Vector3) -> RegionStation:
	for station in stations:
		if station.covers(point):
			return station
	return null

## Player demolition with the remove tool. The halt's price is refunded; lines
## serving it end. The returned data restores everything via [method restore_station].
func demolish_station(id: int) -> Dictionary:
	var station := station_by_id(id)
	if station == null:
		return {}
	var served: Array = []
	for line in lines:
		if int(line["a"]) == id or int(line["b"]) == id:
			served.append(line.duplicate(true))
	var label := station.station_name
	var data := remove_station(id)
	data["lines"] = served
	Economy.earn(int(EpochCatalog.epoch(1)["cost"]),"Abriss: "+label,"refund")
	Events.notification_requested.emit("%s abgerissen · %s zurück" % [label,Economy.format_money(int(EpochCatalog.epoch(1)["cost"]))])
	return data

## Undo of [method demolish_station]: the refund is taken back, lines return.
func restore_station(data: Dictionary) -> void:
	if station_by_id(int(data["id"])):
		return
	Economy.pay(int(EpochCatalog.epoch(1)["cost"]),"Wiederaufbau: "+String(data.get("name","")),"build")
	build_station(data,false)
	for row: Variant in data.get("lines",[]):
		var line: Dictionary = (row as Dictionary).duplicate(true)
		if station_by_id(int(line["a"])) and station_by_id(int(line["b"])):
			line["cooldown"] = 0.0
			lines.append(line)
	_validity_cache.clear()
	refresh()

func placement(point: Vector3) -> Dictionary:
	var rail := network.find_segment_near(point,8.0)
	if rail == null or rail.tunnel:
		return {"reason":"Haltepunkt neben einem gebauten Gleis platzieren"}
	var offset := rail.closest_offset(point)
	var axis := rail.curve.sample_baked(offset,true)
	var tangent := RailGeometry.flat(RailGeometry.tangent_at(rail.curve,offset)).normalized()
	var angle := atan2(tangent.x,tangent.z)
	var basis := Basis(Vector3.UP,angle)
	if basis.x.dot(point-axis) < 0:
		angle += PI
	var data := {"id":_next_station,"name":"Wintervale" if stations.is_empty() else ["Tannenau","Birkenhain","Sonnenfeld","Bergblick","Seetal","Eichenruh"][(stations.size()-1)%7]+(" %d" % _next_station if stations.size()>7 else ""),"pos":SaveUtils.vec3_to_array(axis),"angle":angle,"level":1,"reason":""}
	var footprint := VillageFootprint.make(axis+Basis(Vector3.UP,angle).x*10.7,Vector2(9.3,float(EpochCatalog.epoch(1)["length"])/2+1),angle)
	for station in stations:
		if RailGeometry.flat(axis-station.global_position).length() < 32:
			data["reason"] = "Mindestens 32 m Abstand zum nächsten Ort"
		var occupied := VillageFootprint.make(station.to_global(Vector3(10.7,0,0)),Vector2(9.3,float(EpochCatalog.epoch(station.level)["length"])/2+1),station.rotation.y)
		if VillageFootprint.overlaps(footprint,occupied,0.2):
			data["reason"] = "Die Bahnhofsfläche von %s freihalten" % station.station_name
	for portal in portals:
		if RailGeometry.flat(axis-portal.get_mouth()).length() < 30:
			data["reason"] = "Etwas mehr Abstand zum Tunnel lassen"
	if data["reason"] != "":
		return data
	var right := Basis(Vector3.UP,angle).x
	for z: float in [-9,0,9]:
		for x: float in [2,4,6]:
			var sample := axis+right*x+tangent*z
			if terrain.is_in_lake(sample.x,sample.z):
				data["reason"] = "Am See ist kein Platz für den Haltepunkt"
			if absf(terrain.get_height(sample.x,sample.z)-axis.y)>1.2:
				data["reason"] = "Für einen Haltepunkt wird flacheres Gelände benötigt"
			if village.pick(sample):
				data["reason"] = "Hier steht bereits ein Gebäude oder Weg"
	if data["reason"] == "" and not Economy.can_afford({"money":int(EpochCatalog.epoch(1)["cost"])}):
		data["reason"] = Economy.describe_missing({"money":int(EpochCatalog.epoch(1)["cost"])})
	return data

func build_station(data: Dictionary, paid := true) -> RegionStation:
	if paid:
		var current := placement(SaveUtils.array_to_vec3(data.get("pos"))+Basis(Vector3.UP,float(data.get("angle",0))).x*3)
		if current.get("reason","") != "":
			return null
		if not Economy.pay(int(EpochCatalog.epoch(1)["cost"]),"Holz-Haltepunkt: "+String(data["name"]),"build"):
			return null
	var station := RegionStation.new()
	station.configure(data,self)
	_next_station = maxi(_next_station,station.station_id+1)
	stations.append(station)
	add_child(station)
	_validity_cache.clear()
	refresh()
	return station

func remove_station(id: int, refund := false) -> Dictionary:
	var station := station_by_id(id)
	if station == null:
		return {}
	settle_deliveries()
	for line in lines.duplicate():
		if int(line["a"]) == id or int(line["b"]) == id:
			remove_line(int(line["id"]))
	var data := station.get_data()
	stations.erase(station)
	remove_child(station)
	station.queue_free()
	if refund:
		Economy.earn(int(EpochCatalog.epoch(1)["cost"]),"Rückgängig: Haltepunkt","refund")
	refresh()
	return data

func plan_between(a: RegionStation, b: RegionStation, type: TrainType = null) -> Dictionary:
	if a == null or b == null or a == b:
		return {}
	var best := {}
	for origin_stop in a.get_stops():
		for destination_stop in b.get_stops():
			var start := origin_stop.get_segment(network)
			var goal := destination_stop.get_segment(network)
			if start==null or goal==null:
				continue
			for forward: bool in [true,false]:
				var plan := RailPathfinder.find(network,start.id,forward,goal.id)
				if plan.is_empty():
					continue
				var ids: Array[int] = []
				ids.assign(plan["ids"])
				var directions: Array[bool] = []
				directions.assign(plan["forwards"])
				var path := TrainPath.new(network,ids,directions)
				var from := path.distance_near(origin_stop.global_position,start.id)
				var to := path.distance_near(destination_stop.global_position,goal.id)
				var length := EpochCatalog.consist_length(type) if type else 16.0
				# Include tracks beyond the two stop segments. Extending an existing
				# terminal must create room for a longer train without moving its halt.
				for attempt in 16:
					if from>=length/2+0.5:
						break
					var first := network.get_segment(ids[0])
					var node := first.start_node_id if directions[0] else first.end_node_id
					var previous := _margin_neighbor(first,node,ids)
					if previous==null:
						break
					ids.push_front(previous.id)
					directions.push_front(previous.end_node_id==node)
					from += previous.length
					to += previous.length
					path = TrainPath.new(network,ids,directions)
				for attempt in 16:
					if path.total_length-to>=length/2+0.5:
						break
					var last := network.get_segment(ids[-1])
					var node := last.end_node_id if directions[-1] else last.start_node_id
					var next := _margin_neighbor(last,node,ids)
					if next==null:
						break
					ids.append(next.id)
					directions.append(next.start_node_id==node)
					path = TrainPath.new(network,ids,directions)
				if to-from<length+8 or from<length/2+0.5 or to+length/2>path.total_length-0.5:
					continue
				var score := path.total_length
				for id in ids:
					if dispatcher.interlocking.get_train_on_segment(id)>=0:
						score += 10000
				if best.is_empty() or score<float(best["score"]):
					best = {"path":path,"from":from,"to":to,"stop":destination_stop,"origin_stop":origin_stop,"score":score}
	return best

## Fahrweg vom tiefen Tunnelende zu einem Bahnsteig von [param station].
## Rückgabe {"path", "to", "stop"} oder {} (keine Verbindung / zu wenig Platz).
func plan_from_portal(portal: RegionPortal, station: RegionStation, type: TrainType = null) -> Dictionary:
	if portal == null or station == null or station.is_portal():
		return {}
	var start := portal.get_end_segment()
	if start == null:
		return {}
	# Das tiefe Ende ist das Segmentende; aus dem Berg heraus fährt man rückwärts.
	var outward := start.start_node_id == portal.get_end_node_id()
	var length := EpochCatalog.consist_length(type) if type else 16.0
	var best := {}
	for stop in station.get_stops():
		var goal := stop.get_segment(network)
		if goal == null:
			continue
		var plan := RailPathfinder.find(network,start.id,outward,goal.id)
		if plan.is_empty():
			continue
		var ids: Array[int] = []
		ids.assign(plan["ids"])
		var directions: Array[bool] = []
		directions.assign(plan["forwards"])
		var path := TrainPath.new(network,ids,directions)
		var to := path.distance_near(stop.global_position,goal.id)
		# Hinter dem Bahnsteig muss die zweite Zughälfte Platz haben.
		for attempt in 16:
			if path.total_length-to >= length/2+0.5:
				break
			var last := network.get_segment(ids[-1])
			var node := last.end_node_id if directions[-1] else last.start_node_id
			var next := _margin_neighbor(last,node,ids)
			if next == null:
				break
			ids.append(next.id)
			directions.append(next.start_node_id == node)
			path = TrainPath.new(network,ids,directions)
		if to+length/2 > path.total_length-0.5 or to < length+4:
			continue
		var score := path.total_length
		for id in ids:
			if dispatcher.interlocking.get_train_on_segment(id) >= 0:
				score += 10000
		if best.is_empty() or score < float(best["score"]):
			best = {"path":path,"to":to,"stop":stop,"score":score}
	return best

## Erster Tunnel, aus dem ein Zug [param station] erreichen kann (null = keiner).
func portal_for(station: RegionStation, type: TrainType = null) -> RegionPortal:
	for portal in portals:
		if not plan_from_portal(portal,station,type).is_empty():
			return portal
	return null

func _margin_neighbor(segment: RailSegment, node: int, excluded: Array[int]) -> RailSegment:
	var selected: RailSegment
	var score := -INF
	for id in network.get_next_segments(segment.id,node,false):
		if excluded.has(id):
			continue
		var candidate := network.get_segment(id)
		var alignment := -segment.get_direction_away_from(node).dot(candidate.get_direction_away_from(node))
		if alignment>score:
			score = alignment
			selected = candidate
	return selected

func platform_placement(id: int, point: Vector3) -> Dictionary:
	var station := station_by_id(id)
	if station==null:
		return {"reason":"Bahnhof nicht gefunden"}
	if station.get_stops().size()>=int(EpochCatalog.epoch(station.level)["platforms"]):
		return {"reason":"Zuerst den Bahnhof für weitere Bahnsteige ausbauen"}
	var rail := network.find_segment_near(point,6)
	if rail==null or rail.tunnel:
		return {"reason":"Ein weiteres Gleis neben dem Bahnhof wählen"}
	var axis := rail.closest_point(point)
	if axis.distance_to(station.global_position)>38:
		return {"reason":"Der Bahnsteig muss innerhalb von 38 m am Bahnhof liegen"}
	for stop in station.get_stops():
		if stop.global_position.distance_to(axis)<6:
			return {"reason":"Hier gibt es bereits einen Bahnsteig"}
	var tangent := RailGeometry.flat(RailGeometry.tangent_at(rail.curve,rail.closest_offset(point))).normalized()
	var angle := atan2(tangent.x,tangent.z)
	if Basis(Vector3.UP,angle).x.dot(point-axis)<0:
		angle += PI
	var dimensions := EpochCatalog.epoch(station.level)
	var width := float(dimensions["width"])
	var frame := Transform3D(Basis(Vector3.UP,angle),axis)
	var footprint := VillageFootprint.make(frame*Vector3(1.78+width/2+1.4,0,0),Vector2(width/2+1.5,float(dimensions["length"])/2+2),angle)
	for other in stations:
		for occupied in other.occupied_footprints():
			if VillageFootprint.overlaps(footprint,occupied,0.2):
				return {"pos":SaveUtils.vec3_to_array(axis),"angle":angle,"reason":"Bahnsteig überlappt %s · andere Gleisseite oder mehr Abstand wählen" % other.station_name}
	return {"pos":SaveUtils.vec3_to_array(axis),"angle":angle,"reason":Economy.describe_missing({"money":120})}

func add_platform(id: int, data: Dictionary, charge := true) -> bool:
	var station := station_by_id(id)
	if station==null or (charge and not Economy.pay(120,"Bahnsteig: "+station.station_name,"build")):
		return false
	station.platform_tracks.append(data.duplicate(true))
	station.rebuild()
	_validity_cache.clear()
	refresh()
	return true

func remove_platform(id: int) -> void:
	var station := station_by_id(id)
	if station and not station.platform_tracks.is_empty():
		var number := station.platform_tracks.size()+1
		for stop in station.get_stops():
			if stop.platform_number==number:
				for train in dispatcher.get_trains().duplicate():
					if train.platform_stop==stop or train.get_meta("local_origin_stop",null)==stop or train.get_meta("local_destination_stop",null)==stop:
						dispatcher.retire(train,"")
				station.remove_child(stop)
				stop.queue_free()
		station.platform_tracks.pop_back()
		_validity_cache.clear()
		for child in station.get_children():
			if child is StationSpot and String(child.name).begins_with("PlatformSpot_%d_" % number):
				station.director._spots.erase(child)
				station.remove_child(child)
				child.queue_free()
		station.rebuild()
		Economy.earn(120,"Rückgängig: Bahnsteig","refund")
		refresh()
		return

func line_reason(a_id: int, b_id: int, train_id: String) -> String:
	var a := station_by_id(a_id)
	var b := station_by_id(b_id)
	var type := EpochCatalog.train(train_id)
	if type == null or not progression.is_train_unlocked(train_id):
		return "Dieser Zug ist noch gesperrt"
	if a == null or b == null or a == b:
		return "Zwei unterschiedliche Orte auswählen"
	if a.is_portal() and b.is_portal():
		return "Zwischen zwei Tunneln hält kein Zug – wähle einen deiner Haltepunkte"
	if mini(a.level,b.level) < type.required_station_level:
		return "Der Haltepunkt braucht Stufe %d" % type.required_station_level
	if a.is_portal() or b.is_portal():
		var portal := (a if a.is_portal() else b) as RegionPortal
		var station := b if a.is_portal() else a
		if plan_from_portal(portal,station,type).is_empty():
			return "Gleis vom Tunnel %s bis %s verbinden – mit Platz für den ganzen Zug" % [portal.station_name,station.station_name]
	else:
		if plan_between(a,b,type).is_empty():
			return "Gleise verbinden und an beiden Enden Platz für den ganzen Zug lassen"
		if portal_for(a,type) == null:
			return "Der Zug reist durch den Tunnel an: %s mit dem Tunnel verbinden" % a.station_name
	for line in lines:
		if ((int(line["a"])==a_id and int(line["b"])==b_id) or (int(line["a"])==b_id and int(line["b"])==a_id)) and line["train"] == train_id:
			return "Dieser Zug bedient diese Verbindung bereits"
	return Economy.describe_missing({"money":type.purchase_price})

func add_line(a_id: int, b_id: int, train_id: String) -> Dictionary:
	var reason := line_reason(a_id,b_id,train_id)
	if reason != "":
		Events.notification_requested.emit(reason)
		return {}
	var type := EpochCatalog.train(train_id)
	if not Economy.pay(type.purchase_price,"Zug einsetzen: "+type.display_name,"build"):
		return {}
	var line := {"id":_next_line,"a":a_id,"b":b_id,"train":train_id,"enabled":true,"trips":0,"passengers":0,"goods":0,"cooldown":0.0,"delivered":false}
	_next_line += 1
	lines.append(line)
	_try_dispatch(line)
	refresh()
	return line

func remove_line(id: int) -> void:
	for train in dispatcher.get_trains().duplicate():
		if int(train.get_meta("region_line",-1)) == id:
			dispatcher.retire(train,"")
	for line in lines.duplicate():
		if int(line["id"])==id:
			lines.erase(line)
	refresh()

func line_is_valid(line: Dictionary) -> bool:
	var a := station_by_id(int(line["a"]))
	var b := station_by_id(int(line["b"]))
	var type := EpochCatalog.train(String(line["train"]))
	if not bool(line.get("enabled",true)) or type==null or a==null or b==null or mini(a.level,b.level)<type.required_station_level:
		return false
	var key := "%d:%d:%s:%d:%d" % [a.station_id,b.station_id,line["train"],a.level,b.level]
	if not _validity_cache.has(key):
		if a.is_portal() or b.is_portal():
			_validity_cache[key] = not plan_from_portal((a if a.is_portal() else b) as RegionPortal,b if a.is_portal() else a,type).is_empty()
		else:
			_validity_cache[key] = not plan_between(a,b,type).is_empty()
	return _validity_cache[key]

func train_for_line(id: int) -> Train:
	for train in dispatcher.get_trains():
		if int(train.get_meta("region_line",-1))==id:
			return train
	return null

func _process(delta: float) -> void:
	for delivery in _deliveries:
		var tween: Tween = delivery["tween"]
		if tween.is_valid():
			if WorldClock.paused:
				tween.pause()
			else:
				tween.play()
				tween.set_speed_scale(WorldClock.time_scale)
	if _loading or progression.loading or WorldClock.paused:
		return
	_timer -= delta
	if _timer <= 0:
		_timer = 0.5
		for line in lines:
			line["cooldown"] = maxf(0,float(line.get("cooldown",0))-0.5*WorldClock.time_scale)
			if bool(line.get("enabled",true)) and train_for_line(int(line["id"])) == null:
				_try_dispatch(line)
	# Die Stadt wächst nicht mehr von selbst: Häuser, Wege und Plätze baut der
	# Spieler; Familien kommen mit dem Zug (siehe deliver_families).

func _try_dispatch(line: Dictionary) -> void:
	if float(line.get("cooldown",0))>0 or not line_is_valid(line):
		return
	var a := station_by_id(int(line["a"]))
	var b := station_by_id(int(line["b"]))
	var type := EpochCatalog.train(String(line["train"]))
	if a.is_portal() or b.is_portal():
		_dispatch_from_portal(line,(a if a.is_portal() else b) as RegionPortal,b if a.is_portal() else a,type,false)
		return
	# Neue Linien zwischen eigenen Orten: der Zug reist zuerst durch den Tunnel an.
	if not bool(line.get("delivered",true)):
		var portal := portal_for(a,type)
		if portal:
			_dispatch_from_portal(line,portal,a,type,true)
			return
		line["delivered"] = true
	var plan := plan_between(a,b,type)
	var path: TrainPath = plan["path"]
	for id in path.segment_ids:
		if dispatcher.interlocking.get_train_on_segment(id)>=0 or dispatcher.interlocking.is_block_reserved(network.get_segment(id).block_id):
			return
	var entry := TimetableEntry.new()
	entry.train_number = "%s %03d" % [EpochCatalog.train(String(line["train"])).type_code,int(line["id"])]
	entry.train_name = "%s ↔ %s" % [a.station_name,b.station_name]
	entry.train_type = EpochCatalog.train(String(line["train"]))
	entry.origin = a.station_name
	entry.destination = b.station_name
	entry.station = a.station_name
	entry.departure = TimetableEntry.format_time(WorldClock.time_of_day)
	var train := dispatcher.spawn_region_train(entry,path)
	train.set_meta("region_line",int(line["id"]))
	train.set_meta("onboard",0)
	train.set_meta("manifest",[])
	train.set_meta("origin_dwell",true)
	train.set_meta("destination_distance",float(plan["to"]))
	train.set_meta("local_origin_stop",plan["origin_stop"])
	train.set_meta("local_destination_stop",plan["stop"])
	train.head = float(plan["from"])+train.length/2
	train.platform_stop = plan["origin_stop"]
	train.platform_number = train.platform_stop.platform_number
	train.set_despawn(INF)
	train._visual_head = train.head
	train.update_visuals(0)
	train.update_occupancy()
	train.arrived.connect(_on_arrived)
	train.departed.connect(_on_departed)
	train._arrive()
	if entry.train_type.category == TrainType.Category.PASSENGER:
		var rng := RandomNumberGenerator.new()
		rng.seed = train.train_id*997
		var count := mini(5,2+a.population/8)
		_board_visitors(train,a,b,train.platform_stop,count,rng)
		if not a.director.passenger_boarded.is_connected(_on_boarded):
			a.director.passenger_boarded.connect(_on_boarded)

## Ein Zug kommt aus dem Tunnel: mit Gästen (und wartenden Familien) zu
## [param station]. [param delivery]: Anreise für eine Linie zwischen eigenen
## Orten – am Ziel übernimmt die eigentliche Linie den Zug.
func _dispatch_from_portal(line: Dictionary, portal: RegionPortal, station: RegionStation, type: TrainType, delivery: bool) -> void:
	var plan := plan_from_portal(portal,station,type)
	if plan.is_empty():
		return
	var path: TrainPath = plan["path"]
	for id in path.segment_ids:
		if dispatcher.interlocking.get_train_on_segment(id)>=0 or dispatcher.interlocking.is_block_reserved(network.get_segment(id).block_id):
			return
	var entry := TimetableEntry.new()
	entry.train_number = "%s %03d" % [type.type_code,int(line["id"])]
	entry.train_name = "%s ↔ %s" % [portal.station_name,station.station_name]
	entry.train_type = type
	entry.origin = portal.station_name
	entry.destination = station.station_name
	entry.station = station.station_name
	entry.departure = TimetableEntry.format_time(WorldClock.time_of_day)
	var train := dispatcher.spawn_region_train(entry,path)
	train.set_meta("region_line",int(line["id"]))
	train.set_meta("origin_dwell",false)
	train.set_meta("local_origin_stop",portal.stop)
	train.set_meta("local_destination_stop",plan["stop"])
	var manifest: Array = []
	if delivery:
		train.set_meta("delivery_line",int(line["id"]))
	elif type.category == TrainType.Category.PASSENGER:
		# Gäste aus der Ferne: mehr, je lebendiger der Ort ist.
		var parties := clampi(2+station.population/6,2,6)
		var size := clampi(1+station.population/12,1,4)
		var seats := type.passenger_capacity
		for i in parties:
			var party := mini(size,seats)
			if party <= 0:
				break
			manifest.append(party)
			seats -= party
	var onboard := 0
	for party: int in manifest:
		onboard += party
	train.set_meta("manifest",manifest)
	train.set_meta("onboard",onboard)
	train.set_stop(float(plan["to"])+train.length/2,plan["stop"],(plan["stop"] as PlatformStop).platform_number)
	train.set_despawn(INF)
	train._visual_head = train.head
	train.update_visuals(0)
	train.update_occupancy()
	train.arrived.connect(_on_arrived)
	train.departed.connect(_on_departed)
	train.tree_exiting.connect(_on_train_gone.bind(train))

## Ein Zug ist im Tunnel verschwunden: Fahrgäste sind angekommen, nächster Zug folgt.
func _on_train_gone(train: Train) -> void:
	# Nur echte Ausfahrten in den Berg (nicht Laden, Abriss oder Spielende).
	if train.state != Train.State.DONE or not is_inside_tree() or not bool(train.get_meta("to_portal",false)) or train.head < train.despawn_at-1.5:
		return
	var portal := station_by_name(train.entry.destination)
	var delivered := 0
	for party: int in train.get_meta("manifest",[]):
		delivered += party
	progression.services += 1
	if portal:
		portal.services += 1
		portal.passenger_total += delivered
	progression.passengers += delivered
	if delivered > 0:
		Economy.earn(8*delivered,"Fahrkarten nach "+train.entry.destination,"tickets")
	for line in lines:
		if int(line["id"]) == int(train.get_meta("region_line",-1)):
			line["trips"] = int(line["trips"])+1
			line["passengers"] = int(line["passengers"])+delivered
			line["cooldown"] = PORTAL_HEADWAY
	refresh.call_deferred()

## Tunnel, aus dem eine aktive Linie [param station] bedient (null = keine).
func serving_portal(station: RegionStation) -> RegionPortal:
	for line in lines:
		if not bool(line.get("enabled",true)):
			continue
		var a := station_by_id(int(line["a"]))
		var b := station_by_id(int(line["b"]))
		if a == station and b and b.is_portal():
			return b as RegionPortal
		if b == station and a and a.is_portal():
			return a as RegionPortal
	return null

## Wartende Familien steigen aus dem Zug, der gerade aus dem Tunnel angekommen ist.
func deliver_families(station: RegionStation, train: Train) -> void:
	if station.waiting_houses.is_empty():
		return
	for id in station.waiting_houses.duplicate():
		var house := village.get_object(id) as VillageHouse
		station.waiting_houses.erase(id)
		if house:
			village.welcome_household(house,train.entry.origin)
	refresh()

func _board_visitors(train: Train, origin: RegionStation, destination: RegionStation, platform: PlatformStop, count: int, rng: RandomNumberGenerator) -> void:
	# Guests now use the actual entrance. Give the bounded queue time to reach it
	# instead of closing the doors halfway through a longer station approach.
	train.set_meta("boarding_grace",clampf(origin.director._walk_distance/1.1+18,Train.MAX_DOOR_HOLD,80))
	var available := maxi(0,origin.director.max_travellers-origin.director.regular_traveller_count())
	for i in mini(count,available):
		var visitor := origin.director.spawn_traveller(rng)
		var party := mini(8,mini(maxi(1,train.train_type.passenger_capacity/24),1+origin.population/6))
		visitor.set_meta("party_size",party)
		var start := origin.director.get_exit_point()
		if platform!=origin.stop:
			start = platform.global_position+platform.platform_direction*4+Vector3(0,0,6)
		visitor.begin_trip(destination.station_name,-1,start+Vector3(i*0.3,0,0))

func _on_boarded(npc: Npc, train: Train) -> void:
	if train.has_meta("region_line"):
		var onboard := int(train.get_meta("onboard",0))
		var party := mini(int(npc.get_meta("party_size",1)),maxi(0,train.train_type.passenger_capacity-onboard))
		if party>0:
			var manifest: Array = train.get_meta("manifest",[])
			manifest.append(party)
			train.set_meta("manifest",manifest)
			train.set_meta("onboard",onboard+party)

func _on_arrived(train: Train) -> void:
	if bool(train.get_meta("origin_dwell",false)):
		return
	if train.has_meta("delivery_line"):
		# Angereist: Die Linie zwischen den eigenen Orten übernimmt hier.
		var id := int(train.get_meta("delivery_line"))
		dispatcher.retire(train,"")
		for line in lines:
			if int(line["id"]) == id:
				line["delivered"] = true
				line["cooldown"] = 0.0
				_try_dispatch.call_deferred(line)
		return
	var station := station_by_name(train.entry.station)
	if station == null:
		return
	station.services += 1
	progression.services += 1
	for line in lines:
		if int(line["id"])==int(train.get_meta("region_line",-1)):
			line["trips"] = int(line["trips"])+1
	var origin := station_by_name(train.entry.origin)
	if origin and origin.is_portal():
		deliver_families(station,train)
	if train.train_type.category == TrainType.Category.PASSENGER:
		var rng := RandomNumberGenerator.new()
		rng.seed = train.train_id*331+station.services
		var manifest: Array = train.get_meta("manifest",[])
		for i in manifest.size():
			var visitor := station.director.spawn_traveller(rng)
			visitor.set_meta("party_size",int(manifest[i]))
			visitor.alight_from(train,true)
		train.set_meta("onboard",0)
		train.set_meta("manifest",[])
	else:
		_unload_freight(train,station)
	refresh()

func passenger_arrived(npc: Npc, train: Train) -> void:
	if not train.has_meta("region_line") or bool(train.get_meta("origin_dwell",false)):
		return
	var station := station_by_name(train.entry.station)
	if station == null:
		return
	var party := maxi(1,int(npc.get_meta("party_size",1)))
	station.passenger_total += party
	progression.passengers += party
	Economy.earn(8*party,"Fahrkarte: "+station.station_name,"tickets")
	for line in lines:
		if int(line["id"])==int(train.get_meta("region_line",-1)):
			line["passengers"] = int(line["passengers"])+party
	refresh()

func _on_departed(train: Train) -> void:
	if bool(train.get_meta("origin_dwell",false)):
		train.set_meta("origin_dwell",false)
		var station := station_by_name(train.entry.destination)
		train.entry.station = station.station_name
		train.departed_at = -1
		if station.is_portal():
			_head_into_tunnel(train)
			return
		var target_stop: PlatformStop = train.get_meta("local_destination_stop")
		train.set_stop(float(train.get_meta("destination_distance"))+train.length/2,target_stop,target_stop.platform_number)
		return
	# Shared single-track routes take turns after completing a service. Independent
	# tracks continue concurrently; the existing interlocking remains authoritative.
	# Tunnelzüge fahren ohnehin in den Berg zurück und machen so Platz.
	var from_portal := station_by_name(train.entry.origin) != null and station_by_name(train.entry.origin).is_portal()
	for waiting in lines:
		if from_portal:
			break
		if int(waiting["id"])==int(train.get_meta("region_line")) or train_for_line(int(waiting["id"]))!=null or not line_is_valid(waiting):
			continue
		var wa := station_by_id(int(waiting["a"]))
		var wb := station_by_id(int(waiting["b"]))
		var waiting_type := EpochCatalog.train(String(waiting["train"]))
		var candidate := plan_from_portal((wa if wa.is_portal() else wb) as RegionPortal,wb if wa.is_portal() else wa,waiting_type) if (wa.is_portal() or wb.is_portal()) else plan_between(wa,wb,waiting_type)
		if candidate.is_empty():
			continue
		var overlaps := false
		for id in candidate["path"].segment_ids:
			overlaps = overlaps or train.path.segment_ids.has(id)
		if overlaps:
			for own in lines:
				if int(own["id"])==int(train.get_meta("region_line")):
					own["cooldown"] = 25.0
			dispatcher.retire.call_deferred(train,"")
			return
	# Reverse the actual consist in place; doors and steps are already closed.
	var previous := station_by_name(train.entry.origin)
	var here := station_by_name(train.entry.destination)
	var previous_stop: PlatformStop = train.get_meta("local_origin_stop")
	var here_stop: PlatformStop = train.get_meta("local_destination_stop")
	train.set_meta("local_origin_stop",here_stop)
	train.set_meta("local_destination_stop",previous_stop)
	var ids := train.path.segment_ids.duplicate()
	ids.reverse()
	var forwards: Array[bool] = []
	for i in range(train.path.forwards.size()-1,-1,-1):
		forwards.append(not train.path.forwards[i])
	var old_head := train.head
	train.path = TrainPath.new(network,ids,forwards)
	train.head = train.path.total_length-old_head+train.length
	train.cars.reverse()
	var offset := 0.0
	for car in train.cars:
		car.travel_reversed = not car.travel_reversed
		car.offset_from_head = offset
		offset += car.length+TrainMeshes.COUPLING_GAP
	for i in train.cars.size():
		train.cars[i].set_service_ends(i==0,i==train.cars.size()-1)
	train._visual_head = train.head
	train.entry.origin = here.station_name
	train.entry.destination = previous.station_name
	train.entry.station = previous.station_name
	for car in train.cars:
		car.set_destination("%s  %s" % [train.entry.train_number,previous.station_name])
	train.set_stop(train.path.distance_near(previous_stop.global_position,previous_stop.get_segment(network).id)+train.length/2,previous_stop,previous_stop.platform_number)
	train._door_holds.clear()
	train._hold_time = 0
	train._cargo_holds.clear()
	train._cargo_hold_time = 0
	train.departed_at = -1
	train.arrived_at = -1
	train.granted.clear()
	train.interlocking.release_routes_of(train.train_id)
	train.path_changed()
	train.update_occupancy()
	train.update_visuals(0)
	# Travellers already waiting at this terminal board before it departs.
	if train.train_type.category == TrainType.Category.PASSENGER:
		train.set_meta("onboard",0)
		train.set_meta("manifest",[])
		# A short origin dwell makes both directions playable with the same mechanisms.
		train.set_meta("destination_distance",train.stop_at-train.length/2)
		train.set_meta("origin_dwell",true)
		train.entry.station = here.station_name
		train.platform_stop = here_stop
		train._arrive()
		var rng := RandomNumberGenerator.new()
		rng.seed = train.train_id*37+here.services*13
		_board_visitors(train,here,previous,here_stop,mini(5,2+here.population/8),rng)
		if not here.director.passenger_boarded.is_connected(_on_boarded):
			here.director.passenger_boarded.connect(_on_boarded)
	elif previous.is_portal():
		# Güterzüge fahren leer zurück in den Berg; der nächste kommt beladen.
		_head_into_tunnel(train)
	else:
		for car in train.cars:
			car.refill_region_cargo()


## Ohne Halt bis ans tiefe Tunnelende fahren und dort verschwinden.
func _head_into_tunnel(train: Train) -> void:
	train.stop_at = -1.0
	train.set_meta("to_portal",true)
	train.set_despawn(train.path.total_length-1.0)
	train.departed_at = -1

func _unload_freight(train: Train, station: RegionStation) -> void:
	for car in train.cars:
		for i in car.get_cargo().size():
			var cargo := car.get_cargo()[i]
			if cargo["state"] != "full":
				continue
			var goods_id := String(cargo["goods"])
			var quantity := int(cargo["amount"])*maxi(1,int(cargo.get("portions",0)))
			var amount := mini(quantity,Economy.get_space(goods_id))
			if amount <= 0 or not Economy.is_ordered(goods_id):
				continue
			if not Economy.pay(Economy.get_goods_type(goods_id).unit_price*amount,"Lieferung: "+Economy.get_label(goods_id),"purchase"):
				continue
			var piece := car.detach_cargo(i)
			if piece:
				var world := piece.transform
				station.add_child(piece)
				piece.global_transform = world
				piece.show()
				# Tank commodities leave through the pump, represented by compact
				# receiving crates rather than containers sitting on the tank body.
				if car.kind=="reference_tank":
					piece.scale *= 0.25
				var key := "region_delivery_%d_%d" % [car.get_instance_id(),i]
				train.hold_departure(key)
				var tween := piece.create_tween()
				var raised := piece.global_position+Vector3.UP*2.3
				var receiving := station.to_global(Vector3(10,1.2,float(EpochCatalog.epoch(station.level)["length"])*0.43+i*0.55))
				tween.tween_property(piece,"global_position",raised,0.75).set_trans(Tween.TRANS_SINE)
				tween.tween_property(piece,"global_position",Vector3(receiving.x,raised.y,receiving.z),1.6).set_trans(Tween.TRANS_SINE)
				tween.tween_property(piece,"global_position",receiving,0.75).set_trans(Tween.TRANS_SINE)
				var delivery := {"train":train,"station":station,"line":int(train.get_meta("region_line")),"goods":goods_id,"amount":amount,"piece":piece,"tween":tween,"key":key}
				_deliveries.append(delivery)
				tween.tween_callback(_complete_delivery.bind(delivery))
			else:
				Economy.earn(Economy.get_goods_type(goods_id).unit_price*amount,"Lieferung zurückgestellt","refund")

func _complete_delivery(delivery: Dictionary) -> void:
	if not _deliveries.has(delivery):
		return
	_deliveries.erase(delivery)
	var amount := int(delivery["amount"])
	Economy.add_stock(String(delivery["goods"]),amount)
	progression.goods += amount
	var station: RegionStation = delivery["station"]
	if is_instance_valid(station):
		station.delivered_goods += amount
		Economy.earn(amount*2,"Güterumschlag: "+station.station_name,"freight")
	for line in lines:
		if int(line["id"])==int(delivery["line"]):
			line["goods"] = int(line["goods"])+amount
	var train: Train = delivery["train"]
	freight_delivered.emit(train.entry.train_number if is_instance_valid(train) else "Güterzug",{String(delivery["goods"]):amount})
	if is_instance_valid(train):
		train.release_departure(String(delivery["key"]))
	if is_instance_valid(delivery["piece"]):
		delivery["piece"].queue_free()
	refresh()

## Save at a consistent transfer boundary, so purchased cargo is never lost.
func settle_deliveries() -> void:
	for delivery in _deliveries.duplicate():
		(delivery["tween"] as Tween).kill()
		_complete_delivery(delivery)

func cancel_deliveries() -> void:
	# A load rolls the economy and counters back together; old-world transfers
	# must not finish into the restored snapshot.
	for delivery in _deliveries:
		(delivery["tween"] as Tween).kill()
		if is_instance_valid(delivery["train"]):
			delivery["train"].release_departure(delivery["key"])
		if is_instance_valid(delivery["piece"]):
			delivery["piece"].queue_free()
	_deliveries.clear()

func _grow_public_space(station: RegionStation) -> void:
	if station.population<4:
		return
	var details: Array[Dictionary] = []
	if station.level>=3:
		details.append({"key":"plaza","item":"plaza","offset":Vector3(27,0,0)})
		for side: float in [-1,1]:
			details.append({"key":"lamp_%d" % int(side),"item":"street_lamp" if station.level>=4 else "lantern","offset":Vector3(24,0,side*12)})
	if station.level>=4:
		details.append({"key":"fountain","item":"fountain","offset":Vector3(23,0,20)})
	for detail in details:
		if station.public_space.has(detail["key"]):
			continue
		var point: Vector3 = station.to_global(detail["offset"])
		if village.check_placement(detail["item"],point,0,0,Vector3.INF,true)=="":
			var object: Node3D = village.place(village.prepare(detail["item"],point,0))
			station.public_space[detail["key"]] = object.object_id

func grow_station(station: RegionStation, debug := false) -> bool:
	if debug and not OS.is_debug_build():
		return false
	var data := EpochCatalog.epoch(progression.epoch)
	station.house_ids.assign(station.house_ids.filter(func(id: int) -> bool: return village.get_object(id) != null))
	var potential := mini(int(data["house_limit"]),1+station.passenger_total/4+station.delivered_goods/12)
	if not debug and (station.services<=0 or station.house_ids.size()>=potential):
		return false
	var available: Array = data["growth"]
	var index := station._growth_mark
	for attempt in 28:
		var item := String(available[(index+attempt)%available.size()])
		var slot := index+attempt
		var ring := 1+slot/8
		var theta := (slot%8-3.5)*0.30
		var offset := Vector3(22+ring*10*cos(theta),0,sin(theta)*ring*24)
		var point := station.to_global(offset)
		var angle := station.rotation.y+PI/2
		if village.check_placement(item,point,angle,0,Vector3.INF,true) != "":
			continue
		var object_data := village.prepare(item,point,angle,(index+attempt)%VillageCatalog.get_variant_count(item))
		object_data["build"] = 0.0
		object_data["organic"] = true
		object_data["region_station"] = station.station_id
		var house: VillageHouse = village.place(object_data)
		if not station.house_ids.has(house.object_id):
			station.house_ids.append(house.object_id)
		station._growth_mark = slot+1
		var road_start := station.to_global(Vector3(21.5,0,offset.z))
		var road_end := Vector3(point.x,point.y,point.z)+station.global_basis.x*(-5)
		var road := "path_road" if station.level>=4 else ("path_stone" if station.level>=3 else "path_gravel")
		if village.check_placement(road,road_start,0,0,road_end,true)=="":
			village.place(village.prepare(road,road_start,0,0,road_end))
		Events.notification_requested.emit("%s wächst · Ein neues Zuhause entsteht" % station.station_name)
		refresh()
		return true
	return false

func get_save_id() -> String:
	return SAVE_ID

func save_state() -> Dictionary:
	var station_data: Array = []
	for station in stations:
		station_data.append(station.get_data())
	var portal_data: Array = []
	for portal in portals:
		portal_data.append(portal.get_data())
	return {"stations":station_data,"portals":portal_data,"lines":lines.duplicate(true),"next_station":_next_station,"next_line":_next_line}

func load_state(data: Dictionary) -> void:
	_loading = true
	cancel_deliveries()
	dispatcher.clear_trains()
	for station in stations.duplicate():
		remove_station(station.station_id)
	lines.clear()
	for row: Variant in data.get("stations",[]):
		if row is Dictionary and row.has("id"):
			build_station(row,false)
	# Tunnel der geladenen Epoche gibt es sofort; ihre Gleise prüft _after_load,
	# weil das Gleisnetz erst nach den Orten geladen wird. Tunnel einer späteren
	# Epoche (früherer Spielstand in derselben Sitzung) verschwinden wieder.
	for portal in portals.duplicate():
		if _portal_epoch(portal.station_id) > progression.epoch:
			portals.erase(portal)
			remove_child(portal)
			portal.queue_free()
	open_portals(false,false)
	for row: Variant in data.get("portals",[]):
		var portal := station_by_id(int((row as Dictionary).get("id",0))) as RegionPortal if row is Dictionary else null
		if portal:
			portal.passenger_total = int(row.get("passengers",0))
			portal.services = int(row.get("services",0))
			portal.delivered_goods = int(row.get("goods",0))
	for row: Variant in data.get("lines",[]):
		if row is Dictionary and EpochCatalog.TRAIN_IDS.has(String(row.get("train",""))) and station_by_id(int(row.get("a",0))) and station_by_id(int(row.get("b",0))):
			lines.append(row.duplicate(true))
	_next_station = maxi(_next_station,int(data.get("next_station",1)))
	_next_line = maxi(1,int(data.get("next_line",1)))
	_loading = false

func _after_load(_slot: String) -> void:
	open_portals(false)
