## Plant die Form eines neuen Gleisstücks aus Start, Ende und Richtungen.
##
## Fälle:
## - keine Richtung vorgegeben      → Gerade (Winkel rastet in 15°-Schritten ein)
## - Startrichtung vorgegeben       → Kreisbogen, der tangential anschließt
## - nur Endrichtung vorgegeben     → Kreisbogen, der tangential ins Ziel läuft
## - beide Richtungen vorgegeben    → weiche S-/Bogenkurve (Hermite)
## Kreisbögen werden als Bézierkurve angenähert (Fehler < 0,03 %).
class_name RailPlanner
extends RefCounted


## [param start_direction] / [param end_direction] sind Fahrtrichtungen
## (Vector3.ZERO = frei). Höhen werden linear zwischen Start und Ende gelegt.
static func plan(start: Vector3, start_direction: Vector3, end: Vector3, end_direction: Vector3,
		snap_angle := true) -> RailCandidate:
	var candidate := RailCandidate.new()
	if RailGeometry.flat(end - start).length() < 0.5:
		candidate.error = "Zu kurz"
		return candidate

	var has_start := start_direction != Vector3.ZERO
	var has_end := end_direction != Vector3.ZERO
	if not has_start and not has_end:
		var direction := RailGeometry.flat(end - start).normalized()
		if snap_angle:
			direction = _snap_direction(direction)
		var distance := RailGeometry.flat(end - start).length()
		var snapped_end := start + direction * distance
		snapped_end.y = end.y
		_make_straight(candidate, start, snapped_end)
	elif has_start and not has_end:
		_make_arc(candidate, start, start_direction, end)
	elif has_end and not has_start:
		# Rückwärts vom Ziel aus planen und danach umdrehen.
		_make_arc(candidate, end, -end_direction, start)
		if candidate.has_geometry():
			candidate.points.reverse()
	else:
		_make_hermite(candidate, start, start_direction, end, end_direction)

	if candidate.has_geometry():
		candidate.apply_heights(candidate.points[0].y, candidate.points[3].y)
	return candidate


static func _make_straight(candidate: RailCandidate, start: Vector3, end: Vector3) -> void:
	candidate.kind = RailSegment.Kind.STRAIGHT
	candidate.points = PackedVector3Array([start, start.lerp(end, 1.0 / 3.0), start.lerp(end, 2.0 / 3.0), end])


## Kreisbogen, der in [param start_direction] beginnt und durch [param end] geht.
static func _make_arc(candidate: RailCandidate, start: Vector3, start_direction: Vector3, end: Vector3) -> void:
	var direction := RailGeometry.flat(start_direction).normalized()
	var chord := RailGeometry.flat(end - start)
	var phi := direction.signed_angle_to(chord, Vector3.UP)

	# Fast geradeaus: exakte Gerade in Startrichtung
	if absf(phi) < deg_to_rad(0.5):
		var along := chord.dot(direction)
		if along <= 0.5:
			candidate.error = "Zu kurz"
			return
		var straight_end := start + direction * along
		straight_end.y = end.y
		_make_straight(candidate, start, straight_end)
		return

	if absf(phi) >= PI * 0.5:
		candidate.error = "Kurve zu eng"
		return

	# Der Bogen dreht sich um den doppelten Winkel zwischen Richtung und Sehne.
	var turn := 2.0 * phi
	var radius := chord.length() / (2.0 * absf(sin(phi)))
	var end_direction := direction.rotated(Vector3.UP, turn)
	var handle := 4.0 / 3.0 * tan(absf(turn) / 4.0) * radius
	candidate.kind = RailSegment.Kind.CURVE
	candidate.points = PackedVector3Array([start, start + direction * handle, end - end_direction * handle, end])

	if absf(turn) > deg_to_rad(RailConfig.MAX_TURN_DEGREES):
		candidate.error = "Kurve zu stark (max. %d°)" % int(RailConfig.MAX_TURN_DEGREES)
	elif radius < RailConfig.MIN_RADIUS:
		candidate.error = "Kurve zu eng"


## Weiche Verbindung zweier fester Richtungen (z.B. Lückenschluss zwischen zwei Gleisenden).
static func _make_hermite(candidate: RailCandidate, start: Vector3, start_direction: Vector3,
		end: Vector3, end_direction: Vector3) -> void:
	var sd := RailGeometry.flat(start_direction).normalized()
	var ed := RailGeometry.flat(end_direction).normalized()
	var chord := RailGeometry.flat(end - start)
	if chord.dot(sd) <= 0.0 or chord.dot(ed) <= 0.0:
		candidate.error = "Richtung passt nicht"
		return

	var lateral := (chord - sd * chord.dot(sd)).length()
	if sd.dot(ed) > 0.9999 and lateral < 0.05:
		_make_straight(candidate, start, end)
		return

	if rad_to_deg(sd.angle_to(ed)) > RailConfig.MAX_TURN_DEGREES:
		candidate.error = "Kurve zu stark (max. %d°)" % int(RailConfig.MAX_TURN_DEGREES)
		return

	var handle := chord.length() * 0.4
	candidate.kind = RailSegment.Kind.CURVE
	candidate.points = PackedVector3Array([start, start + sd * handle, end - ed * handle, end])


static func _snap_direction(direction: Vector3) -> Vector3:
	var step := deg_to_rad(RailConfig.ANGLE_SNAP_DEGREES)
	var angle := roundf(atan2(direction.x, direction.z) / step) * step
	return Vector3(sin(angle), 0.0, cos(angle))
