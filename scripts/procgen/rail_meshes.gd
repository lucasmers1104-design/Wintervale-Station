@tool
## Prozedurale Gleis-Assets im Low-Poly-Stil.
##
## - Schotterbett: Trapez-Profil entlang der Kurve, mit Schneeresten
## - Holzschwellen: einzelne Quader im festen Abstand, teils verschneit
## - Schienen: vereinfachtes Schienenprofil, blanke Lauffläche, rostige Flanken
## - Schienenverbinder: Laschen mit Schrauben an beiden Enden jedes Gleisstücks
## - Prellbock (Gleis-Endstück): Rahmen mit rot-weißem Balken und Puffern
## - Ghost: vereinfachte Vorschau für den Build-Mode
##
## Koordinaten: Die Gleisachse liegt auf Höhe 0 (= Gelände), siehe [RailConfig].
class_name RailMeshes
extends RefCounted

const GRAVEL := Color(0.46, 0.43, 0.40)
const GRAVEL_DARK := Color(0.37, 0.35, 0.33)
const SNOW := Color(0.88, 0.91, 0.95)
const WOOD := Color(0.30, 0.21, 0.15)
const STEEL_TOP := Color(0.80, 0.80, 0.82)
const STEEL_SIDE := Color(0.33, 0.32, 0.31)
const RUST := Color(0.42, 0.28, 0.21)
const IRON_DARK := Color(0.18, 0.18, 0.20)
const BUFFER_RED := Color(0.70, 0.14, 0.11)
const BUFFER_WHITE := Color(0.92, 0.91, 0.88)
const CONCRETE := Color(0.62, 0.61, 0.59)
const MOTOR_GREY := Color(0.36, 0.40, 0.42)
const SIGNAL_GREY := Color(0.45, 0.47, 0.48)
const SIGNAL_BLACK := Color(0.07, 0.07, 0.08)

## Querschnitt Schotterbett (x, y) – links nach rechts. Der Rand reicht in
## den Boden, damit kleine Geländeunebenheiten nie Lücken zeigen.
const BALLAST_PROFILE: Array[Vector2] = [
	Vector2(-2.3, -0.6), Vector2(-2.05, 0.02), Vector2(-1.5, RailConfig.BALLAST_TOP),
	Vector2(1.5, RailConfig.BALLAST_TOP), Vector2(2.05, 0.02), Vector2(2.3, -0.6),
]
## Farben / Schneeanteil je Profilkante (Rand, Böschung, Krone, Böschung, Rand).
const BALLAST_COLORS: Array[Color] = [SNOW, GRAVEL_DARK, GRAVEL, GRAVEL_DARK, SNOW]
const BALLAST_SNOW: Array[float] = [0.0, 0.15, 0.3, 0.15, 0.0]

## Vereinfachtes Schienenprofil (Fuß, Steg, Kopf) – konvex, 15 cm hoch.
const RAIL_PROFILE: Array[Vector2] = [
	Vector2(-0.065, 0.0), Vector2(-0.035, 0.03), Vector2(-0.035, RailConfig.RAIL_HEIGHT),
	Vector2(0.035, RailConfig.RAIL_HEIGHT), Vector2(0.035, 0.03), Vector2(0.065, 0.0),
]
const RAIL_COLORS: Array[Color] = [RUST, STEEL_SIDE, STEEL_TOP, STEEL_SIDE, RUST]
const NO_SNOW: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]


