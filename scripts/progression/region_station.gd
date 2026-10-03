class_name RegionStation
extends Node3D

var station_id := 0
var station_name := "Wintervale"
var level := 1
var population := 0
var passenger_total := 0
var services := 0
var delivered_goods := 0
var house_ids: Array[int] = []
## Fertige Häuser, deren Familie noch in Nordtal auf den nächsten Zug wartet.
var waiting_houses: Array[int] = []
var platform_tracks: Array[Dictionary] = []
var public_space := {}
var region: RegionRailway
var stop: PlatformStop
var director: NpcDirector
var _visual: Node3D
var _light: OmniLight3D
var _platform_lights: Array[OmniLight3D] = []
var _glow: StandardMaterial3D
var _growth_mark := 0
var _pad_ids: Array[int] = []
var _access_graph: WalkGraph
var _access_level := 0

func configure(data: Dictionary, owner_region: RegionRailway) -> void:
	region = owner_region
	station_id = int(data["id"])
	station_name = String(data.get("name","Wintervale"))
	level = clampi(int(data.get("level",1)),1,6)
	population = maxi(0,int(data.get("population",0)))
	passenger_total = maxi(0,int(data.get("passengers",0)))
	services = maxi(0,int(data.get("services",0)))
	delivered_goods = maxi(0,int(data.get("goods",0)))
	_growth_mark = maxi(0,int(data.get("growth_mark",0)))
	public_space = data.get("public_space",{}).duplicate()
	house_ids.assign(data.get("houses",[]))
	waiting_houses.assign(data.get("waiting",[]))
	for track: Variant in data.get("platforms",[]):
		if track is Dictionary:
			platform_tracks.append(track)
	position = SaveUtils.array_to_vec3(data.get("pos"))
	rotation.y = float(data.get("angle",0))
	name = "Station_%d" % station_id

func _ready() -> void:
	add_to_group(PropScatter.GROUP_CLEARING)
	stop = PlatformStop.new()
	stop.station_name = station_name
	stop.platform_direction = global_basis.x
	add_child(stop)
	rebuild()
	_create_passenger_director()
	WorldClock.darkness_changed.connect(set_dark)
	set_dark(WorldClock.is_dark())

