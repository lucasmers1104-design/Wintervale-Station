## Automatischer Test für Gleisbau, Geländeanpassung, Weichen, Signale,
## Blocklogik, Speichern/Laden und die Tastenlegende (läuft headless).
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/railway_test.tscn
## Exit-Code 0 = alles bestanden.
extends Node

var failures := 0
var main: Node3D
var terrain: LowPolyTerrain
var network: RailNetwork
var interlocking: RailInterlocking
var view: RailNetworkView
var build: BuildMode
var hill_segment_id := -1


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	_use_empty_map(main)
	terrain = main.get_node("World/Terrain")
	network = main.get_node("World/Railway/RailNetwork")
	interlocking = main.get_node("World/Railway/RailInterlocking")
	view = main.get_node("World/Railway/RailNetworkView")
	build = main.get_node("BuildMode")
	await frames(10)

	build.set_active(true)
	await _test_terrain_adaptation()
	await _test_switches()
	await _test_signals()
	_test_interlocking_invariant()
	await _test_save_load()
	await _test_legend()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Geländeanpassung -------------------------------------------------------------

func _test_terrain_adaptation() -> void:
	print("--- Terrain")
	var tool: RailPlaceTool = build.get_tool(&"rail")
	build.select_tool(&"rail")

	# Hügelige, hindernisfreie Strecke suchen (außerhalb der flachen Mitte)
	var found := false
	var start := Vector3.ZERO
	var target := Vector3.ZERO
	var relief := 0.0
	for step in 48:
		var angle := TAU * step / 48.0
		start = Vector3(cos(angle), 0.0, sin(angle)) * 30.0
		target = Vector3(cos(angle), 0.0, sin(angle)) * 76.0
		tool.cancel()
		tool.click_at(start, true)
		tool.preview_at(target, true)
		if not tool.is_candidate_valid():
			continue
		relief = _relief(tool.get_candidate().curve)
		if relief > 1.2:
			found = true
			break
	check(found, "hilly obstacle-free route found (relief %.2f m)" % relief)
	if not found:
		tool.cancel()
		return

	var candidate := tool.get_candidate()
	check(RailGeometry.max_grade(candidate.curve) <= RailConfig.MAX_GRADE * 1.15,
		"planned profile respects max grade (%.3f)" % RailGeometry.max_grade(candidate.curve))
	check(candidate.max_earthwork <= RailConfig.MAX_EARTHWORK, "earthwork within limit (%.2f m)" % candidate.max_earthwork)

	# Vorschau formt das Gelände schon vor dem Bauen (sobald die Maus kurz ruht)
	build.set_process(false)
	tool.preview_at(target, true)
	tool._settle_timer = 1.0
	tool.preview_at(target, true)
	terrain.flush_changes()
	build.set_process(true)
	var mid := candidate.curve.sample_baked(candidate.get_length() * 0.5, true)
	var preview_error := absf(terrain.get_height(mid.x, mid.z) - (mid.y - TerrainDeformer.GROUND_OFFSET))
	check(preview_error < 0.02, "preview adapts terrain (error %.3f m)" % preview_error)

	var t0 := Time.get_ticks_usec()
	check(tool.click_at(target, true), "hill track built (%s)" % tool.get_status())
	tool.cancel()
	terrain.flush_changes()
	print("      terrain rebuild after build: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var segment: RailSegment = network.get_segments()[-1]
	hill_segment_id = segment.id

	var max_error := 0.0
	var max_fill := 0.0
	for p in segment.axis_points:
		max_error = maxf(max_error, absf(terrain.get_height(p.x, p.z) - (p.y - TerrainDeformer.GROUND_OFFSET)))
		max_fill = maxf(max_fill, absf(terrain.get_base_height(p.x, p.z) - p.y))
	check(max_error < 0.02, "terrain follows track axis (max error %.3f m)" % max_error)
	check(max_fill > 0.25, "terrain was really reshaped (max cut/fill %.2f m)" % max_fill)

	# Echte Kollision des Geländes: kein Schweben, kein Versinken
	await frames(3)
	var space := main.get_world_3d().direct_space_state
	var worst := 0.0
	for i in range(2, segment.axis_points.size() - 2):
		var p := segment.axis_points[i]
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0, GameDefs.LAYER_WORLD)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			worst = INF
			break
		worst = maxf(worst, absf((hit["position"] as Vector3).y - (p.y - TerrainDeformer.GROUND_OFFSET)))
	check(worst < 0.35, "terrain collision matches track bed (max %.2f m)" % worst)

	# Weiter weg bleibt das Gelände unberührt
	var tangent := RailGeometry.flat(segment.get_start_direction()).normalized()
	var side := tangent.cross(Vector3.UP)
	var far := segment.curve.sample_baked(segment.length * 0.5, true) + side * (TerrainDeformer.MAX_INFLUENCE + 1.0)
	check(is_equal_approx(terrain.get_height(far.x, far.z), terrain.get_base_height(far.x, far.z)),
		"terrain far from track unchanged")

	var tree_errors := (main.get_node("World/Nature") as PropScatter).get_instance_ground_errors()
	var worst_tree := 0.0
	for error in tree_errors:
		worst_tree = maxf(worst_tree, absf(error))
	check(worst_tree < 0.01, "trees and rocks sit on adapted terrain (max %.3f m)" % worst_tree)

	# Entfernen und Undo stellen das Gelände korrekt wieder her
	var probe := segment.curve.sample_baked(segment.length * 0.5, true)
	var adapted := terrain.get_height(probe.x, probe.z)
	build.select_tool(&"remove")
	(build.get_tool(&"remove") as RailRemoveTool).remove_at(probe)
	terrain.flush_changes()
	check(network.get_segment(hill_segment_id) == null, "hill track removed")
	check(is_equal_approx(terrain.get_height(probe.x, probe.z), terrain.get_base_height(probe.x, probe.z)),
		"terrain restored after removal")
	build.undo()
	terrain.flush_changes()
	check(absf(terrain.get_height(probe.x, probe.z) - adapted) < 0.001, "undo re-applies terrain adaptation")
	build.select_tool(&"rail")


