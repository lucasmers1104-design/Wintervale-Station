## Baut beim ersten Start die Strecke Nordtal – Wintervale – Südtal.
##
## Nur wenn das Gleisnetz leer ist (neues Spiel). Gebaut wird ausschließlich
## über die normalen Netz-Methoden – das Ergebnis ist also ganz normales,
## speicherbares und veränderbares Gleis.
##
##   Nordtal-Tunnel ─ Einfahrsignal ─ Weiche ═ Gleis 1 / Gleis 2 ═ Weiche ─ Einfahrsignal ─ Südtal-Tunnel
##
## Beide Bahnsteiggleise haben Ausfahrsignale in beide Richtungen, so können
## sich Züge im Bahnhof kreuzen. Alle Signale stehen auf "Zuglenkung".
class_name StarterRailway
extends Node

@export var network: RailNetwork
@export var terrain: LowPolyTerrain
## x-Lage der Bahnsteiggleise (Gleis 1 = durchgehendes Hauptgleis).
@export var main_x := 3.8
@export var side_x := -3.8
## Bahnsteiggleise reichen von north_z bis south_z.
@export var platform_north_z := -33.0
@export var platform_south_z := 15.0
@export var switch_north_z := -70.0
@export var switch_south_z := 52.0
@export var portal_north_z := -85.0
@export var portal_south_z := 85.0
@export var tunnel_length := 40.0

## Knoten und Gleise der gebauten Anlage (für Tests und Portale).
var built := {}


func build_if_empty() -> bool:
	if network.get_segment_count() > 0:
		return false
	build()
	return true


func build() -> void:
	# Bahnsteiggleise exakt eben auf Höhe des Bahnsteigs (Bahnsteigmitte)
	var station_height := terrain.get_height(0.0, (platform_north_z + platform_south_z) * 0.5)
	var track_1 := _segment(Vector3(main_x, station_height, platform_north_z), -1, Vector3.ZERO,
		Vector3(main_x, station_height, platform_south_z), -1, Vector3.ZERO, false, true)
	var track_2 := _segment(Vector3(side_x, station_height, platform_north_z), -1, Vector3.ZERO,
		Vector3(side_x, station_height, platform_south_z), -1, Vector3.ZERO, false, true)
	var p1n := int(track_1["start_node"])
	var p1s := int(track_1["end_node"])
	var p2n := int(track_2["start_node"])
	var p2s := int(track_2["end_node"])

	# Norden: Weiche, Einfahrsignal, Tunnel
	var north_1 := _chain(p1n, Vector3(main_x, 0, switch_north_z))
	var switch_n := int(north_1["end_node"])
	var north_2 := _chain(switch_n, Vector3(main_x, 0, switch_north_z - 8.0))
	var signal_n := int(north_2["end_node"])
	var north_3 := _chain(signal_n, Vector3(main_x, 0, portal_north_z))
	var mouth_n := int(north_3["end_node"])
	_chain(mouth_n, Vector3(main_x, 0, portal_north_z - tunnel_length), true)

	# Süden
	var south_1 := _chain(p1s, Vector3(main_x, 0, switch_south_z))
	var switch_s := int(south_1["end_node"])
	var south_2 := _chain(switch_s, Vector3(main_x, 0, switch_south_z + 8.0))
	var signal_s := int(south_2["end_node"])
	var south_3 := _chain(signal_s, Vector3(main_x, 0, portal_south_z))
	var mouth_s := int(south_3["end_node"])
	_chain(mouth_s, Vector3(main_x, 0, portal_south_z + tunnel_length), true)

	# Weichenverbindungen zu Gleis 2 (S-Kurven)
	var link_n := _segment(Vector3.ZERO, switch_n, Vector3.BACK, Vector3.ZERO, p2n, Vector3.BACK)
	var link_s := _segment(Vector3.ZERO, p2s, Vector3.BACK, Vector3.ZERO, switch_s, Vector3.BACK)

	# Signale (Zuglenkung): Einfahrten und Ausfahrten in beide Richtungen
	_signal(signal_n, int(north_2["id"]))
	_signal(p1n, int(north_1["id"]))
	_signal(p2n, int(link_n["id"]))
	_signal(p1s, int(south_1["id"]))
	_signal(p2s, int(link_s["id"]))
	_signal(signal_s, int(south_2["id"]))

	built = {"track_1": int(track_1["id"]), "track_2": int(track_2["id"]), "switch_north": switch_n,
		"switch_south": switch_s, "link_north": int(link_n["id"]), "link_south": int(link_s["id"])}


## Gleis vom offenen Ende [param node_id] geradeaus bis [param target].
func _chain(node_id: int, target: Vector3, tunnel := false) -> Dictionary:
	return _segment(Vector3.ZERO, node_id, network.get_outward_direction(node_id), target, -1, Vector3.ZERO, tunnel)


## Baut ein Gleis. Mit Knoten-ID wird dort angeschlossen, sonst entsteht ein
## neuer Knoten. Richtungen sind Fahrtrichtungen (Vector3.ZERO = frei).
func _segment(start: Vector3, start_node: int, start_direction: Vector3, end: Vector3, end_node: int,
		end_direction: Vector3, tunnel := false, level := false) -> Dictionary:
	var start_position := start if start_node < 0 else network.get_rail_node(start_node).position
	var end_position := end if end_node < 0 else network.get_rail_node(end_node).position
	var candidate := RailPlanner.plan(start_position, start_direction, end_position, end_direction, false)
	if not candidate.has_geometry():
		push_error("StarterRailway: Gleis nicht planbar (%s)." % candidate.error)
		return {}
	candidate.start_node_id = start_node
	candidate.end_node_id = end_node
	if tunnel or level:
		# Tunnel und Bahnsteiggleise liegen eben
		candidate.apply_heights(start_position.y, start_position.y)
	else:
		var profile := RailProfile.compute(RailGeometry.make_planar_curve(candidate.points), start_position.y,
			end_position.y, start_node >= 0, end_node >= 0, terrain,
			_grade_along(start_node, start_direction), _grade_along(end_node, end_direction))
		if profile["error"] != "":
			push_warning("StarterRailway: Höhenprofil – %s" % profile["error"])
		candidate.apply_profile(profile["heights"])
	var data := network.build_segment_data(candidate)
	if tunnel:
		data["tunnel"] = true
	network.restore_segment(data)
	return data


## Steigung eines bestehenden Gleises am Knoten in Fahrtrichtung (für knickfreie Anschlüsse).
func _grade_along(node_id: int, direction: Vector3) -> float:
	var node := network.get_rail_node(node_id)
	if node == null or direction == Vector3.ZERO:
		return NAN
	for segment_id in node.segment_ids:
		var segment := network.get_segment(segment_id)
		var away := segment.get_direction_away_from(node_id)
		if away.dot(direction) > 0.9:
			return segment.get_grade_away_from(node_id)
		if away.dot(direction) < -0.9:
			return -segment.get_grade_away_from(node_id)
	return NAN


func _signal(node_id: int, segment_id: int) -> void:
	network.add_signal({"id": network.reserve_signal_id(), "node": node_id, "segment": segment_id,
		"mode": RailSignal.Mode.ROUTE})
