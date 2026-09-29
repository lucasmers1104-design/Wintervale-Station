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
var terrain: LowPolyTerrain

var _mesh: MeshInstance3D
var _footprint := {}


func configure(data: Dictionary, p_terrain: LowPolyTerrain) -> void:
	object_id = int(data["id"])
	item_id = String(data["item"])
	start_point = SaveUtils.array_to_vec3(data.get("pos"), Vector3.ZERO)
	end_point = SaveUtils.array_to_vec3(data.get("end"), start_point + Vector3.RIGHT)
	terrain = p_terrain
	_footprint = VillageFootprint.for_item(item_id, start_point, 0.0, 0, end_point)
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
	# Schneewälle nicht auf anderen Wegen oder dem Dorfplatz (Kreuzungen bleiben frei)
	var manager := get_parent()
	var blocked := Callable()
	if manager and manager.has_method(&"is_on_other_path"):
		blocked = func(p: Vector3) -> bool: return bool(manager.call(&"is_on_other_path", p, object_id))
	# Endet der Weg auf einem breiteren Weg (Hauszugang an der Straße) oder dem Dorfplatz,
	# hört er kurz hinter dessen Rand ohne eigene Knotenscheibe auf – sonst schaut seine
	# Scheibe mit Schnee-Bankett als heller Fleck durch die Straße.
	var a := start_point
	var b := end_point
	var caps := [true, true]
	if manager and manager.has_method(&"wider_surface_depth"):
		for k in 2:
			var end := a if k == 0 else b
			var other := b if k == 0 else a
			if float(manager.call(&"wider_surface_depth", end, object_id, get_width())) > 0.0:
				var cut := _clip_to_edge(manager, other, end)
				if k == 0:
					a = cut
				else:
					b = cut
				caps[k] = false
	_mesh.mesh = PathMeshes.build(item_id, a, b, height, caps, blocked)
	# Oberfläche 0: Wege-Shader (Kies, Pflaster, Straße), Oberfläche 1: Randsteine und Schneewall
	if _mesh.mesh.get_surface_count() > 0:
		_mesh.set_surface_override_material(0, PathMeshes.material(item_id))
	if _mesh.mesh.get_surface_count() > 1:
		_mesh.set_surface_override_material(1, preload("res://assets/materials/nature_vertex_color.tres"))


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
	return {"id": object_id, "item": item_id, "pos": SaveUtils.vec3_to_array(start_point),
		"end": SaveUtils.vec3_to_array(end_point)}


func get_footprint() -> Dictionary:
	return _footprint


func get_length() -> float:
	return Vector2(start_point.x, start_point.z).distance_to(Vector2(end_point.x, end_point.z))


func get_width() -> float:
	return PathMeshes.get_width(item_id)


func is_solid() -> bool:
	return false


## Abstand eines Punkts zur Wegmitte (Draufsicht).
func distance_to(point: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var a := Vector2(start_point.x, start_point.z)
	var b := Vector2(end_point.x, end_point.z)
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func clears(x: float, z: float) -> bool:
	return distance_to(Vector3(x, 0, z)) < get_width() * 0.5 + 0.8


func set_dark(_dark: bool) -> void:
	pass


func set_highlight(highlight: Material) -> void:
	if _mesh:
		_mesh.material_overlay = highlight


func _on_terrain_changed(region: Rect2) -> void:
	var box := Rect2(Vector2(start_point.x, start_point.z), Vector2.ZERO).expand(Vector2(end_point.x, end_point.z)).grow(2.0)
	if box.intersects(region):
		rebuild()
