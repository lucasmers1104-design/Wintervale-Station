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
	add_oriented_box(st, Transform3D(Basis.IDENTITY, center), size, color)


## Quader mit beliebiger Lage: [param xform] gibt Mittelpunkt und Ausrichtung vor.
static func add_oriented_box(st: SurfaceTool, xform: Transform3D, size: Vector3, color: Color) -> void:
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		var face_center := n * size * 0.5
		var hu := u * size * 0.5
		var hv := v * size * 0.5
		var p0 := xform * (face_center - hu - hv)
		var p1 := xform * (face_center + hu - hv)
		var p2 := xform * (face_center + hu + hv)
		var p3 := xform * (face_center - hu + hv)
		var outward := xform.basis * n
		add_triangle_facing(st, p0, p1, p2, color, outward)
		add_triangle_facing(st, p0, p2, p3, color, outward)


## Vierkant-Balken von [param a] nach [param b] (z.B. Streben).
static func add_beam(st: SurfaceTool, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var axis := b - a
	var forward := axis.normalized()
	var helper := Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT
	var right := helper.cross(forward).normalized()
	var up := forward.cross(right)
	var basis := Basis(right, up, forward)
	add_oriented_box(st, Transform3D(basis, (a + b) * 0.5), Vector3(thickness, thickness, axis.length()), color)


## Zylinder entlang einer beliebigen Achse von [param a] nach [param b].
static func add_cylinder_between(st: SurfaceTool, a: Vector3, b: Vector3, radius: float,
		segments: int, color: Color) -> void:
	var forward := (b - a).normalized()
	var helper := Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT
	var u := helper.cross(forward).normalized()
	var v := forward.cross(u)
	for i in segments:
		var o0 := (u * cos(TAU * i / segments) + v * sin(TAU * i / segments)) * radius
		var o1 := (u * cos(TAU * (i + 1) / segments) + v * sin(TAU * (i + 1) / segments)) * radius
		var outward := (o0 + o1) * 0.5
		add_triangle_facing(st, a + o0, a + o1, b + o1, color, outward)
		add_triangle_facing(st, a + o0, b + o1, b + o0, color, outward)
		add_triangle_facing(st, a, a + o0, a + o1, color, -forward)
		add_triangle_facing(st, b, b + o0, b + o1, color, forward)


## Viereck aus zwei Dreiecken; die Vorderseite zeigt nach [param outward].
static func add_quad_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		color: Color, outward: Vector3) -> void:
	add_triangle_facing(st, a, b, c, color, outward)
	add_triangle_facing(st, a, c, d, color, outward)


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
	if normal.y <= 0.55:
		add_triangle_facing(st, a, b, c, color, outward)
	elif top_color.a < 0.6 and color.a >= 0.6:
		# Schneekappe als Auflage knapp über dem Stein: taut sie im Frühling weg,
		# kommt der Fels darunter zum Vorschein (statt eines Lochs)
		add_triangle_facing(st, a, b, c, color, outward)
		# 2 cm: genug Abstand, damit die Kappe auch aus der Ferne nicht mit dem Fels flimmert
		var lift := normal * 0.02
		add_triangle_facing(st, a + lift, b + lift, c + lift, top_color, outward)
	else:
		add_triangle_facing(st, a, b, c, top_color, outward)


static func _ring_point(center: Vector3, radius: float, angle: float) -> Vector3:
	return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
