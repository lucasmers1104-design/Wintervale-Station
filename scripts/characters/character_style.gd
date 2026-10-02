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
## Haarschuppen über dieser Höhe (Grad) entfallen, wenn eine Mütze darüber sitzt.
var _hat_clip := 999.0
## Längenfaktor für Pony-Schuppen, die unter der Kopfbedeckung hervorschauen.
var _hat_bang := 1.0
## Schräge Mützenkante (Schiebermütze): Höhe der Kante = x + y·cos(Azimut). Ist sie
## gesetzt, hängt die Kappungshöhe der Haarschuppen vom Azimut ab.
var _hat_rim := Vector2.ZERO
## Schuppen weit über der Kante ganz weglassen (Schiebermütze: Krone unter der Kuppel).
var _hat_skip_crown := false
## Schuppen bis so weit (Grad) über der schrägen Kante werden unter die Kante geschoben, höhere entfallen.
var _hat_rim_keep := 25.0


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
			return CharacterKit.paint(c, P.STRIPES, 13.0 * scale, c2)
		CharacterAppearance.Pattern.RIBS:
			return CharacterKit.paint(c, P.RIBS, 26.0 * scale)
		CharacterAppearance.Pattern.FAIR_ISLE:
			return CharacterKit.paint(c, P.FAIR_ISLE, 16.0 * scale, c2, Color(0, 0, 0, c3.a if c3.a != 0.0 else 0.6))
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
					Vector2(0.114, -0.06)], 12, _solid(look.bottom_color2 if look.bottom_color2.a > 0.0 else look.pants_color.lightened(0.07)),
					true, 1.0, 0.92, 0.0, 1.0, 0.0, true)
				kit.lathe(xf, [Vector2(0.07, -0.3), Vector2(0.075, -0.14)], 10, leg, look.tights_color.a > 0.0)
			CharacterAppearance.Bottom.TROUSERS:
				kit.lathe(xf, [Vector2(0.085, -0.2), Vector2(0.095, -0.06), Vector2(0.094, 0.02)], 12, pants)
				if look.wide_cuff:
					# Breiter Aufschlag (Vorlage satchel_boy: 0,1–0,18 m über dem Boden)
					kit.lathe(xf, [Vector2(0.096, -0.235), Vector2(0.108, -0.228), Vector2(0.11, -0.165), Vector2(0.1, -0.152),
						Vector2(0.092, -0.15)], 12, _solid(look.bottom_color2 if look.bottom_color2.a > 0.0 else look.pants_color.lightened(0.1)),
						true, 1.0, 1.0, 0.0, 1.0, 0.0, true)
				elif look.bottom_color2.a > 0.0:
					kit.lathe(xf, [Vector2(0.092, -0.235), Vector2(0.097, -0.2), Vector2(0.092, -0.185)], 12, _solid(look.bottom_color2))
				else:
					kit.lathe(xf, [Vector2(0.088, -0.235), Vector2(0.09, -0.2)], 12, pants)
			_:
				# Rock/Kleid: nur Bein bzw. Strumpfhose
				kit.lathe(xf, [Vector2(0.066, -0.3), Vector2(0.072, -0.1), Vector2(0.08, 0.02)], 10, leg, look.tights_color.a > 0.0)
		if look.sock_color.a > 0.0:
			if look.shoes in [CharacterAppearance.Shoes.BOOTS, CharacterAppearance.Shoes.LACED_BOOTS]:
				# Dicker Strickrand über dem Stiefelschaft (winter_girl: 0,14–0,19 m über dem Boden)
				kit.lathe(xf, [Vector2(0.09, -0.195), Vector2(0.104, -0.19), Vector2(0.108, -0.155), Vector2(0.098, -0.142),
					Vector2(0.085, -0.14)], 12, CharacterKit.paint(look.sock_color, P.KNIT_CUFF, 22.0), true, 1.0, 1.05, 0.0, 1.0, 0.0, true)
			else:
				# Kniestrumpf bzw. Söckchen mit umgeschlagenem Rand (Vorlage baker: bis 0,11 m)
				kit.lathe(xf, [Vector2(0.074, -0.3), Vector2(0.078, -0.25)], 10, _solid(look.sock_color))
				kit.lathe(xf, [Vector2(0.078, -0.25), Vector2(0.088, -0.245), Vector2(0.09, -0.22), Vector2(0.083, -0.21)], 12,
					CharacterKit.paint(look.sock_color, P.KNIT_CUFF, 22.0), true, 1.0, 1.0, 0.0, 1.0, 0.0, false, true)
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
	if look.top_style == CharacterAppearance.TopStyle.SWEATER and look.shirt_pattern == CharacterAppearance.Pattern.SOLID:
		shirt = CharacterKit.paint(look.shirt_color, P.RIBS, 30.0)
	if look.top_style == CharacterAppearance.TopStyle.TURTLENECK and look.shirt_pattern == CharacterAppearance.Pattern.SOLID:
		shirt = CharacterKit.paint(look.shirt_color, P.RIBS, 30.0)
	torso.lathe(xf, TORSO, 18, shirt, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.0, true, true)
	if look.top_style == CharacterAppearance.TopStyle.SWEATER:
		# Strickpulli (winter_girl): langer Rippbund über der Hüfte
		torso.lathe(xf, [Vector2(0.262, 0.31), Vector2(0.27, 0.325), Vector2(0.268, 0.39), Vector2(0.258, 0.4)], 20,
			CharacterKit.paint(look.shirt_color.darkened(0.03), P.KNIT_CUFF, 40.0), true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.0, true)
	_build_neckline()
	_build_scarf()
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
		CharacterAppearance.TopStyle.BLOUSE, CharacterAppearance.TopStyle.DRESS:
			# Bubikragen mit Bogenkante (bow_girl): zwölf flache Bögen rundum auf den
			# Schultern (Vorlage: 0,70–0,77 m hoch, ±0,145 m breit), vorne mittig geteilt;
			# zwei braune Knöpfe darunter
			# Kleid (baker): sechs große, runde Kragenlappen in shirt_line_color, keine Knöpfe
			var dress := look.top_style == CharacterAppearance.TopStyle.DRESS
			var collar := _solid(look.shirt_line_color if dress and look.shirt_line_color.a > 0.0 else look.shirt_color.lightened(0.12))
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y, 0)), 0.085, 0.022, 14, 5, collar, 1.0, 0.9)
			var count := 2 if dress else 12
			for k in count:
				var t := (float(k) + 0.5) / count
				if dress:
					# nur zwei runde Lappen vorne, hinten liegt der Kragen als Band an
					t = -0.055 if k == 0 else 0.055
				var n := torso_normal(t)
				var out := (n + Vector3.UP * 0.35).normalized()
				var x_axis := Vector3.UP.cross(n).normalized()
				var y_axis := out.cross(x_axis).normalized()
				var size := 0.7 + 0.3 * absf(cos(t * TAU))
				if dress:
					size = 1.0
				torso.ellipsoid(Transform3D(Basis(x_axis, y_axis, out), torso_point(t, 0.712, 0.026)), Vector3(0.058, 0.05, 0.014) * size,
					12, 6, collar)
			for k in (3 if look.outer_open else (0 if dress else 2)):
				var y := NECK_Y - 0.055 - k * 0.05
				torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(0.0)), torso_point(0.0, y, 0.01)), Vector3(0.016, 0.016, 0.008),
					6, 3, _solid(look.shirt_color.darkened(0.45).lerp(Color(0.45, 0.26, 0.14), 0.6)))
		CharacterAppearance.TopStyle.COLLAR_SHIRT, CharacterAppearance.TopStyle.PLAID_SHIRT:
			# Hemdkragen: zwei dicke Kragenflügel vorne (Vorlage: vom Hals bis 0,68 m, Spitzen
			# 0,07 m neben der Mitte), Kante etwas dunkler, damit der Kragen sich abhebt
			var collar_color := look.shirt_color if look.top_style == CharacterAppearance.TopStyle.PLAID_SHIRT else look.shirt_color.lightened(0.04)
			var collar := _solid(collar_color)
			var collar_edge := _solid(collar_color.darkened(0.18))
			for side: float in [-1.0, 1.0]:
				var corners: Array[Vector3] = [torso_point(0.012 * side, NECK_Y + 0.014, 0.012),
					torso_point(0.15 * side, NECK_Y - 0.004, 0.014), torso_point(0.065 * side, NECK_Y - 0.1, 0.02)]
				var up := torso_normal(0.06 * side) * 0.022
				torso.triangle(corners[0] + up, corners[1] + up, corners[2] + up, collar, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
					Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, torso_normal(0.06 * side) + Vector3.UP * 0.4)
				var mid := (corners[0] + corners[1] + corners[2]) / 3.0
				for k in 3:
					var p0: Vector3 = corners[k]
					var p1: Vector3 = corners[(k + 1) % 3]
					torso.quad(p0, p1, p1 + up, p0 + up, collar_edge, Rect2(0, 0, 1, 1), (p0 + p1) * 0.5 - mid)
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y, 0)), 0.085, 0.022, 14, 5, collar, 1.0, 0.9)
			# Knopfleiste
			for k in 3:
				var y := NECK_Y - 0.105 - k * 0.05
				torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(0.0)), torso_point(0.0, y, 0.01)), Vector3(0.016, 0.016, 0.008),
					6, 3, _solid(look.shirt_color.darkened(0.45).lerp(Color(0.45, 0.26, 0.14), 0.6)))
		_:
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y, 0)), 0.085, 0.022, 14, 5, _solid(look.shirt_color.darkened(0.08)), 1.0, 0.9)


## Taille (Hosenbund), Vorlage bei 650 px.
const WAIST_Y := 0.447


## Hosenbund: Hose bzw. Rock reicht bis zur Taille.
func _build_waist() -> void:
	if look.outer in [CharacterAppearance.Outer.SUSPENDERS, CharacterAppearance.Outer.OVERALLS, CharacterAppearance.Outer.PINAFORE, CharacterAppearance.Outer.KNIT_DRESS,
			CharacterAppearance.Outer.LONG_COAT, CharacterAppearance.Outer.DUFFLE_COAT, CharacterAppearance.Outer.PARKA]:
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
	var profile := _skirt_profile(long, top)
	torso.lathe(Transform3D.IDENTITY, profile, 20, paint, true, 1.0, 0.86, 0.0, 1.0, 0.0, true)
	# Zierstreifen über dem Saum (baker)
	if look.bottom_color2.a > 0.0:
		var hem: float = profile[0].y
		torso.lathe(Transform3D.IDENTITY, [Vector2(profile[0].x - 0.006, hem + 0.035), Vector2(profile[0].x - 0.01, hem + 0.06)], 20,
			_solid(look.bottom_color2), true, 1.0, 0.86, 0.0, 1.0, 0.008)


