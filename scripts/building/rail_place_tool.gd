## Werkzeug "Schiene": Gleise mit Vorschau (Ghost) bauen.
##
## Ablauf: 1. Klick setzt den Startpunkt (rastet an offenen Gleisenden ein),
## 2. Klick baut das Gleis bis zum Mauszeiger. Danach geht es vom neuen Ende
## aus direkt weiter (Kette). Rechtsklick oder Esc bricht die Kette ab.
## Grün = baubar, Rot = nicht baubar (Grund steht in der UI).
##
## Während der Vorschau passt sich das Gelände live an (Damm/Einschnitt), und
## am Cursor stehen Länge und Steigung. Gerade Gleise rasten auf ganze Meter
## und 15°-Schritte ein (mit Alt frei).
##
## [SwitchTool] erbt von diesem Werkzeug und überschreibt die Hook-Methoden
## _begin_at(), _pick_start_direction(), _configure_candidate() und _commit().
class_name RailPlaceTool
extends BuildTool

@export var valid_material: Material
@export var invalid_material: Material
@export var marker_material: Material
## Die Geländevorschau folgt, sobald die Maus so lange ruht (Sekunden) …
@export var terrain_preview_settle := 0.08
## … spätestens aber nach dieser Zeit, auch wenn die Maus weiterläuft.
@export var terrain_preview_interval := 0.3

var _has_start := false
var _start_position := Vector3.ZERO
## Mögliche Startrichtungen (leer = frei wählbar).
var _start_directions: Array[Vector3] = []
## Steigung, mit der am Start angeschlossen wird (NAN = frei).
var _start_grade := NAN
## Starthöhe ist fest (Anschluss an ein Gleis) statt vom Gelände bestimmt.
var _start_fixed := false
var _start_node_id := -1
var _candidate: RailCandidate
var _candidate_valid := false
var _ghost_key := ""
var _preview_key := ""
var _preview_timer := 0.0
var _settle_timer := 0.0
var _last_key := ""
var _markers_dirty := true
var _right_press_position := Vector2.INF

var _ghost: MeshInstance3D
var _cursor: MeshInstance3D
var _markers: Node3D
var _marker_mesh: CylinderMesh
var _label: Label3D


func _on_setup() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)

	_marker_mesh = CylinderMesh.new()
	_marker_mesh.top_radius = 0.6
	_marker_mesh.bottom_radius = 0.6
	_marker_mesh.height = 0.05
	_marker_mesh.radial_segments = 16
	_marker_mesh.rings = 0

	_cursor = MeshInstance3D.new()
	_cursor.name = "Cursor"
	_cursor.mesh = _marker_mesh
	_cursor.material_override = marker_material
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cursor)

	_markers = Node3D.new()
	_markers.name = "OpenEndMarkers"
	add_child(_markers)

	_label = Label3D.new()
	_label.name = "Measure"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.no_depth_test = true
	_label.font_size = 48
	_label.pixel_size = 0.0005
	_label.outline_size = 10
	_label.outline_modulate = Color(0.05, 0.05, 0.08, 0.8)
	_label.visible = false
	add_child(_label)
	context.rail_network.topology_changed.connect(func() -> void: _markers_dirty = true)


func activate() -> void:
	super()
	_markers_dirty = true


func deactivate() -> void:
	super()
	_clear_terrain_preview()


func cancel() -> bool:
	_clear_terrain_preview()
	_label.visible = false
	if not _has_start:
		return false
	_has_start = false
	_start_node_id = -1
	_start_directions.clear()
	_candidate = null
	_ghost.visible = false
	set_status("")
	return true


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"interact_primary"):
		var point := context.get_mouse_ground_point()
		if point != Vector3.INF:
			click_at(point, Input.is_action_pressed(&"build_free_angle"))
		return true
	# Rechtsklick ohne Ziehen bricht ab; Ziehen bleibt der Kamera vorbehalten.
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			_right_press_position = button.position
		elif button.position.distance_to(_right_press_position) < 6.0:
			cancel()
	return false


func update_tool(delta: float) -> void:
	_preview_timer += delta
	_settle_timer += delta
	if _markers_dirty:
		_rebuild_markers()
	var point := context.get_mouse_ground_point()
	if point == Vector3.INF:
		_cursor.visible = false
		_ghost.visible = false
		_label.visible = false
		return
	preview_at(point, Input.is_action_pressed(&"build_free_angle"))


