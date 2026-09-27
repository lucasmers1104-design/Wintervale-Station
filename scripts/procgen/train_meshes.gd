@tool
## Prozedurale Zugmodelle im stilisierten Low-Poly-Look.
##
## Wagenkästen entstehen aus einem gerundeten Querschnitt, der durch "Ringe"
## gezogen wird. Die Normalen werden über die Nachbarflächen gemittelt – die
## Kästen wirken dadurch weich gerundet statt kantig. Die Lokfront entsteht,
## indem die letzten Ringe schmaler werden und das Dach absinkt; das
## Fensterband dieser Ringe wird zur umlaufenden Frontscheibe.
##
## Koordinaten je Fahrzeug: Ursprung = Wagenmitte auf Schienenoberkante,
## -Z = vorne, +X = rechts. Alle Maße in Metern.
##
## Fahrzeugtypen: loco_regional, coach, loco_freight, wagon_timber,
## wagon_container, wagon_hopper. Ergebnisse werden je Lackierung zwischengespeichert.
class_name TrainMeshes
extends RefCounted

## Fahrzeugdaten: Länge und Abstand Wagenmitte → Drehgestellmitte.
const SPECS := {
	"loco_regional": {"length": 10.0, "bogie": 3.3, "wheel_base": 2.2},
	"coach": {"length": 12.0, "bogie": 4.3, "wheel_base": 2.2},
	"loco_freight": {"length": 8.6, "bogie": 2.7, "wheel_base": 2.0},
	"wagon_timber": {"length": 9.0, "bogie": 3.1, "wheel_base": 1.8},
	"wagon_container": {"length": 9.6, "bogie": 3.3, "wheel_base": 1.8},
	"wagon_hopper": {"length": 8.4, "bogie": 2.9, "wheel_base": 1.8},
}
## Abstand zwischen zwei Wagenkästen (Puffer berühren sich).
const COUPLING_GAP := 0.84
const WHEEL_RADIUS := 0.42
const BUFFER_HEIGHT := 1.05

const UNDER := Color(0.16, 0.16, 0.18)
const FRAME := Color(0.2, 0.2, 0.22)
const METAL := Color(0.38, 0.38, 0.4)
const RUBBER := Color(0.1, 0.1, 0.11)
const SNOW := Color(0.9, 0.93, 0.97)
const PANE := Color(0.1, 0.13, 0.18)
const WOOD_DECK := Color(0.45, 0.32, 0.21)
const BARK := Color(0.33, 0.23, 0.16)
const LOG_END := Color(0.8, 0.65, 0.45)
const GRAVEL := Color(0.46, 0.44, 0.42)

static var _cache := {}


## Zwischenspeicher leeren (beim Beenden).
static func clear_cache() -> void:
	_cache.clear()


static func get_spec(kind: String) -> Dictionary:
	return SPECS.get(kind, SPECS["coach"])


