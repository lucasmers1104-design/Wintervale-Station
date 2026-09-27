@tool
## Tunnelportal aus Naturstein mit dunkler Röhre und verschneitem Berg darüber.
##
## Lokal: Ursprung = Tunnelmund auf Gleishöhe, -Z führt in den Tunnel hinein,
## die Portalwand schaut nach +Z (zum Bahnhof).
class_name TunnelMeshes
extends RefCounted

const OPENING_WIDTH := 5.6
const OPENING_HEIGHT := 6.4
const WALL_WIDTH := 14.0
const WALL_HEIGHT := 9.0
const STONE := Color(0.60, 0.55, 0.49)
const STONE_DARK := Color(0.48, 0.44, 0.40)
const KEYSTONE := Color(0.70, 0.62, 0.52)
const DARK := Color(0.03, 0.03, 0.035)
const SNOW := Color(0.9, 0.93, 0.97)
const SNOW_SHADE := Color(0.82, 0.86, 0.93)
const ROCK := Color(0.47, 0.44, 0.44)
const ROCK_DARK := Color(0.36, 0.34, 0.36)

# Form des Berges (lokale Meter, Ursprung = Tunnelmund auf Gleishöhe)
## Hangkante direkt hinter dem Gesims – der Berg liegt auf der Mauer auf.
const RIDGE_HEIGHT := 8.3
## Gefälle des Hanges vor der Mauer (Meter pro Meter).
const FRONT_SLOPE := 0.72
## Der Berg reicht seitlich so weit und läuft dort unter dem Gelände aus.
const MOUND_HALF_WIDTH := 30.0
const MOUND_BASE := -6.0
## Der Einschnitt beginnt neben dem Gleis und erreicht die Hangkante an der Mauerecke.
const CUT_INNER := 3.4
const WALL_COVER := 7.2
## Netzreihen an der Mauerfront und im Mauerinneren.
const WALL_FRONT_ROW := 0.05
const WALL_BACK_ROW := -0.7


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


