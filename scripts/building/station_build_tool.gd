class_name StationBuildTool
extends BuildTool

var region: RegionRailway
var expand_station_id := 0
var _preview: MeshInstance3D
var _valid: StandardMaterial3D
var _invalid: StandardMaterial3D
var _data := {}
var _preview_key := "halt"

func _on_setup() -> void:
	_valid = StandardMaterial3D.new()
	_valid.albedo_color = Color(0.4,0.85,0.55,0.55)
	_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_invalid = _valid.duplicate()
	_invalid.albedo_color = Color(0.9,0.3,0.25,0.55)
	_preview = MeshInstance3D.new()
	_preview.mesh = EpochStationMeshes.build(1)["paint"]
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)

func update_tool(_delta: float) -> void:
	preview_at(context.get_mouse_ground_point())

func preview_at(point: Vector3) -> void:
	if point == Vector3.INF:
		_preview.hide()
		return
	_data = region.platform_placement(expand_station_id,point) if expand_station_id>0 else region.placement(point)
	var reason := String(_data.get("reason",""))
	var target_station := region.station_by_id(expand_station_id) if expand_station_id>0 else null
	var key := "platform_%d" % target_station.level if target_station else "halt"
	if key!=_preview_key:
		_preview_key = key
		if key=="halt":
			_preview.mesh = EpochStationMeshes.build(1)["paint"]
		else:
			var definition := EpochCatalog.epoch(region.station_by_id(expand_station_id).level)
			var rng := RandomNumberGenerator.new()
			rng.seed = 400
			_preview.mesh = StationMeshes.create_platform(float(definition["length"]),float(definition["width"]),TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y,rng)
	set_status(reason if reason != "" else ("Klick: Weiteren Bahnsteig errichten · 120 Taler" if expand_station_id>0 else "Klick: Holz-Haltepunkt errichten · 180 Taler"))
	Events.build_cost_changed.emit({"money":120 if expand_station_id>0 else int(EpochCatalog.epoch(1)["cost"])})
	if not _data.has("pos"):
		_preview.hide()
		return
	_preview.global_transform = Transform3D(Basis(Vector3.UP,float(_data["angle"])),SaveUtils.array_to_vec3(_data["pos"]))
	if expand_station_id>0 and region.station_by_id(expand_station_id):
		_preview.global_position += _preview.global_basis.x*(1.78+float(EpochCatalog.epoch(region.station_by_id(expand_station_id).level)["width"])/2)
	_preview.material_override = _valid if reason == "" else _invalid
	_preview.show()

func handle_input(event: InputEvent) -> bool:
	if not event.is_action_pressed(&"interact_primary"):
		return false
	click_at(context.get_mouse_ground_point())
	return true

func click_at(point: Vector3) -> bool:
	if point == Vector3.INF:
		return false
	preview_at(point)
	if _data.get("reason","") != "" or not _data.has("pos"):
		if context.feedback:
			context.feedback.reject(point,get_status())
		return false
	var data := _data.duplicate(true)
	if expand_station_id>0:
		context.undo_redo.create_action("Bahnsteig erweitern")
		context.undo_redo.add_do_method(region.add_platform.bind(expand_station_id,data,true))
		context.undo_redo.add_undo_method(region.remove_platform.bind(expand_station_id))
		context.undo_redo.commit_action()
		if context.feedback:
			context.feedback.confirm("station",SaveUtils.array_to_vec3(data["pos"]),PackedVector3Array(),"Bahnsteig erweitert")
		expand_station_id = 0
		return true
	context.undo_redo.create_action("Holz-Haltepunkt bauen")
	context.undo_redo.add_do_method(region.build_station.bind(data,true))
	context.undo_redo.add_undo_method(region.remove_station.bind(int(data["id"]),true))
	context.undo_redo.commit_action()
	if context.feedback and region.station_by_id(int(data["id"])):
		context.feedback.confirm("station",SaveUtils.array_to_vec3(data["pos"]),PackedVector3Array(),"Holz-Haltepunkt")
	return region.station_by_id(int(data["id"])) != null

func deactivate() -> void:
	super()
	expand_station_id = 0
	_preview.hide()
	Events.build_cost_changed.emit({})
