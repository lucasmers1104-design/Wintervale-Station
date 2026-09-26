## Werkzeug "Entfernen": Gleisstück unter dem Mauszeiger rot markieren und per Klick abreißen.
class_name RailRemoveTool
extends BuildTool

## Wie weit neben der Gleisachse ein Gleis noch getroffen wird.
@export var pick_radius := 2.5
@export var highlight_material: Material

var _hovered_id := -1


func deactivate() -> void:
	_set_hovered(-1)
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


## Markiert das Gleis an [param point] (Vector3.INF = nichts).
func hover_at(point: Vector3) -> void:
	var segment: RailSegment = null
	if point != Vector3.INF:
		segment = context.rail_network.find_segment_near(point, pick_radius)
	_set_hovered(segment.id if segment else -1)


## Entfernt das Gleis an [param point]. true = es wurde etwas entfernt.
func remove_at(point: Vector3) -> bool:
	hover_at(point)
	if _hovered_id < 0:
		return false
	var network := context.rail_network
	var id := _hovered_id
	_set_hovered(-1)
	var data := network.get_segment_data(id)
	var undo_redo := context.undo_redo
	undo_redo.create_action("Gleis entfernen")
	undo_redo.add_do_method(network.remove_segment.bind(id))
	undo_redo.add_undo_method(network.restore_segment.bind(data))
	undo_redo.commit_action()
	return true


func _set_hovered(id: int) -> void:
	if id == _hovered_id:
		return
	var old_view := context.rail_view.get_segment_view(_hovered_id)
	if old_view:
		old_view.set_highlight(null)
	_hovered_id = id
	var new_view := context.rail_view.get_segment_view(id)
	if new_view:
		new_view.set_highlight(highlight_material)
