## Aufnahme beider wählbaren Spielfiguren (New-Game-Menü) im Spiel.
## Start: godot --path . --resolution 1672x941 -s res://tests/qa/character_capture.gd -- <ordner>
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0].trim_suffix("/") + "/"
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await process_frame
	root.get_node(^"/root/WorldClock").call("set_time", 11.5)
	root.get_node(^"/root/WorldClock").set("paused", true)
	main.get_node(^"HUD").visible = false
	var player: Node3D = main.get_node(^"Player")
	var camera := Camera3D.new()
	camera.fov = 45.0
	main.add_child(camera)
	for id in ["male", "female"]:
		player.call("set_character", id)
		for i in 5:
			await process_frame
		var model: Node3D = player.get_node(^"Model")
		var face := -model.global_basis.z
		face.y = 0.0
		face = face.normalized() if face.length() > 0.1 else Vector3.FORWARD
		var p := player.global_position
		camera.global_position = p + face.rotated(Vector3.UP, 0.45) * 2.8 + Vector3.UP * 1.2
		camera.look_at(p + Vector3.UP * 0.75, Vector3.UP)
		camera.make_current()
		for i in 15:
			await process_frame
		print(id, ": ", error_string(root.get_viewport().get_texture().get_image().save_png(out + "player_" + id + ".png")))
	quit()
