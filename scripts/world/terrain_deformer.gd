@tool
## Formt das Gelände entlang von Gleisen ("Gleiskorridore").
##
## Jeder Korridor ist eine Folge von Achspunkten (x, Gleishöhe, z). Im Kern
## des Korridors wird das Gelände auf Gleishöhe eingeebnet, daneben läuft es
## über eine Böschung (Neigung 1:2) weich in das natürliche Gelände aus.
## Wo sich Korridore überlagern, gewinnt der stärkere Einfluss (bei Gleich-
## stand das nähere Gleis) – so behält jedes Gleis sein eigenes Planum.
##
## Die Korridore werden nie gespeichert, sondern immer aus dem Gleisnetz
## abgeleitet – dadurch stimmt das Gelände nach Laden, Entfernen und Undo
## automatisch.
class_name TerrainDeformer
extends RefCounted

## Halbe Breite des eingeebneten Streifens (etwas breiter als das Schotterbett).
const CORE_HALF_WIDTH := 2.8
## Das Gelände liegt knapp unter der Gleisachse, damit das Schotterbett aufliegt.
const GROUND_OFFSET := 0.05
## Böschungsbreite je Meter Höhenunterschied (2 = Neigung 1:2).
const SLOPE_RATIO := 2.0
const MIN_SLOPE_WIDTH := 1.5
const MAX_SLOPE_WIDTH := 10.0
## Weiter reicht kein Korridor ins Gelände hinein.
const MAX_INFLUENCE := CORE_HALF_WIDTH + MAX_SLOPE_WIDTH
## Rastergröße für die schnelle Suche nach nahen Korridor-Abschnitten.
const CELL := 8.0

var _corridors: Dictionary[int, PackedVector3Array] = {}
var _corridor_cells: Dictionary[int, Array] = {}
var _corridor_bounds: Dictionary[int, Rect2] = {}
## Rasterzelle → Liste von Vector2i(Korridor-ID, Abschnitts-Index)
var _cells: Dictionary[Vector2i, Array] = {}
## Exact rotated station footprints, including a soft bank outside the floor.
var _pads: Dictionary[int, Dictionary] = {}
var _pad_cells: Dictionary[Vector2i, Array] = {}


func has_corridors() -> bool:
	return not _corridors.is_empty() or not _pads.is_empty()

func set_pad(id: int, footprint: Dictionary, ground_y: float, bank := 4.0) -> Rect2:
	var previous := remove_pad(id)
	# Start from the first corner explicitly: a zero-size rectangle is valid.
	var corners := VillageFootprint.corners(footprint,bank)
	var bounds := Rect2(corners[0],Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	_pads[id] = {"footprint":footprint,"y":ground_y,"bank":bank,"bounds":bounds}
	for cx in range(floori(bounds.position.x/CELL),floori(bounds.end.x/CELL)+1):
		for cz in range(floori(bounds.position.y/CELL),floori(bounds.end.y/CELL)+1):
			var cell := Vector2i(cx,cz)
			if not _pad_cells.has(cell):
				_pad_cells[cell] = []
			_pad_cells[cell].append(id)
	return bounds if previous.size==Vector2.ZERO else previous.merge(bounds)

func remove_pad(id: int) -> Rect2:
	if not _pads.has(id):
		return Rect2()
	var bounds: Rect2 = _pads[id]["bounds"]
	for cx in range(floori(bounds.position.x/CELL),floori(bounds.end.x/CELL)+1):
		for cz in range(floori(bounds.position.y/CELL),floori(bounds.end.y/CELL)+1):
			var cell := Vector2i(cx,cz)
			if _pad_cells.has(cell):
				_pad_cells[cell].erase(id)
				if _pad_cells[cell].is_empty():
					_pad_cells.erase(cell)
	_pads.erase(id)
	return bounds

func _sample_pads(x: float, z: float, base: float) -> Vector2:
	var entries: Array = _pad_cells.get(Vector2i(floori(x/CELL),floori(z/CELL)),[])
	var best := 0.0
	var height := base
	var nearest := INF
	for id: int in entries:
		var pad: Dictionary = _pads[id]
		var fp: Dictionary = pad["footprint"]
		var local := (Vector2(x,z)-(fp["center"] as Vector2)).rotated(float(fp["angle"]))
		var excess := local.abs()-(fp["half"] as Vector2)
		var distance := Vector2(maxf(0,excess.x),maxf(0,excess.y)).length()
		var weight := 1.0-smoothstep(0,float(pad["bank"]),distance)
		if weight>best+0.0001 or (weight>0 and is_equal_approx(weight,best) and local.length_squared()<nearest):
			best = weight
			nearest = local.length_squared()
			height = float(pad["y"])
	return Vector2(lerpf(base,height,best),best)


func has_corridor(id: int) -> bool:
	return _corridors.has(id)


## Setzt oder ersetzt einen Korridor. Gibt den Bereich zurück, dessen Höhen
## sich dadurch ändern können.
func set_corridor(id: int, points: PackedVector3Array) -> Rect2:
	var region := remove_corridor(id)
	if points.size() < 2:
		return region
	_corridors[id] = points
	var cells: Array[Vector2i] = []
	var bounds := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var rect := Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z)).grow(MAX_INFLUENCE)
		bounds = bounds.merge(rect)
		for cx in range(floori(rect.position.x / CELL), floori(rect.end.x / CELL) + 1):
			for cz in range(floori(rect.position.y / CELL), floori(rect.end.y / CELL) + 1):
				var cell := Vector2i(cx, cz)
				if not _cells.has(cell):
					_cells[cell] = []
				_cells[cell].append(Vector2i(id, i))
				cells.append(cell)
	_corridor_cells[id] = cells
	_corridor_bounds[id] = bounds
	return bounds if region.size == Vector2.ZERO else region.merge(bounds)


