## Build-Mode (Taste B): verwaltet Bauwerkzeuge und Undo/Redo.
##
## Alle Kind-Nodes vom Typ [BuildTool] werden automatisch als Werkzeuge
## registriert. Der Build-Mode läuft nur in der Vogelperspektive – beim
## Einschalten wird dorthin gewechselt, beim Verlassen der Ansicht endet er.
##
## Tasten: B an/aus, 1 Schiene, 2 Entfernen, Strg+Z / Strg+Y, Esc abbrechen/beenden.
class_name BuildMode
extends Node

@export var view_mode_controller: ViewModeController
@export var bird_eye: BirdEyeCamera
@export var terrain: LowPolyTerrain
@export var rail_network: RailNetwork
@export var rail_view: RailNetworkView
@export var default_tool: StringName = &"rail"

var active := false
var undo_redo := UndoRedo.new()
var context := BuildContext.new()

var _tools: Dictionary[StringName, BuildTool] = {}
var _current: BuildTool


func _ready() -> void:
	context.camera = bird_eye.camera
	context.terrain = terrain
	context.rail_network = rail_network
	context.rail_view = rail_view
	context.undo_redo = undo_redo

	for child in get_children():
		var tool := child as BuildTool
		if tool:
			_tools[tool.tool_id] = tool
			tool.setup(context)

	Events.view_mode_changed.connect(_on_view_mode_changed)
	Events.build_tool_requested.connect(select_tool)
	Events.game_loaded.connect(_on_game_loaded)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		undo_redo.free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		toggle()
	elif not active:
		return
	elif event.is_action_pressed(&"undo"):
		undo()
	elif event.is_action_pressed(&"redo"):
		redo()
	elif event.is_action_pressed(&"build_tool_rail"):
		select_tool(&"rail")
	elif event.is_action_pressed(&"build_tool_remove"):
		select_tool(&"remove")
	elif event.is_action_pressed(&"build_cancel"):
		if not (_current and _current.cancel()):
			set_active(false)
	elif not (_current and _current.handle_input(event)):
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if active and _current:
		_current.update_tool(delta)


func toggle() -> void:
	set_active(not active)


func set_active(value: bool) -> void:
	if value == active:
		return
	if value and view_mode_controller.mode != GameDefs.ViewMode.BIRD_EYE:
		view_mode_controller.set_mode(GameDefs.ViewMode.BIRD_EYE)
	active = value
	if active:
		if _current == null:
			_current = _tools.get(default_tool)
		_current.activate()
		Events.build_tool_changed.emit(_current.tool_id)
	elif _current:
		_current.deactivate()
	Events.build_mode_changed.emit(active)


func select_tool(tool_id: StringName) -> void:
	var tool: BuildTool = _tools.get(tool_id)
	if tool == null:
		return
	if _current and _current != tool:
		_current.deactivate()
	_current = tool
	if active:
		_current.activate()
	Events.build_tool_changed.emit(tool_id)


func get_tool(tool_id: StringName) -> BuildTool:
	return _tools.get(tool_id)


func get_current_tool() -> BuildTool:
	return _current


func undo() -> void:
	if undo_redo.has_undo():
		undo_redo.undo()


func redo() -> void:
	if undo_redo.has_redo():
		undo_redo.redo()


func _on_view_mode_changed(mode: GameDefs.ViewMode) -> void:
	if mode != GameDefs.ViewMode.BIRD_EYE:
		set_active(false)


## Nach dem Laden passt der alte Verlauf nicht mehr zum Netz.
func _on_game_loaded(_slot: String) -> void:
	if _current:
		_current.cancel()
	undo_redo.clear_history()
