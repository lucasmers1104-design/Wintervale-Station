@tool
## Prozedurale Bahnhofs-Assets: Bahnsteig, Bank und Stationsschild.
##
## Der Bahnsteig liegt entlang der Z-Achse, Oberkante auf [param height].
## An beiden Enden führen Rampen auf den Boden.
class_name StationMeshes
extends RefCounted

const PAVING := Color(0.68, 0.63, 0.57)
const PAVING_DARK := Color(0.6, 0.56, 0.51)
const EDGE_STONE := Color(0.8, 0.77, 0.72)
const WALL := Color(0.55, 0.5, 0.46)
const SAFETY_LINE := Color(0.93, 0.90, 0.80)
const SNOW := Color(0.88, 0.91, 0.95, 0.5)
const WOOD := Color(0.56, 0.37, 0.23)
const IRON := Color(0.18, 0.18, 0.20)
const SIGN_GREEN := Color(0.14, 0.27, 0.22)
## Zierbrett am Dach, Leitstreifen, Eis (Schneeauflage: taut im Frühling)
const VALANCE := Color(0.9, 0.86, 0.76)
const TACTILE := Color(0.84, 0.82, 0.78)
const ICE := Color(0.74, 0.86, 0.96, 0.5)

const RAMP_LENGTH := 2.5
const EDGE_WIDTH := 0.45
const WALL_BOTTOM := -0.4


