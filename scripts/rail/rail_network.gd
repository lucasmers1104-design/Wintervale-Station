## Das Gleisnetz: verwaltet alle Knoten und Gleisstücke als Graph.
##
## Reine Daten – die Darstellung übernimmt [RailNetworkView], das Bauen die
## Build-Tools. Änderungen laufen ausschließlich über restore_segment() und
## remove_segment(), die mit Dictionaries arbeiten. Dadurch sind sie
## rückgängig machbar (Undo) und direkt speicherbar.
##
## Später bauen Weichen, Signale und die Zug-KI auf diesem Graphen auf.
class_name RailNetwork
extends Node

signal segment_added(segment: RailSegment)
signal segment_removed(segment: RailSegment)
## Verbindungen haben sich geändert (z.B. neue offene Enden).
signal topology_changed

const SAVE_ID := "rail_network"

var _segments: Dictionary[int, RailSegment] = {}
var _nodes: Dictionary[int, RailNode] = {}
var _next_segment_id := 1
var _next_node_id := 1
var _batch_depth := 0


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)


# --- Abfragen ------------------------------------------------------------------

func get_segment(id: int) -> RailSegment:
	return _segments.get(id)


func get_rail_node(id: int) -> RailNode:
	return _nodes.get(id)


func get_segments() -> Array[RailSegment]:
	var list: Array[RailSegment] = []
	list.assign(_segments.values())
	return list


func get_nodes() -> Array[RailNode]:
	var list: Array[RailNode] = []
	list.assign(_nodes.values())
	return list


func get_segment_count() -> int:
	return _segments.size()


## Alle Gleisstücke, die an [param segment_id] angrenzen.
func get_neighbors(segment_id: int) -> Array[int]:
	var segment := get_segment(segment_id)
	if segment == null:
		return []
	return segment.get_neighbors()


## Nächster Knoten im Umkreis (Draufsicht), optional ohne [param exclude_id].
func find_node_near(point: Vector3, radius: float, exclude_id := -1, only_open := false) -> RailNode:
	var best: RailNode = null
	var best_distance := radius
	for node: RailNode in _nodes.values():
		if node.id == exclude_id or (only_open and not node.is_open()):
			continue
		var distance := RailGeometry.flat(node.position - point).length()
		if distance <= best_distance:
			best = node
			best_distance = distance
	return best


func find_open_node_near(point: Vector3, radius: float, exclude_id := -1) -> RailNode:
	return find_node_near(point, radius, exclude_id, true)


## Nächstes Gleisstück, dessen Achse höchstens [param radius] entfernt ist.
func find_segment_near(point: Vector3, radius: float) -> RailSegment:
	var best: RailSegment = null
	var best_distance := radius
	for segment: RailSegment in _segments.values():
		if not segment.bounds.grow(radius).has_point(Vector3(point.x, segment.bounds.get_center().y, point.z)):
			continue
		var distance := segment.distance_to_point(point)
		if distance <= best_distance:
			best = segment
			best_distance = distance
	return best


## Richtung, in die an einem offenen Ende weitergebaut wird (vom Gleis weg).
func get_outward_direction(node_id: int) -> Vector3:
	var node := get_rail_node(node_id)
	if node == null or node.segment_ids.is_empty():
		return Vector3.ZERO
	var segment := get_segment(node.segment_ids[0])
	var direction := segment.get_end_direction() if segment.end_node_id == node_id \
		else -segment.get_start_direction()
	return RailGeometry.flat(direction).normalized()


# --- Bearbeiten (undo-fähig über Dictionaries) -------------------------------------

## Erzeugt die Baudaten für einen Kandidaten und reserviert dafür IDs.
func build_segment_data(candidate: RailCandidate) -> Dictionary:
	var start_node := candidate.start_node_id if candidate.start_node_id >= 0 else _reserve_node_id()
	var end_node := candidate.end_node_id if candidate.end_node_id >= 0 else _reserve_node_id()
	var points: Array = []
	for p in candidate.points:
		points.append(SaveUtils.vec3_to_array(p))
	var id := _next_segment_id
	_next_segment_id += 1
	return {"id": id, "kind": candidate.kind, "points": points, "start_node": start_node, "end_node": end_node}


