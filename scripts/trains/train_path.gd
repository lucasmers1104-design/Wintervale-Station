## Der Weg eines Zuges: eine Folge von Gleisstücken mit Fahrtrichtung.
##
## Positionen auf dem Weg werden als Strecke in Metern ab dem Wegbeginn
## angegeben. Daraus berechnet der Pfad Weltposition und Fahrtrichtung –
## so kann ein Zug über beliebig viele Gleise, Weichen und Kurven fahren.
class_name TrainPath
extends RefCounted

var network: RailNetwork
var segment_ids: Array[int] = []
## true = das Gleis wird von Start- zu Endknoten befahren.
var forwards: Array[bool] = []
## Strecke, an der jedes Gleis beginnt.
var starts := PackedFloat32Array()
var total_length := 0.0


func _init(p_network: RailNetwork, ids: Array[int], directions: Array[bool]) -> void:
	network = p_network
	segment_ids = ids.duplicate()
	forwards = directions.duplicate()
	_measure()


func is_valid() -> bool:
	for id in segment_ids:
		if network.get_segment(id) == null:
			return false
	return not segment_ids.is_empty()


## Index des Gleises, auf dem die Strecke [param distance] liegt.
@warning_ignore("integer_division")
func index_at(distance: float) -> int:
	var low := 0
	var high := segment_ids.size() - 1
	while low < high:
		var middle := (low + high + 1) / 2
		if starts[middle] <= distance:
			low = middle
		else:
			high = middle - 1
	return low


func position_at(distance: float) -> Vector3:
	var index := index_at(distance)
	var segment := network.get_segment(segment_ids[index])
	return segment.curve.sample_baked(_local_offset(index, segment, distance), true)


## Fahrtrichtung (normiert) an der Strecke [param distance].
func direction_at(distance: float) -> Vector3:
	var index := index_at(distance)
	var segment := network.get_segment(segment_ids[index])
	var tangent := RailGeometry.tangent_at(segment.curve, _local_offset(index, segment, distance))
	return tangent if forwards[index] else -tangent


## Knoten am Ende des Gleises Nr. [param index] (in Fahrtrichtung).
func exit_node(index: int) -> int:
	var segment := network.get_segment(segment_ids[index])
	return segment.end_node_id if forwards[index] else segment.start_node_id


func entry_node(index: int) -> int:
	var segment := network.get_segment(segment_ids[index])
	return segment.start_node_id if forwards[index] else segment.end_node_id


## Strecke, an der das Gleis Nr. [param index] endet.
func end_of(index: int) -> float:
	return starts[index + 1] if index + 1 < starts.size() else total_length


## Gleis-IDs ab Index [param index] (für Fahrweganforderungen).
func ids_from(index: int) -> Array[int]:
	return segment_ids.slice(index)


## Alle Gleise, die zwischen zwei Strecken liegen (z.B. unter dem Zug).
func segments_between(from_distance: float, to_distance: float) -> Array[int]:
	var result: Array[int] = []
	var first := index_at(maxf(from_distance, 0.0))
	var last := index_at(clampf(to_distance, 0.0, total_length))
	for i in range(first, last + 1):
		if not result.has(segment_ids[i]):
			result.append(segment_ids[i])
	return result


## Strecke, an der der Weg einem Punkt am nächsten kommt (auf Gleis [param segment_id]).
func distance_near(point: Vector3, segment_id: int) -> float:
	var index := segment_ids.find(segment_id)
	if index < 0:
		return -1.0
	var segment := network.get_segment(segment_id)
	var offset := segment.closest_offset(point)
	return starts[index] + (offset if forwards[index] else segment.length - offset)


## Ersetzt den Weg ab Index [param index] durch neue Gleise (z.B. anderes Bahnsteiggleis).
func replace_from(index: int, ids: Array[int], directions: Array[bool]) -> void:
	var new_ids: Array[int] = segment_ids.slice(0, index)
	new_ids.append_array(ids)
	var new_forwards: Array[bool] = forwards.slice(0, index)
	new_forwards.append_array(directions)
	segment_ids = new_ids
	forwards = new_forwards
	_measure()


func _local_offset(index: int, segment: RailSegment, distance: float) -> float:
	var local := clampf(distance - starts[index], 0.0, segment.length)
	return local if forwards[index] else segment.length - local


func _measure() -> void:
	starts = PackedFloat32Array()
	total_length = 0.0
	for id in segment_ids:
		starts.append(total_length)
		var segment := network.get_segment(id)
		total_length += segment.length if segment else 0.0
