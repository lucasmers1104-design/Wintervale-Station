## Werkzeug "Weiche": Abzweige bauen und Weichen umstellen.
##
## - Klick auf ein bestehendes Gleis setzt dort eine Weiche. Danach wird der
##   abzweigende Ast wie mit dem Schienen-Werkzeug gezogen (die Richtung folgt
##   der Maus). Liegt der Klick mitten im Gleis, wird es dort geteilt.
## - Klick auf eine bestehende Weiche stellt sie um (sofern das Stellwerk es erlaubt).
##
## Nach dem Bau geht es vom Ende des Abzweigs direkt als normales Gleis weiter.
## Teilen + Abzweig sind eine einzige, rückgängig machbare Aktion.
class_name SwitchTool
extends RailPlaceTool

## So nah muss der Klick an einem Gleis bzw. einer Weiche liegen.
@export var pick_radius := 2.5

## Geplante Teilung des Gleises (leer = Abzweig an einem bestehenden Knoten).
var _split := {}
## true, solange der erste Abschnitt (der Weichenast) gezogen wird.
var _branch_mode := false
## Gleise am Abzweigpunkt, je Startrichtung: [Richtung, Nachbargleis, Steigung]
var _options: Array = []
var _related: Array[int] = []
var _sibling := -1


func cancel() -> bool:
	_branch_mode = false
	_split = {}
	_options.clear()
	_related.clear()
	_sibling = -1
	return super()


func _idle_status(point: Vector3) -> String:
	if context.rail_network.find_switch_near(point, pick_radius):
		return "Klick: Weiche umstellen"
	return ""


func _begin_at(point: Vector3) -> bool:
	var network := context.rail_network
	var switch := network.find_switch_near(point, pick_radius)
	if switch:
		var refused := context.interlocking.request_switch_toggle(switch.node_id)
		set_status(refused)
		return false

	var segment := network.find_segment_near(point, pick_radius)
	if segment == null:
		set_status("Auf ein Gleis klicken, um eine Weiche zu setzen")
		return false

	var offset := segment.closest_offset(point)
	var node_id := -1
	if offset < RailConfig.MIN_SPLIT_LENGTH:
		node_id = segment.start_node_id
	elif offset > segment.length - RailConfig.MIN_SPLIT_LENGTH:
		node_id = segment.end_node_id

	var start: Vector3
	var reason := ""
	_options.clear()
	_related.clear()
	_split = {}
	if node_id >= 0:
		var node := network.get_rail_node(node_id)
		if node.is_open():
			reason = "Am Gleisende mit dem Werkzeug Schiene weiterbauen"
		elif node.segment_ids.size() >= 3:
			reason = "Hier ist schon eine Weiche"
		elif not network.get_signals_at_node(node_id).is_empty():
			reason = "Hier steht ein Signal – etwas weiter entfernt setzen"
		start = node.position
		for id in node.segment_ids:
			var neighbor := network.get_segment(id)
			_related.append(id)
			# Der Abzweig läuft parallel zu dem Gleis, das in dieselbe Richtung weiterführt.
			_options.append([neighbor.get_direction_away_from(node_id), id, neighbor.get_grade_away_from(node_id)])
	else:
		start = segment.curve.sample_baked(offset, true)
		var tangent := RailGeometry.tangent_at(segment.curve, offset)
		var run := RailGeometry.flat(tangent).length()
		var grade := tangent.y / run if run > 0.001 else 0.0
		var axis := RailGeometry.flat(tangent).normalized()
		_related.append(segment.id)
		_options.append([axis, segment.id, grade])
		_options.append([-axis, segment.id, -grade])

	if reason == "":
		for other in network.get_switches():
			if network.get_rail_node(other.node_id).position.distance_to(start) < RailConfig.SWITCH_MIN_SPACING:
				reason = "Zu nah an einer anderen Weiche"
	if reason != "":
		set_status(reason)
		_options.clear()
		_related.clear()
		return false

	if node_id < 0:
		_split = network.plan_split(segment.id, offset)
	_start_node_id = node_id if node_id >= 0 else int(_split["node"])
	_start_position = start
	_start_directions.clear()
	for option: Array in _options:
		_start_directions.append(option[0])
	_start_fixed = true
	_branch_mode = true
	_has_start = true
	return true


func _pick_start_direction(target: Vector3) -> Vector3:
	var direction := super(target)
	if _branch_mode:
		for option: Array in _options:
			if option[0] == direction:
				_sibling = option[1]
				_start_grade = option[2]
	return direction


func _configure_candidate(candidate: RailCandidate) -> void:
	if not _branch_mode:
		return
	candidate.related_segments = _related.duplicate()
	candidate.sibling_segment_id = _sibling
	if candidate.kind == RailSegment.Kind.STRAIGHT and candidate.error == "":
		candidate.error = "Abzweig muss abbiegen – Maus zur Seite ziehen"


func _commit(candidate: RailCandidate) -> void:
	if not _branch_mode:
		super(candidate)
		return
	var network := context.rail_network
	var branch := network.build_segment_data(candidate)
	var split := _split
	var undo_redo := context.undo_redo
	undo_redo.create_action("Weiche bauen")
	undo_redo.add_do_method(network.build_switch.bind(split, branch))
	undo_redo.add_undo_method(network.unbuild_switch.bind(split, branch))
	undo_redo.commit_action()

	_branch_mode = false
	_split = {}
	_options.clear()
	_related.clear()
	_sibling = -1
	_continue_from(int(branch["end_node"]))


func _validate_chain() -> void:
	if not _branch_mode:
		super()
