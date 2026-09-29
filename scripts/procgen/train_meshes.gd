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
## wagon_container, wagon_hopper, wagon_flat, wagon_stake – dazu der moderne Triebzug
## railcar_front, railcar_middle, railcar_rear ([RailcarMeshes]). Ergebnisse werden je Lackierung zwischengespeichert.
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
	"wagon_flat": {"length": 9.6, "bogie": 3.3, "wheel_base": 1.8},
	"wagon_stake": {"length": 10.2, "bogie": 3.5, "wheel_base": 1.8},
}
## Ladung der Güterwagen: Material, Menge je Stück, Modell des Stücks und
## Ladeplätze (Mitte der Unterkante, lokal zum Wagen).
## "empty" = Leergut, das auf frei gewordene Plätze zurückgeladen werden kann;
## "bulk" = Schüttgut, das der Kran mit dem Greifer in so vielen Portionen entlädt.
const CARGO := {
	"wagon_timber": {"goods": "wood", "amount": 10, "piece": "wood_bundle",
		"slots": [Vector3(0.0, 1.36, -2.95), Vector3(0.0, 1.36, 0.0), Vector3(0.0, 1.36, 2.95)]},
	"wagon_flat": {"goods": "brick", "amount": 6, "piece": "brick_pallet", "empty": "pallet_stack",
		"slots": [Vector3(-0.62, 1.26, -3.2), Vector3(0.62, 1.26, -3.2), Vector3(-0.62, 1.26, 0.0),
			Vector3(0.62, 1.26, 0.0), Vector3(-0.62, 1.26, 3.2), Vector3(0.62, 1.26, 3.2)]},
	"wagon_container": {"goods": "glass", "amount": 8, "piece": "glass_container", "empty": "container_empty",
		"slots": [Vector3(0.0, 1.32, -2.2), Vector3(0.0, 1.32, 2.2)]},
	"wagon_stake": {"goods": "steel", "amount": 4, "piece": "steel_bundle",
		"slots": [Vector3(0.0, 1.36, -3.3), Vector3(0.0, 1.36, 0.0), Vector3(0.0, 1.36, 3.3)]},
	"wagon_hopper": {"goods": "stone", "amount": 8, "piece": "stone_pile", "bulk": 3,
		"slots": [Vector3.ZERO]},
}
## So tief sinkt die Schüttgut-Oberfläche im Trichterwagen, bis er leer ist.
const BULK_DEPTH := 1.75
const CARGO_WOOD := Color(0.36, 0.25, 0.17)
const PALLET := Color(0.72, 0.58, 0.4)
const BRICK := Color(0.68, 0.3, 0.2)
const STEEL := Color(0.42, 0.47, 0.53)
## Abstand zwischen zwei Wagenkästen (Puffer berühren sich).
const COUPLING_GAP := 0.84
const WHEEL_RADIUS := 0.42
const BUFFER_HEIGHT := 1.05
## Oberkante des Wagenbodens an den Türen (über Schienenoberkante).
const FLOOR_HEIGHT := 1.08

# Ausfahrbare Trittstufe (Maße für die Seite +X, lokal zum Wagen)
const STEP_WIDTH := 1.0
const STEP_DEPTH := 0.34
## Oberkante der oberen Stufe.
const STEP_UPPER_Y := 0.72
## Mitte der unteren Stufe relativ zum Scharnier (ausgeklappt).
const STEP_LOWER_OFFSET := Vector2(0.3, -0.36)
## Mitte der oberen Stufe eingefahren / ausgefahren (Abstand zur Wagenmitte).
const STEP_RETRACTED_X := 1.0
const STEP_EXTENDED_X := 1.48
## So weit ist die untere Stufe eingeklappt (Bogenmaß um die Längsachse).
const STEP_FOLD_ANGLE := 2.14
const STEP_YELLOW := Color(0.95, 0.76, 0.22)

const UNDER := Color(0.16, 0.16, 0.18)
const FRAME := Color(0.2, 0.2, 0.22)
const METAL := Color(0.38, 0.38, 0.4)
const RUBBER := Color(0.1, 0.1, 0.11)
const SNOW := Color(0.9, 0.93, 0.97, 0.5)
const PANE := Color(0.1, 0.13, 0.18)
const WOOD_DECK := Color(0.45, 0.32, 0.21)
const BARK := Color(0.33, 0.23, 0.16)
const LOG_END := Color(0.8, 0.65, 0.45)
const GRAVEL := Color(0.46, 0.44, 0.42)

## Anstrich der Güterwagen (Langträger, Stirnwände): Oxidrot, Graublau, Tannengrün.
const WAGON_COLORS: Array[Color] = [Color(0.45, 0.2, 0.15), Color(0.32, 0.37, 0.42), Color(0.24, 0.33, 0.27)]

static var _cache := {}


## Zwischenspeicher leeren (beim Beenden).
static func clear_cache() -> void:
	_cache.clear()


static func get_spec(kind: String) -> Dictionary:
	if RailcarMeshes.SPECS.has(kind):
		return RailcarMeshes.SPECS[kind]
	return SPECS.get(kind, SPECS["coach"])


