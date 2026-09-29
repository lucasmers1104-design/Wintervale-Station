@tool
## Prozedurale Modelle für die Dorffeste (Etappe 10): Marktbuden mit Waren,
## Weihnachtsbaum, Kinderkarussell, Eingangsbogen, Stehtische, Bühne,
## Lagerfeuer, Heuballen, Kürbisse, Wimpel- und Laternenketten.
##
## Wie alle Modelle: Vertexfarben, Alpha = Schnee-Merker (< 0.6 Schneeauflage,
## taut im Frühling weg). Leuchtende Teile (Birnen, Kerzenflammen, Glut, Stern)
## landen in einem zweiten SurfaceTool "glow" mit dem Material
## festival_lights.gdshader – dort ist Alpha ein Zufallswert je Birne (Funkeln).
##
## Koordinaten je Modell: Ursprung am Boden, -Z = Vorderseite (Kundenseite).
class_name FestivalMeshes
extends RefCounted

const WOOD := Color(0.55, 0.37, 0.23)
const WOOD_LIGHT := Color(0.7, 0.52, 0.34)
const WOOD_DARK := Color(0.36, 0.24, 0.16)
const ROOF_RED := Color(0.58, 0.18, 0.14)
const ROOF_GREEN := Color(0.2, 0.36, 0.27)
const SNOW := Color(0.9, 0.93, 0.97, 0.5)
const SNOW_SHADE := Color(0.82, 0.86, 0.93, 0.5)
const NEEDLES := Color(0.14, 0.3, 0.21)
const NEEDLES_LIGHT := Color(0.2, 0.39, 0.26)
const GOLD := Color(0.92, 0.72, 0.28)
const IRON := Color(0.2, 0.2, 0.22)
const CLOTH_RED := Color(0.72, 0.18, 0.16)
const CLOTH_CREAM := Color(0.93, 0.88, 0.76)
const WARM_BULB := Color(1.0, 0.8, 0.5)
const AMBER_BULB := Color(1.0, 0.6, 0.25)
const FLAME := Color(1.0, 0.72, 0.32)

## Budengröße: Breite (X), Tiefe (Z), Höhe der Theke, Traufhöhe.
const STALL_WIDTH := 2.6
const STALL_DEPTH := 1.8
const COUNTER_HEIGHT := 1.05
const EAVE_HEIGHT := 2.3

## Waren je Budenart: Beschriftung und Farbe des Dachs.
const STALL_TYPES := {
	"gluehwein": {"label": "Glühwein", "roof": ROOF_RED},
	"lebkuchen": {"label": "Lebkuchen", "roof": ROOF_GREEN},
	"kerzen": {"label": "Kerzen & Sterne", "roof": ROOF_RED},
	"spielzeug": {"label": "Holzspielzeug", "roof": ROOF_GREEN},
	"maronen": {"label": "Heiße Maronen", "roof": Color(0.46, 0.28, 0.18)},
	"apfelmost": {"label": "Apfelmost", "roof": Color(0.62, 0.34, 0.14)},
	"kuerbis": {"label": "Kürbisse", "roof": Color(0.45, 0.4, 0.18)},
	"zwiebelkuchen": {"label": "Zwiebelkuchen", "roof": Color(0.55, 0.22, 0.16)},
	"honig": {"label": "Honig & Wachs", "roof": Color(0.66, 0.5, 0.16)},
}


# --- Marktbude -----------------------------------------------------------------------

