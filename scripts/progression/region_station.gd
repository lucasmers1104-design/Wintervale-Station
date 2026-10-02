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
	mesh.visibility_range_end = 210
	mesh.visibility_range_end_margin = 20
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.set_meta("station_id",station_id)
	_visual.add_child(body)
	var collider := CollisionShape3D.new()
	collider.shape = mesh.mesh.create_trimesh_shape()
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
	var label := Label3D.new()
	label.text = station_name
	label.position = Vector3(parts["center_x"],float(parts["height"])+2.2,float(EpochCatalog.epoch(level)["length"])*0.36)
	label.rotation.y = PI/2
	label.font_size = 48
	label.pixel_size = 0.005
	label.outline_size = 0
	_visual.add_child(label)
	_light = OmniLight3D.new()
	_light.position = Vector3(parts["center_x"],3.0,0)
	_light.light_color = Color(1,0.75,0.46)
	_light.omni_range = 9
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 65
	_light.distance_fade_length = 20
	_visual.add_child(_light)
	for z: float in [-0.28,0.28]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(parts["center_x"],3.3,float(EpochCatalog.epoch(level)["length"])*z)
		lamp.light_color = Color(1,0.78,0.50)
		lamp.omni_range = 8
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 50
		lamp.distance_fade_length = 15
		_visual.add_child(lamp)
		_platform_lights.append(lamp)
	for i in platform_tracks.size():
		_add_extra_platform(platform_tracks[i],i+2)
	set_dark(WorldClock.is_dark())

func _add_extra_platform(data: Dictionary, number: int) -> void:
	var axis := SaveUtils.array_to_vec3(data.get("pos"))
	var angle := float(data.get("angle",0))
	var platform := RailwayPlatform.new()
	platform.length = float(EpochCatalog.epoch(level)["length"])
	platform.width = float(EpochCatalog.epoch(level)["width"])
	platform.height = TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y
	platform.canopy_length = platform.length*0.45
	platform.station_name = station_name
	platform.material = region.village.material
	_visual.add_child(platform)
	platform.global_transform = Transform3D(Basis(Vector3.UP,angle),axis)
	platform.global_position += platform.global_basis.x*(1.78+platform.width/2)
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
	var center := Marker3D.new()
	center.name = "BahnsteigMitte"
	center.position = Vector3(2.7,TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y,0)
	graph.add_child(center)
	var exit := Marker3D.new()
	exit.name = "Dorfausgang"
	exit.position = Vector3(5.5,0,10)
	graph.add_child(exit)
	graph.links = PackedStringArray(["Dorfausgang-BahnsteigMitte"])
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
	director.player = region.get_parent().get_node("Player") as PlayerController
	director.max_travellers = 6
	director.travellers_per_train = Vector2i(0,0)
	add_child(director)
	director.passenger_alighted.connect(region.passenger_arrived)

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
	var footprint := VillageFootprint.make(to_global(Vector3(10.7,0,0)),Vector2(9.3,float(data["length"])/2+1),rotation.y)
	for other in region.stations:
		if other==self:
			continue
		var occupied := VillageFootprint.make(other.to_global(Vector3(10.7,0,0)),Vector2(9.3,float(EpochCatalog.epoch(other.level)["length"])/2+1),other.rotation.y)
		if VillageFootprint.overlaps(footprint,occupied,0.2):
			return "Für den Ausbau mehr Abstand zu %s einplanen" % other.station_name
	if services < int(data["upgrade_services"]):
		return "Noch %d erfolgreiche Ankünfte" % (int(data["upgrade_services"])-services)
	return Economy.describe_missing({"money":int(data["cost"])})

func upgrade(debug := false) -> bool:
	if debug and not OS.is_debug_build():
		return false
	if level >= 6 or (not debug and upgrade_reason() != ""):
		return false
	if not debug and not Economy.pay(int(EpochCatalog.epoch(level+1)["cost"]),"Ausbau: "+station_name,"build"):
		return false
	level += 1
	rebuild()
	region.refresh()
	Events.notification_requested.emit("%s · %s" % [station_name,EpochCatalog.epoch(level)["station"]])
	return true

func clears(x: float, z: float) -> bool:
	var p := to_local(Vector3(x,global_position.y,z))
	var length := float(EpochCatalog.epoch(level)["length"])
	return (p.x > 1.4 and p.x < 20 and absf(p.z) < length/2+2) or (level>=3 and p.x>5 and p.x<16 and absf(p.z-length*0.57)<9)

func get_data() -> Dictionary:
	return {"id":station_id,"name":station_name,"level":level,"pos":SaveUtils.vec3_to_array(position),"angle":rotation.y,"population":population,"passengers":passenger_total,"services":services,"goods":delivered_goods,"houses":house_ids.duplicate(),"growth_mark":_growth_mark,"platforms":platform_tracks.duplicate(true),"public_space":public_space.duplicate()}
