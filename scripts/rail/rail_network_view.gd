## Stellt das [RailNetwork] dar: ein [RailSegmentView] pro Gleisstück und
## ein Prellbock an jedem offenen Gleisende.
##
## Hört nur auf die Signale des Netzes – Daten und Darstellung bleiben getrennt.
class_name RailNetworkView
extends Node3D

@export var network: RailNetwork
@export var ballast_material: Material
@export var rail_material: Material

var _views: Dictionary[int, RailSegmentView] = {}
var _buffer_stops: Node3D
var _buffer_mesh: ArrayMesh
var _buffer_shape: BoxShape3D


func _ready() -> void:
	_buffer_mesh = RailMeshes.create_buffer_stop()
	_buffer_shape = BoxShape3D.new()
	_buffer_shape.size = Vector3(2.6, 1.6, 1.0)
	_buffer_stops = Node3D.new()
	_buffer_stops.name = "BufferStops"
	add_child(_buffer_stops)

	network.segment_added.connect(_on_segment_added)
	network.segment_removed.connect(_on_segment_removed)
	network.topology_changed.connect(_rebuild_buffer_stops)
	for segment in network.get_segments():
		_on_segment_added(segment)
	_rebuild_buffer_stops()


func get_segment_view(segment_id: int) -> RailSegmentView:
	return _views.get(segment_id)


func get_buffer_stop_count() -> int:
	return _buffer_stops.get_child_count()


func _on_segment_added(segment: RailSegment) -> void:
	var view := RailSegmentView.new()
	add_child(view)
	view.build(segment, ballast_material, rail_material)
	_views[segment.id] = view


func _on_segment_removed(segment: RailSegment) -> void:
	var view: RailSegmentView = _views.get(segment.id)
	if view:
		_views.erase(segment.id)
		view.queue_free()


func _rebuild_buffer_stops() -> void:
	for child in _buffer_stops.get_children():
		_buffer_stops.remove_child(child)
		child.queue_free()

	for node in network.get_nodes():
		if not node.is_open():
			continue
		var outward := network.get_outward_direction(node.id)
		# Der Prellbock steht kurz vor dem Gleisende und schaut ins Gleis.
		var xform := Transform3D(Basis.looking_at(-outward, Vector3.UP), node.position - outward * 0.8)

		var body := StaticBody3D.new()
		body.collision_layer = GameDefs.LAYER_RAILS
		body.collision_mask = 0
		body.transform = xform
		var mesh := MeshInstance3D.new()
		mesh.mesh = _buffer_mesh
		mesh.material_override = ballast_material
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		collision.shape = _buffer_shape
		collision.position = Vector3(0.0, 0.8, 0.3)
		body.add_child(collision)
		_buffer_stops.add_child(body)
