## Modell-Durchsicht (Master Debugging V2, Phase D/E): nimmt Züge, Figuren und
## Häuser im echten Spiel aus festen Blickwinkeln mit einer freien Kamera auf.
##
## Start (nicht headless):
##   godot --path . --resolution 1672x941 -s res://tests/qa/model_review.gd -- <ordner> [gruppe ...]
## Gruppen: train, train_night, freight, people, houses, station
## Läuft in der QA-Sandbox; Spielstände bleiben unberührt.
extends SceneTree

var _out := "user://qa_sandbox/model_review/"
var _main: Node3D
var _camera: Camera3D
var _clock: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var groups: Array = ["train", "train_night", "freight", "people", "houses", "station"]
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
		if args.size() > 1:
			groups = args.slice(1)
	DirAccess.make_dir_recursive_absolute(_out)
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.get("values")["reduced_motion"] = true
	settings.get("values")["achievement_notifications"] = false
	_clock = root.get_node(^"/root/WorldClock")
	_main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	for i in 30:
		await process_frame
	_main.get_node(^"HUD").visible = false
	root.get_node(^"/root/Seasons").call("set_season", 3, 0.5)
	_main.get_node(^"Weather").call("set_weather", 0, true)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 800.0
	_main.add_child(_camera)
	for group: String in groups:
		match group:
			"train": await _train_shots(8.5, "")
			"train_night": await _train_shots(18.6, "_night")
			"freight": await _freight_shots()
			"people": await _people_shots()
			"houses": await _house_shots()
			"station": await _station_shots()
			"anim": await _animation_strips()
	quit(0)


# --- Bewegungsabläufe als Bildstreifen --------------------------------------------------

func _animation_strips() -> void:
	_clock.call("set_time", 11.0)
	# Gehzyklus der Spielfigur von der Seite: 8 Bilder im Abstand von 4 Frames
	var vmc: Node = _main.get_node(^"ViewModeController")
	vmc.call("set_mode", GameDefs.ViewMode.EXPLORE, true)
	var player: Node3D = _main.get_node(^"Player")
	for i in 30:
		await physics_frame
	Input.action_press(&"move_forward")
	for i in 40:
		await physics_frame
	var frames: Array[Image] = []
	for i in 8:
		var velocity: Vector3 = player.get("velocity")
		var heading := Vector3(velocity.x, 0.0, velocity.z).normalized()
		if heading.length() < 0.5:
			heading = Vector3.FORWARD
		var side := Vector3(-heading.z, 0.0, heading.x)
		var p := player.global_position
		_camera.global_position = p + side * 3.2 + Vector3.UP * 0.9
		_camera.look_at(p + Vector3.UP * 0.7, Vector3.UP)
		_camera.make_current()
		for k in 4:
			await process_frame
		frames.append(root.get_viewport().get_texture().get_image())
	Input.action_release(&"move_forward")
	_save_strip("anim_player_walk", frames)
	# Ankunft eines Personenzugs: Türen und Trittstufen in 8 Stufen
	vmc.call("set_mode", GameDefs.ViewMode.BIRD_EYE, true)
	_clock.call("set_time", 8.2)
	_clock.set("time_scale", 60.0)
	var train: Node3D = null
	for i in 9000:
		await physics_frame
		train = _find_train(0, true)
		if train and int(train.get("dwell_phase")) == 4:  # STEP_OUT
			break
		train = null
	_clock.set("time_scale", 1.0)
	if train == null:
		printerr("no arriving train for door strip")
		return
	var cars: Array = train.get("cars")
	var middle: Node3D = cars[int(cars.size() / 2.0)]
	var forward := _forward(cars)
	var side := _platform_side(train, forward)
	frames.clear()
	for i in 8:
		_camera.global_position = middle.global_position + side * 4.0 + forward * 1.2 + Vector3.UP * 1.6
		_camera.look_at(middle.global_position + side * 1.3 + Vector3.UP * 1.2, Vector3.UP)
		_camera.make_current()
		for k in 24:
			await process_frame
		frames.append(root.get_viewport().get_texture().get_image())
	_save_strip("anim_train_doors", frames)


## Fügt Einzelbilder zu einem 4×2-Raster zusammen (halbe Auflösung).
func _save_strip(strip_name: String, frames: Array[Image]) -> void:
	var cell := Vector2i(frames[0].get_width() / 2, frames[0].get_height() / 2)
	var sheet := Image.create(cell.x * 4, cell.y * 2, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var frame := frames[i]
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 4) * cell.x, (i / 4) * cell.y))
	print(strip_name, ": ", error_string(sheet.save_png(_out + strip_name + ".png")))


# --- Personenzug ------------------------------------------------------------------------

