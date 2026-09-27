## Ein Gleisstück im Netz: eine Kurve zwischen zwei Knoten.
##
## Die Fahrtrichtung eines Stücks läuft immer von start_node zu end_node.
## Nachbarn, Verbindungstypen und der Gleisabschnitt (Block) werden vom
## [RailNetwork] aktuell gehalten.
class_name RailSegment
extends RefCounted

enum Kind { STRAIGHT, CURVE }

var id: int
var kind: Kind
var start_node_id: int
var end_node_id: int
## Die vier Bézier-Kontrollpunkte des Grundrisses (Start, Griff 1, Griff 2, Ende).
var control_points: PackedVector3Array
## Höhenprofil entlang des Grundrisses (gleichmäßig verteilt, ~2 m Abstand).
var heights: PackedFloat32Array
## Geometrischer Verlauf (Grundriss + Höhenprofil).
var curve: Curve3D
## Länge entlang der Kurve in Metern.
var length: float
## Nachbar-Gleise am Anfang bzw. am Ende.
var start_neighbors: Array[int] = []
var end_neighbors: Array[int] = []
## Verbindungstyp am Anfang bzw. am Ende (offenes Ende, Stoß, Weiche).
var start_connection := RailNode.ConnectionType.END
var end_connection := RailNode.ConnectionType.END
## Gleisabschnitt (Block) für Signale und Belegung – Gleise zwischen Signalen.
var block_id := -1
## Liegt im Tunnel: formt kein Gelände (sonst entstünde ein Graben im Berg).
var tunnel := false
## Abtastpunkte im Meterabstand (für Abstandsprüfungen und Auswahl).
var polyline: PackedVector3Array
## Gleisachse im 2-m-Abstand (für die Geländeanpassung).
var axis_points: PackedVector3Array
## Umgebender Quader (leicht vergrößert) für schnelle Vorab-Tests.
var bounds: AABB


func _init(p_id: int, p_kind: Kind, points: PackedVector3Array, p_start_node: int, p_end_node: int,
		p_heights := PackedFloat32Array()) -> void:
	id = p_id
	kind = p_kind
	control_points = points
	heights = p_heights
	start_node_id = p_start_node
	end_node_id = p_end_node
	curve = RailGeometry.make_curve(points, heights)
	length = curve.get_baked_length()
	polyline = RailGeometry.polyline(curve, 1.0)
	axis_points = RailGeometry.polyline(curve, 2.0)
	bounds = AABB(polyline[0], Vector3.ZERO)
	for p in polyline:
		bounds = bounds.expand(p)
	bounds = bounds.grow(0.5)


func get_start_position() -> Vector3:
	return curve.sample_baked(0.0, true)


func get_end_position() -> Vector3:
	return curve.sample_baked(length, true)


## Fahrtrichtung am Anfang (zeigt ins Gleisstück hinein).
func get_start_direction() -> Vector3:
	return RailGeometry.tangent_at(curve, 0.0)


## Fahrtrichtung am Ende (zeigt aus dem Gleisstück heraus).
func get_end_direction() -> Vector3:
	return RailGeometry.tangent_at(curve, length)


## Der Knoten am anderen Ende.
func get_other_node(node_id: int) -> int:
	return end_node_id if node_id == start_node_id else start_node_id


## Richtung vom Knoten weg ins Gleis hinein (Draufsicht).
func get_direction_away_from(node_id: int) -> Vector3:
	var direction := get_start_direction() if node_id == start_node_id else -get_end_direction()
	return RailGeometry.flat(direction).normalized()


## Steigung vom Knoten weg (Höhenänderung je Meter).
func get_grade_away_from(node_id: int) -> float:
	var direction := get_start_direction() if node_id == start_node_id else -get_end_direction()
	var run := RailGeometry.flat(direction).length()
	return direction.y / run if run > 0.001 else 0.0


func get_neighbors() -> Array[int]:
	return start_neighbors + end_neighbors


## Kürzester Abstand (Draufsicht) eines Punktes zur Gleisachse.
func distance_to_point(point: Vector3) -> float:
	return RailGeometry.flat(point).distance_to(RailGeometry.flat(closest_point(point)))


## Nächster Punkt auf der Gleisachse.
func closest_point(point: Vector3) -> Vector3:
	return curve.sample_baked(closest_offset(point), true)


## Kurvenposition (Meter ab Start) des nächsten Achspunktes.
func closest_offset(point: Vector3) -> float:
	var target := RailGeometry.flat(point)
	var best := INF
	var best_offset := 0.0
	var step := length / maxf(1.0, polyline.size() - 1.0)
	for i in polyline.size() - 1:
		var a := RailGeometry.flat(polyline[i])
		var b := RailGeometry.flat(polyline[i + 1])
		var closest := Geometry3D.get_closest_point_to_segment(target, a, b)
		var distance := closest.distance_to(target)
		if distance < best:
			best = distance
			var span := a.distance_to(b)
			best_offset = step * (i + (a.distance_to(closest) / span if span > 0.0 else 0.0))
	return clampf(best_offset, 0.0, length)