## Baut alle Teile eines Gleisstücks.
## Rückgabe: {"ballast": ArrayMesh (Schotter + Schwellen), "rails": ArrayMesh, "collision": PackedVector3Array}
static func create_track(curve: Curve3D, variation_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed * 7919 + 13
	var frames := RailGeometry.sample_frames(curve, 1.0)
	var length := curve.get_baked_length()

	# Schotterbett + Schwellen (Vertexfarben, mattes Material)
	var ballast := SurfaceTool.new()
	ballast.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude(ballast, frames, BALLAST_PROFILE, Vector2.ZERO, BALLAST_COLORS, BALLAST_SNOW, rng)
	_cap(ballast, frames[0], BALLAST_PROFILE, Vector2.ZERO, GRAVEL_DARK, true)
	_cap(ballast, frames[-1], BALLAST_PROFILE, Vector2.ZERO, GRAVEL_DARK, false)
	_add_sleepers(ballast, curve, length, rng)

	# Schienen + Verbinder (Metall-Material)
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-RailConfig.RAIL_OFFSET, RailConfig.RAIL_OFFSET]:
		var offset := Vector2(side, RailConfig.RAIL_BASE)
		_extrude(rails, frames, RAIL_PROFILE, offset, RAIL_COLORS, NO_SNOW, rng)
		_cap(rails, frames[0], RAIL_PROFILE, offset, STEEL_SIDE, true)
		_cap(rails, frames[-1], RAIL_PROFILE, offset, STEEL_SIDE, false)
	_add_rail_joints(rails, curve, length)

	return {
		"ballast": ballast.commit(),
		"rails": rails.commit(),
		"collision": _collision_faces(frames),
	}


## Leichtgewichtige Vorschau (Schotterkrone + Schienen) für den Ghost.
static func create_ghost(curve: Curve3D) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	var frames := RailGeometry.sample_frames(curve, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown: Array[Vector2] = [BALLAST_PROFILE[1], BALLAST_PROFILE[2], BALLAST_PROFILE[3], BALLAST_PROFILE[4]]
	var white: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]
	_extrude(st, frames, crown, Vector2(0.0, 0.03), white, [0.0, 0.0, 0.0], rng)
	for side in [-RailConfig.RAIL_OFFSET, RailConfig.RAIL_OFFSET]:
		_extrude(st, frames, RAIL_PROFILE, Vector2(side, RailConfig.RAIL_BASE), RAIL_COLORS, NO_SNOW, rng)
	return st.commit()


## Prellbock am Gleisende. Lokal: -Z zeigt ins Gleis, +Z ist das Ende der Strecke.
static func create_buffer_stop() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beam_y := RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT + 0.75

	# Schotterhügel mit Schnee
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.12, 0.55), Vector3(3.0, 0.5, 1.9), GRAVEL_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.39, 0.6), Vector3(2.7, 0.05, 1.6), SNOW)

	for x in [-RailConfig.RAIL_OFFSET, RailConfig.RAIL_OFFSET]:
		# Pfosten und schräge Stütze
		LowPolyBuilder.add_box(st, Vector3(x, (0.35 + beam_y) * 0.5, 0.35), Vector3(0.16, beam_y - 0.35, 0.16), IRON_DARK)
		LowPolyBuilder.add_beam(st, Vector3(x, 0.4, 1.35), Vector3(x, beam_y - 0.05, 0.42), 0.12, IRON_DARK)
		# Puffer
		LowPolyBuilder.add_cylinder_between(st, Vector3(x, beam_y, 0.2), Vector3(x, beam_y, -0.22), 0.08, 8, IRON_DARK)
		LowPolyBuilder.add_cylinder_between(st, Vector3(x, beam_y, -0.22), Vector3(x, beam_y, -0.28), 0.19, 10, STEEL_SIDE)

	# Rot-weißer Pufferbalken mit Schneehaube
	LowPolyBuilder.add_box(st, Vector3(0.0, beam_y, 0.3), Vector3(2.3, 0.32, 0.22), BUFFER_RED)
	for x in [-0.72, -0.24, 0.24, 0.72]:
		LowPolyBuilder.add_box(st, Vector3(x, beam_y, 0.3), Vector3(0.16, 0.33, 0.23), BUFFER_WHITE)
	LowPolyBuilder.add_box(st, Vector3(0.0, beam_y + 0.185, 0.3), Vector3(2.2, 0.05, 0.2), SNOW)
	return st.commit()


