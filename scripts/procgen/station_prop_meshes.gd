@tool
## Kleine Bahnhofsdetails im Low-Poly-Stil: Bank, Mülleimer, Blumenkasten,
## Wegweiser, Fahrplanaushang und Bohlenübergang.
##
## Alle Funktionen schreiben in einen SurfaceTool (flach schattiert, Vertexfarben)
## und arbeiten lokal: Ursprung = Boden, -Z = Vorderseite.
class_name StationPropMeshes
extends RefCounted

const WOOD := Color(0.62, 0.40, 0.24)
const WOOD_DARK := Color(0.44, 0.28, 0.17)
const IRON := Color(0.16, 0.17, 0.19)
const GREEN_METAL := Color(0.22, 0.34, 0.28)
const SNOW := Color(0.9, 0.93, 0.97)
const NEEDLES := Color(0.16, 0.34, 0.26)
const NEEDLES_LIGHT := Color(0.24, 0.44, 0.3)
const BERRY := Color(0.78, 0.12, 0.12)
const PETAL := Color(0.97, 0.94, 0.88)
const PETAL_CENTER := Color(0.95, 0.78, 0.3)
const POSTER := Color(0.96, 0.84, 0.36)
const SIGN_BOARD := Color(0.95, 0.9, 0.8)

## Sitzhöhe und Sitzplätze der Bank (lokal) – für die Bewohner.
const BENCH_SEAT_HEIGHT := 0.46
const BENCH_SEATS: Array[float] = [-0.42, 0.42]
## Länge einer Rampe am Bohlenübergang.
const CROSSING_RAMP_LENGTH := 1.62


## Parkbank mit gusseisernen Seitenteilen und warmen Holzlatten.
## Man sitzt mit Blick nach -Z, die Lehne steht bei +Z.
static func add_bench(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var half := 0.85
	for x: float in [-half + 0.08, half - 0.08]:
		# Seitenteil: Vorder- und Hinterbein, Armlehne mit rundem Knauf
		LowPolyBuilder.add_beam(st, Vector3(x, 0.0, -0.2), Vector3(x, 0.44, -0.16), 0.06, IRON)
		LowPolyBuilder.add_beam(st, Vector3(x, 0.0, 0.24), Vector3(x, 0.44, 0.18), 0.06, IRON)
		LowPolyBuilder.add_beam(st, Vector3(x, 0.44, 0.2), Vector3(x, 0.9, 0.3), 0.055, IRON)
		LowPolyBuilder.add_box(st, Vector3(x, 0.44, 0.02), Vector3(0.06, 0.05, 0.44), IRON)
		LowPolyBuilder.add_beam(st, Vector3(x, 0.44, -0.18), Vector3(x, 0.64, -0.2), 0.05, IRON)
		LowPolyBuilder.add_box(st, Vector3(x, 0.66, 0.02), Vector3(0.07, 0.05, 0.46), IRON)
		LowPolyBuilder.add_cylinder(st, Vector3(x, 0.61, -0.23), 0.04, 0.04, 0.08, 6, IRON)
		LowPolyBuilder.add_box(st, Vector3(x, 0.695, 0.02), Vector3(0.08, 0.02, 0.42), SNOW)
	# Sitzlatten
	for i in 4:
		var z := -0.17 + i * 0.12
		LowPolyBuilder.add_box(st, Vector3(0.0, BENCH_SEAT_HEIGHT - 0.02, z), Vector3(half * 2.0, 0.04, 0.1),
			_vary(WOOD, rng, 0.04))
	# Lehnenlatten, leicht nach hinten geneigt
	var lean := Basis(Vector3.RIGHT, -0.2)
	for i in 3:
		var center := Vector3(0.0, 0.6 + i * 0.12, 0.22 + i * 0.024)
		LowPolyBuilder.add_oriented_box(st, Transform3D(lean, center), Vector3(half * 2.0 - 0.1, 0.09, 0.04),
			_vary(WOOD, rng, 0.04))
	LowPolyBuilder.add_oriented_box(st, Transform3D(lean, Vector3(0.0, 0.905, 0.29)), Vector3(half * 2.0 - 0.14, 0.03, 0.07), SNOW)


## Runder Mülleimer aus grünem Blech an einem Pfosten, mit Schneehaube.
static func add_bin(st: SurfaceTool) -> void:
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.45, 0.2), Vector3(0.08, 0.9, 0.08), IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.25, 0.0), 0.2, 0.23, 0.55, 10, GREEN_METAL)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.78, 0.0), 0.245, 0.245, 0.04, 10, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.25, 0.0), 0.215, 0.215, 0.04, 10, IRON)
	for i in 5:
		var angle := TAU * i / 5.0
		var p := Vector3(cos(angle) * 0.225, 0.52, sin(angle) * 0.225)
		LowPolyBuilder.add_box(st, p, Vector3(0.025, 0.46, 0.025), GREEN_METAL.lightened(0.08))
	LowPolyBuilder.add_cone(st, Vector3(0.0, 0.8, 0.0), 0.24, 0.1, 10, SNOW)