## Rockprofil (Radius, Höhe) vom Saum bis zur Taille; Rock bis übers Knie (Vorlage baker:
## Saum bei 0,14 m) bzw. lang.
func _skirt_profile(long: bool, top: float) -> Array:
	var hem := 0.09 if long else 0.14
	var flare := 0.36 if long else 0.33
	return [Vector2(flare, hem), Vector2(flare - 0.025, hem + 0.06), Vector2(0.27, 0.3), Vector2(torso_radius(top) + 0.012, top)]


## Überkleidung (Latzhose, Westen, Jacken, Schürzen, Kleider …).
func _build_outer() -> void:
	if look.bag:
		_satchel()
	match look.outer:
		CharacterAppearance.Outer.OVERALLS:
			_overalls()
		CharacterAppearance.Outer.CARDIGAN:
			_cardigan()
		CharacterAppearance.Outer.SUSPENDERS:
			_suspenders()
		CharacterAppearance.Outer.PINAFORE:
			_pinafore()
		CharacterAppearance.Outer.WORK_APRON:
			_work_apron()
		CharacterAppearance.Outer.DRESS_APRON:
			_dress_apron()
		CharacterAppearance.Outer.VEST:
			_vest()
		CharacterAppearance.Outer.TUNIC:
			_tunic()
		CharacterAppearance.Outer.PUFFER_VEST:
			_puffer_vest()


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

## Oberbekleidung mit eigenen Ärmeln (Ärmel in Jackenfarbe).
const SLEEVED_OUTER := [CharacterAppearance.Outer.CARDIGAN, CharacterAppearance.Outer.PUFFER_JACKET,
	CharacterAppearance.Outer.LONG_COAT, CharacterAppearance.Outer.DUFFLE_COAT, CharacterAppearance.Outer.PARKA,
	CharacterAppearance.Outer.KNIT_DRESS]


## Hochgeschnittene Hose mit Hosenträgern (newsboy): Bund bei 0,53 m, Träger vorne mit
## Knöpfen am Bund, hinten V-förmig zur Mitte, aufgesetzte Gesäßtaschen.
func _suspenders() -> void:
	var cloth := _fabric(look.outer_color, look.outer_pattern, look.outer_color2 if look.outer_pattern != CharacterAppearance.Pattern.SOLID else Color.BLACK)
	# Träger in eigener Farbe (Leder, sailor) oder aus dem Hosenstoff (newsboy)
	var strap := _solid(look.outer_color2) if look.outer_color2.a > 0.0 else cloth
	var strap_width := 0.036 if look.outer_color2.a > 0.0 else 0.048
	var seam := _solid(look.outer_color.darkened(0.3))
	var xf := Transform3D.IDENTITY
	var waist := 0.565
	torso.lathe(xf, _hip_profile(waist), 18, cloth, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.014, true)
	# Bundnaht und vordere Eingrifftaschen
	torso.lathe(xf, torso_profile(0.5, 0.508, 1), 18, seam, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.017)
	if look.cargo_pockets:
		_cargo_pockets(look.outer_color)
	var pocket := _solid(look.outer_color.lightened(0.05))
	for side: float in [-1.0, 1.0]:
		# Gesäßtaschen mit Klappe (Vorlage: 0,33–0,46 m hoch, 0,09–0,2 m neben der Mitte)
		torso.panel(xf, torso_profile(0.34, 0.44, 2), 3, pocket, 1.0, TORSO_DEPTH,
			0.5 + side * 0.1 - 0.042, 0.5 + side * 0.1 + 0.042, 0.016, 0.01, seam)
		torso.panel(xf, torso_profile(0.415, 0.455, 1), 3, cloth, 1.0, TORSO_DEPTH,
			0.5 + side * 0.1 - 0.046, 0.5 + side * 0.1 + 0.046, 0.026, 0.01, seam)
		torso.panel(xf, torso_profile(0.43, 0.495, 2), 3, pocket, 1.0, TORSO_DEPTH,
			side * 0.125 - 0.04, side * 0.125 + 0.04, 0.017, 0.008, seam)
		var points: Array = []
		var outward: Array = []
		var front_angle := side * 0.08
		for y: float in [waist - 0.01, 0.62, 0.7]:
			points.append(torso_point(front_angle, y, 0.02))
			outward.append(torso_normal(front_angle))
		points.append(Vector3(side * 0.13, 0.752, -0.04))
		outward.append(Vector3.UP + torso_normal(front_angle))
		points.append(Vector3(side * 0.12, 0.756, 0.04))
		outward.append(Vector3.UP + torso_normal(0.5))
		for k in 3:
			var y := lerpf(0.7, waist - 0.01, float(k + 1) / 3.0)
			var back_angle := 0.5 - side * lerpf(0.07, 0.045, float(k + 1) / 3.0)
			points.append(torso_point(back_angle, y, 0.02))
			outward.append(torso_normal(back_angle))
		torso.strip(points, outward, strap_width, 0.012, strap, seam)
		torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(front_angle)), torso_point(front_angle, waist - 0.02, 0.036)),
			Vector3(0.022, 0.022, 0.011), 10, 5, CharacterKit.paint(look.accent_color, P.GLOSS))


## Trägerrock (bow_girl): Faltenrock von der Taille (0,535 m) bis übers Knie (0,235 m),
## breiter Bund, Träger vorne mit Messingknöpfen am Bund, hinten parallel nach unten.
func _pinafore() -> void:
	var cloth := _fabric(look.outer_color, look.outer_pattern, look.outer_color2)
	var seam := _solid(look.outer_color.darkened(0.25))
	var waist := 0.535
	# Ringe: [Höhe, Radius, Faltentiefe, Tiefenfaktor]; jede zweite Kante steht als Falte vor
	var rings: Array = [[0.235, 0.278, 1.0, 0.88], [0.27, 0.274, 1.0, 0.87], [0.4, 0.262, 0.75, 0.8], [0.5, 0.25, 0.4, 0.74],
		[waist, torso_radius(waist) + 0.014, 0.0, TORSO_DEPTH]]
	var segments := 36
	var skirt_point := func(t: float, ring: Array) -> Vector3:
		var angle := t * TAU
		var fold := 0.04 * float(ring[2]) if roundi(t * segments) % 2 == 0 else 0.0
		var r := float(ring[1]) + fold
		return Vector3(sin(angle) * r, float(ring[0]), -cos(angle) * r * float(ring[3]))
	torso.warped_lathe(rings, segments, cloth, skirt_point, Vector3(0, 0.42, 0))
	# Bund
	torso.lathe(Transform3D.IDENTITY, torso_profile(waist - 0.035, waist + 0.012, 1), 18, cloth, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.02)
	torso.lathe(Transform3D.IDENTITY, torso_profile(waist - 0.037, waist - 0.033, 1), 18, seam, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.022)
	for side: float in [-1.0, 1.0]:
		var points: Array = []
		var outward: Array = []
		var front_angle := side * 0.085
		var back_angle := 0.5 - side * 0.085
		for y: float in [waist - 0.01, 0.62, 0.7]:
			points.append(torso_point(front_angle, y, 0.02))
			outward.append(torso_normal(front_angle))
		points.append(Vector3(side * 0.135, 0.752, -0.04))
		outward.append(Vector3.UP + torso_normal(front_angle))
		points.append(Vector3(side * 0.13, 0.756, 0.04))
		outward.append(Vector3.UP + torso_normal(back_angle))
		for y: float in [0.7, 0.62, waist - 0.01]:
			points.append(torso_point(back_angle, y, 0.02))
			outward.append(torso_normal(back_angle))
		torso.strip(points, outward, 0.05, 0.012, cloth, seam)
		torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(front_angle)), torso_point(front_angle, waist - 0.016, 0.04)),
			Vector3(0.024, 0.024, 0.012), 10, 5, CharacterKit.paint(look.accent_color, P.GLOSS))


## Schmiedeschürze (smith): dunkles Leinen rundum von der Brust (0,7 m) bis übers Knie,
## Brusttasche, Lederträger mit Messingnieten, Ledergürtel mit Werkzeugtasche links.
func _work_apron() -> void:
	var cloth := _fabric(look.outer_color, look.outer_pattern, look.outer_color2)
	var seam := _solid(look.outer_color.darkened(0.3))
	var leather := _solid(look.accent_color)
	var rivet := CharacterKit.paint(Color(0.85, 0.6, 0.3), P.GLOSS)
	var xf := Transform3D.IDENTITY
	var top := 0.7
	torso.lathe(xf, [Vector2(0.265, 0.25), Vector2(0.258, 0.32)] + torso_profile(0.36, top, 4), 20, cloth, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.016)
	torso.lathe(xf, [Vector2(0.258, 0.245), Vector2(0.27, 0.25), Vector2(0.264, 0.32)], 20, seam, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.012)
	# Brusttasche (rechts der Mitte)
	torso.panel(xf, torso_profile(0.56, 0.66, 2), 3, cloth, 1.0, TORSO_DEPTH, 0.015, 0.11, 0.03, 0.012, seam)
	# Gürtel
	torso.lathe(xf, torso_profile(0.455, 0.5, 1), 20, leather, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.03)
	# Werkzeugtasche vorne links mit Klappe und zwei Griffen
	var pouch := _solid(look.accent_color.lightened(0.12))
	torso.panel(xf, torso_profile(0.3, 0.47, 2), 3, pouch, 1.0, TORSO_DEPTH, -0.15, -0.07, 0.05, 0.03, leather)
	torso.panel(xf, torso_profile(0.4, 0.475, 1), 3, leather, 1.0, TORSO_DEPTH, -0.152, -0.068, 0.082, 0.01, leather)
	torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(-0.11)), torso_point(-0.11, 0.415, 0.094)), Vector3(0.012, 0.012, 0.006),
		6, 3, rivet)
	for k in 2:
		var at := torso_point(-0.09 - k * 0.04, 0.5, 0.06)
		torso.box(Transform3D(Basis(Vector3.UP, -0.6), at), Vector3(0.018, 0.07, 0.018), _solid(look.accent_color.darkened(0.25)))
	# Träger: über die Schultern, vorne und hinten mit Nieten am Schürzenrand
	for side: float in [-1.0, 1.0]:
		var points: Array = []
		var outward: Array = []
		var front_angle := side * 0.1
		var back_angle := 0.5 - side * 0.1
		for y: float in [top - 0.02, 0.73]:
			points.append(torso_point(front_angle, y, 0.03))
			outward.append(torso_normal(front_angle))
		points.append(Vector3(side * 0.15, 0.755, -0.04))
		outward.append(Vector3.UP + torso_normal(front_angle))
		points.append(Vector3(side * 0.15, 0.758, 0.04))
		outward.append(Vector3.UP + torso_normal(back_angle))
		for y: float in [0.73, top - 0.02]:
			points.append(torso_point(back_angle, y, 0.03))
			outward.append(torso_normal(back_angle))
		torso.strip(points, outward, 0.045, 0.012, leather)
		for angle: float in [front_angle, back_angle]:
			torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(angle)), torso_point(angle, top - 0.025, 0.046)),
				Vector3(0.018, 0.018, 0.01), 8, 4, rivet)


