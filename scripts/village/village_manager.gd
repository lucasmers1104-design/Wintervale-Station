## Das Dorf: verwaltet alle gebauten Häuser, Wege und Objekte.
##
## Aufgaben:
## - Objekte anlegen und entfernen (Bauwerkzeuge rufen [method place] und
##   [method remove], Undo/Redo inklusive) und speichern/laden.
## - Platzierung prüfen ([method check_placement]): Gleise, Bahnsteig, andere
##   Objekte, See, Hang, Fußwege der Bewohner.
## - Gelände unter Häusern und dem Dorfplatz einebnen (wie bei Gleisen über
##   Korridore im [TerrainDeformer] – nie gespeichert, immer abgeleitet).
## - Das Fußwegenetz der Bewohner um Wege und Haustüren erweitern ([WalkGraph]).
## - Bewohner zuweisen: Jedes Haus bekommt eine Familie ([VillageResidents]),
##   bekannte Bewohner ohne Zuhause ziehen bevorzugt in neue Häuser ein.
## - Nachts alle Lichter warm einschalten.
class_name VillageManager
extends Node3D

signal changed
## Eine Baustelle kam hinzu, ging voran oder wurde fertig (für das Notizbuch).
signal projects_changed
## Ein Haus ist fertig gebaut.
signal construction_finished(house: VillageHouse)
## Eine Familie zieht ein (Bewohner kommen mit dem Zug an).
signal residents_arriving(home_name: String, count: int)

const SAVE_ID := "village"
const GROUP := &"village_manager"
## Korridor-IDs für eingeebnetes Gelände (weit weg von Gleis-IDs).
const CORRIDOR_BASE := 7000000
## Höchstens so viele erfundene Bewohner (Leistung, gemütliches Dorf statt Stadt).
const MAX_GENERATED_RESIDENTS := 24
## Gebaut wird tagsüber (Spielstunden).
const WORK_START := 6.0
const WORK_END := 20.0
## Höhenunterschied, den ein Haus noch einebnen darf.
const MAX_HOUSE_SLOPE := 3.0

@export var terrain: LowPolyTerrain
@export var walk_graph: WalkGraph
@export var npc_director: NpcDirector
@export var nature: PropScatter
@export var rail_network: RailNetwork
@export var material: Material

## ID → Objekt ([VillageHouse], [VillagePath] oder [VillageObject] – gleiche Schnittstelle).
var _objects: Dictionary = {}
var _residents: Dictionary[int, Array] = {}
## Ganzer Haushalt je Haus (auch Mitglieder, die erst später nachziehen).
var _households: Dictionary[int, Array] = {}
## Zuletzt fertiggestellte Häuser: [{"home", "item", "day"}], neueste zuerst.
var _finished_log: Array[Dictionary] = []
## Objekte, die mit Geld und Material bezahlt wurden (nur diese werden beim Abriss erstattet).
var _paid: Dictionary[int, bool] = {}
var _next_id := 1
var _dark := false
var _network_dirty := false
var _project_timer := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GameDefs.GROUP_SAVEABLE)
	if not Engine.is_editor_hint():
		_dark = WorldClock.is_dark()
		WorldClock.darkness_changed.connect(_on_darkness_changed)
		WorldClock.day_changed.connect(_on_day_changed)
	if terrain:
		terrain.terrain_changed.connect(_on_terrain_changed)


# --- Bauprojekte ------------------------------------------------------------------------

## Baustellen gehen tagsüber voran; dabei wird das reservierte Material verbaut.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or WorldClock.paused:
		return
	var hours := WorldClock.seconds_to_hours(delta * WorldClock.time_scale)
	var working := is_work_time()
	var any := false
	for house in get_projects():
		any = true
		var progress := house.build_progress
		if working:
			var duration := 1.0 if house.organic_growth else VillageCatalog.get_build_hours(house.item_id)
			progress += hours / maxf(duration, 0.1)
		advance_project(house, progress, working)
	if any:
		_project_timer -= delta
		if _project_timer <= 0.0:
			_project_timer = 1.0
			projects_changed.emit()


## Wird gerade gebaut (06–20 Uhr)?
static func is_work_time() -> bool:
	return WorldClock.time_of_day >= WORK_START and WorldClock.time_of_day < WORK_END


## Setzt den Baufortschritt eines Hauses und verbaut das dazu nötige Material
## (bis 90 % Fortschritt ist alles verbaut, danach folgt der Innenausbau).
func advance_project(house: VillageHouse, progress: float, working := true) -> void:
	var key := cost_key(house.object_id)
	var cost := VillageCatalog.get_cost(house.item_id)
	var share := clampf(progress / 0.9, 0.0, 1.0)
	for goods_id: String in cost:
		if goods_id == "money":
			continue
		var remaining := int(Economy.get_reservation(key).get(goods_id, 0))
		var used := int(cost[goods_id]) - remaining
		var target := floori(int(cost[goods_id]) * share)
		if target > used and Economy.has_reservation(key):
			Economy.consume(key, goods_id, target - used)
	house.set_build_progress(progress, Economy.get_reservation(key), working)


## Häuser im Bau.
func get_projects() -> Array[VillageHouse]:
	var list: Array[VillageHouse] = []
	for obj in _objects.values():
		if obj is VillageHouse and not (obj as VillageHouse).is_finished():
			list.append(obj)
	return list