## Hölzerner Blumenkasten mit Tannengrün, roten Beeren und Christrosen.
static func add_flower_box(st: SurfaceTool, rng: RandomNumberGenerator, length := 1.2) -> void:
	var half := length * 0.5
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.2, 0.0), Vector3(length, 0.4, 0.42), WOOD_DARK)
	for i in 3:
		LowPolyBuilder.add_box(st, Vector3(0.0, 0.07 + i * 0.13, -0.215), Vector3(length + 0.02, 0.1, 0.02),
			_vary(WOOD, rng, 0.05))
		LowPolyBuilder.add_box(st, Vector3(0.0, 0.07 + i * 0.13, 0.215), Vector3(length + 0.02, 0.1, 0.02),
			_vary(WOOD, rng, 0.05))
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.41, 0.0), Vector3(length + 0.06, 0.04, 0.48), WOOD)
	# Üppiges Tannengrün: runde Büschel, dazwischen spitze Zweige und etwas Schnee
	var clumps := maxi(3, int(length * 3.0))
	for i in clumps:
		var x := lerpf(-half + 0.2, half - 0.2, (i + 0.5) / clumps) + rng.randf_range(-0.05, 0.05)
		LowPolyBuilder.add_rock(st, rng, Vector3(x, 0.46, rng.randf_range(-0.04, 0.04)), rng.randf_range(0.2, 0.25),
			NEEDLES.lerp(NEEDLES_LIGHT, rng.randf() * 0.4), NEEDLES_LIGHT)
	for i in int(length * 14.0):
		var base := Vector3(rng.randf_range(-half + 0.08, half - 0.08), 0.42, rng.randf_range(-0.16, 0.16))
		var color := NEEDLES.lerp(NEEDLES_LIGHT, rng.randf())
		LowPolyBuilder.add_cone(st, base, rng.randf_range(0.07, 0.1), rng.randf_range(0.26, 0.4), 5, color,
			rng.randf() * TAU, false)
	for i in int(length * 4.0):
		var top := Vector3(rng.randf_range(-half + 0.15, half - 0.15), rng.randf_range(0.6, 0.64), rng.randf_range(-0.08, 0.08))
		LowPolyBuilder.add_cone(st, top, rng.randf_range(0.07, 0.1), 0.05, 6, SNOW, rng.randf() * TAU, false)
	# Beeren und Christrosen
	for i in int(length * 12.0):
		var p := Vector3(rng.randf_range(-half + 0.08, half - 0.08), rng.randf_range(0.55, 0.7), rng.randf_range(-0.19, 0.19))
		LowPolyBuilder.add_box(st, p, Vector3.ONE * 0.04, BERRY)
	for i in int(length * 4.0):
		var p := Vector3(rng.randf_range(-half + 0.12, half - 0.12), rng.randf_range(0.66, 0.72), rng.randf_range(-0.14, 0.14))
		for k in 5:
			var angle := TAU * k / 5.0 + rng.randf() * 0.3
			var petal := p + Vector3(cos(angle) * 0.045, 0.0, sin(angle) * 0.045)
			LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, -angle), petal), Vector3(0.06, 0.012, 0.04), PETAL)
		LowPolyBuilder.add_box(st, p + Vector3(0.0, 0.01, 0.0), Vector3.ONE * 0.03, PETAL_CENTER)


