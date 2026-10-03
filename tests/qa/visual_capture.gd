## Reproduzierbare QA-Screenshots der Spielwelt (Master Debugging V2).
##
## Start (nicht headless – es wird wirklich gerendert):
##   godot --path . --resolution 1672x941 -s res://tests/qa/visual_capture.gd -- <ausgabeordner> [shot ...]
## Ohne Ausgabeordner landen die Bilder in user://qa_sandbox/captures/.
## Jede Aufnahme setzt Uhrzeit, Jahreszeit, Wetter und Kamerapose fest, damit
## Vorher/Nachher-Bilder direkt vergleichbar sind. Spielstände werden nicht
## berührt (QaSandbox leitet alle Schreibzugriffe um).
extends SceneTree

const SHOTS := {
	# name: {time, season, weather, camera: [focus, yaw°, pitch°, distance] | "train" | "player"}
	"hud_1500": {"time": 15.0, "season": 3, "weather": 0, "camera": [Vector3(0, 0, -6), 0.0, 52.0, 45.0]},
	"station_noon": {"time": 12.0, "season": 3, "weather": 0, "camera": [Vector3(2, 0, -9), 35.0, 40.0, 30.0]},
	"station_sunset": {"time": 16.4, "season": 3, "weather": 4, "camera": [Vector3(2, 0, -9), 35.0, 40.0, 30.0]},
	"station_night": {"time": 21.0, "season": 3, "weather": 4, "camera": [Vector3(2, 0, -9), 35.0, 40.0, 30.0]},
	"village_noon": {"time": 12.0, "season": 3, "weather": 1, "camera": [Vector3(-28, 0, 12), -30.0, 45.0, 34.0]},
	"village_night": {"time": 20.5, "season": 3, "weather": 2, "camera": [Vector3(-28, 0, 12), -30.0, 45.0, 34.0]},
	"paths_close": {"time": 11.0, "season": 3, "weather": 0, "camera": [Vector3(-22, 0, 8), 60.0, 55.0, 14.0]},
	"freight_yard": {"time": 13.0, "season": 3, "weather": 1, "camera": [Vector3(26, 0, -10), -50.0, 45.0, 40.0]},
	"summer_village": {"time": 12.0, "season": 1, "weather": 0, "camera": [Vector3(-20, 0, 4), -30.0, 45.0, 45.0]},
	"autumn_station": {"time": 15.5, "season": 2, "weather": 1, "camera": [Vector3(2, 0, -9), 35.0, 40.0, 30.0]},
	"train_platform": {"time": 7.0, "season": 3, "weather": 0, "camera": "train"},
	"train_platform_night": {"time": 18.8, "season": 3, "weather": 4, "camera": "train"},
	"player_third_person": {"time": 14.0, "season": 3, "weather": 1, "camera": "player"},
	"hud_0000": {"time": 0.0, "season": 3, "weather": 4, "camera": [Vector3(0, 0, -6), 0.0, 52.0, 45.0]},
	"hud_0941": {"time": 9.0 + 41.0 / 60.0, "season": 3, "weather": 0, "camera": [Vector3(0, 0, -6), 0.0, 52.0, 45.0]},
	"hud_1200": {"time": 12.0, "season": 3, "weather": 0, "camera": [Vector3(0, 0, -6), 0.0, 52.0, 45.0]},
	"hud_1600": {"time": 16.0, "season": 3, "weather": 0, "camera": [Vector3(0, 0, -6), 0.0, 52.0, 45.0]},
	"hud_2327": {"time": 23.0 + 27.0 / 60.0, "season": 3, "weather": 4, "camera": [Vector3(0, 0, -6), 0.0, 52.0, 45.0]},
	"birch_winter": {"time": 12.5, "season": 3, "weather": 0, "camera": [Vector3(-12.8, 2.5, -6.8), 150.0, 22.0, 13.0]},
	"birch_spring": {"time": 12.5, "season": 0, "weather": 0, "camera": [Vector3(-12.8, 2.5, -6.8), 150.0, 22.0, 13.0]},
	"birch_summer": {"time": 12.5, "season": 1, "weather": 0, "camera": [Vector3(-12.8, 2.5, -6.8), 150.0, 22.0, 13.0]},
	"birch_autumn": {"time": 12.5, "season": 2, "weather": 0, "camera": [Vector3(-12.8, 2.5, -6.8), 150.0, 22.0, 13.0]},
	"pause_menu": {"time": 17.5, "season": 3, "weather": 4, "camera": [Vector3(0, 0, -6), 20.0, 45.0, 40.0], "pause": "menu"},
	"pause_confirm": {"time": 17.5, "season": 3, "weather": 4, "camera": [Vector3(0, 0, -6), 20.0, 45.0, 40.0], "pause": "main_menu"},
}