static func create_platform(length: float, width: float, height: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := width * 0.5
	var z0 := -length * 0.5 + RAMP_LENGTH
	var z1 := length * 0.5 - RAMP_LENGTH

	# Seitenwände in 2-m-Abschnitten mit leicht wechselnder Steinfarbe
	var sections := maxi(1, ceili((z1 - z0) / 2.0))
	for i in sections:
		var za := lerpf(z0, z1, float(i) / sections)
		var zb := lerpf(z0, z1, float(i + 1) / sections)
		for side: float in [-1.0, 1.0]:
			var x: float = side * half_w
			LowPolyBuilder.add_quad_facing(st, Vector3(x, WALL_BOTTOM, za), Vector3(x, height, za),
				Vector3(x, height, zb), Vector3(x, WALL_BOTTOM, zb), _vary(WALL, rng), Vector3(side, 0, 0))

	# Sandsteinpflaster im Läuferverband (jede zweite Reihe um eine halbe Platte versetzt),
	# geräumt – nur vereinzelt liegen Schneereste
	var inner := half_w - EDGE_WIDTH
	var slab := 0.8
	var columns := maxi(1, roundi(inner * 2.0 / slab))
	var rows := maxi(1, roundi((z1 - z0) / 0.55))
	for r in rows:
		var za := lerpf(z0, z1, float(r) / rows)
		var zb := lerpf(z0, z1, float(r + 1) / rows)
		var shift := 0.5 if r % 2 == 1 else 0.0
		for c in range(0, columns + 1):
			var xa := clampf(lerpf(-inner, inner, (c - shift) / columns), -inner, inner)
			var xb := clampf(lerpf(-inner, inner, (c + 1 - shift) / columns), -inner, inner)
			if xb - xa < 0.01:
				continue
			var color := PAVING if rng.randf() < 0.55 else PAVING_DARK
			if rng.randf() < 0.07:
				color = Color(SNOW, 0.75)
			LowPolyBuilder.add_quad_facing(st, Vector3(xa, height, za), Vector3(xb, height, za),
				Vector3(xb, height, zb), Vector3(xa, height, zb), _vary(color, rng, 0.02), Vector3.UP)

	# Bahnsteigkanten (leicht überstehend) und weiße Sicherheitslinie
	for side: float in [-1.0, 1.0]:
		var edge_x: float = side * (half_w - EDGE_WIDTH * 0.5 + 0.03)
		LowPolyBuilder.add_box(st, Vector3(edge_x, height - 0.02, (z0 + z1) * 0.5),
			Vector3(EDGE_WIDTH + 0.06, 0.1, z1 - z0), EDGE_STONE)
		LowPolyBuilder.add_box(st, Vector3(side * (inner - 0.12), height + 0.004, (z0 + z1) * 0.5),
			Vector3(0.1, 0.01, z1 - z0), SAFETY_LINE)
		# Blindenleitstreifen: hellere Platten mit Längsrillen
		var strip_x := side * (inner - 0.5)
		LowPolyBuilder.add_box(st, Vector3(strip_x, height + 0.003, (z0 + z1) * 0.5), Vector3(0.3, 0.008, z1 - z0 - 0.4), TACTILE)
		for k in 4:
			LowPolyBuilder.add_box(st, Vector3(strip_x - 0.105 + k * 0.07, height + 0.01, (z0 + z1) * 0.5),
				Vector3(0.03, 0.008, z1 - z0 - 0.5), TACTILE.lightened(0.08))
		# Schattenfuge unter der überstehenden Kante
		LowPolyBuilder.add_box(st, Vector3(side * (half_w - 0.02), height - 0.1, (z0 + z1) * 0.5), Vector3(0.06, 0.05, z1 - z0),
			WALL.darkened(0.35))

	# Rampen an beiden Enden
	for end: float in [-1.0, 1.0]:
		var top_z: float = z1 if end > 0.0 else z0
		var foot_z: float = top_z + end * RAMP_LENGTH
		var slope_normal := Vector3(0.0, RAMP_LENGTH, end * height).normalized()
		LowPolyBuilder.add_quad_facing(st, Vector3(-half_w, height, top_z), Vector3(half_w, height, top_z),
			Vector3(half_w, 0.0, foot_z), Vector3(-half_w, 0.0, foot_z), _vary(PAVING_DARK, rng), slope_normal)
		for side: float in [-1.0, 1.0]:
			var x: float = side * half_w
			LowPolyBuilder.add_quad_facing(st, Vector3(x, WALL_BOTTOM, top_z), Vector3(x, height, top_z),
				Vector3(x, 0.0, foot_z), Vector3(x, WALL_BOTTOM, foot_z), _vary(WALL, rng), Vector3(side, 0, 0))
		LowPolyBuilder.add_quad_facing(st, Vector3(-half_w, WALL_BOTTOM, foot_z), Vector3(half_w, WALL_BOTTOM, foot_z),
			Vector3(half_w, 0.0, foot_z), Vector3(-half_w, 0.0, foot_z), WALL, Vector3(0, 0, end))
		# Geländer an beiden Seiten der Rampe (Pfosten, Handlauf, Knieleiste)
		for side: float in [-1.0, 1.0]:
			var x: float = side * (half_w - 0.08)
			var posts := 4
			var rail: Array[Vector3] = []
			for k in posts:
				var t := float(k) / (posts - 1)
				var z := lerpf(top_z - end * 0.3, foot_z - end * 0.15, t)
				var ground := lerpf(height, 0.0, clampf((z - top_z) / (foot_z - top_z), 0.0, 1.0))
				LowPolyBuilder.add_box(st, Vector3(x, ground + 0.5, z), Vector3(0.05, 1.0, 0.05), IRON)
				rail.append(Vector3(x, ground + 1.0, z))
			LowPolyBuilder.add_beam(st, rail[0], rail[-1], 0.06, IRON)
			LowPolyBuilder.add_beam(st, rail[0] - Vector3(0, 0.5, 0), rail[-1] - Vector3(0, 0.5, 0), 0.035, IRON)
			LowPolyBuilder.add_box(st, (rail[0] + rail[-1]) * 0.5 + Vector3(0, 0.04, 0), Vector3(0.07, 0.02, rail[0].distance_to(rail[-1]) * 0.8),
				SNOW)
	return st.commit()


## Pflanzkübel aus Holz (Fassdauben, zwei Eisenreifen) mit kleiner Tanne und Schneehaube.
static func add_planter(st: SurfaceTool, base: Vector3, rng: RandomNumberGenerator) -> void:
	var staves := 10
	for i in staves:
		var angle := TAU * i / staves
		var tint := _vary(WOOD, rng, 0.05)
		LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, -angle), base + Vector3(cos(angle), 0.0, sin(angle)) * 0.33
			+ Vector3(0.0, 0.25, 0.0)), Vector3(0.06, 0.5, 0.2), tint)
	for y: float in [0.1, 0.4]:
		LowPolyBuilder.add_cylinder(st, base + Vector3(0.0, y, 0.0), 0.37, 0.37, 0.04, 12, IRON)
	LowPolyBuilder.add_cylinder(st, base + Vector3(0.0, 0.42, 0.0), 0.31, 0.31, 0.04, 10, Color(0.3, 0.22, 0.17))
	var needles := Color(0.16, 0.33, 0.24)
	for k in 3:
		var y := 0.5 + k * 0.26
		var r := 0.34 - k * 0.09
		LowPolyBuilder.add_cone(st, base + Vector3(0.0, y, 0.0), r, 0.42, 7, needles.lightened(k * 0.04), k * 0.4)
		LowPolyBuilder.add_cone(st, base + Vector3(0.0, y + 0.2, 0.0), r * 0.62, 0.22, 7, SNOW, k * 0.4, false)