## Noch verbleibende Bauzeit in Spielstunden (nur Arbeitsstunden).
func get_project_hours_left(house: VillageHouse) -> float:
	return (1.0 - house.build_progress) * VillageCatalog.get_build_hours(house.item_id)


func get_finished_log() -> Array[Dictionary]:
	return _finished_log


func _on_house_finished(house: VillageHouse) -> void:
	Economy.finish_build(cost_key(house.object_id))
	_finished_log.push_front({"home": house.home_name, "item": house.item_id, "day": WorldClock.day})
	if _finished_log.size() > 8:
		_finished_log.resize(8)
	_move_in(house, true)
	if not Engine.is_editor_hint():
		Events.notification_requested.emit("%s ist fertig – Familie %s ist unterwegs" % [
			VillageCatalog.get_label(house.item_id), house.home_name])
	construction_finished.emit(house)
	projects_changed.emit()
	changed.emit()


# --- Objekte ------------------------------------------------------------------------

func get_objects() -> Array[Node3D]:
	var list: Array[Node3D] = []
	list.assign(_objects.values())
	return list


func get_object(id: int):
	return _objects.get(id)


func get_object_count(kind := "") -> int:
	if kind == "":
		return _objects.size()
	var count := 0
	for obj in _objects.values():
		if VillageCatalog.get_kind(obj.item_id) == kind:
			count += 1
	return count


func get_houses() -> Array[VillageHouse]:
	var houses: Array[VillageHouse] = []
	for obj in _objects.values():
		if obj is VillageHouse:
			houses.append(obj)
	return houses


func is_empty() -> bool:
	return _objects.is_empty()


func reserve_id() -> int:
	_next_id += 1
	return _next_id - 1


## Vervollständigt die Daten eines neuen Objekts (ID, Höhe, Familienname).
func prepare(item_id: String, position: Vector3, angle: float, variant := 0, end := Vector3.INF) -> Dictionary:
	var data := {"id": reserve_id(), "item": item_id, "rot": angle, "variant": variant}
	var kind := VillageCatalog.get_kind(item_id)
	var pos := position
	if kind == "house" or kind == "plaza":
		pos.y = level_height(VillageFootprint.for_item(item_id, position, angle, variant))
	else:
		pos.y = _ground(pos)
	data["pos"] = SaveUtils.vec3_to_array(pos)
	if end != Vector3.INF:
		data["end"] = SaveUtils.vec3_to_array(Vector3(end.x, _ground(end), end.z))
	if kind == "house":
		data["seed"] = randi()
		data["home"] = _new_home_name(int(data["seed"]))
		var progress := RegionProgression.find(get_tree())
		if progress:
			# Jedes Haus gehört zum nächsten Haltepunkt – dort kommt die Familie an.
			var station := progress.region.nearest_station(pos)
			if station:
				data["region_station"] = station.station_id
	return data


## Legt ein Objekt aus seinen Daten an. Rückgabe: das Objekt.
func place(data: Dictionary):
	var id := int(data["id"])
	if _objects.has(id):
		remove(id)
	_next_id = maxi(_next_id, id + 1)
	var item_id := String(data["item"])
	var obj
	match VillageCatalog.get_kind(item_id):
		"house":
			var house := VillageHouse.new()
			house.configure(data, material)
			obj = house
		"path":
			var path := VillagePath.new()
			path.configure(data, terrain)
			obj = path
		_:
			var thing := VillageObject.new()
			thing.configure(data, material)
			obj = thing
	_objects[id] = obj
	if bool(data.get("paid", false)):
		_paid[id] = true
	else:
		_paid.erase(id)
	add_child(obj)
	if obj.has_method("set_dark") and _dark:
		obj.set_dark(true)
	_level_terrain(obj)
	if obj is VillagePath:
		_rebuild_paths_near(obj as VillagePath)
	if obj is VillageHouse:
		var house := obj as VillageHouse
		var progress := RegionProgression.find(get_tree())
		if progress and house.region_station_id>0:
			var station := progress.region.station_by_id(house.region_station_id)
			if station and not station.house_ids.has(id):
				station.house_ids.append(id)
		house.finished.connect(_on_house_finished)
		if house.is_finished():
			_move_in(house, false)
		else:
			projects_changed.emit()
	_after_change(obj)
	return obj


## Bauen mit Kosten (Bauwerkzeug, Rückgängig/Wiederholen): Geld wird bezahlt,
## Material für Häuser reserviert (Baustelle) bzw. sofort verbaut. Nur Daten mit
## "paid" werden berechnet (das Startdorf war ein Geschenk). Rückgabe: das Objekt
## oder null, wenn etwas fehlt (dann wird nichts gebaut).
func build(data: Dictionary):
	if bool(data.get("paid", false)):
		var item_id := String(data["item"])
		var key := cost_key(int(data["id"]))
		var cost := VillageCatalog.get_cost(item_id, _data_length(data))
		var label := "Bau: %s" % VillageCatalog.get_label(item_id)
		var construction := VillageCatalog.get_kind(item_id) == "house" and float(data.get("build", 1.0)) < 1.0
		var ok := Economy.charge_build(key, cost, label) if construction else Economy.charge_instant(key, cost, label)
		if not ok:
			if not Engine.is_editor_hint():
				Events.notification_requested.emit(Economy.describe_missing(cost))
			return null
	return place(data)


