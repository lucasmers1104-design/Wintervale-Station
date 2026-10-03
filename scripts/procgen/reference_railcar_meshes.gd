@tool
## Referenzzug: kantiger creme/türkiser Triebwagen und roter WinterSpecial.
## Fenster/Türen sind echte Öffnungen; Innenraum, Linsen und Dekoration eigene Meshes.
## Spielmaße und Fahrwerk-Aufnahmen bleiben kompatibel mit RailcarMeshes.SPECS.
class_name ReferenceRailcarMeshes
extends RefCounted

const ROOF := 3.63
const LOW := 1.94
const HIGH := 2.96
const START := -3.65
const BLACK := Color(0.055, 0.065, 0.075)
const FRAME := TrainMeshes.FRAME
const METAL := TrainMeshes.METAL
const UNDER := TrainMeshes.UNDER
const PANE := Color(0.12, 0.17, 0.19)
const GREEN := Color(0.11, 0.28, 0.09)
const RED := Color(0.78, 0.055, 0.025)
const GOLD := Color(0.95, 0.68, 0.13)
const WARM := Color(1.0, 0.81, 0.42)
const SNOW := TrainMeshes.SNOW
## Breiter, niedriger Wagenkasten wie im Entwurf; Einstiegshöhe bleibt bei 1,08 m.
const HEIGHT_SCALE := 0.82


