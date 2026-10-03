## Sichtbares Gleisstück: Modelle und begehbare Kollision für ein [RailSegment].
class_name RailSegmentView
extends StaticBody3D

var segment_id := -1

var _curve: Curve3D
var _meshes: Array[MeshInstance3D] = []
var _materials: Array[Material] = []
var _overlay: MeshInstance3D


func build(segment: RailSegment, ballast_material: Material, rail_material: Material) -> void:
	segment_id = segment.id
	_curve = segment.curve
	name = "Segment%d" % segment.id
	collision_layer = GameDefs.LAYER_RAILS
	collision_mask = 0

	# Tunnelgleise sind nur am Mundloch sichtbar; dahinter liegt der Berg.
	var curve := segment.curve if not segment.tunnel else _tunnel_mouth(segment.curve)
	var parts := RailMeshes.create_track(curve, segment.id)
	_add_mesh(parts["ballast"], ballast_material)
	_add_mesh(parts["rails"], rail_material)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(parts["collision"])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


## Die ersten Meter eines Tunnelgleises (vom Mundloch aus).
static func _tunnel_mouth(curve: Curve3D, visible_length := 18.0) -> Curve3D:
	var length := curve.get_baked_length()
	if length <= visible_length:
		return curve
	var part := Curve3D.new()
	var steps := 8
	for i in steps + 1:
		part.add_point(curve.sample_baked(visible_length * i / steps, true))
	return part


## Überlagert das Gleis mit einem Hervorhebungs-Material (null = normal).
func set_highlight(material: Material) -> void:
	for i in _meshes.size():
		_meshes[i].material_override = material if material else _materials[i]


## Farbige Einblendung für Belegung/Reservierung (null = aus).
func set_overlay(material: Material) -> void:
	if material == null:
		if _overlay:
			_overlay.visible = false
		return
	if _overlay == null:
		_overlay = MeshInstance3D.new()
		_overlay.mesh = RailMeshes.create_ghost(_curve)
		_overlay.position.y = 0.04
		_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_overlay)
	_overlay.material_override = material
	_overlay.visible = true


func get_overlay_material() -> Material:
	return _overlay.material_override if _overlay and _overlay.visible else null


func _add_mesh(mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	_meshes.append(instance)
	_materials.append(material)
