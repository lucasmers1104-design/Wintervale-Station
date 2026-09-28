@tool
## Low-Poly-Modelle fürs Dorf: Natur, Beleuchtung, Dekoration und der Dorfplatz.
##
## Alle Funktionen schreiben in einen SurfaceTool (flach schattiert, Vertexfarben)
## und arbeiten lokal: Ursprung = Boden, -Z = Vorderseite. Leuchtende Teile
## (Lampengläser) kommen in einen eigenen SurfaceTool "glow", damit sie nachts
## ein warmes Leuchtmaterial bekommen. Lichtpositionen werden zurückgegeben.
class_name VillageMeshes
extends RefCounted

const SNOW := Color(0.92, 0.94, 0.98)
const SNOW_SHADE := Color(0.82, 0.86, 0.93)
const NEEDLES := Color(0.15, 0.33, 0.27)
const NEEDLES_DARK := Color(0.1, 0.24, 0.21)
const NEEDLES_LIGHT := Color(0.24, 0.43, 0.3)
const BARK := Color(0.38, 0.25, 0.17)
const BIRCH := Color(0.9, 0.88, 0.84)
const BIRCH_MARK := Color(0.2, 0.19, 0.2)
const SAGE := Color(0.42, 0.52, 0.38)
const WOOD := Color(0.62, 0.40, 0.24)
const WOOD_DARK := Color(0.44, 0.28, 0.17)
const IRON := Color(0.16, 0.17, 0.19)
const STONE := Color(0.62, 0.58, 0.54)
const STONE_DARK := Color(0.5, 0.47, 0.45)
const ICE := Color(0.7, 0.84, 0.94)
const BERRY := Color(0.8, 0.12, 0.12)
const PETAL := Color(0.97, 0.94, 0.88)
const HEATHER := Color(0.78, 0.42, 0.62)
const GRASS_DRY := Color(0.78, 0.66, 0.42)
const GLASS_WARM := Color(1.0, 0.86, 0.6)
const POST_YELLOW := Color(0.96, 0.76, 0.18)


# --- Bäume (6) -----------------------------------------------------------------------

## Hohe, schlanke Fichte mit vielen Stufen.
static func tree_pine_tall(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.3, 0), 0.22, 0.14, 1.7, 7, BARK)
	var y := 1.0
	var radius := 1.5
	for i in 6:
		var h := radius * 1.25
		var needle := NEEDLES.lerp(NEEDLES_DARK, rng.randf() * 0.6)
		var offset := rng.randf() * TAU
		LowPolyBuilder.add_cone(st, Vector3(0, y, 0), radius, h, 8, needle, offset)
		_snow_band(st, y, radius, h, 0.2, 0.47, 8, offset)
		y += h * 0.46
		radius *= 0.8


## Volle, runde Tanne mit breitem Fuß.
static func tree_fir_full(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.3, 0), 0.26, 0.18, 1.2, 7, BARK)
	var y := 0.6
	var radius := 2.1
	for i in 4:
		var h := radius * 1.05
		var offset := rng.randf() * TAU
		LowPolyBuilder.add_cone(st, Vector3(0, y, 0), radius, h, 10, NEEDLES.lerp(NEEDLES_LIGHT, rng.randf() * 0.35), offset)
		# Schnee in Bändern auf dem sichtbaren Außenring jeder Stufe
		_snow_band(st, y, radius, h, 0.22, 0.5, 10, offset)
		y += h * 0.52
		radius *= 0.74


## Tief verschneite Fichte – der Schnee hängt schwer auf den Ästen.
static func tree_spruce_snowy(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.3, 0), 0.2, 0.14, 1.3, 6, BARK)
	var y := 0.8
	var radius := 1.7
	for i in 5:
		var h := radius * 1.1
		var offset := rng.randf() * TAU
		LowPolyBuilder.add_cone(st, Vector3(0, y, 0), radius, h, 7, NEEDLES_DARK, offset)
		LowPolyBuilder.add_cone(st, Vector3(0, y + h * 0.22, 0), radius * 0.92, h * 0.72, 7, SNOW.lerp(SNOW_SHADE, 0.3), offset, false)
		y += h * 0.5
		radius *= 0.76
	LowPolyBuilder.add_cone(st, Vector3(0, y, 0), 0.25, 0.5, 6, SNOW, 0.0, false)


