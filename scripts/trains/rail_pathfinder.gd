## Wegsuche im Gleisnetz (kürzester Weg, Dijkstra).
##
## Gesucht wird über "gerichtete Gleise" (Gleis + Fahrtrichtung), denn ein Zug
## kann nicht einfach umdrehen. Weichenstellungen werden ignoriert – das
## Stellwerk stellt die Weichen später passend, wenn der Zug den Fahrweg anfordert.
class_name RailPathfinder
extends RefCounted

const ANY_DIRECTION := -1


## Weg von Gleis [param start_id] (in Richtung [param start_forward]) bis Gleis
## [param goal_id]. [param goal_forward]: 1 = vorwärts, 0 = rückwärts, -1 = egal.
## Rückgabe: {"ids": Array[int], "forwards": Array[bool]} oder {} ohne Weg.
static func find(network: RailNetwork, start_id: int, start_forward: bool, goal_id: int,
		goal_forward := ANY_DIRECTION) -> Dictionary:
	if network.get_segment(start_id) == null or network.get_segment(goal_id) == null:
		return {}
	var start_key := _key(start_id, start_forward)
	var distance := {start_key: 0.0}
	var previous := {}
	var open: Array = [start_key]
	var visited := {}
	while not open.is_empty():
		# Kleinsten Abstand wählen (kleine Netze → einfache Liste genügt)
		var best_index := 0
		for i in range(1, open.size()):
			if distance[open[i]] < distance[open[best_index]]:
				best_index = i
		var key: Vector2i = open[best_index]
		open.remove_at(best_index)
		if visited.has(key):
			continue
		visited[key] = true
		var forward := key.y == 1
		if key.x == goal_id and (goal_forward == ANY_DIRECTION or goal_forward == key.y):
			return _reconstruct(previous, key)

		var segment := network.get_segment(key.x)
		var exit_node := segment.end_node_id if forward else segment.start_node_id
		for next_id in network.get_next_segments(key.x, exit_node, false):
			var next := network.get_segment(next_id)
			var next_key := _key(next_id, next.start_node_id == exit_node)
			var cost: float = distance[key] + next.length
			if not distance.has(next_key) or cost < distance[next_key]:
				distance[next_key] = cost
				previous[next_key] = key
				open.append(next_key)
	return {}


## Hängt zwei Wege aneinander, die sich ein Gleis teilen (Ende von a = Anfang von b).
static func join(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty() or b.is_empty():
		return {}
	var ids: Array[int] = []
	var forwards: Array[bool] = []
	ids.assign(a["ids"])
	forwards.assign(a["forwards"])
	var b_ids: Array = b["ids"]
	var b_forwards: Array = b["forwards"]
	for i in range(1, b_ids.size()):
		ids.append(b_ids[i])
		forwards.append(b_forwards[i])
	return {"ids": ids, "forwards": forwards}


static func _key(segment_id: int, forward: bool) -> Vector2i:
	return Vector2i(segment_id, 1 if forward else 0)


static func _reconstruct(previous: Dictionary, last: Vector2i) -> Dictionary:
	var ids: Array[int] = []
	var forwards: Array[bool] = []
	var key := last
	while true:
		ids.push_front(key.x)
		forwards.push_front(key.y == 1)
		if not previous.has(key):
			break
		key = previous[key]
	return {"ids": ids, "forwards": forwards}
