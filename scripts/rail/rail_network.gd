## Das Gleisnetz: verwaltet Knoten, Gleisstücke, Weichen, Signale und
## Gleisabschnitte (Blöcke) als Graph.
##
## Reine Daten – die Darstellung übernimmt [RailNetworkView], die Sicherungs-
## logik [RailInterlocking], das Bauen die Build-Tools. Alle Änderungen laufen
## über Methoden, die mit Dictionaries arbeiten (restore_segment,
## remove_segment, add_signal, build_switch …). Dadurch sind sie rückgängig
## machbar (Undo) und direkt speicherbar.
##
## Begriffe:
## - Knoten mit 1 Gleis = offenes Ende, 2 Gleisen = Stoß, 3 Gleisen = Weiche
## - Block = zusammenhängende Gleise zwischen Signalen (für Belegung & Fahrwege)
class_name RailNetwork
extends Node

signal segment_added(segment: RailSegment)
signal segment_removed(segment: RailSegment)
## Verbindungen, Weichen, Signale oder Blöcke haben sich geändert.
signal topology_changed
## Eine Weiche wurde umgestellt.
signal switch_changed(node_id: int)
## Ein Signal wurde auf Automatik/Halt umgeschaltet.
signal signal_mode_changed(signal_id: int)

const SAVE_ID := "rail_network"
## Abstand des Signalmasts von der Gleisachse (rechts in Fahrtrichtung).
const SIGNAL_SIDE_OFFSET := 2.4
## Der Mast steht kurz vor dem Knoten.
const SIGNAL_BACK_OFFSET := 0.6

var _segments: Dictionary[int, RailSegment] = {}
var _nodes: Dictionary[int, RailNode] = {}
var _signals: Dictionary[int, RailSignal] = {}
var _switches: Dictionary[int, RailSwitch] = {}
## Merkt sich Weichenstellungen, auch wenn eine Weiche kurz verschwindet (Undo).
var _switch_memory: Dictionary[int, int] = {}
var _blocks: Dictionary[int, Array] = {}
var _next_segment_id := 1
var _next_node_id := 1
var _next_signal_id := 1
var _batch_depth := 0


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)


# --- Abfragen: Gleise & Knoten ------------------------------------------------------

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


## Weiterfahrt: Welche Gleise folgen, wenn man aus [param from_segment_id]
## kommend den Knoten [param node_id] überfährt? Mit [param respect_switches]
## wird die aktuelle Weichenstellung berücksichtigt (sonst alle Möglichkeiten).
func get_next_segments(from_segment_id: int, node_id: int, respect_switches := true) -> Array[int]:
	var node := get_rail_node(node_id)
	var result: Array[int] = []
	if node == null:
		return result
	var switch := get_switch(node_id)
	if switch == null:
		for id in node.segment_ids:
			if id != from_segment_id:
				result.append(id)
		return result
	if from_segment_id == switch.trunk_segment_id:
		if respect_switches:
			result.append(switch.get_active_branch())
		else:
			result.assign(switch.branch_segment_ids)
	elif switch.is_branch(from_segment_id):
		if not respect_switches or switch.get_active_branch() == from_segment_id:
			result.append(switch.trunk_segment_id)
	return result


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
	return -get_segment(node.segment_ids[0]).get_direction_away_from(node_id)


## Steigung, mit der ein Gleis an einem offenen Ende weitergeführt werden sollte.
func get_outward_grade(node_id: int) -> float:
	var node := get_rail_node(node_id)
	if node == null or node.segment_ids.is_empty():
		return 0.0
	return -get_segment(node.segment_ids[0]).get_grade_away_from(node_id)


# --- Abfragen: Weichen, Signale, Blöcke ------------------------------------------------

func get_switch(node_id: int) -> RailSwitch:
	return _switches.get(node_id)


func get_switches() -> Array[RailSwitch]:
	var list: Array[RailSwitch] = []
	list.assign(_switches.values())
	return list


func find_switch_near(point: Vector3, radius: float) -> RailSwitch:
	var best: RailSwitch = null
	var best_distance := radius
	for switch: RailSwitch in _switches.values():
		var distance := RailGeometry.flat(get_rail_node(switch.node_id).position - point).length()
		if distance <= best_distance:
			best = switch
			best_distance = distance
	return best


func get_signal(id: int) -> RailSignal:
	return _signals.get(id)


