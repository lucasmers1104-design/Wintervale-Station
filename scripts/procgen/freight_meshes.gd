@tool
## Modelle des Güterbahnhofs im gemütlichen Low-Poly-Stil: Güterschuppen mit
## Laderampe, Lagerhalle, Portalkran (Gerüst, Laufkatze, Traverse, Greifer),
## Lagerflächen (Holzlager, Steinboxen, Stahlregal, Palettenplatz,
## Containerplatz), Lampenmasten, Fahnen, Gabelstapler, Drehkran, Deko und Vögel.
##
## Etwas industrieller als das Dorf, aber mit denselben warmen Farben: rotes
## Holz, Sandstein, senfgelber Kran, viel Schnee, warme Lampen.
## Jede Funktion liefert {"body": ArrayMesh, "glow": ArrayMesh | null, …} in
## eigenen, lokalen Koordinaten (Ursprung am Boden) und wird zwischengespeichert.
class_name FreightMeshes
extends RefCounted

const SNOW := Color(0.92, 0.94, 0.98)
const SNOW_SHADE := Color(0.83, 0.87, 0.94)
const BOARD := Color(0.56, 0.2, 0.15)
const BOARD_DARK := Color(0.43, 0.15, 0.12)
const HALL := Color(0.37, 0.45, 0.39)
const HALL_DARK := Color(0.29, 0.36, 0.31)
const TRIM := Color(0.92, 0.88, 0.8)
const ROOF := Color(0.3, 0.31, 0.35)
const STONE := Color(0.66, 0.6, 0.52)
const STONE_DARK := Color(0.52, 0.48, 0.43)
const WOOD := Color(0.52, 0.36, 0.23)
const WOOD_DARK := Color(0.34, 0.24, 0.16)
const PLANK := Color(0.62, 0.47, 0.32)
const CRANE := Color(0.9, 0.64, 0.18)
const CRANE_DARK := Color(0.27, 0.24, 0.22)
const IRON := Color(0.16, 0.17, 0.19)
const CONCRETE := Color(0.68, 0.67, 0.63)
const BRICK := Color(0.62, 0.3, 0.22)
const GLASS_WARM := Color(1.0, 0.86, 0.6)
const INTERIOR := Color(0.12, 0.1, 0.09)
const GRAVEL := Color(0.62, 0.59, 0.55)
const RUBBER := Color(0.12, 0.12, 0.13)
const YELLOW := Color(0.95, 0.76, 0.22)
## Höhe der Laderampe (etwa Wagenboden).
const DOCK_HEIGHT := 1.2

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


# --- Güterschuppen ---------------------------------------------------------------------