## Holzbude mit Satteldach, Theke und Waren. Rückgabe:
## {"shutter": ArrayMesh (Laden, Scharnier im Ursprung), "shutter_pivot": Vector3,
##  "sign": Transform3D (Schild für die Beschriftung), "customer": Vector3 (Kunde vor der Theke),
##  "keeper": Vector3 (Verkäufer dahinter), "lamp": Vector3, "steam": Vector3 oder INF}
static func stall(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var info: Dictionary = STALL_TYPES.get(kind, STALL_TYPES["gluehwein"])
	var roof_color: Color = info["roof"]
	var hw := STALL_WIDTH * 0.5
	var hd := STALL_DEPTH * 0.5
	# Boden aus Brettern und vier Eckpfosten
	for i in 6:
		var z := -hd + (i + 0.5) * STALL_DEPTH / 6.0
		LowPolyBuilder.add_box(st, Vector3(0, 0.06, z), Vector3(STALL_WIDTH, 0.08, STALL_DEPTH / 6.0 - 0.02), _vary(WOOD_DARK, rng))
	for x: float in [-hw + 0.06, hw - 0.06]:
		for z: float in [-hd + 0.06, hd - 0.06]:
			LowPolyBuilder.add_box(st, Vector3(x, EAVE_HEIGHT * 0.5, z), Vector3(0.12, EAVE_HEIGHT, 0.12), WOOD_DARK)
	# Rückwand und Seitenwände aus senkrechten Brettern (Seiten bis zur Theke offen)
	var boards := 11
	for i in boards:
		var x := -hw + (i + 0.5) * STALL_WIDTH / boards
		LowPolyBuilder.add_box(st, Vector3(x, EAVE_HEIGHT * 0.5, hd - 0.03), Vector3(STALL_WIDTH / boards - 0.012, EAVE_HEIGHT, 0.05),
			_vary(WOOD, rng, 0.04))
	for side: float in [-1.0, 1.0]:
		for i in 7:
			var z := -hd + 0.1 + (i + 0.5) * (STALL_DEPTH - 0.1) / 7.0
			LowPolyBuilder.add_box(st, Vector3(side * (hw - 0.03), EAVE_HEIGHT * 0.5, z),
				Vector3(0.05, EAVE_HEIGHT, (STALL_DEPTH - 0.1) / 7.0 - 0.012), _vary(WOOD, rng, 0.04))
	# Theke vorne: Brettfront und Thekenplatte, darunter ein Tannenzweig-Kranz
	LowPolyBuilder.add_box(st, Vector3(0, COUNTER_HEIGHT * 0.5, -hd + 0.05), Vector3(STALL_WIDTH - 0.1, COUNTER_HEIGHT, 0.08), _vary(WOOD, rng))
	for i in 5:
		LowPolyBuilder.add_box(st, Vector3(-hw + 0.3 + i * 0.5, COUNTER_HEIGHT * 0.5, -hd + 0.005), Vector3(0.03, COUNTER_HEIGHT - 0.1, 0.02), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(0, COUNTER_HEIGHT + 0.03, -hd + 0.18), Vector3(STALL_WIDTH + 0.06, 0.06, 0.5), WOOD_LIGHT)
	# Innen: Regalbrett an der Rückwand
	LowPolyBuilder.add_box(st, Vector3(0, 1.55, hd - 0.2), Vector3(STALL_WIDTH - 0.2, 0.04, 0.3), WOOD_LIGHT)
	# Satteldach mit Überstand, Firstbalken, Schnee und Zierbrettern an den Giebeln
	var ridge_y := EAVE_HEIGHT + 0.85
	var over := 0.35
	for side: float in [-1.0, 1.0]:
		var eave := Vector3(0, EAVE_HEIGHT - 0.05, side * (hd + over))
		var ridge := Vector3(0, ridge_y, 0)
		var x0 := -hw - 0.25
		var x1 := hw + 0.25
		var outward := Vector3(0, 1.0, side * 0.9)
		var planks := 8
		for i in planks:
			var xa := lerpf(x0, x1, float(i) / planks)
			var xb := lerpf(x0, x1, float(i + 1) / planks)
			LowPolyBuilder.add_quad_facing(st, Vector3(xa, eave.y, eave.z), Vector3(xb, eave.y, eave.z), Vector3(xb, ridge.y, 0),
				Vector3(xa, ridge.y, 0), _vary(roof_color, rng, 0.03), outward)
			LowPolyBuilder.add_quad_facing(st, Vector3(xa, eave.y - 0.06, eave.z), Vector3(xb, eave.y - 0.06, eave.z),
				Vector3(xb, ridge.y - 0.06, 0), Vector3(xa, ridge.y - 0.06, 0), WOOD_DARK, -outward)
		# Schnee: etwas kleiner und darüber, mit wulstiger Kante
		var lift := Vector3(0, 0.05, 0)
		LowPolyBuilder.add_quad_facing(st, Vector3(x0 + 0.05, eave.y, eave.z * 0.97) + lift, Vector3(x1 - 0.05, eave.y, eave.z * 0.97) + lift,
			Vector3(x1 - 0.05, ridge.y, 0) + lift, Vector3(x0 + 0.05, ridge.y, 0) + lift, SNOW, outward)
		LowPolyBuilder.add_box(st, Vector3(0, eave.y + 0.06, eave.z * 0.95), Vector3(x1 - x0 - 0.2, 0.09, 0.14), SNOW_SHADE)
		# Traufbrett
		LowPolyBuilder.add_box(st, Vector3(0, eave.y - 0.02, eave.z), Vector3(x1 - x0, 0.12, 0.04), roof_color.darkened(0.25))
	LowPolyBuilder.add_box(st, Vector3(0, ridge_y + 0.03, 0), Vector3(STALL_WIDTH + 0.6, 0.1, 0.12), WOOD_DARK)
	for end: float in [-1.0, 1.0]:
		var x := end * (hw + 0.02)
		LowPolyBuilder.add_triangle_facing(st, Vector3(x, EAVE_HEIGHT, -hd), Vector3(x, EAVE_HEIGHT, hd), Vector3(x, ridge_y - 0.05, 0),
			_vary(WOOD, rng), Vector3(end, 0, 0))
		# Tannenzweige und rote Schleife am Giebel
		for k in 5:
			var a := float(k) / 4.0
			var p := Vector3(x + end * 0.05, lerpf(EAVE_HEIGHT + 0.1, ridge_y - 0.15, 1.0 - absf(a - 0.5) * 2.0), lerpf(-hd, hd, a) * 0.85)
			LowPolyBuilder.add_box(st, p, Vector3(0.1, 0.16, 0.34), NEEDLES_LIGHT if k % 2 == 0 else NEEDLES)
		LowPolyBuilder.add_box(st, Vector3(x + end * 0.1, ridge_y - 0.35, 0), Vector3(0.05, 0.16, 0.2), CLOTH_RED)
	# Schild über der Theke
	var sign_center := Vector3(0, EAVE_HEIGHT + 0.12, -hd - over + 0.02)
	LowPolyBuilder.add_box(st, sign_center, Vector3(1.7, 0.34, 0.05), WOOD_LIGHT.lightened(0.1))
	LowPolyBuilder.add_box(st, sign_center + Vector3(0, 0, 0.01), Vector3(1.78, 0.4, 0.04), WOOD_DARK)
	LowPolyBuilder.add_box(st, sign_center + Vector3(0, 0.22, 0.0), Vector3(1.6, 0.05, 0.1), SNOW)
	# Lichterkette unter der vorderen Traufe (leicht durchhängend)
	_bulb_chain(glow, Vector3(-hw - 0.2, EAVE_HEIGHT - 0.14, -hd - over + 0.02), Vector3(hw + 0.2, EAVE_HEIGHT - 0.14, -hd - over + 0.02),
		16, 0.1, [WARM_BULB, WARM_BULB, AMBER_BULB], rng)
	_bulb_chain(glow, Vector3(-hw - 0.2, EAVE_HEIGHT - 0.14, hd + over - 0.02), Vector3(hw + 0.2, EAVE_HEIGHT - 0.14, hd + over - 0.02),
		14, 0.08, [WARM_BULB, AMBER_BULB], rng)
	# Innenlampe (Glühbirne unter dem Dach)
	var lamp := Vector3(0, EAVE_HEIGHT - 0.1, 0.1)
	LowPolyBuilder.add_box(st, lamp + Vector3(0, 0.2, 0), Vector3(0.02, 0.4, 0.02), IRON)
	_bulb(glow, lamp, 0.07, WARM_BULB, 0.9)
	var steam := Vector3.INF
	match kind:
		"gluehwein":
			steam = _goods_gluehwein(st, glow, rng)
		"lebkuchen":
			_goods_lebkuchen(st, rng)
		"kerzen":
			_goods_kerzen(st, glow, rng)
		"spielzeug":
			_goods_spielzeug(st, rng)
		"maronen":
			steam = _goods_maronen(st, glow, rng)
		"apfelmost":
			_goods_apfelmost(st, rng)
		"kuerbis":
			_goods_kuerbis(st, rng)
		"zwiebelkuchen":
			steam = _goods_zwiebelkuchen(st, rng)
		"honig":
			_goods_honig(st, glow, rng)
	# Laden: Bretterklappe, Scharnier an der Traufe; zu = hängt vor der Öffnung
	var shutter := TrainMeshes._new_st()
	var height := EAVE_HEIGHT - 0.12 - COUNTER_HEIGHT - 0.08
	for i in 9:
		var x := -hw + 0.1 + (i + 0.5) * (STALL_WIDTH - 0.2) / 9.0
		LowPolyBuilder.add_box(shutter, Vector3(x, -height * 0.5, -0.03), Vector3((STALL_WIDTH - 0.2) / 9.0 - 0.01, height, 0.05),
			_vary(roof_color.lerp(WOOD, 0.35), rng, 0.03))
	for y: float in [-0.15, -height + 0.15]:
		LowPolyBuilder.add_box(shutter, Vector3(0, y, -0.065), Vector3(STALL_WIDTH - 0.3, 0.08, 0.03), WOOD_DARK)
	LowPolyBuilder.add_box(shutter, Vector3(0, -height * 0.5, -0.075), Vector3(0.05, height - 0.2, 0.02), WOOD_DARK)
	return {
		"shutter": shutter.commit(), "shutter_pivot": Vector3(0, EAVE_HEIGHT - 0.12, -hd - 0.02),
		"sign": Transform3D(Basis(Vector3.UP, PI), sign_center + Vector3(0, 0, -0.035)),
		"customer": Vector3(rng.randf_range(-0.4, 0.4), 0, -hd - 0.75), "keeper": Vector3(0, 0.1, 0.05),
		"lamp": lamp, "steam": steam, "label": info["label"],
	}


static func _goods_gluehwein(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> Vector3:
	var top := COUNTER_HEIGHT + 0.06
	# Großer Kupfertopf auf einem Stövchen, Schöpfkelle
	var pot := Vector3(-0.6, top, -0.62)
	LowPolyBuilder.add_cylinder(st, pot, 0.26, 0.28, 0.08, 12, IRON)
	LowPolyBuilder.add_cylinder(st, pot + Vector3(0, 0.08, 0), 0.3, 0.32, 0.34, 14, Color(0.72, 0.4, 0.24))
	LowPolyBuilder.add_cylinder(st, pot + Vector3(0, 0.4, 0), 0.28, 0.28, 0.01, 14, Color(0.42, 0.08, 0.1))
	LowPolyBuilder.add_cylinder_between(st, pot + Vector3(0.1, 0.36, 0), pot + Vector3(0.28, 0.75, 0.1), 0.02, 5, METAL_LIGHT)
	# Becher in Reihen (rot mit weißem Stern), dazu Orangen und Zimt
	for i in 8:
		var p := Vector3(-0.1 + (i % 4) * 0.2, top, -0.72 + floorf(i / 4.0) * 0.2)
		LowPolyBuilder.add_cylinder(st, p, 0.055, 0.06, 0.13, 8, CLOTH_RED if i % 3 != 0 else Color(0.2, 0.36, 0.5))
		LowPolyBuilder.add_box(st, p + Vector3(0.065, 0.07, 0), Vector3(0.02, 0.07, 0.02), CLOTH_RED)
	for i in 4:
		LowPolyBuilder.add_rock(st, rng, Vector3(0.75 + i * 0.1, top + 0.05, -0.6 + (i % 2) * 0.12), 0.06, Color(0.95, 0.55, 0.15),
			Color(0.95, 0.55, 0.15), 3, 6)
	# Fässer hinten und Kerzenglas
	for x: float in [-0.8, 0.8]:
		LowPolyBuilder.add_cylinder(st, Vector3(x, 0.1, 0.45), 0.28, 0.3, 0.7, 12, WOOD)
		for y: float in [0.22, 0.62]:
			LowPolyBuilder.add_cylinder(st, Vector3(x, 0.1 + y, 0.45), 0.31, 0.31, 0.04, 12, IRON)
	_bulb(glow, Vector3(0.45, top + 0.06, -0.55), 0.04, FLAME, 0.3)
	return pot + Vector3(0, 0.45, 0)


static func _goods_lebkuchen(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	# Lebkuchenherzen hängen an einer Stange unter der Traufe, dazu Plätzchen auf Tellern
	var bar_y := EAVE_HEIGHT - 0.32
	LowPolyBuilder.add_box(st, Vector3(0, bar_y, -0.72), Vector3(STALL_WIDTH - 0.3, 0.04, 0.04), WOOD_DARK)
	for i in 7:
		var x := -1.0 + i * 0.33
		var size := rng.randf_range(0.17, 0.26)
		var hang := rng.randf_range(0.14, 0.34)
		LowPolyBuilder.add_box(st, Vector3(x, bar_y - hang * 0.5, -0.72), Vector3(0.01, hang, 0.01), CLOTH_RED)
		_heart(st, Vector3(x, bar_y - hang - size * 0.45, -0.72), size, rng)
	var top := COUNTER_HEIGHT + 0.06
	for x: float in [-0.75, 0.0, 0.75]:
		LowPolyBuilder.add_cylinder(st, Vector3(x, top, -0.62), 0.22, 0.24, 0.02, 12, CLOTH_CREAM)
		for k in 5:
			var a := TAU * k / 5.0 + rng.randf()
			var p := Vector3(x + cos(a) * 0.1, top + 0.03, -0.62 + sin(a) * 0.1)
			LowPolyBuilder.add_cylinder(st, p, 0.05, 0.05, 0.02, 6, Color(0.66, 0.38, 0.2).lerp(Color(0.85, 0.65, 0.38), rng.randf()))
	# Regal hinten mit Dosen
	for i in 6:
		LowPolyBuilder.add_cylinder(st, Vector3(-0.9 + i * 0.36, 1.57, 0.7), 0.09, 0.09, 0.16, 8,
			[CLOTH_RED, ROOF_GREEN, GOLD][i % 3])


static func _goods_kerzen(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var top := COUNTER_HEIGHT + 0.06
	var colors := [CLOTH_CREAM, Color(0.85, 0.2, 0.18), Color(0.93, 0.8, 0.45), Color(0.3, 0.52, 0.4)]
	for i in 14:
		var p := Vector3(rng.randf_range(-1.1, 1.1), top, rng.randf_range(-0.78, -0.45))
		var h := rng.randf_range(0.1, 0.34)
		var r := rng.randf_range(0.035, 0.07)
		LowPolyBuilder.add_cylinder(st, p, r, r, h, 8, colors[rng.randi() % colors.size()])
		if rng.randf() < 0.55:
			_flame(glow, p + Vector3(0, h, 0), rng)
	# Strohsterne und Papiersterne hängen unter dem Dach
	for i in 6:
		var p := Vector3(-1.0 + i * 0.4, EAVE_HEIGHT - 0.45 - (i % 2) * 0.15, -0.6)
		LowPolyBuilder.add_box(st, p + Vector3(0, 0.12, 0), Vector3(0.01, 0.2, 0.01), CLOTH_RED)
		_star(st, p, 0.11, 0.04, GOLD if i % 2 == 0 else CLOTH_CREAM, Basis.IDENTITY)
	for i in 5:
		LowPolyBuilder.add_cylinder(st, Vector3(-0.9 + i * 0.45, 1.57, 0.7), 0.06, 0.06, 0.28, 8, colors[i % colors.size()])


static func _goods_spielzeug(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var top := COUNTER_HEIGHT + 0.06
	# Kleine Holzeisenbahn auf der Theke
	for i in 3:
		var p := Vector3(-0.9 + i * 0.3, top, -0.62)
		LowPolyBuilder.add_box(st, p + Vector3(0, 0.08, 0), Vector3(0.26, 0.1, 0.14), [CLOTH_RED, ROOF_GREEN, Color(0.25, 0.4, 0.66)][i])
		if i == 0:
			LowPolyBuilder.add_box(st, p + Vector3(-0.04, 0.17, 0), Vector3(0.12, 0.1, 0.12), CLOTH_RED.darkened(0.2))
			LowPolyBuilder.add_cylinder(st, p + Vector3(0.08, 0.13, 0), 0.03, 0.03, 0.08, 6, IRON)
		for x: float in [-0.08, 0.08]:
			for z: float in [-0.08, 0.08]:
				LowPolyBuilder.add_cylinder_between(st, p + Vector3(x, 0.035, z), p + Vector3(x, 0.035, z * 1.2), 0.035, 8, WOOD_DARK)
	# Nussknacker
	for k in 2:
		var p := Vector3(0.45 + k * 0.35, top, -0.6)
		LowPolyBuilder.add_cylinder(st, p, 0.06, 0.06, 0.16, 8, Color(0.2, 0.22, 0.42))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.16, 0), 0.07, 0.065, 0.16, 8, CLOTH_RED)
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.32, 0), 0.05, 0.05, 0.08, 8, Color(0.93, 0.78, 0.66))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.4, 0), 0.055, 0.055, 0.1, 8, Color(0.12, 0.12, 0.14))
		LowPolyBuilder.add_box(st, p + Vector3(0, 0.36, -0.055), Vector3(0.06, 0.03, 0.02), Color(0.95, 0.95, 0.9))
	# Schaukelpferd hinten
	var h := Vector3(0.0, 0.1, 0.45)
	LowPolyBuilder.add_box(st, h + Vector3(0, 0.45, 0), Vector3(0.5, 0.18, 0.16), Color(0.92, 0.9, 0.85))
	LowPolyBuilder.add_box(st, h + Vector3(0.3, 0.62, 0), Vector3(0.12, 0.3, 0.12), Color(0.92, 0.9, 0.85))
	LowPolyBuilder.add_box(st, h + Vector3(0.38, 0.75, 0), Vector3(0.2, 0.1, 0.1), Color(0.92, 0.9, 0.85))
	LowPolyBuilder.add_box(st, h + Vector3(0.22, 0.66, 0), Vector3(0.06, 0.22, 0.05), CLOTH_RED)
	for x: float in [-0.18, 0.18]:
		LowPolyBuilder.add_beam(st, h + Vector3(x, 0.4, 0.05), h + Vector3(x * 1.2, 0.08, 0.1), 0.04, WOOD_DARK)
		LowPolyBuilder.add_beam(st, h + Vector3(x, 0.4, -0.05), h + Vector3(x * 1.2, 0.08, -0.1), 0.04, WOOD_DARK)
	for z: float in [-0.12, 0.12]:
		LowPolyBuilder.add_box(st, h + Vector3(0, 0.05, z), Vector3(0.8, 0.04, 0.04), CLOTH_RED.darkened(0.3))
	_star(st, Vector3(-0.7, 1.75, 0.72), 0.12, 0.04, GOLD, Basis.IDENTITY)