## Birke im Winter: weißer Stamm mit dunklen Flecken, feine kahle Äste mit Schnee.
static func tree_birch(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var lean := Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
	var top := Vector3(0, 4.6, 0) + lean
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, -0.3, 0), top, 0.15, 7, BIRCH)
	for i in 9:
		var t := rng.randf_range(0.1, 0.8)
		var p := Vector3.ZERO.lerp(top, t) + Vector3(0, -0.3 * (1.0 - t), 0)
		var angle := rng.randf() * TAU
		LowPolyBuilder.add_box(st, p + Vector3(cos(angle), 0, sin(angle)) * 0.13, Vector3(0.12, 0.05, 0.12), BIRCH_MARK)
	# Äste: Hauptäste mit je zwei Zweigen, auf der Oberseite etwas Schnee
	for i in 7:
		var t := 0.42 + i * 0.075
		var start := Vector3.ZERO.lerp(top, t)
		var angle := i * 2.4 + rng.randf() * 0.4
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var length := lerpf(1.6, 0.7, float(i) / 6.0)
		var tip := start + out * length + Vector3.UP * length * 0.8
		LowPolyBuilder.add_cylinder_between(st, start, tip, 0.045, 4, BIRCH.darkened(0.15))
		LowPolyBuilder.add_box(st, (start + tip) * 0.5 + Vector3.UP * 0.05, Vector3(0.06, 0.03, 0.06), SNOW)
		for k in 2:
			var from := start.lerp(tip, 0.55 + k * 0.25)
			var twig := from + (out.rotated(Vector3.UP, (k - 0.5) * 1.3) * 0.45 + Vector3.UP * 0.35)
			LowPolyBuilder.add_cylinder_between(st, from, twig, 0.02, 3, BARK.lightened(0.1))
	# Ein paar letzte goldene Blätter bleiben hängen
	for i in 6:
		var p := top + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.2, 0.2), rng.randf_range(-1.0, 1.0))
		LowPolyBuilder.add_box(st, p, Vector3(0.1, 0.02, 0.1), Color(0.88, 0.66, 0.28))


## Rundkroniger Laubbaum im Spielzeug-Stil: kugelige Krone mit Schneehaube.
static func tree_round(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.3, 0), 0.26, 0.18, 2.4, 7, BARK)
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 1.6, 0), Vector3(0.5, 2.4, 0.1), 0.09, 5, BARK)
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 1.8, 0), Vector3(-0.45, 2.5, -0.2), 0.08, 5, BARK)
	var crown := SAGE.lerp(NEEDLES_LIGHT, rng.randf() * 0.5)
	LowPolyBuilder.add_rock(st, rng, Vector3(0, 3.0, 0), 1.45, crown, SNOW, 5, 9)
	LowPolyBuilder.add_rock(st, rng, Vector3(0.75, 2.6, 0.3), 0.9, crown.darkened(0.08), SNOW, 4, 7)
	LowPolyBuilder.add_rock(st, rng, Vector3(-0.7, 2.7, -0.35), 0.95, crown.lightened(0.05), SNOW, 4, 7)


## Kleines Bäumchen (Jungtanne), z.B. für den Dorfplatz.
static func tree_small(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.2, 0), 0.08, 0.06, 0.5, 5, BARK)
	var y := 0.25
	var radius := 0.75
	for i in 3:
		var h := radius * 1.3
		var offset := rng.randf() * TAU
		LowPolyBuilder.add_cone(st, Vector3(0, y, 0), radius, h, 7, NEEDLES_LIGHT.lerp(NEEDLES, rng.randf() * 0.5), offset)
		LowPolyBuilder.add_cone(st, Vector3(0, y + h * 0.5, 0), radius * 0.55, h * 0.5, 7, SNOW, offset, false)
		y += h * 0.48
		radius *= 0.72


# --- Büsche (4) ------------------------------------------------------------------------