## Alle Signale, nach ID sortiert (stabile Reihenfolge für die Sicherungslogik).
func get_signals() -> Array[RailSignal]:
	var ids := _signals.keys()
	ids.sort()
	var list: Array[RailSignal] = []
	for id: int in ids:
		list.append(_signals[id])
	return list


func get_signals_at_node(node_id: int) -> Array[RailSignal]:
	var list: Array[RailSignal] = []
	for rail_signal: RailSignal in _signals.values():
		if rail_signal.node_id == node_id:
			list.append(rail_signal)
	return list


## Signal an einem Knoten, das die Einfahrt in [param segment_id] sichert.
func get_signal_for(node_id: int, segment_id: int) -> RailSignal:
	for rail_signal: RailSignal in _signals.values():
		if rail_signal.node_id == node_id and rail_signal.segment_id == segment_id:
			return rail_signal
	return null


## Standort des Signalmasts. -Z zeigt zu den Zügen, die auf das Signal zufahren.
func get_signal_transform(rail_signal: RailSignal) -> Transform3D:
	var node := get_rail_node(rail_signal.node_id)
	var segment := get_segment(rail_signal.segment_id)
	if node == null or segment == null:
		return Transform3D.IDENTITY
	var direction := segment.get_direction_away_from(node.id)
	var right := direction.cross(Vector3.UP).normalized()
	var origin := node.position + right * SIGNAL_SIDE_OFFSET - direction * SIGNAL_BACK_OFFSET
	origin.y -= TerrainDeformer.GROUND_OFFSET
	return Transform3D(Basis.looking_at(-direction, Vector3.UP), origin)


func find_signal_near(point: Vector3, radius: float) -> RailSignal:
	var best: RailSignal = null
	var best_distance := radius
	for rail_signal: RailSignal in _signals.values():
		var distance := RailGeometry.flat(get_signal_transform(rail_signal).origin - point).length()
		if distance <= best_distance:
			best = rail_signal
			best_distance = distance
	return best


func get_block_ids() -> Array[int]:
	var list: Array[int] = []
	list.assign(_blocks.keys())
	return list


func get_block_segments(block_id: int) -> Array[int]:
	var list: Array[int] = []
	list.assign(_blocks.get(block_id, []))
	return list


# --- Bearbeiten: Gleise --------------------------------------------------------------

## Erzeugt die Baudaten für einen Kandidaten und reserviert dafür IDs.
func build_segment_data(candidate: RailCandidate) -> Dictionary:
	var start_node := candidate.start_node_id if candidate.start_node_id >= 0 else _reserve_node_id()
	var end_node := candidate.end_node_id if candidate.end_node_id >= 0 else _reserve_node_id()
	return _make_segment_data(_reserve_segment_id(), candidate.kind, candidate.points, candidate.heights,
		start_node, end_node)


## Fügt ein Gleisstück aus Baudaten ein (auch zum Wiederherstellen nach Undo/Laden).
## Enthält [param data] Signale, werden diese mit wiederhergestellt.
func restore_segment(data: Dictionary) -> RailSegment:
	var id := int(data["id"])
	if _segments.has(id):
		return _segments[id]
	var points := PackedVector3Array()
	for value: Variant in data["points"]:
		points.append(SaveUtils.array_to_vec3(value))
	var heights := PackedFloat32Array()
	for value: Variant in data.get("heights", []):
		heights.append(float(value))

	var start_node := _ensure_node(int(data["start_node"]), points[0])
	var end_node := _ensure_node(int(data["end_node"]), points[3])
	var segment := RailSegment.new(id, int(data["kind"]) as RailSegment.Kind, points, start_node.id,
		end_node.id, heights)
	segment.tunnel = bool(data.get("tunnel", false))
	_segments[id] = segment
	start_node.segment_ids.append(id)
	end_node.segment_ids.append(id)
	_next_segment_id = maxi(_next_segment_id, id + 1)

	_batch_depth += 1
	for signal_data: Dictionary in data.get("signals", []):
		add_signal(signal_data)
	_batch_depth -= 1

	_refresh_nodes([start_node.id, end_node.id])
	segment_added.emit(segment)
	_changed()
	return segment


## Entfernt ein Gleisstück samt seiner Signale. Gibt die Baudaten zurück (für Undo).
func remove_segment(id: int) -> Dictionary:
	var segment := get_segment(id)
	if segment == null:
		return {}
	var data := get_segment_data(id)
	_batch_depth += 1
	for rail_signal: RailSignal in _signals.values():
		if rail_signal.segment_id == id:
			remove_signal(rail_signal.id)
	_batch_depth -= 1

	_segments.erase(id)
	for node_id in [segment.start_node_id, segment.end_node_id]:
		var node := get_rail_node(node_id)
		if node:
			node.segment_ids.erase(id)
			if node.segment_ids.is_empty():
				_nodes.erase(node_id)
	_refresh_nodes([segment.start_node_id, segment.end_node_id])
	segment_removed.emit(segment)
	_changed()
	return data