static func _goods_maronen(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> Vector3:
	var top := COUNTER_HEIGHT + 0.06
	# Röstofen: eiserner Kessel mit glühenden Kohlen, darauf die Pfanne
	var oven := Vector3(-0.5, top, -0.6)
	LowPolyBuilder.add_cylinder(st, oven, 0.28, 0.24, 0.25, 10, IRON)
	for k in 6:
		var a := TAU * k / 6.0
		_bulb(glow, oven + Vector3(cos(a) * 0.14, 0.22, sin(a) * 0.14), 0.05, Color(1.0, 0.35, 0.1), rng.randf())
	LowPolyBuilder.add_cylinder(st, oven + Vector3(0, 0.27, 0), 0.3, 0.3, 0.05, 12, IRON.lightened(0.1))
	for k in 12:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.22
		LowPolyBuilder.add_rock(st, rng, oven + Vector3(cos(a) * r, 0.34, sin(a) * r), 0.04, Color(0.45, 0.24, 0.13),
			Color(0.45, 0.24, 0.13), 3, 5)
	# Spitztüten aus Papier
	for i in 5:
		var p := Vector3(0.2 + i * 0.2, top, -0.65)
		LowPolyBuilder.add_cone(st, p + Vector3(0, 0.2, 0), 0.06, -0.2, 6, CLOTH_CREAM.darkened(0.08), 0.0, true)
	LowPolyBuilder.add_cylinder(st, Vector3(0.8, 0.1, 0.4), 0.3, 0.3, 0.55, 10, Color(0.5, 0.36, 0.22))
	return oven + Vector3(0, 0.4, 0)


static func _goods_apfelmost(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var top := COUNTER_HEIGHT + 0.06
	# Apfelkisten auf der Theke, Flaschen und Krüge
	for k in 2:
		var c := Vector3(-0.75 + k * 0.5, top, -0.6)
		_crate(st, c, rng)
		for i in 9:
			var p := c + Vector3(-0.12 + (i % 3) * 0.12, 0.2, -0.1 + floorf(i / 3.0) * 0.1)
			var apple := Color(0.78, 0.16, 0.12) if (i + k) % 3 != 0 else Color(0.62, 0.72, 0.22)
			LowPolyBuilder.add_rock(st, rng, p, 0.055, apple, apple, 3, 6)
	for i in 5:
		var p := Vector3(0.2 + i * 0.18, top, -0.62)
		LowPolyBuilder.add_cylinder(st, p, 0.05, 0.05, 0.22, 8, Color(0.62, 0.42, 0.12))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.22, 0), 0.05, 0.02, 0.08, 8, Color(0.62, 0.42, 0.12))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.3, 0), 0.022, 0.022, 0.03, 6, CLOTH_RED)
	for x: float in [-0.8, 0.0, 0.8]:
		LowPolyBuilder.add_cylinder(st, Vector3(x, 0.1, 0.45), 0.28, 0.3, 0.72, 12, WOOD)
		for y: float in [0.22, 0.62]:
			LowPolyBuilder.add_cylinder(st, Vector3(x, 0.1 + y, 0.45), 0.31, 0.31, 0.04, 12, IRON)