## Abriss (Entfernen-Werkzeug, Rückgängig): Bezahlte Objekte geben Geld und
## Material vollständig zurück. Rückgabe: die Daten (mit "paid") für Rückgängig.
func demolish(id: int) -> Dictionary:
	var obj = _objects.get(id)
	if obj == null:
		return {}
	var data := get_object_data(id)
	if bool(data.get("paid", false)):
		var item_id := String(data["item"])
		Economy.refund_build(cost_key(id), VillageCatalog.get_cost(item_id, _data_length(data)),
			"Abriss: %s" % VillageCatalog.get_label(item_id))
	remove(id)
	return data


## Daten eines Objekts inkl. "paid" (wurde es bezahlt?).
func get_object_data(id: int) -> Dictionary:
	var obj = _objects.get(id)
	if obj == null:
		return {}
	var data: Dictionary = obj.get_data()
	if _paid.has(id):
		data["paid"] = true
	return data


## Schlüssel der Reservierung im Materiallager.
static func cost_key(id: int) -> String:
	return "village:%d" % id


func _data_length(data: Dictionary) -> float:
	if not data.has("end"):
		return 0.0
	var a := SaveUtils.array_to_vec3(data.get("pos"))
	var b := SaveUtils.array_to_vec3(data.get("end"))
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## Entfernt ein Objekt. Rückgabe: seine Daten (für Undo) oder {}.
func remove(id: int) -> Dictionary:
	var obj = _objects.get(id)
	if obj == null:
		return {}
	var data: Dictionary = obj.get_data()
	if obj is VillageHouse:
		_move_out(obj as VillageHouse)
	_unlevel_terrain(id)
	_objects.erase(id)
	_paid.erase(id)
	var footprint: Dictionary = obj.get_footprint()
	remove_child(obj)
	obj.queue_free()
	if obj is VillagePath:
		_rebuild_paths_near(obj as VillagePath)
	_after_change(null, footprint)
	return data


func clear_all() -> void:
	for id in _objects.keys():
		remove(id)
	_next_id = 1


## Objekt unter einem Punkt (kleinere Objekte zuerst, Wege zuletzt).
func pick(point: Vector3):
	var best = null
	var best_area := INF
	for obj in _objects.values():
		var fp: Dictionary = obj.get_footprint()
		var hit := false
		if obj is VillagePath:
			hit = (obj as VillagePath).distance_to(point) < (obj as VillagePath).get_width() * 0.5 + 0.2
		else:
			hit = VillageFootprint.contains(fp, Vector2(point.x, point.z), 0.25)
		if not hit:
			continue
		var half: Vector2 = fp["half"]
		var area := half.x * half.y + (10000.0 if obj is VillagePath else 0.0)
		if area < best_area:
			best_area = area
			best = obj
	return best


# --- Platzierung prüfen ------------------------------------------------------------------