# --- Weichen -------------------------------------------------------------------

## Länge der Weichenzunge (vom Drehpunkt bis zur Spitze).
const BLADE_LENGTH := 3.2

## Weichenzunge: schlanke, spitz zulaufende Schiene. Drehpunkt (Zungenwurzel)
## im Ursprung, die Spitze zeigt nach +Z.
static func create_switch_blade() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := RailConfig.RAIL_HEIGHT * 0.9
	var heel := 0.035
	var tip := 0.008
	var corners := [
		Vector3(-heel, 0.0, 0.0), Vector3(heel, 0.0, 0.0), Vector3(heel, h, 0.0), Vector3(-heel, h, 0.0),
		Vector3(-tip, 0.0, BLADE_LENGTH), Vector3(tip, 0.0, BLADE_LENGTH), Vector3(tip, h * 0.7, BLADE_LENGTH),
		Vector3(-tip, h * 0.7, BLADE_LENGTH),
	]
	var center := Vector3(0.0, h * 0.5, BLADE_LENGTH * 0.5)
	var faces := [[0, 1, 2, 3], [4, 5, 6, 7], [0, 4, 7, 3], [1, 5, 6, 2], [3, 2, 6, 7], [0, 1, 5, 4]]
	for face: Array in faces:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		var color := STEEL_TOP if face == [3, 2, 6, 7] else STEEL_SIDE
		LowPolyBuilder.add_quad_facing(st, a, b, c, d, color, (a + b + c + d) * 0.25 - center)
	return st.commit()


## Weichenantrieb: Betonsockel, Stahlgehäuse mit Deckel und Kabelkasten.
## Lokal: Mitte des Gehäuses im Ursprung (Bodenhöhe), Stellstange zeigt nach +X.
static func create_switch_motor() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.08, 0.0), Vector3(0.9, 0.2, 0.7), CONCRETE)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.34, 0.0), Vector3(0.72, 0.32, 0.5), MOTOR_GREY)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.52, 0.0), Vector3(0.78, 0.05, 0.56), MOTOR_GREY.darkened(0.2))
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.555, 0.0), Vector3(0.7, 0.03, 0.48), SNOW)
	LowPolyBuilder.add_box(st, Vector3(-0.3, 0.3, 0.31), Vector3(0.12, 0.18, 0.1), IRON_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.4, 0.3, 0.0), Vector3(0.12, 0.1, 0.12), IRON_DARK)
	# Pfosten für die Weichenlaterne
	LowPolyBuilder.add_box(st, Vector3(-0.2, 0.85, 0.0), Vector3(0.06, 0.6, 0.06), IRON_DARK)
	return st.commit()


## Weichenlaterne: kleiner Kasten mit weißem Streifen, dreht sich beim Umstellen.
static func create_switch_lantern() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyBuilder.add_box(st, Vector3.ZERO, Vector3(0.22, 0.22, 0.22), IRON_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.0, -0.112), Vector3(0.05, 0.17, 0.01), BUFFER_WHITE)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.0, 0.112), Vector3(0.05, 0.17, 0.01), BUFFER_WHITE)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.14, 0.0), Vector3(0.26, 0.05, 0.26), IRON_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.175, 0.0), Vector3(0.2, 0.025, 0.2), SNOW)
	return st.commit()


# --- Signale -------------------------------------------------------------------

## Höhe der Signallampen über dem Boden (oben grün, unten rot).
const SIGNAL_GREEN_Y := 3.62
const SIGNAL_RED_Y := 3.22
## Die Lampen sitzen knapp vor dem Signalschirm (-Z = Blickrichtung der Züge).
const SIGNAL_LAMP_Z := -0.075

