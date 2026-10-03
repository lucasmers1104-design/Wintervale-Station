@tool
## Fußwege der Bewohner: Wegpunkte und ihre Verbindungen.
##
## Jeder Wegpunkt ist ein [Marker3D]-Kind (der Name ist seine Kennung).
## [member links] verbindet Wegpunkte paarweise in beide Richtungen, z.B.
## "Dorf-Übergang". Die Bewohner suchen darauf den kürzesten Weg (A*) und
## laufen die letzten Meter frei zum eigentlichen Ziel (Bank, Tür, Haus).
##
## Dazu kommt ein dynamischer Teil, den das Dorf setzt ([method set_dynamic]):
## gebaute Wege und Haustüren. Wege sind "billiger" als Querfeldein-Verbindungen,
## deshalb laufen die Bewohner bevorzugt auf Wegen.
##
## Im Editor zeigt der Knoten das Netz als dünne Linien an.
class_name WalkGraph
extends Node3D

const GROUP := &"walk_graph"
## Dynamische Punkte (Wege, Haustüren) haben IDs ab hier.
const DYNAMIC_OFFSET := 100000
## Kostenfaktoren je Verbindungsart: gebaute Wege sind am angenehmsten.
const COST_PATH := 0.65
const COST_BASE := 1.0
const COST_CONNECTOR := 1.3

## Verbindungen als "WegpunktA-WegpunktB".
@export var links: PackedStringArray = []:
	set(value):
		links = value
		if is_node_ready():
			rebuild()
@export var show_in_editor := true

var _astar := _WeightedAStar.new()
var _dynamic_count := 0
var _ids: Dictionary[String, int] = {}
var _debug: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PropScatter.GROUP_CLEARING)
	rebuild()


## Auf den Fußwegen wachsen keine Bäume (1,6 m links und rechts).
func clears(x: float, z: float) -> bool:
	var point := Vector3(x, 0.0, z)
	for id in _ids.values():
		for other in _astar.get_point_connections(id):
			if other > id:
				var a := _astar.get_point_position(id)
				var b := _astar.get_point_position(other)
				if point.distance_to(Geometry3D.get_closest_point_to_segment(point, a, b)) < 1.6:
					return true
	return false


## Liest Wegpunkte und Verbindungen neu ein.
func rebuild() -> void:
	_astar.clear()
	_ids.clear()
	var next_id := 0
	for child in get_children():
		if child is Marker3D:
			_ids[String(child.name)] = next_id
			_astar.add_point(next_id, _flat((child as Marker3D).global_position))
			next_id += 1
	for link in links:
		var ends := link.split("-")
		if ends.size() != 2 or not _ids.has(ends[0].strip_edges()) or not _ids.has(ends[1].strip_edges()):
			push_warning("WalkGraph: Verbindung '%s' kennt ihre Wegpunkte nicht." % link)
			continue
		_astar.connect_points(_ids[ends[0].strip_edges()], _ids[ends[1].strip_edges()])
	if Engine.is_editor_hint():
		_draw_debug()


func has_point(point_name: String) -> bool:
	return _ids.has(point_name)


func get_point(point_name: String) -> Vector3:
	return _astar.get_point_position(_ids[point_name]) if _ids.has(point_name) else Vector3.INF


func get_point_count() -> int:
	return _ids.size()


## Weg von [param from] nach [param to]: Einstieg am nächsten Wegpunkt, dann
## über das Netz, zuletzt frei zum Ziel. Alle Punkte liegen auf Höhe 0 (die
## Bewohner folgen selbst dem Boden).
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	path.append(_flat(from))
	if _astar.get_point_count()==0:
		path.append(_flat(to))
		return path
	var start := _astar.get_closest_point(_flat(from))
	var goal := _astar.get_closest_point(_flat(to))
	if _astar.get_id_path(start, goal).is_empty():
		# Nicht verbunden (z.B. ein Weg ohne Anschluss): über das feste Netz gehen
		start = _closest_base(from)
		goal = _closest_base(to)
		if start<0 or goal<0 or _astar.get_id_path(start,goal).is_empty():
			path.append(_flat(to))
			return path
	# Liegt das Ziel näher als der nächste Wegpunkt, direkt hingehen.
	if _flat(from).distance_to(_flat(to)) < _flat(from).distance_to(_astar.get_point_position(start)) \
			and start == goal:
		path.append(_flat(to))
		return path
	for point in _astar.get_point_path(start, goal):
		if point.distance_to(path[path.size() - 1]) > 0.05:
			path.append(point)
	if _flat(to).distance_to(path[path.size() - 1]) > 0.05:
		path.append(_flat(to))
	return _shortcut(path)


## Sind die zwei Wegpunkte über das Netz verbunden?
func is_connected_between(a: String, b: String) -> bool:
	if not _ids.has(a) or not _ids.has(b):
		return false
	return not _astar.get_id_path(_ids[a], _ids[b]).is_empty()


## Nächster Wegpunkt (Name) zu einer Stelle.
func get_closest_name(point: Vector3) -> String:
	var id := _astar.get_closest_point(_flat(point))
	for key in _ids:
		if _ids[key] == id:
			return key
	return ""