## Leerer Text = darf gebaut werden, sonst der Grund.
func check_placement(item_id: String, position: Vector3, angle: float, variant := 0, end := Vector3.INF, organic := false) -> String:
	var progress := RegionProgression.find(get_tree()) if is_inside_tree() else null
	if progress and not organic and progress.epoch < EpochCatalog.item_epoch(item_id):
		return "Freigeschaltet ab Epoche %d" % EpochCatalog.item_epoch(item_id)
	if progress and not organic and VillageCatalog.get_kind(item_id) == "house" and progress.region.stations.is_empty():
		return "Zuerst einen Haltepunkt bauen – neue Familien kommen mit dem Zug"
	var kind := VillageCatalog.get_kind(item_id)
	var fp := VillageFootprint.for_item(item_id, position, angle, variant, end)
	if VillageCatalog.is_line(item_id):
		var length := Vector2(position.x, position.z).distance_to(Vector2(end.x, end.z))
		if length < 1.0:
			return "Zu kurz"
		if length > float(VillageCatalog.get_item(item_id).get("max_length", 20.0)) + 0.01:
			return "Zu lang (höchstens %d m)" % int(VillageCatalog.get_item(item_id)["max_length"])
	var half_extent := terrain.get_half_extent() * 0.88 if terrain else 1000.0
	var heights: Array[float] = []
	var yards: Array = []
	if is_inside_tree():
		yards = get_tree().get_nodes_in_group(FreightYard.GROUP)
	for p in VillageFootprint.samples(fp, 1.5):
		if absf(p.x) > half_extent or absf(p.y) > half_extent:
			return "Außerhalb des Gebiets"
		for yard: FreightYard in yards:
			if yard.covers(p.x, p.y):
				return "Gehört zum Güterbahnhof"
		if progress:
			for station in progress.region.stations:
				if station.clears(p.x,p.y) and not (kind=="path" and station.permits_path(Vector3(p.x,0,p.y))):
					return "Platz für den Bahnhof freihalten"
		if terrain and terrain.is_in_lake(p.x, p.y):
			return "Im zugefrorenen See"
		if rail_network and rail_network.find_segment_near(Vector3(p.x, 0, p.y), 3.0 if kind == "house" else 2.2):
			return "Zu nah am Gleis"
		heights.append(terrain.get_base_height(p.x, p.y) if terrain else 0.0)
	var slope: float = heights.max() - heights.min() if not heights.is_empty() else 0.0
	if kind == "house" or kind == "plaza":
		if slope > MAX_HOUSE_SLOPE:
			return "Zu steil"
	elif kind == "path":
		var length := maxf(Vector2(position.x, position.z).distance_to(Vector2(end.x, end.z)), 1.0)
		if absf(_ground(end) - _ground(position)) / length > 0.45:
			return "Zu steil"
	elif slope > 1.6:
		return "Zu steil"
	# Andere Dorf-Objekte
	var solid := kind == "house" or kind == "plaza" or bool(VillageCatalog.get_item(item_id).get("solid", false)) \
		or kind == "line"
	for obj in _objects.values():
		var other_kind := VillageCatalog.get_kind(obj.item_id)
		var other_fp: Dictionary = obj.get_footprint()
		if kind == "path":
			if (other_kind == "house" or other_kind == "plaza") and VillageFootprint.crosses_segment(other_fp,
					Vector2(position.x, position.z), Vector2(end.x, end.z), -0.4):
				return "Weg führt durch %s" % VillageCatalog.get_label(obj.item_id)
			continue
		if other_kind == "path":
			var other_path := obj as VillagePath
			if (kind == "house" or kind == "plaza") and VillageFootprint.crosses_segment(fp,
					Vector2(other_path.start_point.x, other_path.start_point.z), Vector2(other_path.end_point.x, other_path.end_point.z), -0.1):
				return "Steht auf einem Weg"
			continue
		var other_solid: bool = obj.is_solid() or other_kind == "house" or other_kind == "plaza"
		if (solid or other_kind == "house" or other_kind == "plaza") and other_solid \
				and VillageFootprint.overlaps(fp, other_fp, -0.05):
			return "Kein Platz (%s)" % VillageCatalog.get_label(obj.item_id)
		if (kind == "house" or kind == "plaza") and VillageFootprint.overlaps(fp, other_fp, -0.05):
			return "Kein Platz (%s)" % VillageCatalog.get_label(obj.item_id)
	# Bahnsteig, Bänke, Laternen und andere feste Objekte des Bahnhofs
	if kind != "path" and _hits_station_objects(fp):
		return "Kein Platz (Bahnhof)"
	# Häuser dürfen die festen Fußwege der Bewohner nicht versperren
	if (kind == "house" or kind == "plaza" or kind == "line") and walk_graph:
		var base := walk_graph.get_base_points()
		for link in walk_graph.links:
			var ends := link.split("-")
			if ends.size() == 2 and base.has(ends[0]) and base.has(ends[1]):
				var a: Vector3 = base[ends[0]]
				var b: Vector3 = base[ends[1]]
				if VillageFootprint.crosses_segment(fp, Vector2(a.x, a.z), Vector2(b.x, b.z), -0.2):
					return "Versperrt einen Fußweg"
	return ""


func _hits_station_objects(fp: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return false
	var shape := BoxShape3D.new()
	var half: Vector2 = fp["half"]
	shape.size = Vector3(half.x * 2.0 - 0.1, 3.0, half.y * 2.0 - 0.1)
	var center: Vector2 = fp["center"]
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, fp["angle"]), Vector3(center.x, _ground(Vector3(center.x, 0, center.y)) + 1.6, center.y))
	query.collision_mask = GameDefs.LAYER_OBJECTS
	for hit in space.intersect_shape(query, 16):
		var collider: Node = hit["collider"]
		if collider and not is_ancestor_of(collider):
			return true
	return false


# --- Wege ------------------------------------------------------------------------------

## Fängt einen Wegpunkt an bestehenden Wegen: an einem Endpunkt oder mitten auf dem Weg.
func snap_path_point(point: Vector3, radius := 1.6) -> Vector3:
	var best := point
	var best_distance := radius
	var progress := RegionProgression.find(get_tree()) if is_inside_tree() else null
	if progress:
		for station in progress.region.stations:
			for entrance in station.path_entrances():
				var distance := Vector2(point.x,point.z).distance_to(Vector2(entrance.x,entrance.z))
				if distance<best_distance:
					best_distance = distance
					best = entrance
	for obj in _objects.values():
		if not obj is VillagePath:
			continue
		var path := obj as VillagePath
		for end in [path.start_point, path.end_point]:
			var d := Vector2(point.x, point.z).distance_to(Vector2(end.x, end.z))
			if d < best_distance:
				best_distance = d
				best = end
	if best != point:
		return best
	for obj in _objects.values():
		if obj is VillagePath:
			var path := obj as VillagePath
			var d := path.distance_to(point)
			if d < path.get_width() * 0.5 + 0.3:
				var p := Geometry2D.get_closest_point_to_segment(Vector2(point.x, point.z),
					Vector2(path.start_point.x, path.start_point.z), Vector2(path.end_point.x, path.end_point.z))
				return Vector3(p.x, point.y, p.y)
	return point


## Liegt der Punkt auf einem gebauten Weg (für Schrittgeräusche)?
func is_on_path(point: Vector3) -> bool:
	for obj in _objects.values():
		if obj is VillagePath and (obj as VillagePath).distance_to(point) < (obj as VillagePath).get_width() * 0.5:
			return true
		if obj is VillageObject and (obj as VillageObject).item_id == "plaza" \
				and Vector2(point.x - obj.position.x, point.z - obj.position.z).length() < 6.0:
			return true
	return false


