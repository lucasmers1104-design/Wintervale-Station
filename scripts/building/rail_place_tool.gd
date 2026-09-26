## Werkzeug "Schiene": Gleise mit Vorschau (Ghost) bauen.
##
## Ablauf: 1. Klick setzt den Startpunkt (rastet an offenen Gleisenden ein),
## 2. Klick baut das Gleis bis zum Mauszeiger. Danach geht es vom neuen Ende
## aus direkt weiter (Kette). Rechtsklick oder Esc bricht die Kette ab.
## Grün = baubar, Rot = nicht baubar (Grund steht in der UI).
class_name RailPlaceTool
extends BuildTool

@export var valid_material: Material
@export var invalid_material: Material
@export var marker_material: Material

var _has_start := false
var _start_position := Vector3.ZERO
var _start_direction := Vector3.ZERO
var _start_node_id := -1
var _candidate: RailCandidate
var _candidate_valid := false
var _ghost_key := ""
var _markers_dirty := true
var _right_press_position := Vector2.INF

var _ghost: MeshInstance3D
var _cursor: MeshInstance3D
var _markers: Node3D
var _marker_mesh: CylinderMesh


func _on_setup() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)

	_marker_mesh = CylinderMesh.new()
	_marker_mesh.top_radius = 0.6
	_marker_mesh.bottom_radius = 0.6
	_marker_mesh.height = 0.05
	_marker_mesh.radial_segments = 16
	_marker_mesh.rings = 0

	_cursor = MeshInstance3D.new()
	_cursor.name = "Cursor"
	_cursor.mesh = _marker_mesh
	_cursor.material_override = marker_material
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cursor)

	_markers = Node3D.new()
	_markers.name = "OpenEndMarkers"
	add_child(_markers)
	context.rail_network.topology_changed.connect(func() -> void: _markers_dirty = true)


func activate() -> void:
	super()
	_markers_dirty = true


func cancel() -> bool:
	if not _has_start:
		return false
	_has_start = false
	_start_node_id = -1
	_candidate = null
	_ghost.visible = false
	set_status("")
	return true


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"interact_primary"):
		var point := context.get_mouse_ground_point()
		if point != Vector3.INF:
			click_at(point, Input.is_key_pressed(KEY_ALT))
		return true
	# Rechtsklick ohne Ziehen bricht ab; Ziehen bleibt der Kamera vorbehalten.
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			_right_press_position = button.position
		elif button.position.distance_to(_right_press_position) < 6.0:
			cancel()
	return false


func update_tool(_delta: float) -> void:
	if _markers_dirty:
		_rebuild_markers()
	var point := context.get_mouse_ground_point()
	if point == Vector3.INF:
		_cursor.visible = false
		_ghost.visible = false
		return
	preview_at(point, Input.is_key_pressed(KEY_ALT))


## Klick an einer Weltposition: Start setzen bzw. Gleis bauen.
## Gibt true zurück, wenn etwas passiert ist.
func click_at(point: Vector3, free_angle := false) -> bool:
	if not _has_start:
		return _begin_at(point)
	preview_at(point, free_angle)
	if _candidate == null or not _candidate_valid:
		return false
	_place(_candidate)
	return true


## Berechnet Vorschau und Gültigkeit für den Mauszeiger an [param point].
func preview_at(point: Vector3, free_angle := false) -> void:
	_validate_chain()
	var snap := _snap(point)
	_cursor.visible = true
	_cursor.global_position = snap["position"] + Vector3.UP * (RailConfig.RAIL_BASE + 0.2)

	if not _has_start:
		_ghost.visible = false
		var node := context.rail_network.find_node_near(point, RailConfig.SNAP_RADIUS)
		set_status("Abzweigen geht erst mit Weichen" if node and not node.is_open() else "")
		return

	var snapped_node: int = snap["node_id"]
	var end_direction: Vector3 = -snap["direction"] if snapped_node >= 0 else Vector3.ZERO
	var candidate := RailPlanner.plan(_start_position, _start_direction, snap["position"], end_direction, not free_angle)
	candidate.start_node_id = _start_node_id
	candidate.end_node_id = snapped_node
	if candidate.has_geometry():
		var end := candidate.get_end()
		var end_height: float = snap["position"].y if snapped_node >= 0 else context.terrain.get_height(end.x, end.z)
		candidate.apply_heights(_start_position.y, end_height)

	var reason := RailPlacementValidator.validate(candidate, context.rail_network, context.terrain,
		context.get_space_state())
	_candidate = candidate
	_candidate_valid = reason == ""
	set_status(reason)
	_update_ghost()