## Baut ein Fahrzeug. Rückgabe:
## {"paint": ArrayMesh, "glass": ArrayMesh, "doors": [{"mesh","position","open_offset","side"}],
##  "lamps_front": [Vector3], "lamps_rear": [Vector3], "length", "bogie", "wheel_base"}
static func build_car(kind: String, livery: Dictionary, variant := 0) -> Dictionary:
	var key := "%s|%s|%d" % [kind, livery, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var result: Dictionary
	match kind:
		"loco_regional":
			result = _build_loco_regional(livery, rng)
		"loco_freight":
			result = _build_loco_freight(livery, rng)
		"wagon_timber":
			result = _build_wagon_timber(rng)
		"wagon_container":
			result = _build_wagon_container(rng)
		"wagon_hopper":
			result = _build_wagon_hopper(rng)
		_:
			result = _build_coach(livery, rng)
	var spec := get_spec(kind)
	result["length"] = spec["length"]
	result["bogie"] = spec["bogie"]
	result["wheel_base"] = spec["wheel_base"]
	_cache[key] = result
	return result


# --- Personenverkehr ---------------------------------------------------------------

## Gerundeter Querschnitt für Lok und Personenwagen (geschlossener Umriss).
static func _passenger_profile() -> Array[Vector2]:
	var right: Array[Vector2] = [
		Vector2(1.18, 0.98), Vector2(1.30, 1.10), Vector2(1.325, 1.82), Vector2(1.33, 1.95),
		Vector2(1.33, 2.85), Vector2(1.30, 3.05), Vector2(1.20, 3.25), Vector2(0.95, 3.43),
		Vector2(0.55, 3.53),
	]
	return _mirror(right, Vector2(0.0, 3.56))


static func _passenger_colors(points: Array[Vector2], livery: Dictionary) -> Array[Color]:
	var colors: Array[Color] = []
	for k in points.size():
		var mid := (points[k].y + points[(k + 1) % points.size()].y) * 0.5
		if mid < 1.12:
			colors.append(UNDER)
		elif mid < 1.83:
			colors.append(livery["primary"])
		elif mid < 1.96:
			colors.append(livery["accent"])
		elif mid < 3.0:
			colors.append(livery["secondary"])
		else:
			colors.append(livery["roof"])
	return colors


static func _build_coach(livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var glass := _new_st()
	var half := 6.0
	var points := _passenger_profile()
	var colors := _passenger_colors(points, livery)
	var grid := _extrude(paint, null, points, colors, [[half, 1.0, 0.0], [-half, 1.0, 0.0]], true)
	_cap(paint, grid[0], Vector3.BACK, livery["secondary"])
	_cap(paint, grid[-1], Vector3.FORWARD, livery["secondary"])

	# Fenster zwischen den Türen, Türöffnungen dunkel hinterlegt
	var doors: Array = []
	var leaf := _door_leaf(livery)
	for side: float in [-1.0, 1.0]:
		for window_range in [[-5.55, -3.7], [-2.05, 2.05], [3.7, 5.55]]:
			_window_row(glass, side, window_range[0], window_range[1], 2.02, 2.8, 1.33)
		for door_z: float in [-2.9, 2.9]:
			_side_quad(paint, side, 1.3335, door_z - 0.66, door_z + 0.66, 1.08, 2.95, RUBBER)
			for leaf_side: float in [-1.0, 1.0]:
				doors.append({"mesh": leaf, "position": Vector3(side * 1.348, 2.015, door_z + leaf_side * 0.32),
					"open_offset": Vector3(side * 0.06, 0.0, leaf_side * 0.6), "side": side})
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 0.93, door_z), Vector3(0.3, 0.07, 1.25), FRAME)

	# Dach: Klimageräte und Schneereste
	for roof_z: float in [-3.3, 3.3]:
		LowPolyBuilder.add_box(paint, Vector3(0.0, 3.62, roof_z), Vector3(1.7, 0.16, 1.5), livery["roof"].lightened(0.15))
		LowPolyBuilder.add_box(paint, Vector3(0.0, 3.73, roof_z), Vector3(1.45, 0.08, 1.2), livery["roof"].lightened(0.25))
		LowPolyBuilder.add_box(paint, Vector3(0.0, 3.785, roof_z), Vector3(1.2, 0.03, 0.9), SNOW)
	_roof_snow(paint, points, -5.8, 5.8, rng)

	# Unterboden, Puffer, Faltenbälge
	_underframe_equipment(paint, 2.6)
	for end: float in [-1.0, 1.0]:
		_add_buffers(paint, end * half, end)
		LowPolyBuilder.add_box(paint, Vector3(0.0, 2.2, end * (half + 0.14)), Vector3(1.05, 2.15, 0.28), RUBBER)
		for i in 5:
			LowPolyBuilder.add_box(paint, Vector3(0.0, 2.2, end * (half + 0.28)), Vector3(1.08, 2.18 - i * 0.35, 0.02), FRAME)
	return {
		"paint": paint.commit(), "glass": glass.commit(), "doors": doors,
		"lamps_front": [], "lamps_rear": [Vector3(-0.92, 1.45, half + 0.02), Vector3(0.92, 1.45, half + 0.02)],
	}