## Latzschürze (baker): Latz bis 0,7 m mit Knöpfen an den Ecken, Träger über den
## Schultern, hinten gekreuzt; Schürzenrock vorne bis 0,175 m mit Zierstreifen
## (outer_color2) und aufgesetzter Tasche mit Blattmotiv; große Schleife hinten.
func _dress_apron() -> void:
	var cloth := _solid(look.outer_color)
	var edge := _solid(look.outer_color.darkened(0.08))
	var stripe := _solid(look.outer_color2 if look.outer_color2.a > 0.0 else look.outer_color.darkened(0.2))
	var xf := Transform3D.IDENTITY
	var top := 0.7
	torso.panel(xf, torso_profile(WAIST_Y, top, 3), 6, cloth, 1.0, TORSO_DEPTH, -0.115, 0.115, 0.016, 0.012, edge)
	torso.lathe(xf, torso_profile(WAIST_Y - 0.012, WAIST_Y + 0.03, 1), 20, cloth, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.02)
	var skirt: Array = [Vector2(0.324, 0.175), Vector2(0.306, 0.235), Vector2(0.272, 0.3), Vector2(torso_radius(WAIST_Y) + 0.014, WAIST_Y)]
	torso.panel(xf, skirt, 10, cloth, 1.0, 0.86, -0.17, 0.17, 0.016, 0.012, edge)
	torso.panel(xf, [Vector2(0.322, 0.2), Vector2(0.318, 0.222)], 10, stripe, 1.0, 0.86, -0.17, 0.17, 0.03, 0.004, stripe)
	# Tasche mit Streifen und Blattmotiv
	var pocket_profile: Array = [Vector2(0.304, 0.235), Vector2(0.282, 0.3), Vector2(0.27, 0.36)]
	torso.panel(xf, pocket_profile, 4, cloth, 1.0, 0.86, -0.1, 0.1, 0.036, 0.014, _solid(look.outer_color.darkened(0.2)))
	torso.panel(xf, [Vector2(0.276, 0.335), Vector2(0.272, 0.35)], 4, stripe, 1.0, 0.86, -0.1, 0.1, 0.05, 0.003, stripe)
	var leaf_at := Vector3(0.0, 0.29, -0.86 * 0.3 - 0.052)
	for k in 3:
		var tilt := (float(k) - 1.0) * 0.7
		torso.scale_tuft(Transform3D(Basis(Vector3.FORWARD, PI + tilt), leaf_at + Vector3(sin(tilt) * 0.012, 0.0, 0.0)),
			0.022, 0.05, 0.006, stripe)
	# Träger: vorne von den Latzecken über die Schulter, hinten gekreuzt zur Gegenseite
	for side: float in [-1.0, 1.0]:
		var points: Array = []
		var outward: Array = []
		var front_angle := side * 0.1
		for y: float in [top - 0.02, 0.73]:
			points.append(torso_point(front_angle, y, 0.028))
			outward.append(torso_normal(front_angle))
		points.append(Vector3(side * 0.14, 0.756, -0.04))
		outward.append(Vector3.UP + torso_normal(front_angle))
		points.append(Vector3(side * 0.14, 0.758, 0.04))
		outward.append(Vector3.UP + torso_normal(0.5 - side * 0.1))
		for k in 4:
			var u := float(k + 1) / 4.0
			var angle := 0.5 - side * lerpf(0.1, 0.012, u)
			var y := lerpf(0.72, WAIST_Y + 0.02, u)
			points.append(torso_point(angle, y, 0.022 + 0.004 * side))
			outward.append(torso_normal(angle))
		torso.strip(points, outward, 0.05, 0.01, cloth, edge)
		torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(side * 0.09)), torso_point(side * 0.09, top - 0.02, 0.044)),
			Vector3(0.022, 0.022, 0.011), 10, 5, _solid(look.accent_color))
	# Schleife hinten mit langen Bändern
	_bow(torso, torso_point(0.5, WAIST_Y + 0.03, 0.05), PI, 0.0, cloth, 0.85, 1.9, true)


## Cargo-Taschen (sailor): aufgesetzte Seitentaschen mit Klappe auf dem Oberschenkel
## (0,3–0,44 m), Hosenschlitz mit Leiste vorne.
func _cargo_pockets(color: Color) -> void:
	var cloth := _solid(color)
	var seam := _solid(color.darkened(0.3))
	var xf := Transform3D.IDENTITY
	for side: float in [-1.0, 1.0]:
		var at := side * 0.2
		torso.panel(xf, [Vector2(0.245, 0.3), Vector2(0.248, 0.35)] + torso_profile(0.38, 0.44, 2), 3, cloth, 1.0, TORSO_DEPTH,
			at - 0.055, at + 0.055, 0.03, 0.022, seam)
		torso.panel(xf, torso_profile(0.4, 0.44, 1), 3, cloth, 1.0, TORSO_DEPTH, at - 0.06, at + 0.06, 0.05, 0.012, seam)
	torso.panel(xf, torso_profile(0.33, 0.49, 2), 2, cloth, 1.0, TORSO_DEPTH, -0.012, 0.03, 0.016, 0.008, seam)


## Weste (satchel_boy): ohne Ärmel bis über die Hüfte (0,36 m), tiefer V-Ausschnitt ab
## 0,5 m, vorne zwei flache Spitzen am Saum, zwei Messingknöpfe rechts der Mitte, Paspeltasche;
## hinten glatt mit kurzem Schlitz.
func _vest() -> void:
	var cloth := _fabric(look.outer_color, look.outer_pattern, look.outer_color2)
	var seam := _solid(look.outer_color.darkened(0.3))
	var xf := Transform3D.IDENTITY
	var hem := 0.36
	var v_tip := 0.5
	torso.lathe(xf, [Vector2(0.255, hem), Vector2(0.258, 0.42)] + torso_profile(0.45, v_tip, 2), 20, cloth, true, 1.0, TORSO_DEPTH,
		0.0, 1.0, 0.016)
	var slices := 10
	for k in slices:
		var y0 := lerpf(v_tip, NECK_Y - 0.01, float(k) / slices)
		var y1 := lerpf(v_tip, NECK_Y - 0.01, float(k + 1) / slices)
		var half := _v_half((y0 + y1) * 0.5, v_tip) * 1.25
		torso.lathe(xf, torso_profile(y0, y1, 1), 20, cloth, true, 1.0, TORSO_DEPTH, half, 1.0 - half, 0.016)
	# Flache Spitzen vorne am Saum
	for side: float in [-1.0, 1.0]:
		var a := torso_point(side * 0.004, hem + 0.002, 0.017) + Vector3(0, 0, -0.004)
		var b := torso_point(side * 0.1, hem + 0.002, 0.017) + Vector3(0, 0, -0.004)
		var tip := torso_point(side * 0.03, hem - 0.035, 0.017) + Vector3(0, 0, -0.004)
		torso.triangle(a, b, tip, cloth, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
			torso_normal(side * 0.05))
	torso.panel(xf, torso_profile(0.43, 0.445, 1), 2, seam, 1.0, TORSO_DEPTH, 0.09, 0.17, 0.02, 0.006, seam)
	# Blende entlang des V (glatte Kante)
	for side: float in [-1.0, 1.0]:
		var points: Array = []
		var outward: Array = []
		for k in 5:
			var y := lerpf(v_tip - 0.01, NECK_Y - 0.01, float(k) / 4.0)
			var angle := side * (_v_half(y, v_tip) * 1.25 + 0.006)
			points.append(torso_point(angle, y, 0.02))
			outward.append(torso_normal(angle))
		torso.strip(points, outward, 0.026, 0.008, cloth, seam)
	# Rückenschlitz
	torso.panel(xf, torso_profile(hem, hem + 0.07, 1), 1, seam, 1.0, TORSO_DEPTH, 0.497, 0.503, 0.018, 0.004, seam)
	for k in 2:
		var y := 0.41 + k * 0.08
		torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(0.035)), torso_point(0.035, y, 0.03)), Vector3(0.021, 0.021, 0.011),
			8, 4, CharacterKit.paint(look.accent_color, P.GLOSS))


## Umhängetasche (satchel_boy): Riemen von der rechten Schulter quer über Brust und Rücken
## zur Tasche an der linken Hüfte, Schnalle vorne, Tasche mit Klappe und Knopf.
func _satchel() -> void:
	var leather := _solid(look.bag_color)
	var dark := _solid(look.bag_color.darkened(0.25))
	var bag_angle := -0.17
	var bag_at := torso_point(bag_angle, 0.4, 0.065)
	var n := torso_normal(bag_angle)
	var bag_basis := Basis.looking_at(-n, Vector3.UP)
	# Taschenkörper mit gerundetem Boden, Klappe darüber
	torso.box(Transform3D(bag_basis, bag_at + Vector3(0, 0.02, 0)), Vector3(0.17, 0.11, 0.07), leather)
	torso.ellipsoid(Transform3D(bag_basis, bag_at + Vector3(0, -0.035, 0)), Vector3(0.085, 0.05, 0.035), 10, 5, leather, true, 0.0, 0.5)
	torso.box(Transform3D(bag_basis, bag_at + n * 0.038 + Vector3(0, 0.03, 0)), Vector3(0.172, 0.09, 0.012), dark)
	torso.ellipsoid(Transform3D(bag_basis, bag_at + n * 0.045 + Vector3(0, -0.005, 0)), Vector3(0.018, 0.018, 0.009), 8, 4,
		CharacterKit.paint(look.accent_color, P.GLOSS))
	# Riemen vorne und hinten
	for back: bool in [false, true]:
		var points: Array = []
		var outward: Array = []
		var shoulder_angle := 0.5 - 0.1 if back else 0.1
		var end_angle := 0.5 + 0.22 if back else bag_angle + 0.02
		points.append(Vector3(0.12, 0.756, 0.04 if back else -0.04))
		outward.append(Vector3.UP + torso_normal(shoulder_angle))
		for k in 5:
			var u := float(k + 1) / 5.0
			var angle := lerpf(shoulder_angle, end_angle, u)
			var y := lerpf(0.72, 0.47, u)
			points.append(torso_point(angle, y, 0.03))
			outward.append(torso_normal(angle))
		torso.strip(points, outward, 0.034, 0.01, leather, dark)
	var buckle_angle := 0.07
	torso.box(Transform3D(Basis.looking_at(-torso_normal(buckle_angle), Vector3.UP) * Basis(Vector3.FORWARD, 0.5),
		torso_point(buckle_angle, 0.66, 0.046)), Vector3(0.045, 0.04, 0.008), CharacterKit.paint(look.accent_color, P.GLOSS))


