## Baut die Figuren im Stil der freigegebenen Charakterblätter
## (docs/character_references/): großer, weich abgerundeter Kopf mit gemaltem Gesicht
## (ovale Augen, Brauen, Dreiecksnase, Lächeln, rosa Wangen), facettierte Haare und
## Mützen, kurzer runder Körper, Stummelarme mit Fäusten, kräftige Stiefel.
##
## Ergebnis: je Gelenk ein Mesh ({"head", "torso", "hip_left", …}). Gleiche
## Erscheinungen teilen sich die Meshes (Zwischenspeicher) – viele Bewohner kosten
## so kaum zusätzlichen Speicher.
##
## Maße in Metern, Figur steht auf y = 0 und schaut nach −Z. Abgeleitet aus den
## Vorlagen: 700 px Figurenhöhe ≙ 1,45 m.
class_name CharacterStyle
extends RefCounted

const P := CharacterKit.Pattern


## Gelenkpositionen (müssen zu CharacterModel passen).
const HIP_HEIGHT := 0.33
const HIP_X := 0.135
const SHOULDER := Vector3(0.205, 0.68, 0.0)
const HEAD_Y := 1.068
## Kopf: halbe Breite, Höhe, Tiefe (Schädel ohne Ohren und Haare).
const HEAD := Vector3(0.217, 0.248, 0.225)
## Haarschale (etwas größer als der Kopf), Mitte leicht über der Kopfmitte.
const HAIR := Vector3(0.252, 0.255, 0.255)
const HAIR_LIFT := 0.018

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func build(look: CharacterAppearance, winter: bool) -> Dictionary:
	var key := look.get_signature() + ("|W" if winter else "|S")
	if _cache.has(key):
		return _cache[key]
	var style := CharacterStyle.new()
	var result := style._build(look, winter)
	_cache[key] = result
	return result


var look: CharacterAppearance
var winter := true
var head := CharacterKit.new()
var torso := CharacterKit.new()
var hips := [CharacterKit.new(), CharacterKit.new()]
var arms := [CharacterKit.new(), CharacterKit.new()]


func _build(p_look: CharacterAppearance, p_winter: bool) -> Dictionary:
	look = p_look
	winter = p_winter
	_build_legs()
	_build_torso()
	_build_arms()
	_build_head()
	return {
		"head": head.commit(), "torso": torso.commit(),
		"hip_left": hips[0].commit(), "hip_right": hips[1].commit(),
		"shoulder_left": arms[0].commit(), "shoulder_right": arms[1].commit(),
	}


# --- Farben ------------------------------------------------------------------------------

func _solid(c: Color) -> CharacterKit.Paint:
	return CharacterKit.paint(c)


func _skin() -> CharacterKit.Paint:
	return CharacterKit.paint(look.skin_color, P.SKIN)


## Stoff mit Muster aus der Erscheinung.
func _fabric(c: Color, pattern: CharacterAppearance.Pattern, c2: Color, scale := 1.0, c3 := Color(0, 0, 0, 0)) -> CharacterKit.Paint:
	match pattern:
		CharacterAppearance.Pattern.PLAID:
			return CharacterKit.paint(c, P.PLAID, 6.0 * scale, c2, c3 if c3.a > 0.0 else c2.lightened(0.5))
		CharacterAppearance.Pattern.GINGHAM:
			return CharacterKit.paint(c, P.GINGHAM, 7.0 * scale, c2)
		CharacterAppearance.Pattern.STRIPES:
			return CharacterKit.paint(c, P.STRIPES, 9.0 * scale, c2)
		CharacterAppearance.Pattern.RIBS:
			return CharacterKit.paint(c, P.RIBS, 26.0 * scale)
		CharacterAppearance.Pattern.FAIR_ISLE:
			return CharacterKit.paint(c, P.FAIR_ISLE, 1.0, c2, Color(0, 0, 0, 0.66))
		CharacterAppearance.Pattern.DIAMONDS:
			return CharacterKit.paint(c, P.DIAMONDS, 1.0, c2, Color(0, 0, 0, 0.68))
		CharacterAppearance.Pattern.QUILT:
			return CharacterKit.paint(c, P.QUILT, 14.0 * scale)
		CharacterAppearance.Pattern.TARTAN:
			return CharacterKit.paint(c, P.TARTAN, 6.0 * scale, c2, c3 if c3.a > 0.0 else c.lightened(0.3))
	return CharacterKit.paint(c)


func _darker(c: Color, amount := 0.12) -> Color:
	return c.darkened(amount)


