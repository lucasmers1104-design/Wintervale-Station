## Ein geplantes, noch nicht gebautes Gleisstück (Ergebnis von [RailPlanner]).
class_name RailCandidate
extends RefCounted

var points := PackedVector3Array()
var kind := RailSegment.Kind.STRAIGHT
## Knoten, an die angeschlossen wird (-1 = neuer Knoten).
var start_node_id := -1
var end_node_id := -1
## Geometrischer Fehler, z.B. "Kurve zu eng" ("" = geometrisch möglich).
var error := ""
var curve: Curve3D


func has_geometry() -> bool:
	return points.size() == 4


func get_start() -> Vector3:
	return points[0]


func get_end() -> Vector3:
	return points[3]


func get_length() -> float:
	return curve.get_baked_length() if curve else 0.0


## Setzt die Höhen von Anfang und Ende; dazwischen steigt das Gleis gleichmäßig.
func apply_heights(start_height: float, end_height: float) -> void:
	for i in 4:
		points[i].y = lerpf(start_height, end_height, i / 3.0)
	curve = RailGeometry.make_curve(points)
