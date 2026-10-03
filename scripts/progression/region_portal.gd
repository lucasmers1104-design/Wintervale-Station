## Tunnelanschluss im Berg (z.B. "Nordtal"): Hier kommen alle Züge her und
## verschwinden wieder. Ein kurzes Gleisstück ragt aus dem Tunnel ins Tal –
## daran schließt der Spieler seine Strecke an.
##
## Für Linien verhält sich das Portal wie ein Ort (Name, Halt, Zähler), hat aber
## keinen Bahnsteig, keine Bewohner und keinen Ausbau. Das Tunnelgleis ist lang
## genug für jeden Zug; sichtbar ist nur der vordere Teil (RailSegmentView),
## Wagen tief im Berg werden ausgeblendet (Train.update_visuals).
class_name RegionPortal
extends RegionStation

## Tunnelgleis im Berg (länger als der längste Zug von ~97 m).
const TUNNEL_TRACK := 125.0
## Gleisstück vor dem Mundloch, an das angeschlossen wird.
const STUB_LENGTH := 14.0
const VISUAL_TUNNEL := 40.0

var portal: TrainPortal
## Gleise des Anschlusses (Tunnel + Stück davor) – nicht abreißbar.
var track_ids: Array[int] = []


func configure_portal(id: int, label: String, mouth: Vector3, yaw: float, owner_region: RegionRailway) -> void:
	region = owner_region
	station_id = id
	station_name = label
	level = 6
	position = mouth
	rotation.y = yaw
	name = "Portal_%s" % label


func _ready() -> void:
	portal = TrainPortal.new()
	portal.portal_name = station_name
	portal.tunnel_length = VISUAL_TUNNEL
	portal.material = region.village.material
	portal.variation_seed = station_id
	add_child(portal)
	stop = PlatformStop.new()
	stop.station_name = station_name
	add_child(stop)
	stop.position = Vector3(0, 0, -TUNNEL_TRACK + 6.0)


func is_portal() -> bool:
	return true


## Tunnelmund, an dem das Gleis aus dem Berg kommt (Weltkoordinaten).
func get_mouth() -> Vector3:
	return global_position


## Offenes Ende des Anschlussgleises (dort setzt der Spieler an).
func get_stub_end() -> Vector3:
	return global_position + global_basis.z * STUB_LENGTH


## Tiefes Ende im Berg (Start- und Endpunkt aller Züge).
func get_deep_end() -> Vector3:
	return global_position - global_basis.z * TUNNEL_TRACK


## Gleis am tiefen Ende des Tunnels.
func get_end_segment() -> RailSegment:
	var node := region.network.find_node_near(get_deep_end(), 3.0)
	if node == null or node.segment_ids.is_empty():
		return null
	return region.network.get_segment(node.segment_ids[0])


func get_end_node_id() -> int:
	var node := region.network.find_node_near(get_deep_end(), 3.0)
	return node.id if node else -1


## Baut Tunnel- und Anschlussgleis, falls sie fehlen (neues Spiel, ältere Reise).
func ensure_track() -> void:
	var network := region.network
	var mouth := get_mouth()
	mouth.y = region.terrain.get_height(mouth.x, mouth.z)
	global_position.y = mouth.y
	var deep := region.network.find_node_near(get_deep_end(), 3.0)
	if deep == null:
		# Ältere Reise mit eigenen Gleisen genau hier: nichts darüber bauen.
		var existing := network.find_segment_near(get_stub_end(), 4.0)
		if existing == null:
			existing = network.find_segment_near(mouth, 4.0)
		if existing and not existing.tunnel:
			push_warning("RegionPortal: %s – an der Tunnelstelle liegt bereits ein Gleis." % station_name)
			return
		# Vom Mundloch in den Berg: der Gleisanfang ist das sichtbare Ende.
		var deep_end := get_deep_end()
		deep_end.y = mouth.y
		var tunnel := _segment(mouth, -1, deep_end, -1, true)
		if tunnel.is_empty():
			return
	var mouth_node := network.find_node_near(mouth, 2.0)
	if mouth_node == null:
		return
	if mouth_node.segment_ids.size() < 2:
		var stub_end := get_stub_end()
		stub_end.y = region.terrain.get_height(stub_end.x, stub_end.z)
		_segment(Vector3.ZERO, mouth_node.id, stub_end, -1, false)
	track_ids.clear()
	for id in mouth_node.segment_ids:
		track_ids.append(id)
	portal.align_to_track(network)


func _segment(start: Vector3, start_node: int, end: Vector3, end_node: int, tunnel: bool) -> Dictionary:
	var network := region.network
	var start_position := start if start_node < 0 else network.get_rail_node(start_node).position
	var start_direction := Vector3.ZERO if start_node < 0 else network.get_outward_direction(start_node)
	var candidate := RailPlanner.plan(start_position, start_direction, end, Vector3.ZERO, false)
	if not candidate.has_geometry():
		push_warning("RegionPortal: Anschluss nicht planbar (%s)." % candidate.error)
		return {}
	candidate.start_node_id = start_node
	candidate.end_node_id = end_node
	candidate.apply_heights(start_position.y, start_position.y)
	var data := network.build_segment_data(candidate)
	if tunnel:
		data["tunnel"] = true
	network.restore_segment(data)
	return data


func get_stops() -> Array[PlatformStop]:
	var result: Array[PlatformStop] = [stop]
	return result


func covers(_point: Vector3) -> bool:
	return false


func clears(_x: float, _z: float) -> bool:
	return false


func set_highlight(_material: Material) -> void:
	pass


func set_dark(_dark: bool) -> void:
	pass


func rebuild() -> void:
	pass


func upgrade_reason() -> String:
	return "Der Tunnel bleibt, wie er ist"


func get_data() -> Dictionary:
	return {"id": station_id, "name": station_name, "passengers": passenger_total, "services": services, "goods": delivered_goods}
