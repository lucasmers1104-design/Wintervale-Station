## Automatischer Smoke-Test der Grundfunktionen (läuft headless, ohne Grafik).
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
## Exit-Code 0 = alles bestanden. Prüft Normalen-Orientierung, Spielfigur,
## Ansichtswechsel, Tag/Nacht mit Laternen, Speichern/Laden sowie das
## Gleis-Bausystem (Planung, Einrasten, Prüfregeln, Entfernen, Undo/Redo).
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
	_test_geometry()

	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	_use_empty_map(main)
	var player: PlayerController = main.get_node("Player")
	var terrain: LowPolyTerrain = main.get_node("World/Terrain")
	var vmc: ViewModeController = main.get_node("ViewModeController")
	var bird: BirdEyeCamera = main.get_node("BirdEyeCamera")

	await frames(2)
	check(vmc.mode == GameDefs.ViewMode.BIRD_EYE, "game starts in bird eye view")
	check(get_viewport().get_camera_3d() == bird.camera, "bird camera current at start")
	var model: CharacterModel = player.get_node("Model")
	check(model.get_mesh_count() >= 15, "character model built (%d parts)" % model.get_mesh_count())

	vmc.set_mode(GameDefs.ViewMode.EXPLORE, true)
	await frames(120)
	var ground := terrain.get_height(player.global_position.x, player.global_position.z)
	check(player.is_on_floor(), "player lands on terrain")
	check(absf(player.global_position.y - ground) < 0.3, "player at ground height")
	check(get_viewport().get_camera_3d() == player.get_camera(), "player camera current")

	var start := player.global_position
	Input.action_press(&"move_forward")
	await frames(60)
	Input.action_release(&"move_forward")
	check(player.global_position.z < start.z - 1.5, "player walks forward (-Z)")

	var nature := main.get_node("World/Nature")
	var instances := 0
	for child in nature.get_children():
		if child is MultiMeshInstance3D:
			instances += (child as MultiMeshInstance3D).multimesh.instance_count
	check(instances > 300, "nature scattered (%d)" % instances)

	vmc.toggle()
	check(vmc.mode == GameDefs.ViewMode.BIRD_EYE, "toggle to bird eye")
	check(not player.input_enabled, "player input disabled in bird eye")
	await frames(90)
	check(get_viewport().get_camera_3d() == bird.camera, "bird camera current after blend")
	vmc.toggle()
	await frames(90)
	check(get_viewport().get_camera_3d() == player.get_camera(), "back to player camera")

	player.set_first_person(true)
	await frames(60)
	var eye := player.global_position + Vector3(0, CharacterModel.EYE_HEIGHT, 0)
	check(player.get_camera().global_position.distance_to(eye) < 0.3, "first person camera at eye")
	player.set_first_person(false)

	# Tag / Nacht
	var lantern: Lantern = main.get_node("World/TestArea/LanternA")
	WorldClock.set_time(20.0)
	await frames(240)
	check(lantern.is_lit(), "lantern lit at night")
	var sun: DirectionalLight3D = main.get_node("DayNightCycle/Sun")
	check(not sun.visible, "sun hidden at night")
	WorldClock.set_time(12.0)
	await frames(240)
	check(not lantern.is_lit(), "lantern off at noon")
	for part in ["FrameBottom", "FrameTop", "Roof", "SnowCap", "Glass"]:
		var mesh: MeshInstance3D = lantern.get_node(part)
		check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "lantern %s casts no shadow" % part)

	await _test_building(main)

	# Speichern / Laden (inkl. Gleisnetz)
	var network: RailNetwork = main.get_node("World/Railway/RailNetwork")
	var view: RailNetworkView = main.get_node("World/Railway/RailNetworkView")
	vmc.set_mode(GameDefs.ViewMode.EXPLORE, true)
	await frames(2)
	SaveManager.delete_save("devtest")
	var saved_pos := player.global_position
	var saved_segments := network.get_segment_count()
	WorldClock.set_time(9.25)
	check(SaveManager.save_game("devtest"), "save ok")
	player.global_position += Vector3(10, 5, 10)
	WorldClock.set_time(22.0)
	network.clear()
	vmc.set_mode(GameDefs.ViewMode.BIRD_EYE, true)
	check(network.get_segment_count() == 0, "network cleared")
	check(SaveManager.load_game("devtest"), "load ok")
	check(player.global_position.distance_to(saved_pos) < 0.01, "player position restored")
	check(absf(WorldClock.time_of_day - 9.25) < 0.01, "time restored")
	check(vmc.mode == GameDefs.ViewMode.EXPLORE, "view mode restored")
	check(network.get_segment_count() == saved_segments, "rail network restored (%d)" % network.get_segment_count())
	await frames(2)
	check(view.get_buffer_stop_count() == 2, "buffer stops restored")
	SaveManager.delete_save("devtest")

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_geometry() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0, 0, 0)
	var b := Vector3(1, 0, 0)
	var c := Vector3(0, 0, 1)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.generate_normals()
	var godot_n: Vector3 = st.commit_to_arrays()[Mesh.ARRAY_NORMAL][0]
	check(godot_n.is_equal_approx(LowPolyBuilder.face_normal(a, b, c)), "face_normal matches Godot winding")

	# Kreisbogen schließt tangential an und endet in der erwarteten Richtung
	var forward := Vector3(0, 0, -1)
	var target := Vector3(6, 0, -20)
	var arc := RailPlanner.plan(Vector3.ZERO, forward, target, Vector3.ZERO)
	check(arc.error == "" and arc.kind == RailSegment.Kind.CURVE, "arc planned")
	var expected_end := forward.rotated(Vector3.UP, 2.0 * forward.signed_angle_to(target, Vector3.UP))
	var actual_end := RailGeometry.tangent_at(arc.curve, arc.get_length())
	check(actual_end.dot(expected_end) > 0.999, "arc end tangent correct")
	check(RailGeometry.tangent_at(arc.curve, 0.0).dot(forward) > 0.999, "arc start tangent correct")
	check(absf(RailGeometry.min_radius(arc.curve) - 1.0 / (2.0 * sin(forward.angle_to(target)) / target.length())) < 1.0,
		"arc radius matches circle")

	var tight := RailPlanner.plan(Vector3.ZERO, forward, Vector3(10, 0, -2), Vector3.ZERO)
	check(tight.error != "", "too tight curve rejected (%s)" % tight.error)

	var snapped := RailPlanner.plan(Vector3.ZERO, Vector3.ZERO, Vector3(10, 0, -9.5), Vector3.ZERO)
	var dir := RailGeometry.flat(snapped.get_end()).normalized()
	check(is_equal_approx(fmod(rad_to_deg(atan2(dir.x, dir.z)) + 360.0, 15.0), 0.0)
		or is_equal_approx(fmod(rad_to_deg(atan2(dir.x, dir.z)) + 360.0, 15.0), 15.0), "free straight snaps to 15°")