func remove_corridor(id: int) -> Rect2:
	if not _corridors.has(id):
		return Rect2()
	for cell: Vector2i in _corridor_cells[id]:
		var entries: Array = _cells.get(cell, [])
		for i in range(entries.size() - 1, -1, -1):
			if (entries[i] as Vector2i).x == id:
				entries.remove_at(i)
		if entries.is_empty():
			_cells.erase(cell)
	var bounds := _corridor_bounds[id]
	_corridors.erase(id)
	_corridor_cells.erase(id)
	_corridor_bounds.erase(id)
	return bounds


## Angepasste Höhe an (x, z). [param base] ist die natürliche Geländehöhe.
## Rückgabe: Vector2(Höhe, Einfluss 0..1).
func sample(x: float, z: float, base: float) -> Vector2:
	var pad := _sample_pads(x,z,base)
	base = pad.x
	var entries: Array = _cells.get(Vector2i(floori(x / CELL), floori(z / CELL)), [])
	if entries.is_empty():
		return pad

	var point := Vector2(x, z)
	var best_weight := 0.0
	var best_distance := INF
	var best_height := base
	for entry: Vector2i in entries:
		var points := _corridors[entry.x]
		var a := points[entry.y]
		var b := points[entry.y + 1]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		var length_sq := ab.length_squared()
		var t := clampf((point - a2).dot(ab) / length_sq, 0.0, 1.0) if length_sq > 0.000001 else 0.0
		var distance := point.distance_to(a2 + ab * t)
		if distance >= MAX_INFLUENCE:
			continue
		var target := lerpf(a.y, b.y, t) - GROUND_OFFSET
		var slope_width := clampf(absf(base - target) * SLOPE_RATIO, MIN_SLOPE_WIDTH, MAX_SLOPE_WIDTH)
		var weight := 1.0 - smoothstep(CORE_HALF_WIDTH, CORE_HALF_WIDTH + slope_width, distance)
		# Stärkster Einfluss gewinnt; bei Gleichstand (z.B. im Gleiskern) der nächste Achsabschnitt.
		if weight > best_weight + 0.0001 or (weight > 0.0 and absf(weight - best_weight) <= 0.0001
				and distance < best_distance):
			best_weight = weight
			best_distance = distance
			best_height = target
	return Vector2(lerpf(base, best_height, best_weight), maxf(best_weight,pad.y))
