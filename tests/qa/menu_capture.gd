## Screenshots aller Menüseiten in Referenzgröße (Master Debugging V2).
##
## Start (nicht headless):
##   godot --path . -s res://tests/qa/menu_capture.gd -- <ausgabeordner> [breite höhe]
## Standard: 1672×941 – die Größe der freigegebenen Referenzbilder.
extends SceneTree

const PAGES := ["new_game", "load_save", "settings_graphics", "settings_audio", "settings_controls",
	"settings_gameplay", "achievements", "credits"]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var out := (args[0] if args.size() > 0 else "user://qa_sandbox/menu_captures").trim_suffix("/") + "/"
	var window := Vector2i(int(args[1]), int(args[2])) if args.size() > 2 else Vector2i(1672, 941)
	DirAccess.make_dir_recursive_absolute(out)
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.get("values")["reduced_motion"] = true
	DisplayServer.window_set_size(window)
	await process_frame
	var suffix := "" if window == Vector2i(1672, 941) else "_%dx%d" % [window.x, window.y]
	var fixture := _make_fixture()
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 8:
		await process_frame
	_save(out + "main_menu%s.png" % suffix)
	var gallery: Control = menu.get_node("ReferenceCanvas/MenuGallery")
	for page: String in PAGES:
		gallery.call("show_page", page)
		for i in 5:
			await process_frame
		_save(out + page + suffix + ".png")
	# Aufgeklappte Auswahlliste (Pergament-Popup) auf der Grafikseite
	gallery.call("show_page", "settings_graphics")
	await process_frame
	var choice := gallery.get_node("LiveContent").find_children("*", "OptionButton", true, false)[0] as OptionButton
	choice.show_popup()
	for i in 4:
		await process_frame
	_save(out + "settings_dropdown%s.png" % suffix)
	choice.get_popup().hide()
	gallery.call("close_page")
	for i in 3:
		await process_frame
	var loading: CanvasLayer = load("res://scripts/ui/menu_loading_screen.gd").new()
	root.add_child(loading)
	await loading.call("reveal")
	loading.call("set_progress", 0.55)
	for i in 30:
		await process_frame
	_save(out + "loading_screen%s.png" % suffix)
	if fixture != "":
		root.get_node(^"/root/SaveManager").call("delete_save", fixture)
	quit()


## Testreise (nur in der QA-Sandbox) mit einigen freigeschalteten Achievements,
## damit freigeschaltete und gesperrte Karten sichtbar sind.
func _make_fixture() -> String:
	var saves: Node = root.get_node(^"/root/SaveManager")
	var source := ""
	for entry: Dictionary in saves.call("list_saves"):
		source = String(entry["slot"])
		break
	if source == "":
		return ""
	var data: Dictionary = saves.call("read_save_data", source)
	data["metadata"]["name"] = "Wintervale QA"
	data["saved_at"] = Time.get_datetime_string_from_system()
	data["saved_unix"] = Time.get_unix_time_from_system()
	data["objects"]["achievements"] = {
		"progress": {"first_tracks": 1, "getting_connected": 42, "all_aboard": 1, "full_schedule": 12,
			"home_sweet_home": 1, "little_village": 9, "bright_nights": 3, "winter_wonderland": 1},
		"unlocked": {"first_tracks": "2026-09-29T18:04:00", "all_aboard": "2026-09-29T18:20:00",
			"home_sweet_home": "2026-09-29T19:02:00", "winter_wonderland": "2026-09-29T18:00:00"},
	}
	var file := FileAccess.open(saves.call("get_save_path", "qa_fixture"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return "qa_fixture"


func _save(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	print(path.get_file(), ": ", error_string(image.save_png(path)), " ", image.get_size())