static func _goods_kuerbis(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var top := COUNTER_HEIGHT + 0.06
	for i in 5:
		pumpkin(st, rng, Vector3(-1.0 + i * 0.5, top, -0.62), rng.randf_range(0.11, 0.18))
	# Großer Stapel vor der Bude
	for i in 6:
		var p := Vector3(-1.1 + (i % 3) * 0.5 + rng.randf_range(-0.1, 0.1), 0.0, -STALL_DEPTH * 0.5 - 0.35 - floorf(i / 3.0) * 0.3)
		if i >= 3:
			p.x += 1.4
		pumpkin(st, rng, p, rng.randf_range(0.17, 0.28))
	for i in 3:
		pumpkin(st, rng, Vector3(-0.7 + i * 0.7, 1.57, 0.7), 0.12)


static func _goods_zwiebelkuchen(st: SurfaceTool, rng: RandomNumberGenerator) -> Vector3:
	var top := COUNTER_HEIGHT + 0.06
	for x: float in [-0.7, 0.05]:
		LowPolyBuilder.add_box(st, Vector3(x, top + 0.02, -0.6), Vector3(0.62, 0.04, 0.42), IRON.lightened(0.2))
		LowPolyBuilder.add_box(st, Vector3(x, top + 0.06, -0.6), Vector3(0.58, 0.05, 0.38), Color(0.9, 0.74, 0.4))
		for k in 5:
			LowPolyBuilder.add_box(st, Vector3(x - 0.2 + k * 0.1, top + 0.09, -0.6), Vector3(0.01, 0.01, 0.36), Color(0.6, 0.42, 0.2))
	# Brotlaibe im Korb
	LowPolyBuilder.add_cylinder(st, Vector3(0.75, top, -0.6), 0.22, 0.26, 0.12, 10, Color(0.62, 0.46, 0.26))
	for k in 4:
		LowPolyBuilder.add_rock(st, rng, Vector3(0.66 + (k % 2) * 0.18, top + 0.16, -0.66 + floorf(k / 2.0) * 0.13), 0.09,
			Color(0.78, 0.52, 0.26), Color(0.86, 0.62, 0.32), 3, 6)
	return Vector3(-0.3, top + 0.12, -0.6)


static func _goods_honig(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var top := COUNTER_HEIGHT + 0.06
	for i in 10:
		var p := Vector3(-1.05 + (i % 5) * 0.22, top, -0.72 + floorf(i / 5.0) * 0.2)
		LowPolyBuilder.add_cylinder(st, p, 0.06, 0.06, 0.13, 8, Color(0.88, 0.58, 0.14))
		LowPolyBuilder.add_cylinder(st, p + Vector3(0, 0.13, 0), 0.075, 0.075, 0.03, 8, [CLOTH_RED, CLOTH_CREAM, ROOF_GREEN][i % 3])
	# Bienenwachskerzen (gerollt) mit Flamme
	for i in 4:
		var p := Vector3(0.35 + i * 0.2, top, -0.62)
		LowPolyBuilder.add_cylinder(st, p, 0.045, 0.045, 0.24, 8, Color(0.95, 0.78, 0.36))
		if i % 2 == 0:
			_flame(glow, p + Vector3(0, 0.24, 0), rng)
	# Bienenkorb aus Stroh
	var skep := Vector3(0.75, 0.1, 0.45)
	for k in 6:
		var r := 0.32 - k * 0.045
		LowPolyBuilder.add_cylinder(st, skep + Vector3(0, k * 0.1, 0), r, r - 0.03, 0.1, 12, Color(0.82, 0.66, 0.36).darkened(k % 2 * 0.08))


# --- Weihnachtsbaum --------------------------------------------------------------------

## Großer, geschmückter Weihnachtsbaum (~7,5 m) mit Stern, Kugeln, Geschenken und
## einer spiraligen Lichterkette (im "glow"). Rückgabe: {"height", "star": Vector3}.
static func christmas_tree(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> Dictionary:
	var height := 7.4
	# Holzkiste als Fuß, Stamm
	LowPolyBuilder.add_box(st, Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 1.3), WOOD)
	for y: float in [0.12, 0.48]:
		LowPolyBuilder.add_box(st, Vector3(0, y, 0), Vector3(1.34, 0.06, 1.34), WOOD_DARK)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.6, 0), 0.22, 0.18, 1.0, 8, Color(0.33, 0.23, 0.16))
	# Sieben Nadelkränze, nach oben kleiner, leicht verdreht, mit Schneekappen
	var tiers := 7
	for i in tiers:
		var t := float(i) / tiers
		var base_y := 1.0 + t * (height - 1.6)
		var radius := lerpf(2.5, 0.55, t)
		var tier_h := lerpf(1.7, 1.0, t)
		var angle := rng.randf() * TAU
		LowPolyBuilder.add_cone(st, Vector3(0, base_y, 0), radius, tier_h, 11, NEEDLES_LIGHT.lerp(NEEDLES, rng.randf() * 0.6), angle)
		# Schneekappe: flacher Kegel etwas darüber (Schneeauflage)
		LowPolyBuilder.add_cone(st, Vector3(0, base_y + tier_h * 0.3, 0), radius * 0.72, tier_h * 0.72, 11, SNOW, angle + 0.1, false)
		# Kugeln am Rand des Kranzes
		var balls := int(lerpf(12, 4, t))
		for k in balls:
			var a := TAU * (k + rng.randf() * 0.5) / balls
			var r := radius * 0.9
			var p := Vector3(cos(a) * r, base_y + 0.08, sin(a) * r)
			var color: Color = [CLOTH_RED, GOLD, Color(0.85, 0.87, 0.92), Color(0.2, 0.4, 0.7)][rng.randi() % 4]
			LowPolyBuilder.add_rock(st, rng, p, 0.11, color, color, 3, 7)
	# Lichterkette als Spirale von unten nach oben
	var turns := 6.5
	var bulbs := 150
	for k in bulbs:
		var t := float(k) / bulbs
		var y := 1.2 + t * (height - 1.9)
		# Radius folgt der Kegelhülle: an jeder Höhe knapp außerhalb der Nadeln
		var local := fposmod((y - 1.0) / ((height - 1.6) / tiers), 1.0)
		var tier_radius := lerpf(2.5, 0.55, clampf((y - 1.0) / (height - 1.6), 0.0, 1.0))
		var r := tier_radius * lerpf(1.0, 0.45, local) + 0.05
		var a := t * turns * TAU
		var color: Color = [WARM_BULB, WARM_BULB, AMBER_BULB, Color(1.0, 0.92, 0.75)][k % 4]
		_bulb(glow, Vector3(cos(a) * r, y, sin(a) * r), 0.055, color, rng.randf())
	# Stern auf der Spitze (leuchtend)
	var star := Vector3(0, height + 0.15, 0)
	_star(glow, star, 0.45, 0.14, Color(1.0, 0.85, 0.4, 0.2), Basis.IDENTITY)
	# Geschenke am Fuß
	var gift_colors := [CLOTH_RED, ROOF_GREEN, Color(0.25, 0.4, 0.66), GOLD, CLOTH_CREAM]
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf() * 0.4
		var r := rng.randf_range(1.0, 1.5)
		var size := Vector3(rng.randf_range(0.3, 0.55), rng.randf_range(0.22, 0.45), rng.randf_range(0.3, 0.5))
		var p := Vector3(cos(a) * r, size.y * 0.5, sin(a) * r)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		var color: Color = gift_colors[k % gift_colors.size()]
		var ribbon: Color = GOLD if color != GOLD else CLOTH_RED
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p), size, color)
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p), Vector3(size.x + 0.01, size.y + 0.01, 0.06), ribbon)
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p), Vector3(0.06, size.y + 0.01, size.z + 0.01), ribbon)
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p + Vector3(0, size.y * 0.5 + 0.04, 0)), Vector3(0.14, 0.06, 0.14), ribbon)
		LowPolyBuilder.add_oriented_box(st, Transform3D(basis, p + Vector3(0, size.y * 0.5 + 0.02, 0)), Vector3(size.x * 0.7, 0.03, size.z * 0.7), SNOW)
	return {"height": height, "star": star}


