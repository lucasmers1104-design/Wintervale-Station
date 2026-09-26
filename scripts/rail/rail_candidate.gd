## Ein geplantes, noch nicht gebautes Gleisstück (Ergebnis von [RailPlanner]).
class_name RailCandidate
extends RefCounted

var points := PackedVector3Array()
var kind := RailSegment.Kind.STRAIGHT
## Höhenprofil (leer = linear zwischen Anfang und Ende).
var heights := PackedFloat32Array()
## Knoten, an die angeschlossen wird (-1 = neuer Knoten).
var start_node_id := -1
var end_node_id := -1
## Beim Abzweigen (Weiche): diese Gleise werden bei der Abstandsprüfung ignoriert …
var related_segments: Array[int] = []
## … und von diesem Gleis muss sich der Abzweig bis zum Ende ausreichend entfernen.
var sibling_segment_id := -1
## Geometrischer Fehler, z.B. "Kurve zu eng" ("" = geometrisch möglich).
var error := ""
## Größter Höhenunterschied zwischen Gleis und natürlichem Gelände.
var max_earthwork := 0.0
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
	heights = PackedFloat32Array()
	curve = RailGeometry.make_curve(points)


## Übernimmt ein berechnetes Höhenprofil (siehe [RailProfile]).
func apply_profile(profile: PackedFloat32Array) -> void:
	heights = profile
	points[0].y = profile[0]
	points[3].y = profile[profile.size() - 1]
	points[1].y = lerpf(points[0].y, points[3].y, 1.0 / 3.0)
	points[2].y = lerpf(points[0].y, points[3].y, 2.0 / 3.0)
	curve = RailGeometry.make_curve(points, heights)
