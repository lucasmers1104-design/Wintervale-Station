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
	var height := func(x: float, z: float) -> float: return terrain.get_height(x, z) if terrain else 0.0
	_mesh.mesh = PathMeshes.build(item_id, start_point, end_point, height)
	# Oberfläche 0: Wege-Shader (Kies, Pflaster, Straße), Oberfläche 1: Randsteine und Schneewall
	if _mesh.mesh.get_surface_count() > 0:
		_mesh.set_surface_override_material(0, PathMeshes.material(item_id))
	if _mesh.mesh.get_surface_count() > 1:
		_mesh.set_surface_override_material(1, preload("res://assets/materials/nature_vertex_color.tres"))


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
