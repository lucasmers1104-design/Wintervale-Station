extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: Node = scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var canvas := menu.get_node("ReferenceCanvas")
	var expected := ["Continue", "NewGame", "LoadSave", "Settings", "Achievements", "Credits", "Quit"]
	for label in expected:
		var button := canvas.get_node_or_null(label) as Button
		if button == null or not button.focus_mode == Control.FOCUS_ALL:
			push_error("Menu button missing or not focusable: " + label)
			quit(1)
			return
	print("Seven focusable buttons found")
	(canvas.get_node("NewGame") as Button).pressed.emit()
	await process_frame
	if current_scene == null or current_scene.name != "Main":
		push_error("New Game did not enter the existing game scene")
		quit(1)
		return
	print("New Game opened the existing game scene")
	quit()