static func _build_loco_regional(livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var glass := _new_st()
	var half := 5.0
	var points := _passenger_profile()
	var colors := _passenger_colors(points, livery)
	# Ringe von hinten nach vorne: [z, Breite, Dachabsenkung]
	var rings := [[half, 1.0, 0.0], [-3.3, 1.0, 0.0], [-4.15, 0.985, 0.32], [-4.7, 0.95, 0.85], [-5.0, 0.9, 1.15]]
	# Seitenfenster des Führerstands und umlaufende Frontscheibe
	var glass_edges := _band_edges(points, [1, 2, 3], 1.95, 3.0)
	# Warngelbe Front
	var overrides := {}
	for k in points.size():
		var mid := (points[k].y + points[(k + 1) % points.size()].y) * 0.5
		if mid > 1.12 and mid < 1.96:
			overrides[Vector2i(3, k)] = livery["accent"]
	var grid := _extrude(paint, glass, points, colors, rings, true, glass_edges, overrides)
	_cap(paint, grid[0], Vector3.BACK, livery["secondary"])
	_cap(paint, grid[-1], Vector3.FORWARD, livery["accent"])

	for side: float in [-1.0, 1.0]:
		# Lüftungsgitter des Maschinenraums
		for i in 8:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.337, 2.12 + i * 0.085, 0.6), Vector3(0.02, 0.035, 5.6), UNDER)
		# Führerstandstür
		_side_quad(paint, side, 1.3345, -3.2, -2.6, 1.15, 2.9, livery["accent"])
		_window_row(glass, side, -3.1, -2.7, 2.15, 2.65, 1.3355)
		LowPolyBuilder.add_box(paint, Vector3(side * 1.25, 0.93, -2.9), Vector3(0.3, 0.07, 0.7), FRAME)

	# Dach: Lüfter, Horn, Antenne, Schnee
	for fan_z: float in [0.4, 2.3]:
		LowPolyBuilder.add_cylinder(paint, Vector3(0.0, 3.54, fan_z), 0.5, 0.5, 0.06, 12, livery["roof"].darkened(0.3))
		LowPolyBuilder.add_cylinder(paint, Vector3(0.0, 3.6, fan_z), 0.42, 0.42, 0.03, 12, UNDER)
		LowPolyBuilder.add_box(paint, Vector3(0.0, 3.635, fan_z), Vector3(0.8, 0.02, 0.06), METAL)
	for x: float in [-0.22, 0.22]:
		LowPolyBuilder.add_cylinder_between(paint, Vector3(x, 3.5, -3.55), Vector3(x, 3.5, -3.95), 0.05, 6, METAL)
	LowPolyBuilder.add_box(paint, Vector3(0.45, 3.7, -2.6), Vector3(0.03, 0.3, 0.03), UNDER)
	_roof_snow(paint, points, -3.1, 4.8, rng)

	# Unterboden mit Tank, Puffer hinten, Schneepflug und Puffer vorne
	LowPolyBuilder.add_cylinder_between(paint, Vector3(0.0, 0.66, -1.7), Vector3(0.0, 0.66, 1.7), 0.36, 10, UNDER)
	_add_buffers(paint, half, 1.0)
	_add_buffers(paint, -half, -1.0)
	_snow_plough(paint, -half, livery["primary"])
	return {
		"paint": paint.commit(), "glass": glass.commit(), "doors": [],
		"lamps_front": [Vector3(-0.72, 1.5, -half - 0.03), Vector3(0.72, 1.5, -half - 0.03), Vector3(0.0, 3.3, -4.2)],
		"lamps_rear": [Vector3(-0.92, 1.5, half + 0.02), Vector3(0.92, 1.5, half + 0.02)],
	}


# --- Güterverkehr --------------------------------------------------------------------