## Güterschuppen mit Laderampe: Die Rampe liegt vorne (x 0…2,2), der Schuppen
## dahinter (x 2,2…10,2), Länge entlang Z (-8…8). Das Dach reicht als Vordach
## über die Rampe. Rückgabe zusätzlich: "lights" (Wandlampen), "chimney"
## (Rauchaustritt), "sign" (Schild über dem Tor), "door_open" (Mitte des offenen Tors).
static func goods_shed() -> Dictionary:
	if _cache.has("shed"):
		return _cache["shed"]
	var st := _new_st()
	var glow := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 881
	var x0 := 2.2
	var x1 := 10.2
	var half_z := 8.0
	var wall_top := 5.0
	var dock := DOCK_HEIGHT

	# Rampe: Sandsteinfront mit Fugen, Bohlenbelag, Stufen, Schneewehe
	LowPolyBuilder.add_box(st, Vector3(x0 * 0.5, (dock - 0.1) * 0.5, 0.0), Vector3(x0, dock - 0.1, half_z * 2.0 + 2.0), STONE)
	for i in 3:
		LowPolyBuilder.add_box(st, Vector3(-0.005, 0.28 + i * 0.3, 0.0), Vector3(0.02, 0.03, half_z * 2.0 + 2.0), STONE_DARK)
	var z := -half_z - 1.0
	var joint := 0
	while z < half_z + 1.0:
		var width := rng.randf_range(0.7, 1.1)
		LowPolyBuilder.add_box(st, Vector3(-0.005, 0.28 + (joint % 3) * 0.3 + 0.15, minf(z + width, half_z + 1.0)),
			Vector3(0.02, 0.28, 0.03), STONE_DARK)
		z += width
		joint += 1
	var plank_z := -half_z - 1.0
	var k := 0
	while plank_z < half_z + 1.0 - 0.01:
		var tone := PLANK.lerp(PLANK.darkened(0.18), float(k % 3) / 2.0).darkened(rng.randf() * 0.05)
		LowPolyBuilder.add_box(st, Vector3(x0 * 0.5, dock - 0.05, plank_z + 0.24), Vector3(x0 + 0.1, 0.1, 0.46), tone)
		plank_z += 0.5
		k += 1
	# Kante mit Stahlwinkel und gelber Markierung
	LowPolyBuilder.add_box(st, Vector3(0.03, dock - 0.02, 0.0), Vector3(0.08, 0.06, half_z * 2.0 + 2.0), IRON)
	LowPolyBuilder.add_box(st, Vector3(0.18, dock + 0.003, 0.0), Vector3(0.14, 0.01, half_z * 2.0 + 2.0), YELLOW)
	for i in 3:
		var step_y := dock - 0.3 * (i + 1)
		LowPolyBuilder.add_box(st, Vector3(x0 * 0.5, step_y + 0.15, half_z + 1.2 + i * 0.35), Vector3(x0, 0.3, 0.35 + i * 0.35 + 0.01), STONE)
	# Schneewehe vor der Rampe und Schneereste an der Kante
	for i in 7:
		var sz := -half_z + i * 2.6 + rng.randf_range(-0.4, 0.4)
		LowPolyBuilder.add_box(st, Vector3(-0.25, 0.1, sz), Vector3(0.6, 0.22, rng.randf_range(1.0, 1.9)), SNOW_SHADE)
	LowPolyBuilder.add_box(st, Vector3(1.9, dock + 0.02, half_z + 0.6), Vector3(0.5, 0.05, 1.0), SNOW)

	# Sockel und Wände (Stülpschalung mit Deckleisten), Eckbretter
	LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, dock * 0.5, 0.0), Vector3(x1 - x0, dock, half_z * 2.0), STONE)
	var wall_h := wall_top - dock
	LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, dock + wall_h * 0.5, 0.0), Vector3(x1 - x0, wall_h, half_z * 2.0), BOARD)
	var bz := -half_z + 0.2
	while bz < half_z - 0.1:
		for x_face: float in [x0 - 0.02, x1 + 0.02]:
			LowPolyBuilder.add_box(st, Vector3(x_face, dock + wall_h * 0.5, bz), Vector3(0.04, wall_h, 0.07), BOARD_DARK)
		bz += 0.45
	var bx := x0 + 0.25
	while bx < x1 - 0.1:
		for z_face: float in [-half_z - 0.02, half_z + 0.02]:
			LowPolyBuilder.add_box(st, Vector3(bx, dock + wall_h * 0.5, z_face), Vector3(0.07, wall_h, 0.04), BOARD_DARK)
		bx += 0.45
	for cx: float in [x0, x1]:
		for cz: float in [-half_z, half_z]:
			LowPolyBuilder.add_box(st, Vector3(cx, dock + wall_h * 0.5, cz), Vector3(0.2, wall_h, 0.2), TRIM)
	LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, dock + 0.06, 0.0), Vector3(x1 - x0 + 0.1, 0.12, half_z * 2.0 + 0.1), TRIM)

	# Drei Schiebetore zur Rampe; das mittlere steht halb offen (warmes Licht drinnen)
	var door_w := 2.4
	var door_h := 2.9
	for door_z: float in [-5.0, 0.0, 5.0]:
		var open := door_z == 0.0
		var panel_z := door_z + (1.7 if open else 0.0)
		if open:
			LowPolyBuilder.add_box(st, Vector3(x0 + 0.02, dock + door_h * 0.5, door_z), Vector3(0.06, door_h, door_w), INTERIOR)
			LowPolyBuilder.add_box(glow, Vector3(x0 + 0.06, dock + door_h * 0.62, door_z), Vector3(0.02, door_h * 0.6, door_w * 0.7),
				GLASS_WARM.darkened(0.55))
		LowPolyBuilder.add_box(st, Vector3(x0 - 0.08, dock + door_h * 0.5, panel_z), Vector3(0.08, door_h, door_w), WOOD_DARK)
		for s: float in [-1.0, 1.0]:
			LowPolyBuilder.add_beam(st, Vector3(x0 - 0.13, dock + 0.15, panel_z + s * (door_w * 0.5 - 0.15)),
				Vector3(x0 - 0.13, dock + door_h - 0.15, panel_z - s * (door_w * 0.5 - 0.15)), 0.09, TRIM)
		LowPolyBuilder.add_box(st, Vector3(x0 - 0.13, dock + door_h * 0.5, panel_z), Vector3(0.05, door_h, 0.1), TRIM)
		for edge: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(st, Vector3(x0 - 0.12, dock + door_h * 0.5, panel_z + edge * (door_w * 0.5 - 0.05)),
				Vector3(0.06, door_h, 0.1), TRIM)
		LowPolyBuilder.add_box(st, Vector3(x0 - 0.12, dock + door_h - 0.05, panel_z), Vector3(0.06, 0.1, door_w), TRIM)
		# Laufschiene über dem Tor
		LowPolyBuilder.add_box(st, Vector3(x0 - 0.1, dock + door_h + 0.18, door_z + 0.8), Vector3(0.1, 0.1, door_w * 2.0), IRON)
	# Fenster: Rückwand und Giebelseiten
	var windows: Array = []
	for wz: float in [-5.5, -2.0, 2.0, 5.5]:
		windows.append([Vector3(x1 + 0.02, dock + 2.3, wz), Vector3.RIGHT])
	for wx: float in [4.4, 8.0]:
		windows.append([Vector3(wx, dock + 2.3, -half_z - 0.02), Vector3.FORWARD])
		windows.append([Vector3(wx, dock + 2.3, half_z + 0.02), Vector3.BACK])
	for w: Array in windows:
		_window(st, glow, w[0], w[1], Vector2(1.0, 1.2))

	# Satteldach, First entlang Z, Vordach über der Rampe
	var ridge := Vector2(6.2, 7.1)
	var west := Vector2(-0.7, 3.65)
	var east := Vector2(x1 + 0.7, 5.0 - 0.2)
	_roof_plane(st, west, ridge, half_z + 0.6, 0.16)
	_roof_plane(st, east, ridge, half_z + 0.6, 0.16)
	# Giebeldreiecke (Holz) und Stirnbretter
	for gz: float in [-half_z, half_z]:
		var out := signf(gz)
		LowPolyBuilder.add_triangle_facing(st, Vector3(x0, wall_top, gz), Vector3(x1, wall_top, gz), Vector3(ridge.x, ridge.y - 0.1, gz),
			BOARD, Vector3(0, 0, out))
		for edge: Vector2 in [west, east]:
			LowPolyBuilder.add_beam(st, Vector3(edge.x, edge.y + 0.08, gz + out * 0.62), Vector3(ridge.x, ridge.y + 0.08, gz + out * 0.62), 0.14, TRIM)
	# Kopfbänder unter dem Vordach
	for kz: float in [-7.0, -2.5, 2.5, 7.0]:
		LowPolyBuilder.add_beam(st, Vector3(x0 - 0.05, 3.3, kz), Vector3(0.2, 3.95, kz), 0.14, WOOD_DARK)
		LowPolyBuilder.add_beam(st, Vector3(x0 - 0.05, 4.3, kz), Vector3(x0 - 0.05, 3.2, kz), 0.12, WOOD_DARK)
	# Schornstein aus Ziegeln
	var chimney := Vector3(8.2, 0.0, -5.0)
	LowPolyBuilder.add_box(st, Vector3(chimney.x, 6.3, chimney.z), Vector3(0.6, 2.4, 0.6), BRICK)
	LowPolyBuilder.add_box(st, Vector3(chimney.x, 7.55, chimney.z), Vector3(0.75, 0.12, 0.75), STONE_DARK)
	LowPolyBuilder.add_box(st, Vector3(chimney.x, 7.64, chimney.z), Vector3(0.66, 0.06, 0.66), SNOW)
	# Schild über dem mittleren Tor
	var sign := Vector3(x0 - 0.18, 4.55, 0.0)
	LowPolyBuilder.add_box(st, sign + Vector3(0.05, 0.0, 0.0), Vector3(0.08, 0.62, 4.2), BOARD_DARK)
	LowPolyBuilder.add_box(st, sign, Vector3(0.06, 0.5, 4.05), TRIM)
	# Wandlampen (Schwanenhals) über den Toren
	var lights: Array[Vector3] = []
	for lz: float in [-5.0, 5.0, -2.4, 2.4]:
		var base := Vector3(x0 - 0.05, 4.35 if absf(lz) > 3.0 else 3.95, lz)
		LowPolyBuilder.add_beam(st, base, base + Vector3(-0.45, 0.2, 0.0), 0.05, IRON)
		LowPolyBuilder.add_cone(st, base + Vector3(-0.5, -0.02, 0.0), 0.22, 0.18, 8, IRON)
		LowPolyBuilder.add_cylinder(glow, base + Vector3(-0.5, -0.1, 0.0), 0.12, 0.12, 0.09, 8, GLASS_WARM)
		lights.append(base + Vector3(-0.5, -0.25, 0.0))
	# Kleinkram auf der Rampe: Fässer, Kisten, Sackkarre
	for p: Vector3 in [Vector3(1.4, dock, -7.2), Vector3(0.9, dock, -6.7)]:
		LowPolyBuilder.add_cylinder(st, p, 0.3, 0.3, 0.85, 10, Color(0.3, 0.42, 0.5))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.85, 0), 0.26, 0.2, 0.04, 10, SNOW)
	for p: Vector3 in [Vector3(1.3, dock, 6.9), Vector3(1.35, dock + 0.6, 6.95), Vector3(0.7, dock, 7.4)]:
		LowPolyBuilder.add_box(st, p + Vector3(0, 0.3, 0), Vector3(0.62, 0.6, 0.62), WOOD.lerp(PLANK, rng.randf()))
	LowPolyBuilder.add_box(st, Vector3(1.35, dock + 1.23, 6.95), Vector3(0.56, 0.04, 0.56), SNOW)

	var result := {"body": st.commit(), "glow": glow.commit(), "lights": lights,
		"chimney": Vector3(chimney.x, 7.7, chimney.z), "sign": sign + Vector3(-0.04, 0.0, 0.0),
		"door_open": Vector3(x0, dock, 0.0), "size": Vector3(x1 + 0.7, 7.2, half_z * 2.0 + 2.0)}
	_cache["shed"] = result
	return result


# --- Lagerhalle ------------------------------------------------------------------------