## Baudaten eines Gleisstücks inkl. der Signale, die es sichern.
func get_segment_data(id: int, with_signals := true) -> Dictionary:
	var segment := get_segment(id)
	if segment == null:
		return {}
	var data := _make_segment_data(segment.id, segment.kind, segment.control_points, segment.heights,
		segment.start_node_id, segment.end_node_id)
	if segment.tunnel:
		data["tunnel"] = true
	if with_signals:
		var signals: Array = []
		for rail_signal: RailSignal in _signals.values():
			if rail_signal.segment_id == id:
				signals.append(rail_signal.to_dict())
		data["signals"] = signals
	return data


## Plant das Teilen eines Gleisstücks an [param offset] (Meter ab Start).
## Reserviert IDs und liefert alles, was apply_split()/revert_split() brauchen.
func plan_split(segment_id: int, offset: float) -> Dictionary:
	var segment := get_segment(segment_id)
	var fraction := clampf(offset / segment.length, 0.01, 0.99)
	var t := RailGeometry.bezier_param_at_fraction(segment.control_points, fraction)
	var halves := RailGeometry.split_bezier(segment.control_points, t)
	var split_point := segment.curve.sample_baked(offset, true)
	var node_id := _reserve_node_id()

	var parts: Array = []
	var ranges := [[0.0, fraction], [fraction, 1.0]]
	var nodes := [[segment.start_node_id, node_id], [node_id, segment.end_node_id]]
	for i in 2:
		var points: PackedVector3Array = halves[i]
		var planar_length := RailGeometry.make_planar_curve(points).get_baked_length()
		var count := maxi(2, ceili(planar_length / RailProfile.SAMPLE_SPACING))
		var heights := PackedFloat32Array()
		if segment.heights.size() >= 2:
			heights = RailGeometry.resample_heights(segment.heights, ranges[i][0], ranges[i][1], count)
		else:
			var y0 := segment.get_start_position().y
			var y1 := segment.get_end_position().y
			heights = RailGeometry.resample_heights(PackedFloat32Array([y0, y1]), ranges[i][0], ranges[i][1], count)
		heights[0 if i == 1 else heights.size() - 1] = split_point.y
		points[0].y = heights[0]
		points[3].y = heights[heights.size() - 1]
		var kind := RailSegment.Kind.STRAIGHT if segment.kind == RailSegment.Kind.STRAIGHT else RailSegment.Kind.CURVE
		var part := _make_segment_data(_reserve_segment_id(), kind, points, heights, nodes[i][0], nodes[i][1])
		if segment.tunnel:
			part["tunnel"] = true
		parts.append(part)
	return {"original": get_segment_data(segment_id), "parts": parts, "node": node_id}


## Teilt ein Gleis wie geplant. Signale werden auf die passenden Teile umgehängt.
func apply_split(split: Dictionary) -> void:
	var original: Dictionary = split["original"]
	var parts: Array = split["parts"]
	_batch_depth += 1
	var removed := remove_segment(int(original["id"]))
	restore_segment(parts[0])
	restore_segment(parts[1])
	for signal_data: Dictionary in removed.get("signals", []):
		var mapped := signal_data.duplicate()
		var at_start := int(signal_data["node"]) == int(original["start_node"])
		mapped["segment"] = int(parts[0]["id"]) if at_start else int(parts[1]["id"])
		add_signal(mapped)
	_batch_depth -= 1
	_changed()


## Macht eine Teilung rückgängig.
func revert_split(split: Dictionary) -> void:
	var parts: Array = split["parts"]
	_batch_depth += 1
	remove_segment(int(parts[0]["id"]))
	remove_segment(int(parts[1]["id"]))
	restore_segment(split["original"])
	_batch_depth -= 1
	_changed()


# --- Bearbeiten: Weichen -------------------------------------------------------------

## Baut eine Weiche: optional ein Gleis teilen, dann den Abzweig anschließen.
func build_switch(split: Dictionary, branch: Dictionary) -> void:
	_batch_depth += 1
	if not split.is_empty():
		apply_split(split)
	restore_segment(branch)
	_batch_depth -= 1
	_changed()