static func bush_round(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var angle := TAU * i / 3.0 + rng.randf() * 0.5
		LowPolyBuilder.add_rock(st, rng, Vector3(cos(angle) * 0.3, 0.35, sin(angle) * 0.3), rng.randf_range(0.45, 0.6),
			SAGE.lerp(NEEDLES_LIGHT, rng.randf()), SNOW)


## Stechpalme: dunkelgrün mit roten Beeren.
static func bush_holly(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 4:
		var angle := TAU * i / 4.0 + rng.randf() * 0.4
		LowPolyBuilder.add_rock(st, rng, Vector3(cos(angle) * 0.35, 0.4, sin(angle) * 0.35), rng.randf_range(0.4, 0.55),
			NEEDLES_DARK.lerp(NEEDLES, rng.randf()), SNOW_SHADE)
	for i in 16:
		var angle := rng.randf() * TAU
		var p := Vector3(cos(angle) * rng.randf_range(0.45, 0.75), rng.randf_range(0.35, 0.8), sin(angle) * rng.randf_range(0.45, 0.75))
		LowPolyBuilder.add_box(st, p, Vector3.ONE * 0.07, BERRY)


## Wacholder: aufrechte, spitze Zweigbüschel.
static func bush_juniper(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 7:
		var angle := rng.randf() * TAU
		var p := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.0, 0.45)
		var h := rng.randf_range(0.9, 1.5)
		LowPolyBuilder.add_cone(st, p, rng.randf_range(0.2, 0.3), h, 6, NEEDLES.lerp(Color(0.3, 0.45, 0.4), rng.randf()), rng.randf() * TAU)
		LowPolyBuilder.add_cone(st, p + Vector3.UP * h * 0.6, 0.1, h * 0.35, 6, SNOW, 0.0, false)


## Eingeschneiter Busch: ein Schneehügel, aus dem Zweige ragen.
static func bush_snowy(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_rock(st, rng, Vector3(0, 0.15, 0), 0.75, SNOW_SHADE, SNOW, 4, 8)
	for i in 10:
		var angle := rng.randf() * TAU
		var from := Vector3(cos(angle) * 0.3, 0.3, sin(angle) * 0.3)
		var to := from + Vector3(cos(angle) * 0.35, rng.randf_range(0.4, 0.7), sin(angle) * 0.35)
		LowPolyBuilder.add_cylinder_between(st, from, to, 0.025, 3, BARK)
		if rng.randf() < 0.4:
			LowPolyBuilder.add_box(st, to, Vector3.ONE * 0.06, BERRY)


# --- Weitere Natur -----------------------------------------------------------------------

## Blumenbeet mit Steineinfassung: Christrosen und Winterheide.
static func flower_bed(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var segments := 12
	for i in segments:
		var angle := TAU * i / segments
		var p := Vector3(cos(angle) * 1.05, 0.08, sin(angle) * 0.75)
		LowPolyBuilder.add_rock(st, rng, p, 0.17, STONE.lerp(STONE_DARK, rng.randf()), SNOW, 3, 5)
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.05, 0), 1.0, 0.95, 0.18, 12, Color(0.32, 0.24, 0.2))
	for i in 14:
		var p := Vector3(rng.randf_range(-0.8, 0.8), 0.12, rng.randf_range(-0.55, 0.55))
		if Vector2(p.x / 0.85, p.z / 0.6).length() > 1.0:
			continue
		if rng.randf() < 0.5:
			# Winterheide: kleine rosa Büschel
			LowPolyBuilder.add_cone(st, p, 0.14, 0.26, 5, HEATHER.lerp(Color(0.62, 0.3, 0.5), rng.randf()), rng.randf() * TAU)
		else:
			# Christrose: Blätter und eine weiße Blüte
			LowPolyBuilder.add_cone(st, p, 0.13, 0.18, 5, NEEDLES_LIGHT, rng.randf() * TAU)
			for k in 5:
				var angle := TAU * k / 5.0
				LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, -angle), p + Vector3(cos(angle) * 0.05, 0.2, sin(angle) * 0.05)),
					Vector3(0.07, 0.015, 0.05), PETAL)
			LowPolyBuilder.add_box(st, p + Vector3(0, 0.21, 0), Vector3.ONE * 0.035, Color(0.95, 0.78, 0.3))


## Kleine Felsgruppe.
static func rocks_small(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var color := STONE.lerp(Color(0.46, 0.44, 0.45), rng.randf())
	LowPolyBuilder.add_rock(st, rng, Vector3(0, 0.25, 0), 0.6, color, SNOW)
	LowPolyBuilder.add_rock(st, rng, Vector3(0.62, 0.12, 0.25), 0.32, color.darkened(0.08), SNOW)
	LowPolyBuilder.add_rock(st, rng, Vector3(-0.45, 0.1, 0.4), 0.26, color.lightened(0.05), SNOW)


## Holzstapel: gestapelte Baumstämme mit hellen Schnittflächen und Schnee obenauf.
static func log_pile(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var rows := [[-0.42, 0.0, 0.42], [-0.21, 0.21], [0.0]]
	for r in rows.size():
		for x: float in rows[r]:
			var y := 0.2 + r * 0.34
			var jitter := rng.randf_range(-0.12, 0.12)
			var a := Vector3(x, y, -0.95 + jitter)
			var b := Vector3(x, y, 0.95 + jitter)
			LowPolyBuilder.add_cylinder_between(st, a, b, 0.19, 8, BARK.lerp(BARK.darkened(0.2), rng.randf()))
			for end in [a, b]:
				var dir := -1.0 if end == a else 1.0
				LowPolyBuilder.add_cylinder_between(st, end, end + Vector3(0, 0, dir * 0.01), 0.16, 8, Color(0.85, 0.7, 0.48))
				LowPolyBuilder.add_cylinder_between(st, end, end + Vector3(0, 0, dir * 0.015), 0.07, 8, Color(0.72, 0.56, 0.36))
	LowPolyBuilder.add_box(st, Vector3(0, 0.9, 0), Vector3(0.3, 0.06, 1.7), SNOW)
	for x: float in [-0.35, 0.35]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.6, 0), Vector3(0.28, 0.05, 1.8), SNOW_SHADE)