## Tunika (scout): ärmellos bis 0,33 m, unten leicht ausgestellt mit Seitenschlitzen,
## vorne geschnürter Schlitz (über Kreuz), Ledergürtel mit Messingschnalle.
func _tunic() -> void:
	var cloth := _fabric(look.outer_color, look.outer_pattern, look.outer_color2)
	var seam := _solid(look.outer_color.darkened(0.25))
	var xf := Transform3D.IDENTITY
	var hem := 0.33
	var slit_top := 0.64
	torso.lathe(xf, [Vector2(0.29, hem), Vector2(0.272, 0.39), Vector2(0.258, 0.43)] + torso_profile(0.46, slit_top, 3), 20, cloth,
		true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.016)
	# Brustschlitz: oberhalb vorne offen, darin das Hemd mit Schnürung
	torso.lathe(xf, torso_profile(slit_top, NECK_Y - 0.01, 2), 20, cloth, true, 1.0, TORSO_DEPTH, 0.035, 0.965, 0.016)
	var lace := _solid(look.accent_color.darkened(0.35))
	for k in 2:
		var y := slit_top + 0.02 + k * 0.04
		for d: float in [-1.0, 1.0]:
			var a := torso_point(-0.03, y - 0.015 * d, 0.024)
			var b := torso_point(0.03, y + 0.015 * d, 0.024)
			torso.tube([a, b], 0.006, 4, lace)
	# Seitenschlitze unten
	for side: float in [-1.0, 1.0]:
		torso.panel(xf, [Vector2(0.29, hem), Vector2(0.272, 0.39)], 1, seam, 1.0, TORSO_DEPTH, side * 0.25 - 0.004, side * 0.25 + 0.004,
			0.018, 0.004, seam)
	# Gürtel mit Schnalle
	var belt := _solid(look.bag_color if look.bag_color.a > 0.0 else look.accent_color.darkened(0.4))
	torso.lathe(xf, torso_profile(WAIST_Y + 0.01, WAIST_Y + 0.05, 1), 20, belt, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.03)
	var buckle := CharacterKit.paint(look.accent_color, P.GLOSS)
	var at := torso_point(0.0, WAIST_Y + 0.03, 0.045)
	var nb := Basis.looking_at(-torso_normal(0.0), Vector3.UP)
	torso.box(Transform3D(nb, at), Vector3(0.07, 0.055, 0.008), buckle)
	torso.box(Transform3D(nb, at + Vector3(0, 0, -0.005)), Vector3(0.045, 0.03, 0.008), belt)


## Daunenweste (winter_girl): dicke, gesteppte Weste ohne Ärmel bis 0,38 m, vorne offen
## (Pulli sichtbar), aufgesetzte Klappentaschen; Stehkragen hinten.
func _puffer_vest() -> void:
	var quilt := CharacterKit.paint(look.outer_color, P.QUILT, 9.0)
	var seam := _solid(look.outer_color.darkened(0.25))
	var xf := Transform3D.IDENTITY
	var hem := 0.38
	var gap := 0.06
	var profile: Array = [Vector2(0.27, hem), Vector2(0.282, hem + 0.03)] + torso_profile(0.45, NECK_Y - 0.03, 4)
	torso.lathe(xf, profile, 22, quilt, true, 1.0, TORSO_DEPTH, gap, 1.0 - gap, 0.035)
	# Stehkragen hinten und an den Seiten
	torso.lathe(xf, [Vector2(0.13, NECK_Y - 0.035), Vector2(0.125, NECK_Y + 0.02)], 16, quilt, true, 1.0, 0.9, 0.18, 0.82, 0.02)
	# Kanten vorne
	for side: float in [-1.0, 1.0]:
		torso.panel(xf, profile, 1, quilt, 1.0, TORSO_DEPTH, side * gap - 0.004, side * gap + 0.004, 0.035, 0.012, seam)
		# Klappentasche
		var at := side * 0.13
		torso.panel(xf, torso_profile(hem + 0.03, hem + 0.12, 2), 3, _solid(look.outer_color.darkened(0.05)), 1.0, TORSO_DEPTH,
			at - 0.05, at + 0.05, 0.05, 0.012, seam)
		torso.panel(xf, torso_profile(hem + 0.1, hem + 0.135, 1), 3, _solid(look.outer_color), 1.0, TORSO_DEPTH,
			at - 0.055, at + 0.055, 0.064, 0.012, seam)


## Halbe Breite des V-Ausschnitts (Winkelanteil) in Höhe [param y].
func _v_half(y: float, tip: float) -> float:
	return 0.075 * clampf((y - tip) / (NECK_Y - tip), 0.0, 1.0)


## Strickjacke (grandpa_cardigan): bis über die Hüfte, V-Ausschnitt mit Rippenblende,
## drei Holzknöpfe, zwei aufgesetzte Taschen, Rippbund unten.
func _cardigan() -> void:
	var knit := CharacterKit.paint(look.outer_color, P.RIBS, 34.0)
	if look.outer_pattern != CharacterAppearance.Pattern.SOLID:
		knit = _fabric(look.outer_color, look.outer_pattern, look.outer_color2, 0.8)
	var rib := CharacterKit.paint(look.outer_color.darkened(0.12), P.KNIT_CUFF, 40.0)
	var xf := Transform3D.IDENTITY
	var open := look.outer_open
	# Offene Strickjacke (granny_gingham): kurz bis 0,42 m, vorne ganz offen
	var hem := 0.42 if open else 0.36
	# Rumpf bis zur V-Spitze geschlossen, darüber in Scheiben vorne immer weiter offen
	var v_tip := hem if open else 0.56
	if not open:
		torso.lathe(xf, [Vector2(0.255, hem), Vector2(0.258, 0.42)] + torso_profile(0.45, v_tip, 3), 20, knit, true, 1.0, TORSO_DEPTH, 0.0, 1.0, 0.016)
	var slices := 6
	for k in slices:
		var y0 := lerpf(v_tip, NECK_Y - 0.01, float(k) / slices)
		var y1 := lerpf(v_tip, NECK_Y - 0.01, float(k + 1) / slices)
		var half := _open_half((y0 + y1) * 0.5) if open else _v_half((y0 + y1) * 0.5, v_tip)
		torso.lathe(xf, torso_profile(y0, y1, 1), 20, knit, true, 1.0, TORSO_DEPTH, half, 1.0 - half, 0.016)
	var rib_gap := _open_half(hem) if open else 0.0
	torso.lathe(xf, [Vector2(0.25, hem - 0.03), Vector2(0.262, hem), Vector2(0.262, hem + 0.035), Vector2(0.256, hem + 0.045)], 20, rib,
		true, 1.0, TORSO_DEPTH, rib_gap, 1.0 - rib_gap, 0.018)
	# Rippenblende am V und Knopfleiste
	for side: float in [-1.0, 1.0]:
		var points: Array = []
		var outward: Array = []
		for k in 6:
			var y := lerpf(hem, NECK_Y - 0.01, float(k) / 5.0)
			var angle := side * (_open_half(y) if open else maxf(_v_half(y, v_tip), 0.012))
			points.append(torso_point(angle, y, 0.022))
			outward.append(torso_normal(angle))
		if look.shawl_collar:
			# Schalkragen: breite, dicke Blende, die hinten um den Hals läuft
			points.append(Vector3(side * 0.11, NECK_Y + 0.005, -0.02))
			outward.append(Vector3.UP + torso_normal(side * 0.15))
			points.append(Vector3(side * 0.09, NECK_Y + 0.01, 0.07))
			outward.append(Vector3.UP + Vector3.BACK)
			points.append(Vector3(0.0, NECK_Y + 0.01, 0.1))
			outward.append(Vector3.UP + Vector3.BACK)
			torso.strip(points, outward, 0.06, 0.028, rib)
		else:
			torso.strip(points, outward, 0.032, 0.008, rib)
		var pocket_at := torso_profile(hem + 0.05, hem + 0.14, 2)
		torso.panel(xf, pocket_at, 3, knit, 1.0, TORSO_DEPTH, side * 0.13 - 0.05, side * 0.13 + 0.05, 0.03, 0.012,
			CharacterKit.paint(look.outer_color.darkened(0.15), P.SOLID))
	for k in (2 if open else 3):
		var y := (hem + 0.12 + k * 0.08) if open else (0.42 + k * 0.065)
		var angle := -_open_half(y) - 0.012 if open else 0.0
		torso.ellipsoid(Transform3D(Basis.looking_at(torso_normal(angle)), torso_point(angle, y, 0.034)), Vector3(0.016, 0.016, 0.009),
			8, 4, CharacterKit.paint(look.accent_color, P.GLOSS))


## Halbe Öffnung (Winkelanteil) einer offenen Jacke in Höhe [param y]: unten schmal, oben weiter.
func _open_half(y: float) -> float:
	return 0.03 + 0.025 * clampf((y - 0.4) / (NECK_Y - 0.4), 0.0, 1.0)


## Hand in der Vorlage bei 670 px (0,405 m), Schulter bei 0,68 m.
const HAND_Y := -0.272