## Wegweiser: Holzpfosten mit Richtungsschildern. [param arrows] = [[Winkel in Grad, Höhe, Breite], …].
## Gibt für jedes Schild die Mitte und Ausrichtung zurück (für die Beschriftung).
static func add_signpost(st: SurfaceTool, arrows: Array) -> Array[Transform3D]:
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.1, 0.0), Vector3(0.11, 2.2, 0.11), WOOD_DARK)
	LowPolyBuilder.add_cone(st, Vector3(0.0, 2.2, 0.0), 0.1, 0.12, 4, WOOD_DARK, PI * 0.25)
	LowPolyBuilder.add_cone(st, Vector3(0.0, 2.24, 0.0), 0.07, 0.08, 4, SNOW, PI * 0.25)
	var boards: Array[Transform3D] = []
	for arrow: Array in arrows:
		var yaw := deg_to_rad(float(arrow[0]))
		var height := float(arrow[1])
		var width := float(arrow[2]) if arrow.size() > 2 else 0.78
		var basis := Basis(Vector3.UP, yaw)
		var center := basis * Vector3(width * 0.5 + 0.03, height, 0.0)
		var xform := Transform3D(basis, center)
		LowPolyBuilder.add_oriented_box(st, xform, Vector3(width, 0.2, 0.035), SIGN_BOARD)
		LowPolyBuilder.add_oriented_box(st, xform.translated_local(Vector3(0.0, 0.0, 0.0)), Vector3(width + 0.04, 0.24, 0.02), WOOD)
		# Pfeilspitze
		var tip := xform.translated_local(Vector3(width * 0.5 + 0.04, 0.0, 0.0))
		LowPolyBuilder.add_oriented_box(st, tip * Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3.ZERO),
			Vector3(0.16, 0.16, 0.03), WOOD)
		LowPolyBuilder.add_oriented_box(st, xform.translated_local(Vector3(0.0, 0.13, 0.0)), Vector3(width + 0.02, 0.03, 0.06), SNOW)
		boards.append(xform)
	return boards


## Aushangfahrplan: gelbes Plakat in einem Holzkasten auf zwei Pfosten.
## Das Plakat zeigt nach -Z; Rückgabe: Mitte der Plakatfläche.
static func add_timetable_case(st: SurfaceTool) -> Vector3:
	for x: float in [-0.5, 0.5]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.9, 0.0), Vector3(0.08, 1.8, 0.08), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.35, 0.03), Vector3(1.0, 1.1, 0.07), WOOD)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.35, -0.01), Vector3(0.88, 0.98, 0.02), POSTER)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.93, 0.0), Vector3(1.12, 0.06, 0.2), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.97, 0.0), Vector3(1.1, 0.03, 0.18), SNOW)
	return Vector3(0.0, 1.35, -0.025)