## Grasbüschel: trockene, goldene Halme, die aus dem Schnee ragen.
static func grass_tuft(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 14:
		var angle := rng.randf() * TAU
		var base := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.0, 0.3)
		var tip := base + Vector3(cos(angle) * 0.18, rng.randf_range(0.35, 0.7), sin(angle) * 0.18)
		var color := GRASS_DRY.lerp(Color(0.6, 0.5, 0.32), rng.randf())
		LowPolyBuilder.add_triangle_facing(st, base + Vector3(-0.03, 0, 0), base + Vector3(0.03, 0, 0), tip, color, Vector3(0, 0, 1))
		LowPolyBuilder.add_triangle_facing(st, base + Vector3(-0.03, 0, 0), base + Vector3(0.03, 0, 0), tip, color, Vector3(0, 0, -1))
	LowPolyBuilder.add_rock(st, rng, Vector3(0, -0.02, 0), 0.25, SNOW_SHADE, SNOW, 3, 6)


# --- Beleuchtung (Glas → glow) -------------------------------------------------------------

## Kleine Gartenlampe (Poller mit Pilzhut). Rückgabe: Lichtpunkt.
static func garden_lamp(st: SurfaceTool, glow: SurfaceTool) -> Vector3:
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.11, 0.09, 0.08, 8, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.08, 0), 0.05, 0.05, 0.5, 6, IRON)
	LowPolyBuilder.add_cylinder(glow, Vector3(0, 0.56, 0), 0.09, 0.09, 0.16, 8, GLASS_WARM)
	LowPolyBuilder.add_cone(st, Vector3(0, 0.72, 0), 0.2, 0.14, 8, IRON)
	LowPolyBuilder.add_cone(st, Vector3(0, 0.78, 0), 0.13, 0.09, 8, SNOW, 0.0, false)
	return Vector3(0, 0.6, 0)


## Straßenlaterne mit geschwungenem Arm und hängender Leuchte. Rückgabe: Lichtpunkt.
static func street_lamp(st: SurfaceTool, glow: SurfaceTool) -> Vector3:
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.2, 0.16, 0.4, 8, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.4, 0), 0.08, 0.06, 3.3, 8, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.2, 0), 0.1, 0.1, 0.12, 8, IRON)
	# Geschwungener Arm aus kurzen Stücken
	var previous := Vector3(0, 3.6, 0)
	for i in range(1, 7):
		var t := float(i) / 6.0
		var p := Vector3(0, 3.6 + sin(t * PI) * 0.35, -t * 0.95)
		LowPolyBuilder.add_cylinder_between(st, previous, p, 0.04, 5, IRON)
		previous = p
	LowPolyBuilder.add_cone(st, Vector3(0, 3.72, 0), 0.1, 0.25, 6, IRON)
	var lamp := Vector3(0, 3.25, -0.95)
	LowPolyBuilder.add_cylinder_between(st, previous, lamp + Vector3(0, 0.3, 0), 0.02, 4, IRON)
	LowPolyBuilder.add_cone(st, lamp + Vector3(0, 0.12, 0), 0.26, 0.2, 6, IRON)
	LowPolyBuilder.add_cone(st, lamp + Vector3(0, 0.2, 0), 0.17, 0.1, 6, SNOW, 0.0, false)
	LowPolyBuilder.add_cylinder(glow, lamp + Vector3(0, -0.2, 0), 0.1, 0.17, 0.32, 6, GLASS_WARM)
	LowPolyBuilder.add_cylinder(st, lamp + Vector3(0, -0.24, 0), 0.08, 0.1, 0.05, 6, IRON)
	return lamp + Vector3(0, -0.15, 0)