## Hauptsignal: Fundament, Mast mit Leiter und Mastschild, schwarzer Schirm
## mit Blenden über den Lampen. Lokal: Mastfuß im Ursprung, -Z zeigt zum Zug.
static func create_signal_mast() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Fundament und Mast
	LowPolyBuilder.add_box(st, Vector3(0.0, 0.1, 0.0), Vector3(0.6, 0.3, 0.6), CONCRETE)
	LowPolyBuilder.add_cylinder(st, Vector3(0.0, 0.25, 0.0), 0.08, 0.06, 3.8, 8, SIGNAL_GREY)
	# Leiter hinter dem Mast
	for x in [-0.15, 0.15]:
		LowPolyBuilder.add_box(st, Vector3(x, 1.8, 0.2), Vector3(0.03, 2.9, 0.03), SIGNAL_GREY)
	for i in 10:
		LowPolyBuilder.add_box(st, Vector3(0.0, 0.55 + i * 0.3, 0.2), Vector3(0.3, 0.025, 0.025), SIGNAL_GREY)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.8, 0.11), Vector3(0.05, 0.05, 0.16), SIGNAL_GREY)
	# Mastschild: weiß-rot-weiß
	for i in 5:
		var color := BUFFER_WHITE if i % 2 == 0 else BUFFER_RED
		LowPolyBuilder.add_box(st, Vector3(0.0, 2.35 + i * 0.09, -0.085), Vector3(0.2, 0.09, 0.02), color)
	# Signalschirm mit Blenden
	var head_y := (SIGNAL_GREEN_Y + SIGNAL_RED_Y) * 0.5
	LowPolyBuilder.add_box(st, Vector3(0.0, head_y, 0.0), Vector3(0.5, 0.95, 0.1), SIGNAL_BLACK)
	LowPolyBuilder.add_box(st, Vector3(0.0, head_y, 0.06), Vector3(0.3, 0.7, 0.05), SIGNAL_GREY)
	for lamp_y in [SIGNAL_GREEN_Y, SIGNAL_RED_Y]:
		LowPolyBuilder.add_box(st, Vector3(0.0, lamp_y + 0.13, -0.16), Vector3(0.26, 0.03, 0.22), SIGNAL_BLACK)
		for x in [-0.125, 0.125]:
			LowPolyBuilder.add_box(st, Vector3(x, lamp_y + 0.04, -0.14), Vector3(0.02, 0.16, 0.18), SIGNAL_BLACK)
	# Schneehaube auf dem Schirm
	LowPolyBuilder.add_box(st, Vector3(0.0, head_y + 0.49, 0.0), Vector3(0.46, 0.04, 0.12), SNOW)
	return st.commit()


# --- Intern ------------------------------------------------------------------

## Zieht ein Profil (offene Linie) entlang der Rahmen. Farbe pro Profilkante,
## optional zufällig mit Schnee; kleine Helligkeitsvariation pro Fläche.
static func _extrude(st: SurfaceTool, frames: Array[Transform3D], profile: Array[Vector2], offset: Vector2,
		colors: Array[Color], snow: Array, rng: RandomNumberGenerator) -> void:
	var centroid := Vector2.ZERO
	for p in profile:
		centroid += p
	centroid /= profile.size()

	for i in frames.size() - 1:
		var fa := frames[i]
		var fb := frames[i + 1]
		for e in profile.size() - 1:
			var a := _to_world(fa, profile[e] + offset)
			var b := _to_world(fa, profile[e + 1] + offset)
			var c := _to_world(fb, profile[e + 1] + offset)
			var d := _to_world(fb, profile[e] + offset)
			var mid := (profile[e] + profile[e + 1]) * 0.5 - centroid
			var outward := fa.basis.x * mid.x + fa.basis.y * mid.y
			var color := SNOW if rng.randf() < float(snow[e]) else colors[e]
			LowPolyBuilder.add_quad_facing(st, a, b, c, d, _vary(color, rng), outward)