## Große Lagerhalle: Ziegelsockel, grüne Holzverschalung, großes Schiebetor an
## der Giebelseite -Z, Oberlichter, Lüftungshauben. Ursprung = Mitte am Boden.
static func warehouse() -> Dictionary:
	if _cache.has("warehouse"):
		return _cache["warehouse"]
	var st := _new_st()
	var glow := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var hx := 6.0
	var hz := 9.0
	var eave := 6.2
	var ridge_y := 8.6
	LowPolyBuilder.add_box(st, Vector3(0, 0.25, 0), Vector3(hx * 2.0 + 0.3, 0.5, hz * 2.0 + 0.3), CONCRETE)
	# Ziegelsockel mit Fugenlinien
	LowPolyBuilder.add_box(st, Vector3(0, 1.15, 0), Vector3(hx * 2.0, 1.3, hz * 2.0), BRICK)
	for i in 5:
		var y := 0.62 + i * 0.26
		LowPolyBuilder.add_box(st, Vector3(0, y, 0), Vector3(hx * 2.0 + 0.02, 0.025, hz * 2.0 + 0.02), BRICK.lightened(0.25))
	LowPolyBuilder.add_box(st, Vector3(0, 1.85, 0), Vector3(hx * 2.0 + 0.12, 0.12, hz * 2.0 + 0.12), STONE)
	# Holzverschalung darüber
	LowPolyBuilder.add_box(st, Vector3(0, (1.9 + eave) * 0.5, 0), Vector3(hx * 2.0 - 0.04, eave - 1.9, hz * 2.0 - 0.04), HALL)
	var z := -hz + 0.3
	while z < hz - 0.1:
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(st, Vector3(side * (hx + 0.0), (1.9 + eave) * 0.5, z), Vector3(0.05, eave - 1.9, 0.08), HALL_DARK)
		z += 0.5
	var x := -hx + 0.3
	while x < hx - 0.1:
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(st, Vector3(x, (1.9 + eave) * 0.5, side * hz), Vector3(0.08, eave - 1.9, 0.05), HALL_DARK)
		x += 0.5
	for cx: float in [-hx, hx]:
		for cz: float in [-hz, hz]:
			LowPolyBuilder.add_box(st, Vector3(cx, (0.5 + eave) * 0.5, cz), Vector3(0.24, eave - 0.5, 0.24), TRIM)
	# Großes Tor (halb offen) an der Giebelseite -Z
	var door_w := 5.0
	var door_h := 4.6
	LowPolyBuilder.add_box(st, Vector3(0, 0.5 + door_h * 0.5, -hz - 0.01), Vector3(door_w, door_h, 0.06), INTERIOR)
	LowPolyBuilder.add_box(glow, Vector3(0.6, 0.5 + door_h * 0.45, -hz + 0.05), Vector3(door_w * 0.5, door_h * 0.5, 0.02), GLASS_WARM.darkened(0.6))
	for panel_x: float in [-door_w * 0.5 - 0.1, -door_w * 0.25 + 0.25]:
		LowPolyBuilder.add_box(st, Vector3(panel_x, 0.5 + door_h * 0.5, -hz - 0.1), Vector3(door_w * 0.5, door_h, 0.1), WOOD_DARK)
		for i in 6:
			LowPolyBuilder.add_box(st, Vector3(panel_x - door_w * 0.25 + 0.2 + i * 0.42, 0.5 + door_h * 0.5, -hz - 0.16),
				Vector3(0.06, door_h - 0.2, 0.04), WOOD)
		LowPolyBuilder.add_beam(st, Vector3(panel_x - door_w * 0.22, 0.7, -hz - 0.17), Vector3(panel_x + door_w * 0.22, 0.5 + door_h - 0.2, -hz - 0.17),
			0.1, TRIM)
	LowPolyBuilder.add_box(st, Vector3(0, 0.5 + door_h + 0.2, -hz - 0.12), Vector3(door_w * 1.9, 0.12, 0.12), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 0.5 + door_h + 0.35, -hz - 0.05), Vector3(door_w + 0.4, 0.18, 0.1), TRIM)
	# Hohe Fensterreihen an den Längsseiten
	for side: float in [-1.0, 1.0]:
		for i in 5:
			_window(st, glow, Vector3(side * (hx + 0.03), 4.6, -6.4 + i * 3.2), Vector3(side, 0, 0), Vector2(1.6, 1.0))
	_window(st, glow, Vector3(-3.6, 3.4, -hz - 0.03), Vector3.FORWARD, Vector2(1.1, 1.1))
	_window(st, glow, Vector3(3.8, 3.4, hz + 0.03), Vector3.BACK, Vector2(1.1, 1.1))
	# Seitentür mit Lampe (+X)
	LowPolyBuilder.add_box(st, Vector3(hx + 0.04, 1.6, 5.5), Vector3(0.06, 2.2, 1.1), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(hx + 0.06, 2.75, 5.5), Vector3(0.05, 0.1, 1.3), TRIM)
	# Dach mit Oberlichtern, Lüftungshauben, Schnee
	_roof_plane(st, Vector2(-hx - 0.7, eave - 0.3), Vector2(0.0, ridge_y), hz + 0.7, 0.18, true)
	_roof_plane(st, Vector2(hx + 0.7, eave - 0.3), Vector2(0.0, ridge_y), hz + 0.7, 0.18, true)
	for gz: float in [-hz, hz]:
		var out := signf(gz)
		LowPolyBuilder.add_triangle_facing(st, Vector3(-hx, eave, gz), Vector3(hx, eave, gz), Vector3(0, ridge_y - 0.1, gz), HALL, Vector3(0, 0, out))
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_beam(st, Vector3(side * (hx + 0.7), eave - 0.2, gz + out * 0.72), Vector3(0, ridge_y + 0.1, gz + out * 0.72), 0.16, TRIM)
	for vz: float in [-4.0, 4.0]:
		LowPolyBuilder.add_box(st, Vector3(0, ridge_y + 0.35, vz), Vector3(1.0, 0.7, 1.0), HALL_DARK)
		LowPolyBuilder.add_cone(st, Vector3(0, ridge_y + 0.7, vz), 0.95, 0.55, 4, ROOF, PI * 0.25)
		LowPolyBuilder.add_cone(st, Vector3(0, ridge_y + 0.78, vz), 0.7, 0.4, 4, SNOW, PI * 0.25, false)
	# Fallrohre
	for cx: float in [-hx - 0.1, hx + 0.1]:
		for cz: float in [-hz + 0.2, hz - 0.2]:
			LowPolyBuilder.add_cylinder(st, Vector3(cx, 0.5, cz), 0.07, 0.07, eave - 0.6, 6, IRON)
	# Lampen über den Toren
	var lights: Array[Vector3] = []
	for lamp: Vector3 in [Vector3(0, 5.55, -hz - 0.35), Vector3(hx + 0.35, 3.1, 5.5)]:
		var wall := Vector3(lamp.x, lamp.y + 0.25, -hz) if lamp.z < 0.0 else Vector3(hx, lamp.y + 0.25, lamp.z)
		LowPolyBuilder.add_beam(st, wall, lamp + Vector3(0, 0.2, 0), 0.05, IRON)
		LowPolyBuilder.add_cone(st, lamp + Vector3(0, 0.02, 0), 0.26, 0.2, 8, IRON)
		LowPolyBuilder.add_cylinder(glow, lamp + Vector3(0, -0.08, 0), 0.14, 0.14, 0.09, 8, GLASS_WARM)
		lights.append(lamp + Vector3(0, -0.2, 0))
	var result := {"body": st.commit(), "glow": glow.commit(), "lights": lights,
		"chimney": Vector3(3.2, ridge_y - 0.6, 5.0), "sign": Vector3(0, 5.95, -hz - 0.2),
		"size": Vector3(hx * 2.0 + 1.4, ridge_y + 0.8, hz * 2.0 + 1.4)}
	# kleiner Blechschornstein fürs Öfchen
	LowPolyBuilder.add_cylinder(st, Vector3(3.2, 7.2, 5.0), 0.14, 0.14, 1.3, 8, IRON)
	result["body"] = st.commit()
	_cache["warehouse"] = result
	return result


