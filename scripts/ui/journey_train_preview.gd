## Shared real train preview for the fleet and epoch rewards.
class_name JourneyTrainPreview
extends PanelContainer
const S = preload("res://scripts/ui/journey_style.gd")
var train_type: TrainType
var _preview: Node3D
var _viewport: SubViewport
var _preview_camera: Camera3D
var _preview_length := 16.0
var container: SubViewportContainer

func _process(delta: float) -> void:
	if is_visible_in_tree() and is_instance_valid(_preview):
		_preview.rotation.y += delta*0.12
		_frame_preview()

func _drag(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_preview.rotation.y += event.relative.x*0.012
		_frame_preview()
		container.accept_event()

func configure(type: TrainType, materials: Dictionary, height := 280.0) -> void:
	train_type = type
	var frame_style := S.card_style()
	frame_style.content_margin_left = 10
	frame_style.content_margin_right = 10
	frame_style.content_margin_top = 10
	frame_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", frame_style)
	container = SubViewportContainer.new()
	container.custom_minimum_size = Vector2(0, height)
	container.stretch = true
	container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	container.tooltip_text = "Mit gedrückter Maustaste drehen"
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(900, int(height))
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)
	_preview = Node3D.new()
	_viewport.add_child(_preview)
	var length := EpochCatalog.consist_length(type)
	_preview_length = length
	var offset := -length / 2
	for i in type.consist.size():
		var car := TrainCar.new()
		_preview.add_child(car)
		car.build(type.consist[i], type, i == 0, i == type.consist.size() - 1, materials, i)
		car.position.z = offset + car.length / 2
		offset += car.length + TrainMeshes.COUPLING_GAP
		car.set_cabin_light(0.85)
		car.set_snow_spray(0)
		if car._exhaust:
			car._exhaust.emitting = false
	_preview.add_child(_preview_track(length + 6.0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -32, 0)
	light.light_energy = 1.15
	light.light_color = Color(1.0, 0.9, 0.76)
	light.shadow_enabled = true
	_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.72, 0.76, 1.0)
	_viewport.add_child(fill)
	var camera := Camera3D.new()
	_preview_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = length * 0.85 + 10
	_viewport.add_child(camera)
	camera.position = Vector3(length * 0.65, length * 0.10 + 3, -length * 0.20)
	camera.look_at(Vector3(0, 2.0, 0))
	_frame_preview()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("ddd8cc")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e6dccb")
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_viewport.add_child(environment)
	container.gui_input.connect(_drag)


## Kurzes Schaugleis unter dem Vorschauzug (Schotter, Schwellen, Schienen).
func _preview_track(length: float) -> MeshInstance3D:
	var st := TrainMeshes._new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.12, 0), Vector3(3.6, 0.24, length), Color(0.55, 0.5, 0.47))
	var count := int(length / 0.65)
	for i in count:
		LowPolyBuilder.add_box(st, Vector3(0, 0.29, -length / 2 + (i + 0.5) * length / count), Vector3(2.5, 0.12, 0.26), Color(0.42, 0.29, 0.19))
	for side: float in [-0.7175, 0.7175]:
		LowPolyBuilder.add_box(st, Vector3(side, 0.41, 0), Vector3(0.08, 0.13, length), Color(0.55, 0.56, 0.58))
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position.y = TrainCar.RAIL_TOP - 0.475
	return mesh


func _frame_preview() -> void:
	if not is_instance_valid(_preview_camera) or not is_instance_valid(_viewport) or not is_instance_valid(_preview):
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for x: float in [-1.6, 1.6]:
		for y: float in [0, 4.4]:
			for z: float in [-_preview_length / 2, _preview_length / 2]:
				var point := _preview_camera.to_local(_preview.to_global(Vector3(x, y, z)))
				minimum = minimum.min(Vector2(point.x, point.y))
				maximum = maximum.max(Vector2(point.x, point.y))
	var aspect := float(_viewport.size.x) / maxf(1, _viewport.size.y)
	var extent := maximum - minimum
	_preview_camera.size = maxf(extent.x, extent.y * aspect) * 1.1
