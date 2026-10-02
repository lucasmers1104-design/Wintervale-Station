## Build-Mode (Taste B): verwaltet Bauwerkzeuge und Undo/Redo.
##
## Alle Kind-Nodes vom Typ [BuildTool] werden automatisch als Werkzeuge
## registriert; Tasten und Reihenfolge stehen in [InputConfig].BUILD_TOOLS.
## Der Build-Mode läuft nur in der Vogelperspektive – beim Einschalten wird
## dorthin gewechselt, beim Verlassen der Ansicht endet er.
##
## Auch ohne Build-Mode lassen sich in der Vogelperspektive Weichen per
## Linksklick umstellen.
class_name BuildMode
extends Node

@export var view_mode_controller: ViewModeController
@export var bird_eye: BirdEyeCamera
@export var terrain: LowPolyTerrain
@export var rail_network: RailNetwork
@export var rail_view: RailNetworkView
@export var interlocking: RailInterlocking
@export var terrain_adapter: RailTerrainAdapter
@export var village: VillageManager
@export var default_tool: StringName = &"rail"
## So nah muss ein Klick an einer Weiche liegen, um sie umzustellen.
@export var switch_pick_radius := 2.5

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
	context.interlocking = interlocking
	context.terrain_adapter = terrain_adapter
	context.undo_redo = undo_redo
	context.village = village

	for child in get_children():
		var tool := child as BuildTool
		if tool:
			_tools[tool.tool_id] = tool
			if tool is VillagePlaceTool:
				(tool as VillagePlaceTool).village = village
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
		if not _try_toggle_switch_outside_build(event):
			return
	elif event.is_action_pressed(&"undo"):
		undo()
	elif event.is_action_pressed(&"redo"):
		redo()
	elif event.is_action_pressed(&"build_cancel"):
		if not (_current and _current.cancel()):
			set_active(false)
	elif _select_tool_by_key(event):
		pass
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
	var progress := RegionProgression.find(get_tree())
	if progress and not progress.tool_unlocked(tool_id):
		Events.notification_requested.emit("Dieses Werkzeug kommt in einer späteren Epoche")
		return
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


func _select_tool_by_key(event: InputEvent) -> bool:
	for entry: Dictionary in InputConfig.BUILD_TOOLS:
		if event.is_action_pressed(entry["action"]):
			select_tool(entry["id"])
			return true
	return false


## In der normalen Vogelperspektive: Klick auf einen Zug → Kamera fährt mit;
## Klick auf eine Weiche stellt sie um.
func _try_toggle_switch_outside_build(event: InputEvent) -> bool:
	if view_mode_controller.mode != GameDefs.ViewMode.BIRD_EYE or not event.is_action_pressed(&"interact_primary"):
		return false
	var train := _pick_train()
	if train:
		bird_eye.follow(train)
		return true
	var point := context.get_mouse_ground_point()
	if point == Vector3.INF:
		return false
	var progress := RegionProgression.find(get_tree())
	if progress:
		var station := progress.region.station_at(point)
		if station:
			Events.region_station_requested.emit(station.station_id)
			return true
	var switch := rail_network.find_switch_near(point, switch_pick_radius)
	if switch == null:
		return false
	var refused := interlocking.request_switch_toggle(switch.node_id)
	Events.notification_requested.emit(refused if refused != "" else "Weiche umgestellt")
	return true


## Zug unter dem Mauszeiger (Strahl gegen die Klickflächen der Wagen).
func _pick_train() -> Train:
	var camera := bird_eye.camera
	var mouse := camera.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 600.0,
		GameDefs.LAYER_TRAINS)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node: Node = hit["collider"]
	while node and not node is Train:
		node = node.get_parent()
	return node as Train


func _on_view_mode_changed(mode: GameDefs.ViewMode) -> void:
	if mode != GameDefs.ViewMode.BIRD_EYE:
		set_active(false)


## Nach dem Laden passt der alte Verlauf nicht mehr zum Netz.
func _on_game_loaded(_slot: String) -> void:
	if _current:
		_current.cancel()
	undo_redo.clear_history()