# --- Portalkran --------------------------------------------------------------------------

## Kranbahn: zwei Schienen auf Schwellen (Ursprung = Mitte der Westschiene am
## Anfang, Schienen entlang +Z, Abstand [param span]).
static func crane_rails(span: float, length: float) -> ArrayMesh:
	var key := "crane_rails|%.1f|%.1f" % [span, length]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	for x: float in [0.0, span]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.06, length * 0.5), Vector3(0.9, 0.12, length + 1.0), CONCRETE.darkened(0.08))
		LowPolyBuilder.add_box(st, Vector3(x, 0.18, length * 0.5), Vector3(0.12, 0.12, length + 0.6), Color(0.45, 0.43, 0.42))
		for end: float in [-0.3, length + 0.3]:
			LowPolyBuilder.add_box(st, Vector3(x, 0.4, end), Vector3(0.5, 0.5, 0.3), YELLOW)
			LowPolyBuilder.add_box(st, Vector3(x, 0.66, end), Vector3(0.44, 0.04, 0.26), SNOW)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Kranportal: zwei Stützen mit Fahrwerken (x = 0 und x = [param span]),
## Fachwerkträger in [param height] Höhe, Laufsteg mit Geländer, Führerhaus,
## Arbeitslampen. "lights" = Lampen unter dem Träger (lokal).
static func crane_gantry(span: float, height: float) -> Dictionary:
	var key := "gantry|%.1f|%.1f" % [span, height]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var glow := _new_st()
	var top := height + 1.2
	for x: float in [0.0, span]:
		# Fahrwerksträger mit zwei Laufrädern je Seite
		LowPolyBuilder.add_box(st, Vector3(x, 0.72, 0.0), Vector3(0.55, 0.55, 5.4), CRANE)
		for wz: float in [-2.2, 2.2]:
			LowPolyBuilder.add_box(st, Vector3(x, 0.42, wz), Vector3(0.62, 0.34, 0.9), CRANE_DARK)
			for side: float in [-1.0, 1.0]:
				LowPolyBuilder.add_cylinder_between(st, Vector3(x + side * 0.33, 0.33, wz), Vector3(x + side * 0.36, 0.33, wz), 0.26, 10, IRON)
		for end: float in [-1.0, 1.0]:
			for i in 4:
				LowPolyBuilder.add_box(st, Vector3(x, 0.72, end * 2.72), Vector3(0.56, 0.12, 0.02),
					YELLOW if i % 2 == 0 else CRANE_DARK)
		# Zwei schräge Stützen (A-Form) und Querriegel
		for s: float in [-1.0, 1.0]:
			LowPolyBuilder.add_beam(st, Vector3(x, 0.95, s * 2.2), Vector3(x, height, s * 0.62), 0.42, CRANE)
		LowPolyBuilder.add_box(st, Vector3(x, height * 0.45, 0.0), Vector3(0.3, 0.3, 2.6), CRANE)
		LowPolyBuilder.add_box(st, Vector3(x, height - 0.2, 0.0), Vector3(0.5, 0.5, 1.8), CRANE)
	# Leiter an der Oststütze
	for s: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(span + 0.45, height * 0.5 + 0.4, s * 0.25), Vector3(0.05, height - 0.6, 0.05), CRANE_DARK)
	for i in int(height / 0.35):
		LowPolyBuilder.add_box(st, Vector3(span + 0.45, 0.9 + i * 0.35, 0.0), Vector3(0.04, 0.04, 0.5), CRANE_DARK)
	# Fachwerkträger: Ober- und Untergurte, Pfosten und Diagonalen auf beiden Seiten
	var x_start := -1.4
	var x_end := span + 1.4
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, height + 0.1, side * 0.6), Vector3(x_end - x_start, 0.24, 0.22), CRANE)
		LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, top, side * 0.6), Vector3(x_end - x_start, 0.24, 0.22), CRANE)
		var steps := int((x_end - x_start) / 1.3)
		for i in steps + 1:
			var px := x_start + i * (x_end - x_start) / steps
			LowPolyBuilder.add_box(st, Vector3(px, height + 0.65, side * 0.6), Vector3(0.12, 1.0, 0.12), CRANE)
			if i < steps:
				var nx := x_start + (i + 1) * (x_end - x_start) / steps
				var up := i % 2 == 0
				LowPolyBuilder.add_beam(st, Vector3(px, height + (0.2 if up else 1.1), side * 0.6),
					Vector3(nx, height + (1.1 if up else 0.2), side * 0.6), 0.09, CRANE)
		# Laufschienen der Katze
		LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, top + 0.16, side * 0.6), Vector3(x_end - x_start - 0.4, 0.08, 0.1), IRON)
		# Schnee auf dem Obergurt
		LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, top + 0.13, side * 0.6 + side * 0.08), Vector3(x_end - x_start - 0.3, 0.05, 0.06), SNOW)
	# Querverbände, Stirnplatten mit Warnstreifen
	var cross := x_start
	while cross <= x_end:
		LowPolyBuilder.add_box(st, Vector3(cross, height + 0.1, 0.0), Vector3(0.1, 0.1, 1.2), CRANE)
		cross += 2.6
	for end_x: float in [x_start - 0.05, x_end + 0.05]:
		LowPolyBuilder.add_box(st, Vector3(end_x, height + 0.65, 0.0), Vector3(0.06, 1.3, 1.44), CRANE_DARK)
		for i in 5:
			LowPolyBuilder.add_box(st, Vector3(end_x + signf(end_x) * 0.03, height + 0.2 + i * 0.24, 0.0), Vector3(0.02, 0.12, 1.4), YELLOW)
	# Laufsteg mit Geländer auf der Südseite
	LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, height + 0.05, 1.15), Vector3(x_end - x_start, 0.06, 0.8), Color(0.4, 0.4, 0.42))
	var post := x_start + 0.2
	while post < x_end:
		LowPolyBuilder.add_box(st, Vector3(post, height + 0.55, 1.52), Vector3(0.05, 1.0, 0.05), YELLOW)
		post += 1.5
	LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, height + 1.05, 1.52), Vector3(x_end - x_start, 0.05, 0.05), YELLOW)
	LowPolyBuilder.add_box(st, Vector3((x_start + x_end) * 0.5, height + 0.6, 1.52), Vector3(x_end - x_start, 0.04, 0.04), YELLOW)
	# Führerhaus unter dem Träger nahe der Oststütze
	var cab := Vector3(span - 2.2, height - 1.05, -0.2)
	LowPolyBuilder.add_box(st, cab, Vector3(1.7, 1.9, 1.6), CRANE)
	LowPolyBuilder.add_box(st, cab + Vector3(0, 0.98, 0), Vector3(1.85, 0.1, 1.75), CRANE_DARK)
	LowPolyBuilder.add_box(st, cab + Vector3(0, 1.05, 0), Vector3(1.7, 0.05, 1.6), SNOW)
	for face: Vector3 in [Vector3(-0.86, 0.15, 0), Vector3(0, 0.15, -0.81), Vector3(0, 0.15, 0.81)]:
		var size := Vector3(0.02, 0.8, 1.2) if face.x != 0.0 else Vector3(1.3, 0.8, 0.02)
		LowPolyBuilder.add_box(glow, cab + face, size, GLASS_WARM.darkened(0.25))
	LowPolyBuilder.add_box(st, cab + Vector3(0, 1.4, 0), Vector3(0.3, 0.8, 0.3), CRANE)
	# Arbeitslampen unter dem Träger
	var lights: Array[Vector3] = []
	for f: float in [0.18, 0.5, 0.82]:
		var lamp := Vector3(span * f, height - 0.12, 0.0)
		LowPolyBuilder.add_box(st, lamp + Vector3(0, 0.08, 0), Vector3(0.5, 0.14, 0.4), CRANE_DARK)
		LowPolyBuilder.add_box(glow, lamp, Vector3(0.42, 0.04, 0.32), GLASS_WARM)
		lights.append(lamp + Vector3(0, -0.3, 0))
	# Kleines Fähnchen oben auf der Oststütze
	LowPolyBuilder.add_cylinder(st, Vector3(span + 1.2, top + 0.2, 0.0), 0.03, 0.03, 1.4, 6, IRON)
	var result := {"body": st.commit(), "glow": glow.commit(), "lights": lights, "flag": Vector3(span + 1.2, top + 1.5, 0.0)}
	_cache[key] = result
	return result