## Liegt der Punkt auf einem anderen Weg als [param exclude_id] (oder auf dem Dorfplatz)?
## Die Schneewälle an Wegrändern enden dort, statt in die Kreuzung zu ragen.
func is_on_other_path(point: Vector3, exclude_id: int, margin := 0.3) -> bool:
	for obj in _objects.values():
		if obj is VillagePath and (obj as VillagePath).object_id != exclude_id \
				and (obj as VillagePath).distance_to(point) < (obj as VillagePath).get_width() * 0.5 + margin:
			return true
		if obj is VillageObject and (obj as VillageObject).item_id == "plaza" \
				and Vector2(point.x - obj.position.x, point.z - obj.position.z).length() < 6.2:
			return true
	return false


## Wie weit reicht an [param point] ein anderer, breiterer Weg (oder der Dorfplatz) noch?
## Rückgabe: Abstand bis zu dessen Rand (> 0 = der Punkt liegt darauf), sonst -1.
func wider_surface_depth(point: Vector3, exclude_id: int, width: float) -> float:
	var best := -1.0
	for obj in _objects.values():
		if obj is VillagePath and (obj as VillagePath).object_id != exclude_id and (obj as VillagePath).get_width() > width + 0.01:
			best = maxf(best, (obj as VillagePath).get_width() * 0.5 - (obj as VillagePath).distance_to(point))
		elif obj is VillageObject and (obj as VillageObject).item_id == "plaza":
			best = maxf(best, 6.0 - Vector2(point.x - obj.position.x, point.z - obj.position.z).length())
	return best if best > 0.0 else -1.0


## Wege, die [param path] berühren, neu bauen (ihre Schneewälle an der Kreuzung anpassen).
func _rebuild_paths_near(path: VillagePath) -> void:
	for obj in _objects.values():
		if obj is VillagePath and obj != path and obj.is_inside_tree():
			var other := obj as VillagePath
			var reach := other.get_width() * 0.5 + path.get_width() * 0.5 + 1.0
			if path.distance_to(other.start_point) < reach or path.distance_to(other.end_point) < reach \
					or other.distance_to(path.start_point) < reach or other.distance_to(path.end_point) < reach:
				other.rebuild()


## Nächster Weg und Abstand dazu (für die automatische Ausrichtung von Häusern).
func nearest_path_point(point: Vector3, max_distance := 14.0) -> Vector3:
	var best := Vector3.INF
	var best_distance := max_distance
	for obj in _objects.values():
		if obj is VillagePath:
			var path := obj as VillagePath
			var p := Geometry2D.get_closest_point_to_segment(Vector2(point.x, point.z),
				Vector2(path.start_point.x, path.start_point.z), Vector2(path.end_point.x, path.end_point.z))
			var d := p.distance_to(Vector2(point.x, point.z))
			if d < best_distance:
				best_distance = d
				best = Vector3(p.x, point.y, p.y)
	return best


## Kann man ohne Hindernis von a nach b laufen (keine Häuser, Gleise, See)?
func is_walkable(a: Vector3, b: Vector3) -> bool:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	for obj in _objects.values():
		if obj is VillagePath:
			continue
		if (obj is VillageHouse or obj.is_solid()) and VillageFootprint.crosses_segment(obj.get_footprint(), a2, b2, 0.15):
			return false
	var steps := maxi(1, ceili(a2.distance_to(b2) / 1.0))
	for i in steps + 1:
		var p := a2.lerp(b2, float(i) / steps)
		if terrain and terrain.is_in_lake(p.x, p.y):
			return false
		if rail_network and rail_network.find_segment_near(Vector3(p.x, 0, p.y), 2.0):
			return false
	return true


# --- Gelände --------------------------------------------------------------------------

## Höhe, auf die eine Grundfläche eingeebnet wird (Mittel der natürlichen Höhen).
func level_height(fp: Dictionary) -> float:
	if terrain == null:
		return 0.0
	var total := 0.0
	var samples := VillageFootprint.samples(fp, 1.5)
	for p in samples:
		total += terrain.get_base_height(p.x, p.y)
	return total / maxf(samples.size(), 1.0)


func _level_terrain(obj) -> void:
	var kind := VillageCatalog.get_kind(obj.item_id)
	if terrain == null or (kind != "house" and kind != "plaza"):
		return
	var fp: Dictionary = obj.get_footprint()
	var half: Vector2 = fp["half"]
	var y: float = obj.position.y + TerrainDeformer.GROUND_OFFSET
	# Parallele Korridorlinien entlang der längeren Seite decken die Fläche ab
	var long_x := half.x >= half.y
	var along := half.x if long_x else half.y
	var across := half.y if long_x else half.x
	var inset := TerrainDeformer.CORE_HALF_WIDTH - 0.6
	var lines := maxi(1, ceili((across * 2.0 - inset * 2.0) / 3.5) + 1)
	for k in lines:
		var offset := lerpf(-across + inset, across - inset, 0.5 if lines == 1 else float(k) / (lines - 1))
		var a := Vector2(-along + inset, offset) if long_x else Vector2(offset, -along + inset)
		var b := Vector2(along - inset, offset) if long_x else Vector2(offset, along - inset)
		if a.distance_to(b) < 0.1:
			b += Vector2(0.1, 0.0)
		var center: Vector2 = fp["center"]
		var wa := center + a.rotated(-fp["angle"])
		var wb := center + b.rotated(-fp["angle"])
		terrain.set_track_corridor(CORRIDOR_BASE + obj.object_id * 8 + k,
			PackedVector3Array([Vector3(wa.x, y, wa.y), Vector3(wb.x, y, wb.y)]))