static func _build_loco_freight(livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var glass := _new_st()
	var half := 4.3

	# Rahmen mit gelben Kanten und Warnstreifen an den Pufferbohlen
	LowPolyBuilder.add_box(paint, Vector3(0.0, 1.12, 0.0), Vector3(2.7, 0.32, half * 2.0), UNDER)
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(paint, Vector3(side * 1.34, 1.24, 0.0), Vector3(0.04, 0.06, half * 2.0), livery["accent"])
	for end: float in [-1.0, 1.0]:
		for i in 6:
			var color: Color = livery["accent"] if i % 2 == 0 else UNDER
			LowPolyBuilder.add_box(paint, Vector3(-1.125 + i * 0.45, 1.05, end * (half + 0.02)), Vector3(0.45, 0.3, 0.06), color)

	# Langer Vorbau mit gerundeter Oberseite
	var hood: Array[Vector2] = _mirror([Vector2(0.85, 1.28), Vector2(0.87, 2.2), Vector2(0.87, 2.34),
		Vector2(0.8, 2.7), Vector2(0.55, 2.88)], Vector2(0.0, 2.93))
	var hood_colors: Array[Color] = []
	for k in hood.size():
		var mid := (hood[k].y + hood[(k + 1) % hood.size()].y) * 0.5
		hood_colors.append(livery["secondary"] if mid > 2.2 and mid < 2.34 else livery["primary"])
	var hood_grid := _extrude(paint, null, hood, hood_colors, [[1.3, 1.0, 0.0], [-3.95, 1.0, 0.0]], true)
	_cap(paint, hood_grid[-1], Vector3.FORWARD, livery["primary"])

	# Führerhaus mit Fenstern rundum
	var cab: Array[Vector2] = _mirror([Vector2(1.25, 1.28), Vector2(1.28, 2.15), Vector2(1.28, 3.2),
		Vector2(1.12, 3.4), Vector2(0.6, 3.49)], Vector2(0.0, 3.52))
	var cab_colors: Array[Color] = []
	for k in cab.size():
		var mid := (cab[k].y + cab[(k + 1) % cab.size()].y) * 0.5
		cab_colors.append(livery["roof"] if mid > 3.25 else livery["primary"])
	var cab_grid := _extrude(paint, null, cab, cab_colors, [[4.1, 1.0, 0.0], [1.3, 1.0, 0.0]], true)
	_cap(paint, cab_grid[0], Vector3.BACK, livery["primary"])
	_cap(paint, cab_grid[-1], Vector3.FORWARD, livery["primary"])
	_end_windows(glass, 1.3 - 0.012, -1.0, [[-1.05, -0.2], [0.2, 1.05]], 2.45, 3.1)
	_end_windows(glass, 4.1 + 0.012, 1.0, [[-1.05, -0.2], [0.2, 1.05]], 2.45, 3.1)
	for side: float in [-1.0, 1.0]:
		_window_row(glass, side, 1.55, 2.45, 2.45, 3.1, 1.29)
		_window_row(glass, side, 2.65, 3.85, 2.45, 3.1, 1.29)

	# Geländer, Auspuff, Kühlergitter, Schnee
	for side: float in [-1.0, 1.0]:
		var post_z := -4.1
		while post_z < 1.3:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.28, 1.8, post_z), Vector3(0.04, 1.0, 0.04), livery["accent"])
			post_z += 1.08
		LowPolyBuilder.add_box(paint, Vector3(side * 1.28, 2.3, -1.4), Vector3(0.045, 0.045, 5.5), livery["accent"])
		for i in 6:
			LowPolyBuilder.add_box(paint, Vector3(side * 0.875, 1.6 + i * 0.1, 0.4), Vector3(0.02, 0.04, 1.4), UNDER)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.3, -4.12), Vector3(2.56, 0.045, 0.045), livery["accent"])
	LowPolyBuilder.add_cylinder(paint, Vector3(0.0, 2.9, -2.2), 0.13, 0.11, 0.38, 8, UNDER)
	LowPolyBuilder.add_cylinder(paint, Vector3(0.0, 2.92, -0.8), 0.45, 0.45, 0.04, 12, UNDER)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.95, -3.0), Vector3(0.9, 0.03, 1.5), SNOW)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 3.53, 2.7), Vector3(1.6, 0.03, 2.2), SNOW)
	_underframe_equipment(paint, 1.4)
	for end: float in [-1.0, 1.0]:
		_add_buffers(paint, end * half, end)
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.2, 0.72, end * (half - 0.25)), Vector3(0.35, 0.05, 0.3), livery["accent"])
	return {
		"paint": paint.commit(), "glass": glass.commit(), "doors": [],
		"lamps_front": [Vector3(0.0, 2.6, -3.98), Vector3(-0.95, 1.42, -half - 0.06), Vector3(0.95, 1.42, -half - 0.06)],
		"lamps_rear": [Vector3(-0.95, 1.42, half + 0.06), Vector3(0.95, 1.42, half + 0.06)],
	}


static func _build_wagon_timber(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 4.5
	_flat_wagon_base(paint, half, rng)
	# Rungen und Holzstämme mit hellen Schnittflächen
	for side: float in [-1.0, 1.0]:
		for i in 5:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 2.05, -3.6 + i * 1.8), Vector3(0.09, 1.5, 0.09), UNDER)
	var rows := [[-0.87, -0.29, 0.29, 0.87], [-0.58, 0.0, 0.58], [-0.29, 0.29]]
	for row_index in rows.size():
		for x: float in rows[row_index]:
			var y := 1.62 + row_index * 0.5
			var log_half := 4.1 - rng.randf() * 0.25
			var radius := rng.randf_range(0.26, 0.3)
			var bark := BARK.lerp(Color(0.42, 0.3, 0.2), rng.randf())
			LowPolyBuilder.add_cylinder_between(paint, Vector3(x, y, -log_half), Vector3(x, y, log_half), radius, 9, bark)
			for end: float in [-1.0, 1.0]:
				LowPolyBuilder.add_cylinder_between(paint, Vector3(x, y, end * log_half), Vector3(x, y, end * (log_half + 0.02)),
					radius * 0.92, 9, LOG_END.lerp(Color(0.9, 0.78, 0.6), rng.randf()))
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.9, 0.0), Vector3(0.62, 0.05, 7.4), SNOW)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.43, 0.0), Vector3(1.5, 0.04, 7.0), SNOW)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


