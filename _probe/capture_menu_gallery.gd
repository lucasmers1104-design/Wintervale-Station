extends SceneTree

const PAGES := [
	"load_save", "achievements", "settings_graphics", "settings_audio",
	"settings_controls", "settings_gameplay", "credits",
]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1672, 941))
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 4:
		await process_frame
	var gallery: Node = menu.get_node("ReferenceCanvas/MenuGallery")
	for page in PAGES:
		gallery.call("show_page", page)
		for i in 4:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var target := "res://docs/menu_gallery_%s.png" % page
		var result := image.save_png(target)
		print(page, ": ", result, " ", image.get_width(), "x", image.get_height())
	gallery.call("show_page", "settings_graphics")
	for dimensions in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		DisplayServer.window_set_size(dimensions)
		for i in 4:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var target := "res://docs/menu_gallery_settings_graphics_%dx%d.png" % [dimensions.x, dimensions.y]
		var result := image.save_png(target)
		print("responsive graphics: ", result, " ", image.get_width(), "x", image.get_height())
	quit()
