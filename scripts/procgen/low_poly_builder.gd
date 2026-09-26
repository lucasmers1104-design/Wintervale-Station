@tool
## Bausteine für flach schattierte Low-Poly-Meshes per Code.
##
## Jedes Dreieck bekommt eigene Vertices mit Flächennormale und Vertexfarbe.
## Das ergibt den facettierten Look ganz ohne Texturen. Alle Funktionen
## schreiben in einen SurfaceTool, der mit PRIMITIVE_TRIANGLES begonnen wurde.
class_name LowPolyBuilder
extends RefCounted


## Normale der Vorderseite eines Dreiecks.
## Godot rendert Dreiecke im Uhrzeigersinn als Vorderseite.
static func face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c - a).cross(b - a).normalized()


static func add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_normal(face_normal(a, b, c))
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Wie add_triangle, ordnet die Ecken aber so, dass die Vorderseite
## in Richtung [param outward] zeigt. Dadurch muss beim Bauen nie über
## die Reihenfolge der Ecken nachgedacht werden.
static func add_triangle_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		color: Color, outward: Vector3) -> void:
	if face_normal(a, b, c).dot(outward) < 0.0:
		add_triangle(st, a, c, b, color)
	else:
		add_triangle(st, a, b, c, color)


static func add_cone(st: SurfaceTool, base: Vector3, radius: float, height: float,
		segments: int, color: Color, angle_offset := 0.0, with_cap := true) -> void:
	var apex := base + Vector3.UP * height
	for i in segments:
		var p0 := _ring_point(base, radius, angle_offset + TAU * i / segments)
		var p1 := _ring_point(base, radius, angle_offset + TAU * (i + 1) / segments)
		add_triangle_facing(st, apex, p0, p1, color, (p0 + p1) * 0.5 - base)
		if with_cap:
			add_triangle_facing(st, base, p0, p1, color, Vector3.DOWN)


static func add_cylinder(st: SurfaceTool, base: Vector3, radius_bottom: float, radius_top: float,
		height: float, segments: int, color: Color, angle_offset := 0.0) -> void:
	var top := base + Vector3.UP * height
	for i in segments:
		var a0 := angle_offset + TAU * i / segments
		var a1 := angle_offset + TAU * (i + 1) / segments
		var b0 := _ring_point(base, radius_bottom, a0)
		var b1 := _ring_point(base, radius_bottom, a1)
		var t0 := _ring_point(top, radius_top, a0)
		var t1 := _ring_point(top, radius_top, a1)
		var outward := (b0 + b1) * 0.5 - base
		add_triangle_facing(st, b0, b1, t1, color, outward)
		add_triangle_facing(st, b0, t1, t0, color, outward)
		add_triangle_facing(st, top, t0, t1, color, Vector3.UP)
		add_triangle_facing(st, base, b0, b1, color, Vector3.DOWN)


static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		var face_center := center + n * size * 0.5
		var hu := u * size * 0.5
		var hv := v * size * 0.5
		var p0 := face_center - hu - hv
		var p1 := face_center + hu - hv
		var p2 := face_center + hu + hv
		var p3 := face_center - hu + hv
		add_triangle_facing(st, p0, p1, p2, color, n)
		add_triangle_facing(st, p0, p2, p3, color, n)


## Unregelmäßiger Stein: eine grobe Kugel mit verrauschten Radien.
## Flächen, die nach oben zeigen, werden mit [param top_color] (Schnee) gefärbt.
static func add_rock(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, radius: float,
		color: Color, top_color: Color, rings := 4, segments := 7) -> void:
	# Ringe von oben nach unten; Index 0 und rings sind die Pole.
	var rows: Array[PackedVector3Array] = []
	for r in rings + 1:
		var row := PackedVector3Array()
		var phi := PI * r / rings
		var count := 1 if r == 0 or r == rings else segments
		for s in count:
			var theta := TAU * s / segments + rng.randf_range(-0.2, 0.2)
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var p := dir * radius * rng.randf_range(0.78, 1.18)
			p.y *= 0.72
			row.append(center + p)
		rows.append(row)

	for r in rings:
		var upper := rows[r]
		var lower := rows[r + 1]
		for s in segments:
			var s1 := (s + 1) % segments
			if r == 0:
				_add_rock_triangle(st, center, upper[0], lower[s], lower[s1], color, top_color)
			elif r == rings - 1:
				_add_rock_triangle(st, center, upper[s], upper[s1], lower[0], color, top_color)
			else:
				_add_rock_triangle(st, center, upper[s], upper[s1], lower[s1], color, top_color)
				_add_rock_triangle(st, center, upper[s], lower[s1], lower[s], color, top_color)


static func _add_rock_triangle(st: SurfaceTool, center: Vector3, a: Vector3, b: Vector3, c: Vector3,
		color: Color, top_color: Color) -> void:
	var outward := (a + b + c) / 3.0 - center
	var normal := face_normal(a, b, c)
	if normal.dot(outward) < 0.0:
		normal = -normal
	add_triangle_facing(st, a, b, c, top_color if normal.y > 0.55 else color, outward)


static func _ring_point(center: Vector3, radius: float, angle: float) -> Vector3:
	return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