func _brow_color() -> Color:
	var c := look.brow_color if look.brow_color.a > 0.0 else look.hair_color.darkened(0.25)
	return Color(c.r, c.g, c.b, 1.0)


# --- Beine -------------------------------------------------------------------------------

func _build_legs() -> void:
	for i in 2:
		var kit: CharacterKit = hips[i]
		var side := -1.0 if i == 0 else 1.0
		var xf := Transform3D.IDENTITY
		# Hosenbein (vom Schritt bis über das Knie), darunter Strumpf/Bein bis zum Stiefel
		var pants := _fabric(look.pants_color, look.bottom_pattern, look.bottom_color2)
		var leg_color := look.tights_color if look.tights_color.a > 0.0 else look.skin_color
		var leg := _solid(leg_color) if look.tights_color.a > 0.0 else _skin()
		match look.bottom:
			CharacterAppearance.Bottom.SHORTS:
				# Weites Hosenbein bis über das Knie, darunter ein breiter Umschlag
				kit.lathe(xf, [Vector2(0.112, -0.075), Vector2(0.118, -0.02), Vector2(0.112, 0.04)], 12, pants, true, 1.0, 0.92)
				kit.lathe(xf, [Vector2(0.116, -0.152), Vector2(0.126, -0.142), Vector2(0.128, -0.1), Vector2(0.126, -0.07),
					Vector2(0.114, -0.06)], 12, _solid(look.pants_color.lightened(0.07)), true, 1.0, 0.92, 0.0, 1.0, 0.0, true)
				kit.lathe(xf, [Vector2(0.07, -0.3), Vector2(0.075, -0.14)], 10, leg, look.tights_color.a > 0.0)
			CharacterAppearance.Bottom.TROUSERS:
				kit.lathe(xf, [Vector2(0.085, -0.2), Vector2(0.095, -0.06), Vector2(0.094, 0.02)], 12, pants)
				if look.bottom_color2.a > 0.0:
					kit.lathe(xf, [Vector2(0.092, -0.235), Vector2(0.097, -0.2), Vector2(0.092, -0.185)], 12, _solid(look.bottom_color2))
				else:
					kit.lathe(xf, [Vector2(0.088, -0.235), Vector2(0.09, -0.2)], 12, pants)
			_:
				# Rock/Kleid: nur Bein bzw. Strumpfhose
				kit.lathe(xf, [Vector2(0.066, -0.3), Vector2(0.072, -0.1), Vector2(0.08, 0.02)], 10, leg, look.tights_color.a > 0.0)
		if look.sock_color.a > 0.0:
			kit.lathe(xf, [Vector2(0.086, -0.205), Vector2(0.095, -0.18), Vector2(0.095, -0.15), Vector2(0.088, -0.135)], 12,
				CharacterKit.paint(look.sock_color, P.KNIT_CUFF, 22.0))
		_build_shoe(kit, side)


func _build_shoe(kit: CharacterKit, _side: float) -> void:
	var leather := _solid(look.shoe_color)
	var sole := _solid(look.shoe_color.darkened(0.45))
	var y0 := -HIP_HEIGHT
	match look.shoes:
		CharacterAppearance.Shoes.MARY_JANES, CharacterAppearance.Shoes.LOAFERS:
			kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, y0 + 0.055, -0.035)), Vector3(0.088, 0.06, 0.13), 10, 6, leather,
				true, 0.0, 0.75)
			kit.lathe(Transform3D(Basis.IDENTITY, Vector3(0, y0, -0.035)), [Vector2(0.085, 0.0), Vector2(0.09, 0.025)], 10, sole,
				true, 1.0, 1.45, 0.0, 1.0, 0.0, true)
			if look.shoes == CharacterAppearance.Shoes.MARY_JANES:
				kit.box(Transform3D(Basis.IDENTITY, Vector3(0, y0 + 0.1, -0.06)), Vector3(0.17, 0.02, 0.03), leather)
			else:
				kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.07 * _side, y0 + 0.07, -0.02)), Vector3(0.016, 0.016, 0.01), 6, 3,
					CharacterKit.paint(look.accent_color, P.GLOSS))
		_:
			# Stiefel: Schaft, runde Kappe vorne, dunkle Sohle, kleiner Umschlag oben
			kit.lathe(Transform3D(Basis.IDENTITY, Vector3(0, y0, 0)),
				[Vector2(0.092, 0.03), Vector2(0.095, 0.09), Vector2(0.092, 0.15), Vector2(0.094, 0.178)], 12, leather,
				true, 1.0, 1.05, 0.0, 1.0, 0.0, false, true)
			kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, y0 + 0.055, -0.06)), Vector3(0.094, 0.07, 0.125), 10, 7, leather,
				true, 0.0, 0.8)
			kit.lathe(Transform3D(Basis.IDENTITY, Vector3(0, y0, -0.035)), [Vector2(0.095, 0.0), Vector2(0.098, 0.03)], 12, sole,
				true, 1.0, 1.5, 0.0, 1.0, 0.0, true)
			if look.shoes == CharacterAppearance.Shoes.LACED_BOOTS:
				for k in 2:
					var y := y0 + 0.085 + k * 0.035
					kit.box(Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0, y, -0.105 + k * 0.01)), Vector3(0.07, 0.012, 0.012),
						_solid(Color(0.86, 0.76, 0.58)))
					kit.box(Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(0, y, -0.105 + k * 0.01)), Vector3(0.07, 0.012, 0.012),
						_solid(Color(0.86, 0.76, 0.58)))