static func _build_wagon_container(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 4.8
	_flat_wagon_base(paint, half, rng)
	var palette := [Color(0.18, 0.45, 0.48), Color(0.62, 0.24, 0.16), Color(0.8, 0.6, 0.2), Color(0.26, 0.36, 0.52)]
	for z_center: float in [-2.2, 2.2]:
		var color: Color = palette[rng.randi() % palette.size()]
		var ribs := color.darkened(0.15)
		LowPolyBuilder.add_box(paint, Vector3(0.0, 2.55, z_center), Vector3(2.4, 2.45, 4.1), color)
		# Wellblech: senkrechte Rippen an den Seiten
		for side: float in [-1.0, 1.0]:
			for i in 15:
				LowPolyBuilder.add_box(paint, Vector3(side * 1.215, 2.55, z_center - 1.85 + i * 0.265), Vector3(0.04, 2.25, 0.1), ribs)
		# Türseite mit Verschlussstangen, Eckbeschläge
		var door_z: float = z_center + 2.06 * signf(z_center)
		for x: float in [-0.8, -0.3, 0.3, 0.8]:
			LowPolyBuilder.add_box(paint, Vector3(x, 2.55, door_z), Vector3(0.05, 2.3, 0.04), METAL)
		for corner_x: float in [-1.17, 1.17]:
			for corner_y: float in [1.36, 3.74]:
				for corner_z in [z_center - 2.02, z_center + 2.02]:
					LowPolyBuilder.add_box(paint, Vector3(corner_x, corner_y, corner_z), Vector3(0.12, 0.1, 0.12), UNDER)
		LowPolyBuilder.add_box(paint, Vector3(0.0, 3.8, z_center), Vector3(2.2, 0.04, 3.8), SNOW)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


static func _build_wagon_hopper(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 4.2
	var body_color := Color(0.3, 0.36, 0.33).lerp(Color(0.42, 0.3, 0.22), rng.randf())
	# Rahmen, Drehgestell-Aufnahmen
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(paint, Vector3(side * 1.1, 1.0, 0.0), Vector3(0.18, 0.3, half * 2.0), UNDER)
	# Trichterkasten: schräge Seiten, oben offen
	var profile: Array[Vector2] = [Vector2(-1.35, 3.35), Vector2(-1.35, 2.55), Vector2(-0.65, 1.35),
		Vector2(0.65, 1.35), Vector2(1.35, 2.55), Vector2(1.35, 3.35)]
	var colors: Array[Color] = []
	for k in profile.size():
		colors.append(body_color)
	var grid := _extrude(paint, null, profile, colors, [[half - 0.35, 1.0, 0.0], [-half + 0.35, 1.0, 0.0]], false)
	_cap(paint, grid[0], Vector3.BACK, body_color.darkened(0.1))
	_cap(paint, grid[-1], Vector3.FORWARD, body_color.darkened(0.1))
	# Rippen außen
	for side: float in [-1.0, 1.0]:
		for i in 8:
			var z := -half + 0.75 + i * ((half * 2.0 - 1.5) / 7.0)
			LowPolyBuilder.add_box(paint, Vector3(side * 1.37, 2.95, z), Vector3(0.06, 0.8, 0.1), body_color.darkened(0.25))
	# Ladung: Schotter mit Schneehaube, Auslaufschurren unten
	var st_load := paint
	var cells := 8
	for i in cells:
		for j in 3:
			var z0 := -half + 0.45 + i * ((half * 2.0 - 0.9) / cells)
			var z1 := z0 + (half * 2.0 - 0.9) / cells
			var x0 := -1.3 + j * (2.6 / 3.0)
			var x1 := x0 + 2.6 / 3.0
			var top := 3.25 + (0.18 if j == 1 else 0.0) + rng.randf_range(-0.05, 0.05)
			var color := SNOW if rng.randf() < 0.45 else GRAVEL.lerp(Color(0.32, 0.3, 0.28), rng.randf())
			LowPolyBuilder.add_quad_facing(st_load, Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1),
				Vector3(x0, top, z1), color, Vector3.UP)
	for z: float in [-1.2, 1.2]:
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.15, z), Vector3(1.1, 0.3, 0.8), body_color.darkened(0.3))
	for end: float in [-1.0, 1.0]:
		_add_buffers(paint, end * half, end)
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.05, end * (half - 0.05)), Vector3(2.5, 0.3, 0.1), UNDER)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