func _relief(curve: Curve3D) -> float:
	var low := INF
	var high := -INF
	for p in RailGeometry.polyline(curve, 2.0):
		var h := terrain.get_base_height(p.x, p.z)
		low = minf(low, h)
		high = maxf(high, h)
	return high - low


# --- Weichen ----------------------------------------------------------------------

var trunk_id := -1
var straight_id := -1
var branch_id := -1
var switch_node := -1


func _test_switches() -> void:
	print("--- Switches")
	var rail: RailPlaceTool = build.get_tool(&"rail")
	build.select_tool(&"rail")
	rail.click_at(Vector3(10, 0, 16))
	check(rail.click_at(Vector3(10, 0, -16)), "main line built (%s)" % rail.get_status())
	rail.cancel()
	var count_before := network.get_segment_count()

	build.select_tool(&"switch")
	var tool: SwitchTool = build.get_tool(&"switch")
	check(tool.click_at(Vector3(10.4, 0, 8)), "switch start on track (%s)" % tool.get_status())
	tool.preview_at(Vector3(10.5, 0, -8))
	check(not tool.is_candidate_valid(), "straight branch rejected (%s)" % tool.get_status())
	tool.preview_at(Vector3(11.5, 0, 2))
	check(not tool.is_candidate_valid(), "too short branch rejected (%s)" % tool.get_status())
	var placed := tool.click_at(Vector3(14.5, 0, -8))
	check(placed, "switch with diverging branch built (%s)" % tool.get_status())
	tool.cancel()
	check(network.get_segment_count() == count_before + 2, "track split + branch = 2 more segments")

	var switches := network.get_switches()
	check(switches.size() == 1, "one switch in network")
	if switches.is_empty():
		return
	var switch := switches[0]
	switch_node = switch.node_id
	trunk_id = switch.trunk_segment_id
	straight_id = switch.branch_segment_ids[0]
	branch_id = switch.branch_segment_ids[1]
	check(network.get_rail_node(switch_node).get_connection_type() == RailNode.ConnectionType.SWITCH,
		"node connection type is SWITCH")
	check(network.get_segment(straight_id).kind == RailSegment.Kind.STRAIGHT, "branch 0 is the straight track")
	check(network.get_segment(trunk_id).end_connection == RailNode.ConnectionType.SWITCH
		or network.get_segment(trunk_id).start_connection == RailNode.ConnectionType.SWITCH, "trunk knows switch connection")
	check(_same(network.get_next_segments(trunk_id, switch_node), [straight_id]), "state 0 routes to straight")
	check(network.get_next_segments(branch_id, switch_node).is_empty(), "trailing against switch is blocked")
	check(network.get_next_segments(trunk_id, switch_node, false).size() == 2, "both routes known without state")

	var switch_view := view.get_switch_view(switch_node)
	check(switch_view != null, "switch model built")
	var blade_before := switch_view.get_blade_angle(0) if switch_view else 0.0
	check(interlocking.request_switch_toggle(switch_node) == "", "switch toggled")
	check(_same(network.get_next_segments(trunk_id, switch_node), [branch_id]), "state 1 routes to branch")
	check(_same(network.get_next_segments(branch_id, switch_node), [trunk_id]), "branch leads back to trunk")
	check(switch_view and switch_view.is_animating(), "switch animation running")
	await frames(60)
	check(switch_view and not is_equal_approx(switch_view.get_blade_angle(0), blade_before), "switch blades moved")

	tool.click_at(Vector3(10.4, 0, 4))
	check(tool.get_status() == "Zu nah an einer anderen Weiche", "switch too close rejected (%s)" % tool.get_status())
	tool.cancel()

	build.undo()
	check(network.get_switches().is_empty() and network.get_segment_count() == count_before, "undo removes switch")
	build.redo()
	check(network.get_switches().size() == 1, "redo restores switch")
	check(network.get_switch(switch_node) and network.get_switch(switch_node).state == 1, "switch state remembered")
	interlocking.request_switch_toggle(switch_node)
	check(network.get_switch(switch_node).state == 0, "switch back to straight")