## Baut ein Fahrzeug. Rückgabe:
## {"paint": ArrayMesh, "glass": ArrayMesh, "doors": [{"mesh","position","open_offset","side"}],
##  "lamps_front": [Vector3], "lamps_rear": [Vector3], "length", "bogie", "wheel_base"}
## Triebwagen ([RailcarMeshes]) zusätzlich: "lamps_idle" (unbeleuchtete Lampen) und
## "display" (Lage der Zielanzeige).
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
		"wagon_flat":
			result = _build_wagon_flat(rng)
		"wagon_stake":
			result = _build_wagon_stake(rng)
		"railcar_front", "railcar_middle", "railcar_rear":
			result = RailcarMeshes.build(kind, livery, rng)
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
	_freight_loco_details(paint, livery, half)
	for end: float in [-1.0, 1.0]:
		_add_buffers(paint, end * half, end)
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.2, 0.72, end * (half - 0.25)), Vector3(0.35, 0.05, 0.3), livery["accent"])
	return {
		"paint": paint.commit(), "glass": glass.commit(), "doors": [],
		"lamps_front": [Vector3(0.0, 2.6, -3.98), Vector3(-0.95, 1.42, -half - 0.06), Vector3(0.95, 1.42, -half - 0.06)],
		"lamps_rear": [Vector3(-0.95, 1.42, half + 0.06), Vector3(0.95, 1.42, half + 0.06)],
	}


## Feinheiten der Güterlok (Etappe 9.5): Wartungstüren am Vorbau, runde Lampengehäuse,
## Sonnenblenden, Signalhorn, Tank, Sandkästen, Aufstiegstritte und Nummernschild.
static func _freight_loco_details(paint: SurfaceTool, livery: Dictionary, half: float) -> void:
	var primary: Color = livery["primary"]
	for side: float in [-1.0, 1.0]:
		# Wartungstüren: feine Fugen und Griffe am Vorbau
		for i in 5:
			var z := -3.6 + i * 0.95
			LowPolyBuilder.add_box(paint, Vector3(side * 0.875, 1.75, z), Vector3(0.012, 0.9, 0.025), primary.darkened(0.3))
			LowPolyBuilder.add_box(paint, Vector3(side * 0.88, 1.85, z + 0.45), Vector3(0.02, 0.1, 0.03), METAL)
		# Sonnenblenden über den Seitenfenstern des Führerhauses
		LowPolyBuilder.add_oriented_box(paint, Transform3D(Basis(Vector3.BACK, side * 0.35), Vector3(side * 1.33, 3.16, 2.05)),
			Vector3(0.14, 0.02, 1.9), UNDER)
		# Sandkästen an den Drehgestellen
		for end: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.18, 0.86, end * 3.9), Vector3(0.22, 0.26, 0.3), primary.darkened(0.15))
			# Aufstiegstritte an den Ecken
			for k in 2:
				LowPolyBuilder.add_box(paint, Vector3(side * 1.2, 0.58 + k * 0.28, end * (half - 0.3)), Vector3(0.28, 0.035, 0.3),
					STEP_YELLOW)
			LowPolyBuilder.add_beam(paint, Vector3(side * 1.33, 0.55, end * (half - 0.16)), Vector3(side * 1.33, 1.0, end * (half - 0.16)),
				0.03, FRAME)
	# Runde Lampengehäuse vorne (Vorbau oben, Pufferbohle) und hinten
	for lamp: Vector3 in [Vector3(0.0, 2.6, -3.96), Vector3(-0.95, 1.42, -half - 0.02), Vector3(0.95, 1.42, -half - 0.02),
			Vector3(-0.95, 1.42, half + 0.02), Vector3(0.95, 1.42, half + 0.02)]:
		var out := -1.0 if lamp.z < 0.0 else 1.0
		LowPolyBuilder.add_cylinder_between(paint, lamp - Vector3(0.0, 0.0, out * 0.04), lamp + Vector3(0.0, 0.0, out * 0.03), 0.15, 12, FRAME)
	# Nummernschild unter der oberen Lampe, Signalhorn auf dem Führerhaus
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.3, -3.975), Vector3(0.62, 0.16, 0.02), UNDER)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 2.3, -3.99), Vector3(0.5, 0.1, 0.01), Color(0.9, 0.88, 0.8))
	for x: float in [-0.12, 0.12]:
		LowPolyBuilder.add_cylinder_between(paint, Vector3(x, 3.56, 2.6), Vector3(x, 3.56, 2.3 - absf(x)), 0.045, 8, METAL)
		LowPolyBuilder.add_cylinder_between(paint, Vector3(x, 3.56, 2.3 - absf(x)), Vector3(x, 3.56, 2.24 - absf(x)), 0.075, 8, METAL)
	# Kraftstofftank zwischen den Drehgestellen
	LowPolyBuilder.add_cylinder_between(paint, Vector3(0.0, 0.7, -1.45), Vector3(0.0, 0.7, 1.45), 0.38, 12, UNDER)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 0.95, 0.0), Vector3(0.12, 0.08, 0.3), METAL)


## Rungenwagen für Holz: Rungen, Querhölzer; die Stammbündel sind Ladung ([constant CARGO]).
static func _build_wagon_timber(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 4.5
	_flat_wagon_base(paint, half, rng)
	for side: float in [-1.0, 1.0]:
		for i in 5:
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 2.05, -3.6 + i * 1.8), Vector3(0.09, 1.5, 0.09), UNDER)
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 2.82, -3.6 + i * 1.8), Vector3(0.12, 0.04, 0.12), SNOW)
	# Querhölzer, auf denen die Bündel liegen
	for z: float in [-3.8, -2.1, -0.85, 0.85, 2.1, 3.8]:
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.31, z), Vector3(2.3, 0.1, 0.16), BARK)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