func rebuild() -> void:
	_update_ground()
	_platform_lights.clear()
	if _visual:
		remove_child(_visual)
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var parts := EpochStationMeshes.build(level)
	var mesh := MeshInstance3D.new()
	mesh.mesh = parts["paint"]
	mesh.material_override = region.village.material
	_visual.add_child(mesh)
	if level>=2:
		var access := StationAccess.describe(level)
		var beginning := float(access["back"])+StationAccess.RISERS*StationAccess.TREAD
		var paving := MeshInstance3D.new()
		paving.name = "ForecourtPaving"
		paving.mesh = PathMeshes.paved_rect(20.5-beginning,3.2)
		paving.position = Vector3((beginning+20.5)*0.5,0.029,float(access["z"]))
		paving.material_override = PathMeshes.material("path_stone")
		paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(paving)
	mesh.visibility_range_end = 210
	mesh.visibility_range_end_margin = 20
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.set_meta("station_id",station_id)
	_visual.add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = LowPolyBuilder.solid_collision(mesh.mesh)
	body.add_child(collider)
	_glow = StandardMaterial3D.new()
	_glow.vertex_color_use_as_albedo = true
	_glow.roughness = 0.55
	_glow.emission_enabled = true
	_glow.emission = Color(1,0.69,0.34)
	var glass := MeshInstance3D.new()
	glass.mesh = parts["glow"]
	glass.material_override = _glow
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(glass)
	if parts.get("glass"):
		var glazing := MeshInstance3D.new()
		glazing.mesh = parts["glass"]
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.25
		material.metallic = 0.12
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.85,0.97,1.0,0.63)
		glazing.material_override = material
		glazing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(glazing)
	# Ortsname auf beiden Seiten der Schildtafel (vorher steckte er in der Tafel).
	var sign_at: Vector3 = parts["sign_at"]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
	for side: float in [-1.0,1.0]:
		var label := Label3D.new()
		label.text = station_name
		label.font = font
		label.font_size = 64 if station_name.length() <= 11 else 46
		label.pixel_size = 0.0042
		label.outline_size = 0
		label.modulate = Color(0.96,0.92,0.8)
		label.double_sided = false
		label.position = sign_at+Vector3(side*float(parts["sign_face"]),float(parts["sign_y"]),0)
		label.rotation.y = side*PI/2
		_visual.add_child(label)
	_light = OmniLight3D.new()
	_light.position = Vector3(parts["center_x"],3.0,0)
	_light.light_color = Color(1,0.75,0.46)
	_light.omni_range = 9
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 65
	_light.distance_fade_length = 20
	_visual.add_child(_light)
	for lamp_point: Vector3 in parts["lamps"]:
		var lamp := OmniLight3D.new()
		lamp.position = lamp_point+Vector3(-0.2,0,0)
		lamp.light_color = Color(1,0.78,0.50)
		lamp.omni_range = 8
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 50
		lamp.distance_fade_length = 15
		_visual.add_child(lamp)
		_platform_lights.append(lamp)
	for i in platform_tracks.size():
		_add_extra_platform(platform_tracks[i],i+2)
	_update_access_graph()
	if director and _access_level!=level:
		var old_descriptors := access_descriptors(_access_level)
		for npc in director.get_npcs()+director.get_travellers():
			if not npc._moving or npc._path.is_empty() or not npc._climb.is_empty():
				continue
			for point in npc._path:
				var touches_platform := false
				for data in old_descriptors:
					touches_platform = touches_platform or StationAccess.platform_local((data["frame"] as Transform3D).affine_inverse()*point,data)
				if touches_platform:
					npc.walk_to(npc._path[-1],npc._on_arrive,npc._pace)
					break
	_access_level = level
	if director:
		director.max_travellers = 4+level*2
	set_dark(WorldClock.is_dark())
	if region and region.village and director:
		region.village.rebuild_walk_network.call_deferred()

func _add_extra_platform(data: Dictionary, number: int) -> void:
	var axis := SaveUtils.array_to_vec3(data.get("pos"))
	var angle := float(data.get("angle",0))
	var platform := RailwayPlatform.new()
	platform.length = float(EpochCatalog.epoch(level)["length"])
	platform.width = float(EpochCatalog.epoch(level)["width"])
	platform.height = TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y
	platform.canopy_length = platform.length*0.45
	platform.station_name = station_name
	platform.track_side = -1.0
	platform.material = region.village.material
	_visual.add_child(platform)
	platform.global_transform = Transform3D(Basis(Vector3.UP,angle),axis)
	platform.global_position += platform.global_basis.x*(1.78+platform.width/2)
	var stairs := MeshInstance3D.new()
	stairs.mesh = EpochStationMeshes.access_mesh(level)
	stairs.material_override = region.village.material
	_visual.add_child(stairs)
	stairs.global_transform = Transform3D(Basis(Vector3.UP,angle),axis)
	var stair_body := StaticBody3D.new()
	stair_body.collision_layer = GameDefs.LAYER_OBJECTS
	stairs.add_child(stair_body)
	var stair_shape := CollisionShape3D.new()
	stair_shape.shape = LowPolyBuilder.solid_collision(stairs.mesh)
	stair_body.add_child(stair_shape)
	var extra_stop: PlatformStop
	for candidate in get_stops():
		if candidate.platform_number==number:
			extra_stop = candidate
	if extra_stop==null:
		extra_stop = PlatformStop.new()
		extra_stop.station_name = station_name
		extra_stop.platform_number = number
		add_child(extra_stop)
	extra_stop.global_position = axis
	extra_stop.platform_direction = Basis(Vector3.UP,angle).x
	for z: float in [-3,0,3]:
		var spot_name := "PlatformSpot_%d_%d" % [number,int(z)]
		var spot := get_node_or_null(spot_name) as StationSpot
		if spot==null:
			spot = StationSpot.new()
			spot.name = spot_name
			spot.station_name = station_name
			spot.kind = StationSpot.Kind.STAND
			add_child(spot)
			if director:
				director._spots.append(spot)
		spot.global_position = axis+Basis(Vector3.UP,angle)*Vector3(2.5,TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y,z)
		spot.rotation.y = angle-rotation.y-PI/2

