extends SceneTree

const PAGES := ["new_game", "load_save", "settings_graphics", "settings_audio", "settings_controls", "settings_gameplay", "achievements", "credits"]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.get("values")["reduced_motion"] = true
	DisplayServer.window_set_size(Vector2i(1672, 941))
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 5:
		await process_frame
	var gallery: Control = menu.get_node("ReferenceCanvas/MenuGallery")
	for page in PAGES:
		gallery.call("show_page", page)
		for i in 4:
			await process_frame
		var screenshot := root.get_viewport().get_texture().get_image()
		var target := "res://docs/phase12_%s.png" % page
		print(page, ": ", screenshot.save_png(target), " ", screenshot.get_width(), "x", screenshot.get_height())
	menu.queue_free()
	await process_frame
	quit()