## Containertragwagen: Boden mit Verriegelungszapfen; die Container sind Ladung.
static func _build_wagon_container(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 4.8
	_flat_wagon_base(paint, half, rng)
	for z_center: float in [-2.2, 2.2]:
		for corner_x: float in [-1.1, 1.1]:
			for corner_z: float in [z_center - 1.95, z_center + 1.95]:
				LowPolyBuilder.add_box(paint, Vector3(corner_x, 1.29, corner_z), Vector3(0.14, 0.06, 0.14), STEP_YELLOW)
	LowPolyBuilder.add_box(paint, Vector3(0.0, 1.27, 0.0), Vector3(2.5, 0.02, 0.2), SNOW)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


## Flachwagen mit niedrigen Bordwänden für Ziegelpaletten.
static func _build_wagon_flat(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 4.8
	_flat_wagon_base(paint, half, rng)
	var board := Color(0.36, 0.43, 0.35)
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(paint, Vector3(side * 1.25, 1.47, 0.0), Vector3(0.06, 0.42, half * 2.0 - 0.1), board)
		LowPolyBuilder.add_box(paint, Vector3(side * 1.26, 1.66, 0.0), Vector3(0.08, 0.05, half * 2.0 - 0.1), board.darkened(0.25))
		# Bordwandscharniere und Rungentaschen
		for i in 7:
			var z := -half + 0.6 + i * ((half * 2.0 - 1.2) / 6.0)
			LowPolyBuilder.add_box(paint, Vector3(side * 1.29, 1.4, z), Vector3(0.04, 0.3, 0.1), UNDER)
		LowPolyBuilder.add_box(paint, Vector3(side * 1.25, 1.69, 0.0), Vector3(0.1, 0.03, half * 2.0 - 0.3), SNOW)
	for end: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.47, end * (half - 0.05)), Vector3(2.5, 0.42, 0.06), board)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


## Rungenwagen für Stahlträger: hohe, rot-weiß gestreifte Rungen, Kanthölzer.
static func _build_wagon_stake(rng: RandomNumberGenerator) -> Dictionary:
	var paint := _new_st()
	var half := 5.1
	_flat_wagon_base(paint, half, rng)
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var z := -half + 0.7 + i * ((half * 2.0 - 1.4) / 5.0)
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 1.85, z), Vector3(0.1, 1.2, 0.1), Color(0.55, 0.16, 0.12))
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 2.3, z), Vector3(0.105, 0.14, 0.105), Color(0.92, 0.9, 0.85))
			LowPolyBuilder.add_box(paint, Vector3(side * 1.22, 2.47, z), Vector3(0.13, 0.04, 0.13), SNOW)
	for z: float in [-4.3, -2.0, -1.0, 1.0, 2.0, 4.3]:
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.31, z), Vector3(2.3, 0.1, 0.14), WOOD_DECK.darkened(0.2))
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
	# Innenwände (sichtbar, sobald die Ladung entladen ist), Auslaufschurren unten
	var inner := body_color.darkened(0.45)
	var z_in := half - 0.36
	for k in profile.size() - 1:
		var a := profile[k]
		var b := profile[k + 1]
		var inward := Vector3(-(a.x + b.x) * 0.5, 2.8 - (a.y + b.y) * 0.5, 0.0)
		LowPolyBuilder.add_quad_facing(paint, Vector3(a.x, a.y, -z_in), Vector3(b.x, b.y, -z_in), Vector3(b.x, b.y, z_in),
			Vector3(a.x, a.y, z_in), inner, inward)
	for end: float in [-1.0, 1.0]:
		for k in range(1, profile.size() - 1):
			LowPolyBuilder.add_triangle_facing(paint, Vector3(profile[0].x, profile[0].y, end * z_in),
				Vector3(profile[k].x, profile[k].y, end * z_in), Vector3(profile[k + 1].x, profile[k + 1].y, end * z_in),
				inner.darkened(0.1), Vector3(0.0, 0.0, -end))
	for z: float in [-1.2, 1.2]:
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.15, z), Vector3(1.1, 0.3, 0.8), body_color.darkened(0.3))
	for end: float in [-1.0, 1.0]:
		_add_buffers(paint, end * half, end)
		LowPolyBuilder.add_box(paint, Vector3(0.0, 1.05, end * (half - 0.05)), Vector3(2.5, 0.3, 0.1), UNDER)
		# Leiter an der Stirnwand und Laufblech oben
		for x: float in [-0.95, -0.55]:
			LowPolyBuilder.add_beam(paint, Vector3(x, 1.3, end * (half - 0.28)), Vector3(x, 3.35, end * (half - 0.28)), 0.03, FRAME)
		for k in 6:
			LowPolyBuilder.add_beam(paint, Vector3(-0.97, 1.5 + k * 0.33, end * (half - 0.28)),
				Vector3(-0.53, 1.5 + k * 0.33, end * (half - 0.28)), 0.025, FRAME)
	# Obergurt: kräftige Kante rund um die Öffnung
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(paint, Vector3(side * 1.37, 3.36, 0.0), Vector3(0.1, 0.08, half * 2.0 - 0.7), body_color.darkened(0.2))
	_wagon_details(paint, half, body_color)
	return {"paint": paint.commit(), "glass": null, "doors": [], "lamps_front": [],
		"lamps_rear": [Vector3(-0.95, 1.3, half + 0.02), Vector3(0.95, 1.3, half + 0.02)]}


# --- Ladung --------------------------------------------------------------------------