func _test_building(main: Node) -> void:
	var build: BuildMode = main.get_node("BuildMode")
	var vmc: ViewModeController = main.get_node("ViewModeController")
	var network: RailNetwork = main.get_node("World/Railway/RailNetwork")
	var view: RailNetworkView = main.get_node("World/Railway/RailNetworkView")

	build.set_active(true)
	check(build.active and vmc.mode == GameDefs.ViewMode.BIRD_EYE, "build mode switches to bird eye")
	await frames(60)
	var tool: RailPlaceTool = build.get_tool(&"rail")
	check(build.get_current_tool() == tool, "rail tool is default")

	# Gerade + Kurve als Kette
	check(tool.click_at(Vector3(10, 0, 10)), "start point set")
	var placed := tool.click_at(Vector3(10, 0, -10))
	check(placed, "straight placed (%s)" % tool.get_status())
	placed = tool.click_at(Vector3(12, 0, -20))
	check(placed, "chained curve placed (%s)" % tool.get_status())
	tool.cancel()
	check(network.get_segment_count() == 2, "2 segments")
	check(network.get_nodes().size() == 3, "3 nodes")

	var straight := network.get_segments()[0]
	var curve := network.get_segments()[1]
	if straight.kind != RailSegment.Kind.STRAIGHT:
		var tmp := straight
		straight = curve
		curve = tmp
	check(straight.kind == RailSegment.Kind.STRAIGHT and curve.kind == RailSegment.Kind.CURVE, "segment kinds")
	check(straight.end_neighbors.size() == 1 and straight.end_neighbors[0] == curve.id
		and curve.start_neighbors.size() == 1 and curve.start_neighbors[0] == straight.id, "neighbors linked")
	check(straight.end_connection == RailNode.ConnectionType.JOINT, "joint connection type")
	check(curve.end_connection == RailNode.ConnectionType.END, "open end connection type")
	check(absf(straight.length - 20.0) < 0.1, "straight length 20 m (%.2f)" % straight.length)
	check(straight.get_end_direction().dot(curve.get_start_direction()) > 0.999, "tangent continuity at joint")
	await frames(2)
	check(view.get_buffer_stop_count() == 2, "buffer stops at both open ends")

	# Einrasten am offenen Ende und gerade weiterbauen
	check(tool.click_at(Vector3(10.6, 0, 10.8)), "start snapped to open end")
	placed = tool.click_at(Vector3(10.5, 0, 22))
	check(placed, "extension placed (%s)" % tool.get_status())
	tool.cancel()
	check(network.get_segment_count() == 3, "3 segments after extension")
	build.undo()
	check(network.get_segment_count() == 2, "undo removes extension")

	# Prüfregeln
	tool.click_at(Vector3(-9.5, 0, 10))
	tool.preview_at(Vector3(-9.5, 0, -2))
	check(not tool.is_candidate_valid() and tool.get_status() == "Hindernis im Weg",
		"obstacle blocks (%s)" % tool.get_status())
	tool.cancel()
	tool.click_at(Vector3(12.5, 0, 8))
	tool.preview_at(Vector3(12.5, 0, -8))
	check(not tool.is_candidate_valid() and tool.get_status() == "Zu nah an einem Gleis",
		"too close blocks (%s)" % tool.get_status())
	tool.cancel()
	tool.click_at(Vector3(3.8, 0, 5))
	tool.preview_at(Vector3(3.8, 0, -20))
	check(tool.is_candidate_valid(), "track along platform edge allowed (%s)" % tool.get_status())
	tool.cancel()
	tool.click_at(Vector3(2.5, 0, 5))
	tool.preview_at(Vector3(2.5, 0, -20))
	check(not tool.is_candidate_valid(), "track through platform blocked (%s)" % tool.get_status())
	tool.cancel()
	tool.click_at(Vector3(25, 0, 10))
	tool.preview_at(Vector3(25, 0, 9))
	check(not tool.is_candidate_valid(), "too short blocks (%s)" % tool.get_status())
	tool.cancel()

	# Entfernen + Undo/Redo
	build.select_tool(&"remove")
	var remover: RailRemoveTool = build.get_tool(&"remove")
	check(remover.remove_at(Vector3(11.5, 0, -17)), "segment removed")
	check(network.get_segment_count() == 1, "1 segment left")
	build.undo()
	check(network.get_segment_count() == 2, "undo restores segment")
	check(network.get_segment(curve.id) != null, "restored with same id")
	build.redo()
	check(network.get_segment_count() == 1, "redo removes again")
	build.undo()
	check(network.get_segment_count() == 2, "undo again")
	build.select_tool(&"rail")

	build.set_active(false)
	check(not build.active, "build mode off")


## Diese Tests prüfen den Bau auf leerer Karte: Startstrecke entfernen, Zugbetrieb aus.
func _use_empty_map(scene: Node) -> void:
	(scene.get_node("World/Railway/TrainDispatcher") as TrainDispatcher).enabled = false
	(scene.get_node("World/Railway/RailNetwork") as RailNetwork).clear()
	# Etappe 8: Der Güterbahnhof steht dort, wo diese Tests ihre Testgleise bauen
	var yard := scene.get_node_or_null("World/FreightYard")
	if yard:
		yard.get_parent().remove_child(yard)
		yard.queue_free()
	(scene.get_node("World/Terrain") as LowPolyTerrain).flush_changes()
