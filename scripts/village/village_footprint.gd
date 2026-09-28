## Grundfläche eines Dorf-Objekts in der Draufsicht: gedrehtes Rechteck
## {"center": Vector2, "half": Vector2, "angle": float (Drehung um Y)}.
## Kreise werden als Quadrat angenähert – für die Platzierung genau genug.
class_name VillageFootprint
extends RefCounted


static func make(center: Vector3, half: Vector2, angle: float) -> Dictionary:
	return {"center": Vector2(center.x, center.z), "half": half, "angle": angle}


## Grundfläche eines Objekts aus Katalog, Lage und Drehung. Linien/Wege: von
## [param start] nach [param end].
static func for_item(item_id: String, position: Vector3, angle: float, variant := 0, end := Vector3.INF) -> Dictionary:
	if VillageCatalog.is_line(item_id) and end != Vector3.INF:
		var a := Vector2(position.x, position.z)
		var b := Vector2(end.x, end.z)
		var length := a.distance_to(b)
		var fp := VillageCatalog.get_footprint(item_id, variant, length)
		var size: Vector2 = fp["size"]
		var dir := (b - a).normalized() if length > 0.01 else Vector2.RIGHT
		# Winkel so, dass die lokale X-Achse entlang der Linie zeigt
		return {"center": (a + b) * 0.5, "half": Vector2(length * 0.5 + size.y * 0.5, size.y * 0.5), "angle": -dir.angle()}
	var footprint := VillageCatalog.get_footprint(item_id, variant)
	if footprint.has("size"):
		var fp := make(position, (footprint["size"] as Vector2) * 0.5, angle)
		# Versatz der Grundfläche (z.B. L-förmiges Bauernhaus) mitdrehen
		var offset: Vector2 = footprint.get("center", Vector2.ZERO)
		fp["center"] = (fp["center"] as Vector2) + offset.rotated(-angle)
		return fp
	var radius := float(footprint["radius"])
	return make(position, Vector2(radius, radius), angle)


## Eckpunkte in Weltkoordinaten (x, z).
static func corners(fp: Dictionary, margin := 0.0) -> PackedVector2Array:
	var half: Vector2 = fp["half"] + Vector2(margin, margin)
	var axis_x := Vector2(cos(fp["angle"]), -sin(fp["angle"]))
	var axis_z := Vector2(sin(fp["angle"]), cos(fp["angle"]))
	var c: Vector2 = fp["center"]
	return PackedVector2Array([c - axis_x * half.x - axis_z * half.y, c + axis_x * half.x - axis_z * half.y,
		c + axis_x * half.x + axis_z * half.y, c - axis_x * half.x + axis_z * half.y])


static func contains(fp: Dictionary, point: Vector2, margin := 0.0) -> bool:
	var local := (point - (fp["center"] as Vector2)).rotated(fp["angle"])
	var half: Vector2 = fp["half"]
	return absf(local.x) <= half.x + margin and absf(local.y) <= half.y + margin


## Überschneiden sich zwei Grundflächen (Trennachsen-Test)?
static func overlaps(a: Dictionary, b: Dictionary, margin := 0.0) -> bool:
	var pa := corners(a, margin)
	var pb := corners(b)
	for poly in [pa, pb]:
		for i in 4:
			var edge: Vector2 = poly[(i + 1) % 4] - poly[i]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var min_a := INF
			var max_a := -INF
			for p in pa:
				min_a = minf(min_a, axis.dot(p))
				max_a = maxf(max_a, axis.dot(p))
			var min_b := INF
			var max_b := -INF
			for p in pb:
				min_b = minf(min_b, axis.dot(p))
				max_b = maxf(max_b, axis.dot(p))
			if max_a < min_b or max_b < min_a:
				return false
	return true


## Kreuzt die Strecke a→b die Grundfläche?
static func crosses_segment(fp: Dictionary, a: Vector2, b: Vector2, margin := 0.0) -> bool:
	var steps := maxi(2, ceili(a.distance_to(b) / 0.5))
	for i in steps + 1:
		if contains(fp, a.lerp(b, float(i) / steps), margin):
			return true
	return false


## Punkte gleichmäßig über der Fläche (für Hang- und Gleisprüfungen).
static func samples(fp: Dictionary, spacing := 1.5) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half: Vector2 = fp["half"]
	var nx := maxi(1, ceili(half.x * 2.0 / spacing))
	var nz := maxi(1, ceili(half.y * 2.0 / spacing))
	for i in nx + 1:
		for j in nz + 1:
			var local := Vector2(lerpf(-half.x, half.x, float(i) / nx), lerpf(-half.y, half.y, float(j) / nz))
			points.append((fp["center"] as Vector2) + local.rotated(-fp["angle"]))
	return points