## Laufkatze mit Windenhaus (Ursprung = Mitte auf den Katzschienen).
static func crane_trolley() -> Dictionary:
	if _cache.has("trolley"):
		return _cache["trolley"]
	var st := _new_st()
	var glow := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.3, 0), Vector3(2.0, 0.3, 1.6), CRANE_DARK)
	for x: float in [-0.75, 0.75]:
		for z: float in [-0.6, 0.6]:
			LowPolyBuilder.add_cylinder_between(st, Vector3(x, 0.12, z - 0.08), Vector3(x, 0.12, z + 0.08), 0.13, 8, IRON)
	LowPolyBuilder.add_box(st, Vector3(0.25, 0.95, 0), Vector3(1.3, 1.0, 1.3), CRANE)
	LowPolyBuilder.add_box(st, Vector3(0.25, 1.5, 0), Vector3(1.5, 0.1, 1.5), CRANE_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.25, 1.57, 0), Vector3(1.35, 0.05, 1.35), SNOW)
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.65, 0.65, -0.55), Vector3(-0.65, 0.65, 0.55), 0.24, 10, Color(0.4, 0.4, 0.42))
	for z: float in [-0.3, 0.3]:
		LowPolyBuilder.add_cylinder_between(st, Vector3(-0.65, 0.65, z - 0.06), Vector3(-0.65, 0.65, z + 0.06), 0.27, 10, IRON)
	LowPolyBuilder.add_box(glow, Vector3(0.91, 1.0, 0.0), Vector3(0.02, 0.3, 0.5), GLASS_WARM)
	var result := {"body": st.commit(), "glow": glow.commit()}
	_cache["trolley"] = result
	return result


## Unterflasche mit Traverse (Lastbalken) – Ursprung = Seilaufhängung oben.
## Die Last hängt mit ihrer Oberkante bei y = [constant HOOK_LOAD_Y].
const HOOK_LOAD_Y := -1.45


static func crane_hook() -> ArrayMesh:
	if _cache.has("hook"):
		return _cache["hook"]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, -0.3, 0), Vector3(0.55, 0.55, 0.36), CRANE)
	for z: float in [-0.12, 0.12]:
		LowPolyBuilder.add_cylinder_between(st, Vector3(-0.3, -0.25, z), Vector3(0.3, -0.25, z), 0.2, 10, IRON)
	for i in 5:
		LowPolyBuilder.add_box(st, Vector3(0.28, -0.1 - i * 0.1, 0), Vector3(0.02, 0.05, 0.37), YELLOW if i % 2 == 0 else CRANE_DARK)
	LowPolyBuilder.add_box(st, Vector3(0, -0.7, 0), Vector3(0.28, 0.3, 0.28), IRON)
	# Traverse entlang Z mit vier Anschlagketten
	LowPolyBuilder.add_box(st, Vector3(0, -0.95, 0), Vector3(0.3, 0.26, 3.2), YELLOW)
	for i in 6:
		LowPolyBuilder.add_box(st, Vector3(0.16, -0.95, -1.35 + i * 0.54), Vector3(0.02, 0.2, 0.22), CRANE_DARK)
	for x: float in [-0.9, 0.9]:
		for z: float in [-1.35, 1.35]:
			LowPolyBuilder.add_beam(st, Vector3(0, -1.05, z), Vector3(x, HOOK_LOAD_Y + 0.02, z), 0.035, IRON)
	var mesh := st.commit()
	_cache["hook"] = mesh
	return mesh


## Eine Schale des Greifers (für Schüttgut); zwei davon spiegelbildlich an Scharnieren.
## Ursprung = Scharnier, die Schale hängt nach unten und öffnet um die Z-Achse.
static func grab_jaw() -> ArrayMesh:
	if _cache.has("jaw"):
		return _cache["jaw"]
	var st := _new_st()
	var steps := 5
	var width := 1.0
	for i in steps:
		var a0 := PI * 0.5 * i / steps
		var a1 := PI * 0.5 * (i + 1) / steps
		var p0 := Vector3(sin(a0) * 0.75, -cos(a0) * 0.75, 0)
		var p1 := Vector3(sin(a1) * 0.75, -cos(a1) * 0.75, 0)
		var out := Vector3(sin((a0 + a1) * 0.5), -cos((a0 + a1) * 0.5), 0)
		LowPolyBuilder.add_quad_facing(st, p0 + Vector3(0, 0, -width * 0.5), p1 + Vector3(0, 0, -width * 0.5),
			p1 + Vector3(0, 0, width * 0.5), p0 + Vector3(0, 0, width * 0.5), CRANE_DARK if i == 0 else CRANE, out)
		LowPolyBuilder.add_quad_facing(st, p0 + Vector3(0, 0, -width * 0.5), p1 + Vector3(0, 0, -width * 0.5),
			p1 + Vector3(0, 0, width * 0.5), p0 + Vector3(0, 0, width * 0.5), CRANE_DARK, -out)
		for s: float in [-1.0, 1.0]:
			LowPolyBuilder.add_triangle_facing(st, Vector3(0, 0, s * width * 0.5), p0 + Vector3(0, 0, s * width * 0.5),
				p1 + Vector3(0, 0, s * width * 0.5), CRANE, Vector3(0, 0, s))
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 0, -0.55), Vector3(0, 0, 0.55), 0.08, 8, IRON)
	var mesh := st.commit()
	_cache["jaw"] = mesh
	return mesh


## Greiferkopf (zwischen Seil und Schalen).
static func grab_head() -> ArrayMesh:
	if _cache.has("grab_head"):
		return _cache["grab_head"]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, -0.35, 0), Vector3(0.7, 0.6, 0.5), CRANE)
	LowPolyBuilder.add_box(st, Vector3(0, -0.72, 0), Vector3(0.3, 0.3, 1.1), CRANE_DARK)
	for s: float in [-1.0, 1.0]:
		LowPolyBuilder.add_beam(st, Vector3(s * 0.3, -0.5, 0), Vector3(s * 0.8, -1.4, 0), 0.08, IRON)
	var mesh := st.commit()
	_cache["grab_head"] = mesh
	return mesh


# --- Lagerflächen --------------------------------------------------------------------------

