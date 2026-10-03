## Real-engine front, side and station captures; no retouched images.
extends Node
var stage: Node3D
var camera: Camera3D
var materials: Dictionary

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1448,900))
	WorldClock.paused = true
	Seasons.set_season(Seasons.Season.SUMMER)
	stage = Node3D.new()
	add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.33,0.36,0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.95,0.90,0.81)
	world.environment.ambient_light_energy = 0.6
	stage.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240,240)
	ground.mesh = plane
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Color(0.33,0.35,0.31)
	matte.roughness = 1
	ground.material_override = matte
	stage.add_child(ground)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.9
	key.light_color = Color(1,0.94,0.84)
	key.shadow_enabled = true
	stage.add_child(key)
	key.look_at_from_position(Vector3(8,12,-10),Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.light_color = Color(0.78,0.85,1)
	stage.add_child(fill)
	fill.look_at_from_position(Vector3(-8,6,7),Vector3.ZERO)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	var factory := TrainDispatcher.new()
	materials = {"paint":load("res://assets/materials/train_paint.tres"),"glass":load("res://assets/materials/train_glass.tres"),"cargo":load("res://assets/materials/cargo.tres"),"lamp_white":factory._lamp_material(Color(1,0.92,0.75),2),"lamp_red":factory._lamp_material(Color(1,0.1,0.08),2),"lamp_idle_white":factory._lens_material(Color(0.5,0.5,0.5)),"lamp_idle_red":factory._lens_material(Color(0.2,0.04,0.03)),"snow":factory._snow_material(),"festive":factory._festive_material()}
	factory.free()
	for id in EpochCatalog.REFERENCE_IDS+["special_winter"]:
		var type := EpochCatalog.train(id)
		var cars: Array[TrainCar] = []
		var offset := 0.0
		for i in type.consist.size():
			var car := TrainCar.new()
			stage.add_child(car)
			car.build(type.consist[i],type,i==0,i==type.consist.size()-1,materials,i)
			car.position.z = offset+car.length/2
			offset += car.length+TrainMeshes.COUPLING_GAP
			car.set_cabin_light(0.85)
			car.set_destination("WINTERVALE")
			car.set_snow_spray(0)
			if car._exhaust:
				car._exhaust.emitting = false
			cars.append(car)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 30
		camera.look_at_from_position(Vector3(0,2.25,-11.5),Vector3(0,2.0,0))
		await _save(id+"_front")
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = offset*0.67
		camera.look_at_from_position(Vector3(-offset*0.55,offset*0.15,offset*0.15),Vector3(0,1.6,offset*0.5))
		await _save(id+"_side")
		if type.category==TrainType.Category.PASSENGER:
			for car in cars:
				car.set_steps(1,1)
				car.set_doors(1,1)
			camera.size = 8.0
			var z: float = cars[0].get_boarding_paths(1)[0]["door"].z if cars[0].has_doors() else cars[1].get_boarding_paths(1)[0]["door"].z
			camera.look_at_from_position(Vector3(12,5,z-2),Vector3(0,1.8,z))
			await _save(id+"_doors")
		for car in cars:
			stage.remove_child(car)
			car.queue_free()
		await get_tree().process_frame
	for level in range(1,7):
		var parts := EpochStationMeshes.build(level)
		var mesh := MeshInstance3D.new()
		mesh.mesh = parts["paint"]
		mesh.material_override = load("res://assets/materials/nature_vertex_color.tres")
		stage.add_child(mesh)
		var glow := MeshInstance3D.new()
		glow.mesh = parts["glow"]
		glow.material_override = load("res://assets/materials/village_glow.tres")
		stage.add_child(glow)
		var length := float(EpochCatalog.epoch(level)["length"])
		camera.size = length*0.85+12
		camera.look_at_from_position(Vector3(-length*0.6,length*0.35,-length*0.3),Vector3(6,2,length*0.1))
		await _save("station_%d" % level)
		mesh.queue_free()
		glow.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func _save(name: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/qa/progression")
	print("CAPTURE ",name," ",get_viewport().get_texture().get_image().save_png("res://docs/qa/progression/%s.png" % name))