# --- Rumpf -------------------------------------------------------------------------------

## Grundform des Rumpfs (Radius, Höhe) von der Hüfte bis zum Hals.
const TORSO := [Vector2(0.2, 0.3), Vector2(0.24, 0.35), Vector2(0.245, 0.43), Vector2(0.232, 0.51), Vector2(0.222, 0.58),
	Vector2(0.208, 0.645), Vector2(0.18, 0.7), Vector2(0.125, 0.745), Vector2(0.09, 0.775)]
const TORSO_DEPTH := 0.72


## Rumpfprofil zwischen zwei Höhen (für Kleidungsteile, die genau anliegen).
static func torso_profile(from_y: float, to_y: float, steps := 6) -> Array:
	var result: Array = []
	for i in steps + 1:
		var y := lerpf(from_y, to_y, float(i) / steps)
		result.append(Vector2(torso_radius(y), y))
	return result


static func torso_radius(y: float) -> float:
	if y <= TORSO[0].y:
		return TORSO[0].x
	for i in TORSO.size() - 1:
		if y <= TORSO[i + 1].y:
			var a: Vector2 = TORSO[i]
			var b: Vector2 = TORSO[i + 1]
			var t := (y - a.y) / (b.y - a.y)
			return lerpf(a.x, b.x, smoothstep(0.0, 1.0, t) * 0.5 + t * 0.5)
	return TORSO[-1].x


## Punkt auf der Rumpfoberfläche: Winkel 0 = vorne, 0.25 = rechts (von der Figur aus links).
static func torso_point(angle: float, y: float, offset := 0.0) -> Vector3:
	var r := torso_radius(y) + offset
	var a := angle * TAU
	return Vector3(sin(a) * r, y, -cos(a) * r * TORSO_DEPTH)


static func torso_normal(angle: float) -> Vector3:
	var a := angle * TAU
	return Vector3(sin(a), 0.0, -cos(a) / TORSO_DEPTH).normalized()


func _build_torso() -> void:
	var xf := Transform3D.IDENTITY
	var shirt := _fabric(look.shirt_color, look.shirt_pattern, look.shirt_stripe_color, 1.0, look.shirt_line_color)
	if look.top_style == CharacterAppearance.TopStyle.TURTLENECK and look.shirt_pattern == CharacterAppearance.Pattern.SOLID:
		shirt = CharacterKit.paint(look.shirt_color, P.RIBS, 30.0)
	torso.lathe(xf, TORSO, 18, shirt, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.0, true, true)
	_build_neckline()
	_build_waist()
	_build_outer()


## Halsabschluss. Höhe des Halses: Vorlage Kragen bei 480–525 px.
const NECK_Y := 0.762


func _build_neckline() -> void:
	match look.top_style:
		CharacterAppearance.TopStyle.TURTLENECK:
			# Dicker, gerollter Rollkragen, der breit auf den Schultern liegt
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y, 0)), 0.1, 0.048, 18, 7,
				CharacterKit.paint(look.shirt_color.darkened(0.02), P.KNIT_CUFF, 34.0), 1.0, 0.88, 0.95)
		CharacterAppearance.TopStyle.COLLAR_SHIRT, CharacterAppearance.TopStyle.PLAID_SHIRT, CharacterAppearance.TopStyle.BLOUSE:
			# Hemdkragen: zwei Spitzen vorne, flach auf den Schultern
			var collar_color := look.shirt_color if look.top_style == CharacterAppearance.TopStyle.PLAID_SHIRT else look.shirt_color.lightened(0.04)
			var collar := _solid(collar_color)
			for side: float in [-1.0, 1.0]:
				var a := torso_point(0.025 * side, NECK_Y + 0.008, 0.01)
				var b := torso_point(0.12 * side, NECK_Y - 0.012, 0.012)
				var tip := torso_point(0.05 * side, NECK_Y - 0.075, 0.018)
				torso.triangle(a, b, tip, collar, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
					torso_normal(0.05 * side) + Vector3.UP * 0.5)
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y, 0)), 0.085, 0.022, 14, 5, collar, 1.0, 0.9)
		_:
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y, 0)), 0.085, 0.022, 14, 5, _solid(look.shirt_color.darkened(0.08)), 1.0, 0.9)


