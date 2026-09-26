@tool
## Geometrie-Hilfen für Gleiskurven.
##
## Jedes Gleisstück ist eine kubische Bézierkurve (4 Kontrollpunkte),
## gespeichert als Godot-[Curve3D]. Curve3D liefert Bogenlängen-Abtastung –
## die Grundlage für Modelle und später für fahrende Züge.
class_name RailGeometry
extends RefCounted


static func make_curve(points: PackedVector3Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(points[0], Vector3.ZERO, points[1] - points[0])
	curve.add_point(points[3], points[2] - points[3], Vector3.ZERO)
	return curve


## Fahrtrichtung (normiert) an einer Stelle der Kurve, gemessen in Metern ab Start.
static func tangent_at(curve: Curve3D, offset: float) -> Vector3:
	var length := curve.get_baked_length()
	var step := minf(0.1, length * 0.25)
	var a := curve.sample_baked(clampf(offset - step, 0.0, length), true)
	var b := curve.sample_baked(clampf(offset + step, 0.0, length), true)
	return (b - a).normalized()


## Lokales Koordinatensystem an einer Stelle: X = rechts, Y = oben, -Z = Fahrtrichtung.
static func frame_at(curve: Curve3D, offset: float) -> Transform3D:
	var forward := tangent_at(curve, offset)
	var right := forward.cross(Vector3.UP).normalized()
	var back := -forward
	var up := back.cross(right)
	return Transform3D(Basis(right, up, back), curve.sample_baked(offset, true))


## Gleichmäßig verteilte Rahmen entlang der Kurve (inkl. Anfang und Ende).
static func sample_frames(curve: Curve3D, spacing: float) -> Array[Transform3D]:
	var length := curve.get_baked_length()
	var count := maxi(1, ceili(length / spacing))
	var frames: Array[Transform3D] = []
	for i in count + 1:
		frames.append(frame_at(curve, length * i / count))
	return frames


static func polyline(curve: Curve3D, spacing: float) -> PackedVector3Array:
	var length := curve.get_baked_length()
	var count := maxi(1, ceili(length / spacing))
	var points := PackedVector3Array()
	for i in count + 1:
		points.append(curve.sample_baked(length * i / count, true))
	return points


## Kleinster Kurvenradius (in der Draufsicht), abgeschätzt über Umkreisradien.
static func min_radius(curve: Curve3D) -> float:
	var points := polyline(curve, 1.0)
	var smallest := INF
	for i in range(1, points.size() - 1):
		var a := flat(points[i - 1])
		var b := flat(points[i])
		var c := flat(points[i + 1])
		var area := (b - a).cross(c - a).length() * 0.5
		if area < 0.0001:
			continue
		smallest = minf(smallest, a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (4.0 * area))
	return smallest


## Vektor ohne Höhenanteil.
static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