# --- Kinderkarussell --------------------------------------------------------------------

## Fester Teil: runder Sockel mit Stufe und Kassenhäuschen. Rückgabe: Radius.
static func carousel_base(st: SurfaceTool) -> float:
	var radius := 2.6
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0, 0), radius + 0.35, radius + 0.35, 0.18, 20, WOOD_DARK)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.18, 0), radius + 0.2, radius + 0.2, 0.02, 20, SNOW_SHADE)
	# Kassenhäuschen
	var booth := Vector3(radius + 1.1, 0, 0)
	LowPolyBuilder.add_box(st, booth + Vector3(0, 0.55, 0), Vector3(0.8, 1.1, 0.8), CLOTH_RED)
	LowPolyBuilder.add_box(st, booth + Vector3(0, 1.3, 0), Vector3(0.8, 0.4, 0.8), CLOTH_CREAM)
	LowPolyBuilder.add_cone(st, booth + Vector3(0, 1.5, 0), 0.6, 0.55, 8, CLOTH_RED)
	LowPolyBuilder.add_cone(st, booth + Vector3(0, 1.62, 0), 0.4, 0.42, 8, SNOW, 0.2, false)
	LowPolyBuilder.add_box(st, booth + Vector3(-0.41, 1.25, 0), Vector3(0.02, 0.3, 0.5), Color(0.15, 0.13, 0.12))
	return radius


