@tool
## Tunnelportal aus Naturstein mit dunkler Röhre und verschneitem Felshügel.
##
## Lokal: Ursprung = Tunnelmund auf Gleishöhe, -Z führt in den Tunnel hinein,
## die Portalwand schaut nach +Z (zum Bahnhof).
class_name TunnelMeshes
extends RefCounted

const OPENING_WIDTH := 5.6
const OPENING_HEIGHT := 6.4
const WALL_WIDTH := 14.0
const WALL_HEIGHT := 9.0
const STONE := Color(0.5, 0.49, 0.47)
const STONE_DARK := Color(0.38, 0.37, 0.36)
const KEYSTONE := Color(0.58, 0.55, 0.5)
const DARK := Color(0.03, 0.03, 0.035)
const SNOW := Color(0.9, 0.93, 0.97)
const ROCK := Color(0.42, 0.43, 0.47)


## Portalwand aus Steinquadern mit Rundbogen, dazu die dunkle Röhre.
static func create_portal(tunnel_length: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_open := OPENING_WIDTH * 0.5
	var arch_center_y := OPENING_HEIGHT - half_open
	var course := 0.6
	var wall_depth := 1.2

	# Mauerwerk: Reihen versetzter Quader, ausgespart für die Öffnung
	var rows := int(WALL_HEIGHT / course)
	for row in rows:
		var y0 := -1.0 + row * course
		var shift := 0.45 if row % 2 == 1 else 0.0
		var x := -WALL_WIDTH * 0.5 - shift
		while x < WALL_WIDTH * 0.5:
			var block := rng.randf_range(0.8, 1.4)
			var x1 := minf(x + block, WALL_WIDTH * 0.5)
			var x0 := maxf(x, -WALL_WIDTH * 0.5)
			var center := Vector3((x0 + x1) * 0.5, y0 + course * 0.5, -wall_depth * 0.5)
			if not _in_opening(center.x, center.y, half_open, arch_center_y, 0.35) and x1 - x0 > 0.2:
				var color := STONE.lerp(STONE_DARK, rng.randf()).lightened(rng.randf_range(-0.03, 0.05))
				LowPolyBuilder.add_box(st, center, Vector3(x1 - x0 - 0.04, course - 0.04, wall_depth + rng.randf_range(0.0, 0.08)), color)
			x = x1

	# Bogensteine rund um die Öffnung, Schlussstein oben
	var voussoirs := 13
	for i in voussoirs:
		var angle := PI * (i + 0.5) / voussoirs
		var radius := half_open + 0.35
		var center := Vector3(cos(angle) * radius, arch_center_y + sin(angle) * radius, 0.08)
		var basis := Basis(Vector3.BACK, angle - PI * 0.5)
		var color := KEYSTONE if i == voussoirs / 2 else STONE.lightened(0.08)
		var size := Vector3(0.62, 0.72 if i == voussoirs / 2 else 0.6, wall_depth + 0.2)
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, center), size, color)
	for side: float in [-1.0, 1.0]:
		for i in 5:
			LowPolyBuilder.add_box(st, Vector3(side * (half_open + 0.35), 0.3 + i * 0.7, 0.08), Vector3(0.62, 0.66, wall_depth + 0.2), STONE.lightened(0.08))

	# Gesims mit Schnee
	LowPolyBuilder.add_box(st, Vector3(0.0, WALL_HEIGHT - 0.8, 0.1), Vector3(WALL_WIDTH + 0.4, 0.3, wall_depth + 0.4), STONE_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, WALL_HEIGHT - 0.6, 0.1), Vector3(WALL_WIDTH + 0.3, 0.1, wall_depth + 0.3), SNOW)

	# Dunkle Tunnelröhre (Innenseiten)
	var inner_y := OPENING_HEIGHT + 0.2
	var z0 := -wall_depth * 0.5
	var z1 := -tunnel_length
	var w := half_open + 0.1
	LowPolyBuilder.add_quad_facing(st, Vector3(-w, -0.8, z0), Vector3(-w, inner_y, z0), Vector3(-w, inner_y, z1), Vector3(-w, -0.8, z1), DARK, Vector3.RIGHT)
	LowPolyBuilder.add_quad_facing(st, Vector3(w, -0.8, z0), Vector3(w, inner_y, z0), Vector3(w, inner_y, z1), Vector3(w, -0.8, z1), DARK, Vector3.LEFT)
	LowPolyBuilder.add_quad_facing(st, Vector3(-w, inner_y, z0), Vector3(w, inner_y, z0), Vector3(w, inner_y, z1), Vector3(-w, inner_y, z1), DARK, Vector3.DOWN)
	LowPolyBuilder.add_quad_facing(st, Vector3(-w, -0.8, z1), Vector3(w, -0.8, z1), Vector3(w, inner_y, z1), Vector3(-w, inner_y, z1), DARK, Vector3.BACK)
	return st.commit()


## Verschneiter Felshügel über der Tunnelröhre.
static func create_mound(tunnel_length: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Der Hügel beginnt hinter der Portalwand, damit das Gleis davor frei bleibt.
	var center_z := -tunnel_length * 0.5 - 6.0
	var radius_z := tunnel_length * 0.5 + 4.0
	var radius_x := 17.0
	var peak := 11.0
	var steps := 14
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.12
	var heights := {}
	for i in steps + 1:
		for j in steps + 1:
			var u := -1.0 + 2.0 * i / steps
			var v := -1.0 + 2.0 * j / steps
			var r := sqrt(u * u + v * v)
			var h := peak * sqrt(maxf(0.0, 1.0 - minf(r, 1.0) * minf(r, 1.0))) - 3.0
			h += noise.get_noise_2d(u * 10.0, v * 10.0) * 1.4 * (1.0 - minf(r, 1.0))
			heights[Vector2i(i, j)] = Vector3(u * radius_x, h, center_z + v * radius_z)
	for i in steps:
		for j in steps:
			var a: Vector3 = heights[Vector2i(i, j)]
			var b: Vector3 = heights[Vector2i(i + 1, j)]
			var c: Vector3 = heights[Vector2i(i + 1, j + 1)]
			var d: Vector3 = heights[Vector2i(i, j + 1)]
			for tri in [[a, b, c], [a, c, d]]:
				var normal := LowPolyBuilder.face_normal(tri[0], tri[1], tri[2])
				if normal.y < 0.0:
					normal = -normal
				var color := SNOW if normal.y > 0.8 else (ROCK if normal.y > 0.55 else ROCK.darkened(0.2))
				color = color.lightened(rng.randf_range(-0.03, 0.03))
				LowPolyBuilder.add_triangle_facing(st, tri[0], tri[1], tri[2], color, Vector3.UP)
	return st.commit()


static func _in_opening(x: float, y: float, half_open: float, arch_center_y: float, margin: float) -> bool:
	if absf(x) > half_open + margin:
		return false
	if y < arch_center_y:
		return true
	return Vector2(x, y - arch_center_y).length() < half_open + margin