static func build(kind: String, livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cab := kind != "railcar_middle"
	var winter: bool = livery.get("winter_special", false)
	var p := TrainMeshes._new_st()
	var g := TrainMeshes._new_st()
	var inside := TrainMeshes._new_st()
	var glow := TrainMeshes._new_st()
	var headlights := TrainMeshes._new_st()
	var taillights := TrainMeshes._new_st()
	var half := 6.0 if cab else 5.5
	var start := START if cab else -half
	var bogie := 4.35 if cab else 3.9
	var dzs: Array[float] = []
	dzs.assign([-1.55, 3.55] if cab else [-2.85, 2.85])
	var windows: Array[Vector2] = []
	windows.assign([Vector2(-3.37, -2.90), Vector2(-0.65, 0.38), Vector2(0.51, 1.55),
		Vector2(1.68, 2.68), Vector2(4.45, 5.65)] if cab else [Vector2(-5.20, -3.73),
		Vector2(-1.97, -0.78), Vector2(-0.65, 0.65), Vector2(0.78, 1.97), Vector2(3.73, 5.20)])
	if winter:
		if cab:
			# Der feste Frontkranz bleibt vor dem gesamten Schiebeweg der Tür.
			dzs[0] = -0.90
			windows[0] = Vector2(-3.37, -3.02)
			windows[1] = Vector2(0.00, 0.85)
			windows[2] = Vector2(1.02, 1.90)
			windows[3] = Vector2(2.05, 2.68)
			windows[-1] = Vector2(4.45, 5.07)
		else:
			windows[0] = Vector2(-4.68, -3.73)
			windows[-1] = Vector2(3.73, 4.68)
	var doors: Array[Dictionary] = []
	var leaf := _reshape_height(_door_leaf(livery), true)
	for side: float in [-1.0, 1.0]:
		_wall(p, side, start, half, windows, dzs, livery)
		for w in windows:
			var outer := _rect(w.x, w.y, LOW, HIGH, 0)
			var inner := _rect(w.x + 0.065, w.y - 0.065, LOW + 0.065, HIGH - 0.065, 0.035)
			_side_ring(p, side, outer, inner, 1.388, BLACK)
			_side_poly(g, side, inner, 1.392, PANE)
		for z in dzs:
			var trim: Color = livery["accent"] if winter else BLACK
			for edge: float in [-1.0, 1.0]:
				LowPolyBuilder.add_box(p, Vector3(side * 1.392, 2.075, z + edge * 0.695), Vector3(0.075, 2.08, 0.055), trim)
			LowPolyBuilder.add_box(p, Vector3(side * 1.392, 3.10, z), Vector3(0.075, 0.06, 1.40), trim)
			LowPolyBuilder.add_box(p, Vector3(side * 1.30, 1.045, z), Vector3(0.20, 0.065, 1.33), METAL)
			LowPolyBuilder.add_box(p, Vector3(side * 1.39, 1.092, z), Vector3(0.05, 0.028, 1.30), TrainMeshes.STEP_YELLOW)
			LowPolyBuilder.add_cylinder_between(p, Vector3(side * 1.40, 1.85, z + 0.83), Vector3(side * 1.425, 1.85, z + 0.83),
				0.035, 8, Color(0.35, 0.70, 0.30))
			for leaf_side: float in [-1.0, 1.0]:
				doors.append({"mesh": leaf, "position": Vector3(side * 1.409, _height(2.08), z + leaf_side * 0.33),
					"open_offset": Vector3(side * 0.10, 0, leaf_side * 0.65), "side": side})
	_roof(p, start, half, livery)
	RailcarMeshes._underfloor(p, bogie)
	RailcarMeshes._skirts(p, livery, half, bogie, dzs, start)
	_interior(inside, start, half, windows, dzs, winter)
	_equipment(p, start, half, livery)
	_gangway(p, half, 1.0)
	if not cab:
		_gangway(p, -half, -1.0)
	var decorations: Array[AABB] = []
	if winter:
		decorations = _decorate(p, glow, rng, start, half, cab)
	else:
		# Auch der normale Zug behält saisonale, im Sommer unsichtbare Schneereste.
		for i in ceili((half - start) / 1.5):
			_sphere(p, Vector3(rng.randf_range(-0.15, 0.15), 3.65, start + 0.6 + i * 1.5),
				0.65, SNOW, Vector3(1.45, 0.08, 0.75))
	if cab:
		_cab(p, g, inside, glow, headlights, taillights, livery)
	var up := Vector3(0, HEIGHT_SCALE, 0.82).normalized()
	var result := {"paint": p.commit(), "glass": g.commit(), "interior": inside.commit(),
		"glow": glow.commit() if winter else null, "light_front": headlights.commit() if cab else null,
		"light_rear": taillights.commit() if cab else null, "doors": doors,
		"lamps_front": [Vector3(-0.98, 1.80, -6.03), Vector3(0.98, 1.80, -6.03)] if cab else [],
		"lamps_rear": [], "lamps_idle": [], "reference_railcar": true, "fixed_decorations": decorations}
	for key in ["paint", "glass", "interior", "glow", "light_front", "light_rear"]:
		if result[key] != null:
			result[key] = _reshape_height(result[key])
	if cab:
		var at := _front(Vector2(0, 3.29), 0.055)
		at.y = _height(at.y)
		result["display"] = Transform3D(Basis(Vector3.LEFT, up, Vector3(0, up.z, -up.y)), at)
	if kind == "railcar_rear":
		for i in decorations.size():
			decorations[i].position.z = -decorations[i].end.z
		for key in ["paint", "glass", "interior", "glow", "light_front", "light_rear"]:
			if result[key] != null:
				result[key] = RailcarMeshes._mirror_mesh(result[key])
		for door in doors:
			door["position"].z = -door["position"].z
			door["open_offset"].z = -door["open_offset"].z
			door["mesh"] = RailcarMeshes._mirror_mesh(door["mesh"])
		result["lamps_front"] = []
		result["lamps_rear"] = [Vector3(-1.20, 1.75, 6.03), Vector3(1.20, 1.75, 6.03)]
		var display: Transform3D = result["display"]
		result["display"] = Transform3D(Basis(Vector3.UP, PI) * display.basis,
			Vector3(display.origin.x, display.origin.y, -display.origin.z))
	return result


static func _height(y: float) -> float:
	return TrainMeshes.FLOOR_HEIGHT + (y - TrainMeshes.FLOOR_HEIGHT) * HEIGHT_SCALE if y > TrainMeshes.FLOOR_HEIGHT else y


static func _reshape_height(mesh: ArrayMesh, door := false) -> ArrayMesh:
	var result := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			if door or vertices[i].y > TrainMeshes.FLOOR_HEIGHT:
				vertices[i].y = vertices[i].y * HEIGHT_SCALE if door else _height(vertices[i].y)
				normals[i] = (normals[i] * Vector3(1, 1.0 / HEIGHT_SCALE, 1)).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


static func _x(y: float) -> float:
	if y < 1.05:
		return lerpf(1.22, 1.38, clampf((y - 0.88) / 0.17, 0, 1))
	return 1.38 if y <= 3.12 else lerpf(1.38, 1.08, clampf((y - 3.12) / 0.51, 0, 1))


static func _color(y: float, l: Dictionary) -> Color:
	if l.get("winter_special", false):
		return l["secondary"] if y < 1.30 else (l["primary"] if y < 1.72 else l["roof"])
	return l["primary"] if y < 1.51 or y > 3.35 else (l["accent"] if y > 1.56 and y < 1.65 else l["secondary"])


## Shell strips omit the window and door rectangles completely.
static func _wall(st: SurfaceTool, side: float, start: float, end: float, windows: Array[Vector2], dzs: Array[float], l: Dictionary) -> void:
	var zs: Array[float] = [start, end]
	for w in windows:
		zs.append_array([w.x, w.y])
	for z in dzs:
		zs.append_array([z - 0.67, z + 0.67])
	zs.sort()
	var ys: Array[float] = [0.88, 1.05, 1.08, 1.30, 1.51, 1.56, 1.65, 1.72, LOW, HIGH, 3.08, 3.12]
	for iz in zs.size() - 1:
		for iy in ys.size() - 1:
			var za := zs[iz]
			var zb := zs[iz + 1]
			var ya := ys[iy]
			var yb := ys[iy + 1]
			if zb - za < 0.0001:
				continue
			var zm := (za + zb) * 0.5
			var ym := (ya + yb) * 0.5
			var hole := false
			for w in windows:
				hole = hole or (zm > w.x and zm < w.y and ym > LOW and ym < HIGH)
			for z in dzs:
				hole = hole or (absf(zm - z) < 0.67 and ym > 1.08 and ym < 3.08)
			if not hole:
				LowPolyBuilder.add_quad_facing(st, Vector3(side * _x(ya), ya, za), Vector3(side * _x(ya), ya, zb),
					Vector3(side * _x(yb), yb, zb), Vector3(side * _x(yb), yb, za), _color(ym, l), Vector3(side, 0, 0))


static func _rect(z0: float, z1: float, y0: float, y1: float, bevel: float) -> Array[Vector2]:
	bevel = maxf(bevel, 0.001)
	return [Vector2(z0 + bevel, y0), Vector2(z1 - bevel, y0), Vector2(z1, y0 + bevel), Vector2(z1, y1 - bevel),
		Vector2(z1 - bevel, y1), Vector2(z0 + bevel, y1), Vector2(z0, y1 - bevel), Vector2(z0, y0 + bevel)]


static func _side_poly(st: SurfaceTool, side: float, points: Array[Vector2], x: float, color: Color) -> void:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		LowPolyBuilder.add_triangle_facing(st, Vector3(side * x, center.y, center.x), Vector3(side * x, a.y, a.x),
			Vector3(side * x, b.y, b.x), color, Vector3(side, 0, 0))


static func _side_ring(st: SurfaceTool, side: float, outer: Array[Vector2], inner: Array[Vector2], x: float, color: Color) -> void:
	for i in outer.size():
		var j := (i + 1) % outer.size()
		LowPolyBuilder.add_quad_facing(st, Vector3(side * x, outer[i].y, outer[i].x), Vector3(side * x, outer[j].y, outer[j].x),
			Vector3(side * x, inner[j].y, inner[j].x), Vector3(side * x, inner[i].y, inner[i].x), color, Vector3(side, 0, 0))


## Chamfered upholstery and coupler casing retain readable facets at close range.
static func _bevel_box(st: SurfaceTool, at: Vector3, size: Vector3, bevel: float, color: Color) -> void:
	var outline := _rect(-size.x * 0.5, size.x * 0.5, -size.y * 0.5, size.y * 0.5, bevel)
	for i in outline.size():
		var j := (i + 1) % outline.size()
		var a := outline[i]
		var b := outline[j]
		var offset := (a + b) * 0.5
		LowPolyBuilder.add_quad_facing(st, at + Vector3(a.x, a.y, -size.z * 0.5), at + Vector3(b.x, b.y, -size.z * 0.5),
			at + Vector3(b.x, b.y, size.z * 0.5), at + Vector3(a.x, a.y, size.z * 0.5), color, Vector3(offset.x, offset.y, 0))
		for direction: float in [-1.0, 1.0]:
			var end := Vector3(0, 0, direction * size.z * 0.5)
			LowPolyBuilder.add_triangle_facing(st, at + end, at + end + Vector3(a.x, a.y, 0),
				at + end + Vector3(b.x, b.y, 0), color, Vector3(0, 0, direction))


static func _door_leaf(l: Dictionary) -> ArrayMesh:
	var p := TrainMeshes._new_st()
	var g := TrainMeshes._new_st()
	var winter: bool = l.get("winter_special", false)
	var color: Color = l["primary"] if winter else l["accent"]
	var trim: Color = l["accent"] if winter else BLACK
	var low := -0.13 if winter else 0.03
	var high := 0.87
	LowPolyBuilder.add_box(p, Vector3(0, (-1.0 + low) * 0.5, 0), Vector3(0.05, low + 1.0, 0.64), color)
	LowPolyBuilder.add_box(p, Vector3(0, 0.935, 0), Vector3(0.05, 0.13, 0.64), color)
	for edge: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(p, Vector3(0, (low + high) * 0.5, edge * 0.296), Vector3(0.05, high - low, 0.048), color)
	var outer := _rect(-0.29, 0.29, low, high, 0.035)
	var inner := _rect(-0.235, 0.235, low + 0.055, high - 0.055, 0.045)
	_side_ring(p, 1, outer, inner, 0.028, trim)
	_side_poly(g, 1, inner, 0.030, PANE)
	LowPolyBuilder.add_box(p, Vector3(0.03, 0, -0.317), Vector3(0.02, 2.0, 0.014), BLACK)
	if winter:
		for edge: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(p, Vector3(0.03, 0, edge * 0.306), Vector3(0.018, 2.0, 0.025), trim)
		LowPolyBuilder.add_box(p, Vector3(0.03, -0.965, 0), Vector3(0.02, 0.035, 0.62), trim)
	LowPolyBuilder.add_box(p, Vector3(0.037, -0.26, -0.22), Vector3(0.025, 0.28, 0.027), METAL)
	var mesh := p.commit()
	g.commit(mesh)
	return mesh


static func _roof(p: SurfaceTool, start: float, end: float, l: Dictionary) -> void:
	var profile: Array[Vector2] = [Vector2(-1.38, 3.12), Vector2(-1.30, 3.37), Vector2(-1.08, ROOF),
		Vector2(1.08, ROOF), Vector2(1.30, 3.37), Vector2(1.38, 3.12)]
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		LowPolyBuilder.add_quad_facing(p, Vector3(a.x, a.y, start), Vector3(a.x, a.y, end), Vector3(b.x, b.y, end),
			Vector3(b.x, b.y, start), l["roof"] if i == 2 else _color((a.y + b.y) * 0.5, l), Vector3((a.x + b.x) * 0.3, 1, 0))


static func _equipment(p: SurfaceTool, start: float, end: float, l: Dictionary) -> void:
	var roof_color: Color = Color(0.22, 0.23, 0.25) if l.get("winter_special", false) else l["roof"]
	for z: float in [start + 1.30, (start + end) * 0.5 + 1.0, end - 0.85]:
		var length := 1.75 if z < end - 1.5 else 0.85
		LowPolyBuilder.add_box(p, Vector3(0, 3.68, z), Vector3(1.50, 0.10, length), FRAME)
		var section: Array[Vector2] = [Vector2(-0.70, 3.70), Vector2(-0.70, 3.89), Vector2(-0.62, 3.96),
			Vector2(0.62, 3.96), Vector2(0.70, 3.89), Vector2(0.70, 3.70)]
		var colors: Array[Color] = []
		for i in section.size():
			colors.append(roof_color.lightened(0.08))
		var rows := TrainMeshes._extrude(p, null, section, colors, [[z + length * 0.5, 1, 0], [z - length * 0.5, 1, 0]], false)
		TrainMeshes._cap(p, rows[0], Vector3.BACK, roof_color)
		TrainMeshes._cap(p, rows[-1], Vector3.FORWARD, roof_color)
		for side: float in [-1.0, 1.0]:
			for i in 4:
				LowPolyBuilder.add_box(p, Vector3(side * 0.708, 3.75 + i * 0.043, z), Vector3(0.013, 0.019, length - 0.2), BLACK)
		LowPolyBuilder.add_box(p, Vector3(0, 3.982, z), Vector3(0.75, 0.03, length * 0.35), FRAME)
	LowPolyBuilder.add_box(p, Vector3(-0.78, 3.70, start + 0.45), Vector3(0.25, 0.14, 0.38), FRAME)
	LowPolyBuilder.add_cylinder(p, Vector3(-0.78, 3.77, start + 0.45), 0.022, 0.014, 0.18, 6, UNDER)


static func _interior(p: SurfaceTool, start: float, end: float, windows: Array[Vector2], dzs: Array[float], winter: bool) -> void:
	LowPolyBuilder.add_box(p, Vector3(0, 1.045, (start + end) * 0.5), Vector3(2.62, 0.065, end - start), Color(0.26, 0.25, 0.22))
	LowPolyBuilder.add_box(p, Vector3(0, 3.30, (start + end) * 0.5), Vector3(2.50, 0.06, end - start), Color(0.77, 0.67, 0.48))
	var seat := Color(0.63, 0.17, 0.07) if winter else Color(0.16, 0.25, 0.30)
	for w in windows:
		var rows := maxi(1, int((w.y - w.x) / 0.7))
		for row in rows:
			var z := lerpf(w.x + 0.2, w.y - 0.2, (row + 0.5) / rows)
			for side: float in [-1.0, 1.0]:
				var x := side * 0.90
				_bevel_box(p, Vector3(x, 1.46, z), Vector3(0.55, 0.13, 0.46), 0.035, seat)
				_bevel_box(p, Vector3(x, 1.82, z + 0.19), Vector3(0.54, 0.67, 0.13), 0.065, seat)
				_bevel_box(p, Vector3(x, 2.13, z + 0.21), Vector3(0.46, 0.12, 0.13), 0.035, seat.lightened(0.08))
				LowPolyBuilder.add_box(p, Vector3(x, 1.24, z), Vector3(0.08, 0.30, 0.18), FRAME)
				for edge: float in [-1.0, 1.0]:
					LowPolyBuilder.add_box(p, Vector3(x + edge * 0.27, 1.66, z), Vector3(0.035, 0.045, 0.38), FRAME)
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(p, Vector3(side * 1.24, 2.45, w.x + 0.04), Vector3(0.035, 1.06, 0.08), Color(0.65, 0.53, 0.35))
	for z in dzs:
		for x: float in [-0.62, 0.62]:
			LowPolyBuilder.add_cylinder_between(p, Vector3(x, 1.08, z + 0.59), Vector3(x, 3.22, z + 0.59), 0.021, 6, GOLD)
	for z in range(ceili(start), floori(end)):
		LowPolyBuilder.add_box(p, Vector3(0, 3.26, z + 0.5), Vector3(0.14, 0.02, 0.65), Color(1, 0.83, 0.49, 0.8))


static func _gangway(p: SurfaceTool, z: float, direction: float) -> void:
	for i in 8:
		LowPolyBuilder.add_box(p, Vector3(0, 2.20, z + direction * (0.04 + i * 0.05)),
			Vector3(2.37 if i % 2 == 0 else 2.25, 2.58, 0.046), BLACK if i % 2 == 0 else FRAME)
	LowPolyBuilder.add_box(p, Vector3(0, 0.87, z + direction * 0.23), Vector3(0.24, 0.16, 0.46), UNDER)


static func _front_z(y: float) -> float:
	return -6.0 + (y - 1.78) * 0.82 if y >= 1.78 else -6.0 + (1.78 - y) * 0.085


static func _front(v: Vector2, lift := 0.0) -> Vector3:
	return Vector3(v.x, v.y, _front_z(v.y) - lift)


static func _front_poly(st: SurfaceTool, points: Array[Vector2], color: Color, lift := 0.0) -> void:
	# Jede Hälfte liegt in genau einer Bug-Ebene. Das gilt auch für die
	# Lampenlinsen, die die Knickkante kreuzen: kein Durchschneiden des Lacks.
	for lower in [true, false]:
		var clipped: Array[Vector2] = []
		for i in points.size():
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			var a_inside := a.y <= 1.78 if lower else a.y >= 1.78
			var b_inside := b.y <= 1.78 if lower else b.y >= 1.78
			if a_inside and (clipped.is_empty() or not clipped[-1].is_equal_approx(a)):
				clipped.append(a)
			if a_inside != b_inside:
				var hit := a.lerp(b, (1.78 - a.y) / (b.y - a.y))
				if clipped.is_empty() or not clipped[-1].is_equal_approx(hit):
					clipped.append(hit)
		if clipped.size() > 1 and clipped[0].is_equal_approx(clipped[-1]):
			clipped.remove_at(clipped.size() - 1)
		if clipped.size() < 3:
			continue
		var center := Vector2.ZERO
		for v in clipped:
			center += v
		center /= clipped.size()
		for i in clipped.size():
			LowPolyBuilder.add_triangle_facing(st, _front(center, lift), _front(clipped[i], lift),
				_front(clipped[(i + 1) % clipped.size()], lift), color, Vector3.FORWARD)


static func _front_ring(st: SurfaceTool, outer: Array[Vector2], inner: Array[Vector2], color: Color, lift := 0.0) -> void:
	for i in outer.size():
		var j := (i + 1) % outer.size()
		LowPolyBuilder.add_quad_facing(st, _front(outer[i], lift), _front(outer[j], lift), _front(inner[j], lift), _front(inner[i], lift), color, Vector3.FORWARD)


static func _front_band(st: SurfaceTool, y0: float, y1: float, color: Color, lift: float) -> void:
	_front_poly(st, [Vector2(-_nose_x(y0), y0), Vector2(_nose_x(y0), y0),
		Vector2(_nose_x(y1), y1), Vector2(-_nose_x(y1), y1)], color, lift)


static func _cab(p: SurfaceTool, g: SurfaceTool, inside: SurfaceTool, glow: SurfaceTool, head: SurfaceTool, tail: SurfaceTool, l: Dictionary) -> void:
	var winter: bool = l.get("winter_special", false)
	var outer: Array[Vector2] = [Vector2(-1.15, 0.72), Vector2(1.15, 0.72), Vector2(1.37, 1.82), Vector2(1.31, 3.35),
		Vector2(1.10, 3.63), Vector2(-1.10, 3.63), Vector2(-1.31, 3.35), Vector2(-1.37, 1.82)]
	var mask: Array[Vector2] = [Vector2(-0.76, 1.86), Vector2(0.76, 1.86), Vector2(1.03, 2.05), Vector2(1.14, 3.34),
		Vector2(1.05, 3.48), Vector2(-1.05, 3.48), Vector2(-1.14, 3.34), Vector2(-1.03, 2.05)]
	var pane: Array[Vector2] = [Vector2(-0.66, 2.035), Vector2(0.66, 2.035), Vector2(0.88, 2.20), Vector2(1.0, 3.095),
		Vector2(0.95, 3.18), Vector2(-0.95, 3.18), Vector2(-1.0, 3.095), Vector2(-0.88, 2.20)]
	# Die Knickkante bei 1,78 m braucht eigene Flächen: große Dreiecke über
	# beide Bug-Ebenen erzeugen sonst überstehende Lampengehäuse und Falten.
	var upper_outer: Array[Vector2] = outer.duplicate()
	upper_outer[0] = Vector2(-_nose_x(1.78), 1.78)
	upper_outer[1] = Vector2(_nose_x(1.78), 1.78)
	_front_poly(p, [outer[0], outer[1], upper_outer[1], upper_outer[0]], l["secondary"])
	_front_ring(p, upper_outer, mask, l["secondary"])
	if winter:
		var border: Array[Vector2] = []
		for v in mask:
			border.append(Vector2(v.x * 1.105, 2.62 + (v.y - 2.62) * 1.12))
		_front_ring(p, border, mask, l["roof"], 0.01)
	_front_ring(p, mask, pane, BLACK, 0.02)
	_front_poly(g, pane, PANE, 0.025)
	if not winter:
		_front_poly(p, [Vector2(-1.05, 3.48), Vector2(1.05, 3.48), Vector2(1.10, 3.63), Vector2(-1.10, 3.63)], l["roof"], 0.025)
		_front_poly(p, _rect(-0.68, 0.68, 3.195, 3.39, 0.025), BLACK, 0.035)
		_front_band(p, 1.02, 1.51, l["primary"], 0.015)
		_front_band(p, 1.515, 1.605, l["accent"], 0.020)
	else:
		_front_band(p, 1.23, 1.49, l["primary"], 0.015)
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(p, Vector3(side * 0.98, 1.14, -5.965), Vector3(0.58, 0.26, 0.22), l["roof"])
			LowPolyBuilder.add_cylinder_between(glow, _front(Vector2(side * 0.79, 1.91), 0.035), _front(Vector2(side * 1.16, 2.40), 0.035), 0.014, 5, WARM)
		_wreath(p, Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD), Vector3(0, 1.66, -6.11)), 0.32)
	for side: float in [-1.0, 1.0]:
		var housing: Array[Vector2] = [Vector2(side * 0.74, 1.64), Vector2(side * 1.22, 1.65), Vector2(side * 1.22, 2.02), Vector2(side * 0.75, 1.88)]
		_front_poly(p, housing, Color(0.17, 0.24, 0.12) if winter else BLACK, 0.025)
		var lens: Array[Vector2] = [Vector2(side * 0.86, 1.685), Vector2(side * 1.14, 1.69), Vector2(side * 1.14, 1.825), Vector2(side * 0.90, 1.84)]
		_front_poly(head, lens, Color.WHITE, 0.041)
		_front_poly(tail, _rect(side * 1.20 - 0.022, side * 1.20 + 0.022, 1.69, 1.80, 0.01), Color.WHITE, 0.043)
	_nose_sides(p, g, l)
	LowPolyBuilder.add_box(inside, Vector3(0, 1.045, -4.72), Vector3(2.38, 0.06, 2.18), Color(0.23, 0.24, 0.22))
	LowPolyBuilder.add_box(inside, Vector3(0, 2.22, -3.72), Vector3(2.50, 2.28, 0.055), Color(0.67, 0.53, 0.33))
	for x: float in [-0.68, 0.24, 0.75]:
		LowPolyBuilder.add_box(inside, Vector3(x, 2.30, -3.77), Vector3(0.065, 2.08, 0.055), Color(0.38, 0.31, 0.23))
	LowPolyBuilder.add_box(inside, Vector3(0, 1.87, -5.12), Vector3(1.92, 0.16, 0.42), Color(0.13, 0.18, 0.20))
	for x: float in [-0.73, 0.0, 0.73]:
		var seat := Color(0.57, 0.14, 0.08) if winter else Color(0.13, 0.21, 0.28)
		LowPolyBuilder.add_box(inside, Vector3(x, 1.43, -4.30), Vector3(0.49, 0.13, 0.50), seat)
		_bevel_box(inside, Vector3(x, 1.90, -4.03), Vector3(0.47, 0.87, 0.13), 0.065, seat)
		LowPolyBuilder.add_box(inside, Vector3(x + 0.26, 1.67, -4.28), Vector3(0.045, 0.045, 0.44), FRAME)
	LowPolyBuilder.add_box(inside, Vector3(0, 3.12, -4.15), Vector3(0.12, 0.02, 0.46), Color(1, 0.83, 0.49, 0.8))
	LowPolyBuilder.add_cylinder_between(p, _front(Vector2(0.10, 2.055), 0.055), _front(Vector2(-0.25, 2.30), 0.065), 0.017, 6, BLACK)
	LowPolyBuilder.add_cylinder_between(p, _front(Vector2(-0.04, 2.14), 0.075), _front(Vector2(-0.60, 2.63), 0.075), 0.025, 6, BLACK)
	LowPolyBuilder.add_box(p, Vector3(0, 0.89, -6.15), Vector3(0.27, 0.24, 0.43), UNDER)
	_bevel_box(p, Vector3(0, 1.03, -6.34), Vector3(0.54, 0.43, 0.34), 0.045, METAL)
	LowPolyBuilder.add_box(p, Vector3(0, 1.04, -6.516), Vector3(0.35, 0.26, 0.015), FRAME)
	LowPolyBuilder.add_box(p, Vector3(0, 0.69, -5.90), Vector3(1.61, 0.14, 0.35), UNDER)
	# Kurze, abgeschrägte Bugschürze verdeckt die Querträger vor den Radsätzen.
	LowPolyBuilder.add_box(p, Vector3(0, 0.53, -5.90), Vector3(1.92, 0.25, 0.22), UNDER)
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(p, Vector3(side * 0.78, 1.18, -5.98), Vector3(0.28, 0.20, 0.08), FRAME)