## Fügt ein Gleisstück aus Baudaten ein (auch zum Wiederherstellen nach Undo/Laden).
func restore_segment(data: Dictionary) -> RailSegment:
	var id := int(data["id"])
	if _segments.has(id):
		return _segments[id]
	var points := PackedVector3Array()
	for value: Variant in data["points"]:
		points.append(SaveUtils.array_to_vec3(value))

	var start_node := _ensure_node(int(data["start_node"]), points[0])
	var end_node := _ensure_node(int(data["end_node"]), points[3])
	var segment := RailSegment.new(id, int(data["kind"]) as RailSegment.Kind, points, start_node.id, end_node.id)
	_segments[id] = segment
	start_node.segment_ids.append(id)
	end_node.segment_ids.append(id)
	_next_segment_id = maxi(_next_segment_id, id + 1)

	_refresh_nodes([start_node.id, end_node.id])
	segment_added.emit(segment)
	_emit_topology_changed()
	return segment


## Entfernt ein Gleisstück. Gibt seine Baudaten zurück (für Undo).
func remove_segment(id: int) -> Dictionary:
	var segment := get_segment(id)
	if segment == null:
		return {}
	var data := get_segment_data(id)
	_segments.erase(id)
	for node_id in [segment.start_node_id, segment.end_node_id]:
		var node := get_rail_node(node_id)
		if node:
			node.segment_ids.erase(id)
			if node.segment_ids.is_empty():
				_nodes.erase(node_id)
	_refresh_nodes([segment.start_node_id, segment.end_node_id])
	segment_removed.emit(segment)
	_emit_topology_changed()
	return data


func get_segment_data(id: int) -> Dictionary:
	var segment := get_segment(id)
	if segment == null:
		return {}
	var points: Array = []
	for p in segment.control_points:
		points.append(SaveUtils.vec3_to_array(p))
	return {
		"id": segment.id,
		"kind": segment.kind,
		"points": points,
		"start_node": segment.start_node_id,
		"end_node": segment.end_node_id,
	}


func clear() -> void:
	_batch_depth += 1
	for id: int in _segments.keys():
		remove_segment(id)
	_batch_depth -= 1
	_emit_topology_changed()


# --- Speichern -------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var segments: Array = []
	for id: int in _segments:
		segments.append(get_segment_data(id))
	return {"next_segment_id": _next_segment_id, "next_node_id": _next_node_id, "segments": segments}


func load_state(data: Dictionary) -> void:
	clear()
	_batch_depth += 1
	for segment_data: Dictionary in data.get("segments", []):
		restore_segment(segment_data)
	_batch_depth -= 1
	_next_segment_id = maxi(_next_segment_id, int(data.get("next_segment_id", 1)))
	_next_node_id = maxi(_next_node_id, int(data.get("next_node_id", 1)))
	_emit_topology_changed()


# --- Intern ------------------------------------------------------------------

func _reserve_node_id() -> int:
	var id := _next_node_id
	_next_node_id += 1
	return id


func _ensure_node(id: int, position: Vector3) -> RailNode:
	if not _nodes.has(id):
		_nodes[id] = RailNode.new(id, position)
		_next_node_id = maxi(_next_node_id, id + 1)
	return _nodes[id]


## Aktualisiert Nachbarn und Verbindungstypen aller Gleise an diesen Knoten.
func _refresh_nodes(node_ids: Array) -> void:
	var touched := {}
	for node_id: int in node_ids:
		var node := get_rail_node(node_id)
		if node:
			for segment_id in node.segment_ids:
				touched[segment_id] = true
	for segment_id: int in touched:
		var segment := get_segment(segment_id)
		segment.start_neighbors = _others_at(segment.start_node_id, segment_id)
		segment.end_neighbors = _others_at(segment.end_node_id, segment_id)
		segment.start_connection = get_rail_node(segment.start_node_id).get_connection_type()
		segment.end_connection = get_rail_node(segment.end_node_id).get_connection_type()


func _others_at(node_id: int, segment_id: int) -> Array[int]:
	var others: Array[int] = []
	for id in get_rail_node(node_id).segment_ids:
		if id != segment_id:
			others.append(id)
	return others


func _emit_topology_changed() -> void:
	if _batch_depth == 0:
		topology_changed.emit()