## Lichterkette zwischen zwei Holzpfosten (entlang der lokalen X-Achse von 0 bis [param length]).
## Kabel und Birnen haben in der Vertexfarbe Alpha = Schwinggewicht (0 an den Pfosten).
## Rückgabe: Punkte für ein paar schwache Lichter.
static func string_lights(st: SurfaceTool, cable: SurfaceTool, bulbs: SurfaceTool, length: float,
		rng: RandomNumberGenerator) -> Array[Vector3]:
	var height := 2.4
	for x: float in [0.0, length]:
		LowPolyBuilder.add_box(st, Vector3(x, height * 0.5, 0), Vector3(0.12, height + 0.2, 0.12), WOOD_DARK)
		LowPolyBuilder.add_cone(st, Vector3(x, height + 0.1, 0), 0.1, 0.1, 4, SNOW, PI * 0.25, false)
	var sag := minf(0.6, length * 0.06)
	var segments := maxi(6, int(length / 0.45))
	var previous := Vector3(0, height, 0)
	var lights: Array[Vector3] = []
	var palette := [Color(1.0, 0.78, 0.45), Color(1.0, 0.62, 0.36), Color(1.0, 0.88, 0.62)]
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p := Vector3(t * length, height - sin(t * PI) * sag, 0)
		var weight := sin(t * PI)
		_colored_beam(cable, previous, p, 0.018, Color(0.12, 0.12, 0.12, weight))
		if i < segments:
			var bulb := p + Vector3(0, -0.07, 0)
			var color: Color = palette[i % palette.size()]
			color.a = weight
			_colored_box(bulbs, bulb, Vector3(0.07, 0.1, 0.07), color)
		previous = p
	for k in maxi(1, int(length / 5.0)):
		var t := (k + 0.5) / maxi(1, int(length / 5.0))
		lights.append(Vector3(t * length, height - sin(t * PI) * sag - 0.2, 0))
	return lights


# --- Dekoration ---------------------------------------------------------------------------

## Brunnen: runde Steinschale mit gefrorenem Wasser, Säule mit Schale und Eiszapfen.
static func fountain(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var segments := 12
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.2, 0), 1.55, 1.55, 0.3, segments, STONE_DARK)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var mid := (a0 + a1) * 0.5
		var p := Vector3(cos(mid), 0, sin(mid)) * 1.35
		LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, -mid), p + Vector3(0, 0.35, 0)),
			Vector3(0.3, 0.55, 0.72), STONE.lerp(STONE_DARK, rng.randf() * 0.4))
		LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, -mid), p + Vector3(0, 0.64, 0)),
			Vector3(0.34, 0.05, 0.74), SNOW)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.1, 0), 1.2, 1.2, 0.35, segments, ICE)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.1, 0), 0.26, 0.2, 1.1, 8, STONE)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.15, 0), 0.25, 0.6, 0.2, 10, STONE)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.33, 0), 0.52, 0.52, 0.04, 10, SNOW)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.33, 0), 0.1, 0.07, 0.45, 6, STONE)
	LowPolyBuilder.add_cone(st, Vector3(0, 1.78, 0), 0.14, 0.2, 6, SNOW)
	for i in 10:
		var angle := TAU * i / 10.0 + rng.randf() * 0.2
		LowPolyBuilder.add_cone(st, Vector3(cos(angle) * 0.58, 1.18, sin(angle) * 0.58), 0.04, -rng.randf_range(0.25, 0.5), 4, ICE, 0.0, false)


## Fahrradständer mit zwei Fahrrädern.
static func bike_rack(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var one := SurfaceTool.new()
	one.begin(Mesh.PRIMITIVE_TRIANGLES)
	StationPropMeshes.add_bicycle(one, rng)
	var mesh := one.commit()
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.35, 0, 0)))
	var two := SurfaceTool.new()
	two.begin(Mesh.PRIMITIVE_TRIANGLES)
	StationPropMeshes.add_bicycle(two, rng)
	st.append_from(two.commit(), 0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.35, 0, 0.1)))


