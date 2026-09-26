## Hilfsfunktionen, um Godot-Typen JSON-tauglich zu speichern.
class_name SaveUtils
extends RefCounted


static func vec3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func array_to_vec3(value: Variant, fallback := Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() == 3:
		var list: Array = value
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return fallback
