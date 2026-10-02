## Werkzeug "Entfernen": Gleis, Signal oder Dorf-Objekt unter dem Mauszeiger rot
## markieren und per Klick abreißen. Signale haben Vorrang, weil sie kleiner sind,
## danach Dorf-Objekte (Häuser, Bäume, Wege …), zuletzt Gleise.
## Beim Entfernen eines Gleises verschwinden auch seine Signale (Undo stellt
## alles wieder her, auch die Geländeanpassung).
class_name RailRemoveTool
extends BuildTool

## Wie weit neben der Gleisachse ein Gleis noch getroffen wird.
@export var pick_radius := 2.5
@export var signal_pick_radius := 1.6
@export var highlight_material: Material

var _hovered_id := -1
var _hovered_signal := -1
var _hovered_village = null
var _hovered_station: RegionStation


func deactivate() -> void:
	_set_hovered(-1, -1)
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"interact_primary"):
		var point := context.get_mouse_ground_point()
		if point != Vector3.INF:
			remove_at(point)
		return true
	return false


func update_tool(_delta: float) -> void:
	hover_at(context.get_mouse_ground_point())


## Markiert Signal oder Gleis an [param point] (Vector3.INF = nichts).
func hover_at(point: Vector3) -> void:
	if point == Vector3.INF:
		_set_hovered(-1, -1)
		return
	var network := context.rail_network
	var rail_signal := network.find_signal_near(point, signal_pick_radius)
	if rail_signal:
		_set_hovered(-1, rail_signal.id)
		return
	var village_object = context.village.pick(point) if context.village else null
	if village_object:
		_set_hovered(-1, -1, village_object)
		return
	# Haltepunkte (Epochen-Spiel): Bahnsteig oder Gebäude anklicken. Direkt auf
	# einem Gleis gewinnt das Gleis, damit Parallelgleise abreißbar bleiben.
	var progress := RegionProgression.find(get_tree())
	if progress and network.find_segment_near(point, 1.5) == null:
		var station := progress.region.station_at(point)
		if station:
			_set_hovered(-1, -1, null, station)
			return
	var segment := network.find_segment_near(point, pick_radius)
	_set_hovered(segment.id if segment else -1, -1)


## Entfernt Signal oder Gleis an [param point]. true = es wurde etwas entfernt.
func remove_at(point: Vector3) -> bool:
	hover_at(point)
	var network := context.rail_network
	var undo_redo := context.undo_redo
	if _hovered_village and is_instance_valid(_hovered_village):
		var village := context.village
		var object_id: int = _hovered_village.object_id
		var label := VillageCatalog.get_label(_hovered_village.item_id)
		_set_hovered(-1, -1)
		var object_data := village.get_object_data(object_id)
		undo_redo.create_action("%s entfernen" % label)
		undo_redo.add_do_method(village.demolish.bind(object_id))
		undo_redo.add_undo_method(village.build.bind(object_data))
		undo_redo.commit_action()
		return true
	if _hovered_station and is_instance_valid(_hovered_station):
		var region := _hovered_station.region
		var station_id := _hovered_station.station_id
		# Lambdas kopieren lokale Variablen – der Halter teilt die Abrissdaten.
		var holder := {"data": _hovered_station.get_data()}
		var label := _hovered_station.station_name
		_set_hovered(-1, -1)
		undo_redo.create_action("%s abreißen" % label)
		undo_redo.add_do_method(func() -> void: holder["data"] = region.demolish_station(station_id))
		undo_redo.add_undo_method(func() -> void: region.restore_station(holder["data"]))
		undo_redo.commit_action()
		return true
	if _hovered_signal >= 0:
		var signal_id := _hovered_signal
		_set_hovered(-1, -1)
		var signal_data := network.get_signal(signal_id).to_dict()
		undo_redo.create_action("Signal entfernen")
		undo_redo.add_do_method(network.remove_signal.bind(signal_id))
		undo_redo.add_undo_method(network.add_signal.bind(signal_data))
		undo_redo.commit_action()
		return true
	if _hovered_id < 0:
		return false
	var portal_progress := RegionProgression.find(get_tree())
	if portal_progress and portal_progress.region.is_portal_track(_hovered_id):
		Events.notification_requested.emit("Der Tunnelanschluss bleibt – hier kommen deine Züge an")
		return false
	var id := _hovered_id
	_set_hovered(-1, -1)
	var data := network.get_segment_data(id)
	undo_redo.create_action("Gleis entfernen")
	undo_redo.add_do_method(network.remove_segment.bind(id))
	undo_redo.add_undo_method(network.restore_segment.bind(data))
	undo_redo.commit_action()
	return true


func _set_hovered(segment_id: int, signal_id: int, village_object = null, station: RegionStation = null) -> void:
	if station != _hovered_station:
		if _hovered_station and is_instance_valid(_hovered_station):
			_hovered_station.set_highlight(null)
		_hovered_station = station
		if station:
			station.set_highlight(highlight_material)
	if village_object != _hovered_village:
		if _hovered_village and is_instance_valid(_hovered_village):
			_hovered_village.set_highlight(null)
		_hovered_village = village_object
		if village_object:
			village_object.set_highlight(highlight_material)
	var view := context.rail_view
	if segment_id != _hovered_id:
		var old_segment := view.get_segment_view(_hovered_id)
		if old_segment:
			old_segment.set_highlight(null)
		_hovered_id = segment_id
		var new_segment := view.get_segment_view(segment_id)
		if new_segment:
			new_segment.set_highlight(highlight_material)
	if signal_id != _hovered_signal:
		var old_signal := view.get_signal_view(_hovered_signal)
		if old_signal:
			old_signal.set_highlight(null)
		_hovered_signal = signal_id
		var new_signal := view.get_signal_view(signal_id)
		if new_signal:
			new_signal.set_highlight(highlight_material)