func _train_shots(hour: float, suffix: String) -> void:
	var train := await _wait_for_train(hour, 0, true)
	if train == null:
		printerr("no passenger train dwelling")
		return
	var cars: Array = train.get("cars")
	var lead: Node3D = cars[0]
	var forward := _forward(cars)
	var side := _platform_side(train, forward)
	var nose := lead.global_position + forward * float(lead.get("length")) * 0.5
	var middle: Node3D = cars[int(cars.size() / 2.0)]
	var rear: Node3D = cars[-1]
	var tail := rear.global_position - forward * float(rear.get("length")) * 0.5
	var up := Vector3.UP
	_clock.set("paused", true)
	await _shot("train_front34" + suffix, nose + forward * 8.0 + side * 6.0 + up * 2.6, nose + up * 1.8)
	await _shot("train_front" + suffix, nose + forward * 9.0 + up * 2.0, nose + up * 1.9)
	await _shot("train_side" + suffix, middle.global_position + side * 13.0 + up * 2.2, middle.global_position + up * 1.8)
	await _shot("train_platform_eye" + suffix, lead.global_position + side * 3.2 - forward * 7.0 + up * 1.65,
		lead.global_position + forward * 2.0 + up * 1.7)
	if suffix == "":
		var bogie := lead.global_position - forward * float(lead.get("bogie_offset"))
		await _shot("train_bogie", bogie + side * 3.2 + forward * 1.4 + up * 0.8, bogie + up * 0.55)
		await _shot("train_door_step", middle.global_position + side * 3.0 + forward * 1.5 + up * 1.2,
			middle.global_position + side * 1.2 + up * 0.9)
		await _shot("train_coupling", lead.global_position - forward * float(lead.get("length")) * 0.5 + side * 3.5 + up * 1.8,
			lead.global_position - forward * float(lead.get("length")) * 0.5 + up * 1.2)
		await _shot("train_rear34", tail - forward * 8.0 + side * 6.0 + up * 2.6, tail + up * 1.8)
		await _shot("train_roof", middle.global_position + side * 7.0 + forward * 6.0 + up * 9.0, middle.global_position + up * 2.5)
		await _shot("train_far_side", middle.global_position - side * 14.0 + up * 3.0, middle.global_position + up * 1.8)
	_clock.set("paused", false)


func _wait_for_train(hour: float, category: int, dwelling: bool) -> Node3D:
	_clock.call("set_time", hour)
	_clock.set("time_scale", 60.0)
	for i in 9000:
		await physics_frame
		var train := _find_train(category, dwelling)
		if train:
			if dwelling and (float(train.call("get_step_amount")) < 1.0 or not bool(train.call("doors_open"))):
				continue
			_clock.set("time_scale", 1.0)
			for k in 10:
				await process_frame
			return train
	_clock.set("time_scale", 1.0)
	return null


func _find_train(category: int, dwelling: bool) -> Node3D:
	var dispatcher: Node = _main.get_node(^"World/Railway/TrainDispatcher")
	for train: Node3D in dispatcher.call("get_trains"):
		var train_type: Resource = train.get("train_type")
		if train_type == null or int(train_type.get("category")) != category:
			continue
		if dwelling and int(train.get("state")) != 1:
			continue
		if not dwelling and int(train.get("state")) != 0:
			continue
		return train
	return null


func _forward(cars: Array) -> Vector3:
	if cars.size() < 2:
		return -(cars[0] as Node3D).global_basis.z
	var direction: Vector3 = (cars[0] as Node3D).global_position - (cars[1] as Node3D).global_position
	direction.y = 0.0
	return direction.normalized()


func _platform_side(train: Node3D, forward: Vector3) -> Vector3:
	var doors: Array = train.call("get_door_points")
	var center: Vector3 = train.call("get_focus_point")
	var side := Vector3(-forward.z, 0.0, forward.x)
	if not doors.is_empty():
		var offset: Vector3 = doors[0] - center
		if offset.dot(side) < 0.0:
			side = -side
	return side


# --- Güterzug ---------------------------------------------------------------------------

func _freight_shots() -> void:
	var train := await _wait_for_train(10.0, 1, true)
	if train == null:
		train = await _wait_for_train(14.0, 1, false)
	if train == null:
		printerr("no freight train")
		return
	var cars: Array = train.get("cars")
	var forward := _forward(cars)
	var side := Vector3(-forward.z, 0.0, forward.x)
	var lead: Node3D = cars[0]
	var nose := lead.global_position + forward * float(lead.get("length")) * 0.5
	_clock.set("paused", true)
	await _shot("freight_loco34", nose + forward * 8.0 + side * 6.0 + Vector3.UP * 2.8, nose + Vector3.UP * 1.8)
	await _shot("freight_loco_side", lead.global_position + side * 10.0 + Vector3.UP * 2.0, lead.global_position + Vector3.UP * 1.6)
	for i in range(1, mini(cars.size(), 5)):
		var car: Node3D = cars[i]
		await _shot("freight_wagon_%d" % i, car.global_position + side * 9.0 + forward * 3.0 + Vector3.UP * 4.0,
			car.global_position + Vector3.UP * 1.4)
	_clock.set("paused", false)