## Taille (Hosenbund), Vorlage bei 650 px.
const WAIST_Y := 0.447


## Hosenbund: Hose bzw. Rock reicht bis zur Taille.
func _build_waist() -> void:
	if look.outer in [CharacterAppearance.Outer.OVERALLS, CharacterAppearance.Outer.PINAFORE, CharacterAppearance.Outer.KNIT_DRESS,
			CharacterAppearance.Outer.DRESS_APRON, CharacterAppearance.Outer.LONG_COAT, CharacterAppearance.Outer.DUFFLE_COAT,
			CharacterAppearance.Outer.PARKA]:
		return
	var pants := _fabric(look.pants_color, look.bottom_pattern, look.bottom_color2)
	match look.bottom:
		CharacterAppearance.Bottom.SHORTS, CharacterAppearance.Bottom.TROUSERS:
			torso.lathe(Transform3D.IDENTITY, _hip_profile(WAIST_Y), 18, pants, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.012, true)
		CharacterAppearance.Bottom.SKIRT, CharacterAppearance.Bottom.LONG_SKIRT:
			_skirt(look.bottom == CharacterAppearance.Bottom.LONG_SKIRT, pants, WAIST_Y)


## Hosenteil am Rumpf: unten weit (Schritt), oben bis [param top].
func _hip_profile(top: float) -> Array:
	var profile: Array = [Vector2(0.06, 0.262), Vector2(0.17, 0.275), Vector2(0.225, 0.295), Vector2(0.245, 0.325)]
	profile.append_array(torso_profile(0.35, top, 3))
	return profile


func _skirt(long: bool, paint: CharacterKit.Paint, top: float) -> void:
	var hem := 0.09 if long else 0.2
	var flare := 0.36 if long else 0.33
	torso.lathe(Transform3D.IDENTITY, [Vector2(flare, hem), Vector2(flare - 0.03, hem + 0.06), Vector2(0.27, 0.3),
		Vector2(torso_radius(top) + 0.012, top)], 20, paint, true, 1.0, 0.86, 0.0, 1.0, 0.0, true)


## Überkleidung (Latzhose, Westen, Jacken, Schürzen, Kleider …).
func _build_outer() -> void:
	match look.outer:
		CharacterAppearance.Outer.OVERALLS:
			_overalls()


## Latzhose: Hosenteil, Latz mit großer Brusttasche, Träger mit Messingknöpfen,
## Seiten- und Gesäßtaschen (Maße aus der Vorlage player_male).
func _overalls() -> void:
	var cloth := _fabric(look.outer_color, look.outer_pattern, look.outer_color2)
	var seam := _solid(look.outer_color.darkened(0.3))
	var xf := Transform3D.IDENTITY
	torso.lathe(xf, _hip_profile(WAIST_Y), 18, cloth, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.014, true)
	# Latz vorne (bis 0,665 m) und Brusttasche
	torso.panel(xf, torso_profile(WAIST_Y - 0.01, 0.665, 3), 6, cloth, 1.0, TORSO_DEPTH, -0.115, 0.115, 0.014, 0.012, seam)
	var pocket := _solid(look.outer_color.lightened(0.05))
	torso.panel(xf, torso_profile(0.475, 0.6, 2), 4, pocket, 1.0, TORSO_DEPTH, -0.075, 0.075, 0.026, 0.016, seam)
	# Seitentaschen (Schlitz) und Gesäßtaschen
	for side: float in [-1.0, 1.0]:
		torso.panel(xf, torso_profile(0.36, 0.43, 2), 3, cloth, 1.0, TORSO_DEPTH,
			side * 0.16 - 0.04, side * 0.16 + 0.04, 0.016, 0.008, seam)
		torso.panel(xf, torso_profile(0.34, 0.43, 2), 3, cloth, 1.0, TORSO_DEPTH,
			0.5 + side * 0.075 - 0.045, 0.5 + side * 0.075 + 0.045, 0.016, 0.01, seam)
	# Träger: von den Latzecken über die Schultern gerade nach hinten zum Bund
	for side: float in [-1.0, 1.0]:
		var points: Array = []
		var outward: Array = []
		var front_angle := side * 0.095
		var back_angle := 0.5 - side * 0.085
		for y: float in [0.64, 0.69, 0.72]:
			points.append(torso_point(front_angle, y, 0.024))
			outward.append(torso_normal(front_angle))
		points.append(Vector3(side * 0.14, 0.752, -0.045))
		outward.append(Vector3.UP + torso_normal(front_angle))
		points.append(Vector3(side * 0.14, 0.756, 0.04))
		outward.append(Vector3.UP + torso_normal(back_angle))
		for y: float in [0.72, 0.66, 0.56, WAIST_Y]:
			points.append(torso_point(back_angle, y, 0.022))
			outward.append(torso_normal(back_angle))
		torso.strip(points, outward, 0.05, 0.012, cloth, seam)
		var button_at := torso_point(side * 0.095, 0.625, 0.04)
		torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(side * 0.095)), button_at), Vector3(0.024, 0.024, 0.012), 10, 5,
			CharacterKit.paint(look.accent_color, P.GLOSS))


