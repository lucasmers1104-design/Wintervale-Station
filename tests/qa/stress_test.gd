## Stabilitäts- und Messtest (Master Debugging V2, Phase K).
##
## Start: godot --headless --path . -s res://tests/qa/stress_test.gd
## Misst CPU-Zeiten (headless, ohne GPU), Objektzahlen und verwaiste Nodes
## über wiederholte Wechsel Welt ↔ Hauptmenü sowie Speichern/Laden-Zyklen.
## Die Zahlen sind Messwerte dieses Rechners, keine FPS-Zusage.
extends SceneTree

const MAIN := "res://scenes/main/main.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS  ", message)
	else:
		push_error("FAIL  " + message)
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"memory_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
	}


func _open_world() -> Node:
	change_scene_to_file(MAIN)
	await _frames(40)
	return current_scene


func _run() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	var saves: Node = root.get_node(^"/root/SaveManager")
	var clock: Node = root.get_node(^"/root/WorldClock")
	settings.get("values")["reduced_motion"] = true
	settings.get("values")["achievement_notifications"] = false
	settings.get("values")["autosave"] = false

	var world := await _open_world()
	var first := _counts()
	print("world loaded: ", first)
	var started := Time.get_ticks_usec()
	settings.call("_route_audio_in", world)
	var route_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("audio bus routing walk: %.2f ms over %d nodes" % [route_ms, first["nodes"]])
	_check(route_ms < 16.0, "periodic audio routing walk fits in one frame (%.2f ms)" % route_ms)

	# Zeitraffer ×60: CPU-Zeit pro Frame (Prozess + Physik), headless gemessen
	clock.set("time_scale", 60.0)
	var worst := 0.0
	var total := 0.0
	for i in 300:
		await process_frame
		var frame := Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		worst = maxf(worst, frame)
		total += frame
	clock.set("time_scale", 1.0)
	print("x60 simulation: avg %.2f ms, worst %.2f ms CPU per frame (headless)" % [total / 300.0 * 1000.0, worst * 1000.0])

	# Speichern/Laden-Zyklen dürfen nichts verdoppeln
	saves.set("active_slot", "stress_probe")
	_check(saves.call("save_game", "stress_probe"), "save for reload cycles")
	await _frames(5)
	var before_cycles := _counts()
	for i in 5:
		_check(saves.call("load_game", "stress_probe"), "reload cycle %d" % (i + 1))
		await _frames(20)
	var after_cycles := _counts()
	print("after 5 reloads: ", after_cycles)
	_check(after_cycles["nodes"] <= before_cycles["nodes"] + 60,
		"reloading does not pile up nodes (%d -> %d)" % [before_cycles["nodes"], after_cycles["nodes"]])

	# Welt ↔ Hauptmenü mehrfach wechseln
	var baseline := {}
	for cycle in 3:
		change_scene_to_file(MENU)
		await _frames(20)
		var in_menu := _counts()
		print("cycle %d in menu: %s" % [cycle + 1, in_menu])
		if cycle == 0:
			baseline = in_menu
		world = await _open_world()
	change_scene_to_file(MENU)
	await _frames(20)
	var final := _counts()
	print("final in menu: ", final)
	_check(final["orphans"] <= baseline["orphans"] + 5,
		"no orphan nodes accumulate across scene changes (%d -> %d)" % [baseline["orphans"], final["orphans"]])
	_check(final["nodes"] <= baseline["nodes"] + 20,
		"menu node count stable after 3 world visits (%d -> %d)" % [baseline["nodes"], final["nodes"]])
	_check(final["objects"] <= baseline["objects"] * 1.15 + 500,
		"object count stable after 3 world visits (%d -> %d)" % [baseline["objects"], final["objects"]])
	saves.call("delete_save", "stress_probe")
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