# --- Drehgestelle --------------------------------------------------------------------

## Drehgestellrahmen (ohne Radsätze). Ursprung = Mitte auf Schienenoberkante.
static func create_bogie(wheel_base: float) -> ArrayMesh:
	var key := "bogie|%f" % wheel_base
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(side * 0.98, 0.5, 0.0), Vector3(0.12, 0.26, wheel_base + 0.7), FRAME)
		LowPolyBuilder.add_box(st, Vector3(side * 0.98, 0.36, 0.0), Vector3(0.1, 0.12, wheel_base * 0.5), FRAME)
		for axle: float in [-0.5, 0.5]:
			LowPolyBuilder.add_box(st, Vector3(side * 0.98, WHEEL_RADIUS, axle * wheel_base), Vector3(0.18, 0.24, 0.3), UNDER)
			LowPolyBuilder.add_cylinder(st, Vector3(side * 0.98, 0.62, axle * wheel_base * 0.55), 0.08, 0.08, 0.16, 8, METAL)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.74, 0.0), Vector3(2.1, 0.16, 0.4), FRAME)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Radsatz: zwei Räder mit Speichenmarkierung (damit man das Drehen sieht) und Achse.
## Ursprung = Achsmitte; dreht sich um X.
static func create_wheelset() -> ArrayMesh:
	if _cache.has("wheelset"):
		return _cache["wheelset"]
	var st := _new_st()
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.72, 0.0, 0.0), Vector3(0.72, 0.0, 0.0), 0.07, 8, METAL)
	for side: float in [-1.0, 1.0]:
		var inner := side * 0.68
		var outer := side * 0.8
		LowPolyBuilder.add_cylinder_between(st, Vector3(inner, 0.0, 0.0), Vector3(outer, 0.0, 0.0), WHEEL_RADIUS, 12, UNDER)
		LowPolyBuilder.add_cylinder_between(st, Vector3(inner - side * 0.03, 0.0, 0.0), Vector3(inner, 0.0, 0.0),
			WHEEL_RADIUS + 0.035, 12, METAL)
		var face := side * 0.805
		LowPolyBuilder.add_box(st, Vector3(face, 0.0, 0.0), Vector3(0.012, WHEEL_RADIUS * 1.6, 0.07), METAL)
		LowPolyBuilder.add_box(st, Vector3(face, 0.0, 0.0), Vector3(0.012, 0.07, WHEEL_RADIUS * 1.6), METAL)
	var mesh := st.commit()
	_cache["wheelset"] = mesh
	return mesh


# --- Bausteine ---------------------------------------------------------------------

