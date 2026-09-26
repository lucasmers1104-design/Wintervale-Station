## Prüft, ob ein geplantes Gleisstück gebaut werden darf.
##
## Gibt einen kurzen, verständlichen Grund zurück ("" = gültig).
## Neue Bauregeln kommen einfach als weitere Prüfung hinzu.
class_name RailPlacementValidator
extends RefCounted

## Rund um Anschlusspunkte dürfen Gleise einander natürlich nahe kommen.
const JOINT_RADIUS := 6.0


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
	if RailGeometry.max_grade(candidate.curve) > RailConfig.MAX_GRADE * 1.15:
		return "Zu steil (max. %d %%)" % roundi(RailConfig.MAX_GRADE * 100.0)

	var samples := RailGeometry.polyline(candidate.curve, 1.0)
	var terrain_reason := _check_terrain(samples, terrain)
	if terrain_reason != "":
		return terrain_reason

	var joints := _joint_positions(candidate, network)
	if _overlaps_rails(candidate, samples, network, joints):
		return "Zu nah an einem Gleis"
	if _conflicts_in_height(samples, network, joints):
		return "Höhenunterschied zum Nachbargleis zu groß"
	if candidate.sibling_segment_id >= 0:
		var sibling := network.get_segment(candidate.sibling_segment_id)
		if sibling and sibling.distance_to_point(candidate.get_end()) < RailConfig.MIN_TRACK_DISTANCE:
			return "Abzweig zu kurz – weiter ziehen"
	if space and _hits_obstacle(candidate, space):
		return "Hindernis im Weg"
	return ""


static func _check_terrain(samples: PackedVector3Array, terrain: LowPolyTerrain) -> String:
	var limit := terrain.get_half_extent() * 0.85
	for p in samples:
		if absf(p.x) > limit or absf(p.z) > limit:
			return "Außerhalb des Baugebiets"
		if Vector2(p.x, p.z).distance_to(terrain.lake_center) < terrain.lake_radius + RailConfig.LAKE_MARGIN:
			return "Zu nah am See"
		if absf(p.y - terrain.get_base_height(p.x, p.z)) > RailConfig.MAX_EARTHWORK:
			return "Gelände zu steil (zu viel Erdarbeit)"
	return ""


## Anschlusspunkte des Kandidaten (bestehende Knoten oder Abzweigstelle).
static func _joint_positions(candidate: RailCandidate, network: RailNetwork) -> Array[Vector3]:
	var joints: Array[Vector3] = []
	for node_id in [candidate.start_node_id, candidate.end_node_id]:
		var node := network.get_rail_node(node_id)
		if node:
			joints.append(node.position)
	if not candidate.related_segments.is_empty():
		joints.append(candidate.get_start())
	return joints


## Prüft den Abstand zu bestehenden Gleisen. Rund um die Anschlusspunkte und
## zu den Gleisen, von denen abgezweigt wird, darf das Gleis nah heranreichen.
static func _overlaps_rails(candidate: RailCandidate, samples: PackedVector3Array, network: RailNetwork,
		joints: Array[Vector3]) -> bool:
	var area := _area(samples, RailConfig.MIN_TRACK_DISTANCE)
	var min_distance_sq := RailConfig.MIN_TRACK_DISTANCE * RailConfig.MIN_TRACK_DISTANCE
	for segment in network.get_segments():
		if candidate.related_segments.has(segment.id) or not segment.bounds.intersects(area):
			continue
		for p in samples:
			if _is_near_any(p, joints, JOINT_RADIUS):
				continue
			for q in segment.polyline:
				if p.distance_squared_to(q) < min_distance_sq:
					return true
	return false


## Liegen zwei Gleise nah beieinander, dürfen sich ihre Höhen kaum
## unterscheiden – sonst würde die Geländeanpassung das Nachbargleis
## verschütten oder freilegen.
static func _conflicts_in_height(samples: PackedVector3Array, network: RailNetwork, joints: Array[Vector3]) -> bool:
	var reach := TerrainDeformer.CORE_HALF_WIDTH * 2.0 + 2.0
	var area := _area(samples, reach)
	for segment in network.get_segments():
		if not segment.bounds.intersects(area):
			continue
		for i in range(0, samples.size(), 2):
			var p := samples[i]
			if _is_near_any(p, joints, JOINT_RADIUS):
				continue
			var closest := segment.closest_point(p)
			var distance := RailGeometry.flat(closest - p).length()
			if distance >= reach:
				continue
			var allowed := RailConfig.NEIGHBOR_HEIGHT_TOLERANCE \
				+ maxf(0.0, distance - TerrainDeformer.CORE_HALF_WIDTH * 2.0) * 0.5
			if absf(closest.y - p.y) > allowed:
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


static func _area(samples: PackedVector3Array, margin: float) -> AABB:
	var area := AABB(samples[0], Vector3.ZERO)
	for p in samples:
		area = area.expand(p)
	return area.grow(margin)


static func _is_near_any(point: Vector3, targets: Array[Vector3], radius: float) -> bool:
	for target in targets:
		if point.distance_to(target) < radius:
			return true
	return false