static func _nose_x(y: float) -> float:
	if y < 1.82:
		return lerpf(1.15, 1.37, clampf((y - 0.72) / 1.10, 0, 1))
	return lerpf(1.37, 1.31, (y - 1.82) / 1.53) if y < 3.35 else lerpf(1.31, 1.10, clampf((y - 3.35) / 0.28, 0, 1))


static func _nose_point(side: float, y: float, z: float, lift := 0.0) -> Vector3:
	var t := clampf((z - _front_z(y)) / (START - _front_z(y)), 0, 1)
	return Vector3(side * (lerpf(_nose_x(y), _x(y), t) + lift), y, z)


static func _nose_surface_x(y: float, z: float) -> float:
	return lerpf(_nose_x(y), _x(y), (z - _front_z(y)) / (START - _front_z(y)))


## Kontinuierliche Normalen verhindern horizontale Rillen zwischen Lackstreifen.
static func _nose_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, side: float) -> void:
	for triangle: Array in [[a, b, c], [a, c, d]]:
		if LowPolyBuilder.face_normal(triangle[0], triangle[1], triangle[2]).x * side < 0:
			triangle.reverse()
		for vertex: Vector3 in triangle:
			var dy := (_nose_surface_x(vertex.y + 0.002, vertex.z) - _nose_surface_x(vertex.y - 0.002, vertex.z)) / 0.004
			var dz := (_nose_surface_x(vertex.y, vertex.z + 0.002) - _nose_surface_x(vertex.y, vertex.z - 0.002)) / 0.004
			st.set_color(color)
			st.set_normal(Vector3(side, -dy, -dz).normalized())
			st.add_vertex(vertex)


