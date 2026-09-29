extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for dimensions in [Vector2i(1672, 941), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		DisplayServer.window_set_size(dimensions)
		for i in 15:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var target := "res://docs/main_menu_capture_%dx%d.png" % [dimensions.x, dimensions.y]
		var result := image.save_png(target)
		print("menu capture: ", result, " / ", image.get_width(), "x", image.get_height(), " -> ", target)
		if dimensions == Vector2i(1672, 941):
			(menu.get_node("ReferenceCanvas/Settings") as Button).grab_focus()
			for i in 3:
				await process_frame
			var settings_image := root.get_viewport().get_texture().get_image()
			var settings_result := settings_image.save_png("res://docs/main_menu_settings_focus_1672x941.png")
			print("settings focus capture: ", settings_result)
			(menu.get_node("ReferenceCanvas/Continue") as Button).grab_focus()
	quit()
