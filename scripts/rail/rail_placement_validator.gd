## Prüft, ob ein geplantes Gleisstück gebaut werden darf.
##
## Gibt einen kurzen, verständlichen Grund zurück ("" = gültig).
## Neue Bauregeln kommen einfach als weitere Prüfung hinzu.
class_name RailPlacementValidator
extends RefCounted


static func validate(candidate: RailCandidate, network: RailNetwork, terrain: LowPolyTerrain,
		space: PhysicsDirectSpaceState3D) -> String:
	if candidate.error != "":
		return candidate.error
	if not candidate.has_geometry():
		return "Zu kurz"

	var length := candidate.get_length()
	if length < RailConfig.MIN_LENGTH:
		return "Zu kurz"
	if length > RailConfig.MAX_LENGTH:
		return "Zu lang (max. %d m)" % int(RailConfig.MAX_LENGTH)
	if candidate.kind == RailSegment.Kind.CURVE \
			and RailGeometry.min_radius(candidate.curve) < RailConfig.MIN_RADIUS * 0.95:
		return "Kurve zu eng"
	if absf(candidate.get_end().y - candidate.get_start().y) / length > RailConfig.MAX_GRADE:
		return "Zu steil"

	var samples := RailGeometry.polyline(candidate.curve, 1.0)
	var terrain_reason := _check_terrain(samples, terrain)
	if terrain_reason != "":
		return terrain_reason
	if _overlaps_rails(candidate, samples, network):
		return "Zu nah an einem Gleis"
	if space and _hits_obstacle(candidate, space):
		return "Hindernis im Weg"
	return ""


static func _check_terrain(samples: PackedVector3Array, terrain: LowPolyTerrain) -> String:
	var limit := terrain.get_half_extent() * 0.85
	for p in samples:
		if absf(p.x) > limit or absf(p.z) > limit:
			return "Außerhalb des Baugebiets"
		if terrain.is_in_lake(p.x, p.z):
			return "Nicht auf dem Eis"
		var ground := terrain.get_height(p.x, p.z)
		if ground - p.y > RailConfig.MAX_TERRAIN_ABOVE or p.y - ground > RailConfig.MAX_TERRAIN_BELOW:
			return "Gelände zu uneben"
	return ""


## Prüft den Abstand zu bestehenden Gleisen. Rund um die Knoten, an die
## angeschlossen wird, darf das neue Gleis natürlich nah heranreichen.
static func _overlaps_rails(candidate: RailCandidate, samples: PackedVector3Array, network: RailNetwork) -> bool:
	var joints: Array[Vector3] = []
	for node_id in [candidate.start_node_id, candidate.end_node_id]:
		var node := network.get_rail_node(node_id)
		if node:
			joints.append(node.position)

	var area := AABB(samples[0], Vector3.ZERO)
	for p in samples:
		area = area.expand(p)
	area = area.grow(RailConfig.MIN_TRACK_DISTANCE)

	var min_distance_sq := RailConfig.MIN_TRACK_DISTANCE * RailConfig.MIN_TRACK_DISTANCE
	for segment in network.get_segments():
		if not segment.bounds.intersects(area):
			continue
		for p in samples:
			if _is_near_any(p, joints, 6.0):
				continue
			for q in segment.polyline:
				if p.distance_squared_to(q) < min_distance_sq:
					return true
	return false


## Fährt den Lichtraum des Gleises mit Quadern ab und sucht Objekte (Bäume, Steine, Laternen …).
static func _hits_obstacle(candidate: RailCandidate, space: PhysicsDirectSpaceState3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(RailConfig.CLEARANCE_HALF_WIDTH * 2.0, 1.6, 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = GameDefs.LAYER_OBJECTS
	for frame in RailGeometry.sample_frames(candidate.curve, 2.0):
		query.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 1.2)
		if not space.intersect_shape(query, 1).is_empty():
			return true
	return false


static func _is_near_any(point: Vector3, targets: Array[Vector3], radius: float) -> bool:
	for target in targets:
		if point.distance_to(target) < radius:
			return true
	return false
