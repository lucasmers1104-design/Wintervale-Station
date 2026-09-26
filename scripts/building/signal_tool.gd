## Werkzeug "Signal": Hauptsignale an Gleise setzen.
##
## Das Signal steht rechts neben dem Gleis – die Seite, auf der die Maus steht,
## bestimmt also die Fahrtrichtung, für die es gilt. Nahe an einem Knoten
## wird dort gesetzt, sonst wird das Gleis an der Stelle geteilt (Signale
## sind Blockgrenzen). Entfernen geht mit dem Werkzeug Entfernen.
class_name SignalTool
extends BuildTool

@export var valid_material: Material
@export var invalid_material: Material
@export var pick_radius := 4.0

var _ghost: MeshInstance3D
var _plan := {}


func _on_setup() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "SignalGhost"
	_ghost.mesh = RailMeshes.create_signal_mast()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


func deactivate() -> void:
	_ghost.visible = false
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"interact_primary"):
		var point := context.get_mouse_ground_point()
		if point != Vector3.INF:
			place_at(point)
		return true
	return false


func update_tool(_delta: float) -> void:
	preview_at(context.get_mouse_ground_point())


## Berechnet Standort und Gültigkeit für ein Signal an [param point].
func preview_at(point: Vector3) -> void:
	_plan = plan_signal(point) if point != Vector3.INF else {}
	if _plan.is_empty():
		_ghost.visible = false
		set_status("")
		return
	set_status(_plan["reason"])
	if _plan.has("transform"):
		_ghost.global_transform = _plan["transform"]
		_ghost.material_override = valid_material if _plan["reason"] == "" else invalid_material
		_ghost.visible = true
	else:
		_ghost.visible = false


## Setzt ein Signal an [param point]. true = gebaut.
func place_at(point: Vector3) -> bool:
	preview_at(point)
	if _plan.is_empty() or _plan["reason"] != "":
		return false
	var network := context.rail_network
	var split := {}
	var node_id: int = _plan["node_id"]
	var segment_id: int = _plan["segment_id"]
	if _plan.has("split_offset"):
		split = network.plan_split(_plan["split_segment"], _plan["split_offset"])
		node_id = int(split["node"])
		var parts: Array = split["parts"]
		segment_id = int(parts[1]["id"]) if _plan["forward"] else int(parts[0]["id"])
	var signal_data := {"id": network.reserve_signal_id(), "node": node_id, "segment": segment_id,
		"mode": RailSignal.Mode.AUTO}
	var undo_redo := context.undo_redo
	undo_redo.create_action("Signal setzen")
	undo_redo.add_do_method(network.build_signal.bind(split, signal_data))
	undo_redo.add_undo_method(network.unbuild_signal.bind(split, signal_data))
	undo_redo.commit_action()
	return true


## Plant ein Signal. Rückgabe: {"reason", "transform", "node_id", "segment_id",
## "forward", optional "split_segment"/"split_offset"} – leer, wenn kein Gleis in der Nähe ist.
func plan_signal(point: Vector3) -> Dictionary:
	var network := context.rail_network
	var existing := network.find_signal_near(point, 1.5)
	if existing:
		return {"reason": "Hier steht schon ein Signal"}
	var segment := network.find_segment_near(point, pick_radius)
	if segment == null:
		return {}

	var offset := segment.closest_offset(point)
	var axis_point := segment.curve.sample_baked(offset, true)
	var tangent := RailGeometry.flat(RailGeometry.tangent_at(segment.curve, offset)).normalized()
	var forward := (point - axis_point).dot(tangent.cross(Vector3.UP)) >= 0.0
	var travel := tangent if forward else -tangent
	var plan := {"forward": forward, "reason": "", "node_id": -1, "segment_id": -1}

	var node_id := -1
	if offset < RailConfig.MIN_SPLIT_LENGTH:
		node_id = segment.start_node_id
	elif offset > segment.length - RailConfig.MIN_SPLIT_LENGTH:
		node_id = segment.end_node_id

	if node_id >= 0:
		var node := network.get_rail_node(node_id)
		axis_point = node.position
		plan["node_id"] = node_id
		plan["segment_id"] = _governed_segment(segment, node_id, forward)
		if node.get_connection_type() == RailNode.ConnectionType.SWITCH:
			plan["reason"] = "Nicht direkt an einer Weiche"
		elif plan["segment_id"] < 0:
			plan["reason"] = "Hinter dem Signal fehlt das Gleis"
		elif network.get_signal_for(node_id, plan["segment_id"]):
			plan["reason"] = "Hier steht schon ein Signal"
		elif plan["segment_id"] >= 0:
			travel = network.get_segment(plan["segment_id"]).get_direction_away_from(node_id)
	else:
		plan["split_segment"] = segment.id
		plan["split_offset"] = offset

	var right := travel.cross(Vector3.UP).normalized()
	var mast := axis_point + right * RailNetwork.SIGNAL_SIDE_OFFSET - travel * RailNetwork.SIGNAL_BACK_OFFSET
	mast.y -= TerrainDeformer.GROUND_OFFSET
	plan["transform"] = Transform3D(Basis.looking_at(-travel, Vector3.UP), mast)
	if plan["reason"] == "":
		plan["reason"] = _check_mast_space(mast, segment.id)
	return plan


## Das Gleis, in das ein Zug vom Knoten aus in der gewählten Richtung einfährt.
func _governed_segment(segment: RailSegment, node_id: int, forward: bool) -> int:
	var into_segment := (node_id == segment.start_node_id) == forward
	if into_segment:
		return segment.id
	var others := context.rail_network.get_next_segments(segment.id, node_id, false)
	return others[0] if others.size() == 1 else -1


func _check_mast_space(mast: Vector3, own_segment: int) -> String:
	for other in context.rail_network.get_segments():
		if other.id != own_segment and other.bounds.grow(2.0).has_point(Vector3(mast.x, other.bounds.get_center().y, mast.z)) \
				and other.distance_to_point(mast) < 2.0:
			return "Kein Platz für den Signalmast"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 3.0, 0.6)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = GameDefs.LAYER_OBJECTS
	query.transform = Transform3D(Basis.IDENTITY, mast + Vector3.UP * 1.8)
	if not context.get_space_state().intersect_shape(query, 1).is_empty():
		return "Hindernis im Weg"
	return ""
