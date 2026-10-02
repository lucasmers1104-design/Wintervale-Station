## Geometry and moving-part integration for both reference liveries, all three cars.
extends Node

var failures := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)


func _ready() -> void:
	var factory := TrainDispatcher.new()
	var materials := {"paint": load("res://assets/materials/train_paint.tres"), "glass": load("res://assets/materials/train_glass.tres"),
		"lamp_white": factory._lamp_material(Color(1, 0.92, 0.75), 2), "lamp_red": factory._lamp_material(Color(1, 0.1, 0.08), 2),
		"lamp_idle_white": factory._lens_material(Color(0.55, 0.56, 0.54)), "lamp_idle_red": factory._lens_material(Color(0.25, 0.035, 0.02)),
		"snow": factory._snow_material(), "festive": factory._festive_material()}
	factory.free()
	for design in ["regional_express", "special_winter"]:
		var type: TrainType = load("res://assets/trains/%s.tres" % design)
		for i in type.consist.size():
			var kind := type.consist[i]
			var parts := TrainMeshes.build_car(kind, type.get_livery(), i)
			var valid := true
			var triangles := 0
			for key in ["paint", "glass", "interior", "glow", "light_front", "light_rear"]:
				var mesh: ArrayMesh = parts.get(key)
				if mesh == null:
					continue
				for surface in mesh.get_surface_count():
					var arrays := mesh.surface_get_arrays(surface)
					var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					triangles += vs.size() / 3
					for vertex in vs:
						valid = valid and vertex.is_finite()
					for normal in ns:
						valid = valid and normal.is_finite() and normal.length() > 0.8
			check(valid, "%s/%s finite geometry" % [design, kind])
			check(triangles < 22000, "%s/%s geometry budget (%d triangles)" % [design, kind, triangles])
			check(parts["interior"] != null and (parts["glow"] != null) == type.winter_special, "%s/%s cabin and variant details" % [design, kind])
			if type.winter_special:
				var clearance := true
				for door in parts["doors"]:
					var basis := Basis(Vector3.UP, PI) if float(door["side"]) < 0 else Basis.IDENTITY
					var leaf_bounds := Transform3D(basis, door["position"]) * (door["mesh"] as Mesh).get_aabb()
					var opened := leaf_bounds
					opened.position += door["open_offset"]
					var swept := leaf_bounds.merge(opened)
					for decoration: AABB in parts["fixed_decorations"]:
						clearance = clearance and not swept.intersects(decoration)
				check(clearance, "%s/%s fixed wreaths clear entire door travel" % [design, kind])
			var car := TrainCar.new()
			add_child(car)
			car.build(kind, type, i == 0, i == 2, materials, i)
			car.set_destination("RE 209  Wintervale am verschneiten Bergbahnhof")
			check(car.get_destination().contains("Wintervale") if i != 1 else car.get_destination().is_empty(), "%s/%s destination" % [design, kind])
			car.set_cabin_light(1.0)
			check(is_equal_approx(car.get_cabin_light(), 1.0), "%s/%s cabin responds" % [design, kind])
			for side: float in [-1.0, 1.0]:
				car.set_steps(1.0, side)
				car.set_doors(1.0, side)
				var paths := car.get_boarding_paths(side)
				var aligned := paths.size() == 2
				for path in paths:
					var found := false
					for step in car._steps:
						if float(step["side"]) != side:
							continue
						var unit: Node3D = step["unit"]
						if absf(unit.global_position.z - (path["door"] as Vector3).z) < 0.001:
							found = unit.visible and is_equal_approx(absf(unit.position.x), TrainMeshes.STEP_EXTENDED_X)
							found = found and unit.get_parent() == car._body
					aligned = aligned and found
				check(aligned, "%s/%s boarding/stairs aligned on side %s" % [design, kind, side])
				var doors_ok := true
				for door in car._doors:
					var node: MeshInstance3D = door["node"]
					var closed: Vector3 = door["closed"]
					if float(door["side"]) == side:
						doors_ok = doors_ok and absf(node.position.z - closed.z) > 0.60 and absf(node.position.x - closed.x) > 0.09
					else:
						doors_ok = doors_ok and node.position.is_equal_approx(closed)
				check(doors_ok, "%s/%s only platform-side doors open" % [design, kind])
				car._body.rotation = Vector3(0.01, 0.0, 0.025)
				var tilted_paths := car.get_boarding_paths(side)
				var tilted_alignment := true
				for path in tilted_paths:
					var door_z := car._body.to_local(path["door"]).z
					for step in car._steps:
						var unit: Node3D = step["unit"]
						if float(step["side"]) == side and is_equal_approx(unit.position.z, door_z):
							tilted_alignment = tilted_alignment and (path["upper"] as Vector3).is_equal_approx(unit.to_global(Vector3(0, TrainMeshes.STEP_UPPER_Y, 0)))
				check(tilted_alignment, "%s/%s boarding follows suspension on side %s" % [design, kind, side])
				car._body.rotation = Vector3.ZERO
				car.set_doors(0.0, side)
				car.set_steps(0.0, side)
				var closed_ok := true
				for door in car._doors:
					closed_ok = closed_ok and (door["node"] as Node3D).position.is_equal_approx(door["closed"])
				for step in car._steps:
					closed_ok = closed_ok and not (step["unit"] as Node3D).visible
				check(closed_ok, "%s/%s doors shut / steps hidden" % [design, kind])
			car.free()
	var normal := TrainMeshes.build_car("railcar_front", (load("res://assets/trains/regional_express.tres") as TrainType).get_livery())
	var winter := TrainMeshes.build_car("railcar_front", (load("res://assets/trains/special_winter.tres") as TrainType).get_livery())
	check(normal["paint"] != winter["paint"] and normal["glow"] == null and winter["glow"] != null, "livery cache keeps winter and regional geometry separate")
	TrainMeshes.clear_cache()
	SoundLibrary.clear_cache()
	print("REFERENCE TRAIN: ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