## Klick an einer Weltposition: Start setzen bzw. Gleis bauen.
## Gibt true zurück, wenn etwas passiert ist.
func click_at(point: Vector3, free_angle := false) -> bool:
	if not _has_start:
		return _begin_at(point)
	preview_at(point, free_angle)
	if _candidate == null or not _candidate_valid:
		return false
	_commit(_candidate)
	return true


## Berechnet Vorschau und Gültigkeit für den Mauszeiger an [param point].
func preview_at(point: Vector3, free_angle := false) -> void:
	_validate_chain()
	var snap := _snap(point)
	_cursor.visible = true
	_cursor.global_position = snap["position"] + Vector3.UP * (RailConfig.RAIL_BASE + 0.2)

	if not _has_start:
		_ghost.visible = false
		_label.visible = false
		set_status(_idle_status(point))
		return

	var candidate := _plan(snap, free_angle)
	var reason := RailPlacementValidator.validate(candidate, context.rail_network, context.terrain,
		context.get_space_state())
	_candidate = candidate
	_candidate_valid = reason == ""
	set_status(reason)
	_update_ghost()
	_update_label()
	_update_terrain_preview()


func has_start() -> bool:
	return _has_start


func is_candidate_valid() -> bool:
	return _candidate_valid


func get_candidate() -> RailCandidate:
	return _candidate


# --- Hooks für abgeleitete Werkzeuge ------------------------------------------------

## Startpunkt setzen. Standard: offenes Gleisende oder freies Gelände.
func _begin_at(point: Vector3) -> bool:
	var node := context.rail_network.find_node_near(point, RailConfig.SNAP_RADIUS)
	if node:
		if not node.is_open():
			set_status("Zum Abzweigen das Werkzeug Weiche nutzen")
			return false
		_start_at_node(node.id)
	else:
		_start_node_id = -1
		_start_position = Vector3(point.x, context.terrain.get_height(point.x, point.z), point.z)
		_start_directions.clear()
		_start_grade = NAN
		_start_fixed = false
	_has_start = true
	return true


## Wählt die Startrichtung passend zur Mausposition.
func _pick_start_direction(target: Vector3) -> Vector3:
	if _start_directions.is_empty():
		return Vector3.ZERO
	var wanted := RailGeometry.flat(target - _start_position)
	var best := _start_directions[0]
	for direction in _start_directions:
		if direction.dot(wanted) > best.dot(wanted):
			best = direction
	return best


## Letzte Anpassungen am Kandidaten vor der Prüfung.
func _configure_candidate(_candidate_to_configure: RailCandidate) -> void:
	pass


## Baut den Kandidaten (als rückgängig machbare Aktion).
func _commit(candidate: RailCandidate) -> void:
	var network := context.rail_network
	var data := network.build_segment_data(candidate)
	var undo_redo := context.undo_redo
	undo_redo.create_action("Gleis bauen")
	undo_redo.add_do_method(network.restore_segment.bind(data))
	undo_redo.add_undo_method(network.remove_segment.bind(int(data["id"])))
	undo_redo.commit_action()
	_continue_from(int(data["end_node"]))


func _idle_status(point: Vector3) -> String:
	var node := context.rail_network.find_node_near(point, RailConfig.SNAP_RADIUS)
	return "Zum Abzweigen das Werkzeug Weiche nutzen" if node and not node.is_open() else ""


# --- Intern ----------------------------------------------------------------

func _start_at_node(node_id: int) -> void:
	var network := context.rail_network
	_start_node_id = node_id
	_start_position = network.get_rail_node(node_id).position
	_start_directions = [network.get_outward_direction(node_id)]
	_start_grade = network.get_outward_grade(node_id)
	_start_fixed = true


## Kette: vom neuen Ende aus weiterbauen (außer es wurde an ein Gleis angeschlossen).
func _continue_from(node_id: int) -> void:
	_clear_terrain_preview()
	var node := context.rail_network.get_rail_node(node_id)
	if node and node.is_open():
		_start_at_node(node_id)
		_has_start = true
	else:
		cancel()