# --- Signale & Blöcke -------------------------------------------------------------

var s1 := -1
var s2 := -1


func _test_signals() -> void:
	print("--- Signals")
	build.select_tool(&"signal")
	var tool: SignalTool = build.get_tool(&"signal")
	var blocks_before := network.get_block_ids().size()
	var plan := tool.plan_signal(Vector3(12.5, 0, 12))
	check(plan.get("reason", "?") == "" and plan.get("forward", false) == true,
		"signal planned for travel towards the switch (%s)" % plan.get("reason", "?"))
	check(tool.place_at(Vector3(12.5, 0, 12)), "signal 1 placed")
	check(tool.place_at(Vector3(7.5, 0, -12)), "signal 2 placed (opposite direction)")
	check(network.get_signals().size() == 2, "two signals in network")
	check(not tool.place_at(Vector3(12.5, 0, 12)), "no second signal at the same spot")
	var signals := network.get_signals()
	s1 = signals[0].id
	s2 = signals[1].id
	check(network.get_block_ids().size() == blocks_before + 2, "signals split the line into blocks")
	check(view.get_signal_view(s1) != null and view.get_signal_view(s2) != null, "signal models built")
	# Signale teilen Gleise – die IDs rund um die Weiche neu abfragen
	var switch := network.get_switch(switch_node)
	trunk_id = switch.trunk_segment_id
	straight_id = switch.branch_segment_ids[0]
	branch_id = switch.branch_segment_ids[1]

	interlocking.evaluate()
	var sig1 := network.get_signal(s1)
	var sig2 := network.get_signal(s2)
	check(sig1.aspect == RailSignal.Aspect.CLEAR, "signal 1 green on free line (%s)" % sig1.reason)
	check(sig2.aspect == RailSignal.Aspect.STOP and sig2.reason.begins_with("Fahrweg von Signal"),
		"opposing signal 2 red – conflict detected (%s)" % sig2.reason)
	await frames(2)
	check(view.get_signal_view(s1).get_aspect() == RailSignal.Aspect.CLEAR, "signal 1 model shows green")

	# Blockbelegung
	interlocking.set_segment_occupied(straight_id, true)
	var route := interlocking.get_route(s1)
	check(sig1.aspect == RailSignal.Aspect.STOP, "occupied block turns signal 1 red")
	check(route != null and route.entered, "route marked as entered")
	check(interlocking.request_switch_toggle(switch_node) != "", "switch locked while its block is occupied")
	interlocking.set_segment_occupied(straight_id, false)
	check(sig1.aspect == RailSignal.Aspect.CLEAR, "freed block turns signal 1 green again")

	# Halt / Automatik
	network.set_signal_mode(s1, RailSignal.Mode.HALT)
	check(sig1.aspect == RailSignal.Aspect.STOP and sig2.aspect == RailSignal.Aspect.CLEAR,
		"signal 1 on halt releases route, signal 2 gets green (%s)" % sig2.reason)
	network.set_signal_mode(s2, RailSignal.Mode.HALT)
	network.set_signal_mode(s1, RailSignal.Mode.AUTO)
	check(sig1.aspect == RailSignal.Aspect.CLEAR, "signal 1 green again")

	# Fahrweg folgt der Weiche
	check(interlocking.request_switch_toggle(switch_node) == "", "switch toggles on unentered auto route")
	interlocking.evaluate()
	route = interlocking.get_route(s1)
	check(route != null and route.segments.has(branch_id),
		"route now leads into diverging branch (%s, branch %d)" % [route.segments if route else [], branch_id])
	check(sig1.aspect == RailSignal.Aspect.CLEAR, "signal 1 green via branch")
	interlocking.request_switch_toggle(switch_node)
	network.set_signal_mode(s2, RailSignal.Mode.AUTO)
	interlocking.evaluate()

	# Remove + undo signal
	build.select_tool(&"remove")
	var remover: RailRemoveTool = build.get_tool(&"remove")
	var mast := network.get_signal_transform(network.get_signal(s2)).origin
	check(remover.remove_at(mast), "signal removed with remove tool")
	check(network.get_signal(s2) == null, "signal 2 gone")
	build.undo()
	check(network.get_signal(s2) != null, "undo restores signal 2")
	build.select_tool(&"test")
	var simulation: SimulationTool = build.get_tool(&"test")
	check(simulation.describe(mast).begins_with("Signal"), "test tool describes signal")
	var p := network.get_segment(straight_id).curve.sample_baked(5.0, true)
	simulation.click_at(p)
	check(interlocking.is_segment_occupied(straight_id), "test tool occupies track")
	await frames(2)
	check(view.get_segment_view(straight_id).get_overlay_material() != null, "occupied track highlighted")
	simulation.click_at(p)
	check(not interlocking.is_segment_occupied(straight_id), "test tool frees track")