func _unlevel_terrain(id: int) -> void:
	if terrain == null:
		return
	for k in 8:
		terrain.remove_track_corridor(CORRIDOR_BASE + id * 8 + k)


func _ground(point: Vector3) -> float:
	return terrain.get_height(point.x, point.z) if terrain else 0.0


## Gelände hat sich geändert (Gleisbau, Haus): kleine Objekte wieder auf den Boden setzen.
func _on_terrain_changed(region: Rect2) -> void:
	var area := region.grow(1.0)
	for obj in _objects.values():
		if obj is VillageObject:
			var thing := obj as VillageObject
			var kind := VillageCatalog.get_kind(thing.item_id)
			if kind == "plaza" or not area.has_point(Vector2(thing.position.x, thing.position.z)):
				continue
			var ground := _ground(thing.position)
			if absf(ground - thing.position.y) > 0.01:
				thing.position.y = ground
				if kind == "line" and thing.end_point != Vector3.INF:
					thing.end_point.y = _ground(thing.end_point)
					thing.transform = Transform3D(VillageObject.line_basis(thing.position, thing.end_point), thing.position)


# --- Bewohner --------------------------------------------------------------------------

func get_residents(house: VillageHouse) -> Array:
	return _residents.get(house.object_id, [])


func get_generated_resident_count() -> int:
	var count := 0
	for list: Array in _residents.values():
		count += list.size()
	return count


## Haushaltsgröße eines Hauses (aus Hausgröße und Startwert: 1–4 Personen).
static func household_size(house: VillageHouse) -> int:
	return clampi(house.get_capacity() + posmod(house.resident_seed, 2), 1, 4)


## Der ganze Haushalt (Steckbriefe, zwischengespeichert – gleicher Startwert = gleiche Familie).
func get_household(house: VillageHouse) -> Array:
	if not _households.has(house.object_id):
		var list: Array = []
		list.assign(VillageResidents.generate(house.home_name, house.resident_seed, household_size(house)))
		for profile: NpcProfile in list:
			_assign_favourite_way(profile, house)
		_households[house.object_id] = list
	return _households[house.object_id]


## An welchem Tag ein Haushaltsmitglied einzieht: die ersten beiden sofort,
## weitere Angehörige (Kinder, Großeltern) an den folgenden Tagen.
static func join_day(house: VillageHouse, index: int) -> int:
	return house.finished_day + maxi(0, index - 1)


## Ein fertiges Haus bezieht seine Bewohner: bekannte Familie (Steckbrief) oder
## neue Familie. [param arriving] = sie kommen gerade mit dem Zug an (sonst sind
## sie schon da, z.B. nach dem Laden).
func _move_in(house: VillageHouse, arriving: bool) -> void:
	if house.region_station_id>0:
		var progress := RegionProgression.find(get_tree())
		var station := progress.region.station_by_id(house.region_station_id) if progress else null
		if station==null or station.director==null:
			return
		if arriving:
			# Gerade fertig: Die Familie reist mit dem nächsten Zug aus dem Tunnel an.
			if not station.waiting_houses.has(house.object_id):
				station.waiting_houses.append(house.object_id)
			progress.region.refresh()
			var portal := progress.region.serving_portal(station)
			if not Engine.is_editor_hint():
				if portal:
					Events.notification_requested.emit("Familie %s kommt mit dem nächsten Zug aus %s" % [house.home_name, portal.station_name])
				else:
					Events.notification_requested.emit("Familie %s wartet im Tunnel – richte im Fuhrpark eine Linie nach %s ein" % [house.home_name, station.station_name])
			return
		if station.waiting_houses.has(house.object_id):
			return
		var household := get_household(house)
		var present: Array = _residents.get(house.object_id,[])
		# Town census includes every household; only a bounded sample becomes NPCs.
		for profile: NpcProfile in household:
			if not present.has(profile) and station.director.get_npcs().size()<6:
				profile.came_from = station.station_name
				station.director.add_resident(profile,"")
				present.append(profile)
		_residents[house.object_id] = present
		progress.region.refresh()
		return
	if npc_director == null:
		return
	if npc_director.has_family(house.home_name):
		return  # z.B. Familie Berger – ihre Steckbriefe liegen in assets/npcs
	var household := get_household(house)
	var present: Array = _residents.get(house.object_id, [])
	var added := 0
	for i in household.size():
		var profile: NpcProfile = household[i]
		if present.has(profile) or join_day(house, i) > WorldClock.day:
			continue
		if get_generated_resident_count() >= MAX_GENERATED_RESIDENTS:
			break
		npc_director.add_resident(profile, profile.came_from if arriving else "")
		present.append(profile)
		added += 1
	_residents[house.object_id] = present
	if added > 0:
		if arriving:
			residents_arriving.emit(house.home_name, added)
			if not Engine.is_editor_hint():
				Events.notification_requested.emit("Familie %s kommt mit dem Zug aus %s (%d)" % [
					house.home_name, (household[0] as NpcProfile).came_from, added])
		changed.emit()