static func _nose_sides(p: SurfaceTool, g: SurfaceTool, l: Dictionary) -> void:
	var ys: Array[float] = [0.72, 0.88, 1.05, 1.30, 1.51, 1.56, 1.65, 1.72, 1.82, 2.04, 3.02, 3.12, 3.35, ROOF]
	for side: float in [-1.0, 1.0]:
		for i in ys.size() - 1:
			var a := ys[i]
			var b := ys[i + 1]
			var window := a >= 2.04 and b <= 3.02
			var spans: Array[Vector2] = []
			spans.assign([Vector2(0, 1)] if not window else [Vector2(0, 0.16), Vector2(0.84, 1)])
			for span in spans:
				_nose_quad(p, _nose_point(side, a, lerpf(_front_z(a), START, span.x)),
					_nose_point(side, a, lerpf(_front_z(a), START, span.y)), _nose_point(side, b, lerpf(_front_z(b), START, span.y)),
					_nose_point(side, b, lerpf(_front_z(b), START, span.x)),
					l["secondary"] if l.get("winter_special", false) else _color((a + b) * 0.5, l), side)
		var outer: Array[Vector2] = []
		var inner: Array[Vector2] = []
		for v: Vector2 in [Vector2(0.16, 2.04), Vector2(0.84, 2.04), Vector2(0.84, 3.02), Vector2(0.16, 3.02)]:
			outer.append(Vector2(lerpf(_front_z(v.y), START, v.x), v.y))
		for v: Vector2 in [Vector2(0.19, 2.10), Vector2(0.80, 2.10), Vector2(0.80, 2.96), Vector2(0.19, 2.96)]:
			inner.append(Vector2(lerpf(_front_z(v.y), START, v.x), v.y))
		for i in 4:
			var j := (i + 1) % 4
			_nose_quad(p, _nose_point(side, outer[i].y, outer[i].x, 0.003), _nose_point(side, outer[j].y, outer[j].x, 0.003),
				_nose_point(side, inner[j].y, inner[j].x, 0.004), _nose_point(side, inner[i].y, inner[i].x, 0.004), BLACK, side)
		_nose_quad(g, _nose_point(side, inner[0].y, inner[0].x, 0.004), _nose_point(side, inner[1].y, inner[1].x, 0.004),
			_nose_point(side, inner[2].y, inner[2].x, 0.004), _nose_point(side, inner[3].y, inner[3].x, 0.004), PANE, side)
	LowPolyBuilder.add_quad_facing(p, Vector3(-1.10, ROOF, _front_z(ROOF)), Vector3(1.10, ROOF, _front_z(ROOF)),
		Vector3(1.08, ROOF, START), Vector3(-1.08, ROOF, START), l["roof"], Vector3.UP)


