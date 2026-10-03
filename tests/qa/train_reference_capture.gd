## Reproduzierbare Godot-Aufnahmen der echten TrainCar-Modelle (kein Mockup).
## godot --path . res://tests/qa/train_reference_capture.tscn
extends Node

@onready var root := get_tree().root

var stage: Node3D
var camera: Camera3D
var cars: Array[TrainCar] = []
var materials: Dictionary


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1448, 900))
	root.get_node("WorldClock").paused = true
	root.get_node("Seasons").set_season(Seasons.Season.WINTER)
	stage = Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.40, 0.39, 0.38)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.92, 0.91, 0.90)
	environment.ambient_light_energy = 0.48
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.29, 0.28, 0.27)
	grey.roughness = 1.0
	ground.material_override = grey
	stage.add_child(ground)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1, 0.94, 0.84)
	key.light_energy = 0.85
	key.shadow_enabled = true
	stage.add_child(key)
	key.look_at_from_position(Vector3(8, 12, -10), Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.76, 0.83, 1.0)
	fill.light_energy = 0.18
	stage.add_child(fill)
	fill.look_at_from_position(Vector3(-8, 5, 4), Vector3.ZERO)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.make_current()
	var factory := TrainDispatcher.new()
	materials = {"paint": load("res://assets/materials/train_paint.tres"), "glass": load("res://assets/materials/train_glass.tres"),
		"lamp_white": factory._lamp_material(Color(1, 0.92, 0.75), 2.0), "lamp_red": factory._lamp_material(Color(1, 0.12, 0.08), 2.0),
		"lamp_idle_white": factory._lens_material(Color(0.55, 0.56, 0.54)), "lamp_idle_red": factory._lens_material(Color(0.25, 0.035, 0.02)),
		"snow": factory._snow_material(), "festive": factory._festive_material()}
	factory.free()
	for design in ["regional_express", "special_winter"]:
		root.get_node("Seasons").set_season(Seasons.Season.WINTER if design == "special_winter" else Seasons.Season.SUMMER)
		var type: TrainType = load("res://assets/trains/%s.tres" % design)
		for i in type.consist.size():
			var car := TrainCar.new()
			stage.add_child(car)
			car.build(type.consist[i], type, i == 0, i == type.consist.size() - 1, materials, i)
			car.position.z = i * 12.34 if i < 2 else 24.68
			car.set_cabin_light(1.0)
			car.set_destination("WINTERVALE")
			cars.append(car)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 28.0
		camera.look_at_from_position(Vector3(0, 2.5, -18), Vector3(0, 2.1, -5.5))
		await _save(design + "_front")
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 24.8
		camera.look_at_from_position(Vector3(-23, 7.0, 0.34), Vector3(0, 1.4, 12.34))
		await _save(design + "_side")
		for car in cars:
			car.set_steps(1.0, 1.0)
			car.set_doors(1.0, 1.0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 9.4
		camera.look_at_from_position(Vector3(12, 5.0, -0.5), Vector3(0, 1.6, 0.3))
		await _save(design + "_doors")
		for car in cars:
			car.queue_free()
		cars.clear()
		await get_tree().process_frame
	TrainMeshes.clear_cache()
	SoundLibrary.clear_cache()
	get_tree().quit()


func _save(design: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/%s.png" % design
	print("CAPTURE ", path, " ", root.get_texture().get_image().save_png(path))