## Holzbank; Sitzfläche entlang Z, Blick in Richtung +X.
static func add_bench(st: SurfaceTool, origin: Vector3, rng: RandomNumberGenerator) -> void:
	var length := 1.6
	for z: float in [-0.65, 0.65]:
		LowPolyBuilder.add_box(st, origin + Vector3(0.0, 0.22, z), Vector3(0.45, 0.44, 0.06), IRON)
		LowPolyBuilder.add_box(st, origin + Vector3(-0.2, 0.62, z), Vector3(0.05, 0.4, 0.06), IRON)
	for i in 3:
		LowPolyBuilder.add_box(st, origin + Vector3(-0.15 + i * 0.14, 0.46, 0.0),
			Vector3(0.12, 0.04, length), _vary(WOOD, rng, 0.04))
	for i in 2:
		LowPolyBuilder.add_box(st, origin + Vector3(-0.22, 0.62 + i * 0.16, 0.0),
			Vector3(0.04, 0.12, length), _vary(WOOD, rng, 0.04))
	LowPolyBuilder.add_box(st, origin + Vector3(0.0, 0.495, 0.25), Vector3(0.3, 0.03, 0.7), SNOW)


## Stationsschild auf zwei Pfosten; die Tafel steht quer zur X-Achse.
## Rückgabe: Höhe der Tafelmitte (für die Beschriftung).
static func add_sign(st: SurfaceTool, origin: Vector3, board_width: float) -> float:
	var board_y := 2.1
	for z in [-board_width * 0.45, board_width * 0.45]:
		LowPolyBuilder.add_box(st, origin + Vector3(0.0, board_y * 0.5 + 0.1, z), Vector3(0.08, board_y + 0.2, 0.08), IRON)
	LowPolyBuilder.add_box(st, origin + Vector3(0.0, board_y, 0.0), Vector3(0.07, 0.5, board_width), SIGN_GREEN)
	LowPolyBuilder.add_box(st, origin + Vector3(0.0, board_y + 0.27, 0.0), Vector3(0.1, 0.04, board_width + 0.04), SNOW)
	return board_y


