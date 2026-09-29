extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1672, 941))
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 5:
		await process_frame
	_save("res://docs/menu_polish_main.png")
	var gallery: Control = menu.get_node("ReferenceCanvas/MenuGallery")
	gallery.call("show_page", "settings_graphics")
	gallery.call("show_page", "settings_audio")
	for i in 3:
		await process_frame
	_save("res://docs/menu_polish_tab.png")
	var loading := MenuLoadingScreen.new()
	root.add_child(loading)
	loading.set_progress(0.45)
	for i in 3:
		await process_frame
	_save("res://docs/menu_polish_loading.png")
	loading.queue_free()
	menu.queue_free()
	await process_frame
	var world: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 8:
		await process_frame
	_save("res://docs/menu_polish_hud.png")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in 5:
		await process_frame
	_save("res://docs/menu_polish_hud_1280.png")
	quit()


func _save(path: String) -> void:
	var screenshot := root.get_viewport().get_texture().get_image()
	print(path, " ", screenshot.save_png(path), " ", screenshot.get_width(), "x", screenshot.get_height())