## Holzlager: Unterleger (Kanthölzer) und hohe Rungen zwischen den Spalten.
## [param columns] Spalten-Mitten (x), [param rows] Reihen-Mitten (z), lokal.
static func wood_rack(columns: Array, rows: Array) -> ArrayMesh:
	var key := "wood_rack|%s|%s" % [columns, rows]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	for cx: float in columns:
		for rz: float in rows:
			for z: float in [-0.85, 0.85]:
				LowPolyBuilder.add_box(st, Vector3(cx, 0.08, rz + z), Vector3(2.3, 0.16, 0.2), WOOD_DARK)
	var min_x: float = columns.min() - 1.35
	var max_x: float = columns.max() + 1.35
	var boundaries: Array[float] = [min_x]
	for i in columns.size() - 1:
		boundaries.append((float(columns[i]) + float(columns[i + 1])) * 0.5)
	boundaries.append(max_x)
	for bx in boundaries:
		for rz: float in rows:
			for z: float in [-1.1, 1.1]:
				LowPolyBuilder.add_box(st, Vector3(bx, 1.7, rz + z), Vector3(0.16, 3.4, 0.16), WOOD)
				LowPolyBuilder.add_box(st, Vector3(bx, 3.43, rz + z), Vector3(0.2, 0.06, 0.2), SNOW)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Steinboxen: [param count] nebeneinanderliegende Boxen aus Betonblöcken
## (Breite [param width] entlang X, Tiefe [param depth] entlang Z, offen nach -Z).
static func stone_bays(count: int, width: float, depth: float) -> ArrayMesh:
	var key := "bays|%d|%.1f|%.1f" % [count, width, depth]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var total := count * width
	var block := Vector3(0.8, 0.8, 1.6)
	for wall in count + 1:
		var x := -total * 0.5 + wall * width
		var z := -depth * 0.5 + block.z * 0.5
		while z < depth * 0.5:
			for layer in 2:
				var color := CONCRETE.darkened(rng.randf() * 0.08)
				LowPolyBuilder.add_box(st, Vector3(x, 0.4 + layer * 0.8, z), Vector3(block.x, block.y - 0.02, block.z - 0.03), color)
			LowPolyBuilder.add_box(st, Vector3(x, 1.62, z), Vector3(block.x - 0.1, 0.05, block.z - 0.2), SNOW)
			z += block.z
	var bx := -total * 0.5
	while bx < total * 0.5:
		for layer in 2:
			LowPolyBuilder.add_box(st, Vector3(bx + block.z * 0.5, 0.4 + layer * 0.8, depth * 0.5 + block.x * 0.5),
				Vector3(block.z - 0.03, block.y - 0.02, block.x), CONCRETE.darkened(rng.randf() * 0.08))
		LowPolyBuilder.add_box(st, Vector3(bx + block.z * 0.5, 1.62, depth * 0.5 + block.x * 0.5), Vector3(block.z - 0.2, 0.05, block.x - 0.1), SNOW)
		bx += block.z
	# Boden der Boxen (festgefahrener Kies)
	LowPolyBuilder.add_box(st, Vector3(0, 0.02, 0), Vector3(total, 0.04, depth), GRAVEL.darkened(0.1))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Unterleger für Paletten, Stahl oder Container (flache Kanthölzer bzw. Betonplatten).
static func sleepers(slots: Array, size: Vector2, concrete := false) -> ArrayMesh:
	var key := "sleepers|%s|%s|%s" % [slots, size, concrete]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	for slot: Vector3 in slots:
		if concrete:
			LowPolyBuilder.add_box(st, slot + Vector3(0, 0.06, 0), Vector3(size.x + 0.3, 0.12, size.y + 0.3), CONCRETE)
		else:
			for z: float in [-size.y * 0.32, size.y * 0.32]:
				LowPolyBuilder.add_box(st, slot + Vector3(0, 0.06, z), Vector3(size.x + 0.2, 0.12, 0.18), WOOD_DARK)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Fester Hofbelag: festgefahrener Schnee mit Kiesflecken und zwei Fahrspuren je
## Spur-Mitte in [param lanes] (Rechteck, lokal ab 0,0). Die Farben laufen weich
## ineinander (Farbe je Eckpunkt), damit keine Kacheln zu sehen sind.
static func yard_ground(size: Vector2, lanes: Array) -> ArrayMesh:
	var key := "ground|%s|%s" % [size, lanes]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var cell := 1.0
	var nx := int(size.x / cell)
	var nz := int(size.y / cell)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.06
	var color_at := func(x: float, z: float) -> Color:
		var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
		var color := SNOW.lerp(SNOW_SHADE, smoothstep(0.3, 0.6, n)).lerp(GRAVEL.lightened(0.12), smoothstep(0.62, 0.85, n) * 0.7)
		for lane: float in lanes:
			for track: float in [-0.75, 0.75]:
				var d := absf(x - lane - track)
				color = color.lerp(GRAVEL.lightened(0.05), (1.0 - smoothstep(0.15, 0.4, d)) * 0.45)
		return color
	for i in nx:
		for j in nz:
			var x0 := i * size.x / nx
			var x1 := (i + 1) * size.x / nx
			var z0 := j * size.y / nz
			var z1 := (j + 1) * size.y / nz
			var corners := [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = corners[idx]
				st.set_color(color_at.call(p.x, p.z))
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


# --- Beleuchtung, Fahnen -------------------------------------------------------------------

## Lampenmast (Gittermast) mit zwei warmen Flutlichtern. "lights" lokal.
static func lamp_mast(height := 9.0) -> Dictionary:
	var key := "mast|%.1f" % height
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var glow := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.2, 0), Vector3(0.8, 0.4, 0.8), CONCRETE)
	var corners := [Vector2(-0.22, -0.22), Vector2(0.22, -0.22), Vector2(0.22, 0.22), Vector2(-0.22, 0.22)]
	for c: Vector2 in corners:
		LowPolyBuilder.add_beam(st, Vector3(c.x, 0.4, c.y), Vector3(c.x * 0.4, height, c.y * 0.4), 0.06, IRON)
	var y := 0.8
	while y < height - 0.4:
		var shrink := lerpf(1.0, 0.4, y / height)
		for k in 4:
			var a: Vector2 = corners[k] * shrink
			var b: Vector2 = corners[(k + 1) % 4] * shrink
			LowPolyBuilder.add_beam(st, Vector3(a.x, y, a.y), Vector3(b.x, y + 0.6, b.y), 0.035, IRON)
		y += 0.6
	LowPolyBuilder.add_box(st, Vector3(0, height, 0), Vector3(1.8, 0.1, 0.5), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, height + 0.07, 0), Vector3(1.7, 0.04, 0.4), SNOW)
	var lights: Array[Vector3] = []
	for s: float in [-1.0, 1.0]:
		var lamp := Vector3(s * 0.65, height - 0.25, 0.0)
		LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, -0.5), lamp), Vector3(0.5, 0.3, 0.42), CRANE_DARK)
		LowPolyBuilder.add_oriented_box(glow, Transform3D(Basis(Vector3.RIGHT, -0.5), lamp + Vector3(0, -0.12, -0.08)),
			Vector3(0.42, 0.04, 0.34), GLASS_WARM)
		lights.append(lamp + Vector3(0, -0.5, -0.3))
	var result := {"body": st.commit(), "glow": glow.commit(), "lights": lights}
	_cache[key] = result
	return result