## Drehender Teil ohne Pferde: Plattform, Mittelsäule, gestreiftes Zeltdach mit
## Bogenkante, Birnen am Rand (glow). Die Pferde hängt carousel.gd einzeln an.
static func carousel_top(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator, radius: float) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.2, 0), radius, radius, 0.14, 24, WOOD_LIGHT)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.2, 0), radius + 0.03, radius + 0.03, 0.06, 24, GOLD)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.34, 0), 0.4, 0.35, 2.4, 12, CLOTH_CREAM)
	for k in 6:
		var a := TAU * k / 6.0
		LowPolyBuilder.add_box(st, Vector3(cos(a) * 0.41, 1.5, sin(a) * 0.41), Vector3(0.04, 2.2, 0.08), GOLD)
	# Dach: 16 Bahnen rot/creme, darüber eine kleine Spitze mit Fahne
	var roof_y := 2.85
	var segments := 16
	var peak := Vector3(0, roof_y + 1.2, 0)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0) * (radius + 0.3), roof_y, sin(a0) * (radius + 0.3))
		var p1 := Vector3(cos(a1) * (radius + 0.3), roof_y, sin(a1) * (radius + 0.3))
		var color := CLOTH_RED if i % 2 == 0 else CLOTH_CREAM
		LowPolyBuilder.add_triangle_facing(st, peak, p0, p1, color, (p0 + p1) * 0.5 + Vector3(0, 0.8, 0))
		LowPolyBuilder.add_triangle_facing(st, peak - Vector3(0, 0.05, 0), p0 - Vector3(0, 0.05, 0), p1 - Vector3(0, 0.05, 0),
			color.darkened(0.25), Vector3.DOWN)
		# Bogenkante (Lambrequin) unter dem Dachrand
		var mid := (p0 + p1) * 0.5
		LowPolyBuilder.add_triangle_facing(st, p0, p1, mid + Vector3(0, -0.28, 0) + mid.normalized() * 0.02, color,
			Vector3(mid.x, 0, mid.z))
		# Schnee auf jeder zweiten Bahn
		if i % 2 == 1:
			LowPolyBuilder.add_triangle_facing(st, peak + Vector3(0, 0.03, 0), p0.lerp(peak, 0.35) + Vector3(0, 0.05, 0),
				p1.lerp(peak, 0.35) + Vector3(0, 0.05, 0), SNOW, Vector3.UP)
	LowPolyBuilder.add_cylinder(st, peak, 0.08, 0.02, 0.5, 6, GOLD)
	LowPolyBuilder.add_box(st, peak + Vector3(0.18, 0.4, 0), Vector3(0.3, 0.16, 0.02), CLOTH_RED)
	# Deckenfries mit Birnen
	LowPolyBuilder.add_cylinder(st, Vector3(0, roof_y - 0.34, 0), radius + 0.22, radius + 0.22, 0.34, 24, GOLD.darkened(0.15))
	for k in 32:
		var a := TAU * k / 32.0
		_bulb(glow, Vector3(cos(a) * (radius + 0.25), roof_y - 0.17, sin(a) * (radius + 0.25)), 0.06,
			WARM_BULB if k % 2 == 0 else AMBER_BULB, rng.randf())


## Ein Karussellpferd (weiß mit Sattel) an seiner Stange. Ursprung = Stange auf Plattformhöhe.
static func carousel_horse(rng: RandomNumberGenerator, color: Color) -> ArrayMesh:
	var st := TrainMeshes._new_st()
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0, 0), 0.03, 0.03, 2.5, 6, GOLD)
	var body := Vector3(0, 0.95, 0)
	LowPolyBuilder.add_box(st, body, Vector3(0.24, 0.3, 0.72), color)
	LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, 0.6), body + Vector3(0, 0.25, -0.38)), Vector3(0.18, 0.4, 0.2), color)
	LowPolyBuilder.add_box(st, body + Vector3(0, 0.42, -0.55), Vector3(0.16, 0.16, 0.3), color)
	LowPolyBuilder.add_box(st, body + Vector3(0, 0.44, -0.42), Vector3(0.05, 0.28, 0.16), GOLD)
	for x: float in [-0.08, 0.08]:
		LowPolyBuilder.add_box(st, body + Vector3(x, 0.53, -0.48), Vector3(0.04, 0.08, 0.04), color)
	# Beine im Galopp
	for z: float in [-0.25, 0.25]:
		for x: float in [-0.08, 0.08]:
			var swing := 0.45 if z < 0.0 else -0.45
			LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, swing), body + Vector3(x, -0.3, z + swing * 0.25)),
				Vector3(0.06, 0.4, 0.06), color)
	LowPolyBuilder.add_box(st, body + Vector3(0, 0.17, 0.02), Vector3(0.28, 0.06, 0.3), CLOTH_RED)
	LowPolyBuilder.add_box(st, body + Vector3(0, 0.1, 0.02), Vector3(0.3, 0.12, 0.12), GOLD)
	LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, -0.7), body + Vector3(0, 0.02, 0.43)), Vector3(0.05, 0.3, 0.05),
		[GOLD, CLOTH_CREAM][rng.randi() % 2])
	return st.commit()


# --- Eingangsbogen, Stehtische, Herbstfest --------------------------------------------

## Holzbogen über dem Eingang mit Tannengirlande, Lichtern und Schild. Rückgabe: Schild-Transform.
static func arch(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator, width: float, winter: bool) -> Transform3D:
	var h := 3.3
	var hw := width * 0.5
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(side * hw, h * 0.5, 0), Vector3(0.22, h, 0.22), WOOD_DARK)
		LowPolyBuilder.add_box(st, Vector3(side * hw, 0.2, 0), Vector3(0.4, 0.4, 0.4), Color(0.5, 0.47, 0.44))
		LowPolyBuilder.add_box(st, Vector3(side * hw, h + 0.02, 0), Vector3(0.28, 0.06, 0.28), SNOW)
	var segments := 12
	var prev := Vector3.ZERO
	for i in segments + 1:
		var t := float(i) / segments
		var x := lerpf(-hw, hw, t)
		var y := h + sin(t * PI) * 0.55
		var p := Vector3(x, y, 0)
		if i > 0:
			LowPolyBuilder.add_beam(st, prev, p, 0.2, WOOD)
			# Girlande aus Tannengrün (im Herbst: Laub und Ähren)
			var green: Color = (NEEDLES_LIGHT if i % 2 == 0 else NEEDLES) if winter else \
				[Color(0.8, 0.45, 0.12), Color(0.7, 0.28, 0.1), Color(0.86, 0.7, 0.3)][i % 3]
			LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.BACK, atan2(p.y - prev.y, p.x - prev.x)),
				(prev + p) * 0.5 + Vector3(0, 0.06, 0)), Vector3(prev.distance_to(p) + 0.1, 0.24, 0.32), green)
			if winter:
				LowPolyBuilder.add_box(st, (prev + p) * 0.5 + Vector3(0, 0.2, 0), Vector3(prev.distance_to(p) * 0.8, 0.06, 0.2), SNOW)
		prev = p
	_bulb_chain(glow, Vector3(-hw, h - 0.15, -0.2), Vector3(hw, h - 0.15, -0.2), 20, -0.45, [WARM_BULB, AMBER_BULB], rng)
	_bulb_chain(glow, Vector3(-hw, h - 0.15, 0.2), Vector3(hw, h - 0.15, 0.2), 20, -0.45, [WARM_BULB, AMBER_BULB], rng)
	# Hängendes Schild
	var sign := Vector3(0, h - 0.35, 0)
	for x: float in [-0.9, 0.9]:
		LowPolyBuilder.add_box(st, Vector3(x, h + 0.02, 0), Vector3(0.02, 0.5, 0.02), IRON)
	LowPolyBuilder.add_box(st, sign, Vector3(2.4, 0.5, 0.06), CLOTH_RED if winter else Color(0.55, 0.3, 0.14))
	LowPolyBuilder.add_box(st, sign, Vector3(2.5, 0.58, 0.04), GOLD.darkened(0.2))
	if winter:
		LowPolyBuilder.add_box(st, sign + Vector3(0, 0.28, 0), Vector3(2.3, 0.05, 0.1), SNOW)
		_star(st, sign + Vector3(-1.05, 0, -0.05), 0.12, 0.03, GOLD, Basis.IDENTITY)
		_star(st, sign + Vector3(1.05, 0, -0.05), 0.12, 0.03, GOLD, Basis.IDENTITY)
	return Transform3D(Basis.IDENTITY, sign)


