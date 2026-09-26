## Berechnet das Höhenprofil eines Gleises über das natürliche Gelände.
##
## Vorgehen:
## 1. Gelände entlang des Grundrisses alle ~2 m abtasten.
## 2. Mehrfach glätten – kleine Hügel und Mulden verschwinden, das Gleis
##    folgt aber der großen Geländeform (wenig Erdarbeit).
## 3. Steigung begrenzen (max. [constant RailConfig.MAX_GRADE]).
## Feste Enden (an bestehende Gleise angeschlossen) behalten ihre Höhe und
## übernehmen die Steigung des Nachbargleises – so gibt es keine Knicke.
class_name RailProfile
extends RefCounted

const SAMPLE_SPACING := 2.0
const SMOOTH_PASSES := 4
const SMOOTH_RADIUS := 3


## [param start_grade]/[param end_grade]: Steigung in Fahrtrichtung an festen
## Enden (NAN = frei). Rückgabe: {"heights", "ground", "error", "max_earthwork"}.
static func compute(planar: Curve3D, start_height: float, end_height: float, start_fixed: bool,
		end_fixed: bool, terrain: LowPolyTerrain, start_grade := NAN, end_grade := NAN) -> Dictionary:
	var length := planar.get_baked_length()
	var n := maxi(2, ceili(length / SAMPLE_SPACING))
	var ds := length / n
	var max_step := RailConfig.MAX_GRADE * ds

	var ground := PackedFloat32Array()
	for i in n + 1:
		var p := planar.sample_baked(ds * i, true)
		ground.append(terrain.get_base_height(p.x, p.z))

	var h0 := start_height if start_fixed else ground[0]
	var h1 := end_height if end_fixed else ground[n]
	if absf(h1 - h0) > RailConfig.MAX_GRADE * length + 0.001:
		return {"heights": _linear(h0, h1, n), "ground": ground, "error": "Zu steil", "max_earthwork": 0.0}

	# Feste Punkte: Enden und (bei Anschlüssen) die Steigung direkt daneben
	var pinned := {0: h0, n: h1}
	if start_fixed and not is_nan(start_grade) and n > 3:
		pinned[1] = h0 + clampf(start_grade, -RailConfig.MAX_GRADE, RailConfig.MAX_GRADE) * ds
	if end_fixed and not is_nan(end_grade) and n > 3:
		pinned[n - 1] = h1 - clampf(end_grade, -RailConfig.MAX_GRADE, RailConfig.MAX_GRADE) * ds

	var heights := ground.duplicate()
	_apply_pins(heights, pinned)
	for pass_index in SMOOTH_PASSES:
		var smoothed := heights.duplicate()
		for i in range(1, n):
			if pinned.has(i):
				continue
			var sum := 0.0
			for k in range(-SMOOTH_RADIUS, SMOOTH_RADIUS + 1):
				sum += heights[clampi(i + k, 0, n)]
			smoothed[i] = sum / (SMOOTH_RADIUS * 2 + 1)
		heights = smoothed

	# Steigung begrenzen: abwechselnd von vorne und hinten, feste Punkte bleiben
	for iteration in 8:
		for i in range(1, n + 1):
			if not pinned.has(i):
				heights[i] = clampf(heights[i], heights[i - 1] - max_step, heights[i - 1] + max_step)
		for i in range(n - 1, -1, -1):
			if not pinned.has(i):
				heights[i] = clampf(heights[i], heights[i + 1] - max_step, heights[i + 1] + max_step)

	var error := ""
	var max_earthwork := 0.0
	for i in n + 1:
		max_earthwork = maxf(max_earthwork, absf(heights[i] - ground[i]))
		if i > 0 and absf(heights[i] - heights[i - 1]) > max_step * 1.05:
			error = "Zu steil"
	return {"heights": heights, "ground": ground, "error": error, "max_earthwork": max_earthwork}


static func _apply_pins(heights: PackedFloat32Array, pinned: Dictionary) -> void:
	for index: int in pinned:
		heights[index] = pinned[index]


static func _linear(h0: float, h1: float, n: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for i in n + 1:
		result.append(lerpf(h0, h1, float(i) / n))
	return result
