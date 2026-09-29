## Global preferences. Gameplay progress belongs in save files, never here.
extends Node

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"fullscreen": false, "vsync": true, "resolution": "1280x720", "fps_limit": 60,
	"master_volume": 80, "music_volume": 70, "ambient_volume": 75,
	"train_volume": 90, "weather_volume": 70, "ui_volume": 85,
	"camera_sensitivity": 1.0, "pan_speed": 1.0, "zoom_speed": 1.0,
	"invert_camera_y": false, "camera_smoothing": 1.0,
	"autosave": true, "day_speed": 1.0,
	"achievement_notifications": true, "reduced_motion": false,
}
const AUDIO_BUSES := {
	"master_volume": "Master", "music_volume": "WintervaleMusic",
	"ambient_volume": "WintervaleAmbient", "train_volume": "WintervaleTrain",
	"weather_volume": "WintervaleWeather", "ui_volume": "WintervaleUI",
}

var legend_expanded := true
var fullscreen := false
var values: Dictionary = DEFAULTS.duplicate(true)
var storage_path := QaSandbox.redirect(PATH)
var _audio_scan_delay := 0.0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(storage_path) == OK:
		legend_expanded = bool(config.get_value("ui", "legend_expanded", legend_expanded))
		for key in DEFAULTS:
			values[key] = config.get_value("preferences", key, DEFAULTS[key])
		if not config.has_section_key("preferences", "fullscreen"):
			values["fullscreen"] = bool(config.get_value("display", "fullscreen", false))
	fullscreen = bool(values["fullscreen"])
	_ensure_audio_buses()
	apply_all()


func _process(delta: float) -> void:
	_audio_scan_delay -= delta
	if _audio_scan_delay > 0.0:
		return
	_audio_scan_delay = 3.0
	var scene := get_tree().current_scene
	if scene:
		_route_audio_in(scene)


func get_pref(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_pref(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = value
	if key == "fullscreen":
		fullscreen = bool(value)
	apply_all()
	_save()


func apply_values(next_values: Dictionary, persist := true) -> void:
	for key in DEFAULTS:
		if next_values.has(key):
			values[key] = next_values[key]
	fullscreen = bool(values["fullscreen"])
	apply_all()
	if persist:
		_save()


func persist_preferences() -> void:
	_save()


func set_legend_expanded(value: bool) -> void:
	legend_expanded = value
	_save()


func set_fullscreen(value: bool) -> void:
	set_pref("fullscreen", value)


func restore_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	fullscreen = false
	apply_all()
	_save()


func apply_all() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			var parts := String(values["resolution"]).split("x")
			if parts.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values["vsync"]) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = maxi(0, int(values["fps_limit"]))
	for key in AUDIO_BUSES:
		var index := AudioServer.get_bus_index(AUDIO_BUSES[key])
		if index >= 0:
			var linear := clampf(float(values[key]) / 100.0, 0.0, 1.0)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	WorldClock.day_length_minutes = 48.0 / maxf(float(values["day_speed"]), 0.25)
	apply_gameplay()
	changed.emit()


func apply_gameplay() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://scenes/main/main.tscn":
		return
	var player := scene.get_node_or_null(^"Player") as PlayerController
	if player:
		player.mouse_sensitivity = 0.0025 * float(values["camera_sensitivity"])
		player.zoom_step = 0.6 * float(values["zoom_speed"])
		player.look_smoothing = 22.0 * float(values["camera_smoothing"])
	var camera := scene.get_node_or_null(^"BirdEyeCamera") as BirdEyeCamera
	if camera:
		camera.pan_speed = float(values["pan_speed"])
		camera.zoom_factor = 1.0 + 0.15 * float(values["zoom_speed"])
		camera.smoothing = 8.0 * float(values["camera_smoothing"])


func _ensure_audio_buses() -> void:
	for bus_name in AUDIO_BUSES.values():
		if bus_name == "Master" or AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")


func _route_audio_in(root: Node) -> void:
	for child in root.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			var category := SoundLibrary.category_for_player(child)
			if category == "" and child.name.to_lower().contains("music"):
				category = "WintervaleMusic"
			if category != "":
				child.bus = category
		_route_audio_in(child)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "legend_expanded", legend_expanded)
	config.set_value("display", "fullscreen", fullscreen)
	for key in values:
		config.set_value("preferences", key, values[key])
	config.save(storage_path)
	changed.emit()