## Gelber Briefkasten auf einem Pfosten mit Posthorn-Plakette.
static func mailbox(st: SurfaceTool) -> void:
	LowPolyBuilder.add_box(st, Vector3(0, 0.55, 0), Vector3(0.1, 1.1, 0.1), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 1.3, 0), Vector3(0.44, 0.5, 0.3), POST_YELLOW)
	LowPolyBuilder.add_cylinder_between(st, Vector3(-0.22, 1.55, 0), Vector3(0.22, 1.55, 0), 0.15, 8, POST_YELLOW)
	LowPolyBuilder.add_box(st, Vector3(0, 1.72, 0), Vector3(0.4, 0.04, 0.24), SNOW)
	LowPolyBuilder.add_box(st, Vector3(0, 1.42, -0.155), Vector3(0.28, 0.04, 0.02), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 1.2, -0.155), Vector3(0.12, 0.12, 0.02), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, 1.2, -0.165), Vector3(0.07, 0.07, 0.01), POST_YELLOW)


## Pflanzkübel: Holzfass mit Metallreifen und einem kleinen Nadelbaum.
static func planter(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.38, 0.46, 0.6, 10, WOOD)
	for y: float in [0.12, 0.48]:
		LowPolyBuilder.add_cylinder(st, Vector3(0, y, 0), 0.41 + y * -0.12 + 0.05, 0.41 + y * -0.12 + 0.05, 0.05, 10, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.55, 0), 0.4, 0.4, 0.04, 10, Color(0.3, 0.22, 0.18))
	var tree := SurfaceTool.new()
	tree.begin(Mesh.PRIMITIVE_TRIANGLES)
	tree_small(tree, rng)
	st.append_from(tree.commit(), 0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), Vector3(0, 0.6, 0)))


## Schneemann mit Karottennase, Kohleaugen, Schal und Mütze.
static func snowman(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_rock(st, rng, Vector3(0, 0.38, 0), 0.5, SNOW, SNOW, 4, 9)
	LowPolyBuilder.add_rock(st, rng, Vector3(0, 0.98, 0), 0.36, SNOW, SNOW, 4, 8)
	LowPolyBuilder.add_rock(st, rng, Vector3(0, 1.42, 0), 0.26, SNOW, SNOW, 4, 8)
	for x: float in [-0.09, 0.09]:
		LowPolyBuilder.add_box(st, Vector3(x, 1.5, -0.24), Vector3.ONE * 0.05, Color(0.08, 0.08, 0.09))
	LowPolyBuilder.add_cylinder_between(st, Vector3(0, 1.42, -0.22), Vector3(0, 1.4, -0.45), 0.04, 5, Color(0.95, 0.5, 0.15))
	for y: float in [0.85, 1.0, 1.15]:
		LowPolyBuilder.add_box(st, Vector3(0, y, -0.34), Vector3.ONE * 0.05, Color(0.08, 0.08, 0.09))
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.2, 0), 0.3, 0.3, 0.1, 10, Color(0.75, 0.22, 0.2))
	LowPolyBuilder.add_box(st, Vector3(0.15, 1.05, -0.22), Vector3(0.09, 0.28, 0.05), Color(0.75, 0.22, 0.2))
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.6, 0), 0.24, 0.24, 0.04, 10, Color(0.2, 0.3, 0.4))
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.62, 0), 0.16, 0.14, 0.24, 10, Color(0.2, 0.3, 0.4))
	# Stöckchen-Arme
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_cylinder_between(st, Vector3(side * 0.3, 1.02, 0), Vector3(side * 0.72, 1.32, 0.05), 0.025, 4, BARK)
		LowPolyBuilder.add_cylinder_between(st, Vector3(side * 0.6, 1.24, 0.04), Vector3(side * 0.72, 1.12, -0.06), 0.018, 3, BARK)


## Holzschlitten.
static func sled(st: SurfaceTool) -> void:
	for x: float in [-0.25, 0.25]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.03, 0), Vector3(0.05, 0.05, 1.1), IRON)
		LowPolyBuilder.add_cylinder_between(st, Vector3(x, 0.03, -0.55), Vector3(x, 0.2, -0.7), 0.025, 4, IRON)
		for z: float in [-0.35, 0.35]:
			LowPolyBuilder.add_box(st, Vector3(x, 0.14, z), Vector3(0.05, 0.2, 0.05), WOOD_DARK)
	for i in 5:
		LowPolyBuilder.add_box(st, Vector3(0, 0.26, -0.4 + i * 0.2), Vector3(0.62, 0.04, 0.15), WOOD)
	LowPolyBuilder.add_box(st, Vector3(0, 0.29, 0.1), Vector3(0.5, 0.02, 0.5), SNOW)


