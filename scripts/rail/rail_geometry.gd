@tool
## Geometrie-Hilfen für Gleiskurven.
##
## Der Grundriss eines Gleisstücks ist eine kubische Bézierkurve (4 Kontroll-
## punkte). Die Höhe kommt aus einem separaten Höhenprofil (alle ~2 m ein Wert,
## siehe [RailProfile]). Beides zusammen ergibt eine Godot-[Curve3D] mit
## Bogenlängen-Abtastung – die Grundlage für Modelle und später für Züge.
class_name RailGeometry
extends RefCounted


## Kurve aus Grundriss-Kontrollpunkten und optionalem Höhenprofil.
## Ohne Profil steigt die Höhe linear zwischen Anfang und Ende.
static func make_curve(points: PackedVector3Array, heights := PackedFloat32Array()) -> Curve3D:
	if heights.size() < 2:
		var linear := Curve3D.new()
		linear.up_vector_enabled = false
		linear.bake_interval = 0.25
		linear.add_point(points[0], Vector3.ZERO, points[1] - points[0])
		linear.add_point(points[3], points[2] - points[3], Vector3.ZERO)
		return linear

	var planar := make_planar_curve(points)
	var length := planar.get_baked_length()
	var n := heights.size() - 1
	var ds := length / n
	var curve := Curve3D.new()
	curve.up_vector_enabled = false
	curve.bake_interval = 0.25
	for i in n + 1:
		var position := planar.sample_baked(ds * i, true)
		position.y = heights[i]
		var horizontal := tangent_at(planar, ds * i)
		# Independent vertical handles preserve the solved interval's slope.
		# Averaged slopes caused cubic overshoot above the permitted grade at
		# the transition between a level platform and an inclined approach.
		var incoming := horizontal*ds/3.0
		var outgoing := incoming
		if i>0:
			incoming.y = (heights[i]-heights[i-1])/3.0
		if i<n:
			outgoing.y = (heights[i+1]-heights[i])/3.0
		curve.add_point(position,-incoming if i>0 else Vector3.ZERO,outgoing if i<n else Vector3.ZERO)
	return curve


## Grundriss (Höhe 0) der Bézierkurve.
static func make_planar_curve(points: PackedVector3Array) -> Curve3D:
	var flat_points := PackedVector3Array()
	for p in points:
		flat_points.append(flat(p))
	var curve := Curve3D.new()
	# Rail frames are computed by frame_at, without the engine's redundant
	# up-vector rotation cache (which is unstable on some straight diagonals).
	curve.up_vector_enabled = false
	curve.bake_interval = 0.25
	curve.add_point(flat_points[0], Vector3.ZERO, flat_points[1] - flat_points[0])
	curve.add_point(flat_points[3], flat_points[2] - flat_points[3], Vector3.ZERO)
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


## Größte Steigung entlang der Kurve (Höhenänderung je Meter Grundriss).
static func max_grade(curve: Curve3D) -> float:
	var points := polyline(curve, 2.0)
	var steepest := 0.0
	for i in points.size() - 1:
		var run := flat(points[i + 1] - points[i]).length()
		if run > 0.01:
			steepest = maxf(steepest, absf(points[i + 1].y - points[i].y) / run)
	return steepest


## Punkt der Bézierkurve bei Parameter t (0..1).
static func bezier_point(points: PackedVector3Array, t: float) -> Vector3:
	var u := 1.0 - t
	return points[0] * u * u * u + points[1] * 3.0 * u * u * t + points[2] * 3.0 * u * t * t + points[3] * t * t * t


## Parameter t, an dem der gegebene Anteil der Grundriss-Länge erreicht ist.
static func bezier_param_at_fraction(points: PackedVector3Array, fraction: float) -> float:
	var steps := 200
	var lengths := PackedFloat32Array([0.0])
	var previous := flat(points[0])
	for i in range(1, steps + 1):
		var p := flat(bezier_point(points, float(i) / steps))
		lengths.append(lengths[-1] + previous.distance_to(p))
		previous = p
	var target := clampf(fraction, 0.0, 1.0) * lengths[-1]
	for i in range(1, steps + 1):
		if lengths[i] >= target:
			var span := lengths[i] - lengths[i - 1]
			var local := (target - lengths[i - 1]) / span if span > 0.0 else 0.0
			return (i - 1 + local) / steps
	return 1.0


## Teilt eine Bézierkurve bei t exakt in zwei Bézierkurven (De-Casteljau).
static func split_bezier(points: PackedVector3Array, t: float) -> Array[PackedVector3Array]:
	var p01 := points[0].lerp(points[1], t)
	var p12 := points[1].lerp(points[2], t)
	var p23 := points[2].lerp(points[3], t)
	var p012 := p01.lerp(p12, t)
	var p123 := p12.lerp(p23, t)
	var middle := p012.lerp(p123, t)
	return [
		PackedVector3Array([points[0], p01, p012, middle]),
		PackedVector3Array([middle, p123, p23, points[3]]),
	]


## Tastet ein Höhenprofil zwischen zwei Anteilen neu ab (lineare Interpolation).
static func resample_heights(heights: PackedFloat32Array, from_fraction: float, to_fraction: float,
		count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var n := heights.size() - 1
	for i in count + 1:
		var f := lerpf(from_fraction, to_fraction, float(i) / count) * n
		var index := clampi(floori(f), 0, n - 1)
		result.append(lerpf(heights[index], heights[index + 1], f - index))
	return result


## Vektor ohne Höhenanteil.
static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