# --- Figuren ----------------------------------------------------------------------------

func _people_shots() -> void:
	_clock.call("set_time", 11.5)
	var player: Node3D = _main.get_node(^"Player")
	for i in 5:
		await process_frame
	var model: Node3D = player.get_node(^"Model")
	var face := -model.global_basis.z
	if face.length() < 0.5:
		face = Vector3.FORWARD
	face.y = 0.0
	face = face.normalized()
	var p := player.global_position
	await _shot("player_front", p + face * 3.2 + Vector3.UP * 1.3, p + Vector3.UP * 0.8)
	await _shot("player_34", p + face.rotated(Vector3.UP, 0.8) * 3.0 + Vector3.UP * 1.4, p + Vector3.UP * 0.8)
	await _shot("player_back", p - face * 3.0 + Vector3.UP * 1.5, p + Vector3.UP * 0.8)
	# Bewohner: die ersten sichtbaren Figuren
	var director: Node = _main.get_node(^"World/NpcDirector") if _main.has_node(^"World/NpcDirector") else null
	if director == null:
		for node in _main.find_children("*", "Node", true, false):
			if node.has_method("get_npcs"):
				director = node
				break
	_clock.set("time_scale", 60.0)
	for i in 900:
		await physics_frame
	_clock.set("time_scale", 1.0)
	var count := 0
	if director:
		for npc: Node3D in director.call("get_npcs"):
			if not npc.visible or count >= 4:
				continue
			var npc_model: Node3D = npc.get_node_or_null(^"Model")
			var look := -(npc_model if npc_model else npc).global_basis.z
			look.y = 0.0
			look = look.normalized() if look.length() > 0.1 else Vector3.FORWARD
			var q := npc.global_position
			look = _free_direction(q + Vector3.UP * 1.1, look, 3.2)
			print("npc_%d: %s state=%d behaviour=%s pos=%s hour=%.2f" % [count, npc.get("display_name"), int(npc.get("state")), npc.call("get_behaviour") if npc.has_method("get_behaviour") else "", q, float(_clock.get("time_of_day"))])
			await _shot("npc_%d" % count, q + look * 3.0 + Vector3.UP * 1.2, q + Vector3.UP * 0.75)
			count += 1


## Erste freie Blickrichtung ab [param preferred] (in 45°-Schritten), damit die
## Kamera nicht in Wänden, Buden oder Bäumen steht.
func _free_direction(from: Vector3, preferred: Vector3, distance: float) -> Vector3:
	var space := _main.get_world_3d().direct_space_state
	for step in [0, 1, -1, 2, -2, 3, -3, 4]:
		var direction := preferred.rotated(Vector3.UP, step * PI / 4.0)
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance + Vector3.UP * 0.2)
		query.collision_mask = 0xFFFFFFFF & ~(1 << 6)  # Bewohner selbst ignorieren
		if space.intersect_ray(query).is_empty():
			return direction
	return preferred


# --- Häuser -----------------------------------------------------------------------------

func _house_shots() -> void:
	_clock.call("set_time", 13.0)
	var village: Node = _main.get_node(^"World/Village")
	var seen := {}
	for house: Node3D in village.call("get_houses"):
		var item := String(house.get("item_id"))
		if seen.has(item):
			continue
		seen[item] = true
		var front := house.global_basis.z
		front.y = 0.0
		front = front.normalized()
		var right := Vector3(-front.z, 0.0, front.x)
		var c := house.global_position
		await _shot("house_" + item, c + front * 11.0 + right * 7.0 + Vector3.UP * 6.0, c + Vector3.UP * 2.4)
	_clock.call("set_time", 20.5)
	# Fenster blenden nach Einbruch der Dunkelheit über einige Sekunden auf
	await create_timer(6.0).timeout
	for house: Node3D in village.call("get_houses"):
		var front := house.global_basis.z
		front.y = 0.0
		front = front.normalized()
		var c := house.global_position
		await _shot("house_night", c + front * 12.0 + Vector3.UP * 5.0, c + Vector3.UP * 2.4)
		break


func _station_shots() -> void:
	_clock.call("set_time", 14.0)
	await _shot("station_building", Vector3(-14, 6, -2), Vector3(-2, 2.5, -14))
	await _shot("station_platform_eye", Vector3(-1.2, 1.7, 8), Vector3(0, 1.8, -20))
	_clock.call("set_time", 19.5)
	await create_timer(6.0).timeout
	await _shot("station_platform_night", Vector3(-1.2, 1.7, 8), Vector3(0, 1.8, -20))
	await _shot("freight_yard_eye", Vector3(18, 4, 4), Vector3(28, 1.5, -12))


# --- Aufnahme ---------------------------------------------------------------------------

func _shot(shot_name: String, from: Vector3, target: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(target, Vector3.UP)
	_camera.make_current()
	for i in 20:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := _out + shot_name + ".png"
	print(shot_name, ": ", error_string(image.save_png(path)))