## Stehtisch aus einem Fass mit runder Platte und Windlicht. Rückgabe: Punkt des Windlichts.
static func standing_table(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator, winter: bool) -> void:
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.3, 0.3, 1.0, 12, WOOD)
	for y: float in [0.15, 0.8]:
		LowPolyBuilder.add_cylinder(st, Vector3(0, y, 0), 0.32, 0.32, 0.05, 12, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.0, 0), 0.5, 0.5, 0.05, 14, WOOD_LIGHT)
	if winter:
		LowPolyBuilder.add_cylinder(st, Vector3(0.2, 1.05, 0.1), 0.2, 0.18, 0.02, 10, SNOW)
	# Windlicht mit Kerze und Tannenzweig
	LowPolyBuilder.add_cylinder(st, Vector3(-0.05, 1.05, -0.05), 0.08, 0.08, 0.02, 8, IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(-0.05, 1.07, -0.05), 0.03, 0.03, 0.08, 6, CLOTH_CREAM)
	_flame(glow, Vector3(-0.05, 1.15, -0.05), rng)
	for k in 3:
		var a := TAU * k / 3.0
		LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.UP, a), Vector3(-0.05, 1.07, -0.05) + Vector3(cos(a), 0, sin(a)) * 0.13),
			Vector3(0.18, 0.04, 0.07), NEEDLES_LIGHT if winter else Color(0.72, 0.36, 0.12))


static func hay_bale(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var straw := Color(0.86, 0.72, 0.4)
	LowPolyBuilder.add_box(st, Vector3(0, 0.23, 0), Vector3(1.1, 0.46, 0.55), _vary(straw, rng, 0.04))
	for x: float in [-0.3, 0.3]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.23, 0), Vector3(0.03, 0.47, 0.56), Color(0.5, 0.36, 0.2))
	for i in 5:
		LowPolyBuilder.add_box(st, Vector3(rng.randf_range(-0.5, 0.5), 0.465, rng.randf_range(-0.25, 0.25)), Vector3(0.14, 0.02, 0.03),
			straw.lightened(0.1))


static func pumpkin(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, radius: float) -> void:
	var colors := [Color(0.93, 0.5, 0.12), Color(0.9, 0.62, 0.16), Color(0.86, 0.42, 0.1), Color(0.48, 0.58, 0.28)]
	var color: Color = colors[rng.randi() % colors.size()]
	LowPolyBuilder.add_rock(st, rng, base + Vector3(0, radius * 0.72, 0), radius, color, color.lightened(0.05), 4, 10)
	LowPolyBuilder.add_cylinder(st, base + Vector3(0, radius * 1.4, 0), 0.025, 0.018, radius * 0.4, 5, Color(0.36, 0.3, 0.14))


## Kleine Holzbühne mit Rückwand und Wimpeln. Rückgabe: Punkt, an dem der Musikant steht.
static func stage(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> Vector3:
	var w := 3.6
	var d := 2.4
	LowPolyBuilder.add_box(st, Vector3(0, 0.25, 0), Vector3(w, 0.5, d), WOOD_DARK)
	for i in 12:
		LowPolyBuilder.add_box(st, Vector3(-w * 0.5 + (i + 0.5) * w / 12.0, 0.51, 0), Vector3(w / 12.0 - 0.02, 0.03, d), _vary(WOOD_LIGHT, rng, 0.04))
	for i in 2:
		LowPolyBuilder.add_box(st, Vector3(0, 0.08 + i * 0.17, -d * 0.5 - 0.2 - i * 0.02), Vector3(1.0, 0.16, 0.4 - i * 0.2), WOOD)
	LowPolyBuilder.add_box(st, Vector3(0, 1.8, d * 0.5 - 0.05), Vector3(w, 2.6, 0.1), Color(0.45, 0.2, 0.14))
	for x: float in [-w * 0.5, w * 0.5]:
		LowPolyBuilder.add_box(st, Vector3(x, 1.8, d * 0.5 - 0.05), Vector3(0.14, 2.7, 0.14), WOOD_DARK)
	bunting(st, Vector3(-w * 0.5, 3.1, d * 0.5 - 0.12), Vector3(w * 0.5, 3.1, d * 0.5 - 0.12), 0.35, rng)
	bunting(st, Vector3(-w * 0.5, 3.1, d * 0.5 - 0.1), Vector3(-w * 0.5 - 0.2, 2.6, -d * 0.5), 0.2, rng)
	bunting(st, Vector3(w * 0.5, 3.1, d * 0.5 - 0.1), Vector3(w * 0.5 + 0.2, 2.6, -d * 0.5), 0.2, rng)
	_bulb_chain(glow, Vector3(-w * 0.5, 2.9, d * 0.5 - 0.16), Vector3(w * 0.5, 2.9, d * 0.5 - 0.16), 14, 0.25, [AMBER_BULB, WARM_BULB], rng)
	# Stuhl und Notenständer
	LowPolyBuilder.add_box(st, Vector3(0.3, 0.75, 0.3), Vector3(0.42, 0.06, 0.42), WOOD)
	for x: float in [0.12, 0.48]:
		for z: float in [0.12, 0.48]:
			LowPolyBuilder.add_box(st, Vector3(x, 0.63, z), Vector3(0.05, 0.25, 0.05), WOOD_DARK)
	LowPolyBuilder.add_cylinder(st, Vector3(-0.5, 0.52, -0.3), 0.015, 0.015, 1.0, 5, IRON)
	LowPolyBuilder.add_oriented_box(st, Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(-0.5, 1.55, -0.28)), Vector3(0.4, 0.3, 0.02), IRON)
	return Vector3(0.0, 0.52, 0.0)


## Wimpelkette (bunte Dreiecksfähnchen) zwischen [param a] und [param b], mit Durchhang.
static func bunting(st: SurfaceTool, a: Vector3, b: Vector3, sag: float, rng: RandomNumberGenerator) -> void:
	var colors := [CLOTH_RED, Color(0.95, 0.72, 0.2), Color(0.3, 0.52, 0.38), CLOTH_CREAM, Color(0.28, 0.42, 0.66), Color(0.86, 0.46, 0.14)]
	var count := maxi(3, int(a.distance_to(b) / 0.32))
	var side := (b - a).cross(Vector3.UP).normalized()
	var prev := a
	for i in count + 1:
		var t := float(i) / count
		var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0)
		if i > 0:
			LowPolyBuilder.add_beam(st, prev, p, 0.012, WOOD_DARK)
			var mid := (prev + p) * 0.5
			var color: Color = colors[(i + rng.randi() % 2) % colors.size()]
			for face: float in [1.0, -1.0]:
				LowPolyBuilder.add_triangle_facing(st, prev.lerp(p, 0.1), prev.lerp(p, 0.9), mid - Vector3(0, 0.26, 0), color,
					side * face)
		prev = p


