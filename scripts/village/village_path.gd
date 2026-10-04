## Ein Wegstück (Kiesweg, Steinweg oder kleine Straße) zwischen zwei Knoten.
##
## Die Geometrie liegt in Weltkoordinaten und folgt dem Gelände (siehe
## [PathMeshes]). Knoten gleicher Lage teilen sich Wegstücke – dadurch entsteht
## das Wegenetz, auf dem die Bewohner bevorzugt laufen. Wege haben keine
## Kollision (man läuft einfach darüber), roden aber Bäume.
class_name VillagePath
extends Node3D

var object_id := 0
var item_id := "path_gravel"
var start_point := Vector3.ZERO
var end_point := Vector3.ZERO
var route_points := PackedVector3Array()
var terrain: LowPolyTerrain

var _mesh: MeshInstance3D
var _footprint := {}


func configure(data: Dictionary, p_terrain: LowPolyTerrain) -> void:
	object_id = int(data["id"])
	item_id = String(data["item"])
	start_point = SaveUtils.array_to_vec3(data.get("pos"), Vector3.ZERO)
	end_point = SaveUtils.array_to_vec3(data.get("end"), start_point + Vector3.RIGHT)
	route_points = PackedVector3Array([start_point])
	var saved: Variant = data.get("points",[])
	if saved is Array:
		for i in range(1,mini(saved.size()-1,64)):
			var point := SaveUtils.array_to_vec3(saved[i],Vector3.INF)
			if point.is_finite():
				route_points.append(point)
	route_points.append(end_point)
	terrain = p_terrain
	_footprint = VillageFootprint.for_item(item_id, start_point, 0.0, 0, end_point)
	if route_points.size()>2:
		var box := Rect2(Vector2(start_point.x,start_point.z),Vector2.ZERO)
		for point in route_points:
			box = box.expand(Vector2(point.x,point.z))
		box = box.grow(PathMeshes.get_width(item_id)*0.5)
		_footprint = VillageFootprint.make(Vector3(box.get_center().x,0,box.get_center().y),box.size*0.5,0)
	name = "%s_%d" % [item_id, object_id]


func _ready() -> void:
	add_to_group(PropScatter.GROUP_CLEARING)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	rebuild()
	if terrain:
		terrain.terrain_changed.connect(_on_terrain_changed)


## Neu an das Gelände anpassen (z.B. nachdem ein Haus den Boden geebnet hat).
func rebuild() -> void:
	var height := func(x: float, z: float) -> float: return terrain.get_surface_height(x, z) if terrain else 0.0
	_mesh.mesh = PathMeshes.build_route(item_id,render_points(),height)
	if _mesh.mesh.get_surface_count()>0:
		_mesh.set_surface_override_material(0,PathMeshes.material(item_id))
	var manager := get_parent()
	if manager and manager.has_method("queue_path_surfaces"):
		_mesh.hide()
		manager.queue_path_surfaces()


func render_points() -> PackedVector3Array:
	var manager := get_parent()
	# Übergänge zu breiterem Belag reichen nur kurz hinter dessen Rand.
	var points := route_points.duplicate()
	if manager and manager.has_method(&"wider_surface_depth"):
		for k in 2:
			var end := points[0] if k == 0 else points[-1]
			var other := points[1] if k == 0 else points[-2]
			if float(manager.call(&"wider_surface_depth", end, object_id, get_width())) > 0.0:
				var cut := _clip_to_edge(manager, other, end)
				if k == 0:
					points[0] = cut
				else:
					points[-1] = cut
	return points


## Punkt zwischen [param inside_from] (frei) und [param into] (auf dem breiteren Weg), an dem
## der Weg 0,25 m weit auf den breiteren Belag reicht (Halbierungssuche).
func _clip_to_edge(manager: Node, inside_from: Vector3, into: Vector3) -> Vector3:
	if float(manager.call(&"wider_surface_depth", inside_from, object_id, get_width())) > 0.0:
		return into
	var lo := 0.0
	var hi := 1.0
	for i in 16:
		var mid := (lo + hi) * 0.5
		if float(manager.call(&"wider_surface_depth", inside_from.lerp(into, mid), object_id, get_width())) > 0.25:
			hi = mid
		else:
			lo = mid
	return inside_from.lerp(into, hi)


func get_data() -> Dictionary:
	var data := {"id": object_id, "item": item_id, "pos": SaveUtils.vec3_to_array(start_point),
		"end": SaveUtils.vec3_to_array(end_point)}
	if route_points.size()>2:
		var saved: Array = []
		for point in route_points:
			saved.append(SaveUtils.vec3_to_array(point))
		data["points"] = saved
	return data


func get_footprint() -> Dictionary:
	return _footprint


func get_length() -> float:
	return PathMeshes.route_length(route_points)


func get_width() -> float:
	return PathMeshes.get_width(item_id)


func is_solid() -> bool:
	return false


## Abstand eines Punkts zur Wegmitte (Draufsicht).
func distance_to(point: Vector3) -> float:
	var closest := closest_point(point)
	return Vector2(point.x,point.z).distance_to(Vector2(closest.x,closest.z))


func closest_point(point: Vector3) -> Vector3:
	var p := Vector2(point.x,point.z)
	var best := start_point
	var distance := INF
	for i in range(1,route_points.size()):
		var a := route_points[i-1]
		var b := route_points[i]
		var candidate := Geometry2D.get_closest_point_to_segment(p,Vector2(a.x,a.z),Vector2(b.x,b.z))
		if candidate.distance_squared_to(p)<distance:
			distance = candidate.distance_squared_to(p)
			best = Vector3(candidate.x,point.y,candidate.y)
	return best


func crosses_footprint(fp: Dictionary, margin := 0.0) -> bool:
	for i in range(1,route_points.size()):
		if VillageFootprint.crosses_segment(fp,Vector2(route_points[i-1].x,route_points[i-1].z),Vector2(route_points[i].x,route_points[i].z),margin):
			return true
	return false


func clears(x: float, z: float) -> bool:
	return distance_to(Vector3(x, 0, z)) < get_width() * 0.5 + 0.8


func set_dark(_dark: bool) -> void:
	pass


func set_highlight(highlight: Material) -> void:
	if _mesh:
		_mesh.material_overlay = highlight
		_mesh.position.y = 0.006 if highlight else 0.0
		_mesh.visible = highlight!=null


func _on_terrain_changed(region: Rect2) -> void:
	var center: Vector2 = _footprint["center"]
	var half: Vector2 = _footprint["half"]
	var box := Rect2(center-half,half*2).grow(2.0) if route_points.size()>2 else Rect2(Vector2(start_point.x,start_point.z),Vector2.ZERO).expand(Vector2(end_point.x,end_point.z)).grow(2.0)
	if box.intersects(region):
		rebuild()