## Verschließt das Profil an einem Ende (Fächer um den Mittelpunkt).
static func _cap(st: SurfaceTool, frame: Transform3D, profile: Array[Vector2], offset: Vector2,
		color: Color, at_start: bool) -> void:
	var centroid := Vector2.ZERO
	for p in profile:
		centroid += p
	centroid /= profile.size()
	var center := _to_world(frame, centroid + offset)
	var outward := frame.basis.z if at_start else -frame.basis.z
	for e in profile.size():
		var a := _to_world(frame, profile[e] + offset)
		var b := _to_world(frame, profile[(e + 1) % profile.size()] + offset)
		LowPolyBuilder.add_triangle_facing(st, center, a, b, color, outward)


static func _add_sleepers(st: SurfaceTool, curve: Curve3D, length: float, rng: RandomNumberGenerator) -> void:
	var count := maxi(1, floori(length / RailConfig.SLEEPER_SPACING))
	var spacing := length / count
	var y := RailConfig.BALLAST_TOP + RailConfig.SLEEPER_HEIGHT * 0.5
	for i in count:
		var frame := RailGeometry.frame_at(curve, spacing * (i + 0.5))
		var center := frame.origin + frame.basis.y * y
		LowPolyBuilder.add_oriented_box(st, Transform3D(frame.basis, center), RailConfig.SLEEPER_SIZE, _vary(WOOD, rng, 0.04))
		# Etwas Schnee auf manchen Schwellen
		if rng.randf() < 0.35:
			var snow_length := rng.randf_range(0.5, 1.4)
			var snow_center := center + frame.basis.y * (RailConfig.SLEEPER_HEIGHT * 0.5 + 0.015) \
				+ frame.basis.x * rng.randf_range(-0.6, 0.6)
			LowPolyBuilder.add_oriented_box(st, Transform3D(frame.basis, snow_center),
				Vector3(snow_length, 0.03, 0.22), SNOW)


## Laschen (Schienenverbinder) mit je zwei Schrauben an beiden Gleisenden.
static func _add_rail_joints(st: SurfaceTool, curve: Curve3D, length: float) -> void:
	var plate_length := minf(0.35, length * 0.25)
	for offset in [plate_length * 0.5, length - plate_length * 0.5]:
		var frame := RailGeometry.frame_at(curve, offset)
		for rail_x in [-RailConfig.RAIL_OFFSET, RailConfig.RAIL_OFFSET]:
			for side in [-1.0, 1.0]:
				var x: float = rail_x + side * 0.05
				var center := frame.origin + frame.basis.x * x + frame.basis.y * (RailConfig.RAIL_BASE + 0.07)
				LowPolyBuilder.add_oriented_box(st, Transform3D(frame.basis, center), Vector3(0.025, 0.08, plate_length), IRON_DARK)
				for bolt: float in [-0.09, 0.09]:
					var bolt_center: Vector3 = center + frame.basis.x * (side * 0.02) + frame.basis.z * bolt
					LowPolyBuilder.add_oriented_box(st, Transform3D(frame.basis, bolt_center), Vector3(0.03, 0.035, 0.035), STEEL_SIDE)


## Begehbare Oberfläche des Schotterbetts (für die Spielfigur).
static func _collision_faces(frames: Array[Transform3D]) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for i in frames.size() - 1:
		for e in range(1, BALLAST_PROFILE.size() - 2):
			var a := _to_world(frames[i], BALLAST_PROFILE[e])
			var b := _to_world(frames[i], BALLAST_PROFILE[e + 1])
			var c := _to_world(frames[i + 1], BALLAST_PROFILE[e + 1])
			var d := _to_world(frames[i + 1], BALLAST_PROFILE[e])
			faces.append_array(PackedVector3Array([a, b, c, a, c, d]))
	return faces


static func _to_world(frame: Transform3D, p: Vector2) -> Vector3:
	return frame.origin + frame.basis.x * p.x + frame.basis.y * p.y


static func _vary(color: Color, rng: RandomNumberGenerator, amount := 0.03) -> Color:
	var v := rng.randf_range(-amount, amount)
	return Color(color.r + v, color.g + v, color.b + v)