## Ein Ladungsstück. Ursprung = Mitte der Unterkante, Länge entlang Z (Ausnahme
## "stone_pile": Ursprung = Wagenmitte auf Schienenoberkante). Wird auch im
## Güterbahnhof für die Lagerbestände benutzt – dort liegen dieselben Stücke.
## Stücke: wood_bundle, brick_pallet, pallet_stack, glass_container, container_empty,
## steel_bundle, stone_pile, stone_scoop, stone_heap.
static func create_cargo(piece: String, variant := 0) -> ArrayMesh:
	var key := "cargo|%s|%d" % [piece, variant]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match piece:
		"wood_bundle":
			_cargo_wood_bundle(st, rng)
		"brick_pallet":
			_cargo_pallet(st, Vector3.ZERO, rng)
			_cargo_bricks(st, rng)
		"pallet_stack":
			for i in 5:
				_cargo_pallet(st, Vector3(rng.randf_range(-0.03, 0.03), i * 0.145, rng.randf_range(-0.04, 0.04)), rng)
			LowPolyBuilder.add_box(st, Vector3(0.0, 0.745, 0.0), Vector3(1.0, 0.04, 1.15), SNOW)
		"glass_container":
			var palette := [Color(0.18, 0.45, 0.48), Color(0.26, 0.36, 0.52), Color(0.55, 0.26, 0.18), Color(0.3, 0.44, 0.34)]
			_cargo_container(st, palette[variant % palette.size()], true)
		"container_empty":
			_cargo_container(st, Color(0.52, 0.5, 0.46), false)
		"steel_bundle":
			_cargo_steel_bundle(st, rng)
		"stone_pile":
			_cargo_stone_pile(st, rng)
		"stone_scoop":
			for i in 5:
				LowPolyBuilder.add_rock(st, rng, Vector3(rng.randf_range(-0.35, 0.35), 0.18 + rng.randf() * 0.2,
					rng.randf_range(-0.3, 0.3)), rng.randf_range(0.22, 0.32), GRAVEL.lerp(Color(0.6, 0.57, 0.52), rng.randf()), GRAVEL)
		"stone_heap":
			_cargo_stone_heap(st, rng)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Bündel aus neun Stämmen (4-3-2) auf zwei Kanthölzern, zwei Spanngurte, Schnee obenauf.
static func _cargo_wood_bundle(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var half := 1.3
	for z: float in [-0.85, 0.85]:
		LowPolyBuilder.add_box(st, Vector3(0.0, 0.05, z), Vector3(2.1, 0.1, 0.14), CARGO_WOOD)
	var rows := [[-0.78, -0.26, 0.26, 0.78], [-0.52, 0.0, 0.52], [-0.26, 0.26]]
	var top := 0.0
	for row_index in rows.size():
		for x: float in rows[row_index]:
			var radius := rng.randf_range(0.24, 0.27)
			var y := 0.1 + 0.26 + row_index * 0.44
			var z0 := -half - rng.randf() * 0.08
			var z1 := half + rng.randf() * 0.08
			var bark := BARK.lerp(Color(0.42, 0.3, 0.2), rng.randf())
			LowPolyBuilder.add_cylinder_between(st, Vector3(x, y, z0), Vector3(x, y, z1), radius, 9, bark)
			for z_end: float in [z0, z1]:
				var out := signf(z_end)
				LowPolyBuilder.add_cylinder_between(st, Vector3(x, y, z_end), Vector3(x, y, z_end + out * 0.015),
					radius * 0.93, 9, LOG_END.lerp(Color(0.9, 0.78, 0.6), rng.randf()))
				LowPolyBuilder.add_cylinder_between(st, Vector3(x, y, z_end + out * 0.015), Vector3(x, y, z_end + out * 0.02),
					radius * 0.45, 7, LOG_END.darkened(0.22))
			top = maxf(top, y + radius)
	# Spanngurte (gelb) über das Bündel
	for z: float in [-0.7, 0.7]:
		LowPolyBuilder.add_box(st, Vector3(0.0, top + 0.01, z), Vector3(0.62, 0.03, 0.08), STEP_YELLOW)
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_beam(st, Vector3(side * 0.3, top + 0.01, z), Vector3(side * 1.06, 0.36, z), 0.04, STEP_YELLOW)
	# Schneehaube, an den Schultern dünner
	LowPolyBuilder.add_box(st, Vector3(0.0, top + 0.03, 0.0), Vector3(0.5, 0.07, half * 2.0 - 0.2), SNOW)
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(side * 0.5, top - 0.14, 0.0), Vector3(0.34, 0.05, half * 2.0 - 0.5), SNOW)


## Europalette: drei Kufen, Klötze, fünf Deckbretter. [param base] = Unterkante Mitte.
static func _cargo_pallet(st: SurfaceTool, base: Vector3, rng: RandomNumberGenerator) -> void:
	var wood := PALLET.lerp(PALLET.darkened(0.2), rng.randf())
	for x: float in [-0.48, 0.0, 0.48]:
		LowPolyBuilder.add_box(st, base + Vector3(x, 0.012, 0.0), Vector3(0.12, 0.024, 1.2), wood.darkened(0.1))
		for z: float in [-0.52, 0.0, 0.52]:
			LowPolyBuilder.add_box(st, base + Vector3(x, 0.064, z), Vector3(0.12, 0.08, 0.14), wood.darkened(0.25))
	for z: float in [-0.52, -0.26, 0.0, 0.26, 0.52]:
		LowPolyBuilder.add_box(st, base + Vector3(0.0, 0.124, z), Vector3(1.08, 0.024, 0.12), wood)