## Verschneiter Berg, in den das Portal eingelassen ist.
##
## Der Berg liegt auf der Portalmauer auf (Hangkante direkt hinter dem Gesims),
## steigt über der Röhre an und fällt zu den Seiten weit aus. Vor der Mauer
## schneidet ein felsiger Einschnitt die Gleistrasse frei: Seine Flanken
## laufen von den Mauerecken schräg zum Gleis hinunter – so wirkt die Mauer
## wie in den Hang gebaut. Alle Ränder liegen tief unter dem Gelände.
static func create_mound(tunnel_length: float, noise_seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := mound_noise(noise_seed)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = noise_seed
	var xs := _mound_columns()
	var zs := _mound_rows(tunnel_length)
	var grid: Array[PackedVector3Array] = []
	for z0 in zs:
		var row := PackedVector3Array()
		for x0 in xs:
			var x := x0
			var z := z0
			# Leichter Versatz für ein organisches Netz – nicht an Mauer, Einschnitt und Rand
			if not _is_key_column(x0):
				x += jitter.randf_range(-0.45, 0.45)
			if z0 < -1.5 and z0 > zs[zs.size() - 1]:
				z += jitter.randf_range(-0.6, 0.6)
			row.append(Vector3(x, mound_height(x, z, tunnel_length, noise), z))
		grid.append(row)

	for j in zs.size() - 1:
		for i in xs.size() - 1:
			# Zwischen Mauerfront und Mauerinnerem steht die Mauer selbst – dort kein Hang
			if is_equal_approx(zs[j], WALL_FRONT_ROW) and absf(xs[i]) <= WALL_COVER + 0.01 \
					and absf(xs[i + 1]) <= WALL_COVER + 0.01:
				continue
			var a := grid[j][i]
			var b := grid[j][i + 1]
			var c := grid[j + 1][i + 1]
			var d := grid[j + 1][i]
			for tri: Array[Vector3] in [[a, b, c], [a, c, d]] as Array[Array]:
				var highest := maxf(tri[0].y, maxf(tri[1].y, tri[2].y))
				if highest < MOUND_BASE + 0.5:
					continue  # liegt komplett im Boden
				var normal := LowPolyBuilder.face_normal(tri[0], tri[1], tri[2])
				if normal.y < 0.0:
					normal = -normal
				var color := ROCK_DARK
				if normal.y > 0.86:
					color = SNOW
				elif normal.y > 0.74:
					color = SNOW_SHADE
				elif normal.y > 0.5:
					color = ROCK
				color = color.lightened(jitter.randf_range(-0.025, 0.025))
				LowPolyBuilder.add_triangle_facing(st, tri[0], tri[1], tri[2], color, Vector3.UP)
	return st.commit()


## Höhe des Berges über Gleishöhe an der lokalen Stelle (x, z).
## Ohne den Zufallsversatz des Netzes – für Deko auf dem Berg genau genug.
static func mound_height(x: float, z: float, tunnel_length: float, noise: FastNoiseLite) -> float:
	var ax := absf(x)
	var top: float
	if z > WALL_BACK_ROW:
		top = RIDGE_HEIGHT - FRONT_SLOPE * maxf(z, 0.0)  # Hang vor der Mauer fällt zum Tal hin ab
	else:
		top = RIDGE_HEIGHT + 6.0 * smoothstep(0.7, 11.0, -z)
		top = lerpf(top, MOUND_BASE, smoothstep(tunnel_length + 2.0, tunnel_length + 14.0, -z))
	var width := 1.0 - smoothstep(7.5, MOUND_HALF_WIDTH, ax)
	var height := lerpf(MOUND_BASE, top, width)
	# Unruhe nur abseits der Mauer, damit Hangkante und Einschnitt sauber bleiben
	var calm := clampf(maxf(WALL_BACK_ROW - z, ax - WALL_COVER) / 6.0, 0.0, 1.0)
	height += noise.get_noise_2d(x, z) * 2.2 * calm * width
	if z > WALL_BACK_ROW:
		# Felseinschnitt: unten am Gleis flach, zur Mauerecke hin steil
		var t := clampf((ax - CUT_INNER) / (WALL_COVER - CUT_INNER), 0.0, 1.0)
		height = minf(height, -0.5 + (RIDGE_HEIGHT + 1.0) * pow(t, 1.3))
	return height


static func mound_noise(noise_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.07
	return noise


static func _mound_columns() -> PackedFloat32Array:
	var half := PackedFloat32Array([0.0, 1.7, CUT_INNER, 5.3, WALL_COVER, 9.0, 11.0, 13.5, 16.0, 19.0,
		22.5, 26.0, MOUND_HALF_WIDTH])
	var xs := PackedFloat32Array()
	for i in range(half.size() - 1, 0, -1):
		xs.append(-half[i])
	xs.append_array(half)
	return xs


## Reihen von vorne (Talseite) nach hinten (Bergseite).
static func _mound_rows(tunnel_length: float) -> PackedFloat32Array:
	var zs := PackedFloat32Array([17.0, 13.5, 11.0, 8.5, 6.0, 4.0, 2.0, WALL_FRONT_ROW, WALL_BACK_ROW, -2.5, -5.0])
	var z := -8.0
	while z > -tunnel_length - 16.0:
		zs.append(z)
		z -= 3.5
	zs.append(-tunnel_length - 17.0)
	return zs


static func _is_key_column(x: float) -> bool:
	var ax := absf(x)
	return ax < 0.01 or absf(ax - CUT_INNER) < 0.01 or absf(ax - WALL_COVER) < 0.01 \
		or ax > MOUND_HALF_WIDTH - 0.01


static func _in_opening(x: float, y: float, half_open: float, arch_center_y: float, margin: float) -> bool:
	if absf(x) > half_open + margin:
		return false
	if y < arch_center_y:
		return true
	return Vector2(x, y - arch_center_y).length() < half_open + margin