static func _sphere(st: SurfaceTool, at: Vector3, radius: float, color: Color, scale := Vector3.ONE) -> void:
	for r in 4:
		for s in 8:
			var ps: Array[Vector3] = []
			for pair: Vector2i in [Vector2i(r, s), Vector2i(r, s + 1), Vector2i(r + 1, s + 1), Vector2i(r + 1, s)]:
				var phi := PI * pair.x / 4.0
				var theta := TAU * pair.y / 8.0
				ps.append(at + Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radius * scale)
			if r > 0:
				LowPolyBuilder.add_triangle_facing(st, ps[0], ps[1], ps[2], color, (ps[0] + ps[1] + ps[2]) / 3.0 - at)
			if r < 3:
				LowPolyBuilder.add_triangle_facing(st, ps[0], ps[2], ps[3], color, (ps[0] + ps[2] + ps[3]) / 3.0 - at)


static func _bow(p: SurfaceTool, t: Transform3D, size: float) -> void:
	LowPolyBuilder.add_oriented_box(p, t, Vector3(size * 0.42, size * 0.34, size * 0.32), RED)
	for side: float in [-1.0, 1.0]:
		var knot := t * Vector3(side * size * 0.12, 0, 0.03)
		var top := t * Vector3(side * size * 0.72, size * 0.29, -0.025)
		var bottom := t * Vector3(side * size * 0.70, -size * 0.25, -0.025)
		var fold := t * Vector3(side * size * 0.43, 0, 0.08)
		LowPolyBuilder.add_triangle_facing(p, knot, top, fold, RED.lightened(0.05), t.basis.z)
		LowPolyBuilder.add_triangle_facing(p, knot, fold, bottom, RED, t.basis.z)
		LowPolyBuilder.add_triangle_facing(p, top, bottom, fold, RED.darkened(0.08), t.basis.z)
		LowPolyBuilder.add_triangle_facing(p, t * Vector3(side * size * 0.12, -size * 0.12, 0.02), t * Vector3(side * size * 0.54, -size * 0.90, 0.02),
			t * Vector3(side * size * 0.15, -size * 0.70, 0.025), RED, t.basis.z)