## Zufällige Belegungen, Weichen- und Signalwechsel – die Sicherheitsregeln
## müssen immer gelten.
func _test_interlocking_invariant() -> void:
	print("--- Interlocking invariant (random)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var segments := network.get_segments()
	var violations := 0
	var greens := 0
	for i in 400:
		var action := rng.randi() % 4
		if action == 0:
			var segment := segments[rng.randi() % segments.size()]
			interlocking.set_segment_occupied(segment.id, not interlocking.is_segment_occupied(segment.id))
		elif action == 1 and switch_node >= 0:
			interlocking.request_switch_toggle(switch_node)
		elif action == 2:
			var rail_signal := network.get_signals()[rng.randi() % network.get_signals().size()]
			network.set_signal_mode(rail_signal.id, RailSignal.Mode.HALT if rng.randf() < 0.3 else RailSignal.Mode.AUTO)
		interlocking.evaluate()
		violations += _count_violations()
		for rail_signal in network.get_signals():
			if rail_signal.aspect == RailSignal.Aspect.CLEAR:
				greens += 1
	check(violations == 0, "no conflicting green signals in 400 random steps (%d violations)" % violations)
	check(greens > 0, "signals did turn green during the random test (%d)" % greens)
	for segment in segments:
		interlocking.set_segment_occupied(segment.id, false)
	for rail_signal in network.get_signals():
		network.set_signal_mode(rail_signal.id, RailSignal.Mode.AUTO)


func _count_violations() -> int:
	var violations := 0
	var used := {}
	for rail_signal in network.get_signals():
		if rail_signal.aspect != RailSignal.Aspect.CLEAR:
			continue
		var route := interlocking.get_route(rail_signal.id)
		if route == null:
			violations += 1
			continue
		for block_id in route.blocks:
			if interlocking.is_block_occupied(block_id) or used.has(block_id) \
					or interlocking.get_block_owner(block_id) != rail_signal.id:
				violations += 1
			used[block_id] = true
		for node_id: int in route.switch_positions:
			if network.get_switch(node_id).state != route.switch_positions[node_id]:
				violations += 1
	return violations


# --- Speichern & Laden ---------------------------------------------------------------

func _test_save_load() -> void:
	print("--- Save/Load")
	interlocking.set_segment_occupied(branch_id, true)
	interlocking.request_switch_toggle(switch_node)
	network.set_signal_mode(s2, RailSignal.Mode.HALT)
	interlocking.evaluate()
	var hill := network.get_segment(hill_segment_id)
	var probe := hill.curve.sample_baked(hill.length * 0.5, true) if hill else Vector3.ZERO
	var height_before := terrain.get_height(probe.x, probe.z)
	var segments_before := network.get_segment_count()
	var blocks_before := network.get_block_ids().size()
	var state_before := network.get_switch(switch_node).state
	var hill_heights := hill.heights.duplicate() if hill else PackedFloat32Array()

	SaveManager.delete_save("railtest")
	check(SaveManager.save_game("railtest"), "save ok")
	network.clear()
	interlocking.set_segment_occupied(branch_id, false)
	terrain.flush_changes()
	check(network.get_segment_count() == 0, "network cleared")
	check(is_equal_approx(terrain.get_height(probe.x, probe.z), terrain.get_base_height(probe.x, probe.z)),
		"terrain adaptation gone with network")
	check(SaveManager.load_game("railtest"), "load ok")
	terrain.flush_changes()
	check(network.get_segment_count() == segments_before, "all segments restored (%d)" % network.get_segment_count())
	check(network.get_block_ids().size() == blocks_before, "blocks rebuilt")
	check(network.get_switch(switch_node) and network.get_switch(switch_node).state == state_before, "switch state restored")
	check(network.get_signal(s2) and network.get_signal(s2).mode == RailSignal.Mode.HALT, "signal mode restored")
	check(network.get_signal(s1) and network.get_signal(s1).segment_id == network.get_signal(s1).segment_id, "signal binding restored")
	check(interlocking.is_segment_occupied(branch_id), "test occupancy restored")
	var hill_after := network.get_segment(hill_segment_id)
	check(hill_after != null and hill_after.heights == hill_heights, "track height profile restored exactly")
	check(absf(terrain.get_height(probe.x, probe.z) - height_before) < 0.001, "terrain adaptation restored after load")
	await frames(2)
	check(view.get_switch_view(switch_node) != null and view.get_signal_view(s1) != null, "switch & signal models rebuilt")
	SaveManager.delete_save("railtest")
	interlocking.set_segment_occupied(branch_id, false)


# --- Tastenlegende ----------------------------------------------------------------

func _test_legend() -> void:
	print("--- Legend")
	var hud: GameHUD = main.get_node("HUD")
	var legend := hud.get_legend()
	var vmc: ViewModeController = main.get_node("ViewModeController")

	for mode: StringName in InputConfig.LEGENDS:
		for entry: Dictionary in InputConfig.LEGENDS[mode]:
			for action: StringName in entry.get("actions", []):
				if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
					check(false, "legend action '%s' is bound" % action)
	check(true, "all legend actions exist in the input map")

	build.select_tool(&"signal")
	await frames(1)
	check(legend.get_mode() == &"build_signal", "legend follows build tool (%s)" % legend.get_mode())
	check(_legend_has(legend, "Signal setzen", ["Linksklick"]), "build legend shows signal placement")
	check(_legend_has(legend, "Rückgängig", ["Strg+Z"]), "build legend shows Strg+Z")
	check(_legend_has(legend, "Bahn-Werkzeug", ["1", "2", "3", "4", "5"]), "build legend shows tool keys 1–5")
	check(_legend_has(legend, "Dorf bauen", ["6", "7", "8", "9", "0"]), "build legend shows village keys 6–0")
	build.select_tool(&"switch")
	check(_legend_has(legend, "Auf Weiche: umstellen", ["Linksklick"]), "legend shows switch controls")

	build.set_active(false)
	await frames(1)
	check(legend.get_mode() == &"bird_eye", "legend shows bird view keys")
	check(_legend_has(legend, "Drehen", ["Q", "E"]), "bird legend shows Q/E")
	vmc.set_mode(GameDefs.ViewMode.EXPLORE, true)
	await frames(2)
	check(legend.get_mode() == &"explore", "legend switches to explore mode")
	check(_legend_has(legend, "Gehen", ["W", "A", "S", "D"]), "explore legend shows WASD")
	check(_legend_has(legend, "Springen", ["Leertaste"]), "explore legend shows jump key")

	await frames(2)
	var screen := hud.get_viewport().get_visible_rect()
	var rect := legend.get_global_rect()
	check(screen.encloses(rect), "legend fully on screen")
	check(rect.position.x > screen.size.x * 0.5 and rect.position.y > screen.size.y * 0.4,
		"legend sits bottom right (%s)" % rect)
	check(rect.size.y < screen.size.y * 0.35, "legend is compact (%.0f px high)" % rect.size.y)
	legend.set_expanded(false)
	await frames(1)
	check(legend.get_global_rect().size.y < rect.size.y, "legend collapses")
	legend.set_expanded(true)


func _legend_has(legend: KeyLegend, text: String, keys: Array) -> bool:
	for row in legend.get_rows():
		if row["text"] == text:
			var shown: Array = row["keys"]
			return shown == keys
	return false


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


## Diese Tests prüfen den Bau auf leerer Karte: Startstrecke entfernen, Zugbetrieb aus.
func _use_empty_map(scene: Node) -> void:
	(scene.get_node("World/Railway/TrainDispatcher") as TrainDispatcher).enabled = false
	(scene.get_node("World/Railway/RailNetwork") as RailNetwork).clear()
	(scene.get_node("World/Terrain") as LowPolyTerrain).flush_changes()