static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Rechte Hälfte + Scheitelpunkt → geschlossener, symmetrischer Umriss.
## Reihenfolge: links unten → oben → rechts unten; die Schlusskante bildet den Boden.
static func _mirror(right: Array[Vector2], top: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for p in right:
		points.append(Vector2(-p.x, p.y))
	points.append(top)
	for i in range(right.size() - 1, -1, -1):
		points.append(right[i])
	return points


## Kanten eines Profils im Höhenband [y0, y1] für die angegebenen Ring-Intervalle.
static func _band_edges(points: Array[Vector2], intervals: Array, y0: float, y1: float) -> Dictionary:
	var edges := {}
	for r: int in intervals:
		for k in points.size():
			var mid := (points[k].y + points[(k + 1) % points.size()].y) * 0.5
			if mid >= y0 and mid <= y1:
				edges[Vector2i(r, k)] = true
	return edges


## Zieht ein Profil durch Ringe [z, Breitenfaktor, Dachabsenkung] und rundet die
## Normalen über benachbarte Flächen. Kanten in [param glass_edges] landen im
## Glas-Mesh. Rückgabe: die Punkte jedes Rings (für Deckel).
static func _extrude(paint: SurfaceTool, glass: SurfaceTool, points: Array[Vector2], colors: Array[Color],
		rings: Array, closed: bool, glass_edges := {}, color_overrides := {}, drop_from := 2.2,
		roof_top := 3.56) -> Array[PackedVector3Array]:
	var n := points.size()
	var edge_count := n if closed else n - 1
	var center_y := 0.0
	for p in points:
		center_y += p.y
	center_y /= n

	var grid: Array[PackedVector3Array] = []
	for ring: Array in rings:
		var row := PackedVector3Array()
		for p in points:
			var f := clampf((p.y - drop_from) / (roof_top - drop_from), 0.0, 1.0)
			row.append(Vector3(p.x * float(ring[1]), p.y - float(ring[2]) * f, float(ring[0])))
		grid.append(row)

	# Weiche Normalen: Flächennormalen je Eckpunkt aufsummieren (flaches Array: Ring * n + Punkt)
	var normals := PackedVector3Array()
	normals.resize(rings.size() * n)
	var face_normals := {}
	for r in rings.size() - 1:
		for k in edge_count:
			var k2 := (k + 1) % n
			var a := grid[r][k]
			var b := grid[r][k2]
			var c := grid[r + 1][k2]
			var d := grid[r + 1][k]
			var normal := (b - a).cross(d - a)
			var mid := (a + b + c + d) * 0.25
			if normal.dot(Vector3(mid.x, mid.y - center_y, 0.0)) < 0.0:
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
		for k in edge_count:
			var k2 := (k + 1) % n
			var key := Vector2i(r, k)
			var target := glass if glass and glass_edges.has(key) else paint
			var color: Color = color_overrides.get(key, colors[k])
			_smooth_quad(target, [grid[r][k], grid[r][k2], grid[r + 1][k2], grid[r + 1][k]],
				[normals[r * n + k], normals[r * n + k2], normals[(r + 1) * n + k2], normals[(r + 1) * n + k]],
				color, face_normals[key])
	return grid


static func _smooth_quad(st: SurfaceTool, p: Array, normal: Array, color: Color, outward: Vector3) -> void:
	_smooth_triangle(st, p[0], p[1], p[2], normal[0], normal[1], normal[2], color, outward)
	_smooth_triangle(st, p[0], p[2], p[3], normal[0], normal[2], normal[3], color, outward)


static func _smooth_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3,
		nc: Vector3, color: Color, outward: Vector3) -> void:
	if LowPolyBuilder.face_normal(a, b, c).dot(outward) < 0.0:
		var swap_point := b
		b = c
		c = swap_point
		var swap_normal := nb
		nb = nc
		nc = swap_normal
	st.set_color(color)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


## Stirnwand: Fächer aus dem Mittelpunkt, flach schattiert.
static func _cap(st: SurfaceTool, row: PackedVector3Array, outward: Vector3, color: Color) -> void:
	var center := Vector3.ZERO
	for p in row:
		center += p
	center /= row.size()
	for i in row.size():
		LowPolyBuilder.add_triangle_facing(st, center, row[i], row[(i + 1) % row.size()], color, outward)


## Fensterreihe an einer Wagenseite: Scheiben mit schmalen Stegen dazwischen.
static func _window_row(glass: SurfaceTool, side: float, z0: float, z1: float, y0: float, y1: float, x: float) -> void:
	var span := z1 - z0
	var count := maxi(1, roundi(span / 1.3))
	var pillar := 0.18
	var width := (span - pillar * (count - 1)) / count
	for i in count:
		var a := z0 + i * (width + pillar)
		_side_quad(glass, side, x + 0.012, a, a + width, y0, y1, PANE)


## Rechteck an der Wagenseite (Normale nach außen).
static func _side_quad(st: SurfaceTool, side: float, x: float, z0: float, z1: float, y0: float, y1: float,
		color: Color) -> void:
	var px := side * x
	LowPolyBuilder.add_quad_facing(st, Vector3(px, y0, z0), Vector3(px, y0, z1), Vector3(px, y1, z1),
		Vector3(px, y1, z0), color, Vector3(side, 0.0, 0.0))


## Fenster an einer Stirnwand (Normale entlang Z).
static func _end_windows(glass: SurfaceTool, z: float, facing: float, x_ranges: Array, y0: float, y1: float) -> void:
	for x_range: Array in x_ranges:
		LowPolyBuilder.add_quad_facing(glass, Vector3(x_range[0], y0, z), Vector3(x_range[1], y0, z),
			Vector3(x_range[1], y1, z), Vector3(x_range[0], y1, z), PANE, Vector3(0.0, 0.0, facing))


## Schiebetürflügel: Türblatt in Akzentfarbe mit Fenster und Griff.
static func _door_leaf(livery: Dictionary) -> ArrayMesh:
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3.ZERO, Vector3(0.04, 1.84, 0.62), livery["accent"])
	LowPolyBuilder.add_box(st, Vector3(0.022, 0.42, 0.0), Vector3(0.01, 0.62, 0.44), PANE)
	LowPolyBuilder.add_box(st, Vector3(0.025, -0.1, 0.0), Vector3(0.02, 0.2, 0.05), METAL)
	return st.commit()


