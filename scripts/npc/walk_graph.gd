@tool
## Fußwege der Bewohner: Wegpunkte und ihre Verbindungen.
##
## Jeder Wegpunkt ist ein [Marker3D]-Kind (der Name ist seine Kennung).
## [member links] verbindet Wegpunkte paarweise in beide Richtungen, z.B.
## "Dorf-Übergang". Die Bewohner suchen darauf den kürzesten Weg (A*) und
## laufen die letzten Meter frei zum eigentlichen Ziel (Bank, Tür, Haus).
##
## Im Editor zeigt der Knoten das Netz als dünne Linien an.
class_name WalkGraph
extends Node3D

const GROUP := &"walk_graph"

## Verbindungen als "WegpunktA-WegpunktB".
@export var links: PackedStringArray = []:
	set(value):
		links = value
		if is_node_ready():
			rebuild()
@export var show_in_editor := true

var _astar := AStar3D.new()
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
	if _ids.is_empty():
		path.append(_flat(to))
		return path
	var start := _astar.get_closest_point(_flat(from))
	var goal := _astar.get_closest_point(_flat(to))
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