func _build_arms() -> void:
	for i in 2:
		var kit: CharacterKit = arms[i]
		var sleeve := _fabric(look.shirt_color, look.shirt_pattern, look.shirt_stripe_color, 0.6, look.shirt_line_color)
		if look.top_style == CharacterAppearance.TopStyle.TURTLENECK and look.shirt_pattern == CharacterAppearance.Pattern.SOLID:
			sleeve = CharacterKit.paint(look.shirt_color, P.RIBS, 14.0)
		var sleeve_color := look.shirt_color
		if look.outer in SLEEVED_OUTER:
			sleeve_color = look.outer_color
			# Norwegerband auf den Ärmeln in Brusthöhe (0,6 m = 0,08 m unter der Schulter)
			sleeve = _fabric(look.outer_color, look.outer_pattern, look.outer_color2, 0.6, Color(0, 0, 0, -0.08))
			if look.outer == CharacterAppearance.Outer.CARDIGAN and look.outer_pattern == CharacterAppearance.Pattern.SOLID:
				sleeve = CharacterKit.paint(look.outer_color, P.RIBS, 14.0)
		var xf := Transform3D.IDENTITY
		match look.sleeves:
			CharacterAppearance.Sleeves.ROLLED:
				# Weiter Ärmel mit dickem, hochgekrempeltem Wulst über dem Unterarm
				kit.lathe(xf, [Vector2(0.064, -0.13), Vector2(0.068, -0.06), Vector2(0.07, 0.0), Vector2(0.055, 0.05), Vector2(0.0, 0.065)],
					10, sleeve)
				kit.lathe(xf, [Vector2(0.07, -0.19), Vector2(0.088, -0.18), Vector2(0.092, -0.14), Vector2(0.085, -0.115),
					Vector2(0.074, -0.11)], 10, (CharacterKit.paint(sleeve_color, P.KNIT_CUFF, 22.0) if look.outer == CharacterAppearance.Outer.CARDIGAN else _solid(sleeve_color.lightened(0.02))),
					true, 1.0, 1.0, 0.0, 1.0, 0.0, true)
				kit.lathe(xf, [Vector2(0.05, -0.24), Vector2(0.054, -0.18)], 10, _skin(), false)
			CharacterAppearance.Sleeves.PUFF:
				kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, -0.07, 0)), Vector3(0.095, 0.12, 0.09), 10, 6, sleeve)
				kit.lathe(xf, [Vector2(0.06, -0.215), Vector2(0.066, -0.17), Vector2(0.074, -0.11)], 10, sleeve)
				kit.torus(Transform3D(Basis.IDENTITY, Vector3(0, -0.205, 0)), 0.055, 0.02, 10, 5, _solid(look.shirt_color.darkened(0.05)))
			CharacterAppearance.Sleeves.SHORT_PUFF:
				# Kurzer Puffärmel mit breitem Bündchen (baker), darunter der nackte Unterarm
				var cuff_color := look.shirt_line_color if look.shirt_line_color.a > 0.0 else look.shirt_color.darkened(0.05)
				kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, -0.045, 0)), Vector3(0.1, 0.105, 0.095), 10, 6, sleeve)
				kit.lathe(xf, [Vector2(0.074, -0.16), Vector2(0.084, -0.155), Vector2(0.086, -0.12), Vector2(0.08, -0.11)], 10,
					_solid(cuff_color), true, 1.0, 1.0, 0.0, 1.0, 0.0, true)
				kit.lathe(xf, [Vector2(0.05, -0.24), Vector2(0.056, -0.15)], 10, _skin(), false)
			_:
				kit.lathe(xf, [Vector2(0.062, -0.2), Vector2(0.07, -0.08), Vector2(0.078, 0.0), Vector2(0.06, 0.05), Vector2(0.0, 0.07)],
					10, sleeve)
				if look.top_style == CharacterAppearance.TopStyle.SWEATER and look.outer not in SLEEVED_OUTER:
					# Breites Rippbündchen (winter_girl)
					kit.lathe(xf, [Vector2(0.064, -0.235), Vector2(0.078, -0.228), Vector2(0.08, -0.165), Vector2(0.072, -0.158)], 10,
						CharacterKit.paint(look.shirt_color.darkened(0.04), P.KNIT_CUFF, 22.0), true, 1.0, 1.0, 0.0, 1.0, 0.0, true)
				else:
					kit.lathe(xf, [Vector2(0.06, -0.225), Vector2(0.066, -0.195)], 10,
						CharacterKit.paint(look.shirt_color.darkened(0.05), P.KNIT_CUFF, 18.0))
		_build_hand(kit, -1.0 if i == 0 else 1.0, HAND_Y)


## Faust (bloße Hand) bzw. Fäustling mit Daumen.
func _build_hand(kit: CharacterKit, side: float, y: float) -> void:
	var mittens := (winter or look.gloves) and look.mitten_color.a > 0.0
	if mittens:
		var m := _solid(look.mitten_color)
		kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, y, -0.005)), Vector3(0.07, 0.078, 0.064), 10, 7, m)
		kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(-side * 0.048, y + 0.012, -0.03)), Vector3(0.03, 0.042, 0.028), 6, 4, m)
		if look.gloves:
			# Lederstulpe: weit ausgestellt über dem Handgelenk (Vorlage smith)
			kit.lathe(Transform3D.IDENTITY, [Vector2(0.06, y + 0.04), Vector2(0.08, y + 0.06), Vector2(0.088, y + 0.11),
				Vector2(0.082, y + 0.12), Vector2(0.06, y + 0.115)], 10, _solid(look.mitten_color.darkened(0.08)), true, 1.0, 1.0,
				0.0, 1.0, 0.0, false, true)
		elif look.mitten_cuff_color.a > 0.0:
			kit.lathe(Transform3D.IDENTITY, [Vector2(0.062, y + 0.045), Vector2(0.07, y + 0.06), Vector2(0.07, y + 0.095),
				Vector2(0.064, y + 0.105)], 10, CharacterKit.paint(look.mitten_cuff_color, P.KNIT_CUFF, 16.0))
		return
	var skin := _skin()
	kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, y, -0.004)), Vector3(0.07, 0.074, 0.064), 12, 8, skin, false)
	kit.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(-side * 0.043, y + 0.014, -0.03)), Vector3(0.026, 0.036, 0.026), 8, 5, skin, false)


# --- Kopf --------------------------------------------------------------------------------