## Ziegelstapel auf der Palette: Lagen mit Fugen, Spannbänder, Schneehaube.
static func _cargo_bricks(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var layers := 7
	var y := 0.136
	for layer in layers:
		var rows := 4
		for row in rows:
			var z := -0.45 + row * 0.3 + (0.075 if layer % 2 == 1 else 0.0)
			var length := 0.28 if (layer % 2 == 0 or row < rows - 1) else 0.14
			for col in 4:
				var x := -0.39 + col * 0.26
				var color := BRICK.lerp(Color(0.78, 0.4, 0.26), rng.randf()).darkened(rng.randf() * 0.12)
				LowPolyBuilder.add_box(st, Vector3(x, y + 0.042, z), Vector3(0.245, 0.078, length - 0.02), color)
		y += 0.09
	# Fugenmörtel innen (verhindert Durchsicht zwischen den Steinen)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.136 + layers * 0.045, 0.02), Vector3(0.98, layers * 0.09 - 0.02, 1.08), Color(0.78, 0.72, 0.64))
	for z: float in [-0.3, 0.3]:
		LowPolyBuilder.add_box(st, Vector3(0.0, y + 0.004, z), Vector3(1.06, 0.012, 0.05), Color(0.2, 0.32, 0.55))
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(st, Vector3(side * 0.53, 0.136 + (y - 0.136) * 0.5, z), Vector3(0.012, y - 0.136, 0.05),
				Color(0.2, 0.32, 0.55))
	LowPolyBuilder.add_box(st, Vector3(0.0, y + 0.03, 0.0), Vector3(0.96, 0.05, 1.12), SNOW)
	LowPolyBuilder.add_box(st, Vector3(0.12, y + 0.07, -0.08), Vector3(0.55, 0.04, 0.7), SNOW)


## 20-Fuß-Container (2,4 × 2,45 × 4,1 m) mit Wellblech, Türen, Eckbeschlägen.
## [param full] = Glas geladen (Plombe und Aufkleber an der Tür).
static func _cargo_container(st: SurfaceTool, color: Color, full: bool) -> void:
	var ribs := color.darkened(0.15)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.225, 0.0), Vector3(2.4, 2.45, 4.1), color)
	for side: float in [-1.0, 1.0]:
		for i in 15:
			LowPolyBuilder.add_box(st, Vector3(side * 1.215, 1.225, -1.85 + i * 0.265), Vector3(0.04, 2.25, 0.1), ribs)
	# Türseite (+Z) mit Verschlussstangen
	for x: float in [-0.8, -0.3, 0.3, 0.8]:
		LowPolyBuilder.add_box(st, Vector3(x, 1.225, 2.06), Vector3(0.05, 2.3, 0.04), METAL)
	if full:
		LowPolyBuilder.add_box(st, Vector3(0.55, 1.3, 2.08), Vector3(0.5, 0.36, 0.01), Color(0.95, 0.93, 0.86))
		LowPolyBuilder.add_box(st, Vector3(0.55, 1.3, 2.085), Vector3(0.3, 0.2, 0.01), Color(0.55, 0.78, 0.88))
	for corner_x: float in [-1.17, 1.17]:
		for corner_y: float in [0.05, 2.4]:
			for corner_z: float in [-2.02, 2.02]:
				LowPolyBuilder.add_box(st, Vector3(corner_x, corner_y, corner_z), Vector3(0.12, 0.1, 0.12), UNDER)
	LowPolyBuilder.add_box(st, Vector3(0.0, 2.47, 0.0), Vector3(2.2, 0.04, 3.8), SNOW)
	LowPolyBuilder.add_box(st, Vector3(-0.3, 2.5, 0.4), Vector3(1.2, 0.04, 2.0), SNOW)