var _out := "user://qa_sandbox/captures/"
var _main: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	# "env:<eigenschaft>=<wert>" setzt Environment-Werte nur für diese Aufnahme (Vergleiche).
	var overrides := {}
	for arg in args.duplicate():
		if arg.begins_with("env:"):
			var pair := arg.trim_prefix("env:").split("=")
			overrides[pair[0]] = float(pair[1])
			args.erase(arg)
	var wanted: Array = SHOTS.keys()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
		if args.size() > 1:
			wanted = args.slice(1)
	DirAccess.make_dir_recursive_absolute(_out)
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.get("values")["reduced_motion"] = true
	settings.get("values")["achievement_notifications"] = false
	_main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_main)
	var environment: Environment = (_main.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	for key: String in overrides:
		environment.set(key, overrides[key])
		print("override ", key, " = ", environment.get(key))
	current_scene = _main
	for i in 30:
		await process_frame
	for shot_name: String in wanted:
		if not SHOTS.has(shot_name):
			printerr("unknown shot ", shot_name)
			continue
		await _capture(shot_name, SHOTS[shot_name])
	quit(0)


func _capture(shot_name: String, shot: Dictionary) -> void:
	var clock: Node = root.get_node(^"/root/WorldClock")
	var seasons: Node = root.get_node(^"/root/Seasons")
	var weather: Node = _main.get_node(^"Weather")
	var vmc: Node = _main.get_node(^"ViewModeController")
	var bird: Node = _main.get_node(^"BirdEyeCamera")
	seasons.call("set_season", int(shot["season"]), 0.5)
	weather.call("set_weather", int(shot["weather"]), true)
	var hud: CanvasLayer = _main.get_node(^"HUD")
	var notebook := _main.get_node_or_null(^"Notebook")
	if notebook is CanvasLayer:
		(notebook as CanvasLayer).visible = false
	var camera: Variant = shot["camera"]
	if camera is String and camera == "train":
		if not await _wait_for_dwelling_train(float(shot["time"])):
			printerr("no dwelling train for ", shot_name)
			return
	else:
		clock.call("set_time", float(shot["time"]))
	if camera is Array:
		vmc.call("set_mode", GameDefs.ViewMode.BIRD_EYE, true)
		bird.call("load_state", {"focus": [camera[0].x, camera[0].y, camera[0].z],
			"yaw": deg_to_rad(camera[1]), "pitch": deg_to_rad(camera[2]), "distance": camera[3]})
	elif camera == "player":
		vmc.call("set_mode", GameDefs.ViewMode.EXPLORE, true)
	elif camera == "train":
		var train: Node3D = _dwelling_train()
		# Kamera auf die Bahnsteigseite (dort liegen die offenen Türen), leicht schräg:
		# Türen und ausgefahrene Trittstufen im Blick.
		var doors: Array = train.call("get_door_points")
		var focus: Vector3 = doors[int(doors.size() / 2.0)] if not doors.is_empty() else train.call("get_focus_point")
		var center: Vector3 = train.call("get_focus_point")
		var side := Vector3(focus.x - center.x, 0.0, focus.z - center.z)
		if doors.size() >= 2:
			var along: Vector3 = (doors[-1] - doors[0]).normalized()
			side = (focus - center) - along * (focus - center).dot(along)
			side.y = 0.0
		vmc.call("set_mode", GameDefs.ViewMode.BIRD_EYE, true)
		bird.call("load_state", {"focus": [focus.x, focus.y, focus.z], "yaw": atan2(side.x, side.z) + deg_to_rad(60.0),
			"pitch": deg_to_rad(32.0), "distance": 9.0})
	hud.visible = shot_name.begins_with("hud_") or shot.has("pause")
	clock.set("paused", true)
	var pause_menu := _main.get_node_or_null(^"PauseMenu")
	if shot.has("pause") and pause_menu:
		pause_menu.call("open")
		if shot["pause"] != "menu":
			pause_menu.call("get_entry_button", shot["pause"]).pressed.emit()
	for i in 45:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := _out + shot_name + ".png"
	print(shot_name, ": ", error_string(image.save_png(path)), " -> ", path)
	if shot.has("pause") and pause_menu:
		pause_menu.call("close")
		pause_menu.call("_close_dialog")
	clock.set("paused", false)


func _dwelling_train() -> Node3D:
	var dispatcher: Node = _main.get_node(^"World/Railway/TrainDispatcher")
	for train: Node3D in dispatcher.call("get_trains"):
		if int(train.get("state")) == 1 and train.get("train_type") != null \
				and int(train.get("train_type").get("category")) == 0:
			return train
	return null


func _wait_for_dwelling_train(from_hour: float) -> bool:
	var clock: Node = root.get_node(^"/root/WorldClock")
	clock.call("set_time", from_hour)
	clock.set("time_scale", 60.0)
	for i in 6000:
		await physics_frame
		var train := _dwelling_train()
		if train and train.call("get_step_amount") >= 1.0 and train.call("doors_open"):
			clock.set("time_scale", 1.0)
			return true
	clock.set("time_scale", 1.0)
	return false