func _build_head() -> void:
	var face := CharacterKit.paint(look.skin_color, P.FACE, 1.0, Color(_brow_color(), 1.0),
		Color(look.brow_thickness, 0, 0, 1.0 if look.freckles else 0.0))
	head.head_shape(Transform3D.IDENTITY, HEAD, 28, 18, face)
	# Ohren
	for side: float in [-1.0, 1.0]:
		# Große, abstehende Ohren auf Augenhöhe (Vorlage: 60 px breit, Mitte 0,27 m neben der Kopfmitte)
		head.ellipsoid(Transform3D(Basis(Vector3.UP, side * 0.35), Vector3(side * 0.222, -0.135, 0.03)),
			Vector3(0.05, 0.062, 0.046), 12, 8, _skin(), false)
		head.ellipsoid(Transform3D(Basis(Vector3.UP, side * 0.35), Vector3(side * 0.256, -0.135, 0.018)),
			Vector3(0.014, 0.036, 0.028), 8, 5, CharacterKit.paint(look.skin_color.darkened(0.1), P.SKIN), false)
	if look.glasses:
		_build_glasses()
	if look.beard or look.mustache:
		_build_beard()
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
	# Unter einer Kopfbedeckung: Schuppen oben weglassen, Pony tiefer ansetzen
	var clip := _hat_clip
	if _hat_rim != Vector2.ZERO and absf(wrapf(az, -180.0, 180.0)) > 60.0:
		# Unter der schrägen Kante: tief darunter liegende Schuppen entfallen, die übrigen
		# schauen als Kranz unter der Kante hervor
		var rim_y := _hat_rim.x + _hat_rim.y * cos(deg_to_rad(az))
		clip = rad_to_deg(asin(clampf((rim_y - HAIR_LIFT) / HAIR.y, -1.0, 1.0)))
		if el > clip + _hat_rim_keep:
			return
		if el > clip - 6.0:
			el = clip - 6.0
			length *= 0.75
			lift = minf(lift, 0.12)
	elif el > clip:
		# seitlich, bzw. unter der Schiebermütze auch Kronen-Schuppen: verdeckt
		if absf(az) > 60.0 or (_hat_skip_crown and el > clip + 20.0):
			return
		el = minf(el, clip - 8.0)
		length *= _hat_bang
		# flach an die Stirn gedrückt, damit der Schirm sichtbar bleibt
		lift = minf(lift, 0.0)
		thick *= 0.6
		droop *= 0.3
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
	if hat in [CharacterAppearance.HatStyle.FLAT_CAP, CharacterAppearance.HatStyle.BEANIE, CharacterAppearance.HatStyle.POMPOM_BEANIE,
			CharacterAppearance.HatStyle.BERET, CharacterAppearance.HatStyle.BUCKET_HAT, CharacterAppearance.HatStyle.TRAPPER_HAT,
			CharacterAppearance.HatStyle.ELF_HAT, CharacterAppearance.HatStyle.STRAW_HAT, CharacterAppearance.HatStyle.CHEF_HAT]:
		match hat:
			CharacterAppearance.HatStyle.FLAT_CAP:
				_hat_clip = 30.0
			CharacterAppearance.HatStyle.CHEF_HAT:
				_hat_clip = 12.0
			CharacterAppearance.HatStyle.BUCKET_HAT:
				_hat_clip = 14.0
			CharacterAppearance.HatStyle.BEANIE, CharacterAppearance.HatStyle.POMPOM_BEANIE:
				_hat_clip = 12.0
			_:
				_hat_clip = 22.0
		if hat == CharacterAppearance.HatStyle.FLAT_CAP:
			_hat_rim = Vector2(0.1, 0.137)
			_hat_skip_crown = true
		elif hat in [CharacterAppearance.HatStyle.BEANIE, CharacterAppearance.HatStyle.POMPOM_BEANIE]:
			# Umschlag vorne 0,04 m über, hinten 0,14 m unter der Kopfmitte (18° gekippt)
			_hat_rim = Vector2(-0.05 + look.hat_lift, 0.3 * look.hat_scale * sin(deg_to_rad(18.0 + look.hat_tilt)))
		_hat_bang = 0.36 if hat in [CharacterAppearance.HatStyle.BEANIE, CharacterAppearance.HatStyle.POMPOM_BEANIE] else 0.6
	match look.hair_style:
		CharacterAppearance.HairStyle.SPIKY, CharacterAppearance.HairStyle.MESSY, CharacterAppearance.HairStyle.CURLY:
			# Strubbelkopf (player_male): runde, facettierte Schuppen wie ein Tannenzapfen,
			# seitlich über dem Ohr (Kotelette davor), hinten bis in den Nacken; dicker Pony
			# bis knapp über die Brauen, eine Strähne rechts der Mitte länger; Spitze oben.
			# Lockenkopf (smith): dieselben Schuppen, aber größer und stärker abstehend, oben
			# hoch aufgetürmt, kürzerer Pony.
			var curly := look.hair_style == CharacterAppearance.HairStyle.CURLY
			var big := look.hair_volume
			var puff := -0.08 if curly else 0.0
			_hair_cap(hair_dark, 16.0, 0.5, 0.94 if not curly else 0.97, 1.0 if not curly else 1.06)
			# Unter der Schiebermütze (newsboy) enden die Haare höher im Nacken
			var back_len := 0.7 if look.hair_style == CharacterAppearance.HairStyle.MESSY else 1.0
			# Hinterkopf: Reihen von oben nach unten (untere zuerst, damit obere darüber liegen)
			var rows := [[-38.0, 3, 0.17, 0.19, 26.0], [-14.0, 4, 0.21, 0.23, 44.0], [12.0, 4, 0.24, 0.26, 58.0],
				[36.0, 4, 0.25, 0.27, 70.0], [58.0, 3, 0.22, 0.24, 84.0]]
			if curly:
				# Viele kleinere, dicht anliegende Schuppen (Vorlage smith: Hinterkopf wie ein Zapfen)
				rows = [[-40.0, 4, 0.15, 0.17, 40.0], [-20.0, 5, 0.17, 0.19, 64.0], [2.0, 6, 0.18, 0.2, 80.0], [24.0, 6, 0.19, 0.21, 92.0],
					[46.0, 5, 0.19, 0.21, 100.0], [64.0, 4, 0.19, 0.2, 120.0]]
			for row: Array in rows:
				var count: int = row[1]
				var spread: float = row[4]
				for k in count:
					var az := 180.0 + (float(k) - (count - 1) * 0.5) * (spread * 2.0 / maxf(count - 1, 1))
					if float(row[0]) > 40.0:
						az += 15.0
					_scale(az, row[0], row[2] * big, row[3] * back_len * big, hair if (k % 2) == 0 else hair_dark,
						0.34 * back_len * back_len + puff, 1.0)
			# Seiten: über dem Ohr, hinter dem Ohr bis zum Nacken
			for side: float in [-1.0, 1.0]:
				_scale(side * 128.0, -2.0, 0.17 * big, 0.21 * big, hair_dark, 0.25 + puff * 2.0, 1.0 - 0.06 * float(curly))
				_scale(side * 104.0, 30.0, 0.22 * big, 0.25 * big, hair, 0.38 + puff * 2.0, 1.02 - 0.06 * float(curly))
				_scale(side * 78.0, 38.0, 0.21 * big, 0.24 * big, hair_dark, 0.32 + puff * 2.0, 1.02 - 0.06 * float(curly))
				_scale(side * 64.0, 8.0, 0.075, 0.16, hair_dark, 0.04, 0.98, 0.7)
			# Pony
			var bangs := [[-48.0, 34.0, 0.2, 0.28], [-20.0, 38.0, 0.21, 0.3], [10.0, 38.0, 0.21, 0.36], [38.0, 34.0, 0.2, 0.28]]
			for b: Array in bangs:
				var lift := 0.08 if curly else 0.0
				var bang_el: float = b[1] + (10.0 if curly else 0.0)
				_scale(b[0], bang_el, b[2] * big, b[3] * (0.85 if curly else 1.0), hair_dark if int(b[0]) == 10 else hair, lift, 1.0,
					0.85, 0.4 if curly else 0.75)
			# Krone
			for az: float in [-30.0, 40.0, 110.0, 250.0]:
				_scale(az, 68.0, 0.2 * big, 0.22 * big, hair, 0.12 + puff * 1.6, 1.0)
			if curly:
				for az: float in [-80.0, 0.0, 80.0, 160.0, 240.0]:
					_scale(az, 84.0, 0.2, 0.22, hair_dark if int(az) % 160 == 0 else hair, 0.7, 1.02)
			# Aufrechte Spitze oben, leicht zur Seite geneigt (nur beim Strubbelkopf ohne Mütze)
			if look.hair_style == CharacterAppearance.HairStyle.SPIKY and hat == CharacterAppearance.HatStyle.NONE:
				var tip := Transform3D(Basis(Vector3.FORWARD, PI + 0.35) * Basis(Vector3.RIGHT, 0.2), Vector3(-0.03, 0.34, -0.02))
				head.scale_tuft(tip, 0.13, 0.2, 0.09, hair)
		CharacterAppearance.HairStyle.FRINGE:
			# Glattes Haar (player_female): Kappe bis in den Nacken (unten etwas ausgestellt),
			# Pony mit Seitenscheitel (große Strähne über dem rechten Auge), je eine lange
			# Strähne vor dem Ohr bis unters Kinn. Unter einem Kopftuch bleibt nur das sichtbar.
			# Kappe hinten tief bis in den Nacken (unter dem Tuch rund statt kantig)
			_hair_cap(hair, 10.0, 0.16, 0.93 if hat == CharacterAppearance.HatStyle.BUCKET_HAT else 1.0, 1.0)
			var fringe := [[-48.0, 16.0, 0.22, 0.22], [-18.0, 20.0, 0.21, 0.24], [14.0, 20.0, 0.26, 0.3], [46.0, 16.0, 0.22, 0.22]]
			if look.middle_part:
				# Mittelscheitel (granny_gingham): zwei große Strähnen links und rechts der Mitte
				fringe = [[-54.0, 16.0, 0.22, 0.18], [-20.0, 24.0, 0.26, 0.19], [20.0, 24.0, 0.26, 0.19], [54.0, 16.0, 0.22, 0.18]]
			for f: Array in fringe:
				_scale(f[0], f[1], f[2], f[3], hair_dark if int(f[0]) == 14 else hair, -0.15, 0.97, 0.34, 0.45)
			# Seitliches Volumen unter dem Tuch: rahmt das Gesicht bis über die Ohren
			# (unter einem Hut mit Krempe würde es durch die Krempe stechen)
			for side: float in ([] if hat in [CharacterAppearance.HatStyle.STRAW_HAT, CharacterAppearance.HatStyle.BUCKET_HAT] else [-1.0, 1.0]):
				for k in 3:
					_scale(side * (78.0 + k * 26.0), 6.0 - k * 4.0, 0.22 * look.hair_volume, 0.24 * look.hair_volume, hair if k % 2 == 0 else hair_dark, 0.04 if hat == CharacterAppearance.HatStyle.HEADSCARF else -0.05,
						1.03 if hat == CharacterAppearance.HatStyle.HEADSCARF else 1.0, 0.6)
			if look.back_scales:
				# Hinterkopf unter der Krempe: zwei Reihen großer Schuppen bis in den Nacken
				for row: Array in [[-52.0, 5, 0.2, 0.22], [-34.0, 6, 0.2, 0.2]]:
					var count: int = row[1]
					for k in count:
						var az := lerpf(118.0, 242.0, float(k) / float(count - 1))
						_scale(az, row[0], row[2], row[3], hair if k % 2 == 0 else hair_dark, 0.06, 0.98)
			for side: float in ([-1.0, 1.0] if look.face_strands else []):
				var root: Array = _hair_point(side * 64.0, 4.0, 1.0)
				var p: Vector3 = root[0]
				head.scale_tuft(Transform3D(Basis(Vector3.UP, side * 0.95), p + Vector3(side * 0.012, -0.14, -0.005)),
					0.075, 0.3, 0.055, hair_dark)
		CharacterAppearance.HairStyle.BOB:
			# Halblanger Bob (bow_girl): glatte, facettierte Haarschale – vorne knapp über den
			# Brauen, hinten bis zur Ohrmitte (die Ohren schauen darunter hervor) –, an den
			# Schläfen nach außen stehende Spitzen, Pony aus vier großen Strähnen, je eine
			# lange Strähne vor dem Ohr bis unters Kinn und zwei kleine im Nacken.
			_hair_cap(hair, 27.5, 0.39, 1.06, 1.0)
			# Fülle am Hinterkopf bis in den Nacken (die Ohren bleiben frei)
			head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.06)), Vector3(0.255, 0.25, 0.235), 14, 10, hair, true, 0.1, 0.75)
			for side: float in [-1.0, 1.0]:
				_scale(side * 86.0, -2.0, 0.12, 0.2, hair_dark, 0.25, 1.06)
				_scale(side * 128.0, 4.0, 0.16, 0.22, hair, 0.25, 1.06)
				_scale(180.0 + side * 22.0, -26.0, 0.12, 0.16, hair_dark, 0.12, 1.0)
				var root: Array = _hair_point(side * 66.0, 4.0, 1.05)
				var p: Vector3 = root[0]
				head.scale_tuft(Transform3D(Basis(Vector3.UP, side * 0.95), p + Vector3(side * 0.01, -0.15, -0.005)),
					0.085, 0.32, 0.06, hair_dark)
			var fringe := [[-50.0, 24.0, 0.22, 0.24], [-34.0, 30.0, 0.22, 0.26], [-12.0, 32.0, 0.24, 0.28], [40.0, 28.0, 0.24, 0.26], [14.0, 34.0, 0.28, 0.34]]
			for fr: Array in fringe:
				_scale(fr[0], fr[1], fr[2], fr[3], hair_dark if int(fr[0]) == 14 else hair, -0.18, 1.07, 0.45, 0.3)
		CharacterAppearance.HairStyle.BALD_RING:
			# Glatze mit Haarkranz (grandpa_cardigan): große, facettierte Wolkenbüschel über
			# den Ohren, ein Band davon um den Hinterkopf, oben blanker Schädel.
			for side: float in [-1.0, 1.0]:
				_puff(Vector3(side * 0.205, 0.13, 0.03), Vector3(0.115, 0.125, 0.12), hair)
				_puff(Vector3(side * 0.225, 0.0, 0.06), Vector3(0.1, 0.11, 0.11), hair_dark)
				_puff(Vector3(side * 0.16, 0.11, 0.13), Vector3(0.11, 0.115, 0.1), hair)
				_puff(Vector3(side * 0.2, -0.06, 0.13), Vector3(0.1, 0.1, 0.1), hair)
				_puff(Vector3(side * 0.11, -0.1, 0.18), Vector3(0.1, 0.095, 0.085), hair_dark)
			_puff(Vector3(0.0, -0.1, 0.225), Vector3(0.11, 0.095, 0.08), hair)
	_build_hair_extra(hair, hair_dark)
	_build_hat(hat)


func _build_hair_extra(hair: CharacterKit.Paint, _hair_dark: CharacterKit.Paint) -> void:
	match look.hair_extra:
		CharacterAppearance.HairExtra.BUN_TOP:
			# Dutt oben am Hinterkopf
			# (beim Bob etwas tiefer, weiter hinten und zur linken Seite – Vorlage bow_girl)
			var bun_at := Vector3(-0.06, 0.3, 0.13) if look.hair_style == CharacterAppearance.HairStyle.BOB else Vector3(0.03, 0.34, 0.12)
			head.ellipsoid(Transform3D(Basis.IDENTITY, bun_at), Vector3(0.125, 0.115, 0.12), 10, 7, hair)
			if look.bow_color.a > 0.0:
				# Große Schleife vorne links am Dutt (Vorlage: 0,38 m breit, leicht schräg)
				_bow(head, Vector3(-0.11, 0.29, 0.0), 0.7, -0.22, _solid(look.bow_color))
		CharacterAppearance.HairExtra.BUN_BACK:
			head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.27)), Vector3(0.1, 0.095, 0.085), 10, 7, hair)
		CharacterAppearance.HairExtra.TWIN_BUNS:
			for side: float in [-1.0, 1.0]:
				head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(side * 0.22, 0.2, 0.1)), Vector3(0.085, 0.085, 0.08), 10, 6, hair)
		CharacterAppearance.HairExtra.LOW_BUNS:
			# Drei Knoten im Nacken (baker): einer mittig, zwei dahinter seitlich hinter den Ohren
			for side: float in [-1.0, 1.0]:
				head.ellipsoid(Transform3D(Basis(Vector3.UP, side * 0.5), Vector3(side * 0.19, -0.12, 0.16)), Vector3(0.1, 0.1, 0.095), 9, 6, hair)
			head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.19, 0.25)), Vector3(0.09, 0.085, 0.08), 9, 6, hair)
		CharacterAppearance.HairExtra.LOW_TAIL:
			# Tiefer, runder Zopf im Nacken mit Haargummi (bow_color)
			head.ellipsoid(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.0, -0.2, 0.27)), Vector3(0.085, 0.1, 0.075), 10, 6, hair)
			if look.bow_color.a > 0.0:
				head.torus(Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(0.0, -0.11, 0.255)), 0.035, 0.016, 10, 4, _solid(look.bow_color))


