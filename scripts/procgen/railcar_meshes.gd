@tool
## Moderner, stilisierter Regional-Triebwagen (Etappe 9.5).
##
## Ein dreiteiliger Triebzug: zwei Endwagen mit Führerstand ("railcar_front",
## "railcar_rear") und ein Mittelwagen ("railcar_middle"). Weiche Formen statt
## Kisten:
## - Wagenkasten aus einem gerundeten Querschnitt mit leicht eingezogenen Flanken,
##   gewölbtem Dach und abgerundeter Unterkante,
## - Bugnase als Loft durch viele Stationen: das Dach senkt sich zur schrägen,
##   umlaufenden Frontscheibe, darunter eine kurze, runde Bugschürze,
## - schwarze Frontmaske und durchgehendes Fensterband mit abgeschrägten Scheiben,
## - Schwenkschiebetüren mit großem Fenster, Schürzen zwischen den Drehgestellen,
##   Dachaufbauten (Klima, Kühler), Faltenbalg, Scharfenbergkupplung,
## - Scheinwerfer (zwei unten, einer oben), rote Schlusslichter und eine Zielanzeige.
##
## Die Farben kommen aus der Lackierung der Zuggattung: primary = untere Hälfte
## und Bug, secondary = Wagenkasten, accent = Zierlinie und Türen, roof = Dach.
## Koordinaten wie in [TrainMeshes]: Ursprung = Wagenmitte auf Schienenoberkante,
## -Z = vorne, +X = rechts. Der hintere Endwagen ist der gespiegelte vordere.
class_name RailcarMeshes
extends RefCounted

const SPECS := {
	"railcar_front": {"length": 12.0, "bogie": 4.35, "wheel_base": 2.1},
	"railcar_middle": {"length": 11.0, "bogie": 3.9, "wheel_base": 2.1},
	"railcar_rear": {"length": 12.0, "bogie": 4.35, "wheel_base": 2.1},
}
const ROOF_TOP := 3.63
const NOSE_LENGTH := 2.7
## Fensterband (Unter- und Oberkante der Scheiben).
const WINDOW_LOW := 1.98
const WINDOW_HIGH := 2.86
## Halbe Breite einer Türöffnung.
const DOOR_HALF := 0.67
const DOOR_BOTTOM := 1.08
const DOOR_TOP := 2.95
const BAND := Color(0.09, 0.1, 0.12)
const RUBBER := Color(0.08, 0.08, 0.09)
const UNDER := TrainMeshes.UNDER
const FRAME := TrainMeshes.FRAME
const METAL := TrainMeshes.METAL
const SNOW := TrainMeshes.SNOW
const PANE := TrainMeshes.PANE
const LENS_WHITE := Color(0.95, 0.93, 0.86)
## Frontscheibe: Alpha 0.5 sagt dem Fenster-Shader "wenig spiegeln" – die schräge
## Scheibe würde sonst den hellen Himmel spiegeln und wie Dach aussehen.
const WINDSCREEN := Color(0.1, 0.13, 0.18, 0.5)
## Einstiegsraum hinter den Türen (Alpha 0.8): hell, ohne Sitze, kaum Spiegelung.
const VESTIBULE := Color(0.16, 0.15, 0.14, 0.8)

## Stationen der Bugnase: [Abstand ab Nasenbeginn, Dachhöhe, "Knie" (bis hier bleibt
## der Querschnitt unverändert), Breite oben, Breite unten].
const NOSE := [
	[0.0, 3.63, 1.9, 1.0, 1.0],
	[0.45, 3.58, 1.9, 0.995, 1.0],
	[0.9, 3.45, 1.9, 0.985, 0.998],
	[1.3, 3.22, 1.9, 0.965, 0.99],
	[1.65, 2.9, 1.9, 0.94, 0.98],
	[1.95, 2.48, 1.9, 0.905, 0.965],
	[2.15, 2.08, 1.9, 0.875, 0.95],
	[2.35, 1.88, 1.3, 0.85, 0.93],
	[2.52, 1.8, 1.3, 0.82, 0.9],
	[2.64, 1.66, 1.3, 0.79, 0.86],
	[2.7, 1.5, 1.3, 0.76, 0.82],
]
## Bis zu diesem Abstand ab Nasenbeginn reicht die Frontscheibe (danach Bugschürze).
const WINDSCREEN_END := 2.15
## Ab diesem Abstand ab Nasenbeginn gehört auch die Dachwölbung zur Frontscheibe –
## die Oberkante der Scheibe läuft so als glatte Linie quer übers Dach.
const WINDSCREEN_TOP_START := 1.05


