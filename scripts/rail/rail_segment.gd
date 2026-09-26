## Ein Gleisstück im Netz: eine Bézierkurve zwischen zwei Knoten.
##
## Die Fahrtrichtung eines Stücks läuft immer von start_node zu end_node.
## Nachbarn und Verbindungstypen werden vom [RailNetwork] aktuell gehalten.
class_name RailSegment
extends RefCounted

enum Kind { STRAIGHT, CURVE }

var id: int
var kind: Kind
var start_node_id: int
var end_node_id: int
## Die vier Bézier-Kontrollpunkte (Start, Griff 1, Griff 2, Ende).
var control_points: PackedVector3Array
var curve: Curve3D
## Länge entlang der Kurve in Metern.
var length: float
## Nachbar-Gleise am Anfang bzw. am Ende.
var start_neighbors: Array[int] = []
var end_neighbors: Array[int] = []
## Verbindungstyp am Anfang bzw. am Ende (offenes Ende, Stoß, später Weiche).
var start_connection := RailNode.ConnectionType.END
var end_connection := RailNode.ConnectionType.END
## Abtastpunkte im Meterabstand (für Abstandsprüfungen und Auswahl).
var polyline: PackedVector3Array
## Umgebender Quader (leicht vergrößert) für schnelle Vorab-Tests.
var bounds: AABB


func _init(p_id: int, p_kind: Kind, points: PackedVector3Array, p_start_node: int, p_end_node: int) -> void:
	id = p_id
	kind = p_kind
	control_points = points
	start_node_id = p_start_node
	end_node_id = p_end_node
	curve = RailGeometry.make_curve(points)
	length = curve.get_baked_length()
	polyline = RailGeometry.polyline(curve, 1.0)
	bounds = AABB(polyline[0], Vector3.ZERO)
	for p in polyline:
		bounds = bounds.expand(p)
	bounds = bounds.grow(0.5)


func get_start_position() -> Vector3:
	return control_points[0]


func get_end_position() -> Vector3:
	return control_points[3]


## Fahrtrichtung am Anfang (zeigt ins Gleisstück hinein).
func get_start_direction() -> Vector3:
	return RailGeometry.tangent_at(curve, 0.0)


## Fahrtrichtung am Ende (zeigt aus dem Gleisstück heraus).
func get_end_direction() -> Vector3:
	return RailGeometry.tangent_at(curve, length)


func get_neighbors() -> Array[int]:
	return start_neighbors + end_neighbors


## Kürzester Abstand (Draufsicht) eines Punktes zur Gleisachse.
func distance_to_point(point: Vector3) -> float:
	var target := RailGeometry.flat(point)
	var best := INF
	for i in polyline.size() - 1:
		var a := RailGeometry.flat(polyline[i])
		var b := RailGeometry.flat(polyline[i + 1])
		best = minf(best, Geometry3D.get_closest_point_to_segment(target, a, b).distance_to(target))
	return best