func has_start() -> bool:
	return _has_start


func is_candidate_valid() -> bool:
	return _candidate_valid


# --- Intern ----------------------------------------------------------------

func _begin_at(point: Vector3) -> bool:
	var node := context.rail_network.find_node_near(point, RailConfig.SNAP_RADIUS)
	if node:
		if not node.is_open():
			set_status("Abzweigen geht erst mit Weichen")
			return false
		_start_node_id = node.id
		_start_position = node.position
		_start_direction = context.rail_network.get_outward_direction(node.id)
	else:
		_start_node_id = -1
		_start_position = Vector3(point.x, context.terrain.get_height(point.x, point.z), point.z)
		_start_direction = Vector3.ZERO
	_has_start = true
	return true


func _place(candidate: RailCandidate) -> void:
	var network := context.rail_network
	var data := network.build_segment_data(candidate)
	var undo_redo := context.undo_redo
	undo_redo.create_action("Gleis bauen")
	undo_redo.add_do_method(network.restore_segment.bind(data))
	undo_redo.add_undo_method(network.remove_segment.bind(int(data["id"])))
	undo_redo.commit_action()

	# Kette: vom neuen Ende aus weiterbauen (außer es wurde an ein Gleis angeschlossen)
	var end_node := network.get_rail_node(int(data["end_node"]))
	if end_node and end_node.is_open():
		_start_node_id = end_node.id
		_start_position = end_node.position
		_start_direction = network.get_outward_direction(end_node.id)
	else:
		cancel()


## Nach Undo kann der Startknoten verschwunden oder belegt sein.
func _validate_chain() -> void:
	if _has_start and _start_node_id >= 0:
		var node := context.rail_network.get_rail_node(_start_node_id)
		if node == null or not node.is_open():
			cancel()


## Rastet an offenen Gleisenden in der Nähe ein.
func _snap(point: Vector3) -> Dictionary:
	var network := context.rail_network
	var node := network.find_open_node_near(point, RailConfig.SNAP_RADIUS, _start_node_id)
	if node:
		return {"position": node.position, "node_id": node.id, "direction": network.get_outward_direction(node.id)}
	var ground := Vector3(point.x, context.terrain.get_height(point.x, point.z), point.z)
	return {"position": ground, "node_id": -1, "direction": Vector3.ZERO}


func _update_ghost() -> void:
	if _candidate == null or not _candidate.has_geometry():
		_ghost.visible = false
		_ghost_key = ""
		return
	var key := "%s|%s" % [_candidate.points, _candidate_valid]
	if key != _ghost_key:
		_ghost_key = key
		_ghost.mesh = RailMeshes.create_ghost(_candidate.curve)
		_ghost.material_override = valid_material if _candidate_valid else invalid_material
	_ghost.visible = true


func _rebuild_markers() -> void:
	_markers_dirty = false
	for child in _markers.get_children():
		_markers.remove_child(child)
		child.queue_free()
	for node in context.rail_network.get_nodes():
		if node.is_open():
			var marker := MeshInstance3D.new()
			marker.mesh = _marker_mesh
			marker.material_override = marker_material
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marker.position = node.position + Vector3.UP * (RailConfig.RAIL_BASE + 0.2)
			_markers.add_child(marker)