func _create_passenger_director() -> void:
	var graph := WalkGraph.new()
	_access_graph = graph
	_update_access_graph()
	add_child(graph)
	for z: float in [-6,-3,0,3,6]:
		var spot := StationSpot.new()
		spot.station_name = station_name
		spot.kind = StationSpot.Kind.STAND
		spot.position = Vector3(2.5,TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y,z)
		spot.rotation.y = -PI/2
		add_child(spot)
	director = NpcDirector.new()
	director.station_name = station_name
	director.auto_load_profiles = false
	director.dispatcher = region.dispatcher
	director.walk_graph = graph
	director.terrain = region.terrain
	director.access_route = walk_route
	director.access_height = walk_height
	director.player = region.get_parent().get_node("Player") as PlayerController
	director.max_travellers = 4+level*2
	director.travellers_per_train = Vector2i(0,0)
	add_child(director)
	director.passenger_alighted.connect(region.passenger_arrived)

func access_descriptors(at_level := 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var description_level := at_level if at_level>0 else level
	var main := StationAccess.describe(description_level)
	main["frame"] = global_transform
	main["outside_x"] = 20.8
	result.append(main)
	for track in platform_tracks:
		var extra := StationAccess.describe(description_level)
		extra["frame"] = Transform3D(Basis(Vector3.UP,float(track["angle"])),SaveUtils.array_to_vec3(track["pos"]))
		extra["outside_x"] = float(extra["back"])+4.2
		result.append(extra)
	return result

func path_entrances() -> PackedVector3Array:
	var result := PackedVector3Array()
	for data in access_descriptors():
		result.append((data["frame"] as Transform3D)*Vector3(float(data["back"])+StationAccess.RISERS*StationAccess.TREAD+0.3,0,float(data["z"])))
	return result

func permits_path(point: Vector3) -> bool:
	var p := to_local(point)
	var data := StationAccess.describe(level)
	return p.x>=float(data["back"])+StationAccess.RISERS*StationAccess.TREAD-0.15 and absf(p.z-float(data["z"]))<=2.4

func walk_height(point: Vector3) -> float:
	for data in access_descriptors():
		var frame: Transform3D = data["frame"]
		var height := StationAccess.ground_local(frame.affine_inverse()*point,data)
		if not is_nan(height):
			return frame.origin.y+height
	return NAN

func walk_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var descriptors := access_descriptors()
	var source := -1
	var target := -1
	for i in descriptors.size():
		var frame: Transform3D = descriptors[i]["frame"]
		if StationAccess.platform_local(frame.affine_inverse()*from,descriptors[i]):
			source = i
		if StationAccess.platform_local(frame.affine_inverse()*to,descriptors[i]):
			target = i
	var result := PackedVector3Array([from])
	var start := from
	if source>=0:
		var data := descriptors[source]
		var frame: Transform3D = data["frame"]
		var destination := to if source==target else frame*Vector3(float(data["outside_x"]),0,float(data["z"]))
		for point in StationAccess.local_path(frame.affine_inverse()*start,frame.affine_inverse()*destination,data):
			result.append(frame*point)
		start = destination
	if target<0 and source>=0 and _access_graph:
		for point in _access_graph.find_path(start,to):
			if point.distance_to(result[-1])>0.05:
				result.append(point)
		return result
	if target>=0 and target!=source:
		var data := descriptors[target]
		var frame: Transform3D = data["frame"]
		var outside := frame*Vector3(float(data["outside_x"]),0,float(data["z"]))
		if _access_graph:
			for point in _access_graph.find_path(start,outside):
				if point.distance_to(result[-1])>0.05:
					result.append(point)
			start = outside
		for point in StationAccess.local_path(frame.affine_inverse()*start,frame.affine_inverse()*to,data):
			result.append(frame*point)
	elif source<0 and target<0:
		var path := _access_graph.find_path(from,to) if _access_graph else PackedVector3Array([from,to])
		var crosses_platform := false
		for point in path:
			crosses_platform = crosses_platform or StationAccess.platform_local(to_local(point),descriptors[0])
		if crosses_platform:
			result.append(to_global(Vector3(maxf(to_local(from).x,20.8),0,to_local(from).z)))
			result.append(to_global(Vector3(maxf(to_local(to).x,20.8),0,to_local(to).z)))
		else:
			return path
	result.append(to)
	return result

## Each station shares village paths, but keeps its own safe stair entrances.
func set_village_routes(points: PackedVector3Array, edges: Array) -> void:
	if _access_graph==null:
		return
	var local_edges: Array = []
	for edge: Array in edges:
		if edge[0] is int and edge[1] is int:
			local_edges.append(edge)
	var outside := _access_graph.get_point("Dorfausgang")
	var nearest := -1
	var distance := 30.0
	for i in points.size():
		var d := RailGeometry.flat(points[i]-outside).length()
		if d<distance and region.village.is_walkable(outside,points[i]):
			distance = d
			nearest = i
	if nearest>=0:
		local_edges.append([nearest,"Dorfausgang",WalkGraph.COST_CONNECTOR])
	_access_graph.set_dynamic(points,local_edges)

func _update_access_graph() -> void:
	if _access_graph==null:
		return
	var data := StationAccess.describe(level)
	var z := float(data["z"])
	var points := {"Dorfausgang":Vector3(20.8,0,z),"TreppenFuss":Vector3(float(data["back"])+2.9,0,z),"TreppenKopf":Vector3(float(data["back"])-0.25,float(data["height"]),z),"BahnsteigZugang":Vector3(2.65,float(data["height"]),z),"BahnsteigMitte":Vector3(2.65,float(data["height"]),0)}
	for key: String in points:
		var marker := _access_graph.get_node_or_null(key) as Marker3D
		if marker==null:
			marker = Marker3D.new()
			marker.name = key
			_access_graph.add_child(marker)
		marker.position = points[key]
	_access_graph.links = PackedStringArray(["Dorfausgang-TreppenFuss","TreppenFuss-TreppenKopf","TreppenKopf-BahnsteigZugang","BahnsteigZugang-BahnsteigMitte"])
	if _access_graph.is_inside_tree():
		_access_graph.rebuild()
	if director:
		director._platform_points.assign([to_global(points["BahnsteigMitte"]),to_global(points["BahnsteigZugang"])])
		director._walk_distance = 20.8-2.65+absf(z)

func _update_ground() -> void:
	if region==null or region.terrain==null or is_portal():
		return
	for id in _pad_ids:
		region.terrain.remove_station_pad(id)
	_pad_ids.clear()
	var length := float(EpochCatalog.epoch(level)["length"])
	var area := VillageFootprint.make(to_global(Vector3(11.0,0,0)),Vector2(9.5,length/2+2),global_rotation.y)
	_set_pad(0,area,global_position.y-TerrainDeformer.GROUND_OFFSET)
	if level>=3:
		_set_pad(1,VillageFootprint.make(to_global(Vector3(10.5,0,length*0.57)),Vector2(6,9),global_rotation.y),global_position.y-TerrainDeformer.GROUND_OFFSET)
	for i in platform_tracks.size():
		var track := platform_tracks[i]
		var frame := Transform3D(Basis(Vector3.UP,float(track["angle"])),SaveUtils.array_to_vec3(track["pos"]))
		var width := float(EpochCatalog.epoch(level)["width"])
		_set_pad(i+2,VillageFootprint.make(frame*Vector3(1.78+width/2+1.4,0,0),Vector2(width/2+1.5,length/2+2),float(track["angle"])),frame.origin.y-TerrainDeformer.GROUND_OFFSET)

func _set_pad(index: int, area: Dictionary, height: float) -> void:
	var id := station_id*16+index
	region.terrain.set_station_pad(id,area,height)
	_pad_ids.append(id)

func occupied_footprints(at_level := 0) -> Array[Dictionary]:
	var target := at_level if at_level>0 else level
	var length := float(EpochCatalog.epoch(target)["length"])
	var width := float(EpochCatalog.epoch(target)["width"])
	var result: Array[Dictionary] = [VillageFootprint.make(to_global(Vector3(11,0,0)),Vector2(9.5,length/2+2),global_rotation.y)]
	if target>=3:
		result.append(VillageFootprint.make(to_global(Vector3(10.5,0,length*0.57)),Vector2(6,9),global_rotation.y))
	for track in platform_tracks:
		var frame := Transform3D(Basis(Vector3.UP,float(track["angle"])),SaveUtils.array_to_vec3(track["pos"]))
		result.append(VillageFootprint.make(frame*Vector3(1.78+width/2+1.4,0,0),Vector2(width/2+1.5,length/2+2),float(track["angle"])))
	return result

func _exit_tree() -> void:
	if is_instance_valid(region) and is_instance_valid(region.terrain):
		for id in _pad_ids:
			region.terrain.remove_station_pad(id)

func set_dark(dark: bool) -> void:
	if _light:
		_light.light_energy = 1.5 if dark else 0.0
	if _glow:
		_glow.emission_energy_multiplier = 0.65 if dark else 0.04
	for lamp in _platform_lights:
		lamp.light_energy = 1.2 if dark else 0.0

func get_stops() -> Array[PlatformStop]:
	return region.dispatcher.get_platform_stops(station_name)

func rename_station(candidate: String) -> bool:
	candidate = candidate.strip_edges()
	if candidate=="" or (region.station_by_name(candidate)!=null and candidate!=station_name):
		return false
	for train in region.dispatcher.get_trains().duplicate():
		if train.entry.origin==station_name or train.entry.destination==station_name:
			region.dispatcher.retire(train,"")
	station_name = candidate
	for child in get_children():
		if child is PlatformStop or child is StationSpot:
			child.station_name = candidate
	director.station_name = candidate
	for profile in director.profiles:
		profile.came_from = candidate
	rebuild()
	region.refresh()
	return true

func upgrade_reason() -> String:
	if level >= 6:
		return "Der Hauptbahnhof ist vollständig ausgebaut"
	if region.progression.epoch <= level:
		return "Epoche %d wird benötigt" % (level+1)
	var data := EpochCatalog.epoch(level+1)
	var blocked := upgrade_space_reason()
	if blocked!="":
		return blocked
	if services < int(data["upgrade_services"]):
		return "Noch %d erfolgreiche Ankünfte" % (int(data["upgrade_services"])-services)
	return Economy.describe_missing({"money":int(data["cost"])})

func upgrade_space_reason() -> String:
	if level>=6:
		return ""
	var future := occupied_footprints(level+1)
	var current := occupied_footprints()
	for other in region.stations:
		if other==self:
			continue
		for footprint in future:
			for occupied in other.occupied_footprints():
				if VillageFootprint.overlaps(footprint,occupied,0.2):
					return "Für den Ausbau mehr Abstand zu %s einplanen" % other.station_name
	for obj in region.village.get_objects():
		if obj is VillagePath:
			var samples := PackedVector3Array()
			for leg in range(1,obj.route_points.size()):
				var a: Vector3 = obj.route_points[leg-1]
				var b: Vector3 = obj.route_points[leg]
				var steps := maxi(1,ceili(a.distance_to(b)/1.0))
				for i in steps+1:
					samples.append(a.lerp(b,float(i)/steps))
			for point in samples:
				for i in future.size():
					if level+1>=3 and i==1:
						continue # The walkable forecourt may cover an existing path.
					if not VillageFootprint.contains(future[i],Vector2(point.x,point.z),obj.get_width()*0.5):
						continue
					var already_reserved := false
					for old in current:
						already_reserved = already_reserved or VillageFootprint.contains(old,Vector2(point.x,point.z),obj.get_width()*0.5)
					if not already_reserved:
						return "Ausbau würde %s überbauen · Weg vorher verlegen" % VillageCatalog.get_label(obj.item_id)
			continue
		for footprint in future:
			if VillageFootprint.overlaps(footprint,obj.get_footprint(),0.15):
				return "Ausbau braucht Platz für %s · Objekt vorher versetzen" % VillageCatalog.get_label(obj.item_id)
	return ""

func resident_visual_limit() -> int:
	return [6,8,10,12,16,20][clampi(level-1,0,5)]

func upgrade(debug := false) -> bool:
	if debug and not OS.is_debug_build():
		return false
	if level >= 6 or (not debug and upgrade_reason() != ""):
		return false
	if not debug and not Economy.pay(int(EpochCatalog.epoch(level+1)["cost"]),"Ausbau: "+station_name,"build"):
		return false
	level += 1
	rebuild()
	region.village.refresh_station_residents(self)
	var build := region.get_parent().get_node_or_null("BuildMode") as BuildMode
	if build and build.context.feedback and not debug:
		build.context.feedback.confirm("station",global_position,PackedVector3Array(),EpochCatalog.epoch(level)["station"])
	region.refresh()
	Events.notification_requested.emit("%s · %s" % [station_name,EpochCatalog.epoch(level)["station"]])
	return true

## Tunnelanschlüsse (RegionPortal) überschreiben das.
func is_portal() -> bool:
	return false


## Platform, buildings or an extra platform cover [param point] (used for picking).
func covers(point: Vector3) -> bool:
	var p := to_local(Vector3(point.x,global_position.y,point.z))
	var length := float(EpochCatalog.epoch(level)["length"])
	if p.x > 1.5 and p.x < 20 and absf(p.z) < length/2+1.5:
		return true
	for track in platform_tracks:
		var axis := SaveUtils.array_to_vec3(track.get("pos"))
		var local := Basis(Vector3.UP,float(track.get("angle",0))).inverse()*(Vector3(point.x,axis.y,point.z)-axis)
		if local.x > 1.5 and local.x < 2.2+float(EpochCatalog.epoch(level)["width"]) and absf(local.z) < length/2+1.5:
			return true
	return false

## Red overlay while the remove tool hovers the station.
func set_highlight(material: Material) -> void:
	if _visual == null:
		return
	for node in _visual.find_children("*","GeometryInstance3D",true,false):
		(node as GeometryInstance3D).material_overlay = material

func clears(x: float, z: float) -> bool:
	# Includes parallel platforms and stairs, not only the main building.
	for footprint in occupied_footprints():
		if VillageFootprint.contains(footprint,Vector2(x,z),0.35):
			return true
	return false

func get_data() -> Dictionary:
	return {"id":station_id,"name":station_name,"level":level,"pos":SaveUtils.vec3_to_array(position),"angle":rotation.y,"population":population,"passengers":passenger_total,"services":services,"goods":delivered_goods,"houses":house_ids.duplicate(),"waiting":waiting_houses.duplicate(),"growth_mark":_growth_mark,"platforms":platform_tracks.duplicate(true),"public_space":public_space.duplicate()}