## Bohlenübergang über ein Gleis (Gleis entlang Z, man geht entlang X).
static func add_crossing(st: SurfaceTool, rng: RandomNumberGenerator, width := 1.8) -> void:
	var top := RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT
	var gauge := RailConfig.RAIL_OFFSET - 0.06
	for section: Array in [[-1.9, -RailConfig.RAIL_OFFSET - 0.06], [-gauge, gauge], [RailConfig.RAIL_OFFSET + 0.06, 1.9]]:
		var x0 := float(section[0])
		var x1 := float(section[1])
		var planks := int(width / 0.3)
		for i in planks:
			var z := -width * 0.5 + (i + 0.5) * width / planks
			var height := top - 0.01
			LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, height - 0.05, z), Vector3(x1 - x0, 0.1, width / planks - 0.03),
				_vary(WOOD_DARK, rng, 0.05))
	# Rampen an beiden Enden zum Boden
	for side: float in [-1.0, 1.0]:
		var ramp := crossing_ramp(side)
		LowPolyBuilder.add_oriented_box(st, ramp, Vector3(CROSSING_RAMP_LENGTH, 0.08, width), _vary(WOOD_DARK, rng, 0.03))


## Gepäckstapel: liegender Koffer, stehender Koffer, Reisetasche, Rucksack und
## eine Einkaufstasche mit Baguette – leicht verschneit.
static func add_luggage(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.55, 0.33, 0.22), Color(0.3, 0.46, 0.44), Color(0.68, 0.24, 0.2), Color(0.8, 0.62, 0.34)]
	var big: Color = colors[rng.randi() % colors.size()]
	# Großer Koffer, liegend
	_suitcase(st, Transform3D(Basis(Vector3.UP, 0.1), Vector3(0.0, 0.11, 0.0)), Vector3(0.62, 0.22, 0.42), big)
	# Kleiner Koffer darauf, schräg
	var small: Color = colors[(colors.find(big) + 1 + rng.randi() % 3) % colors.size()]
	_suitcase(st, Transform3D(Basis(Vector3.UP, -0.35), Vector3(0.05, 0.31, -0.02)), Vector3(0.42, 0.18, 0.3), small)
	# Stehender Koffer daneben mit Griff
	var stand: Color = colors[(colors.find(big) + 2) % colors.size()]
	_suitcase(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.25), Vector3(0.52, 0.26, 0.08)),
		Vector3(0.36, 0.14, 0.5), stand)
	# Reisetasche (Seesack) davor
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.2, 0.12, 0.34), Vector3(0.28, 0.12, 0.38), 0.12, 8, Color(0.3, 0.36, 0.48))
	LowPolyBuilder.add_beam(st, Vector3(-0.05, 0.25, 0.35), Vector3(0.14, 0.25, 0.36), 0.025, Color(0.2, 0.16, 0.12))
	# Einkaufstasche mit Baguette
	LowPolyBuilder.add_box(st, Vector3(-0.48, 0.14, 0.12), Vector3(0.22, 0.28, 0.14), Color(0.78, 0.62, 0.42))
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.46, 0.2, 0.08), Vector3(-0.42, 0.46, 0.16), 0.03, 6, Color(0.86, 0.62, 0.32))
	# Etwas Schnee obenauf
	LowPolyBuilder.add_box(st, Vector3(0.05, 0.405, -0.02), Vector3(0.3, 0.012, 0.2), SNOW)


static func _suitcase(st: SurfaceTool, xform: Transform3D, size: Vector3, color: Color) -> void:
	LowPolyBuilder.add_oriented_box(st, xform, size, color)
	var trim := color.darkened(0.4)
	for x: float in [-size.x * 0.3, size.x * 0.3]:
		LowPolyBuilder.add_oriented_box(st, xform.translated_local(Vector3(x, 0.0, 0.0)),
			Vector3(0.035, size.y + 0.01, size.z + 0.01), trim)
	LowPolyBuilder.add_oriented_box(st, xform.translated_local(Vector3(0.0, size.y * 0.5 + 0.02, 0.0)),
		Vector3(0.12, 0.03, 0.03), trim)