# --- Arme --------------------------------------------------------------------------------

## Hand in der Vorlage bei 670 px (0,405 m), Schulter bei 0,68 m.
const HAND_Y := -0.272


func _build_arms() -> void:
	for i in 2:
		var kit: CharacterKit = arms[i]
		var sleeve := _fabric(look.shirt_color, look.shirt_pattern, look.shirt_stripe_color, 0.6, look.shirt_line_color)
		if look.top_style == CharacterAppearance.TopStyle.TURTLENECK and look.shirt_pattern == CharacterAppearance.Pattern.SOLID:
			sleeve = CharacterKit.paint(look.shirt_color, P.RIBS, 14.0)
		var xf := Transform3D.IDENTITY
		match look.sleeves:
			CharacterAppearance.Sleeves.ROLLED:
				# Weiter Ärmel mit dickem, hochgekrempeltem Wulst über dem Unterarm
				kit.lathe(xf, [Vector2(0.064, -0.13), Vector2(0.068, -0.06), Vector2(0.07, 0.0), Vector2(0.055, 0.05), Vector2(0.0, 0.065)],
					10, sleeve)
				kit.lathe(xf, [Vector2(0.07, -0.19), Vector2(0.088, -0.18), Vector2(0.092, -0.14), Vector2(0.085, -0.115),
					Vector2(0.074, -0.11)], 10, _solid(look.shirt_color.lightened(0.02)), true, 1.0, 1.0, 0.0, 1.0, 0.0, true)
				kit.lathe(xf, [Vector2(0.05, -0.24), Vector2(0.054, -0.18)], 10, _skin(), false)
			CharacterAppearance.Sleeves.PUFF:
				kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, -0.07, 0)), Vector3(0.095, 0.12, 0.09), 10, 6, sleeve)
				kit.lathe(xf, [Vector2(0.06, -0.215), Vector2(0.066, -0.17), Vector2(0.074, -0.11)], 10, sleeve)
				kit.torus(Transform3D(Basis.IDENTITY, Vector3(0, -0.205, 0)), 0.055, 0.02, 10, 5, _solid(look.shirt_color.darkened(0.05)))
			_:
				kit.lathe(xf, [Vector2(0.062, -0.2), Vector2(0.07, -0.08), Vector2(0.078, 0.0), Vector2(0.06, 0.05), Vector2(0.0, 0.07)],
					10, sleeve)
				kit.lathe(xf, [Vector2(0.06, -0.225), Vector2(0.066, -0.195)], 10,
					CharacterKit.paint(look.shirt_color.darkened(0.05), P.KNIT_CUFF, 18.0))
		_build_hand(kit, -1.0 if i == 0 else 1.0, HAND_Y)


## Faust (bloße Hand) bzw. Fäustling mit Daumen.
func _build_hand(kit: CharacterKit, side: float, y: float) -> void:
	var mittens := winter and look.mitten_color.a > 0.0
	if mittens:
		var m := _solid(look.mitten_color)
		kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, y, -0.005)), Vector3(0.07, 0.078, 0.064), 10, 7, m)
		kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(-side * 0.048, y + 0.012, -0.03)), Vector3(0.03, 0.042, 0.028), 6, 4, m)
		if look.mitten_cuff_color.a > 0.0:
			kit.lathe(Transform3D.IDENTITY, [Vector2(0.062, y + 0.045), Vector2(0.07, y + 0.06), Vector2(0.07, y + 0.095),
				Vector2(0.064, y + 0.105)], 10, CharacterKit.paint(look.mitten_cuff_color, P.KNIT_CUFF, 16.0))
		return
	var skin := _skin()
	kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, y, -0.004)), Vector3(0.07, 0.074, 0.064), 12, 8, skin, false)
	kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(-side * 0.043, y + 0.014, -0.03)), Vector3(0.026, 0.036, 0.026), 8, 5, skin, false)