func unbuild_switch(split: Dictionary, branch: Dictionary) -> void:
	_batch_depth += 1
	remove_segment(int(branch["id"]))
	if not split.is_empty():
		revert_split(split)
	_batch_depth -= 1
	_changed()


func set_switch_state(node_id: int, state: int) -> void:
	var switch := get_switch(node_id)
	if switch == null or switch.state == state:
		return
	switch.state = clampi(state, 0, 1)
	_switch_memory[node_id] = switch.state
	switch_changed.emit(node_id)


# --- Bearbeiten: Signale -------------------------------------------------------------

func reserve_signal_id() -> int:
	var id := _next_signal_id
	_next_signal_id += 1
	return id


func add_signal(data: Dictionary) -> RailSignal:
	var id := int(data["id"])
	var rail_signal := RailSignal.new(id, int(data["node"]), int(data["segment"]),
		int(data.get("mode", RailSignal.Mode.AUTO)) as RailSignal.Mode)
	if data.has("resume_mode"):
		rail_signal.resume_mode = int(data["resume_mode"]) as RailSignal.Mode
	_signals[id] = rail_signal
	_next_signal_id = maxi(_next_signal_id, id + 1)
	_changed()
	return rail_signal


func remove_signal(id: int) -> Dictionary:
	var rail_signal := get_signal(id)
	if rail_signal == null:
		return {}
	var data := rail_signal.to_dict()
	_signals.erase(id)
	_changed()
	return data


## Setzt ein Signal (optional nach Teilen eines Gleises).
func build_signal(split: Dictionary, signal_data: Dictionary) -> void:
	_batch_depth += 1
	if not split.is_empty():
		apply_split(split)
	add_signal(signal_data)
	_batch_depth -= 1
	_changed()


func unbuild_signal(split: Dictionary, signal_data: Dictionary) -> void:
	_batch_depth += 1
	remove_signal(int(signal_data["id"]))
	if not split.is_empty():
		revert_split(split)
	_batch_depth -= 1
	_changed()


func set_signal_mode(id: int, mode: RailSignal.Mode) -> void:
	var rail_signal := get_signal(id)
	if rail_signal and rail_signal.mode != mode:
		rail_signal.mode = mode
		if mode != RailSignal.Mode.HALT:
			rail_signal.resume_mode = mode
		signal_mode_changed.emit(id)


func clear() -> void:
	_batch_depth += 1
	for id: int in _segments.keys():
		remove_segment(id)
	_signals.clear()
	_switch_memory.clear()
	_batch_depth -= 1
	_changed()


# --- Speichern -------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var segments: Array = []
	for id: int in _segments:
		segments.append(get_segment_data(id, false))
	var signals: Array = []
	for rail_signal in get_signals():
		signals.append(rail_signal.to_dict())
	var switch_states := {}
	for switch: RailSwitch in _switches.values():
		switch_states[str(switch.node_id)] = switch.state
	return {
		"next_segment_id": _next_segment_id,
		"next_node_id": _next_node_id,
		"next_signal_id": _next_signal_id,
		"segments": segments,
		"signals": signals,
		"switch_states": switch_states,
	}


func load_state(data: Dictionary) -> void:
	clear()
	_batch_depth += 1
	var states: Dictionary = data.get("switch_states", {})
	for key: Variant in states:
		_switch_memory[int(key)] = int(states[key])
	for segment_data: Dictionary in data.get("segments", []):
		restore_segment(segment_data)
	for signal_data: Dictionary in data.get("signals", []):
		add_signal(signal_data)
	_batch_depth -= 1
	_next_segment_id = maxi(_next_segment_id, int(data.get("next_segment_id", 1)))
	_next_node_id = maxi(_next_node_id, int(data.get("next_node_id", 1)))
	_next_signal_id = maxi(_next_signal_id, int(data.get("next_signal_id", 1)))
	_changed()


# --- Intern ------------------------------------------------------------------

func _make_segment_data(id: int, kind: int, points: PackedVector3Array, heights: PackedFloat32Array,
		start_node: int, end_node: int) -> Dictionary:
	var point_list: Array = []
	for p in points:
		point_list.append(SaveUtils.vec3_to_array(p))
	var height_list: Array = []
	for h in heights:
		height_list.append(snappedf(h, 0.0001))
	return {"id": id, "kind": kind, "points": point_list, "heights": height_list,
		"start_node": start_node, "end_node": end_node}


func _reserve_segment_id() -> int:
	var id := _next_segment_id
	_next_segment_id += 1
	return id