## Sechs Doppel-T-Träger in zwei Lagen, dazwischen Kanthölzer, Schnee obenauf.
static func _cargo_steel_bundle(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var half := 1.4
	var y := 0.0
	for layer in 2:
		for z: float in [-0.9, 0.9]:
			LowPolyBuilder.add_box(st, Vector3(0.0, y + 0.05, z), Vector3(2.0, 0.1, 0.12), CARGO_WOOD)
		y += 0.1
		for x: float in [-0.6, 0.0, 0.6]:
			var tint := STEEL.lerp(Color(0.5, 0.36, 0.28), rng.randf() * 0.35)
			var length := half - rng.randf() * 0.1
			LowPolyBuilder.add_box(st, Vector3(x, y + 0.02, 0.0), Vector3(0.36, 0.04, length * 2.0), tint)
			LowPolyBuilder.add_box(st, Vector3(x, y + 0.2, 0.0), Vector3(0.05, 0.32, length * 2.0), tint.darkened(0.15))
			LowPolyBuilder.add_box(st, Vector3(x, y + 0.38, 0.0), Vector3(0.36, 0.04, length * 2.0), tint.lightened(0.08))
			if layer == 1:
				LowPolyBuilder.add_box(st, Vector3(x + 0.04, y + 0.405, 0.2), Vector3(0.16, 0.012, length * 1.2), SNOW)
		y += 0.4
	for z: float in [-0.5, 0.5]:
		LowPolyBuilder.add_box(st, Vector3(0.0, y + 0.03, z), Vector3(1.9, 0.02, 0.06), STEP_YELLOW)


## Schüttgut im Trichterwagen: unregelmäßige Oberfläche aus Bruchstein mit Schneeflecken.
static func _cargo_stone_pile(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var half := 4.2
	var cells := 8
	for i in cells:
		for j in 3:
			var z0 := -half + 0.45 + i * ((half * 2.0 - 0.9) / cells)
			var z1 := z0 + (half * 2.0 - 0.9) / cells
			var x0 := -1.3 + j * (2.6 / 3.0)
			var x1 := x0 + 2.6 / 3.0
			var top := 3.25 + (0.18 if j == 1 else 0.0) + rng.randf_range(-0.05, 0.05)
			var color := Color(SNOW, 0.75) if rng.randf() < 0.35 else GRAVEL.lerp(Color(0.32, 0.3, 0.28), rng.randf())
			LowPolyBuilder.add_quad_facing(st, Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1),
				Vector3(x0, top, z1), color, Vector3.UP)
	for i in 6:
		LowPolyBuilder.add_rock(st, rng, Vector3(rng.randf_range(-0.9, 0.9), 3.35, rng.randf_range(-3.2, 3.2)),
			rng.randf_range(0.18, 0.28), GRAVEL.lerp(Color(0.55, 0.52, 0.48), rng.randf()), SNOW)
	# Seitenschürze, damit man beim Absenken nicht unter die Oberfläche sieht
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_quad_facing(st, Vector3(side * 1.3, 3.25, -half + 0.45), Vector3(side * 1.3, 3.25, half - 0.45),
			Vector3(side * 1.3, 2.6, half - 0.45), Vector3(side * 1.3, 2.6, -half + 0.45), GRAVEL.darkened(0.2), Vector3(-side, 0, 0))


## Kegelförmiger Steinhaufen fürs Lager (Einheitsgröße, wird skaliert).
static func _cargo_stone_heap(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var rings := [[1.0, 0.0], [0.72, 0.42], [0.4, 0.78], [0.0, 1.0]]
	var segments := 10
	for r in rings.size() - 1:
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var lower_r: float = rings[r][0]
			var upper_r: float = rings[r + 1][0]
			var lower_y: float = rings[r][1]
			var upper_y: float = rings[r + 1][1]
			var p0 := Vector3(cos(a0) * lower_r, lower_y, sin(a0) * lower_r)
			var p1 := Vector3(cos(a1) * lower_r, lower_y, sin(a1) * lower_r)
			var p2 := Vector3(cos(a1) * upper_r, upper_y, sin(a1) * upper_r)
			var p3 := Vector3(cos(a0) * upper_r, upper_y, sin(a0) * upper_r)
			var color := Color(SNOW, 0.75) if r == rings.size() - 2 and rng.randf() < 0.7 else GRAVEL.lerp(Color(0.62, 0.58, 0.53), rng.randf())
			var outward := Vector3(cos((a0 + a1) * 0.5), 0.6, sin((a0 + a1) * 0.5))
			LowPolyBuilder.add_triangle_facing(st, p0, p1, p2, color, outward)
			if upper_r > 0.0:
				LowPolyBuilder.add_triangle_facing(st, p0, p2, p3, color, outward)
	for i in 5:
		var a := rng.randf() * TAU
		LowPolyBuilder.add_rock(st, rng, Vector3(cos(a) * 0.8, 0.12, sin(a) * 0.8), rng.randf_range(0.1, 0.16),
			GRAVEL.lerp(Color(0.6, 0.57, 0.52), rng.randf()), SNOW)


# --- Drehgestelle --------------------------------------------------------------------

## Drehgestellrahmen (ohne Radsätze). Ursprung = Mitte auf Schienenoberkante.
##
## Etappe 9.5: geformte Seitenrahmen (hoch über den Achsen, tief in der Mitte),
## Achslager mit Deckeln, je zwei Schraubenfedern (Primärfederung), Luftfeder
## unter dem Wagenkasten (Sekundärfederung), Querträger, Dämpfer und Bremsen.
static func create_bogie(wheel_base: float) -> ArrayMesh:
	var key := "bogie|%f" % wheel_base
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var half := wheel_base * 0.5
	var spring := METAL.darkened(0.15)
	for side: float in [-1.0, 1.0]:
		var x := side * 0.98
		# Seitenrahmen: über den Achsen hoch, in der Mitte zur Luftfeder abgesenkt
		var ends := half + 0.38
		var profile: Array[Vector3] = [Vector3(x, 0.6, -ends), Vector3(x, 0.62, -half + 0.18), Vector3(x, 0.47, -half * 0.35),
			Vector3(x, 0.47, half * 0.35), Vector3(x, 0.62, half - 0.18), Vector3(x, 0.6, ends)]
		for i in profile.size() - 1:
			var a := profile[i]
			var b := profile[i + 1]
			var dir := (b - a).normalized()
			LowPolyBuilder.add_oriented_box(st, Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * 0.5),
				Vector3(0.13, 0.22, a.distance_to(b) + 0.06), FRAME)
		# Obergurt über der Mitte (Aufnahme der Luftfeder)
		LowPolyBuilder.add_box(st, Vector3(x, 0.6, 0.0), Vector3(0.16, 0.06, half * 0.9), FRAME.lightened(0.05))
		for axle: float in [-1.0, 1.0]:
			var z := axle * half
			# Achslager mit rundem Deckel
			LowPolyBuilder.add_box(st, Vector3(x, WHEEL_RADIUS, z), Vector3(0.2, 0.24, 0.32), UNDER)
			LowPolyBuilder.add_cylinder_between(st, Vector3(x + side * 0.1, WHEEL_RADIUS, z),
				Vector3(x + side * 0.16, WHEEL_RADIUS, z), 0.1, 10, METAL)
			LowPolyBuilder.add_cylinder_between(st, Vector3(x + side * 0.16, WHEEL_RADIUS, z),
				Vector3(x + side * 0.175, WHEEL_RADIUS, z), 0.045, 8, METAL.lightened(0.2))
			# Zwei Schraubenfedern zwischen Achslager und Rahmen
			for offset: float in [-0.1, 0.1]:
				var base := Vector3(x, WHEEL_RADIUS + 0.12, z + offset)
				LowPolyBuilder.add_cylinder(st, base, 0.055, 0.055, 0.12, 8, spring)
				for ring in 3:
					LowPolyBuilder.add_cylinder(st, base + Vector3(0.0, 0.02 + ring * 0.04, 0.0), 0.062, 0.062, 0.012, 8,
						spring.darkened(0.25))
			# Bremseinheit zwischen Rahmen und Rad
			LowPolyBuilder.add_box(st, Vector3(side * 0.74, 0.55, z - axle * 0.46), Vector3(0.12, 0.16, 0.14), UNDER)
			LowPolyBuilder.add_box(st, Vector3(side * 0.74, WHEEL_RADIUS, z - axle * 0.43), Vector3(0.1, 0.22, 0.05), METAL.darkened(0.3))
		# Luftfeder (Gummibalg) und Dämpfer
		LowPolyBuilder.add_cylinder(st, Vector3(x * 0.92, 0.63, 0.0), 0.16, 0.18, 0.14, 12, RUBBER)
		LowPolyBuilder.add_cylinder(st, Vector3(x * 0.92, 0.77, 0.0), 0.2, 0.2, 0.03, 12, FRAME)
		LowPolyBuilder.add_cylinder_between(st, Vector3(side * 1.08, 0.52, -half * 0.45), Vector3(side * 1.08, 0.66, half * 0.1),
			0.035, 6, METAL.darkened(0.1))
	# Querträger und Mittelzapfen
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.5, 0.0), Vector3(1.9, 0.18, 0.46), FRAME)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.59, 0.0), 0.16, 0.16, 0.2, 10, UNDER)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Radsatz: Räder mit Spurkranz, Radscheibe und Nabe, Achse mit Bremsscheiben.
## Drei Löcher in der Radscheibe zeigen, dass sich das Rad dreht.
## Ursprung = Achsmitte; dreht sich um X.
static func create_wheelset() -> ArrayMesh:
	if _cache.has("wheelset"):
		return _cache["wheelset"]
	var st := _new_st()
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.9, 0.0, 0.0), Vector3(0.9, 0.0, 0.0), 0.075, 10, METAL)
	for x: float in [-0.3, 0.3]:
		LowPolyBuilder.add_cylinder_between(st, Vector3(x - 0.02, 0.0, 0.0), Vector3(x + 0.02, 0.0, 0.0), 0.28, 14,
			METAL.darkened(0.2))
	for side: float in [-1.0, 1.0]:
		var inner := side * 0.68
		var outer := side * 0.8
		# Lauffläche (blank), Radscheibe (dunkel), Spurkranz innen
		LowPolyBuilder.add_cylinder_between(st, Vector3(inner, 0.0, 0.0), Vector3(outer, 0.0, 0.0), WHEEL_RADIUS, 16,
			METAL.lightened(0.1))
		LowPolyBuilder.add_cylinder_between(st, Vector3(outer - side * 0.01, 0.0, 0.0), Vector3(outer + side * 0.004, 0.0, 0.0),
			WHEEL_RADIUS - 0.05, 16, UNDER)
		LowPolyBuilder.add_cylinder_between(st, Vector3(inner - side * 0.03, 0.0, 0.0), Vector3(inner, 0.0, 0.0),
			WHEEL_RADIUS + 0.035, 16, METAL)
		# Nabe und drei Löcher in der Radscheibe
		LowPolyBuilder.add_cylinder_between(st, Vector3(outer, 0.0, 0.0), Vector3(outer + side * 0.04, 0.0, 0.0), 0.11, 10,
			METAL.darkened(0.1))
		for k in 3:
			var angle := TAU * k / 3.0
			var hole := Vector3(outer + side * 0.006, cos(angle) * 0.22, sin(angle) * 0.22)
			LowPolyBuilder.add_cylinder_between(st, hole, hole + Vector3(side * 0.004, 0.0, 0.0), 0.045, 8,
				Color(0.06, 0.06, 0.07))
	var mesh := st.commit()
	_cache["wheelset"] = mesh
	return mesh