# --- Kopf --------------------------------------------------------------------------------

func _build_head() -> void:
	var face := CharacterKit.paint(look.skin_color, P.FACE, 1.0, Color(_brow_color(), 1.0),
		Color(0, 0, 0, 1.0 if look.freckles else 0.0))
	head.head_shape(Transform3D.IDENTITY, HEAD, 28, 18, face)
	# Ohren
	for side: float in [-1.0, 1.0]:
		# Große, abstehende Ohren auf Augenhöhe (Vorlage: 60 px breit, Mitte 0,27 m neben der Kopfmitte)
		head.ellipsoid(Transform3D(Basis(Vector3.UP, side * 0.35), Vector3(side * 0.222, -0.135, 0.03)),
			Vector3(0.05, 0.062, 0.046), 12, 8, _skin(), false)
		head.ellipsoid(Transform3D(Basis(Vector3.UP, side * 0.35), Vector3(side * 0.256, -0.135, 0.018)),
			Vector3(0.014, 0.036, 0.028), 8, 5, CharacterKit.paint(look.skin_color.darkened(0.1), P.SKIN), false)
	# Nase: kleine dreiseitige Pyramide, Spitze nach vorne, eine Ecke unten
	head.pyramid(Transform3D(Basis.IDENTITY, Vector3(0, -0.119, -HEAD.z + 0.008)), 0.025, 0.03, 3,
		_solid(Color(0.91, 0.43, 0.34)), PI)
	_build_hair()


# --- Haare -------------------------------------------------------------------------------

## Punkt und Normale auf der Haarschale (Azimut 0 = vorne, positiv = rechts; Höhe in Grad).
func _hair_point(az: float, el: float, scale := 1.0) -> Array:
	var a := deg_to_rad(az)
	var e := deg_to_rad(el)
	var r := HAIR * scale
	var p := Vector3(sin(a) * cos(e) * r.x, sin(e) * r.y + HAIR_LIFT, -cos(a) * cos(e) * r.z)
	var n := Vector3(sin(a) * cos(e) / r.x, sin(e) / r.y, -cos(a) * cos(e) / r.z).normalized()
	return [p, n]


## Haarbüschel auf der Schale: hängt die Oberfläche hinab (oder steht ab: [param lift]).
func _tuft(az: float, el: float, length: float, width: float, paint: CharacterKit.Paint, lift := 0.25,
		twist := 0.0, depth := 0.6, scale := 1.0) -> void:
	var pn := _hair_point(az, el, scale)
	var p: Vector3 = pn[0]
	var n: Vector3 = pn[1]
	# Richtung "bergab" entlang der Schale
	var down := (Vector3.DOWN - n * n.dot(Vector3.DOWN))
	if down.length() < 0.05:
		down = Vector3(sin(deg_to_rad(az)), 0, -cos(deg_to_rad(az)))
	down = down.normalized()
	var tip_dir := (down * cos(lift) + n * sin(lift)).normalized()
	if absf(twist) > 0.0:
		tip_dir = tip_dir.rotated(n, twist)
	var y_axis := -tip_dir
	var z_axis := n
	var x_axis := y_axis.cross(z_axis).normalized()
	z_axis = x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis)
	head.chunk(Transform3D(basis, p + n * width * depth * 0.15), width, width * depth, length, paint, 5, 0.3)


## Haarschuppe auf der Schale (Tannenzapfen-Haar der Vorlagen): liegt flach auf, Spitze
## zeigt die Oberfläche hinab; [param lift] hebt die Spitze leicht ab (Bogenmaß).
func _scale(az: float, el: float, width: float, length: float, paint: CharacterKit.Paint, lift := 0.18,
		scale := 1.0, thick := 0.8, droop := 0.0) -> void:
	var pn := _hair_point(az, el, scale)
	var p: Vector3 = pn[0]
	var n: Vector3 = pn[1]
	var down := (Vector3.DOWN - n * n.dot(Vector3.DOWN))
	if down.length() < 0.05:
		down = Vector3(sin(deg_to_rad(az)), 0, -cos(deg_to_rad(az)))
	down = down.normalized()
	var tip_dir := (down * cos(lift) + n * sin(lift)).normalized()
	# Hängende Strähnen (Pony): Richtung zum Lot hin biegen
	tip_dir = tip_dir.lerp(Vector3.DOWN, droop).normalized()
	var y_axis := -tip_dir
	var x_axis := y_axis.cross(n).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	head.scale_tuft(Transform3D(Basis(x_axis, y_axis, z_axis), p + n * width * thick * 0.18), width, length, width * thick, paint)


