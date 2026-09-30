## Prüft, dass die Lichterketten der Sonderzüge nur dort hängen, wo der Wagen
## eine Dachkante hat – nicht in der Luft vor der abfallenden Bugnase.
##
## Start: godot --headless --path . -s res://tests/qa/festive_lights_test.gd
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


func _run() -> void:
	var materials := {"paint": StandardMaterial3D.new(), "glass": StandardMaterial3D.new(),
		"lamp_white": StandardMaterial3D.new(), "lamp_red": StandardMaterial3D.new(),
		"lamp_idle_red": StandardMaterial3D.new(), "lamp_idle_white": StandardMaterial3D.new(),
		"snow": StandardMaterial3D.new(), "cargo": StandardMaterial3D.new(), "festive": StandardMaterial3D.new()}
	for path in ["res://assets/trains/special_winter.tres", "res://assets/trains/special_autumn.tres"]:
		var train_type: Resource = load(path)
		var car_script: GDScript = load("res://scripts/trains/train_car.gd")
		var nose := float(load("res://scripts/procgen/railcar_meshes.gd").get("NOSE_LENGTH"))
		var consist: PackedStringArray = train_type.get("consist")
		var code := String(train_type.get("type_code"))
		for i in consist.size():
			var car: Node3D = car_script.new()
			root.add_child(car)
			car.call("build", consist[i], train_type, i == 0, i == consist.size() - 1, materials, i)
			var lights := car.find_child("FestiveLights", true, false) as MeshInstance3D
			_check(lights != null, "%s %s has fairy lights" % [code, consist[i]])
			if lights == null:
				continue
			var box := lights.mesh.get_aabb()
			var front_limit := -float(car.get("length")) * 0.5 + (nose if consist[i] == "railcar_front" else 0.5)
			var rear_limit := float(car.get("length")) * 0.5 - (nose if consist[i] == "railcar_rear" else 0.5)
			_check(box.position.z >= front_limit and box.end.z <= rear_limit,
				"%s %s: lights stay on the roof edge (z %.2f..%.2f within %.2f..%.2f)" % [code,
				consist[i], box.position.z, box.end.z, front_limit, rear_limit])
			_check(absf(box.end.x) <= 1.45 and box.end.y <= 3.2, "%s %s: lights hug the body" % [code, consist[i]])
			car.queue_free()
	await process_frame
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
