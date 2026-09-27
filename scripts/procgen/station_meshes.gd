@tool
## Prozedurale Bahnhofs-Assets: Bahnsteig, Bank und Stationsschild.
##
## Der Bahnsteig liegt entlang der Z-Achse, Oberkante auf [param height].
## An beiden Enden führen Rampen auf den Boden.
class_name StationMeshes
extends RefCounted

const PAVING := Color(0.60, 0.58, 0.56)
const PAVING_DARK := Color(0.52, 0.50, 0.49)
const EDGE_STONE := Color(0.76, 0.75, 0.73)
const WALL := Color(0.47, 0.45, 0.44)
const SAFETY_LINE := Color(0.93, 0.90, 0.80)
const SNOW := Color(0.88, 0.91, 0.95)
const WOOD := Color(0.50, 0.33, 0.20)
const IRON := Color(0.18, 0.18, 0.20)
const SIGN_GREEN := Color(0.14, 0.27, 0.22)

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

	# Pflaster in 1-m-Kacheln, manche verschneit
	var inner := half_w - EDGE_WIDTH
	var columns := maxi(1, roundi(inner * 2.0))
	var rows := maxi(1, roundi(z1 - z0))
	for c in columns:
		for r in rows:
			var xa := lerpf(-inner, inner, float(c) / columns)
			var xb := lerpf(-inner, inner, float(c + 1) / columns)
			var za := lerpf(z0, z1, float(r) / rows)
			var zb := lerpf(z0, z1, float(r + 1) / rows)
			var color := SNOW if rng.randf() < 0.22 else (PAVING if rng.randf() < 0.6 else PAVING_DARK)
			LowPolyBuilder.add_quad_facing(st, Vector3(xa, height, za), Vector3(xb, height, za),
				Vector3(xb, height, zb), Vector3(xa, height, zb), _vary(color, rng), Vector3.UP)

	# Bahnsteigkanten (leicht überstehend) und weiße Sicherheitslinie
	for side: float in [-1.0, 1.0]:
		var edge_x: float = side * (half_w - EDGE_WIDTH * 0.5 + 0.03)
		LowPolyBuilder.add_box(st, Vector3(edge_x, height - 0.02, (z0 + z1) * 0.5),
			Vector3(EDGE_WIDTH + 0.06, 0.1, z1 - z0), EDGE_STONE)
		LowPolyBuilder.add_box(st, Vector3(side * (inner - 0.12), height + 0.004, (z0 + z1) * 0.5),
			Vector3(0.1, 0.01, z1 - z0), SAFETY_LINE)

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
	return st.commit()


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
		# Traufkante
		LowPolyBuilder.add_box(st, Vector3(outer.x, outer.y + 0.06, center.z), Vector3(0.08, 0.22, length), IRON)
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


static func _vary(color: Color, rng: RandomNumberGenerator, amount := 0.025) -> Color:
	var v := rng.randf_range(-amount, amount)
	return Color(color.r + v, color.g + v, color.b + v)
