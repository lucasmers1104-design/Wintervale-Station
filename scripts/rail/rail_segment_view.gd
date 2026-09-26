## Sichtbares Gleisstück: Modelle und begehbare Kollision für ein [RailSegment].
class_name RailSegmentView
extends StaticBody3D

var segment_id := -1

var _meshes: Array[MeshInstance3D] = []
var _materials: Array[Material] = []


func build(segment: RailSegment, ballast_material: Material, rail_material: Material) -> void:
	segment_id = segment.id
	name = "Segment%d" % segment.id
	collision_layer = GameDefs.LAYER_RAILS
	collision_mask = 0

	var parts := RailMeshes.create_track(segment.curve, segment.id)
	_add_mesh(parts["ballast"], ballast_material)
	_add_mesh(parts["rails"], rail_material)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(parts["collision"])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


## Überlagert das Gleis mit einem Hervorhebungs-Material (null = normal).
func set_highlight(material: Material) -> void:
	for i in _meshes.size():
		_meshes[i].material_override = material if material else _materials[i]


func _add_mesh(mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	_meshes.append(instance)
	_materials.append(material)
