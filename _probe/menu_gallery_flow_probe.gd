extends SceneTree

const EXPECTED := [
	"load_save", "achievements", "settings_graphics", "settings_audio",
	"settings_controls", "settings_gameplay", "credits",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var gallery: Control = menu.get_node("ReferenceCanvas/MenuGallery")
	for page in EXPECTED:
		gallery.call("show_page", page)
		if not gallery.visible or gallery.get_node("PageArt").texture == null:
			push_error("Visual page unavailable: " + page)
			quit(1)
			return
	print("All seven visual pages load")
	for entry in ["LoadSave", "Settings", "Achievements", "Credits"]:
		gallery.call("close_page")
		(menu.get_node("ReferenceCanvas/" + entry) as Button).pressed.emit()
		if not gallery.visible:
			push_error("Main menu did not open visual page: " + entry)
			quit(1)
			return
	print("Main menu opens all four referenced destinations")
	gallery.call("show_page", "settings_graphics")
	(gallery.get_node("VisibleControls/Audio") as Button).pressed.emit()
	if gallery.get_node("PageArt").texture != load("res://assets/ui/menu_screens/settings_audio.png"):
		push_error("Settings tab navigation did not open Audio")
		quit(1)
		return
	(gallery.get_node("VisibleControls/Back") as Button).pressed.emit()
	if gallery.visible:
		push_error("Back did not close the visual page")
		quit(1)
		return
	print("Settings tab and Back navigation work")
	quit()
