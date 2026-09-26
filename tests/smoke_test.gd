## Automatischer Smoke-Test der Grundfunktionen (läuft headless, ohne Grafik).
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
## Exit-Code 0 = alles bestanden. Prüft Normalen-Orientierung, Landung und
## Laufen der Figur, Ansichtswechsel, Ego-Perspektive, Tag/Nacht mit Laternen
## sowie Speichern und Laden.
extends Node

var failures := 0


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	# 1) Winding: unsere Normale == Godots generate_normals
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0, 0, 0)
	var b := Vector3(1, 0, 0)
	var c := Vector3(0, 0, 1)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	var godot_n: Vector3 = arrays[Mesh.ARRAY_NORMAL][0]
	var ours := LowPolyBuilder.face_normal(a, b, c)
	print("godot normal ", godot_n, " ours ", ours)
	check(godot_n.is_equal_approx(ours), "face_normal matches Godot winding")

	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	var player: PlayerController = main.get_node("Player")
	var terrain: LowPolyTerrain = main.get_node("World/Terrain")
	var vmc: ViewModeController = main.get_node("ViewModeController")
	var bird: BirdEyeCamera = main.get_node("BirdEyeCamera")

	await frames(120)
	var ground := terrain.get_height(player.global_position.x, player.global_position.z)
	print("player y ", player.global_position.y, " ground ", ground)
	check(player.is_on_floor(), "player lands on terrain")
	check(absf(player.global_position.y - ground) < 0.3, "player at ground height")
	check(get_viewport().get_camera_3d() == player.get_camera(), "player camera current")

	# Walk forward
	var start := player.global_position
	Input.action_press(&"move_forward")
	await frames(60)
	Input.action_release(&"move_forward")
	print("moved ", player.global_position - start)
	check(player.global_position.z < start.z - 1.5, "player walks forward (-Z)")

	# Tree/prop count
	var nature := main.get_node("World/Nature")
	var instances := 0
	for child in nature.get_children():
		if child is MultiMeshInstance3D:
			instances += (child as MultiMeshInstance3D).multimesh.instance_count
	print("nature instances ", instances)
	check(instances > 300, "nature scattered")

	# Toggle view
	vmc.toggle()
	check(vmc.mode == GameDefs.ViewMode.BIRD_EYE, "mode bird eye")
	check(not player.input_enabled, "player input disabled in bird eye")
	await frames(90)
	check(get_viewport().get_camera_3d() == bird.camera, "bird camera current after blend")
	check(bird.camera.global_position.y > player.global_position.y + 10.0, "bird camera above")
	vmc.toggle()
	await frames(90)
	check(get_viewport().get_camera_3d() == player.get_camera(), "back to player camera")

	# First person toggle
	player.set_first_person(true)
	await frames(60)
	var cam_dist := player.get_camera().global_position.distance_to(player.global_position + Vector3(0, 1.62, 0))
	print("fp cam dist ", cam_dist)
	check(cam_dist < 0.3, "first person camera at eye")
	player.set_first_person(false)

	# Night -> lanterns
	var lantern: Lantern = main.get_node("World/TestArea/LanternA")
	WorldClock.set_time(20.0)
	check(WorldClock.is_dark(), "dark at 20:00")
	await frames(240)
	check(lantern.is_lit(), "lantern lit at night")
	var sun: DirectionalLight3D = main.get_node("DayNightCycle/Sun")
	var moon: DirectionalLight3D = main.get_node("DayNightCycle/Moon")
	print("sun vis ", sun.visible, " moon energy ", moon.light_energy)
	check(not sun.visible and moon.light_energy > 0.1, "moon instead of sun at night")
	WorldClock.set_time(12.0)
	await frames(240)
	check(not lantern.is_lit(), "lantern off at noon")
	check(sun.visible and sun.light_energy > 0.5, "sun at noon")

	# Save/Load roundtrip
	SaveManager.delete_save("devtest")
	var saved_pos := player.global_position
	WorldClock.set_time(9.25)
	check(SaveManager.save_game("devtest"), "save ok")
	player.global_position += Vector3(10, 5, 10)
	WorldClock.set_time(22.0)
	vmc.set_mode(GameDefs.ViewMode.BIRD_EYE, true)
	check(SaveManager.load_game("devtest"), "load ok")
	check(player.global_position.distance_to(saved_pos) < 0.01, "player position restored")
	check(absf(WorldClock.time_of_day - 9.25) < 0.01, "time restored")
	check(vmc.mode == GameDefs.ViewMode.EXPLORE, "view mode restored")
	SaveManager.delete_save("devtest")

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