# --- Trittstufen ---------------------------------------------------------------------

## Obere Stufe der ausfahrbaren Trittstufe (gebaut für die Seite +X, die Gegenseite
## wird um 180° gedreht). Ursprung = Stufenmitte in Längsrichtung, eingefahren.
static func create_step_upper() -> ArrayMesh:
	if _cache.has("step_upper"):
		return _cache["step_upper"]
	var st := _new_st()
	_step_tread(st, Vector3(0.0, STEP_UPPER_Y, 0.0))
	# Seitenwangen und Führungsschiene darunter
	for z: float in [-STEP_WIDTH * 0.5 + 0.02, STEP_WIDTH * 0.5 - 0.02]:
		LowPolyBuilder.add_box(st, Vector3(0.0, STEP_UPPER_Y - 0.08, z), Vector3(STEP_DEPTH, 0.12, 0.03), FRAME)
	LowPolyBuilder.add_box(st, Vector3(-0.05, STEP_UPPER_Y - 0.13, 0.0), Vector3(0.2, 0.04, STEP_WIDTH - 0.1), UNDER)
	var mesh := st.commit()
	_cache["step_upper"] = mesh
	return mesh


## Untere, klappbare Stufe mit Wangen. Ursprung = Scharnier an der Vorderkante der oberen Stufe.
static func create_step_lower() -> ArrayMesh:
	if _cache.has("step_lower"):
		return _cache["step_lower"]
	var st := _new_st()
	for z: float in [-STEP_WIDTH * 0.5 + 0.02, STEP_WIDTH * 0.5 - 0.02]:
		LowPolyBuilder.add_beam(st, Vector3(-0.02, -0.01, z), Vector3(STEP_LOWER_OFFSET.x + STEP_DEPTH * 0.45, STEP_LOWER_OFFSET.y - 0.05, z),
			0.035, FRAME)
	_step_tread(st, Vector3(STEP_LOWER_OFFSET.x, STEP_LOWER_OFFSET.y, 0.0))
	var mesh := st.commit()
	_cache["step_lower"] = mesh
	return mesh