## Dorfplatz: runder Pflasterplatz mit Brunnen in der Mitte, vier Bänken,
## Laternen, Pflanzkübeln, Bäumchen, Wegweiser, Briefkasten und Fahrradständer.
## Rückgabe: {"lights": [...], "seats": [Transform3D], "radius"}.
static func plaza(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> Dictionary:
	var radius := 6.0
	# Pflaster in Ringen: abwechselnd helle und dunkle Steine
	var rings := 6
	for r in rings:
		var r0 := radius * r / rings
		var r1 := radius * (r + 1) / rings
		var count := maxi(6, (r + 1) * 8)
		for i in count:
			var a0 := TAU * i / count
			var a1 := TAU * (i + 1) / count
			var color := STONE.lerp(STONE_DARK, rng.randf() * 0.6)
			if r == rings - 1:
				color = Color(0.5, 0.46, 0.43)
			if rng.randf() < 0.12:
				color = SNOW_SHADE
			var p00 := Vector3(cos(a0) * r0, 0.06, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, 0.06, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, 0.06, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, 0.06, sin(a1) * r1)
			if r == 0:
				LowPolyBuilder.add_triangle_facing(st, p00, p10, p11, color, Vector3.UP)
			else:
				LowPolyBuilder.add_quad_facing(st, p00, p10, p11, p01, color, Vector3.UP)
	# Randsteine und ein Sockel in den Boden
	for i in 24:
		var angle := TAU * (i + 0.5) / 24.0
		LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, -angle), Vector3(cos(angle), 0, sin(angle)) * (radius + 0.08) + Vector3(0, 0.02, 0)),
			Vector3(0.22, 0.2, radius * TAU / 24.0), STONE_DARK)
	LowPolyBuilder.add_cylinder(st, Vector3(0, -0.8, 0), radius + 0.05, radius + 0.05, 0.84, 24, STONE_DARK)
	# Brunnen in der Mitte
	var part := SurfaceTool.new()
	part.begin(Mesh.PRIMITIVE_TRIANGLES)
	fountain(part, rng)
	st.append_from(part.commit(), 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)))
	var seats: Array[Transform3D] = []
	var lights: Array[Vector3] = []
	# Vier Bänke diagonal, Blick zum Brunnen
	for k in 4:
		var angle := PI * 0.25 + k * PI * 0.5
		var dir := Vector3(cos(angle), 0, sin(angle))
		var xform := Transform3D(Basis.looking_at(-dir, Vector3.UP), dir * 3.6 + Vector3(0, 0.06, 0))
		var bench := SurfaceTool.new()
		bench.begin(Mesh.PRIMITIVE_TRIANGLES)
		StationPropMeshes.add_bench(bench, rng)
		st.append_from(bench.commit(), 0, xform)
		for x in StationPropMeshes.BENCH_SEATS:
			seats.append(xform * Transform3D(Basis.IDENTITY, Vector3(x, StationPropMeshes.BENCH_SEAT_HEIGHT, -0.02)))
	# Laternen und Pflanzkübel abwechselnd auf den Achsen
	for k in 4:
		var angle := k * PI * 0.5
		var dir := Vector3(cos(angle), 0, sin(angle))
		if k % 2 == 0:
			var lamp := SurfaceTool.new()
			lamp.begin(Mesh.PRIMITIVE_TRIANGLES)
			var lamp_glow := SurfaceTool.new()
			lamp_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
			var light := street_lamp(lamp, lamp_glow)
			var xf := Transform3D(Basis.looking_at(dir, Vector3.UP), dir * 5.2 + Vector3(0, 0.06, 0))
			st.append_from(lamp.commit(), 0, xf)
			glow.append_from(lamp_glow.commit(), 0, xf)
			lights.append(xf * light)
		else:
			var pot := SurfaceTool.new()
			pot.begin(Mesh.PRIMITIVE_TRIANGLES)
			planter(pot, rng)
			st.append_from(pot.commit(), 0, Transform3D(Basis.IDENTITY, dir * 5.1 + Vector3(0, 0.06, 0)))
	# Kleine Bäume, Wegweiser, Briefkasten und Fahrradständer am Rand
	for angle: float in [0.9, 2.35, 3.95, 5.45]:
		var tree := SurfaceTool.new()
		tree.begin(Mesh.PRIMITIVE_TRIANGLES)
		tree_small(tree, rng)
		st.append_from(tree.commit(), 0, Transform3D(Basis(Vector3.UP, angle), Vector3(cos(angle), 0, sin(angle)) * 6.9))
	var sign_st := SurfaceTool.new()
	sign_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boards := StationPropMeshes.add_signpost(sign_st, [[0.0, 1.95, 0.9], [180.0, 1.63, 0.9], [90.0, 1.31, 0.9]])
	var sign_xf := Transform3D(Basis.IDENTITY, Vector3(-4.3, 0.06, -4.3))
	st.append_from(sign_st.commit(), 0, sign_xf)
	var box := SurfaceTool.new()
	box.begin(Mesh.PRIMITIVE_TRIANGLES)
	mailbox(box)
	st.append_from(box.commit(), 0, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(4.4, 0.06, 4.2)))
	var rack := SurfaceTool.new()
	rack.begin(Mesh.PRIMITIVE_TRIANGLES)
	bike_rack(rack, rng)
	st.append_from(rack.commit(), 0, Transform3D(Basis(Vector3.UP, -PI * 0.25), Vector3(4.5, 0.06, -4.3)))
	var sign_boards: Array[Transform3D] = []
	for b in boards:
		sign_boards.append(sign_xf * b)
	return {"lights": lights, "seats": seats, "radius": radius, "signs": sign_boards}