## Bahnsteigdach für einen Mittelbahnsteig: Stützen in der Mitte, leicht
## geneigte Dachflächen (Schmetterlingsdach), Holzuntersicht, Schnee obenauf.
## Rückgabe: Positionen der Hängelampen (für Lichter).
static func add_canopy(st: SurfaceTool, center: Vector3, length: float, width: float, height: float,
		rng: RandomNumberGenerator) -> Array[Vector3]:
	var roof_y := center.y + height
	var half_l := length * 0.5
	var half_w := width * 0.5
	var columns := maxi(2, roundi(length / 6.0) + 1)
	for i in columns:
		var z := center.z - half_l + 1.0 + i * (length - 2.0) / (columns - 1)
		LowPolyBuilder.add_cylinder(st, Vector3(center.x, center.y, z), 0.12, 0.1, height, 8, IRON)
		LowPolyBuilder.add_box(st, Vector3(center.x, center.y + 0.12, z), Vector3(0.36, 0.24, 0.36), IRON)
		# Kopfbänder zur Dachunterseite
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_beam(st, Vector3(center.x, roof_y - 0.9, z),
				Vector3(center.x + side * half_w * 0.8, roof_y + 0.08 * half_w * 0.8 - 0.05, z), 0.08, IRON)
	# Dachflächen: innen tiefer (Rinne), außen höher, Holzuntersicht
	var slope := 0.08
	for side: float in [-1.0, 1.0]:
		var inner := Vector3(center.x, roof_y, 0.0)
		var outer := Vector3(center.x + side * half_w, roof_y + slope * half_w, 0.0)
		var planks := int(length / 0.5)
		for i in planks:
			var z0 := center.z - half_l + i * 0.5
			var z1 := z0 + 0.5
			LowPolyBuilder.add_quad_facing(st, inner + Vector3(0, 0, z0), outer + Vector3(0, 0, z0), outer + Vector3(0, 0, z1),
				inner + Vector3(0, 0, z1), _vary(WOOD.lightened(0.1), rng, 0.04), Vector3.DOWN)
		var lift := Vector3(0.0, 0.12, 0.0)
		LowPolyBuilder.add_quad_facing(st, inner + lift + Vector3(0, 0, center.z - half_l), outer + lift + Vector3(0, 0, center.z - half_l),
			outer + lift + Vector3(0, 0, center.z + half_l), inner + lift + Vector3(0, 0, center.z + half_l), IRON.lightened(0.1), Vector3.UP)
		# Schnee auf dem Dach
		var snow := Vector3(0.0, 0.16, 0.0)
		LowPolyBuilder.add_quad_facing(st, inner + snow + Vector3(side * 0.15, 0, center.z - half_l + 0.1),
			outer + snow + Vector3(-side * 0.1, 0, center.z - half_l + 0.1), outer + snow + Vector3(-side * 0.1, 0, center.z + half_l - 0.1),
			inner + snow + Vector3(side * 0.15, 0, center.z + half_l - 0.1), SNOW, Vector3.UP)
		# Traufkante mit Dachrinne und Schneewulst
		LowPolyBuilder.add_box(st, Vector3(outer.x, outer.y + 0.06, center.z), Vector3(0.08, 0.22, length), IRON)
		LowPolyBuilder.add_cylinder_between(st, Vector3(outer.x + side * 0.1, outer.y - 0.01, center.z - half_l),
			Vector3(outer.x + side * 0.1, outer.y - 0.01, center.z + half_l), 0.06, 6, IRON.lightened(0.15))
		LowPolyBuilder.add_box(st, Vector3(outer.x + side * 0.04, outer.y + 0.23, center.z), Vector3(0.28, 0.1, length - 0.3), SNOW)
		# Zierbrett: Reihe spitz zulaufender Bretter unter der Traufe (klassischer Bahnhofsstil)
		_valance(st, Vector3(outer.x + side * 0.05, outer.y - 0.05, center.z), length, side, rng)
	LowPolyBuilder.add_box(st, Vector3(center.x, roof_y + 0.02, center.z), Vector3(0.3, 0.14, length), IRON)
	# Hängelampen
	var lamps: Array[Vector3] = []
	var lamp_count := maxi(2, roundi(length / 5.0))
	for i in lamp_count:
		var z := center.z - half_l + (i + 0.5) * length / lamp_count
		for side: float in [-1.0, 1.0]:
			var lamp := Vector3(center.x + side * half_w * 0.45, roof_y - 0.45, z)
			LowPolyBuilder.add_box(st, lamp + Vector3(0, 0.25, 0), Vector3(0.02, 0.4, 0.02), IRON)
			LowPolyBuilder.add_cylinder(st, lamp + Vector3(0, 0.02, 0), 0.08, 0.22, 0.14, 8, IRON)
			lamps.append(lamp)
	return lamps


## Zierbrett entlang einer Dachkante: spitze Bretter, darunter hier und da Eiszapfen.
static func _valance(st: SurfaceTool, top_center: Vector3, length: float, side: float, rng: RandomNumberGenerator) -> void:
	var board := 0.16
	var count := int(length / board)
	var outward := Vector3(side, 0.0, 0.0)
	for i in count:
		var z := top_center.z - length * 0.5 + (i + 0.5) * length / count
		var top := Vector3(top_center.x, top_center.y, z)
		var a := top + Vector3(0.0, 0.0, -board * 0.46)
		var b := top + Vector3(0.0, 0.0, board * 0.46)
		var shoulder := -0.26
		var tip := top + Vector3(0.0, -0.38, 0.0)
		var color := _vary(VALANCE, rng, 0.02)
		for face: float in [1.0, -1.0]:
			var off := outward * face * 0.012
			LowPolyBuilder.add_quad_facing(st, a + off, b + off, b + Vector3(0, shoulder, 0) + off, a + Vector3(0, shoulder, 0) + off,
				color, outward * face)
			LowPolyBuilder.add_triangle_facing(st, a + Vector3(0, shoulder, 0) + off, b + Vector3(0, shoulder, 0) + off, tip + off,
				color, outward * face)
		# Eiszapfen (tauen mit der Schneedecke)
		if rng.randf() < 0.28:
			var icicle := tip + Vector3(side * 0.05, 0.02, 0.0)
			LowPolyBuilder.add_cone(st, icicle, 0.025, -rng.randf_range(0.12, 0.32), 4, ICE, rng.randf() * TAU, false)
	# Grüne Deckleiste über dem Zierbrett
	LowPolyBuilder.add_box(st, top_center + Vector3(side * 0.02, 0.0, 0.0), Vector3(0.05, 0.06, length), SIGN_GREEN)


static func _vary(color: Color, rng: RandomNumberGenerator, amount := 0.025) -> Color:
	var v := rng.randf_range(-amount, amount)
	return Color(color.r + v, color.g + v, color.b + v, color.a)