## Eine Stufe: Riffelblech mit gelber Sicherheitskante vorne. [param top] = Mitte der Oberkante.
static func _step_tread(st: SurfaceTool, top: Vector3) -> void:
	LowPolyBuilder.add_box(st, top - Vector3(0.0, 0.0225, 0.0), Vector3(STEP_DEPTH, 0.045, STEP_WIDTH), METAL)
	for i in 5:
		var x := -STEP_DEPTH * 0.5 + 0.05 + i * 0.055
		LowPolyBuilder.add_box(st, top + Vector3(x, 0.005, 0.0), Vector3(0.018, 0.01, STEP_WIDTH - 0.1), METAL.darkened(0.3))
	LowPolyBuilder.add_box(st, top + Vector3(STEP_DEPTH * 0.5 - 0.025, -0.02, 0.0), Vector3(0.05, 0.05, STEP_WIDTH), STEP_YELLOW)


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


## Ausrüstung eines Güterwagens: Rangiertritte und Griffe an allen Ecken, Handbremsrad
## an einem Ende, Bremszylinder und Luftbehälter unter dem Rahmen, Bremsschläuche.
static func _wagon_details(st: SurfaceTool, half: float, color: Color) -> void:
	for end: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			# Rangiertritt (gelb) und senkrechter Griff
			var corner := Vector3(side * 1.25, 0.0, end * (half - 0.35))
			LowPolyBuilder.add_box(st, corner + Vector3(0.0, 0.62, 0.0), Vector3(0.3, 0.035, 0.32), STEP_YELLOW)
			LowPolyBuilder.add_beam(st, corner + Vector3(side * 0.05, 0.64, -end * 0.12), corner + Vector3(side * 0.05, 0.9, -end * 0.12),
				0.03, FRAME)
			LowPolyBuilder.add_beam(st, corner + Vector3(side * 0.07, 1.25, end * 0.1), corner + Vector3(side * 0.07, 1.75, end * 0.1),
				0.03, STEP_YELLOW)
		# Bremsschlauch neben dem Kupplungshaken
		LowPolyBuilder.add_cylinder_between(st, Vector3(0.3, 0.95, end * (half + 0.02)), Vector3(0.36, 0.7, end * (half + 0.2)),
			0.03, 5, RUBBER)
	# Handbremsrad an der Stirnseite (+Z)
	var wheel_center := Vector3(-0.85, 1.55, half + 0.07)
	LowPolyBuilder.add_cylinder_between(st, wheel_center, wheel_center + Vector3(0.0, 0.0, 0.03), 0.24, 12, FRAME)
	LowPolyBuilder.add_cylinder_between(st, wheel_center + Vector3(0.0, 0.0, -0.005), wheel_center + Vector3(0.0, 0.0, 0.035), 0.19,
		12, color.darkened(0.35))
	for k in 3:
		var angle := TAU * k / 3.0
		LowPolyBuilder.add_beam(st, wheel_center + Vector3(0.0, 0.0, 0.04), wheel_center + Vector3(cos(angle) * 0.2, sin(angle) * 0.2, 0.04),
			0.025, FRAME)
	LowPolyBuilder.add_beam(st, wheel_center + Vector3(0.0, -0.1, 0.0), Vector3(-0.85, 1.05, half - 0.02), 0.05, FRAME)
	# Bremszylinder und Luftbehälter unter dem Rahmen
	LowPolyBuilder.add_cylinder_between(st, Vector3(0.35, 0.76, -0.9), Vector3(0.35, 0.76, 0.1), 0.17, 10, UNDER)
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.35, 0.8, 0.3), Vector3(-0.35, 0.8, 0.8), 0.13, 8, UNDER.lightened(0.05))
	LowPolyBuilder.add_beam(st, Vector3(0.35, 0.76, 0.1), Vector3(0.35, 0.76, 1.6), 0.04, METAL)


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


## Flachwagen-Unterbau: lackierte Langträger mit Rippen, Holzboden, Puffer und
## die Ausrüstung eines echten Güterwagens (siehe [method _wagon_details]).
static func _flat_wagon_base(st: SurfaceTool, half: float, rng: RandomNumberGenerator) -> void:
	var sill: Color = WAGON_COLORS[rng.randi() % WAGON_COLORS.size()]
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(side * 1.18, 0.98, 0.0), Vector3(0.18, 0.34, half * 2.0), UNDER)
		# Außenlangträger in Wagenfarbe mit senkrechten Rippen
		LowPolyBuilder.add_box(st, Vector3(side * 1.285, 1.06, 0.0), Vector3(0.04, 0.3, half * 2.0 - 0.1), sill)
		var ribs := int(half * 2.0 / 0.9)
		for i in ribs + 1:
			var z := -half + 0.1 + i * ((half * 2.0 - 0.2) / ribs)
			LowPolyBuilder.add_box(st, Vector3(side * 1.31, 1.06, z), Vector3(0.025, 0.3, 0.06), sill.darkened(0.2))
	_wagon_details(st, half, sill)
	var planks := int(half * 2.0 / 0.5)
	for i in planks:
		var z := -half + 0.25 + i * 0.5
		LowPolyBuilder.add_box(st, Vector3(0.0, 1.2, z), Vector3(2.55, 0.12, 0.48), WOOD_DECK.lerp(WOOD_DECK.darkened(0.2), rng.randf()))
	for end: float in [-1.0, 1.0]:
		_add_buffers(st, end * half, end)