## Baut einen Wagen des Triebzugs (gleiches Ergebnisformat wie [method TrainMeshes.build_car]).
static func build(kind: String, livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"railcar_middle":
			return _build_middle(livery, rng)
		"railcar_rear":
			return _mirrored(_build_cab(livery, rng))
		_:
			return _build_cab(livery, rng)


# --- Querschnitt ---------------------------------------------------------------------

## Rechte Hälfte des Querschnitts von unten nach oben (mit Punkten an allen Farbgrenzen).
static func _right_profile() -> Array[Vector2]:
	return [
		Vector2(1.2, 0.98), Vector2(1.33, 1.06), Vector2(1.375, 1.25), Vector2(1.388, 1.55), Vector2(1.39, 1.66),
		Vector2(1.395, 1.95), Vector2(1.393, 2.45), Vector2(1.38, 2.88), Vector2(1.36, 3.02), Vector2(1.33, 3.12),
		Vector2(1.3, 3.21), Vector2(1.25, 3.3), Vector2(1.19, 3.38), Vector2(1.12, 3.44), Vector2(1.0, 3.5), Vector2(0.86, 3.55),
		Vector2(0.67, 3.585), Vector2(0.46, 3.61), Vector2(0.24, 3.625),
	]


static func _profile() -> Array[Vector2]:
	return TrainMeshes._mirror(_right_profile(), Vector2(0.0, ROOF_TOP))


## Halbe Breite des Wagenkastens in Höhe [param y] (für Fenster, Türen, Anbauteile).
static func body_x(y: float) -> float:
	var right := _right_profile()
	if y <= right[0].y:
		return right[0].x
	for i in right.size() - 1:
		if y <= right[i + 1].y:
			return lerpf(right[i].x, right[i + 1].x, (y - right[i].y) / (right[i + 1].y - right[i].y))
	return right[-1].x


## Farbe einer Profilkante am geraden Wagenkasten (nach Höhe der Kantenmitte).
static func _band_color(mid: float, livery: Dictionary) -> Color:
	if mid < 1.06:
		return UNDER
	if mid < 1.55:
		return livery["primary"]
	if mid < 1.66:
		return livery["accent"]
	if mid < 3.02:
		return livery["secondary"]
	return livery["roof"]


# --- Endwagen ------------------------------------------------------------------------

static func _build_cab(livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var paint := TrainMeshes._new_st()
	var glass := TrainMeshes._new_st()
	var half := 6.0
	var nose_start := -half + NOSE_LENGTH
	var points := _profile()
	var n := points.size()

	# Ringe von hinten (Übergang) nach vorne (Bugspitze)
	var rings: Array[PackedVector3Array] = []
	rings.append(_ring(points, half, 1.0, 1.0, ROOF_TOP, ROOF_TOP))
	var stations := _nose_stations()
	for station: Array in stations:
		rings.append(_ring(points, nose_start - float(station[0]), station[3], station[4], station[1], station[2]))
	# Farben: am geraden Kasten nach der Höhe im Querschnitt; an der Nase nach der
	# tatsächlichen Höhe der Fläche – so liegt die Frontscheibe vorne auf der Nase
	# (dort sitzen die Dachpunkte des Querschnitts) und läuft seitlich um.
	var colors: Array = []
	var glass_edges := {}
	for r in rings.size() - 1:
		var row: Array[Color] = []
		for k in n:
			var base_mid := (points[k].y + points[(k + 1) % n].y) * 0.5
			var color := _band_color(base_mid, livery)
			var nose_interval := r - 1
			if nose_interval >= 0:
				var distance := float(stations[nose_interval][0])
				var in_windscreen := distance < WINDSCREEN_END
				var dome := base_mid > 3.02
				if in_windscreen and base_mid > 1.95 and (not dome or distance >= WINDSCREEN_TOP_START):
					glass_edges[Vector2i(r, k)] = true
				elif in_windscreen and distance > 0.2 and (base_mid > 1.66 and base_mid < 1.95
						or dome and distance >= WINDSCREEN_TOP_START - 0.25 or base_mid > 3.02 and base_mid < 3.12):
					# Schwarzer Rahmen um die Scheibe (unten, oben quer übers Dach, seitlich oben)
					color = BAND
				elif base_mid > 1.06 and (not in_windscreen or base_mid < 1.66):
					# Bug in der Hauptfarbe, die Zierlinie läuft um die Front
					color = livery["accent"] if base_mid > 1.55 and base_mid < 1.66 and distance < 2.3 else livery["primary"]
			row.append(color)
		colors.append(row)
	_loft(paint, glass, rings, colors, glass_edges)
	TrainMeshes._cap(paint, rings[0], Vector3.BACK, livery["secondary"].darkened(0.08))
	TrainMeshes._cap(paint, rings[-1], Vector3.FORWARD, livery["primary"])
	var tip := nose_start - float(NOSE[-1][0])

	# Scheinwerferband an der Bugspitze, Schürze und Kupplung
	_front_lamp_band(paint, tip)
	_front_apron(paint, livery, nose_start - 1.3, tip)
	_coupler(paint, tip, -1.0)

	# Seitenfenster, Türen, Schürzen
	var doors: Array = []
	var leaf := _door_leaf(livery)
	var door_zs: Array[float] = [-1.6, 3.5]
	for side: float in [-1.0, 1.0]:
		_window_band(paint, glass, side, nose_start + 0.08, nose_start + 0.85, 1)
		_window_band(paint, glass, side, -0.8, 2.8, 3)
		_window_band(paint, glass, side, 4.3, 5.72, 1)
		for door_z in door_zs:
			_door_opening(paint, glass, side, door_z, livery)
			for leaf_side: float in [-1.0, 1.0]:
				doors.append({"mesh": leaf, "position": Vector3(side * (body_x(2.0) + 0.03), 2.015, door_z + leaf_side * 0.33),
					"open_offset": Vector3(side * 0.07, 0.0, leaf_side * 0.62), "side": side})
		# Führerstandstür (schmal, in der Hauptfarbe) mit Griffstange
		_side_panel(paint, side, nose_start + 0.95, nose_start + 1.55, 1.12, 2.92, 0.004, RUBBER, 0.06)
		_side_panel(paint, side, nose_start + 0.99, nose_start + 1.51, 1.16, 2.88, 0.008, livery["primary"], 0.05)
		_side_panel(glass, side, nose_start + 1.07, nose_start + 1.43, 2.2, 2.75, 0.012, PANE, 0.05)
		LowPolyBuilder.add_cylinder_between(paint, Vector3(side * (body_x(1.6) + 0.035), 1.35, nose_start + 1.62),
			Vector3(side * (body_x(2.5) + 0.035), 2.55, nose_start + 1.62), 0.018, 6, METAL)
	_skirts(paint, livery, half, 4.35, door_zs, nose_start - 1.0)
	_underfloor(paint, 4.35)

	# Dach: Klimagerät über dem Fahrgastraum, Kühler mit Lüfter, Antenne, Schnee
	_roof_pod(paint, livery, 1.2, 2.6, false)
	_roof_pod(paint, livery, 4.55, 1.6, true)
	LowPolyBuilder.add_box(paint, Vector3(0.35, ROOF_TOP + 0.12, nose_start + 0.5), Vector3(0.03, 0.24, 0.03), UNDER)
	TrainMeshes._roof_snow(paint, points, nose_start + 0.3, half - 0.3, rng)

	# Übergang zum Nachbarwagen
	_gangway(paint, half, 1.0)

	var lamp_y := 1.21
	return {
		"paint": paint.commit(), "glass": glass.commit(), "doors": doors,
		"lamps_front": [Vector3(-0.62, lamp_y, tip - 0.02), Vector3(0.62, lamp_y, tip - 0.02),
			_nose_point(Vector2(0.0, ROOF_TOP), WINDSCREEN_TOP_START - 0.12, nose_start) + Vector3(0.0, 0.02, -0.02)],
		"lamps_rear": [Vector3(-0.9, 1.45, half + 0.02), Vector3(0.9, 1.45, half + 0.02)],
		"lamps_idle": [{"position": Vector3(-0.9, lamp_y, tip - 0.02), "facing": -1.0, "color": "red"},
			{"position": Vector3(0.9, lamp_y, tip - 0.02), "facing": -1.0, "color": "red"}],
		"display": _display_transform(nose_start),
	}


# --- Mittelwagen ---------------------------------------------------------------------

static func _build_middle(livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var paint := TrainMeshes._new_st()
	var glass := TrainMeshes._new_st()
	var half := 5.5
	var points := _profile()
	var n := points.size()
	var rings: Array[PackedVector3Array] = [_ring(points, half, 1.0, 1.0, ROOF_TOP, ROOF_TOP),
		_ring(points, -half, 1.0, 1.0, ROOF_TOP, ROOF_TOP)]
	var row: Array[Color] = []
	for k in n:
		row.append(_band_color((points[k].y + points[(k + 1) % n].y) * 0.5, livery))
	_loft(paint, null, rings, [row], {})
	TrainMeshes._cap(paint, rings[0], Vector3.BACK, livery["secondary"].darkened(0.08))
	TrainMeshes._cap(paint, rings[1], Vector3.FORWARD, livery["secondary"].darkened(0.08))

	var doors: Array = []
	var leaf := _door_leaf(livery)
	var door_zs: Array[float] = [-2.9, 2.9]
	for side: float in [-1.0, 1.0]:
		_window_band(paint, glass, side, -5.2, -3.75, 1)
		_window_band(paint, glass, side, -2.05, 2.05, 3)
		_window_band(paint, glass, side, 3.75, 5.2, 1)
		for door_z in door_zs:
			_door_opening(paint, glass, side, door_z, livery)
			for leaf_side: float in [-1.0, 1.0]:
				doors.append({"mesh": leaf, "position": Vector3(side * (body_x(2.0) + 0.03), 2.015, door_z + leaf_side * 0.33),
					"open_offset": Vector3(side * 0.07, 0.0, leaf_side * 0.62), "side": side})
	_skirts(paint, livery, half, 3.9, door_zs, -half)
	_underfloor(paint, 3.9)
	_roof_pod(paint, livery, 0.0, 2.8, false)
	TrainMeshes._roof_snow(paint, points, -half + 0.3, half - 0.3, rng)
	for end: float in [-1.0, 1.0]:
		_gangway(paint, end * half, end)
	return {
		"paint": paint.commit(), "glass": glass.commit(), "doors": doors,
		"lamps_front": [], "lamps_rear": [Vector3(-0.9, 1.45, half + 0.02), Vector3(0.9, 1.45, half + 0.02)],
		"lamps_idle": [],
	}


# --- Formen --------------------------------------------------------------------------

## Ein Ring des Wagenkastens bei [param z]: oberhalb des Knies wird der Querschnitt
## auf die Dachhöhe [param top] zusammengeschoben, die Breite nach oben hin verjüngt.
static func _ring(points: Array[Vector2], z: float, width_top: float, width_low: float, top: float,
		knee: float) -> PackedVector3Array:
	var row := PackedVector3Array()
	for p in points:
		row.append(_map_point(p, z, width_top, width_low, top, knee))
	return row


static func _map_point(p: Vector2, z: float, width_top: float, width_low: float, top: float, knee: float) -> Vector3:
	var y := p.y
	# Vector2 speichert 32 Bit: der Dachpunkt liegt minimal über ROOF_TOP, daher mit Abstand vergleichen
	if y > knee + 0.001 and ROOF_TOP - knee > 0.01:
		y = knee + (y - knee) * (top - knee) / (ROOF_TOP - knee)
	var width := lerpf(width_low, width_top, smoothstep(1.2, 2.6, p.y))
	return Vector3(p.x * width, y, z)


## Stationen der Nase, jeweils mit einer Zwischenstation (weichere Rundungen).
static func _nose_stations() -> Array:
	var result: Array = []
	for i in NOSE.size():
		result.append(NOSE[i])
		if i < NOSE.size() - 1:
			var mid: Array = []
			for j in 5:
				mid.append((float(NOSE[i][j]) + float(NOSE[i + 1][j])) * 0.5)
			# Knie nicht mitteln: es wechselt nur zwischen Scheiben- und Bugteil
			mid[2] = NOSE[i][2]
			result.append(mid)
	return result


## Punkt der Bugnase: Querschnittspunkt [param base] im Abstand [param distance] ab Nasenbeginn.
static func _nose_point(base: Vector2, distance: float, nose_start: float) -> Vector3:
	for i in NOSE.size() - 1:
		var a: Array = NOSE[i]
		var b: Array = NOSE[i + 1]
		if distance <= float(b[0]) or i == NOSE.size() - 2:
			var t := clampf((distance - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			var p0 := _map_point(base, nose_start - float(a[0]), a[3], a[4], a[1], a[2])
			var p1 := _map_point(base, nose_start - float(b[0]), b[3], b[4], b[1], b[2])
			return p0.lerp(p1, t)
	return Vector3.ZERO


## Zieht Flächen zwischen den Ringen und rundet die Normalen über die Nachbarflächen.
## [param colors] = je Ring-Intervall ein Array mit einer Farbe je Profilkante.
static func _loft(paint: SurfaceTool, glass: SurfaceTool, rings: Array[PackedVector3Array], colors: Array,
		glass_edges: Dictionary) -> void:
	var n := rings[0].size()
	var center_y := 2.3
	var normals := PackedVector3Array()
	normals.resize(rings.size() * n)
	var face_normals := {}
	for r in rings.size() - 1:
		for k in n:
			var k2 := (k + 1) % n
			var a := rings[r][k]
			var b := rings[r][k2]
			var c := rings[r + 1][k2]
			var d := rings[r + 1][k]
			var normal := (b - a).cross(d - a)
			if normal.length() < 0.000001:
				normal = (c - b).cross(d - b)
			var mid := (a + b + c + d) * 0.25
			if normal.dot(Vector3(mid.x, mid.y - center_y, mid.z * 0.3)) < 0.0:
				normal = -normal
			normal = normal.normalized()
			face_normals[Vector2i(r, k)] = normal
			normals[r * n + k] += normal
			normals[r * n + k2] += normal
			normals[(r + 1) * n + k2] += normal
			normals[(r + 1) * n + k] += normal
	for i in normals.size():
		normals[i] = normals[i].normalized()
	for r in rings.size() - 1:
		var row: Array = colors[mini(r, colors.size() - 1)]
		for k in n:
			var k2 := (k + 1) % n
			var key := Vector2i(r, k)
			var target := glass if glass and glass_edges.has(key) else paint
			TrainMeshes._smooth_quad(target, [rings[r][k], rings[r][k2], rings[r + 1][k2], rings[r + 1][k]],
				[normals[r * n + k], normals[r * n + k2], normals[(r + 1) * n + k2], normals[(r + 1) * n + k]],
				WINDSCREEN if target == glass else row[k], face_normals[key])


## Fläche an der Wagenseite, die der Wölbung des Kastens folgt: Rechteck mit
## abgeschrägten Ecken ([param chamfer]), [param lift] über der Oberfläche.
## Sie wird in waagrechte Streifen an den Knicken des Querschnitts geteilt – eine
## große, flache Fläche würde sonst in den gewölbten Kasten einsinken.
static func _side_panel(st: SurfaceTool, side: float, z0: float, z1: float, y0: float, y1: float, lift: float,
		color: Color, chamfer := 0.0) -> void:
	var levels: Array[float] = [y0, y1]
	if chamfer > 0.0:
		levels.append_array([y0 + chamfer, y1 - chamfer])
	for p in _right_profile():
		if p.y > y0 + 0.001 and p.y < y1 - 0.001:
			levels.append(p.y)
	levels.sort()
	for i in levels.size() - 1:
		var ya := levels[i]
		var yb := levels[i + 1]
		if yb - ya < 0.0005:
			continue
		var ia := _panel_inset(ya, y0, y1, chamfer)
		var ib := _panel_inset(yb, y0, y1, chamfer)
		var xa := side * (body_x(ya) + lift)
		var xb := side * (body_x(yb) + lift)
		LowPolyBuilder.add_quad_facing(st, Vector3(xa, ya, z0 + ia), Vector3(xa, ya, z1 - ia), Vector3(xb, yb, z1 - ib),
			Vector3(xb, yb, z0 + ib), color, Vector3(side, 0.0, 0.0))


## Wie weit die abgeschrägten Ecken in Höhe [param y] nach innen rücken.
static func _panel_inset(y: float, y0: float, y1: float, chamfer: float) -> float:
	if chamfer <= 0.0:
		return 0.0
	return maxf(maxf(chamfer - (y - y0), chamfer - (y1 - y)), 0.0)


## Fensterband: schwarzer Rahmen, darauf [param panes] Scheiben mit schmalen Stegen.
static func _window_band(paint: SurfaceTool, glass: SurfaceTool, side: float, z0: float, z1: float, panes: int) -> void:
	_side_panel(paint, side, z0 - 0.05, z1 + 0.05, WINDOW_LOW - 0.06, WINDOW_HIGH + 0.06, 0.003, BAND, 0.1)
	var pillar := 0.1
	var width := (z1 - z0 - pillar * (panes - 1)) / panes
	for i in panes:
		var a := z0 + i * (width + pillar)
		_side_panel(glass, side, a, a + width, WINDOW_LOW, WINDOW_HIGH, 0.008, PANE, 0.07)


## Dunkle Türöffnung mit Gummirahmen und Einstiegskante; darin laufen die Türflügel.
static func _door_opening(paint: SurfaceTool, glass: SurfaceTool, side: float, door_z: float, livery: Dictionary) -> void:
	_side_panel(paint, side, door_z - DOOR_HALF - 0.05, door_z + DOOR_HALF + 0.05, DOOR_BOTTOM - 0.04, DOOR_TOP + 0.05,
		0.003, BAND, 0.08)
	# Dahinter der warm beleuchtete Einstiegsraum (Glas-Material, Markierung VESTIBULE)
	_side_panel(glass, side, door_z - DOOR_HALF, door_z + DOOR_HALF, DOOR_BOTTOM, DOOR_TOP, 0.005, VESTIBULE, 0.06)
	# Einstiegskante in Akzentfarbe (gut sichtbar beim Einsteigen)
	LowPolyBuilder.add_box(paint, Vector3(side * 1.3, DOOR_BOTTOM - 0.05, door_z), Vector3(0.12, 0.05, DOOR_HALF * 2.0),
		livery["accent"].darkened(0.1))


## Schwenkschiebetür-Flügel: Oberfläche 0 = Lack (Türblatt, Rahmen, Griff, Taster),
## Oberfläche 1 = Glas (großes Türfenster mit abgeschrägten Ecken).
static func _door_leaf(livery: Dictionary) -> ArrayMesh:
	var paint := TrainMeshes._new_st()
	var glass := TrainMeshes._new_st()
	var accent: Color = livery["accent"]
	LowPolyBuilder.add_box(paint, Vector3.ZERO, Vector3(0.05, 1.86, 0.64), accent)
	# Gummidichtung an der Mittelkante
	LowPolyBuilder.add_box(paint, Vector3(0.0, 0.0, -0.315), Vector3(0.056, 1.86, 0.02), RUBBER)
	# Fenster mit schwarzem Rahmen
	var frame := [Vector2(-0.24, -0.05), Vector2(0.24, -0.05), Vector2(0.28, -0.01), Vector2(0.28, 0.8),
		Vector2(0.24, 0.84), Vector2(-0.24, 0.84), Vector2(-0.28, 0.8), Vector2(-0.28, -0.01)]
	_leaf_polygon(paint, frame, 0.027, BAND)
	var pane := []
	for p: Vector2 in frame:
		pane.append(Vector2(p.x * 0.86, 0.395 + (p.y - 0.395) * 0.93))
	_leaf_polygon(glass, pane, 0.031, PANE)
	# Griffleiste und leuchtender Türtaster
	LowPolyBuilder.add_box(paint, Vector3(0.035, -0.12, -0.2), Vector3(0.025, 0.36, 0.035), METAL)
	LowPolyBuilder.add_cylinder_between(paint, Vector3(0.026, -0.18, 0.12), Vector3(0.04, -0.18, 0.12), 0.045, 10,
		Color(0.35, 0.8, 0.45))
	var mesh := paint.commit()
	glass.commit(mesh)
	return mesh


static func _leaf_polygon(st: SurfaceTool, outline: Array, x: float, color: Color) -> void:
	var center := Vector2.ZERO
	for p: Vector2 in outline:
		center += p
	center /= outline.size()
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		LowPolyBuilder.add_triangle_facing(st, Vector3(x, center.y, center.x), Vector3(x, a.y, a.x), Vector3(x, b.y, b.x),
			color, Vector3.RIGHT)


## Schürzen zwischen den Drehgestellen (verdecken die Unterflurtechnik) mit Aussparungen
## für Drehgestelle und Trittstufen. [param start] = vorderes Ende (bei Endwagen hinter der Bugschürze).
static func _skirts(paint: SurfaceTool, livery: Dictionary, half: float, bogie: float, door_zs: Array[float],
		start: float) -> void:
	var cuts: Array = [[-bogie - 1.45, -bogie + 1.45], [bogie - 1.45, bogie + 1.45]]
	for door_z in door_zs:
		cuts.append([door_z - DOOR_HALF - 0.08, door_z + DOOR_HALF + 0.08])
	var pieces: Array = [[start, half - 0.15]]
	for cut: Array in cuts:
		var next: Array = []
		for piece: Array in pieces:
			if cut[1] <= piece[0] or cut[0] >= piece[1]:
				next.append(piece)
				continue
			if cut[0] > piece[0]:
				next.append([piece[0], cut[0]])
			if cut[1] < piece[1]:
				next.append([cut[1], piece[1]])
		pieces = next
	var color: Color = livery["primary"].darkened(0.12)
	var profile: Array[Vector2] = [Vector2(1.3, 1.02), Vector2(1.31, 0.82), Vector2(1.25, 0.66)]
	for piece: Array in pieces:
		if float(piece[1]) - float(piece[0]) < 0.25:
			continue
		for side: float in [-1.0, 1.0]:
			for i in profile.size() - 1:
				var a := profile[i]
				var b := profile[i + 1]
				var outward := Vector3(side, (a.x - b.x) * 2.0, 0.0)
				LowPolyBuilder.add_quad_facing(paint, Vector3(side * a.x, a.y, piece[0]), Vector3(side * a.x, a.y, piece[1]),
					Vector3(side * b.x, b.y, piece[1]), Vector3(side * b.x, b.y, piece[0]), color, outward)
			# Stirnkanten der Schürze
			for z: float in [piece[0], piece[1]]:
				LowPolyBuilder.add_quad_facing(paint, Vector3(side * 1.3, 1.02, z), Vector3(side * 1.18, 1.02, z),
					Vector3(side * 1.18, 0.66, z), Vector3(side * 1.25, 0.66, z), color.darkened(0.2), Vector3(0, 0, signf(z)))


## Unterflurtechnik: Tank, Kästen, Leitungen (zwischen den Drehgestellen).
static func _underfloor(paint: SurfaceTool, bogie: float) -> void:
	var span := bogie - 1.6
	LowPolyBuilder.add_box(paint, Vector3(0.0, 0.8, 0.0), Vector3(2.2, 0.36, span * 2.0), UNDER)
	LowPolyBuilder.add_cylinder_between(paint, Vector3(-0.55, 0.72, -span * 0.8), Vector3(-0.55, 0.72, span * 0.2), 0.3, 10, FRAME)
	LowPolyBuilder.add_box(paint, Vector3(0.6, 0.7, span * 0.4), Vector3(0.8, 0.4, span * 0.8), FRAME)
	for x: float in [-1.0, 1.0]:
		LowPolyBuilder.add_cylinder_between(paint, Vector3(x * 0.9, 0.93, -bogie + 1.4), Vector3(x * 0.9, 0.93, bogie - 1.4),
			0.025, 5, METAL)


## Dachaufbau mit weich gerundeter Haube: Klimagerät oder Kühler (mit Lüfter).
static func _roof_pod(paint: SurfaceTool, livery: Dictionary, z: float, length: float, fan: bool) -> void:
	var base := ROOF_TOP - 0.03
	var right: Array[Vector2] = [Vector2(0.7, base - 0.05), Vector2(0.74, base + 0.08), Vector2(0.68, base + 0.2),
		Vector2(0.42, base + 0.27)]
	var points := TrainMeshes._mirror(right, Vector2(0.0, base + 0.29))
	var color: Color = livery["roof"].lightened(0.14)
	var rings: Array[PackedVector3Array] = []
	var half := length * 0.5
	for station: Array in [[half, 0.8, 0.7], [half - 0.18, 0.97, 0.95], [half - 0.3, 1.0, 1.0],
			[-half + 0.3, 1.0, 1.0], [-half + 0.18, 0.97, 0.95], [-half, 0.8, 0.7]]:
		var row := PackedVector3Array()
		for p in points:
			row.append(Vector3(p.x * float(station[1]), base + (p.y - base) * float(station[2]), z + float(station[0])))
		rings.append(row)
	var row_colors: Array[Color] = []
	for k in points.size():
		row_colors.append(color)
	_loft(paint, null, rings, [row_colors], {})
	TrainMeshes._cap(paint, rings[0], Vector3.BACK, color)
	TrainMeshes._cap(paint, rings[-1], Vector3.FORWARD, color)
	# Lüftungsschlitze an den Flanken
	for side: float in [-1.0, 1.0]:
		for i in 4:
			LowPolyBuilder.add_box(paint, Vector3(side * 0.735, base + 0.06 + i * 0.04, z), Vector3(0.012, 0.018, length - 0.9),
				BAND)
	if fan:
		LowPolyBuilder.add_cylinder(paint, Vector3(0.0, base + 0.27, z), 0.36, 0.36, 0.03, 14, BAND)
		LowPolyBuilder.add_box(paint, Vector3(0.0, base + 0.305, z), Vector3(0.66, 0.012, 0.05), METAL)
		LowPolyBuilder.add_box(paint, Vector3(0.0, base + 0.305, z), Vector3(0.05, 0.012, 0.66), METAL)
	LowPolyBuilder.add_box(paint, Vector3(0.0, base + 0.305, z - half * 0.35), Vector3(0.9, 0.025, length * 0.35), SNOW)


## Faltenbalg-Übergang und Kurzkupplung am Wagenende ([param direction] ±1).
static func _gangway(paint: SurfaceTool, z_end: float, direction: float) -> void:
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.2, z_end + direction * 0.08), Vector3(1.35, 2.3, 0.16), FRAME)
	for i in 6:
		var z := z_end + direction * (0.17 + i * 0.045)
		var shrink := 0.06 if i % 2 == 0 else 0.0
		LowPolyBuilder.add_box(paint, Vector3(0.0, 2.2, z), Vector3(1.24 - shrink, 2.22 - shrink, 0.04), RUBBER)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 0.92, z_end + direction * 0.21), Vector3(0.22, 0.16, 0.42), FRAME)


## Scharfenbergkupplung unter der Bugspitze.
static func _coupler(paint: SurfaceTool, tip: float, direction: float) -> void:
	var y := 0.8
	LowPolyBuilder.add_cylinder_between(paint, Vector3(0.0, y, tip + 0.5), Vector3(0.0, y, tip - 0.28), 0.085, 8, METAL)
	LowPolyBuilder.add_box(paint, Vector3(0.0, y, tip - 0.36), Vector3(0.34, 0.3, 0.16), FRAME)
	LowPolyBuilder.add_box(paint, Vector3(0.0, y + 0.06, tip - 0.445), Vector3(0.12, 0.08, 0.02), METAL)
	LowPolyBuilder.add_cylinder_between(paint, Vector3(0.0, y - 0.07, tip - 0.44), Vector3(0.0, y - 0.07, tip - 0.46), 0.05, 8,
		METAL.darkened(0.3))


## Schwarzes Scheinwerferband über die Bugspitze (die Lampen setzt TrainCar davor).
static func _front_lamp_band(paint: SurfaceTool, tip: float) -> void:
	var outline := [Vector2(-1.02, 1.1), Vector2(1.02, 1.1), Vector2(1.08, 1.16), Vector2(1.08, 1.28), Vector2(1.02, 1.33),
		Vector2(-1.02, 1.33), Vector2(-1.08, 1.28), Vector2(-1.08, 1.16)]
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		LowPolyBuilder.add_triangle_facing(paint, Vector3(0.0, 1.215, tip - 0.006), Vector3(a.x, a.y, tip - 0.006),
			Vector3(b.x, b.y, tip - 0.006), BAND, Vector3.FORWARD)


## Runde Bugschürze unter der Nase (Schneeräumer-Form), läuft nach hinten in die Seitenschürzen.
static func _front_apron(paint: SurfaceTool, livery: Dictionary, z_back: float, tip: float) -> void:
	var right: Array[Vector2] = [Vector2(1.2, 0.99), Vector2(1.27, 0.8), Vector2(1.2, 0.56), Vector2(0.9, 0.44)]
	var points: Array[Vector2] = []
	for p in right:
		points.append(Vector2(-p.x, p.y))
	for i in range(right.size() - 1, -1, -1):
		points.append(right[i])
	var rings: Array[PackedVector3Array] = []
	var steps := 6
	for i in steps + 1:
		var t := float(i) / steps
		var z := lerpf(z_back, tip - 0.08, t)
		var width := lerpf(1.0, 0.8, t * t)
		var row := PackedVector3Array()
		for p in points:
			# Unten schiebt sich die Schürze etwas nach vorne (Räumerkante)
			row.append(Vector3(p.x * width, p.y, z - (0.14 * t * (1.0 - clampf((p.y - 0.44) / 0.5, 0.0, 1.0)))))
		rings.append(row)
	var colors: Array[Color] = []
	for k in points.size():
		var mid := (points[k].y + points[(k + 1) % points.size()].y) * 0.5
		colors.append(UNDER if mid < 0.6 else livery["primary"].darkened(0.12))
	_loft(paint, null, rings, [colors], {})
	TrainMeshes._cap(paint, rings[-1], Vector3.FORWARD, UNDER)


## Lage der Zielanzeige im oberen Rand der Frontscheibe (Text setzt TrainCar).
static func _display_transform(nose_start: float) -> Transform3D:
	# Auf der Mittellinie der Scheibe, knapp unter dem oberen Rahmen
	var upper := _nose_point(Vector2(0.0, ROOF_TOP), WINDSCREEN_TOP_START + 0.12, nose_start)
	var lower := _nose_point(Vector2(0.0, ROOF_TOP), WINDSCREEN_TOP_START + 0.32, nose_start)
	var slope := (upper - lower).normalized()
	var outward := Vector3(0.0, slope.z, -slope.y).normalized()
	# Text liest man von vorne: X nach links, Y die Scheibe hinauf, Z aus der Scheibe heraus
	var basis := Basis(Vector3.LEFT, slope, outward)
	return Transform3D(basis, (upper + lower) * 0.5 + outward * 0.03)


# --- Spiegeln (hinterer Endwagen) ----------------------------------------------------

## Spiegelt einen Endwagen längs (Z → -Z): die Bugnase zeigt dann nach hinten.
static func _mirrored(parts: Dictionary) -> Dictionary:
	var result := parts.duplicate()
	result["paint"] = _mirror_mesh(parts["paint"])
	result["glass"] = _mirror_mesh(parts["glass"])
	var doors: Array = []
	for door: Dictionary in parts["doors"]:
		var copy := door.duplicate()
		var p: Vector3 = door["position"]
		var o: Vector3 = door["open_offset"]
		copy["position"] = Vector3(p.x, p.y, -p.z)
		copy["open_offset"] = Vector3(o.x, o.y, -o.z)
		doors.append(copy)
	result["doors"] = doors
	# Bug hinten: rote Schlusslichter leuchten, die Scheinwerfer bleiben dunkel
	var rear: Array = []
	var idle: Array = []
	for idle_lamp: Dictionary in parts["lamps_idle"]:
		var p: Vector3 = idle_lamp["position"]
		rear.append(Vector3(p.x, p.y, -p.z))
	for p: Vector3 in parts["lamps_front"]:
		idle.append({"position": Vector3(p.x, p.y, -p.z), "facing": 1.0, "color": "white"})
	result["lamps_rear"] = rear
	result["lamps_idle"] = idle
	result["lamps_front"] = []
	var display: Transform3D = parts["display"]
	result["display"] = Transform3D(Basis(Vector3.UP, PI) * display.basis,
		Vector3(display.origin.x, display.origin.y, -display.origin.z))
	return result


static func _mirror_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in vertices.size():
			vertices[i].z = -vertices[i].z
			normals[i].z = -normals[i].z
		# Spiegeln dreht den Umlaufsinn um: je Dreieck zwei Ecken tauschen
		for i in range(0, vertices.size() - 2, 3):
			var v := vertices[i + 1]
			vertices[i + 1] = vertices[i + 2]
			vertices[i + 2] = v
			var nn := normals[i + 1]
			normals[i + 1] = normals[i + 2]
			normals[i + 2] = nn
			var c := colors[i + 1]
			colors[i + 1] = colors[i + 2]
			colors[i + 2] = c
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
