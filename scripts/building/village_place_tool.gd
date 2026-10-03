## Bauwerkzeug fürs Dorf – eines je Kategorie (Wohnhäuser, Wege, Natur,
## Beleuchtung, Dekoration). Innerhalb der Kategorie wählt man das Objekt per
## Button oder Taste, dreht es, wechselt die Farbe und setzt es per Klick.
##
## Einzelobjekte: Vorschau folgt der Maus (grün = passt, rot = geht nicht,
## mit Grund in der Statuszeile). Häuser drehen sich automatisch mit der Tür
## zum nächsten Weg, bis man selbst dreht.
## Linienobjekte (Wege, Zäune, Hecken, Lichterketten): Klick = Start, Klick =
## Ende, danach geht es direkt weiter. Wege rasten an Wegenden und mitten auf
## Wegen ein und verbinden sich dadurch automatisch.
class_name VillagePlaceTool
extends BuildTool

@export var category: StringName = &"houses"
@export var valid_material: Material
@export var invalid_material: Material
@export var marker_material: Material
## Drehschritt mit der Drehen-Taste (Grad).
@export var rotate_step := 45.0

var village: VillageManager

var _items: Array[String] = []
var _index := 0
var _variant := 0
var _angle := 0.0
var _auto_orient := true
var _start := Vector3.INF
var _point := Vector3.INF
var _valid := false
var _ghost_key := ""
var _check_key := ""
var _ghost: Node3D
var _marker: MeshInstance3D


func _on_setup() -> void:
	_items = VillageCatalog.get_items(category)
	_refresh_unlocked_items.call_deferred()
	_marker = MeshInstance3D.new()
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.material_override = marker_material
	add_child(_marker)
	Events.village_item_requested.connect(_on_item_requested)


func activate() -> void:
	super()
	_refresh_unlocked_items()
	_announce_items()


func deactivate() -> void:
	_clear_ghost()
	super()


func cancel() -> bool:
	if _start != Vector3.INF:
		_start = Vector3.INF
		_ghost_key = ""
		return true
	return false


func get_item() -> String:
	return _items[_index] if not _items.is_empty() else ""


func get_items() -> Array[String]:
	return _items


func select_item(item_id: String) -> void:
	var index := _items.find(item_id)
	if index < 0:
		return
	_index = index
	_variant = 0
	_start = Vector3.INF
	_ghost_key = ""
	_announce_items()


func handle_input(event: InputEvent) -> bool:
	if _items.is_empty():
		return false
	if event.is_action_pressed(&"build_rotate"):
		_angle = fposmod(_angle - deg_to_rad(rotate_step), TAU)
		_auto_orient = false
		return true
	if event.is_action_pressed(&"build_next_item"):
		select_item(_items[(_index + 1) % _items.size()])
		return true
	if event.is_action_pressed(&"build_variant"):
		_variant = (_variant + 1) % VillageCatalog.get_variant_count(get_item())
		_ghost_key = ""
		return true
	if event.is_action_pressed(&"interact_primary"):
		var point := context.get_mouse_ground_point()
		if point != Vector3.INF:
			click_at(point)
		return true
	return false


func update_tool(_delta: float) -> void:
	preview_at(context.get_mouse_ground_point())


# --- Öffentlich (auch für Tests) --------------------------------------------------------

## Klick: Einzelobjekt setzen bzw. Linie beginnen/beenden. true = gebaut.
func click_at(point: Vector3) -> bool:
	var item_id := get_item()
	if not point.is_finite() or item_id=="":
		return false
	point = _snap(point)
	if VillageCatalog.is_line(item_id):
		if _start == Vector3.INF:
			_start = point
			if context.feedback:
				context.feedback.snapped(point,true)
			return false
		preview_at(point)
		if not _valid:
			if context.feedback:
				context.feedback.reject(point,get_status())
			return false
		var finish := _clamp_length(item_id,_start,point)
		var data := village.prepare(item_id, _start, 0.0, _variant, finish)
		_commit(data)
		_start = SaveUtils.array_to_vec3(data["end"])  # includes terrain height
		return true
	preview_at(point)
	if not _valid:
		if context.feedback:
			context.feedback.reject(point,get_status())
		return false
	_commit(village.prepare(item_id, point, _current_angle(point), _variant))
	return true


