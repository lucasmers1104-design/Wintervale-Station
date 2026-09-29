## HUD-Regressionstest (Master Debugging V2).
##
## Start: godot --headless --path . -s res://tests/qa/hud_test.gd
## Prüft, dass die kleine Analoguhr genau zwei Zeiger hat, die dieselbe Zeit
## wie die Digitalanzeige zeigen, und dass der Notizbuch-Knopf sichtbar,
## groß genug und funktionsfähig ist.
extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS  ", message)
	else:
		push_error("FAIL  " + message)
		failures += 1


func _angle_close(a: float, b: float) -> bool:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0) < 0.6


func _run() -> void:
	var clock: Node = root.get_node(^"/root/WorldClock")
	clock.set("paused", true)
	var events: Node = root.get_node(^"/root/Events")
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var hands: Control = hud.call("get_clock_hands")
	_check(hands != null, "clock hands exist")
	_check(hud.find_children("*", "HudClockHands", true, false).size() <= 1, "exactly one hand set")
	var constants: Dictionary = hands.get_script().get_script_constant_map()
	_check(constants.has("MINUTE_SHAPE") and constants.has("HOUR_SHAPE") and not constants.has("SECOND_SHAPE"),
		"exactly two hands: hour and minute")
	var cases := {
		0.0: [0.0, 0.0], 12.0: [0.0, 0.0], 16.0: [120.0, 0.0], 3.0: [90.0, 0.0],
		9.0 + 41.0 / 60.0: [290.5, 246.0], 23.0 + 27.0 / 60.0: [343.5, 162.0], 6.5: [195.0, 180.0],
	}
	var time_label: Label = hud.find_child("TimeValue", true, false)
	for hours: float in cases:
		clock.call("set_time", hours)
		await process_frame
		var expected: Array = cases[hours]
		var text: String = clock.call("get_time_string")
		_check(time_label.text == text, "digital time shows %s" % text)
		_check(_angle_close(float(hands.get("hour_degrees")), expected[0]),
			"%s hour hand at %.1f° (is %.1f°)" % [text, expected[0], hands.get("hour_degrees")])
		_check(_angle_close(float(hands.get("minute_degrees")), expected[1]),
			"%s minute hand at %.1f° (is %.1f°)" % [text, expected[1], hands.get("minute_degrees")])
	# Stundenzeiger um 16:00 zeigt auf die 4 (wie die Digitalanzeige), nicht mehr fest gemalt.
	var art: TextureRect = hud.find_child("StatusBarArtwork", true, false)
	var atlas := art.texture as AtlasTexture
	_check(atlas.atlas.resource_path.ends_with("hud_status_bar_clean.png"), "status bar uses hand-free clock face")

	var book: Button = hud.find_child("NotebookButton", true, false)
	var rect := book.get_global_rect()
	var bar: Control = hud.find_child("PremiumStatusBar", true, false)
	_check(book.visible and rect.size.x * bar.scale.x >= 30.0, "notebook button large enough (%.0f px)" % (rect.size.x * bar.scale.x))
	var viewport_rect := hud.get_viewport().get_visible_rect()
	var screen_rect := Rect2(bar.position + book.position * bar.scale, book.size * bar.scale)
	_check(viewport_rect.encloses(screen_rect), "notebook button inside the screen")
	var requested := [false]
	events.connect("notebook_requested", func(_page: String) -> void: requested[0] = true)
	book.pressed.emit()
	_check(requested[0], "notebook button opens the notebook")
	hud.queue_free()
	await process_frame
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