# --- Linienobjekte ------------------------------------------------------------------------

## Holzzaun von 0 bis [param length] entlang X: Pfosten, zwei Querlatten, Staketen.
static func fence(st: SurfaceTool, length: float, rng: RandomNumberGenerator) -> void:
	var posts := maxi(1, ceili(length / 1.6))
	for i in posts + 1:
		var x := length * i / posts
		LowPolyBuilder.add_box(st, Vector3(x, 0.5, 0), Vector3(0.12, 1.1, 0.12), WOOD_DARK)
		LowPolyBuilder.add_cone(st, Vector3(x, 1.05, 0), 0.1, 0.1, 4, SNOW, PI * 0.25, false)
	for y: float in [0.3, 0.72]:
		LowPolyBuilder.add_box(st, Vector3(length * 0.5, y, 0.07), Vector3(length, 0.07, 0.03), WOOD_DARK)
	var x := 0.15
	while x < length - 0.1:
		var h := 0.92 + rng.randf_range(-0.03, 0.03)
		LowPolyBuilder.add_box(st, Vector3(x, h * 0.5, 0.1), Vector3(0.1, h, 0.03), WOOD.lerp(WOOD_DARK, rng.randf() * 0.3))
		LowPolyBuilder.add_cone(st, Vector3(x, h, 0.1), 0.07, 0.08, 4, SNOW, PI * 0.25, false)
		x += 0.22


## Hecke von 0 bis [param length] entlang X: kastenförmig, weich, mit Schnee obenauf.
static func hedge(st: SurfaceTool, length: float, rng: RandomNumberGenerator) -> void:
	var blobs := maxi(2, int(length / 0.7))
	for i in blobs:
		var x := length * (i + 0.5) / blobs
		var color := NEEDLES.lerp(NEEDLES_LIGHT, rng.randf() * 0.5)
		LowPolyBuilder.add_rock(st, rng, Vector3(x, 0.55, 0), 0.62, color, SNOW, 4, 7)
	LowPolyBuilder.add_box(st, Vector3(length * 0.5, 0.45, 0), Vector3(maxf(length - 0.4, 0.2), 0.9, 0.8), NEEDLES_DARK)
	LowPolyBuilder.add_box(st, Vector3(length * 0.5, 0.92, 0), Vector3(maxf(length - 0.3, 0.2), 0.08, 0.7), SNOW)


# --- Hilfen -----------------------------------------------------------------------------

## Schneeband auf einer Kegelstufe: liegt als Kegelstumpf knapp über der Nadeloberfläche
## zwischen den Anteilen [param from] und [param to] der Stufenhöhe – also auf dem
## Außenring, der unter der nächsten Stufe hervorschaut. Die Unterkante bleibt grün.
static func _snow_band(st: SurfaceTool, y: float, radius: float, height: float, from: float, to: float,
		segments: int, offset: float) -> void:
	var lift := 0.035
	var bottom := radius * (1.0 - from) + lift
	var top := radius * (1.0 - to) + lift
	LowPolyBuilder.add_cylinder(st, Vector3(0, y + height * from + lift, 0), bottom, top, height * (to - from), segments, SNOW, offset)


## Vierkant mit eigener Vertexfarbe (inkl. Alpha als Datenkanal).
static func _colored_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	LowPolyBuilder.add_box(st, center, size, color)


static func _colored_beam(st: SurfaceTool, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	LowPolyBuilder.add_beam(st, a, b, thickness, color)