## Fahnenmast (weiß, mit Knauf). Die Fahne selbst: [method flag_cloth].
static func flag_pole(height := 7.0) -> ArrayMesh:
	var key := "pole|%.1f" % height
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.28, 0.24, 0.3, 8, STONE)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.3, 0), 0.07, 0.05, height, 8, TRIM)
	LowPolyBuilder.add_cylinder(st, Vector3(0, height + 0.3, 0), 0.1, 0.1, 0.14, 8, YELLOW)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.3, 0), 0.22, 0.2, 0.06, 8, SNOW)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Fahnentuch (1,6 × 1,0 m, Streifen in [param colors]) mit UV für den Wind-Shader.
## Ursprung = oberes Ende am Mast, das Tuch weht entlang +X.
static func flag_cloth(colors: Array) -> ArrayMesh:
	var key := "flag|%s" % [colors]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 1.6
	var height := 1.0
	var nx := 10
	var ny := colors.size() * 2
	for i in nx:
		for j in ny:
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var v0 := float(j) / ny
			var v1 := float(j + 1) / ny
			var color: Color = colors[int(j / 2.0) % colors.size()]
			var corners := [Vector3(u0 * length, -v0 * height, 0), Vector3(u1 * length, -v0 * height, 0),
				Vector3(u1 * length, -v1 * height, 0), Vector3(u0 * length, -v1 * height, 0)]
			var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(color)
				st.set_normal(Vector3.BACK)
				st.set_uv(uvs[idx])
				st.add_vertex(corners[idx])
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


# --- Fahrzeuge und Geräte ------------------------------------------------------------------

## Gabelstapler (dekorativ): Fahrgestell, Gegengewicht, Schutzdach, Sitz, Räder.
## Mast ([method forklift_mast]) und Gabel ([method forklift_forks]) sind eigene
## Teile, damit die Gabel heben kann. Ursprung = Mitte am Boden, Gabel zeigt nach -Z.
static func forklift() -> Dictionary:
	if _cache.has("forklift"):
		return _cache["forklift"]
	var st := _new_st()
	var body := Color(0.93, 0.62, 0.14)
	LowPolyBuilder.add_box(st, Vector3(0, 0.55, 0.15), Vector3(1.1, 0.5, 1.9), body)
	LowPolyBuilder.add_box(st, Vector3(0, 0.95, 0.85), Vector3(1.1, 0.5, 0.5), Color(0.3, 0.3, 0.32))
	LowPolyBuilder.add_box(st, Vector3(0, 0.83, 0.2), Vector3(0.6, 0.12, 0.55), RUBBER)
	LowPolyBuilder.add_box(st, Vector3(0, 1.12, 0.45), Vector3(0.6, 0.5, 0.1), RUBBER)
	for s: float in [-1.0, 1.0]:
		LowPolyBuilder.add_beam(st, Vector3(s * 0.5, 0.8, -0.45), Vector3(s * 0.5, 2.1, -0.35), 0.06, IRON)
		LowPolyBuilder.add_beam(st, Vector3(s * 0.5, 0.8, 0.95), Vector3(s * 0.5, 2.1, 0.8), 0.06, IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 2.12, 0.22), Vector3(1.1, 0.06, 1.35), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 2.17, 0.22), Vector3(1.0, 0.05, 1.25), SNOW)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.8, -0.2), 0.03, 0.03, 0.35, 6, IRON)
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.15, 1.15, -0.25), Vector3(0.15, 1.15, -0.25), 0.16, 10, RUBBER)
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.5, 0.75]:
			LowPolyBuilder.add_cylinder_between(st, Vector3(s * 0.5, 0.3, z), Vector3(s * 0.62, 0.3, z), 0.3 if z < 0.0 else 0.24, 12, RUBBER)
			LowPolyBuilder.add_cylinder_between(st, Vector3(s * 0.62, 0.3, z), Vector3(s * 0.63, 0.3, z), 0.14, 8, Color(0.7, 0.7, 0.7))
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.9, 1.1), Vector3(0.12, 0.12, 0.08), Color(0.95, 0.5, 0.1))
	var result := {"body": st.commit(), "seat": Vector3(0.0, 0.89, 0.22)}
	_cache["forklift"] = result
	return result


static func forklift_mast() -> ArrayMesh:
	if _cache.has("fork_mast"):
		return _cache["fork_mast"]
	var st := _new_st()
	for s: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(s * 0.38, 1.15, -0.95), Vector3(0.1, 2.2, 0.12), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 2.2, -0.95), Vector3(0.86, 0.1, 0.12), IRON)
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 0.5, -0.9), Vector3(0, 1.9, -0.9), 0.05, 6, Color(0.6, 0.6, 0.6))
	var mesh := st.commit()
	_cache["fork_mast"] = mesh
	return mesh


static func forklift_forks() -> ArrayMesh:
	if _cache.has("forks"):
		return _cache["forks"]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.35, -1.05), Vector3(0.85, 0.6, 0.06), IRON)
	for s: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(s * 0.28, 0.07, -1.6), Vector3(0.12, 0.05, 1.1), IRON)
	var mesh := st.commit()
	_cache["forks"] = mesh
	return mesh


## Kleiner Drehkran auf der Rampe: Säule (fest) und schwenkbarer Ausleger.
static func jib_pillar() -> ArrayMesh:
	if _cache.has("jib_pillar"):
		return _cache["jib_pillar"]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.1, 0), Vector3(0.8, 0.2, 0.8), IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.2, 0), 0.16, 0.13, 3.2, 10, CRANE)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 3.4, 0), 0.14, 0.1, 0.05, 10, SNOW)
	var mesh := st.commit()
	_cache["jib_pillar"] = mesh
	return mesh


static func jib_arm() -> ArrayMesh:
	if _cache.has("jib_arm"):
		return _cache["jib_arm"]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(-1.3, 3.2, 0), Vector3(2.9, 0.22, 0.2), CRANE)
	LowPolyBuilder.add_beam(st, Vector3(0.0, 2.2, 0), Vector3(-1.6, 3.1, 0), 0.1, CRANE)
	LowPolyBuilder.add_box(st, Vector3(-1.3, 3.33, 0), Vector3(2.7, 0.04, 0.16), SNOW)
	LowPolyBuilder.add_box(st, Vector3(-2.5, 3.0, 0), Vector3(0.3, 0.25, 0.28), CRANE_DARK)
	LowPolyBuilder.add_cylinder(st, Vector3(-2.5, 2.1, 0), 0.015, 0.015, 0.8, 4, IRON)
	LowPolyBuilder.add_box(st, Vector3(-2.5, 2.0, 0), Vector3(0.12, 0.18, 0.06), IRON)
	var mesh := st.commit()
	_cache["jib_arm"] = mesh
	return mesh


# --- Deko --------------------------------------------------------------------------------

## Holzstapel unter einem kleinen Pultdach (Brennholz des Schuppens).
static func firewood_stack() -> ArrayMesh:
	if _cache.has("firewood"):
		return _cache["firewood"]
	var st := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for row in 5:
		for i in 9:
			var x := -1.6 + i * 0.4 + (0.2 if row % 2 == 1 else 0.0)
			if x > 1.7:
				continue
			var y := 0.2 + row * 0.34
			var r := rng.randf_range(0.14, 0.18)
			LowPolyBuilder.add_cylinder_between(st, Vector3(x, y, -0.45), Vector3(x, y, 0.45), r, 7,
				TrainMeshes.BARK.lerp(Color(0.45, 0.32, 0.2), rng.randf()))
			LowPolyBuilder.add_cylinder_between(st, Vector3(x, y, 0.45), Vector3(x, y, 0.47), r * 0.9, 7,
				TrainMeshes.LOG_END.lerp(Color(0.9, 0.78, 0.6), rng.randf()))
	for x: float in [-1.95, 1.95]:
		LowPolyBuilder.add_box(st, Vector3(x, 1.1, 0), Vector3(0.12, 2.2, 0.12), WOOD_DARK)
	LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 2.25, -0.05)), Vector3(4.4, 0.08, 1.4), WOOD)
	LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 2.32, -0.05)), Vector3(4.3, 0.08, 1.3), SNOW)
	var mesh := st.commit()
	_cache["firewood"] = mesh
	return mesh