static func _wreath(p: SurfaceTool, t: Transform3D, radius: float) -> void:
	# Vertikales Gegenmaß: die Höhenanpassung darf den Kranz nicht oval machen.
	t.basis.y /= HEIGHT_SCALE
	for i in 18:
		var a := TAU * i / 18
		_sphere(p, t * Vector3(sin(a) * radius, cos(a) * radius, 0), radius * 0.31, GREEN.lightened(0.05) if i % 3 == 0 else GREEN)
	for i in 9:
		var a := TAU * (i + 0.5) / 9
		_sphere(p, t * Vector3(sin(a) * radius, cos(a) * radius, 0.085), radius * 0.17, GOLD if i % 2 else RED)
	_bow(p, t.translated_local(Vector3(0, radius * 0.91, 0.11)), radius * 0.68)


static func _decorate(p: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator, start: float, end: float, cab: bool) -> Array[AABB]:
	var bounds: Array[AABB] = []
	for side: float in [-1.0, 1.0]:
		var count := ceili((end - start) / 0.22)
		for i in count:
			var z := lerpf(start, end - 0.18, (i + 0.5) / count)
			_sphere(p, Vector3(side * 1.355, 3.34 - 0.06 * absf(sin((z - start) * 2.4)), z), 0.082,
				GREEN if i % 3 else GREEN.lightened(0.05), Vector3(0.65, 0.80, 1.55))
		var bulb_count := maxi(2,ceili((end-start)/0.42))
		for i in bulb_count:
			var bulb_z := lerpf(start+0.18,end-0.18,float(i)/(bulb_count-1))
			_sphere(glow,Vector3(side*1.407,3.30-0.035*sin(bulb_z*2.4),bulb_z),0.027,WARM)
		var basis := Basis(Vector3(0, 0, -side), Vector3.UP, Vector3(side, 0, 0))
		for z: float in [(-2.61 if cab else start + 0.33), end - 0.33]:
			_wreath(p, Transform3D(basis, Vector3(side * 1.412, 2.43, z)), 0.25)
			bounds.append(AABB(Vector3(side * 1.47 - 0.14, _height(2.43) - 0.36, z - 0.33), Vector3(0.28, 0.72, 0.66)))
		for z: float in [start + 1.0, end - 1.40]:
			_bow(p, Transform3D(basis, Vector3(side * 1.39, 3.28, z)), 0.16)
	for i in ceili((end - start) / 0.78):
		var z := start + 0.28 + i * 0.78
		_sphere(p, Vector3(rng.randf_range(-0.13, 0.13), 3.67, z), 0.71, SNOW,
			Vector3(rng.randf_range(1.45, 1.70), rng.randf_range(0.12, 0.22), rng.randf_range(0.76, 1.04)))
		for side: float in [-1.0, 1.0]:
			if i % 3 == 0:
				_sphere(p, Vector3(side * 1.18, 3.56, z), 0.23, SNOW, Vector3(1, 0.53, 1.8))
	if cab:
		_sphere(p, Vector3(0, 3.67, -4.11), 0.75, SNOW, Vector3(1.45, 0.20, 0.8))
		for side: float in [-1.0, 1.0]:
			_sphere(p, _front(Vector2(side * 1.10, 3.55), -0.01), 0.19, SNOW, Vector3(1.10, 0.45, 1.20))
			_sphere(p, _front(Vector2(side * 1.16, 3.34), 0.02), 0.10, GREEN, Vector3(0.75, 1.40, 1))
		for i in 7:
			var x := -1.07 + i * 0.355
			var y := 3.455 - 0.055 * (1.0 - absf(x))
			var at := _front(Vector2(x, y), 0.07)
			_sphere(glow, at, 0.030, WARM)
			if i > 0:
				LowPolyBuilder.add_cylinder_between(p, _front(Vector2(x - 0.355, y), 0.065), at, 0.012, 5, BLACK)
	return bounds


static func wheel_faces(winter: bool) -> ArrayMesh:
	var p := TrainMeshes._new_st()
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_cylinder_between(p, Vector3(side * 0.79, 0, 0), Vector3(side * 1.055, 0, 0), 0.335, 16, FRAME)
		LowPolyBuilder.add_cylinder_between(p, Vector3(side * 1.055, 0, 0), Vector3(side * 1.068, 0, 0), 0.255, 14,
			Color(0.30, 0.37, 0.16) if winter else METAL.darkened(0.20))
	return p.commit()