# --- Kopfbedeckungen --------------------------------------------------------------------

func _build_hat(hat: CharacterAppearance.HatStyle) -> void:
	var cloth := _fabric(look.hat_color, look.hat_pattern, look.hat_color2)
	match hat:
		CharacterAppearance.HatStyle.HEADSCARF:
			# Kopftuch (player_female): Band über Scheitel und Hinterkopf – vorne sieht der
			# Pony darunter hervor, seitlich die Haare bis knapp über dem Ohr, hinten reicht
			# es bis zum Nacken und ist rechts unten verknotet (zwei Zipfel).
			var shell := HAIR * Vector3(1.1, 1.06, 1.12) * look.hat_scale
			# 26°: Vorderrand über der Stirn (y ≈ 0,1), hinten unter der Ohroberkante
			var band := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(26.0 + look.hat_tilt)), Vector3(0, HAIR_LIFT + 0.03, 0.02))
			head.ellipsoid(band, shell, 18, 10, cloth, true, 0.43, 0.94)
			# Gerollter Saum am Tuchrand
			var rim_y := -cos(PI * 0.43)
			var rim_r := sin(PI * 0.43)
			head.torus(band * Transform3D(Basis.IDENTITY, Vector3(0, shell.y * rim_y, 0)), shell.x * rim_r * 0.99, 0.017, 24, 6, cloth,
				1.0, shell.z / shell.x)
			var ks := look.hat_knot_side
			var knot_at := Vector3(0.13 * ks, -0.03, 0.26)
			head.ellipsoid(Transform3D(Basis.IDENTITY, knot_at), Vector3(0.058, 0.052, 0.045), 8, 6, cloth)
			head.scale_tuft(Transform3D(Basis(Vector3.FORWARD, 1.2 * ks) * Basis(Vector3.RIGHT, -0.3), knot_at + Vector3(-0.1 * ks, -0.04, 0.02)),
				0.12, 0.22, 0.045, cloth)
			head.scale_tuft(Transform3D(Basis(Vector3.FORWARD, -2.0 * ks) * Basis(Vector3.RIGHT, -0.3), knot_at + Vector3(0.08 * ks, -0.03, 0.01)),
				0.09, 0.16, 0.04, cloth)
		CharacterAppearance.HatStyle.FLAT_CAP:
			# Schiebermütze (newsboy): weiche, bauschige Kuppel aus Segmenten, die seitlich
			# übersteht und hinten tief über den Hinterkopf fällt. Maße aus der Vorlage
			# (relativ zur Kopfmitte): Unterkante vorne 0,24 m, hinten −0,04 m, Kuppel oben
			# fast waagerecht bei 0,38 m, 0,7 m breit, 0,6 m tief. Je Ring: (Radius, Höhe,
			# Anteil der Randneigung) – unten voll schräg, nach oben hin waagerecht.
			# Schirm vorne, fällt 30° nach vorne ab.
			var rim_drop := 0.137
			var depth := 0.86
			var center_z := 0.015
			var cap_point := func(t: float, ring: Vector3) -> Vector3:
				var angle := t * TAU
				return Vector3(sin(angle) * ring.x, ring.y + cos(angle) * rim_drop * ring.z, center_z - cos(angle) * ring.x * depth)
			head.warped_lathe([Vector3(0.31, 0.1, 1.0), Vector3(0.335, 0.155, 0.82), Vector3(0.34, 0.22, 0.6), Vector3(0.315, 0.285, 0.36),
				Vector3(0.255, 0.335, 0.16), Vector3(0.15, 0.37, 0.05), Vector3(0.0, 0.383, 0.0)], 12, cloth, cap_point, Vector3(0, 0.15, center_z))
			head.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0, 0.39, center_z)), Vector3(0.032, 0.024, 0.032), 8, 4,
				_solid(look.hat_color.darkened(0.05)))
			# Schirm in gescherter Basis: Ansatz folgt der schrägen Unterkante
			var brim_xf := Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, -rim_drop / 0.31, depth)), Vector3(0, 0.1, center_z))
			head.lathe(brim_xf, [Vector2(0.285, -0.01), Vector2(0.31, -0.022), Vector2(0.435, -0.142), Vector2(0.45, -0.14),
				Vector2(0.44, -0.124), Vector2(0.31, 0.0), Vector2(0.285, 0.012)], 10, _solid(look.hat_color.lightened(0.06)),
				true, 1.0, 1.0, -0.11, 0.11)
		CharacterAppearance.HatStyle.CHEF_HAT:
			# Kochmütze (baker): gerades Band mit Zierstreifen (hat_color2), darüber eine
			# große, bauschige, facettierte Haube; leicht nach hinten gekippt. Vorlage: Band
			# 0,1–0,29 m über der Kopfmitte, Haube bis 0,53 m, 0,7 m breit.
			var white := _solid(look.hat_color)
			var hat_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0, 0.06, 0.0))
			head.lathe(hat_xf, [Vector2(0.27, 0.0), Vector2(0.276, 0.1), Vector2(0.272, 0.2)], 18, white, true, 1.0, 0.98)
			if look.hat_color2.a > 0.0:
				head.lathe(hat_xf, [Vector2(0.279, 0.11), Vector2(0.281, 0.14)], 18, _solid(look.hat_color2), true, 1.0, 0.98)
			# Haube: flach facettierte Kuppel, die rundum über das Band hinausquillt
			head.lathe(hat_xf, [Vector2(0.255, 0.17), Vector2(0.33, 0.195), Vector2(0.355, 0.245), Vector2(0.35, 0.305), Vector2(0.31, 0.36),
				Vector2(0.23, 0.4), Vector2(0.12, 0.42), Vector2(0.0, 0.425)], 13, white, true, 1.0, 0.95)
			for k in 5:
				var a := TAU * (float(k) + 0.2) / 5.0
				head.ellipsoid(hat_xf * Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.17, 0.37, -cos(a) * 0.16)),
					Vector3(0.15, 0.07, 0.13), 7, 4, white)
		CharacterAppearance.HatStyle.BEANIE, CharacterAppearance.HatStyle.POMPOM_BEANIE:
			# Strickmütze (sailor): breiter, gerippter Umschlag, darüber eine weiche Kuppel
			# mit Rautengitter (Strickbild der Vorlage), Bommel oben hinten. Nach hinten
			# gekippt; Vorlage: Umschlag vorne 0,04 m über der Kopfmitte, oben 0,36 m.
			var knit := CharacterKit.paint(look.hat_color, P.PLAID, 9.0, look.hat_color.darkened(0.05), look.hat_color.darkened(0.3))
			var rib := CharacterKit.paint(look.hat_color.darkened(0.04), P.PLAID, 8.0, look.hat_color.darkened(0.08), look.hat_color.darkened(0.32))
			var hat_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(18.0 + look.hat_tilt)) * Basis.from_scale(Vector3.ONE * look.hat_scale),
				Vector3(0, -0.05 + look.hat_lift, 0.03))
			head.lathe(hat_xf, [Vector2(0.295, 0.0), Vector2(0.312, 0.025), Vector2(0.315, 0.11), Vector2(0.3, 0.135)], 20, rib,
				true, 1.0, 0.97, 0.0, 1.0, 0.0, true)
			head.lathe(hat_xf, [Vector2(0.285, 0.12), Vector2(0.305, 0.18), Vector2(0.295, 0.24), Vector2(0.25, 0.3), Vector2(0.14, 0.335),
				Vector2(0.0, 0.342)], 16, knit, true, 1.0, 0.95)
			if hat == CharacterAppearance.HatStyle.POMPOM_BEANIE:
				head.ellipsoid(hat_xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0.1)), Vector3(0.105, 0.1, 0.105), 9, 6,
					_solid(look.hat_color2 if look.hat_color2.a > 0.0 else look.hat_color))
		CharacterAppearance.HatStyle.BUCKET_HAT:
			# Wanderhut (scout): sitzt oben auf dem Haar – runde, oben schmale Krone,
			# breite, hängende Krempe, Hutband (hat_color2) mit Messingknopf und weißer
			# Feder (hat_color3) links. Vorlage: Krone 0,42 m über der Kopfmitte, an der
			# Hutband-Unterkante 0,5 m breit und 0,42 m tief, Krempe 0,4 m Radius.
			var felt := _solid(look.hat_color)
			var hat_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)) * Basis.from_scale(Vector3.ONE * look.hat_scale),
				Vector3(0, 0.11, 0.02))
			var depth := 1.0
			head.lathe(hat_xf, [Vector2(0.255, 0.0), Vector2(0.258, 0.08), Vector2(0.245, 0.17), Vector2(0.205, 0.24), Vector2(0.13, 0.29),
				Vector2(0.05, 0.308), Vector2(0.0, 0.31)], 12, felt, true, 1.0, depth)
			head.lathe(hat_xf, [Vector2(0.24, -0.004), Vector2(0.32, -0.04), Vector2(0.39, -0.14), Vector2(0.405, -0.175),
				Vector2(0.39, -0.17), Vector2(0.32, -0.055), Vector2(0.24, 0.012)], 14, _solid(look.hat_color.darkened(0.03)), true, 1.0, 0.95)
			if look.hat_color2.a > 0.0:
				head.lathe(hat_xf, [Vector2(0.263, 0.02), Vector2(0.263, 0.08), Vector2(0.255, 0.09)], 18, _solid(look.hat_color2), true,
					1.0, depth)
			var side_at := hat_xf * Vector3(-0.24, 0.055, -0.1)
			head.ellipsoid(Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.FORWARD, PI * 0.5), side_at + Vector3(-0.018, 0, -0.01)),
				Vector3(0.03, 0.01, 0.03), 8, 3, CharacterKit.paint(look.accent_color, P.GLOSS))
			if look.hat_color3.a > 0.0:
				head.scale_tuft(Transform3D(Basis(Vector3.FORWARD, PI - 0.9) * Basis(Vector3.UP, 0.5), side_at + Vector3(-0.08, 0.06, 0.0)),
					0.13, 0.2, 0.07, _solid(look.hat_color3))
		CharacterAppearance.HatStyle.STRAW_HAT:
			# Strohhut (gardener): runde Kuppel, breite leicht hängende Krempe, farbiges Band
			# Maße aus der Vorlage: Krempe 0,1 m über der Kopfmitte, Krone 0,22 m hoch,
			# Krempe 0,33 m Radius, ganzer Hut 20° nach hinten gekippt.
			var straw := CharacterKit.paint(look.hat_color, P.RIBS, 40.0)
			var hat_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(20.0)), Vector3(0, 0.1, 0.0))
			head.lathe(hat_xf, [Vector2(0.285, 0.0), Vector2(0.285, 0.07), Vector2(0.275, 0.13), Vector2(0.24, 0.18), Vector2(0.17, 0.215),
				Vector2(0.08, 0.232), Vector2(0.0, 0.236)], 18, straw, true)
			head.lathe(hat_xf, [Vector2(0.28, -0.012), Vector2(0.35, -0.02), Vector2(0.395, -0.045), Vector2(0.405, -0.06),
				Vector2(0.39, -0.055), Vector2(0.345, -0.032), Vector2(0.28, 0.008)], 24, _solid(look.hat_color.darkened(0.04)), true)
			if look.hat_color2.a > 0.0:
				head.lathe(hat_xf, [Vector2(0.293, 0.012), Vector2(0.293, 0.075), Vector2(0.287, 0.085)], 22, _solid(look.hat_color2), true)