## Papierlaternen an einer Schnur (Herbstabend): nur leuchtende Teile.
static func paper_lanterns(glow: SurfaceTool, st: SurfaceTool, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var count := maxi(2, int(a.distance_to(b) / 0.9))
	var colors := [Color(1.0, 0.55, 0.2), Color(1.0, 0.8, 0.35), Color(0.95, 0.35, 0.2)]
	var prev := a
	for i in count + 1:
		var t := float(i) / count
		var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.35, 0)
		if i > 0:
			LowPolyBuilder.add_beam(st, prev, p, 0.012, WOOD_DARK)
		if i > 0 and i < count:
			LowPolyBuilder.add_box(st, p - Vector3(0, 0.06, 0), Vector3(0.01, 0.12, 0.01), WOOD_DARK)
			var lantern := p - Vector3(0, 0.3, 0)
			var color: Color = colors[rng.randi() % colors.size()]
			color.a = rng.randf()
			LowPolyBuilder.add_cylinder(glow, lantern - Vector3(0, 0.14, 0), 0.12, 0.16, 0.14, 8, color)
			LowPolyBuilder.add_cylinder(glow, lantern, 0.16, 0.12, 0.14, 8, color)
			LowPolyBuilder.add_cylinder(st, lantern + Vector3(0, 0.14, 0), 0.08, 0.08, 0.03, 8, IRON)
		prev = p


## Lagerfeuer im Steinkreis mit Holzstapel; die Glut leuchtet (glow). Rückgabe: Flammenpunkt.
static func bonfire(st: SurfaceTool, glow: SurfaceTool, rng: RandomNumberGenerator) -> Vector3:
	for k in 12:
		var a := TAU * k / 12.0
		LowPolyBuilder.add_rock(st, rng, Vector3(cos(a) * 1.05, 0.12, sin(a) * 1.05), 0.2, Color(0.46, 0.44, 0.44),
			SNOW, 3, 6)
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf() * 0.2
		var foot := Vector3(cos(a) * 0.7, 0.05, sin(a) * 0.7)
		LowPolyBuilder.add_cylinder_between(st, foot, Vector3(cos(a) * 0.1, 1.2, sin(a) * 0.1), 0.07, 6, Color(0.38, 0.26, 0.17))
	for k in 10:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.5
		_bulb(glow, Vector3(cos(a) * r, 0.1, sin(a) * r), 0.1, Color(1.0, 0.35 + rng.randf() * 0.2, 0.08), rng.randf())
	# Sitzbalken im Kreis
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var c := Vector3(cos(a) * 2.4, 0.2, sin(a) * 2.4)
		var along := Vector3(-sin(a), 0, cos(a))
		LowPolyBuilder.add_cylinder_between(st, c - along * 0.8, c + along * 0.8, 0.2, 8, Color(0.42, 0.3, 0.2))
	return Vector3(0, 0.5, 0)


# --- Bausteine ---------------------------------------------------------------------

const METAL_LIGHT := Color(0.62, 0.62, 0.64)


## Leuchtende Birne (kleine Kugel aus 8 Dreiecken). [param seed] = Zufall fürs Funkeln.
static func _bulb(glow: SurfaceTool, center: Vector3, radius: float, color: Color, seed: float) -> void:
	var c := Color(color.r, color.g, color.b, seed)
	var top := center + Vector3(0, radius, 0)
	var bottom := center - Vector3(0, radius * 1.2, 0)
	var ring: Array[Vector3] = []
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		ring.append(center + Vector3(cos(a), 0, sin(a)) * radius)
	for k in 4:
		var p0 := ring[k]
		var p1 := ring[(k + 1) % 4]
		var out := (p0 + p1) * 0.5 - center
		LowPolyBuilder.add_triangle_facing(glow, top, p0, p1, c, out + Vector3.UP * 0.3)
		LowPolyBuilder.add_triangle_facing(glow, bottom, p0, p1, c, out - Vector3.UP * 0.3)


## Birnenkette mit Durchhang [param sag] (negativ = Bogen nach oben).
static func _bulb_chain(glow: SurfaceTool, a: Vector3, b: Vector3, count: int, sag: float, colors: Array,
		rng: RandomNumberGenerator) -> void:
	for i in count:
		var t := (i + 0.5) / count
		var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0)
		_bulb(glow, p, 0.045, colors[i % colors.size()], rng.randf())


## Kerzenflamme (Tropfen) im glow.
static func _flame(glow: SurfaceTool, base: Vector3, rng: RandomNumberGenerator) -> void:
	_bulb(glow, base + Vector3(0, 0.04, 0), 0.025, FLAME, rng.randf())
	LowPolyBuilder.add_cone(glow, base + Vector3(0, 0.05, 0), 0.02, 0.07, 4, Color(FLAME, rng.randf()), 0.0, false)


## Fünfzackiger Stern, flach in der XY-Ebene (mit Dicke).
static func _star(st: SurfaceTool, center: Vector3, radius: float, thickness: float, color: Color, basis: Basis) -> void:
	var points: Array[Vector3] = []
	for k in 10:
		var a := PI * 0.5 + TAU * k / 10.0
		var r := radius if k % 2 == 0 else radius * 0.45
		points.append(center + basis * Vector3(cos(a) * r, sin(a) * r, 0))
	var front := center + basis * Vector3(0, 0, -thickness)
	var back := center + basis * Vector3(0, 0, thickness)
	var normal := basis * Vector3.BACK
	for k in 10:
		var p0 := points[k]
		var p1 := points[(k + 1) % 10]
		LowPolyBuilder.add_triangle_facing(st, front, p0, p1, color, -normal + (p0 + p1 - center * 2.0) * 0.5)
		LowPolyBuilder.add_triangle_facing(st, back, p0, p1, color, normal + (p0 + p1 - center * 2.0) * 0.5)


## Lebkuchenherz: flaches Herz mit weißem Zuckerrand und einem kleinen Muster.
static func _heart(st: SurfaceTool, center: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var outline: Array[Vector2] = []
	for k in 16:
		var t := TAU * k / 16.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		outline.append(Vector2(x, y) / 34.0)
	var brown := Color(0.58, 0.32, 0.16).lerp(Color(0.7, 0.42, 0.22), rng.randf())
	for layer in 2:
		var scale := size * (1.0 if layer == 0 else 0.84)
		var z := -0.012 - layer * 0.012
		var color := brown if layer == 1 else CLOTH_CREAM
		for k in 16:
			var a := outline[k] * scale
			var b := outline[(k + 1) % 16] * scale
			for face: float in [1.0, -1.0]:
				LowPolyBuilder.add_triangle_facing(st, center + Vector3(0, 0, z * face), center + Vector3(a.x, a.y, z * face),
					center + Vector3(b.x, b.y, z * face), color, Vector3(0, 0, face))
	var accent: Color = [CLOTH_RED, ROOF_GREEN, Color(0.95, 0.72, 0.2)][rng.randi() % 3]
	LowPolyBuilder.add_box(st, center + Vector3(0, 0.0, -0.028), Vector3(size * 0.35, size * 0.12, 0.01), accent)
	LowPolyBuilder.add_box(st, center + Vector3(0, 0.0, 0.028), Vector3(size * 0.35, size * 0.12, 0.01), accent)


static func _crate(st: SurfaceTool, center: Vector3, rng: RandomNumberGenerator) -> void:
	for y: float in [0.05, 0.15]:
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_box(st, center + Vector3(0, y, side * 0.17), Vector3(0.42, 0.07, 0.02), _vary(WOOD_LIGHT, rng))
			LowPolyBuilder.add_box(st, center + Vector3(side * 0.2, y, 0), Vector3(0.02, 0.07, 0.34), _vary(WOOD_LIGHT, rng))
	LowPolyBuilder.add_box(st, center + Vector3(0, 0.01, 0), Vector3(0.4, 0.02, 0.32), WOOD)


static func _vary(color: Color, rng: RandomNumberGenerator, amount := 0.025) -> Color:
	var v := rng.randf_range(-amount, amount)
	return Color(color.r + v, color.g + v, color.b + v, color.a)