## Schneereste auf dem Dach in unregelmäßigen Stücken.
static func _roof_snow(st: SurfaceTool, points: Array[Vector2], z0: float, z1: float, rng: RandomNumberGenerator) -> void:
	var roof: Array[Vector2] = []
	for p in points:
		if p.y > 3.4:
			roof.append(Vector2(p.x * 0.97, p.y + 0.03))
	# Nur die oberen Punkte, von links nach rechts sortiert
	roof.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var colors: Array[Color] = []
	for i in roof.size():
		colors.append(SNOW)
	var z := z0
	while z < z1:
		var piece := rng.randf_range(1.2, 3.0)
		var end := minf(z + piece, z1)
		var grid := _extrude(st, null, roof, colors, [[end, 1.0, 0.0], [z, 1.0, 0.0]], false)
		_cap(st, grid[0], Vector3.BACK, SNOW)
		_cap(st, grid[-1], Vector3.FORWARD, SNOW)
		z = end + rng.randf_range(0.3, 1.2)


## Puffer, Pufferbohle und Kupplungshaken an einem Wagenende ([param direction] ±1).
static func _add_buffers(st: SurfaceTool, z_end: float, direction: float) -> void:
	LowPolyBuilder.add_box(st, Vector3(0.0, BUFFER_HEIGHT, z_end + direction * 0.04), Vector3(2.5, 0.3, 0.1), FRAME)
	for x: float in [-0.85, 0.85]:
		var base := Vector3(x, BUFFER_HEIGHT, z_end)
		LowPolyBuilder.add_cylinder_between(st, base, base + Vector3(0.0, 0.0, direction * 0.36), 0.09, 8, METAL)
		LowPolyBuilder.add_cylinder_between(st, base + Vector3(0.0, 0.0, direction * 0.36),
			base + Vector3(0.0, 0.0, direction * 0.42), 0.18, 10, METAL.darkened(0.2))
	LowPolyBuilder.add_box(st, Vector3(0.0, BUFFER_HEIGHT - 0.05, z_end + direction * 0.25), Vector3(0.12, 0.1, 0.35), UNDER)


## Unterflurkästen zwischen den Drehgestellen.
static func _underframe_equipment(st: SurfaceTool, half_span: float) -> void:
	LowPolyBuilder.add_box(st, Vector3(-0.45, 0.72, 0.0), Vector3(0.9, 0.42, half_span * 1.4), UNDER)
	LowPolyBuilder.add_box(st, Vector3(0.55, 0.75, -half_span * 0.3), Vector3(0.7, 0.36, half_span * 0.8), FRAME)
	LowPolyBuilder.add_box(st, Vector3(0.55, 0.78, half_span * 0.55), Vector3(0.6, 0.3, half_span * 0.5), UNDER)


## Keilförmiger Schneepflug unter der Lokfront.
static func _snow_plough(st: SurfaceTool, z_front: float, color: Color) -> void:
	var tip := Vector3(0.0, 0.12, z_front - 0.55)
	var left_top := Vector3(-1.2, 0.85, z_front - 0.05)
	var right_top := Vector3(1.2, 0.85, z_front - 0.05)
	var left_bottom := Vector3(-1.2, 0.12, z_front - 0.1)
	var right_bottom := Vector3(1.2, 0.12, z_front - 0.1)
	var tip_top := Vector3(0.0, 0.85, z_front - 0.45)
	LowPolyBuilder.add_quad_facing(st, left_bottom, tip, tip_top, left_top, color, Vector3(-0.4, 0.2, -1.0))
	LowPolyBuilder.add_quad_facing(st, tip, right_bottom, right_top, tip_top, color, Vector3(0.4, 0.2, -1.0))
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.88, z_front - 0.22), Vector3(2.45, 0.06, 0.5), SNOW)


## Flachwagen-Unterbau: Langträger, Holzboden, Puffer.
static func _flat_wagon_base(st: SurfaceTool, half: float, rng: RandomNumberGenerator) -> void:
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(side * 1.18, 0.98, 0.0), Vector3(0.18, 0.34, half * 2.0), UNDER)
	var planks := int(half * 2.0 / 0.5)
	for i in planks:
		var z := -half + 0.25 + i * 0.5
		LowPolyBuilder.add_box(st, Vector3(0.0, 1.2, z), Vector3(2.55, 0.12, 0.48), WOOD_DECK.lerp(WOOD_DECK.darkened(0.2), rng.randf()))
	for end: float in [-1.0, 1.0]:
		_add_buffers(st, end * half, end)