## Epochen-Spiel: Die Familie eines fertigen Hauses steigt aus dem Zug aus
## [param origin] (Tunnel) – höchstens sechs Bewohner je Ort werden zu Figuren.
func welcome_household(house: VillageHouse, origin: String) -> void:
	var progress := RegionProgression.find(get_tree())
	var station := progress.region.station_by_id(house.region_station_id) if progress else null
	if station == null or station.director == null:
		return
	var household := get_household(house)
	var present: Array = _residents.get(house.object_id, [])
	for profile: NpcProfile in household:
		if not present.has(profile) and station.director.get_npcs().size() < 6:
			profile.came_from = origin
			station.director.add_resident(profile, origin)
			present.append(profile)
	_residents[house.object_id] = present
	residents_arriving.emit(house.home_name, household.size())
	if not Engine.is_editor_hint():
		Events.notification_requested.emit("Familie %s ist in %s angekommen (%d)" % [house.home_name, station.station_name, household.size()])
	changed.emit()


func _move_out(house: VillageHouse) -> void:
	if house.region_station_id>0:
		var progress := RegionProgression.find(get_tree())
		var station := progress.region.station_by_id(house.region_station_id) if progress else null
		if station and station.director:
			for profile in _residents.get(house.object_id,[]):
				station.director.remove_resident(profile)
		_residents.erase(house.object_id)
		_households.erase(house.object_id)
		if progress:
			progress.region.refresh.call_deferred()
		return
	if npc_director == null:
		return
	for profile in _residents.get(house.object_id, []):
		npc_director.remove_resident(profile)
	_residents.erase(house.object_id)
	_households.erase(house.object_id)


## Neuer Tag: Angehörige ziehen nach (sie kommen mit dem Zug).
func _on_day_changed(_day: int) -> void:
	for house in get_houses():
		if house.is_finished() and house.finished_day > 0:
			_move_in(house, true)


## Einwohner insgesamt (bekannte Familien und Zugezogene) und Haushalte.
func get_population() -> int:
	var progress := RegionProgression.find(get_tree())
	if progress:
		return int(progress.metrics()["population"])
	return (npc_director.get_npcs().size() if npc_director else 0)


## Lieblingsweg: ein schöner Ort in der Nähe (Dorfplatz, Brunnen, Bank, Weg),
## über den der Bewohner gern zum Bahnhof und zurück geht.
func _assign_favourite_way(profile: NpcProfile, house: VillageHouse) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(profile.display_name) + house.resident_seed
	var home := house.get_front_point()
	var candidates: Array = []
	for obj in _objects.values():
		var name_text := ""
		var point := Vector3.INF
		if obj is VillageObject:
			match (obj as VillageObject).item_id:
				"plaza":
					name_text = "über den Dorfplatz"
				"fountain":
					name_text = "am Brunnen vorbei"
				"bench":
					name_text = "an der Bank vorbei"
				"street_lamp", "lantern":
					name_text = "unter den Laternen entlang"
			point = obj.position
		elif obj is VillagePath:
			var path := obj as VillagePath
			name_text = "den %s entlang" % VillageCatalog.get_label(path.item_id)
			point = path.start_point.lerp(path.end_point, 0.5)
		if name_text == "" or point == Vector3.INF:
			continue
		var distance := Vector2(point.x, point.z).distance_to(Vector2(home.x, home.z))
		if distance > 6.0 and distance < 45.0:
			candidates.append([name_text, point])
	if candidates.is_empty():
		profile.favourite_way = "auf dem kürzesten Weg"
		profile.favourite_via = Vector3.INF
		return
	var pick: Array = candidates[rng.randi() % candidates.size()]
	profile.favourite_way = pick[0]
	profile.favourite_via = pick[1]


func _new_home_name(seed_value: int) -> String:
	if npc_director:
		var homeless := npc_director.get_homeless_families()
		if not homeless.is_empty():
			return homeless[0]
	var taken: Array = []
	for house in get_houses():
		taken.append(house.home_name)
	if npc_director:
		taken.append_array(npc_director.get_family_names())
	return VillageResidents.family_name(seed_value, taken)


# --- Fußwegenetz ---------------------------------------------------------------------------