## Vorschau an [param point] (Vector3.INF = keine).
func preview_at(point: Vector3) -> void:
	if point == Vector3.INF or village == null:
		_clear_ghost()
		return
	var item_id := get_item()
	if item_id=="":
		_clear_ghost()
		return
	point = _snap(point)
	# Nur neu prüfen, wenn sich etwas geändert hat (die Prüfung kostet Physik- und Wegetests)
	var check_key := "%s|%d|%s|%s|%.3f|%d" % [item_id, _variant, point.snapped(Vector3.ONE * 0.05), _start,
		_current_angle(point), village.get_object_count() * 100000 + Economy.revision % 100000]
	if check_key == _check_key and _ghost:
		return
	_check_key = check_key
	_point = point
	var reason := ""
	if VillageCatalog.is_line(item_id):
		if _start == Vector3.INF:
			_show_marker(point, 0.5)
			_clear_ghost()
			set_status("Startpunkt setzen")
			_valid = false
			return
		var end := _clamp_length(item_id, _start, point)
		reason = village.check_placement(item_id, _start, 0.0, _variant, end)
		_show_ghost(item_id, _start, 0.0, end)
	else:
		var angle := _current_angle(point)
		reason = village.check_placement(item_id, point, angle, _variant)
		_show_ghost(item_id, point, angle, Vector3.INF)
	# Kosten: Geld und Material müssen vorhanden sein
	var cost := get_cost_at(point)
	Events.build_cost_changed.emit(cost)
	if reason == "":
		reason = Economy.describe_missing(cost)
	_valid = reason == ""
	set_status(reason)
	_set_ghost_material(valid_material if _valid else invalid_material)


## Was das gewählte Objekt an dieser Stelle kostet (Linien: je nach Länge).
func get_cost_at(point: Vector3) -> Dictionary:
	var item_id := get_item()
	var length := 0.0
	if VillageCatalog.is_line(item_id) and _start != Vector3.INF and point != Vector3.INF:
		var end := _clamp_length(item_id, _start, point)
		length = Vector2(_start.x, _start.z).distance_to(Vector2(end.x, end.z))
	return VillageCatalog.get_cost(item_id, length)


func is_valid() -> bool:
	return _valid


func has_start() -> bool:
	return _start != Vector3.INF


# --- Intern ---------------------------------------------------------------------------

## Bauen über Undo/Redo: bezahlen + setzen bzw. abreißen + erstatten.
## Häuser beginnen als Baustelle (Fortschritt 0).
func _commit(data: Dictionary) -> void:
	var id := int(data["id"])
	data["paid"] = true
	if VillageCatalog.get_kind(String(data["item"])) == "house":
		data["build"] = 0.0
	var undo_redo := context.undo_redo
	undo_redo.create_action("%s bauen" % VillageCatalog.get_label(String(data["item"])))
	undo_redo.add_do_method(village.build.bind(data))
	undo_redo.add_undo_method(village.demolish.bind(id))
	undo_redo.commit_action()
	if village.get_object(id) and context.feedback:
		var at := SaveUtils.array_to_vec3(data["pos"])
		var points := PackedVector3Array()
		if data.has("end"):
			var finish := SaveUtils.array_to_vec3(data["end"])
			for i in range(17):
				var p := at.lerp(finish,i/16.0)
				p.y = context.terrain.get_surface_height(p.x,p.z)+0.05
				points.append(p)
		context.feedback.confirm(VillageCatalog.get_kind(String(data["item"])),at,points,VillageCatalog.get_label(String(data["item"])))
	_ghost_key = ""
	_check_key = ""


## Häuser drehen sich mit der Tür (-Z) zum nächsten Weg, bis man selbst dreht.
func _current_angle(point: Vector3) -> float:
	if _auto_orient and VillageCatalog.get_kind(get_item()) == "house":
		var target := village.nearest_path_point(point, 16.0)
		if target != Vector3.INF:
			var dir := Vector2(target.x - point.x, target.z - point.z)
			if dir.length() > 0.5:
				# Tür zeigt nach -Z → Drehung so, dass -Z zum Weg zeigt; auf 15° runden
				var angle := atan2(-dir.x, -dir.y)
				return snappedf(angle, deg_to_rad(15.0))
	return _angle


func _snap(point: Vector3) -> Vector3:
	var item_id := get_item()
	if VillageCatalog.get_kind(item_id) == "path":
		var snapped := village.snap_path_point(point)
		if context.feedback:
			context.feedback.snapped(snapped,snapped.distance_to(point)>0.08)
		return snapped
	if VillageCatalog.get_kind(item_id) == "house":
		return Vector3(snappedf(point.x, 0.5), point.y, snappedf(point.z, 0.5))
	return point