## Verschneiter Stapel Paletten, ein paar Kisten und Fässer (lose Deko).
static func pallet_pile() -> ArrayMesh:
	if _cache.has("pallet_pile"):
		return _cache["pallet_pile"]
	var st := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6262
	for i in 7:
		var y := i * 0.145
		LowPolyBuilder.add_box(st, Vector3(rng.randf_range(-0.05, 0.05), y + 0.07, rng.randf_range(-0.05, 0.05)), Vector3(1.2, 0.14, 1.0),
			TrainMeshes.PALLET.darkened(rng.randf() * 0.2))
		LowPolyBuilder.add_box(st, Vector3(0, y + 0.03, 0), Vector3(1.22, 0.02, 1.02), TrainMeshes.PALLET.darkened(0.35))
	LowPolyBuilder.add_box(st, Vector3(0, 1.05, 0), Vector3(1.15, 0.08, 0.95), SNOW)
	LowPolyBuilder.add_box(st, Vector3(0.1, 1.11, -0.05), Vector3(0.7, 0.06, 0.6), SNOW)
	for p: Vector3 in [Vector3(1.3, 0, 0.2), Vector3(1.6, 0, -0.5)]:
		LowPolyBuilder.add_cylinder(st, p, 0.3, 0.3, 0.88, 10, Color(0.55, 0.22, 0.15))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.3, 0), 0.305, 0.305, 0.05, 10, Color(0.35, 0.14, 0.1))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.88, 0), 0.26, 0.2, 0.05, 10, SNOW)
	LowPolyBuilder.add_box(st, Vector3(-1.2, 0.3, 0.3), Vector3(0.6, 0.6, 0.6), WOOD)
	LowPolyBuilder.add_box(st, Vector3(-1.2, 0.62, 0.3), Vector3(0.55, 0.05, 0.55), SNOW)
	var mesh := st.commit()
	_cache["pallet_pile"] = mesh
	return mesh


## Kleiner Vogel (Rotkehlchen/Spatz) zum Sitzen auf Waggons. Ursprung = Füße, Blick nach -Z.
static func bird(variant := 0) -> ArrayMesh:
	var key := "bird|%d" % variant
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var back: Color = [Color(0.45, 0.33, 0.24), Color(0.36, 0.34, 0.33), Color(0.5, 0.4, 0.3)][variant % 3]
	var breast: Color = [Color(0.9, 0.45, 0.2), Color(0.78, 0.74, 0.68), Color(0.85, 0.7, 0.5)][variant % 3]
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 0.07, 0.05), Vector3(0, 0.09, -0.05), 0.055, 6, back)
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 0.06, -0.035), Vector3(0, 0.07, -0.06), 0.045, 6, breast)
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 0.14, -0.05), Vector3(0, 0.15, -0.08), 0.035, 6, back)
	LowPolyBuilder.add_cone(st, Vector3(0, 0.14, -0.105), 0.012, 0.03, 4, Color(0.9, 0.7, 0.3))
	LowPolyBuilder.add_beam(st, Vector3(0, 0.1, 0.06), Vector3(0, 0.12, 0.13), 0.03, back.darkened(0.2))
	for s: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(s * 0.02, 0.02, 0.0), Vector3(0.008, 0.04, 0.008), IRON)
		LowPolyBuilder.add_box(st, Vector3(s * 0.017, 0.155, -0.075), Vector3(0.01, 0.01, 0.01), IRON)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


# --- Hilfen ------------------------------------------------------------------------------

## Fenster mit Rahmen, Sprossen und Schneehäubchen; Glas leuchtet nachts ([param glow]).
static func _window(st: SurfaceTool, glow: SurfaceTool, center: Vector3, normal: Vector3, size: Vector2) -> void:
	var along := Vector3(normal.z, 0, -normal.x) if absf(normal.x) + absf(normal.z) > 0.5 else Vector3.RIGHT
	var basis := Basis(along, Vector3.UP, normal)
	var xf := Transform3D(basis, center)
	LowPolyBuilder.add_oriented_box(st, xf, Vector3(size.x + 0.2, size.y + 0.2, 0.06), TRIM)
	LowPolyBuilder.add_oriented_box(glow, xf.translated_local(Vector3(0, 0, 0.035)), Vector3(size.x, size.y, 0.02), GLASS_WARM.darkened(0.2))
	LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, 0, 0.05)), Vector3(0.06, size.y, 0.03), TRIM)
	LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, 0, 0.05)), Vector3(size.x, 0.06, 0.03), TRIM)
	LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, -size.y * 0.5 - 0.12, 0.08)), Vector3(size.x + 0.3, 0.06, 0.18), TRIM)
	LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, -size.y * 0.5 - 0.07, 0.1)), Vector3(size.x + 0.2, 0.05, 0.14), SNOW)


## Eine Dachfläche von der Traufe [param eave] (x, y) zum First [param ridge]
## (x, y), entlang Z über ±[param half_z], mit Schneeschicht und Sparrenköpfen.
static func _roof_plane(st: SurfaceTool, eave: Vector2, ridge: Vector2, half_z: float, thickness: float,
		skylights := false) -> void:
	var dir := (ridge - eave)
	var length := dir.length()
	# Winkel immer so, dass die Dachnormale nach oben zeigt (Schnee oben, Sparren unten)
	var angle := atan2(dir.y, dir.x) if dir.x >= 0.0 else atan2(-dir.y, -dir.x)
	var center := (eave + ridge) * 0.5
	var basis := Basis(Vector3.BACK, angle)
	LowPolyBuilder.add_oriented_box(st, Transform3D(basis, Vector3(center.x, center.y, 0)), Vector3(length, thickness, half_z * 2.0), ROOF)
	var normal := basis * Vector3.UP
	var snow_center := Vector3(center.x, center.y, 0) + normal * (thickness * 0.5 + 0.05)
	LowPolyBuilder.add_oriented_box(st, Transform3D(basis, snow_center), Vector3(length - 0.1, 0.1, half_z * 2.0 - 0.1), SNOW)
	# Schneekante an der Traufe (leicht überhängend, weicher Abschluss)
	var eave3 := Vector3(eave.x, eave.y, 0) + normal * (thickness * 0.5 + 0.06)
	LowPolyBuilder.add_oriented_box(st, Transform3D(basis, eave3 + (Vector3(dir.x, dir.y, 0) / length) * 0.1),
		Vector3(0.3, 0.14, half_z * 2.0 - 0.1), SNOW_SHADE)
	if skylights:
		for z: float in [-half_z * 0.55, 0.0, half_z * 0.55]:
			var p := Vector3(center.x, center.y, z) + normal * (thickness * 0.5 + 0.11)
			LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p), Vector3(length * 0.45, 0.06, 1.6), Color(0.5, 0.62, 0.72))
			LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p + normal * 0.02), Vector3(length * 0.47, 0.03, 0.08), TRIM)
	# Sparrenköpfe unter der Traufe
	var z := -half_z + 0.4
	while z < half_z:
		var under := Vector3(eave.x, eave.y, z) - normal * (thickness * 0.5 + 0.05)
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, under + Vector3(dir.x, dir.y, 0) / length * 0.3), Vector3(0.7, 0.1, 0.1), WOOD_DARK)
		z += 0.9