## Haarkappe: facettierte Schale, vorne höher geschnitten (Gesicht frei).
func _hair_cap(paint: CharacterKit.Paint, front_cut := 25.0, back_low := 0.2, scale := 0.97, y_scale := 1.0) -> void:
	var r := HAIR * scale * Vector3(1.0, y_scale, 1.0)
	# Vorne hochgezogen: positive Neigung um X kippt die Kappe nach hinten (Unterkante vorne höher)
	var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(front_cut)), Vector3(0, HAIR_LIFT, 0.035))
	head.ellipsoid(xf, r, 14, 8, paint, true, back_low, 1.0)


func _build_hair() -> void:
	var hat := look.hat_style if winter or look.hat_style in [CharacterAppearance.HatStyle.STRAW_HAT, CharacterAppearance.HatStyle.CHEF_HAT,
		CharacterAppearance.HatStyle.BUCKET_HAT, CharacterAppearance.HatStyle.BERET, CharacterAppearance.HatStyle.FLAT_CAP, CharacterAppearance.HatStyle.HEADSCARF] else CharacterAppearance.HatStyle.NONE
	var hair := _solid(look.hair_color)
	var hair_dark := _solid(look.hair_color.darkened(0.16))
	match look.hair_style:
		CharacterAppearance.HairStyle.SPIKY:
			# Strubbelkopf (player_male): runde, facettierte Schuppen wie ein Tannenzapfen,
			# seitlich über dem Ohr (Kotelette davor), hinten bis in den Nacken; dicker Pony
			# bis knapp über die Brauen, eine Strähne rechts der Mitte länger; Spitze oben.
			_hair_cap(hair_dark, 16.0, 0.5, 0.94, 1.0)
			# Hinterkopf: Reihen von oben nach unten (untere zuerst, damit obere darüber liegen)
			var rows := [[-38.0, 3, 0.17, 0.19, 26.0], [-14.0, 4, 0.21, 0.23, 44.0], [12.0, 4, 0.24, 0.26, 58.0],
				[36.0, 4, 0.25, 0.27, 70.0], [58.0, 3, 0.22, 0.24, 84.0]]
			for row: Array in rows:
				var count: int = row[1]
				var spread: float = row[4]
				for k in count:
					var az := 180.0 + (float(k) - (count - 1) * 0.5) * (spread * 2.0 / maxf(count - 1, 1))
					if float(row[0]) > 40.0:
						az += 15.0
					_scale(az, row[0], row[2], row[3], hair if (k % 2) == 0 else hair_dark, 0.34, 1.0)
			# Seiten: über dem Ohr, hinter dem Ohr bis zum Nacken
			for side: float in [-1.0, 1.0]:
				_scale(side * 128.0, -2.0, 0.17, 0.21, hair_dark, 0.25, 1.0)
				_scale(side * 104.0, 30.0, 0.22, 0.25, hair, 0.38, 1.02)
				_scale(side * 78.0, 38.0, 0.21, 0.24, hair_dark, 0.32, 1.02)
				_scale(side * 64.0, 8.0, 0.075, 0.16, hair_dark, 0.04, 0.98, 0.7)
			# Pony
			var bangs := [[-48.0, 34.0, 0.2, 0.28], [-20.0, 38.0, 0.21, 0.3], [10.0, 38.0, 0.21, 0.36], [38.0, 34.0, 0.2, 0.28]]
			for b: Array in bangs:
				_scale(b[0], b[1], b[2], b[3], hair_dark if int(b[0]) == 10 else hair, 0.0, 1.0, 0.85, 0.75)
			# Krone
			for az: float in [-30.0, 40.0, 110.0, 250.0]:
				_scale(az, 68.0, 0.2, 0.22, hair, 0.12, 1.0)
			# Aufrechte Spitze oben, leicht zur Seite geneigt
			var tip := Transform3D(Basis(Vector3.FORWARD, PI + 0.35) * Basis(Vector3.RIGHT, 0.2), Vector3(-0.03, 0.34, -0.02))
			head.scale_tuft(tip, 0.13, 0.2, 0.09, hair)
		CharacterAppearance.HairStyle.FRINGE:
			# Glattes Haar (player_female): Kappe bis in den Nacken (unten etwas ausgestellt),
			# Pony mit Seitenscheitel (große Strähne über dem rechten Auge), je eine lange
			# Strähne vor dem Ohr bis unters Kinn. Unter einem Kopftuch bleibt nur das sichtbar.
			# Kappe hinten tief bis in den Nacken (unter dem Tuch rund statt kantig)
			_hair_cap(hair, 10.0, 0.16, 1.0, 1.0)
			var fringe := [[-48.0, 16.0, 0.22, 0.22], [-18.0, 20.0, 0.21, 0.24], [14.0, 20.0, 0.26, 0.3], [46.0, 16.0, 0.22, 0.22]]
			for f: Array in fringe:
				_scale(f[0], f[1], f[2], f[3], hair_dark if int(f[0]) == 14 else hair, -0.15, 0.97, 0.34, 0.45)
			# Seitliches Volumen unter dem Tuch: rahmt das Gesicht bis über die Ohren
			for side: float in [-1.0, 1.0]:
				for k in 3:
					_scale(side * (78.0 + k * 26.0), 6.0 - k * 4.0, 0.22, 0.24, hair if k % 2 == 0 else hair_dark, 0.12, 1.07, 0.6)
			for side: float in [-1.0, 1.0]:
				var root: Array = _hair_point(side * 64.0, 4.0, 1.0)
				var p: Vector3 = root[0]
				head.scale_tuft(Transform3D(Basis(Vector3.UP, side * 0.95), p + Vector3(side * 0.012, -0.14, -0.005)),
					0.075, 0.3, 0.055, hair_dark)
	_build_hair_extra(hair, hair_dark)
	_build_hat(hat)


