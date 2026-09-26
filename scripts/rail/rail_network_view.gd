## Stellt das [RailNetwork] dar: Gleisstücke, Prellböcke an offenen Enden,
## Weichen (mit Stellanimation) und Signale (mit Signalbild aus dem Stellwerk).
##
## Optional blendet die Ansicht Belegung (rot) und reservierte Fahrwege (grün)
## ein – für die Testsimulation im Build-Mode.
##
## Hört nur auf Signale von Netz und Stellwerk – Daten und Darstellung bleiben getrennt.
class_name RailNetworkView
extends Node3D

## Absenkung abzweigender Weichenäste (Meter), siehe _update_layers().
const DIVERGING_DROP := 0.012

@export var network: RailNetwork
@export var interlocking: RailInterlocking
@export var ballast_material: Material
@export var rail_material: Material
@export var occupied_material: Material
@export var reserved_material: Material

var _views: Dictionary[int, RailSegmentView] = {}
var _switch_views: Dictionary[int, RailSwitchView] = {}
var _signal_views: Dictionary[int, RailSignalView] = {}
var _buffer_stops: Node3D
var _switches: Node3D
var _signals: Node3D
var _buffer_mesh: ArrayMesh
var _buffer_shape: BoxShape3D
var _overlays_visible := false


func _ready() -> void:
	_buffer_mesh = RailMeshes.create_buffer_stop()
	_buffer_shape = BoxShape3D.new()
	_buffer_shape.size = Vector3(2.6, 1.6, 1.0)
	_buffer_stops = _make_group("BufferStops")
	_switches = _make_group("Switches")
	_signals = _make_group("Signals")

	network.segment_added.connect(_on_segment_added)
	network.segment_removed.connect(_on_segment_removed)
	network.topology_changed.connect(_on_topology_changed)
	network.switch_changed.connect(_on_switch_changed)
	if interlocking:
		interlocking.state_changed.connect(_refresh_states)
	for segment in network.get_segments():
		_on_segment_added(segment)
	_on_topology_changed()


func get_segment_view(segment_id: int) -> RailSegmentView:
	return _views.get(segment_id)


func get_switch_view(node_id: int) -> RailSwitchView:
	return _switch_views.get(node_id)


func get_signal_view(signal_id: int) -> RailSignalView:
	return _signal_views.get(signal_id)


func get_buffer_stop_count() -> int:
	return _buffer_stops.get_child_count()


## Belegung und Fahrwege farbig einblenden (Testsimulation).
func set_overlays_visible(value: bool) -> void:
	_overlays_visible = value
	_refresh_states()


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


func _on_topology_changed() -> void:
	_rebuild_buffer_stops()
	_rebuild_switches()
	_rebuild_signals()
	_update_layers()
	_refresh_states()


## An Weichen liegen gerader und abzweigender Strang anfangs übereinander.
## Der Abzweig wird minimal abgesenkt, damit nichts flimmert (Z-Fighting).
func _update_layers() -> void:
	var diverging := {}
	for switch in network.get_switches():
		diverging[switch.branch_segment_ids[1]] = true
	for id: int in _views:
		_views[id].position.y = -DIVERGING_DROP if diverging.has(id) else 0.0


func _on_switch_changed(node_id: int) -> void:
	var view := get_switch_view(node_id)
	var switch := network.get_switch(node_id)
	if view and switch:
		view.set_state(switch.state, true)


## Signalbilder und Einblendungen an den Zustand des Stellwerks anpassen.
func _refresh_states() -> void:
	for rail_signal in network.get_signals():
		var view := get_signal_view(rail_signal.id)
		if view:
			view.set_aspect(rail_signal.aspect)
	var occupied := {}
	var reserved := {}
	if _overlays_visible and interlocking:
		for id in interlocking.get_occupied_segments():
			occupied[id] = true
		for id in interlocking.get_reserved_segments():
			reserved[id] = true
	for id: int in _views:
		var material: Material = null
		if occupied.has(id):
			material = occupied_material
		elif reserved.has(id):
			material = reserved_material
		_views[id].set_overlay(material)


func _rebuild_buffer_stops() -> void:
	_clear(_buffer_stops)
	for node in network.get_nodes():
		if not node.is_open():
			continue
		var outward := network.get_outward_direction(node.id)
		# Der Prellbock steht kurz vor dem Gleisende und schaut ins Gleis.
		var body := StaticBody3D.new()
		body.collision_layer = GameDefs.LAYER_RAILS
		body.collision_mask = 0
		body.transform = Transform3D(Basis.looking_at(-outward, Vector3.UP), node.position - outward * 0.8)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _buffer_mesh
		mesh.material_override = ballast_material
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		collision.shape = _buffer_shape
		collision.position = Vector3(0.0, 0.8, 0.3)
		body.add_child(collision)
		_buffer_stops.add_child(body)


func _rebuild_switches() -> void:
	_clear(_switches)
	_switch_views.clear()
	for switch in network.get_switches():
		var view := RailSwitchView.new()
		_switches.add_child(view)
		view.build(switch, network, ballast_material)
		_switch_views[switch.node_id] = view


func _rebuild_signals() -> void:
	_clear(_signals)
	_signal_views.clear()
	for rail_signal in network.get_signals():
		var view := RailSignalView.new()
		_signals.add_child(view)
		view.build(rail_signal, network.get_signal_transform(rail_signal), ballast_material)
		_signal_views[rail_signal.id] = view


func _make_group(group_name: String) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	return group


func _clear(group: Node3D) -> void:
	for child in group.get_children():
		group.remove_child(child)
		child.queue_free()