func _reserve_node_id() -> int:
	var id := _next_node_id
	_next_node_id += 1
	return id


func _ensure_node(id: int, position: Vector3) -> RailNode:
	if not _nodes.has(id):
		_nodes[id] = RailNode.new(id, position)
		_next_node_id = maxi(_next_node_id, id + 1)
	return _nodes[id]


## Aktualisiert Nachbarn, Verbindungstypen und Weichen an diesen Knoten.
func _refresh_nodes(node_ids: Array) -> void:
	var touched := {}
	for node_id: int in node_ids:
		_refresh_switch(node_id)
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


## Erkennt Stamm- und Astgleise einer Weiche anhand der Richtungen am Knoten.
func _refresh_switch(node_id: int) -> void:
	var node := get_rail_node(node_id)
	if node == null or node.segment_ids.size() != 3:
		if _switches.has(node_id):
			_switch_memory[node_id] = _switches[node_id].state
			_switches.erase(node_id)
		return

	var directions := {}
	for id in node.segment_ids:
		directions[id] = get_segment(id).get_direction_away_from(node_id)
	var trunk := -1
	var lowest := INF
	for id in node.segment_ids:
		var score := 0.0
		for other in node.segment_ids:
			if other != id:
				score += (directions[id] as Vector3).dot(directions[other])
		if score < lowest:
			lowest = score
			trunk = id

	var branches: Array[int] = []
	for id in node.segment_ids:
		if id != trunk:
			branches.append(id)
	branches.sort_custom(_is_straighter_branch.bind(node_id))

	var switch: RailSwitch = _switches.get(node_id, RailSwitch.new())
	switch.node_id = node_id
	switch.trunk_segment_id = trunk
	switch.branch_segment_ids = branches
	if not _switches.has(node_id):
		switch.state = _switch_memory.get(node_id, 0)
	var axis := get_segment(branches[0]).get_direction_away_from(node_id)
	var right := axis.cross(Vector3.UP).normalized()
	var diverging := get_segment(branches[1])
	var far_end := diverging.get_end_position() if diverging.start_node_id == node_id else diverging.get_start_position()
	switch.diverging_side = 1.0 if (far_end - node.position).dot(right) >= 0.0 else -1.0
	_switches[node_id] = switch


## Sortierung der Weichenäste: der geradere Ast zuerst.
func _is_straighter_branch(a: int, b: int, node_id: int) -> bool:
	var deviation_a := _branch_deviation(a, node_id)
	var deviation_b := _branch_deviation(b, node_id)
	return deviation_a < deviation_b - 0.001 or (absf(deviation_a - deviation_b) <= 0.001 and a < b)


## Wie stark ein Ast von der Weichenachse abbiegt (Winkel zwischen Anfang und Ende).
func _branch_deviation(segment_id: int, node_id: int) -> float:
	var segment := get_segment(segment_id)
	var away := segment.get_direction_away_from(node_id)
	var far := segment.get_end_direction() if segment.start_node_id == node_id else -segment.get_start_direction()
	return away.angle_to(RailGeometry.flat(far).normalized())


func _others_at(node_id: int, segment_id: int) -> Array[int]:
	var others: Array[int] = []
	for id in get_rail_node(node_id).segment_ids:
		if id != segment_id:
			others.append(id)
	return others


## Blöcke neu bilden: Gleise hängen zusammen, solange am Knoten kein Signal steht.
func _recompute_blocks() -> void:
	var parent := {}
	for id: int in _segments:
		parent[id] = id
	var signal_nodes := {}
	for rail_signal: RailSignal in _signals.values():
		signal_nodes[rail_signal.node_id] = true
	for node: RailNode in _nodes.values():
		if signal_nodes.has(node.id) or node.segment_ids.size() < 2:
			continue
		var root := _find_root(parent, node.segment_ids[0])
		for i in range(1, node.segment_ids.size()):
			var other := _find_root(parent, node.segment_ids[i])
			if other != root:
				parent[maxi(root, other)] = mini(root, other)
				root = mini(root, other)

	_blocks.clear()
	for id: int in _segments:
		var block := _find_root(parent, id)
		_segments[id].block_id = block
		if not _blocks.has(block):
			_blocks[block] = []
		_blocks[block].append(id)


func _find_root(parent: Dictionary, id: int) -> int:
	while parent[id] != id:
		parent[id] = parent[parent[id]]
		id = parent[id]
	return id


func _changed() -> void:
	if _batch_depth == 0:
		_recompute_blocks()
		topology_changed.emit()