func _build_hair_extra(hair: CharacterKit.Paint, _hair_dark: CharacterKit.Paint) -> void:
	match look.hair_extra:
		CharacterAppearance.HairExtra.BUN_TOP:
			# Dutt oben am Hinterkopf
			head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.03, 0.34, 0.12)), Vector3(0.125, 0.115, 0.12), 10, 7, hair)
		CharacterAppearance.HairExtra.BUN_BACK:
			head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.27)), Vector3(0.1, 0.095, 0.085), 10, 7, hair)
		CharacterAppearance.HairExtra.TWIN_BUNS:
			for side: float in [-1.0, 1.0]:
				head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(side * 0.22, 0.2, 0.1)), Vector3(0.085, 0.085, 0.08), 10, 6, hair)
		CharacterAppearance.HairExtra.LOW_TAIL:
			head.scale_tuft(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.1, 0.27)), 0.12, 0.28, 0.1, hair)


# --- Kopfbedeckungen --------------------------------------------------------------------

func _build_hat(hat: CharacterAppearance.HatStyle) -> void:
	var cloth := _fabric(look.hat_color, look.hat_pattern, look.hat_color2)
	match hat:
		CharacterAppearance.HatStyle.HEADSCARF:
			# Kopftuch (player_female): Band über Scheitel und Hinterkopf – vorne sieht der
			# Pony darunter hervor, seitlich die Haare bis knapp über dem Ohr, hinten reicht
			# es bis zum Nacken und ist rechts unten verknotet (zwei Zipfel).
			var shell := HAIR * Vector3(1.1, 1.06, 1.12)
			# 26°: Vorderrand über der Stirn (y ≈ 0,1), hinten unter der Ohroberkante
			var band := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(26.0)), Vector3(0, HAIR_LIFT + 0.03, 0.02))
			head.ellipsoid(band, shell, 18, 10, cloth, true, 0.43, 0.94)
			# Gerollter Saum am Tuchrand
			var rim_y := -cos(PI * 0.43)
			var rim_r := sin(PI * 0.43)
			head.torus(band * Transform3D(Basis.IDENTITY, Vector3(0, shell.y * rim_y, 0)), shell.x * rim_r * 0.99, 0.017, 24, 6, cloth,
				1.0, shell.z / shell.x)
			var knot_at := Vector3(0.13, -0.03, 0.26)
			head.ellipsoid(Transform3D(Basis.IDENTITY, knot_at), Vector3(0.058, 0.052, 0.045), 8, 6, cloth)
			head.scale_tuft(Transform3D(Basis(Vector3.FORWARD, 1.2) * Basis(Vector3.RIGHT, -0.3), knot_at + Vector3(-0.1, -0.04, 0.02)),
				0.12, 0.22, 0.045, cloth)
			head.scale_tuft(Transform3D(Basis(Vector3.FORWARD, -2.0) * Basis(Vector3.RIGHT, -0.3), knot_at + Vector3(0.08, -0.03, 0.01)),
				0.09, 0.16, 0.04, cloth)