## Halstuch bzw. Winterschal um den Hals.
func _build_scarf() -> void:
	match look.scarf_style:
		CharacterAppearance.ScarfStyle.NECKERCHIEF_BACK:
			# Großes Halstuch (scout): dick um den Hals, vorne als Dreieck auf der Brust,
			# hinten links verknotet mit zwei Zipfeln
			var cloth := _solid(look.scarf_color)
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y - 0.01, 0)), 0.115, 0.036, 16, 6, cloth, 1.0, 0.86)
			torso.torus(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, NECK_Y - 0.04, -0.01)), 0.13, 0.03, 16, 5, cloth, 1.0, 0.86)
			var knot_angle := 0.66
			var knot := torso_point(knot_angle, NECK_Y - 0.03, 0.06)
			var out := torso_normal(knot_angle)
			torso.ellipsoid(Transform3D(Basis.IDENTITY, knot), Vector3(0.04, 0.036, 0.034), 8, 5, cloth)
			var along := Vector3.UP.cross(out).normalized()
			for k in 2:
				# Zipfel: einer schräg nach unten, einer zur Seite
				var dir := (Vector3.DOWN * (0.7 - 0.5 * k) + along * (0.5 + 0.4 * k) + out * 0.4).normalized()
				var y_axis := -dir
				var x_axis := y_axis.cross(out).normalized()
				var z_axis := x_axis.cross(y_axis).normalized()
				torso.scale_tuft(Transform3D(Basis(x_axis, y_axis, z_axis), knot + dir * 0.075 + out * 0.01), 0.1, 0.15, 0.03, cloth)
		CharacterAppearance.ScarfStyle.NECKERCHIEF:
			var cloth := _solid(look.scarf_color)
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y - 0.005, 0)), 0.1, 0.022, 16, 5, cloth, 1.0, 0.86)
			# Knoten vorne und zwei breite Zipfel, die über dem Hemdkragen liegen
			var knot := torso_point(0.0, NECK_Y - 0.025, 0.045)
			torso.ellipsoid(Transform3D(Basis.IDENTITY, knot), Vector3(0.032, 0.028, 0.024), 8, 5, cloth)
			for side: float in [-1.0, 1.0]:
				var a := knot + Vector3(side * 0.012, -0.012, -0.008)
				var b := torso_point(side * 0.085, NECK_Y - 0.11, 0.05)
				var c := torso_point(side * 0.02, NECK_Y - 0.125, 0.05)
				torso.triangle(a, b, c, cloth, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
					Vector3.FORWARD)
		CharacterAppearance.ScarfStyle.WRAP:
			if not winter:
				return
			var knit := _fabric(look.scarf_color, look.scarf_pattern, look.scarf_color2, 1.0)
			# Dicker, zweimal gewickelter Schal (winter_girl), ein Ende vorne links, eines
			# hinten, beide mit Fransen
			torso.torus(Transform3D(Basis.IDENTITY, Vector3(0, NECK_Y - 0.005, 0)), 0.12, 0.05, 18, 7, knit, 1.0, 0.88, 1.0)
			torso.torus(Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, NECK_Y - 0.05, -0.01)), 0.15, 0.04, 18, 6, knit, 1.0, 0.86, 1.0)
			for end: Array in [[-0.09, 0.3], [0.54, 0.22]]:
				var angle: float = end[0]
				var length: float = end[1]
				var points := [torso_point(angle, NECK_Y - 0.04, 0.07), torso_point(angle * 1.05, NECK_Y - 0.04 - length * 0.5, 0.05),
					torso_point(angle * 1.1, NECK_Y - 0.04 - length, 0.045)]
				var outward := [torso_normal(angle), torso_normal(angle), torso_normal(angle)]
				torso.strip(points, outward, 0.1, 0.03, knit)
				var tip: Vector3 = points[2]
				var n := torso_normal(angle)
				var across := Vector3.UP.cross(n).normalized()
				for k in 5:
					var at := tip + across * (float(k) - 2.0) * 0.019 + n * 0.015 + Vector3(0, -0.025, 0)
					torso.box(Transform3D(Basis.looking_at(-n, Vector3.UP), at), Vector3(0.011, 0.05, 0.01), knit)


## Runde Brille (grandpa_cardigan): zwei Ringe vor den Augen, Steg, Bügel zu den Ohren.
func _build_glasses() -> void:
	var frame := CharacterKit.paint(look.glasses_color, P.GLOSS)
	var eye_y := -0.32 * HEAD.y
	for side: float in [-1.0, 1.0]:
		var center := Vector3(side * 0.58 * HEAD.x, eye_y, -HEAD.z * 0.93)
		head.torus(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center), 0.062, 0.009, 18, 4, frame)
		head.tube([center + Vector3(side * 0.062, 0.01, 0.0), Vector3(side * HEAD.x * 0.98, eye_y + 0.012, -0.08),
			Vector3(side * HEAD.x * 1.0, eye_y + 0.005, 0.0)], 0.008, 4, frame)
	head.tube([Vector3(-0.07, eye_y + 0.012, -HEAD.z * 0.97), Vector3(0.0, eye_y + 0.024, -HEAD.z * 1.0),
		Vector3(0.07, eye_y + 0.012, -HEAD.z * 0.97)], 0.008, 4, frame)


## Wolkenbüschel (graues Haar, Bart): grob facettiertes Ellipsoid.
func _puff(at: Vector3, radii: Vector3, paint: CharacterKit.Paint) -> void:
	head.ellipsoid(Transform3D(Basis.IDENTITY, at), radii, 7, 5, paint, true)


## Schleife: Knoten, zwei flache, facettierte Schlaufen (Pyramiden mit der Spitze zum
## Knoten) und zwei kurze Zipfel. [param yaw] dreht sie zur Seite, [param roll] kippt sie.
func _bow(kit: CharacterKit, center: Vector3, yaw: float, roll: float, paint: CharacterKit.Paint, size := 1.0, tail := 1.0,
		ribbon := false) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll) * Basis.from_scale(Vector3.ONE * size), center)
	kit.ellipsoid(frame, Vector3(0.036, 0.038, 0.03), 8, 5, paint)
	for side: float in [-1.0, 1.0]:
		var outer := Vector3(side * 0.185, 0.012, 0.0)
		var lobe := Basis.looking_at(Vector3(-side, -0.08, 0.0).normalized(), Vector3.UP)
		lobe.x = lobe.x * 0.6
		kit.pyramid(frame * Transform3D(lobe, outer), 0.1, 0.172, 6, paint)
		if ribbon:
			# Breite Bänder mit gerade abgeschnittenem Ende (Schürzenschleife)
			kit.box(frame * Transform3D(Basis(Vector3.FORWARD, side * 0.22), Vector3(side * 0.035, -0.06 * tail, 0.004)),
				Vector3(0.075, 0.12 * tail, 0.014), paint)
			continue
		kit.scale_tuft(frame * Transform3D(Basis(Vector3.FORWARD, side * 0.45 / tail), Vector3(side * 0.03, -0.065 * tail, -0.004)),
			0.06, 0.12 * tail, 0.025, paint)


## Punkt auf der Kopfform (Superellipsoid wie CharacterKit.head_shape) in Richtung
## Azimut/Höhe (Grad; Azimut 0 = vorne).
func _face_point(az: float, el: float, power := 2.6) -> Vector3:
	var a := deg_to_rad(az)
	var e := deg_to_rad(el)
	var d := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
	var sum := pow(absf(d.x / HEAD.x), power) + pow(absf(d.y / HEAD.y), power) + pow(absf(d.z / HEAD.z), power)
	return d * pow(sum, -1.0 / power)


## Vollbart aus facettierten Büscheln (smith): Koteletten vor den Ohren, über die Wangen
## unterhalb der Bäckchen bis unters Kinn; Mund bleibt frei. Schnurrbart aus zwei
## hängenden Wülsten zwischen Nase und Mund.
func _build_beard() -> void:
	var hair := _solid(look.hair_color)
	var hair_dark := _solid(look.hair_color.darkened(0.12))
	if look.beard:
		# Je Azimut die Oberkante des Barts (Grad): Koteletten hoch, Wangen unter den
		# Bäckchen, vorne erst unter dem Mund
		var columns := [[100.0, 6.0], [86.0, 0.0], [72.0, -16.0], [58.0, -34.0], [44.0, -46.0], [30.0, -54.0], [15.0, -56.0], [0.0, -58.0]]
		var k := 0
		for column: Array in columns:
			for side: float in ([1.0] if float(column[0]) == 0.0 else [-1.0, 1.0]):
				var az: float = column[0] * side
				var el: float = column[1]
				while el >= -82.0:
					var p := _face_point(az, el)
					k += 1
					head.ellipsoid(Transform3D(Basis(Vector3.UP, deg_to_rad(az)) * Basis(Vector3.RIGHT, deg_to_rad(el) * 0.5), p),
						Vector3(0.056, 0.054, 0.036), 7, 4, hair if k % 3 != 0 else hair_dark)
					el -= 18.0
		# Kinnbart: hängt unter dem Kinn etwas tiefer
		for az: float in [-36.0, -12.0, 12.0, 36.0]:
			var p := _face_point(az, -84.0) + Vector3(0, -0.035, -0.035)
			head.ellipsoid(Transform3D(Basis(Vector3.UP, deg_to_rad(az)), p), Vector3(0.06, 0.055, 0.05), 7, 4, hair)
	if look.mustache or look.beard:
		for side: float in [-1.0, 1.0]:
			head.ellipsoid(Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 0.048, -0.138, -HEAD.z + 0.01)),
				Vector3(0.055, 0.025, 0.028), 8, 4, hair)