func _clamp_length(item_id: String, start: Vector3, end: Vector3) -> Vector3:
	var max_length := float(VillageCatalog.get_item(item_id).get("max_length", 20.0))
	var flat := Vector2(end.x - start.x, end.z - start.z)
	if flat.length() > max_length:
		flat = flat.normalized() * max_length
		return Vector3(start.x + flat.x, end.y, start.z + flat.y)
	return end


func _show_ghost(item_id: String, position: Vector3, angle: float, end: Vector3) -> void:
	var length := 0.0
	if end != Vector3.INF:
		length = snappedf(Vector2(position.x, position.z).distance_to(Vector2(end.x, end.z)), 0.1)
	var key := "%s|%d|%.1f" % [item_id, _variant, length]
	if VillageCatalog.get_kind(item_id) == "path":
		key += "|%s|%s" % [position.snapped(Vector3.ONE * 0.1), end.snapped(Vector3.ONE * 0.1)]
	if key != _ghost_key:
		_clear_ghost()
		_ghost_key = key
		_ghost = Node3D.new()
		add_child(_ghost)
		if VillageCatalog.get_kind(item_id) == "path":
			var mesh := MeshInstance3D.new()
			var terrain := context.terrain
			mesh.mesh = PathMeshes.build(item_id, position, end, func(x: float, z: float) -> float: return terrain.get_surface_height(x, z) + 0.02)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ghost.add_child(mesh)
		else:
			VillageVisual.attach(_ghost, item_id, _variant, length, null, true, valid_material)
			for child in _ghost.get_children():
				if child is GeometryInstance3D:
					(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if VillageCatalog.get_kind(item_id) == "path":
		_ghost.transform = Transform3D.IDENTITY
	elif end != Vector3.INF:
		var start := Vector3(position.x, context.terrain.get_height(position.x, position.z), position.z)
		var finish := Vector3(end.x, context.terrain.get_height(end.x, end.z), end.z)
		_ghost.transform = Transform3D(VillageObject.line_basis(start, finish), start)
	else:
		var kind := VillageCatalog.get_kind(item_id)
		var y := village.level_height(VillageFootprint.for_item(item_id, position, angle, _variant)) \
			if kind == "house" or kind == "plaza" else context.terrain.get_height(position.x, position.z)
		_ghost.transform = Transform3D(Basis(Vector3.UP, angle), Vector3(position.x, y, position.z))
	# Grundfläche als flacher Rahmen
	var fp := VillageFootprint.for_item(item_id, position, angle, _variant, end)
	var half: Vector2 = fp["half"]
	var box := BoxMesh.new()
	box.size = Vector3(half.x * 2.0 + 0.3, 0.04, half.y * 2.0 + 0.3)
	_marker.mesh = box
	var center: Vector2 = fp["center"]
	_marker.transform = Transform3D(Basis(Vector3.UP, fp["angle"]),
		Vector3(center.x, context.terrain.get_height(center.x, center.y) + 0.05, center.y))
	_marker.visible = true


func _show_marker(point: Vector3, radius: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.05
	disc.radial_segments = 16
	disc.rings = 0
	_marker.mesh = disc
	_marker.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, context.terrain.get_height(point.x, point.z) + 0.05, point.z))
	_marker.visible = true


func _set_ghost_material(material: Material) -> void:
	if _ghost == null:
		return
	for child in _ghost.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material


func _clear_ghost() -> void:
	if _check_key != "":
		Events.build_cost_changed.emit({})
	_check_key = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_ghost_key = ""
	if _marker:
		_marker.visible = false


func _announce_items() -> void:
	if visible:
		Events.village_items_changed.emit(category, _items, get_item())


func _on_item_requested(item_id: String) -> void:
	if visible and _items.has(item_id):
		select_item(item_id)

func _refresh_unlocked_items() -> void:
	var progress := RegionProgression.find(get_tree())
	_items = VillageCatalog.get_items(category)
	if progress:
		_items.assign(_items.filter(func(id: String) -> bool: return progress.epoch>=EpochCatalog.item_epoch(id)))
	_index = clampi(_index,0,maxi(0,_items.size()-1))
	_announce_items()