func _plan(snap: Dictionary, free_angle: bool) -> RailCandidate:
	var network := context.rail_network
	var snapped_node: int = snap["node_id"]
	var target: Vector3 = snap["position"]
	var end_direction: Vector3 = -snap["direction"] if snapped_node >= 0 else Vector3.ZERO
	var start_direction := _pick_start_direction(target)
	var candidate := RailPlanner.plan(_start_position, start_direction, target, end_direction, not free_angle)

	# Freie Geraden auf ganze Meter runden – für präzises Bauen
	if candidate.has_geometry() and not free_angle and start_direction == Vector3.ZERO and snapped_node < 0:
		var run := RailGeometry.flat(candidate.get_end() - candidate.get_start())
		var rounded := maxf(1.0, roundf(run.length()))
		candidate = RailPlanner.plan(_start_position, Vector3.ZERO,
			_start_position + run.normalized() * rounded, Vector3.ZERO, false)

	candidate.start_node_id = _start_node_id
	candidate.end_node_id = snapped_node
	_configure_candidate(candidate)
	if not candidate.has_geometry():
		return candidate

	var end_fixed := snapped_node >= 0
	var end_height := network.get_rail_node(snapped_node).position.y if end_fixed else 0.0
	var end_grade := -network.get_outward_grade(snapped_node) if end_fixed else NAN
	var profile := RailProfile.compute(RailGeometry.make_planar_curve(candidate.points), _start_position.y,
		end_height, _start_fixed, end_fixed, context.terrain, _start_grade, end_grade)
	candidate.apply_profile(profile["heights"])
	candidate.max_earthwork = profile["max_earthwork"]
	if candidate.error == "" and profile["error"] != "":
		candidate.error = profile["error"]
	return candidate


## Nach Undo kann der Startknoten verschwunden oder belegt sein.
func _validate_chain() -> void:
	if _has_start and _start_node_id >= 0 and _start_directions.size() == 1:
		var node := context.rail_network.get_rail_node(_start_node_id)
		if node == null or not node.is_open():
			cancel()


## Rastet an offenen Gleisenden in der Nähe ein.
func _snap(point: Vector3) -> Dictionary:
	var network := context.rail_network
	var node := network.find_open_node_near(point, RailConfig.SNAP_RADIUS, _start_node_id)
	if node:
		return {"position": node.position, "node_id": node.id, "direction": network.get_outward_direction(node.id)}
	var ground := Vector3(point.x, context.terrain.get_height(point.x, point.z), point.z)
	return {"position": ground, "node_id": -1, "direction": Vector3.ZERO}


func _update_ghost() -> void:
	if _candidate == null or not _candidate.has_geometry():
		_ghost.visible = false
		_ghost_key = ""
		return
	var key := "%s|%s|%s" % [_candidate.points, _candidate.heights, _candidate_valid]
	if key != _ghost_key:
		_ghost_key = key
		_ghost.mesh = RailMeshes.create_ghost(_candidate.curve)
		_ghost.material_override = valid_material if _candidate_valid else invalid_material
	_ghost.visible = true


## Länge und Steigung am Cursor.
func _update_label() -> void:
	if _candidate == null or not _candidate.has_geometry():
		_label.visible = false
		return
	var grade := RailGeometry.max_grade(_candidate.curve) * 100.0
	_label.text = "%d m  ·  %.1f %%" % [roundi(_candidate.get_length()), grade]
	_label.modulate = Color(0.85, 1.0, 0.88) if _candidate_valid else Color(1.0, 0.7, 0.62)
	_label.global_position = _candidate.get_end() + Vector3.UP * 2.2
	_label.visible = true


## Geländeanpassung live zeigen. Gedrosselt, weil dafür Geländekacheln neu
## gebaut werden: sobald die Maus kurz ruht oder spätestens alle 0,3 s.
func _update_terrain_preview() -> void:
	if context.terrain_adapter == null:
		return
	if _candidate == null or not _candidate.has_geometry():
		_clear_terrain_preview()
		return
	if _ghost_key != _last_key:
		_last_key = _ghost_key
		_settle_timer = 0.0
	if _ghost_key == _preview_key:
		return
	if _settle_timer < terrain_preview_settle and _preview_timer < terrain_preview_interval:
		return
	_preview_key = _ghost_key
	_preview_timer = 0.0
	context.terrain_adapter.show_preview(RailGeometry.polyline(_candidate.curve, 2.0))


func _clear_terrain_preview() -> void:
	if _preview_key != "" and context.terrain_adapter:
		context.terrain_adapter.clear_preview()
	_preview_key = ""


func _rebuild_markers() -> void:
	_markers_dirty = false
	for child in _markers.get_children():
		_markers.remove_child(child)
		child.queue_free()
	for node in context.rail_network.get_nodes():
		if node.is_open():
			var marker := MeshInstance3D.new()
			marker.mesh = _marker_mesh
			marker.material_override = marker_material
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marker.position = node.position + Vector3.UP * (RailConfig.RAIL_BASE + 0.2)
			_markers.add_child(marker)