## Fahrrad in einem Fahrradständer: Rahmen, zwei Laufräder, Sattel, Lenker, Korb.
## Fährt entlang X, steht aufrecht; Ursprung = Boden unter der Mitte.
static func add_bicycle(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var frame_colors := [Color(0.18, 0.44, 0.46), Color(0.7, 0.2, 0.18), Color(0.85, 0.66, 0.28)]
	var frame: Color = frame_colors[rng.randi() % frame_colors.size()]
	var tyre := Color(0.1, 0.1, 0.11)
	var metal := Color(0.62, 0.62, 0.64)
	var radius := 0.34
	var rear := Vector3(-0.52, radius, 0.0)
	var front := Vector3(0.52, radius, 0.0)
	for hub in [rear, front]:
		_wheel(st, hub, radius, tyre, metal)
	# Rahmen (Diamant): Tretlager, Sattelrohr, Oberrohr, Unterrohr, Streben, Gabel
	var crank := Vector3(-0.06, 0.28, 0.0)
	var seat := Vector3(-0.2, 0.78, 0.0)
	var head := Vector3(0.36, 0.8, 0.0)
	for pair: Array in [[crank, seat], [seat, head], [crank, head], [crank, rear], [seat, rear]]:
		LowPolyBuilder.add_cylinder_between(st, pair[0], pair[1], 0.022, 6, frame)
	for z: float in [-0.04, 0.04]:
		LowPolyBuilder.add_cylinder_between(st, head + Vector3(0.0, 0.0, z * 0.5), front + Vector3(0.0, 0.0, z), 0.016, 6, frame)
	# Sattel, Lenker, Pedale
	LowPolyBuilder.add_cylinder_between(st, seat, seat + Vector3(-0.02, 0.08, 0.0), 0.014, 6, metal)
	LowPolyBuilder.add_box(st, seat + Vector3(-0.02, 0.1, 0.0), Vector3(0.22, 0.05, 0.1), Color(0.3, 0.2, 0.14))
	LowPolyBuilder.add_box(st, seat + Vector3(-0.02, 0.13, 0.0), Vector3(0.16, 0.012, 0.08), SNOW)
	LowPolyBuilder.add_cylinder_between(st, head, head + Vector3(-0.04, 0.14, 0.0), 0.016, 6, metal)
	LowPolyBuilder.add_cylinder_between(st, head + Vector3(-0.06, 0.14, -0.24), head + Vector3(-0.06, 0.14, 0.24), 0.013, 6, metal)
	for z: float in [-0.24, 0.24]:
		LowPolyBuilder.add_cylinder_between(st, head + Vector3(-0.06, 0.14, z), head + Vector3(-0.06, 0.14, z * 0.8), 0.022, 6, tyre)
	LowPolyBuilder.add_cylinder_between(st, crank + Vector3(0.0, 0.0, -0.08), crank + Vector3(0.0, 0.0, 0.08), 0.03, 6, metal)
	# Korb vorne mit einem kleinen Tannenzweig
	var basket := front + Vector3(-0.02, 0.5, 0.0)
	LowPolyBuilder.add_box(st, basket, Vector3(0.24, 0.18, 0.3), Color(0.62, 0.45, 0.28))
	LowPolyBuilder.add_box(st, basket + Vector3(0.0, 0.07, 0.0), Vector3(0.2, 0.06, 0.26), Color(0.2, 0.14, 0.1))
	LowPolyBuilder.add_cone(st, basket + Vector3(0.0, 0.08, 0.0), 0.07, 0.2, 5, NEEDLES, 0.3, false)
	# Fahrradständer: zwei Bügel
	for x: float in [-0.25, 0.25]:
		LowPolyBuilder.add_cylinder_between(st, Vector3(x, 0.0, 0.14), Vector3(x, 0.55, 0.14), 0.02, 6, IRON)
		LowPolyBuilder.add_cylinder_between(st, Vector3(x, 0.0, -0.14), Vector3(x, 0.55, -0.14), 0.02, 6, IRON)
		LowPolyBuilder.add_cylinder_between(st, Vector3(x, 0.55, -0.14), Vector3(x, 0.55, 0.14), 0.02, 6, IRON)
		LowPolyBuilder.add_box(st, Vector3(x, 0.57, 0.0), Vector3(0.05, 0.015, 0.3), SNOW)


static func _wheel(st: SurfaceTool, hub: Vector3, radius: float, tyre: Color, metal: Color) -> void:
	var segments := 14
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := hub + Vector3(cos(a0), sin(a0), 0.0) * radius
		var p1 := hub + Vector3(cos(a1), sin(a1), 0.0) * radius
		LowPolyBuilder.add_cylinder_between(st, p0, p1, 0.028, 5, tyre)
	for i in 6:
		var angle := TAU * i / 6.0
		LowPolyBuilder.add_cylinder_between(st, hub, hub + Vector3(cos(angle), sin(angle), 0.0) * (radius - 0.02), 0.006, 3, metal)
	LowPolyBuilder.add_cylinder_between(st, hub + Vector3(0.0, 0.0, -0.05), hub + Vector3(0.0, 0.0, 0.05), 0.03, 6, metal)


## Schneebank: niedriger, länglicher Schneewall aus weichen Buckeln (z.B. vom Schneeräumen).
static func add_snow_bank(st: SurfaceTool, rng: RandomNumberGenerator, length := 3.0) -> void:
	var blobs := maxi(3, int(length / 0.45))
	for i in blobs:
		var x := lerpf(-length * 0.5 + 0.25, length * 0.5 - 0.25, (i + 0.5) / blobs) + rng.randf_range(-0.1, 0.1)
		var edge := 1.0 - absf(x) / (length * 0.5) * 0.6
		var radius := rng.randf_range(0.28, 0.4) * edge
		var shade := SNOW.lerp(Color(0.8, 0.85, 0.93), rng.randf() * 0.5)
		LowPolyBuilder.add_rock(st, rng, Vector3(x, radius * 0.25, rng.randf_range(-0.08, 0.08)), radius, shade.darkened(0.03), shade)


## Kleine Sitzgruppe: zwei Bänke einander gegenüber, dazwischen ein runder Tisch
## mit einem Windlicht. Rückgabe: Sitzplätze [Lage, Blickrichtung] für die Bewohner.
static func add_seating_group(st: SurfaceTool, rng: RandomNumberGenerator) -> Array[Transform3D]:
	var seats: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		# Bank bei z = ±0.95, Blick zur Mitte
		var bench_st := SurfaceTool.new()
		bench_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		add_bench(bench_st, rng)
		var xform := Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0.0, 0.0, side * 0.95))
		st.append_from(bench_st.commit(), 0, xform)
		for x in BENCH_SEATS:
			seats.append(xform * Transform3D(Basis.IDENTITY, Vector3(x, BENCH_SEAT_HEIGHT, -0.02)))
	# Runder Tisch mit Windlicht
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.16, 0.12, 0.05, 8, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.05, 0.0), 0.04, 0.04, 0.55, 6, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.6, 0.0), 0.34, 0.34, 0.05, 10, _vary(WOOD, rng, 0.03))
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.65, 0.0), 0.3, 0.28, 0.012, 10, SNOW)
	LowPolyBuilder.add_cylinder(st, Vector3(0.1, 0.66, 0.05), 0.06, 0.06, 0.12, 6, Color(0.95, 0.82, 0.55))
	return seats


## Lage einer Übergangsrampe (Mitte, Neigung) auf Seite [param side] (±1): vom
## Bohlenbelag bei ±1,9 m in 1,5 m sanft hinunter auf den Boden.
static func crossing_ramp(side: float) -> Transform3D:
	var top := RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT
	var angle := atan2(top, 1.5)
	return Transform3D(Basis(Vector3.BACK, -side * angle), Vector3(side * 2.65, top * 0.5 - 0.04, 0.0))



static func _vary(color: Color, rng: RandomNumberGenerator, amount := 0.025) -> Color:
	var v := rng.randf_range(-amount, amount)
	return Color(color.r + v, color.g + v, color.b + v)