## Überspringt am Anfang einen Wegpunkt, wenn er in die Gegenrichtung führen würde
## (wer schon zwischen zwei Punkten steht, läuft nicht erst zurück).
func _shortcut(path: PackedVector3Array) -> PackedVector3Array:
	if path.size() >= 3:
		var back := path[1] - path[0]
		var ahead := path[2] - path[1]
		if back.dot(ahead) < 0.0 and path[0].distance_to(path[1]) < 3.0:
			path.remove_at(1)
	return path


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


func _draw_debug() -> void:
	if _debug == null:
		_debug = MeshInstance3D.new()
		_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_debug, false, Node.INTERNAL_MODE_BACK)
	if not show_in_editor or _ids.is_empty():
		_debug.mesh = null
		return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.7, 0.3)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for id in _ids.values():
		for other in _astar.get_point_connections(id):
			if other > id:
				mesh.surface_add_vertex(to_local(_astar.get_point_position(id)) + Vector3.UP * 0.8)
				mesh.surface_add_vertex(to_local(_astar.get_point_position(other)) + Vector3.UP * 0.8)
	mesh.surface_end()
	_debug.mesh = mesh


# --- Dynamischer Teil (Dorf) ---------------------------------------------------------

## Setzt Wege und Haustüren neu. [param points]: Positionen; [param edges]:
## [a, b, faktor] – a/b sind Indizes in [param points] (int) oder Namen fester
## Wegpunkte (String). Punkte ohne Verbindung werden nicht aufgenommen.
func set_dynamic(points: PackedVector3Array, edges: Array) -> void:
	for i in _dynamic_count:
		if _astar.has_point(DYNAMIC_OFFSET + i):
			_astar.remove_point(DYNAMIC_OFFSET + i)
	_astar.factors.clear()
	_dynamic_count = points.size()
	var used := {}
	for edge: Array in edges:
		for k in 2:
			if edge[k] is int:
				used[edge[k]] = true
	for i in points.size():
		if used.has(i):
			_astar.add_point(DYNAMIC_OFFSET + i, _flat(points[i]))
	for edge: Array in edges:
		var a := _resolve(edge[0])
		var b := _resolve(edge[1])
		if a < 0 or b < 0 or a == b or not _astar.has_point(a) or not _astar.has_point(b):
			continue
		_astar.connect_points(a, b)
		_astar.factors[_key(a, b)] = float(edge[2])


func get_dynamic_point_count() -> int:
	var count := 0
	for i in _dynamic_count:
		if _astar.has_point(DYNAMIC_OFFSET + i):
			count += 1
	return count


## Alle festen Wegpunkte: Name → Position.
func get_base_points() -> Dictionary:
	var points := {}
	for key in _ids:
		points[key] = _astar.get_point_position(_ids[key])
	return points


## Kosten eines Weges (Länge × Faktor je Verbindung) – für Tests.
func get_path_cost(from: Vector3, to: Vector3) -> float:
	var start := _astar.get_closest_point(_flat(from))
	var goal := _astar.get_closest_point(_flat(to))
	var ids := _astar.get_id_path(start, goal)
	var cost := 0.0
	for i in ids.size() - 1:
		cost += _astar._compute_cost(ids[i], ids[i + 1])
	return cost


## Anteil eines gefundenen Weges, der über gebaute Wege führt (0..1).
func get_path_share_on_paths(from: Vector3, to: Vector3) -> float:
	var start := _astar.get_closest_point(_flat(from))
	var goal := _astar.get_closest_point(_flat(to))
	var ids := _astar.get_id_path(start, goal)
	var total := 0.0
	var on_path := 0.0
	for i in ids.size() - 1:
		var length := _astar.get_point_position(ids[i]).distance_to(_astar.get_point_position(ids[i + 1]))
		total += length
		if is_equal_approx(float(_astar.factors.get(_key(ids[i], ids[i + 1]), COST_BASE)), COST_PATH):
			on_path += length
	return on_path / total if total > 0.0 else 0.0


func _resolve(ref: Variant) -> int:
	if ref is int:
		return DYNAMIC_OFFSET + int(ref)
	return _ids.get(String(ref), -1)


func _closest_base(point: Vector3) -> int:
	var best := -1
	var best_distance := INF
	for id in _ids.values():
		var distance := _astar.get_point_position(id).distance_to(_flat(point))
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


static func _key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## A* mit Kostenfaktor je Verbindung (Wege billiger, Querfeldein teurer).
class _WeightedAStar extends AStar3D:
	var factors: Dictionary = {}

	func _compute_cost(from_id: int, to_id: int) -> float:
		var factor := float(factors.get(WalkGraph._key(from_id, to_id), WalkGraph.COST_BASE))
		return get_point_position(from_id).distance_to(get_point_position(to_id)) * factor

	func _estimate_cost(from_id: int, end_id: int) -> float:
		return get_point_position(from_id).distance_to(get_point_position(end_id)) * WalkGraph.COST_PATH


## Kürzester Abstand (Draufsicht) von [param point] zu einer Verbindung des Netzes –
## damit Festbuden & Co. keine Fußwege der Bewohner versperren.
func distance_to_links(point: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var best := INF
	for id in _astar.get_point_ids():
		var a := _astar.get_point_position(id)
		for other in _astar.get_point_connections(id):
			if other < id:
				continue
			var b := _astar.get_point_position(other)
			var closest := Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z))
			best = minf(best, closest.distance_to(p))
	return best