func _after_change(obj, removed_footprint := {}) -> void:
	var fp: Dictionary = obj.get_footprint() if obj else removed_footprint
	if nature and not fp.is_empty():
		var half: Vector2 = fp["half"]
		var r := maxf(half.x, half.y) + 2.0
		var c: Vector2 = fp["center"]
		nature.refresh_area(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
	if not _network_dirty:
		_network_dirty = true
		rebuild_walk_network.call_deferred()
	changed.emit()


## Baut den dynamischen Teil des Fußwegenetzes neu: Wege, Dorfplatz, Haustüren.
func rebuild_walk_network() -> void:
	_network_dirty = false
	if walk_graph == null:
		return
	var points := PackedVector3Array()
	var edges: Array = []
	var index_of := func(p: Vector3) -> int:
		for i in points.size():
			if Vector2(points[i].x, points[i].z).distance_to(Vector2(p.x, p.z)) < 0.5:
				return i
		points.append(Vector3(p.x, 0.0, p.z))
		return points.size() - 1
	# 1) Wege, unterteilt in höchstens 6-m-Stücke (bessere Einstiegspunkte)
	var path_chains: Array = []
	for obj in _objects.values():
		if obj is VillagePath:
			var path := obj as VillagePath
			var steps := maxi(1, ceili(path.get_length() / 6.0))
			var chain: Array[int] = []
			for s in steps + 1:
				chain.append(index_of.call(path.start_point.lerp(path.end_point, float(s) / steps)))
			for s in steps:
				edges.append([chain[s], chain[s + 1], WalkGraph.COST_PATH])
			path_chains.append({"path": path, "chain": chain})
	# T-Kreuzungen: Wegende mitten auf einem anderen Weg
	for entry: Dictionary in path_chains:
		var chain: Array = entry["chain"]
		for end_index: int in [chain[0], chain[chain.size() - 1]]:
			var end_point := points[end_index]
			for other: Dictionary in path_chains:
				if other == entry:
					continue
				var other_path: VillagePath = other["path"]
				if other_path.distance_to(end_point) < other_path.get_width() * 0.5 + 0.35:
					var nearest := -1
					var nearest_d := INF
					for idx: int in other["chain"]:
						var d := points[idx].distance_to(end_point)
						if d > 0.01 and d < nearest_d:
							nearest_d = d
							nearest = idx
					if nearest >= 0:
						edges.append([end_index, nearest, WalkGraph.COST_PATH])
	# 2) Dorfplatz: ein Ring um den Brunnen
	for obj in _objects.values():
		if obj is VillageObject and (obj as VillageObject).item_id == "plaza":
			var ring: Array[int] = []
			for k in 8:
				var a := TAU * k / 8.0
				ring.append(index_of.call(obj.position + Vector3(cos(a), 0, sin(a)) * 4.6))
			for k in 8:
				edges.append([ring[k], ring[(k + 1) % 8], WalkGraph.COST_PATH])
	# 3) Anschlüsse ans feste Netz (Bahnhof, Dorfstraße)
	var base := walk_graph.get_base_points()
	var dynamic_count := points.size()
	for i in dynamic_count:
		var best_name := ""
		var best_distance := 7.0
		for base_name: String in base:
			var d := (base[base_name] as Vector3).distance_to(points[i])
			if d < best_distance and is_walkable(points[i], base[base_name]):
				best_distance = d
				best_name = base_name
		if best_name != "":
			edges.append([i, best_name, WalkGraph.COST_CONNECTOR])
	# Einzelne Dorfplatz-Punkte an nahe Wege anbinden
	for i in dynamic_count:
		for j in range(i + 1, dynamic_count):
			var d := points[i].distance_to(points[j])
			if d > 0.5 and d < 3.2 and not _has_edge(edges, i, j) and is_walkable(points[i], points[j]):
				edges.append([i, j, WalkGraph.COST_CONNECTOR])
	# 4) Haustüren: zum nächsten Weg, sonst zum nächsten festen Wegpunkt
	for house in get_houses():
		var door := house.get_front_point()
		var door_index = index_of.call(door)
		var best := -1
		var best_distance := 16.0
		for i in dynamic_count:
			var d := points[i].distance_to(Vector3(door.x, 0, door.z))
			if d < best_distance and is_walkable(door, points[i]):
				best_distance = d
				best = i
		if best >= 0:
			edges.append([door_index, best, WalkGraph.COST_CONNECTOR])
		else:
			var best_name := ""
			best_distance = 30.0
			for base_name: String in base:
				var d := (base[base_name] as Vector3).distance_to(Vector3(door.x, 0, door.z))
				if d < best_distance and is_walkable(door, base[base_name]):
					best_distance = d
					best_name = base_name
			if best_name != "":
				edges.append([door_index, best_name, WalkGraph.COST_CONNECTOR])
	walk_graph.set_dynamic(points, edges)


static func _has_edge(edges: Array, a: int, b: int) -> bool:
	for edge: Array in edges:
		if (edge[0] is int and edge[1] is int) and ((edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a)):
			return true
	return false


# --- Licht ---------------------------------------------------------------------------------

func _on_darkness_changed(dark: bool) -> void:
	_dark = dark
	for obj in _objects.values():
		if obj is VillageObject:
			(obj as VillageObject).set_dark(dark)


# --- Speichern -----------------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	var list: Array = []
	var ids := _objects.keys()
	ids.sort()
	for id in ids:
		list.append(get_object_data(id))
	return {"objects": list, "next_id": _next_id, "finished_log": _finished_log.duplicate(true)}


func load_state(data: Dictionary) -> void:
	clear_all()
	for entry in data.get("objects", []):
		if entry is Dictionary and VillageCatalog.has_item(String(entry.get("item", ""))):
			place(entry)
	_next_id = maxi(_next_id, int(data.get("next_id", _next_id)))
	_finished_log.clear()
	for entry: Variant in data.get("finished_log", []):
		if entry is Dictionary:
			_finished_log.append(entry)
	# Lieblingswege erst bestimmen, wenn alle Wege und Plätze wieder stehen
	for house in get_houses():
		for profile: NpcProfile in _households.get(house.object_id, []):
			_assign_favourite_way(profile, house)
	if terrain:
		terrain.flush_changes()
	rebuild_walk_network()


func _exit_tree() -> void:
	VillageCatalog.clear_cache()
	HouseMeshes.clear_cache()
	VillageVisual.clear_cache()
