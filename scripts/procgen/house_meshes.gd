@tool
## Acht gemütliche Low-Poly-Wohnhäuser – jedes mit eigener Form.
##
## Lokal: Ursprung = Boden in der Mitte der Grundfläche, die Haustür zeigt
## nach -Z. Alle Häuser bestehen aus denselben Bausteinen (Wände, Sockel,
## Dachplatten mit Schneeschicht und Eiszapfen, Sprossenfenster mit Läden,
## Tür mit Kranz und Vordach, Schornstein, Fachwerk), aber jede Form ist anders:
##
##   cottage    Häuschen: eingeschossig, steiles Satteldach, Vordach
##   chalet     Chalet: Giebel zur Straße, weiter Dachüberstand, Holzbalkon
##   townhouse  Stadthaus: schmal und hoch, drei Geschosse, Gaube
##   farmhouse  Bauernhaus: L-Form mit Fachwerk, zwei Dächer
##   tower      Turmhaus: Haus mit rundem Eckturm und Spitzdach
##   aframe     A-Frame-Hütte: Dach bis zum Boden, große Giebelverglasung
##   barn       Scheunenhaus: Mansarddach, Scheunentor-Fenster
##   villa      Gaubenhaus: Walmdach mit zwei Gauben und Erker
##
## [method build] liefert {"body", "glass", "chimneys", "lights", "door", "size", "center", "height"}
## ("size"/"center" = Grundfläche der Mauern plus Rand, lokal).
## "glass" wird mit dem Fenster-Shader gezeichnet (nachts warm beleuchtet).
class_name HouseMeshes
extends RefCounted

const TYPES: Array[String] = ["cottage", "chalet", "townhouse", "farmhouse", "tower", "aframe", "barn", "villa"]
const NAMES := {
	"cottage": "Häuschen", "chalet": "Chalet", "townhouse": "Stadthaus", "farmhouse": "Bauernhaus",
	"tower": "Turmhaus", "aframe": "A-Frame-Hütte", "barn": "Scheunenhaus", "villa": "Gaubenhaus",
}
## Bewohner je Haus (Grundlage für die Dorfbevölkerung).
const CAPACITY := {
	"cottage": 1, "chalet": 2, "townhouse": 2, "farmhouse": 3, "tower": 2, "aframe": 1, "barn": 2, "villa": 3,
}

const SNOW := Color(0.92, 0.94, 0.98, 0.5)
const SNOW_SHADE := Color(0.82, 0.86, 0.93, 0.5)
const TIMBER := Color(0.36, 0.24, 0.16)
const TRIM := Color(0.93, 0.89, 0.8)
const STONE := Color(0.55, 0.52, 0.5)
const STONE_DARK := Color(0.44, 0.42, 0.41)
const BRICK := Color(0.62, 0.36, 0.28)
const DOOR_WOOD := Color(0.46, 0.28, 0.18)
const BRASS := Color(0.85, 0.66, 0.3)
const GREEN := Color(0.17, 0.35, 0.26)
const BERRY := Color(0.78, 0.13, 0.12)
const ICE := Color(0.82, 0.9, 0.98, 0.5)

## Farbpaletten: Wand, Dach, Fensterläden, Tür.
const PALETTES := [
	[Color(0.93, 0.86, 0.72), Color(0.62, 0.27, 0.21), Color(0.25, 0.42, 0.36), Color(0.62, 0.22, 0.18)],
	[Color(0.74, 0.35, 0.28), Color(0.31, 0.33, 0.39), Color(0.93, 0.88, 0.76), Color(0.25, 0.36, 0.44)],
	[Color(0.62, 0.7, 0.6), Color(0.43, 0.3, 0.22), Color(0.9, 0.84, 0.7), Color(0.72, 0.3, 0.22)],
	[Color(0.87, 0.68, 0.4), Color(0.29, 0.36, 0.38), Color(0.36, 0.25, 0.18), Color(0.3, 0.44, 0.38)],
	[Color(0.64, 0.73, 0.8), Color(0.55, 0.26, 0.22), Color(0.95, 0.92, 0.84), Color(0.8, 0.62, 0.3)],
	[Color(0.94, 0.91, 0.85), Color(0.36, 0.3, 0.3), Color(0.55, 0.22, 0.2), Color(0.28, 0.4, 0.34)],
]

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


## Baut das Haus [param type] in der Farbvariante [param variant].
static func build(type: String, variant := 0) -> Dictionary:
	var key := "%s|%d" % [type, variant]
	if _cache.has(key):
		return _cache[key]
	var b := _Builder.new(variant)
	match type:
		"cottage":
			_cottage(b)
		"chalet":
			_chalet(b)
		"townhouse":
			_townhouse(b)
		"farmhouse":
			_farmhouse(b)
		"tower":
			_tower(b)
		"aframe":
			_aframe(b)
		"barn":
			_barn(b)
		_:
			_villa(b)
	var result := b.finish()
	_cache[key] = result
	return result


# --- Die acht Häuser ---------------------------------------------------------------

static func _cottage(b: _Builder) -> void:
	b.footprint(-2.4, 2.4, -2.0, 2.0)
	b.plinth(-2.4, 2.4, -2.0, 2.0)
	b.walls(-2.4, 2.4, -2.0, 2.0, 0.3, 2.6, b.wall)
	b.corner_trims(-2.4, 2.4, -2.0, 2.0, 0.3, 2.6)
	b.gable_roof_x(-2.4, 2.4, -2.0, 2.0, 2.6, 4.7, 0.55, 0.45)
	b.door(Vector3(0.0, 0.3, -2.0), true)
	b.window(Vector3(-1.45, 1.55, -2.0), Vector3.FORWARD, 0.8, 0.95, true, true)
	b.window(Vector3(1.45, 1.55, -2.0), Vector3.FORWARD, 0.8, 0.95, true, true)
	b.window(Vector3(2.4, 1.55, 0.0), Vector3.RIGHT, 0.8, 0.95, true, false)
	b.window(Vector3(-2.4, 1.55, 0.3), Vector3.LEFT, 0.8, 0.95, true, false)
	b.window(Vector3(-2.4, 3.3, 0.0), Vector3.LEFT, 0.55, 0.65, false, false)  # Giebelfenster
	b.window(Vector3(2.4, 3.3, 0.0), Vector3.RIGHT, 0.55, 0.65, false, false)
	b.window(Vector3(0.0, 1.55, 2.0), Vector3.BACK, 0.8, 0.95, true, false)
	b.chimney(Vector3(1.3, 0.0, 0.8), 5.3)
	b.height = 5.3


static func _chalet(b: _Builder) -> void:
	b.footprint(-2.8, 2.8, -2.6, 2.6)
	b.plinth(-2.8, 2.8, -2.6, 2.6)
	b.walls(-2.8, 2.8, -2.6, 2.6, 0.35, 2.4, b.wall)
	# Obergeschoss aus Holz mit waagrechter Schalung
	b.walls(-2.8, 2.8, -2.6, 2.6, 2.4, 4.2, TIMBER.lightened(0.18))
	b.siding(-2.8, 2.8, -2.6, 2.6, 2.4, 4.2)
	b.belt(-2.8, 2.8, -2.6, 2.6, 2.4)
	b.gable_roof_z(-2.8, 2.8, -2.6, 2.6, 4.2, 5.9, 1.0, 0.9, true)
	b.door(Vector3(-1.3, 0.35, -2.6), false)
	b.window(Vector3(0.9, 1.45, -2.6), Vector3.FORWARD, 1.3, 1.0, true, true)
	b.window(Vector3(-1.2, 3.25, -2.6), Vector3.FORWARD, 0.75, 0.9, true, true)
	b.window(Vector3(1.2, 3.25, -2.6), Vector3.FORWARD, 0.75, 0.9, true, true)
	b.window(Vector3(0.0, 4.75, -2.6), Vector3.FORWARD, 0.6, 0.6, false, false)
	for z: float in [-1.1, 1.1]:
		b.window(Vector3(2.8, 1.45, z), Vector3.RIGHT, 0.8, 0.95, true, false)
		b.window(Vector3(-2.8, 3.25, z), Vector3.LEFT, 0.7, 0.85, true, false)
	b.balcony(-2.2, 2.2, -2.6, 2.45)
	b.chimney(Vector3(-1.6, 0.0, 1.2), 6.6)
	b.height = 6.6


static func _townhouse(b: _Builder) -> void:
	b.footprint(-1.9, 1.9, -2.3, 2.3)
	b.plinth(-1.9, 1.9, -2.3, 2.3)
	b.walls(-1.9, 1.9, -2.3, 2.3, 0.4, 6.9, b.wall)
	b.corner_trims(-1.9, 1.9, -2.3, 2.3, 0.4, 6.9)
	b.belt(-1.9, 1.9, -2.3, 2.3, 2.7)
	b.belt(-1.9, 1.9, -2.3, 2.3, 4.9)
	b.gable_roof_x(-1.9, 1.9, -2.3, 2.3, 6.9, 9.4, 0.45, 0.35)
	b.door(Vector3(-0.7, 0.4, -2.3), true)
	b.window(Vector3(0.8, 1.6, -2.3), Vector3.FORWARD, 0.8, 1.1, true, true)
	for y: float in [3.7, 5.9]:
		b.window(Vector3(-0.8, y, -2.3), Vector3.FORWARD, 0.75, 1.05, true, true)
		b.window(Vector3(0.8, y, -2.3), Vector3.FORWARD, 0.75, 1.05, true, true)
		b.window(Vector3(1.9, y, 0.0), Vector3.RIGHT, 0.7, 1.0, true, false)
		b.window(Vector3(-1.9, y, 0.0), Vector3.LEFT, 0.7, 1.0, true, false)
	b.dormer(Vector3(0.0, 0.0, -2.3), 6.9, 9.4, 2.3, 1.1)
	b.chimney(Vector3(-1.0, 0.0, 1.3), 10.1)
	b.height = 10.1


static func _farmhouse(b: _Builder) -> void:
	b.footprint(-3.8, 3.8, -2.2, 3.8)
	# Haupthaus quer, Flügel nach hinten links
	b.plinth(-3.8, 3.8, -2.2, 2.2)
	b.plinth(-3.8, -0.4, 2.2, 3.8)
	b.walls(-3.8, 3.8, -2.2, 2.2, 0.3, 2.9, b.wall)
	b.walls(-3.8, -0.4, 2.0, 3.8, 0.3, 2.9, b.wall)
	b.timber_frame(-3.8, 3.8, -2.2, 2.2, 0.3, 2.9)
	b.gable_roof_x(-3.8, 3.8, -2.2, 2.2, 2.9, 5.2, 0.6, 0.5)
	b.gable_roof_z(-3.8, -0.4, 0.0, 3.8, 2.9, 4.7, 0.5, 0.45, false)
	b.door(Vector3(0.4, 0.3, -2.2), true)
	for x: float in [-2.6, -1.2, 1.9, 3.0]:
		b.window(Vector3(x, 1.65, -2.2), Vector3.FORWARD, 0.72, 0.9, true, true)
	b.window(Vector3(3.8, 1.65, 0.0), Vector3.RIGHT, 0.72, 0.9, true, false)
	b.window(Vector3(3.8, 3.7, 0.0), Vector3.RIGHT, 0.6, 0.7, false, false)
	b.window(Vector3(-2.1, 1.65, 3.8), Vector3.BACK, 0.72, 0.9, true, false)
	b.window(Vector3(-3.8, 1.65, 2.9), Vector3.LEFT, 0.72, 0.9, true, false)
	b.bench_at_wall(Vector3(2.4, 0.3, -2.2))
	b.chimney(Vector3(1.8, 0.0, 0.9), 5.9)
	b.chimney(Vector3(-2.6, 0.0, 3.0), 5.2)
	b.height = 5.9


static func _tower(b: _Builder) -> void:
	b.footprint(-2.6, 3.7, -2.5, 2.4)
	b.plinth(-2.6, 2.4, -2.4, 2.4)
	b.walls(-2.6, 2.4, -2.4, 2.4, 0.35, 4.2, b.wall)
	b.corner_trims(-2.6, 2.4, -2.4, 2.4, 0.35, 4.2)
	b.belt(-2.6, 2.4, -2.4, 2.4, 2.3)
	b.gable_roof_x(-2.6, 2.4, -2.4, 2.4, 4.2, 6.4, 0.5, 0.4)
	# Runder Eckturm vorne rechts mit Spitzdach
	b.turret(Vector3(2.35, 0.0, -2.35), 1.35, 6.1, 9.2)
	b.door(Vector3(-0.9, 0.35, -2.4), true)
	b.window(Vector3(-2.0, 1.4, -2.4), Vector3.FORWARD, 0.7, 0.9, true, true)
	b.window(Vector3(0.5, 1.4, -2.4), Vector3.FORWARD, 0.7, 0.9, true, true)
	b.window(Vector3(-1.4, 3.25, -2.4), Vector3.FORWARD, 0.7, 0.85, true, true)
	b.window(Vector3(0.2, 3.25, -2.4), Vector3.FORWARD, 0.7, 0.85, true, true)
	b.window(Vector3(-2.6, 1.4, 0.8), Vector3.LEFT, 0.7, 0.9, true, false)
	b.window(Vector3(-2.6, 5.0, 0.0), Vector3.LEFT, 0.55, 0.6, false, false)
	b.window(Vector3(-0.4, 1.4, 2.4), Vector3.BACK, 0.7, 0.9, true, false)
	b.chimney(Vector3(-1.4, 0.0, 1.2), 7.0)
	b.height = 9.2


static func _aframe(b: _Builder) -> void:
	b.footprint(-2.55, 2.55, -2.9, 2.9)
	b.plinth(-2.3, 2.3, -2.9, 2.9)
	# Stirnwände (Dreiecke) vorne und hinten, das Dach reicht bis zum Boden
	b.a_frame(-2.3, 2.3, -2.9, 2.9, 0.35, 5.6)
	b.door(Vector3(0.0, 0.35, -2.9), false)
	b.window(Vector3(-1.0, 1.25, -2.9), Vector3.FORWARD, 0.55, 1.2, false, false)
	b.window(Vector3(1.0, 1.25, -2.9), Vector3.FORWARD, 0.55, 1.2, false, false)
	b.triangle_window(Vector3(0.0, 2.55, -2.9), 2.3, 2.2)
	b.window(Vector3(0.0, 2.0, 2.9), Vector3.BACK, 0.8, 0.9, false, false)
	b.deck(-2.6, 2.6, -4.3, -2.9)
	b.chimney(Vector3(0.9, 0.0, 1.4), 5.9)
	b.height = 5.9


static func _barn(b: _Builder) -> void:
	b.footprint(-3.0, 3.0, -3.4, 3.4)
	b.plinth(-3.0, 3.0, -3.4, 3.4)
	b.walls(-3.0, 3.0, -3.4, 3.4, 0.3, 2.8, b.wall)
	b.corner_trims(-3.0, 3.0, -3.4, 3.4, 0.3, 2.8)
	b.board_and_batten(-3.0, 3.0, -3.4, 3.4, 0.3, 2.8)
	b.gambrel_roof(-3.0, 3.0, -3.4, 3.4, 2.8, 4.6, 6.0, 0.55, 0.45)
	b.door(Vector3(-1.6, 0.3, -3.4), true)
	# Großes Scheunentor als Fenster mit Andreaskreuz, darüber Heuboden-Luke
	b.barn_window(Vector3(0.9, 1.5, -3.4), 2.0, 2.2)
	b.window(Vector3(0.0, 4.2, -3.4), Vector3.FORWARD, 0.9, 0.8, false, true)
	for z: float in [-1.6, 0.4, 2.2]:
		b.window(Vector3(3.0, 1.55, z), Vector3.RIGHT, 0.7, 0.9, true, false)
		b.window(Vector3(-3.0, 1.55, z), Vector3.LEFT, 0.7, 0.9, true, false)
	b.chimney(Vector3(1.6, 0.0, 1.8), 6.7)
	b.height = 6.7


static func _villa(b: _Builder) -> void:
	b.footprint(-3.4, 3.4, -2.8, 2.8)
	b.plinth(-3.4, 3.4, -2.8, 2.8)
	b.walls(-3.4, 3.4, -2.8, 2.8, 0.4, 4.6, b.wall)
	b.corner_trims(-3.4, 3.4, -2.8, 2.8, 0.4, 4.6)
	b.belt(-3.4, 3.4, -2.8, 2.8, 2.5)
	b.hip_roof(-3.4, 3.4, -2.8, 2.8, 4.6, 7.2, 0.6)
	b.bay_window(Vector3(-1.7, 0.4, -2.8), 2.0, 2.4)
	b.door(Vector3(1.0, 0.4, -2.8), true)
	b.window(Vector3(2.5, 1.55, -2.8), Vector3.FORWARD, 0.75, 1.0, true, true)
	for x: float in [-1.7, 1.7]:
		b.window(Vector3(x, 3.5, -2.8), Vector3.FORWARD, 0.8, 1.0, true, true)
		b.dormer(Vector3(x, 0.0, -2.8), 4.6, 7.2, 2.8, 0.95)
	for z: float in [-1.2, 1.2]:
		b.window(Vector3(3.4, 1.55, z), Vector3.RIGHT, 0.75, 1.0, true, false)
		b.window(Vector3(-3.4, 3.5, z), Vector3.LEFT, 0.75, 1.0, true, false)
		b.window(Vector3(-3.4, 1.55, z), Vector3.LEFT, 0.75, 1.0, true, false)
	b.chimney(Vector3(-2.2, 0.0, 1.0), 7.9)
	b.chimney(Vector3(2.2, 0.0, 1.0), 7.9)
	b.height = 7.9


# --- Baukasten -----------------------------------------------------------------------

## Sammelt Körper- und Glasgeometrie eines Hauses.
class _Builder:
	var st := SurfaceTool.new()
	var glass := SurfaceTool.new()
	var rng := RandomNumberGenerator.new()
	var wall: Color
	var roof: Color
	var shutter: Color
	var door_color: Color
	var chimneys: Array[Vector3] = []
	var lights: Array[Vector3] = []
	var door_point := Vector3(0.0, 0.0, -3.0)
	var size := Vector2(6.0, 6.0)
	var center := Vector2.ZERO
	var height := 5.0

	func _init(variant: int) -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		glass.begin(Mesh.PRIMITIVE_TRIANGLES)
		rng.seed = 7331 + variant * 97
		var palette: Array = PALETTES[posmod(variant, PALETTES.size())]
		wall = palette[0]
		roof = palette[1]
		shutter = palette[2]
		door_color = palette[3]

	func finish() -> Dictionary:
		return {"body": st.commit(), "glass": glass.commit(), "chimneys": chimneys, "lights": lights,
			"door": door_point, "size": size, "center": center, "height": height}

	## Grundfläche = Mauern plus 0,4 m Rand (Dachüberstände zählen nicht – darunter kann man gehen).
	func footprint(x0: float, x1: float, z0: float, z1: float) -> void:
		size = Vector2(x1 - x0 + 0.8, z1 - z0 + 0.8)
		center = Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)

	func vary(color: Color, amount := 0.03) -> Color:
		var v := rng.randf_range(-amount, amount)
		return Color(color.r + v, color.g + v, color.b + v, color.a)

	# Wände und Sockel -------------------------------------------------------

	func walls(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, color: Color) -> void:
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
			Vector3(x1 - x0, y1 - y0, z1 - z0), vary(color, 0.015))

	func plinth(x0: float, x1: float, z0: float, z1: float) -> void:
		# Sockel aus Natursteinen, reicht in den Boden (für leichte Hanglagen)
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5),
			Vector3(x1 - x0 + 0.16, 1.2, z1 - z0 + 0.16), STONE)
		var x := x0
		while x < x1 - 0.3:
			var w := rng.randf_range(0.45, 0.8)
			for z: float in [z0 - 0.09, z1 + 0.09]:
				LowPolyBuilder.add_box(st, Vector3(minf(x + w * 0.5, x1 - 0.2), 0.18, z), Vector3(w - 0.05, 0.2, 0.03),
					vary(STONE_DARK, 0.05))
			x += w

	func corner_trims(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
		for x: float in [x0, x1]:
			for z: float in [z0, z1]:
				LowPolyBuilder.add_box(st, Vector3(x, (y0 + y1) * 0.5, z), Vector3(0.2, y1 - y0, 0.2), TRIM)

	func belt(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y, z0 - 0.02), Vector3(x1 - x0 + 0.1, 0.14, 0.08), TRIM)
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y, z1 + 0.02), Vector3(x1 - x0 + 0.1, 0.14, 0.08), TRIM)
		LowPolyBuilder.add_box(st, Vector3(x0 - 0.02, y, (z0 + z1) * 0.5), Vector3(0.08, 0.14, z1 - z0 + 0.1), TRIM)
		LowPolyBuilder.add_box(st, Vector3(x1 + 0.02, y, (z0 + z1) * 0.5), Vector3(0.08, 0.14, z1 - z0 + 0.1), TRIM)

	## Waagrechte Holzschalung (Obergeschoss des Chalets).
	func siding(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
		var y := y0 + 0.22
		while y < y1 - 0.1:
			var color := vary(TIMBER.lightened(0.12), 0.02)
			LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y, z0 - 0.015), Vector3(x1 - x0, 0.035, 0.03), color)
			LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y, z1 + 0.015), Vector3(x1 - x0, 0.035, 0.03), color)
			LowPolyBuilder.add_box(st, Vector3(x0 - 0.015, y, (z0 + z1) * 0.5), Vector3(0.03, 0.035, z1 - z0), color)
			LowPolyBuilder.add_box(st, Vector3(x1 + 0.015, y, (z0 + z1) * 0.5), Vector3(0.03, 0.035, z1 - z0), color)
			y += 0.3

	## Senkrechte Bretter mit Deckleisten (Scheune).
	func board_and_batten(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
		var x := x0 + 0.35
		while x < x1 - 0.2:
			for z: float in [z0 - 0.015, z1 + 0.015]:
				LowPolyBuilder.add_box(st, Vector3(x, (y0 + y1) * 0.5, z), Vector3(0.05, y1 - y0, 0.03), wall.darkened(0.12))
			x += 0.45
		var z := z0 + 0.35
		while z < z1 - 0.2:
			for xs: float in [x0 - 0.015, x1 + 0.015]:
				LowPolyBuilder.add_box(st, Vector3(xs, (y0 + y1) * 0.5, z), Vector3(0.03, y1 - y0, 0.05), wall.darkened(0.12))
			z += 0.45

	## Fachwerk: Pfosten, Riegel und Streben aus dunklem Holz.
	func timber_frame(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
		var faces := [[Vector3(x0, 0, z0 - 0.03), Vector3(x1, 0, z0 - 0.03)], [Vector3(x1, 0, z1 + 0.03), Vector3(x0, 0, z1 + 0.03)],
			[Vector3(x0 - 0.03, 0, z1), Vector3(x0 - 0.03, 0, z0)], [Vector3(x1 + 0.03, 0, z0), Vector3(x1 + 0.03, 0, z1)]]
		for face: Array in faces:
			var a: Vector3 = face[0]
			var c: Vector3 = face[1]
			var length := a.distance_to(c)
			var bays := maxi(1, roundi(length / 1.6))
			for i in bays + 1:
				var p := a.lerp(c, float(i) / bays)
				LowPolyBuilder.add_beam(st, p + Vector3.UP * y0, p + Vector3.UP * y1, 0.12, TIMBER)
			for y: float in [y0 + 0.05, (y0 + y1) * 0.5 + 0.2, y1 - 0.06]:
				LowPolyBuilder.add_beam(st, a + Vector3.UP * y, c + Vector3.UP * y, 0.11, TIMBER)
			for i in bays:
				if i % 2 == 0:
					var p0 := a.lerp(c, float(i) / bays)
					var p1 := a.lerp(c, float(i + 1) / bays)
					LowPolyBuilder.add_beam(st, p0 + Vector3.UP * ((y0 + y1) * 0.5 + 0.2), p1 + Vector3.UP * (y1 - 0.06), 0.09, TIMBER)

	# Dächer ------------------------------------------------------------------

	## Satteldach mit First entlang X (Traufen vorne/hinten, Giebel links/rechts).
	func gable_roof_x(x0: float, x1: float, z0: float, z1: float, eave: float, ridge: float, overhang: float,
			gable_overhang: float) -> void:
		var zc := (z0 + z1) * 0.5
		var slope := (ridge - eave) / (zc - z0)
		var low := eave - overhang * slope
		var gx0 := x0 - gable_overhang
		var gx1 := x1 + gable_overhang
		roof_slab([Vector3(gx0, low, z0 - overhang), Vector3(gx1, low, z0 - overhang), Vector3(gx1, ridge, zc), Vector3(gx0, ridge, zc)])
		roof_slab([Vector3(gx1, low, z1 + overhang), Vector3(gx0, low, z1 + overhang), Vector3(gx0, ridge, zc), Vector3(gx1, ridge, zc)])
		ridge_cap(Vector3(gx0, ridge, zc), Vector3(gx1, ridge, zc))
		for x: float in [x0, x1]:
			gable_fill(Vector3(x, eave, z0), Vector3(x, eave, z1), Vector3(x, ridge, zc), Vector3(signf(x), 0, 0))
		icicles(Vector3(gx0, low, z0 - overhang), Vector3(gx1, low, z0 - overhang))
		icicles(Vector3(gx0, low, z1 + overhang), Vector3(gx1, low, z1 + overhang))

	## Satteldach mit First entlang Z (Giebel vorne/hinten).
	func gable_roof_z(x0: float, x1: float, z0: float, z1: float, eave: float, ridge: float, overhang: float,
			gable_overhang: float, verge_boards: bool) -> void:
		var xc := (x0 + x1) * 0.5
		var slope := (ridge - eave) / (xc - x0)
		var low := eave - overhang * slope
		var gz0 := z0 - gable_overhang
		var gz1 := z1 + gable_overhang
		roof_slab([Vector3(x0 - overhang, low, gz1), Vector3(x0 - overhang, low, gz0), Vector3(xc, ridge, gz0), Vector3(xc, ridge, gz1)])
		roof_slab([Vector3(x1 + overhang, low, gz0), Vector3(x1 + overhang, low, gz1), Vector3(xc, ridge, gz1), Vector3(xc, ridge, gz0)])
		ridge_cap(Vector3(xc, ridge, gz0), Vector3(xc, ridge, gz1))
		for z: float in [z0, z1]:
			gable_fill(Vector3(x0, eave, z), Vector3(x1, eave, z), Vector3(xc, ridge, z), Vector3(0, 0, signf(z)))
		if verge_boards:
			# Verzierte Ortbretter am Giebel (typisch Chalet)
			for z: float in [gz0 - 0.02, gz1 + 0.02]:
				LowPolyBuilder.add_beam(st, Vector3(x0 - overhang, low - 0.08, z), Vector3(xc, ridge - 0.08, z), 0.16, TRIM)
				LowPolyBuilder.add_beam(st, Vector3(x1 + overhang, low - 0.08, z), Vector3(xc, ridge - 0.08, z), 0.16, TRIM)
		icicles(Vector3(x0 - overhang, low, gz0), Vector3(x0 - overhang, low, gz1))
		icicles(Vector3(x1 + overhang, low, gz0), Vector3(x1 + overhang, low, gz1))

	## Mansarddach: steiler unterer und flacher oberer Teil je Seite (First entlang Z).
	func gambrel_roof(x0: float, x1: float, z0: float, z1: float, eave: float, knee: float, ridge: float,
			overhang: float, gable_overhang: float) -> void:
		var xc := (x0 + x1) * 0.5
		var knee_in := (x1 - x0) * 0.2
		var gz0 := z0 - gable_overhang
		var gz1 := z1 + gable_overhang
		var steep := (knee - eave) / knee_in
		var low := eave - overhang * steep
		for side: float in [-1.0, 1.0]:
			var outer_x: float = x0 if side < 0.0 else x1
			var knee_x: float = outer_x - side * knee_in
			var eave_x: float = outer_x + side * overhang
			var lower := [Vector3(eave_x, low, gz1), Vector3(eave_x, low, gz0), Vector3(knee_x, knee, gz0), Vector3(knee_x, knee, gz1)]
			var upper := [Vector3(knee_x, knee, gz1), Vector3(knee_x, knee, gz0), Vector3(xc, ridge, gz0), Vector3(xc, ridge, gz1)]
			if side > 0.0:
				lower = [lower[1], lower[0], lower[3], lower[2]]
				upper = [upper[1], upper[0], upper[3], upper[2]]
			roof_slab(lower)
			roof_slab(upper)
			icicles(Vector3(eave_x, low, gz0), Vector3(eave_x, low, gz1))
		ridge_cap(Vector3(xc, ridge, gz0), Vector3(xc, ridge, gz1))
		for z: float in [z0, z1]:
			var n := Vector3(0, 0, signf(z))
			gable_fill(Vector3(x0, eave, z), Vector3(x0 + knee_in, knee, z), Vector3(x0 + knee_in, eave, z), n)
			gable_fill(Vector3(x1, eave, z), Vector3(x1 - knee_in, knee, z), Vector3(x1 - knee_in, eave, z), n)
			var quad := [Vector3(x0 + knee_in, eave, z), Vector3(x1 - knee_in, eave, z), Vector3(x1 - knee_in, knee, z), Vector3(x0 + knee_in, knee, z)]
			LowPolyBuilder.add_quad_facing(st, quad[0], quad[1], quad[2], quad[3], wall, n)
			gable_fill(Vector3(x0 + knee_in, knee, z), Vector3(x1 - knee_in, knee, z), Vector3(xc, ridge, z), n)

	## Walmdach: vier Dachflächen, kurzer First entlang X.
	func hip_roof(x0: float, x1: float, z0: float, z1: float, eave: float, ridge: float, overhang: float) -> void:
		var zc := (z0 + z1) * 0.5
		var half_depth := (z1 - z0) * 0.5
		var slope := (ridge - eave) / half_depth
		var low := eave - overhang * slope
		var inset := half_depth
		var r0 := Vector3(x0 + inset, ridge, zc)
		var r1 := Vector3(x1 - inset, ridge, zc)
		var e := [Vector3(x0 - overhang, low, z0 - overhang), Vector3(x1 + overhang, low, z0 - overhang),
			Vector3(x1 + overhang, low, z1 + overhang), Vector3(x0 - overhang, low, z1 + overhang)]
		roof_slab([e[0], e[1], r1, r0])
		roof_slab([e[2], e[3], r0, r1])
		roof_slab([e[1], e[2], r1])
		roof_slab([e[3], e[0], r0])
		ridge_cap(r0, r1)
		icicles(e[0], e[1])
		icicles(e[2], e[3])

	## Dachfläche als dicke Platte (Dachfarbe) mit Schneedecke obendrauf und Holzuntersicht.
	func roof_slab(points: Array) -> void:
		var n := LowPolyBuilder.face_normal(points[0], points[1], points[2])
		if n.y < 0.0:
			n = -n
		var centroid := Vector3.ZERO
		for p: Vector3 in points:
			centroid += p
		centroid /= points.size()
		var thickness := 0.16
		var top: Array[Vector3] = []
		var bottom: Array[Vector3] = []
		for p: Vector3 in points:
			top.append(p)
			bottom.append(p - n * thickness)
		_polygon(st, top, vary(roof, 0.02), n)
		_polygon(st, bottom, TIMBER.lightened(0.15), -n)
		for i in top.size():
			var j := (i + 1) % top.size()
			var mid := (top[i] + top[j]) * 0.5
			var edge_out := RailGeometry.flat(mid - centroid).normalized() + Vector3.DOWN * 0.2
			LowPolyBuilder.add_quad_facing(st, top[i], top[j], bottom[j], bottom[i], roof.darkened(0.25), edge_out)
		# Schnee: etwas kleiner als die Dachfläche, damit die Dachkante sichtbar bleibt
		var snow: Array[Vector3] = []
		var snow_low: Array[Vector3] = []
		for p: Vector3 in points:
			var shrunk := centroid + (p - centroid) * 0.94
			snow.append(shrunk + n * 0.1)
			snow_low.append(shrunk + n * 0.02)
		_polygon(st, snow, SNOW.lerp(SNOW_SHADE, rng.randf() * 0.3), n)
		for i in snow.size():
			var j := (i + 1) % snow.size()
			var mid := (snow[i] + snow[j]) * 0.5
			LowPolyBuilder.add_quad_facing(st, snow[i], snow[j], snow_low[j], snow_low[i], SNOW_SHADE,
				RailGeometry.flat(mid - centroid).normalized())

	func ridge_cap(a: Vector3, b: Vector3) -> void:
		LowPolyBuilder.add_beam(st, a + Vector3.UP * 0.08, b + Vector3.UP * 0.08, 0.26, SNOW)

	## Giebeldreieck (Wandfarbe) mit kleinem Lüftungsloch.
	func gable_fill(a: Vector3, b: Vector3, apex: Vector3, outward: Vector3) -> void:
		LowPolyBuilder.add_triangle_facing(st, a, b, apex, vary(wall, 0.015), outward)
		LowPolyBuilder.add_triangle_facing(st, a + outward * 0.01, b + outward * 0.01, apex + outward * 0.01,
			vary(wall, 0.015), outward)

	## Eiszapfen und Schneewulst entlang einer Traufe.
	func icicles(a: Vector3, b: Vector3) -> void:
		var length := a.distance_to(b)
		var count := int(length / 0.45)
		for i in count:
			if rng.randf() < 0.45:
				continue
			var p := a.lerp(b, (i + 0.5) / count) + Vector3.DOWN * 0.14
			LowPolyBuilder.add_cone(st, p, rng.randf_range(0.03, 0.05), -rng.randf_range(0.18, 0.45), 4, ICE, rng.randf() * TAU, false)

	# Fenster und Türen --------------------------------------------------------

	## Sprossenfenster auf einer Wand. [param center] liegt auf der Wandfläche,
	## [param facing] ist die Wandnormale nach außen.
	func window(center: Vector3, facing: Vector3, width: float, height: float, shutters: bool, flower_box: bool) -> void:
		var basis := Basis.looking_at(-facing, Vector3.UP)  # lokal: +Z = nach außen
		var xf := Transform3D(basis, center + facing * 0.02)
		var frame := TRIM
		LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, height * 0.5 + 0.05, 0.03)), Vector3(width + 0.2, 0.1, 0.08), frame)
		LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, -height * 0.5 - 0.05, 0.05)), Vector3(width + 0.28, 0.08, 0.16), frame)
		LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, -height * 0.5 - 0.0, 0.09)), Vector3(width + 0.2, 0.05, 0.12), SNOW)
		for side: float in [-1.0, 1.0]:
			LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(side * (width * 0.5 + 0.05), 0, 0.03)), Vector3(0.1, height, 0.08), frame)
		# Sprossen
		LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, 0, 0.035)), Vector3(0.05, height, 0.04), frame)
		LowPolyBuilder.add_oriented_box(st, xf.translated_local(Vector3(0, height * 0.12, 0.035)), Vector3(width, 0.05, 0.04), frame)
		# Glas (eigene Oberfläche): Rot = nachts beleuchtet (manche bleiben dunkel)
		var lit := 0.0 if rng.randf() < 0.25 else rng.randf_range(0.65, 1.0)
		_glass_quad(xf, width, height, lit)
		if shutters:
			for side: float in [-1.0, 1.0]:
				var shutter_xf := xf.translated_local(Vector3(side * (width * 0.5 + 0.1 + width * 0.25), 0, 0.03))
				LowPolyBuilder.add_oriented_box(st, shutter_xf, Vector3(width * 0.48, height + 0.05, 0.05), vary(shutter, 0.02))
				for k in 3:
					LowPolyBuilder.add_oriented_box(st, shutter_xf.translated_local(Vector3(0, (k - 1) * height * 0.3, 0.03)),
						Vector3(width * 0.4, 0.03, 0.02), shutter.darkened(0.2))
		if flower_box:
			var box_xf := xf.translated_local(Vector3(0, -height * 0.5 - 0.17, 0.16))
			LowPolyBuilder.add_oriented_box(st, box_xf, Vector3(width + 0.1, 0.2, 0.22), DOOR_WOOD.lightened(0.1))
			for k in 5:
				var p := box_xf * Vector3(lerpf(-width * 0.45, width * 0.45, k / 4.0), 0.1, rng.randf_range(-0.05, 0.05))
				LowPolyBuilder.add_cone(st, p, 0.08, rng.randf_range(0.14, 0.22), 5, vary(GREEN, 0.04), rng.randf() * TAU, false)
				if rng.randf() < 0.6:
					LowPolyBuilder.add_box(st, p + Vector3(0, 0.12, 0), Vector3.ONE * 0.04, BERRY)

	## Haustür mit Rahmen, Fenster, Kranz, Stufe, Lampe und (optional) Vordach.
	func door(base: Vector3, canopy: bool) -> void:
		var out := Vector3.FORWARD if base.z < 0.0 else Vector3.BACK
		var z := base.z + out.z * 0.03
		var w := 1.0
		var h := 2.05
		var y := base.y
		LowPolyBuilder.add_box(st, Vector3(base.x, y + h * 0.5, z), Vector3(w + 0.22, h + 0.12, 0.1), TRIM)
		for k in 3:
			LowPolyBuilder.add_box(st, Vector3(base.x - w * 0.33 + k * w * 0.33, y + h * 0.5 - 0.02, z + out.z * 0.05),
				Vector3(w * 0.31, h - 0.08, 0.06), vary(door_color, 0.02))
		var pane := Transform3D(Basis.looking_at(-out, Vector3.UP), Vector3(base.x, y + h * 0.72, z + out.z * 0.085))
		_glass_quad(pane, 0.36, 0.36, 0.9)
		LowPolyBuilder.add_box(st, Vector3(base.x + w * 0.36, y + h * 0.46, z + out.z * 0.1), Vector3(0.06, 0.06, 0.05), BRASS)
		# Kranz aus Tannengrün mit roter Schleife
		var wreath := Vector3(base.x, y + h * 0.72, z + out.z * 0.14)
		for k in 10:
			var angle := TAU * k / 10.0
			LowPolyBuilder.add_box(st, wreath + Vector3(cos(angle) * 0.2, sin(angle) * 0.2, 0.0), Vector3(0.11, 0.11, 0.07), vary(GREEN, 0.04))
		LowPolyBuilder.add_box(st, wreath + Vector3(0, -0.2, 0.03), Vector3(0.12, 0.08, 0.04), BERRY)
		# Stufe(n) vor der Tür
		LowPolyBuilder.add_box(st, Vector3(base.x, y - 0.1, base.z + out.z * 0.45), Vector3(w + 0.6, 0.2, 0.7), STONE)
		LowPolyBuilder.add_box(st, Vector3(base.x, y + 0.005, base.z + out.z * 0.45), Vector3(w + 0.5, 0.02, 0.6), SNOW_SHADE)
		# Wandlampe neben der Tür (leuchtet nachts)
		var lamp := Vector3(base.x - w * 0.5 - 0.35, y + h + 0.05, z + out.z * 0.12)
		LowPolyBuilder.add_box(st, lamp + Vector3(0, 0.15, -out.z * 0.06), Vector3(0.05, 0.05, 0.14), TIMBER.darkened(0.3))
		LowPolyBuilder.add_box(st, lamp + Vector3(0, 0.13, 0), Vector3(0.18, 0.04, 0.18), TIMBER.darkened(0.3))
		var lamp_xf := Transform3D(Basis.looking_at(-out, Vector3.UP), lamp + out * 0.075)
		_glass_quad(lamp_xf, 0.13, 0.18, 1.0)
		for side: float in [-1.0, 1.0]:
			_glass_quad(Transform3D(Basis.looking_at(Vector3(-side, 0, 0), Vector3.UP), lamp + Vector3(side * 0.075, 0, 0)), 0.13, 0.18, 1.0)
		lights.append(lamp + out * 0.3)
		if canopy:
			var cz := base.z + out.z * 0.55
			for side: float in [-1.0, 1.0]:
				LowPolyBuilder.add_beam(st, Vector3(base.x + side * (w * 0.7), y + h + 0.1, base.z + out.z * 0.05),
					Vector3(base.x + side * (w * 0.7), y + h - 0.3, base.z + out.z * 0.9), 0.07, TIMBER)
			var a := Vector3(base.x - w * 0.85, y + h + 0.55, base.z + out.z * 0.02)
			var b := Vector3(base.x + w * 0.85, y + h + 0.55, base.z + out.z * 0.02)
			var c := Vector3(base.x + w * 0.85, y + h + 0.15, cz + out.z * 0.55)
			var d := Vector3(base.x - w * 0.85, y + h + 0.15, cz + out.z * 0.55)
			roof_slab([a, b, c, d] if out.z < 0.0 else [b, a, d, c])
		door_point = Vector3(base.x, 0.0, base.z + out.z * 1.3)

	func triangle_window(bottom_center: Vector3, width: float, height: float) -> void:
		var xf := Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), bottom_center + Vector3.FORWARD * 0.02)
		var a := xf * Vector3(-width * 0.5, 0, 0)
		var b := xf * Vector3(width * 0.5, 0, 0)
		var c := xf * Vector3(0, height, 0)
		_glass_triangle(a, b, c, Vector3.FORWARD, 0.9)
		LowPolyBuilder.add_beam(st, a, b, 0.09, TRIM)
		LowPolyBuilder.add_beam(st, a, c, 0.09, TRIM)
		LowPolyBuilder.add_beam(st, b, c, 0.09, TRIM)
		LowPolyBuilder.add_beam(st, (a + b) * 0.5, c, 0.06, TRIM)

	## Großes Scheunentor-Fenster mit Andreaskreuz.
	func barn_window(center: Vector3, width: float, height: float) -> void:
		var xf := Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), center + Vector3.FORWARD * 0.03)
		_glass_quad(xf, width, height, 0.8)
		var corners := [xf * Vector3(-width * 0.5, -height * 0.5, 0.04), xf * Vector3(width * 0.5, -height * 0.5, 0.04),
			xf * Vector3(width * 0.5, height * 0.5, 0.04), xf * Vector3(-width * 0.5, height * 0.5, 0.04)]
		for i in 4:
			LowPolyBuilder.add_beam(st, corners[i], corners[(i + 1) % 4], 0.14, TRIM)
		LowPolyBuilder.add_beam(st, corners[0], corners[2], 0.1, TRIM)
		LowPolyBuilder.add_beam(st, corners[1], corners[3], 0.1, TRIM)

	## Erker: ein kleiner Vorbau mit drei Fenstern und eigenem Dach.
	func bay_window(base: Vector3, width: float, height: float) -> void:
		var depth := 0.8
		var z := base.z - depth
		walls(base.x - width * 0.5, base.x + width * 0.5, z, base.z, base.y, base.y + 0.6, wall)
		LowPolyBuilder.add_box(st, Vector3(base.x, base.y + 0.6 + height * 0.5, z + depth * 0.5), Vector3(width, height, depth), vary(wall, 0.01))
		window(Vector3(base.x, base.y + 0.6 + height * 0.5, z), Vector3.FORWARD, width * 0.6, height * 0.7, false, false)
		for side: float in [-1.0, 1.0]:
			window(Vector3(base.x + side * width * 0.5, base.y + 0.6 + height * 0.5, z + depth * 0.5), Vector3(side, 0, 0),
				depth * 0.55, height * 0.7, false, false)
		var top := base.y + 0.6 + height
		roof_slab([Vector3(base.x - width * 0.5 - 0.15, top + 0.05, z - 0.15), Vector3(base.x + width * 0.5 + 0.15, top + 0.05, z - 0.15),
			Vector3(base.x + width * 0.5 + 0.15, top + 0.45, base.z), Vector3(base.x - width * 0.5 - 0.15, top + 0.45, base.z)])

	## Gaube: kleiner Aufbau mit Fenster auf der vorderen Dachfläche.
	func dormer(front: Vector3, eave: float, ridge: float, half_depth: float, width: float) -> void:
		var slope := (ridge - eave) / half_depth
		var z_face := front.z + 0.35
		var y_base := eave + (z_face - front.z) * slope
		var h := 1.0
		var back := z_face + (h + 0.2) / slope
		LowPolyBuilder.add_box(st, Vector3(front.x, y_base + h * 0.5 - 0.1, (z_face + back) * 0.5),
			Vector3(width, h + 0.2, back - z_face), vary(wall, 0.01))
		window(Vector3(front.x, y_base + h * 0.45, z_face), Vector3.FORWARD, width * 0.55, h * 0.6, false, false)
		var top := y_base + h + 0.1
		var ov := 0.18
		roof_slab([Vector3(front.x - width * 0.5 - ov, top, z_face - ov), Vector3(front.x, top + 0.45, z_face - ov),
			Vector3(front.x, top + 0.45, back), Vector3(front.x - width * 0.5 - ov, top, back)])
		roof_slab([Vector3(front.x, top + 0.45, z_face - ov), Vector3(front.x + width * 0.5 + ov, top, z_face - ov),
			Vector3(front.x + width * 0.5 + ov, top, back), Vector3(front.x, top + 0.45, back)])
		gable_fill(Vector3(front.x - width * 0.5, top, z_face), Vector3(front.x + width * 0.5, top, z_face),
			Vector3(front.x, top + 0.45, z_face), Vector3.FORWARD)

	## Runder (achteckiger) Eckturm mit Fenstern und spitzem Kegeldach.
	func turret(center: Vector3, radius: float, eave: float, apex: float) -> void:
		var segments := 8
		LowPolyBuilder.add_cylinder(st, center + Vector3.DOWN * 0.8, radius + 0.1, radius + 0.1, 1.15, segments, STONE, PI / 8.0)
		LowPolyBuilder.add_cylinder(st, center + Vector3.UP * 0.35, radius, radius, eave - 0.35, segments, vary(wall, 0.01), PI / 8.0)
		LowPolyBuilder.add_cylinder(st, center + Vector3.UP * 2.3, radius + 0.04, radius + 0.04, 0.14, segments, TRIM, PI / 8.0)
		for level: float in [1.45, 3.4, 5.0]:
			for k: int in ([5, 6, 7] if level < 3.0 else [4, 5, 6, 7]):
				var angle := PI / 8.0 + TAU * (k + 0.5) / segments
				var normal := Vector3(cos(angle), 0, sin(angle))
				var apothem := radius * cos(PI / segments)
				window(center + normal * apothem + Vector3.UP * level, normal, 0.45, 0.7, false, false)
		var ring: Array[Vector3] = []
		for k in segments:
			var angle := PI / 8.0 + TAU * k / segments
			ring.append(center + Vector3(cos(angle), 0, sin(angle)) * (radius + 0.3) + Vector3.UP * eave)
		var tip := center + Vector3.UP * apex
		for k in segments:
			roof_slab([ring[k], ring[(k + 1) % segments], tip])
		LowPolyBuilder.add_cylinder(st, tip, 0.05, 0.02, 0.5, 4, BRASS)
		LowPolyBuilder.add_box(st, tip + Vector3.UP * 0.55, Vector3(0.12, 0.12, 0.12), BRASS)

	## A-Frame: steile Dachflächen bis fast zum Boden, Stirnwände als Dreiecke.
	func a_frame(x0: float, x1: float, z0: float, z1: float, y0: float, ridge: float) -> void:
		var xc := (x0 + x1) * 0.5
		var ov := 0.35
		for side: float in [-1.0, 1.0]:
			var x: float = x0 if side < 0.0 else x1
			var slab := [Vector3(x + side * 0.25, y0 - 0.1, z1 + ov), Vector3(x + side * 0.25, y0 - 0.1, z0 - ov),
				Vector3(xc, ridge, z0 - ov), Vector3(xc, ridge, z1 + ov)]
			if side > 0.0:
				slab = [slab[1], slab[0], slab[3], slab[2]]
			roof_slab(slab)
		ridge_cap(Vector3(xc, ridge, z0 - ov), Vector3(xc, ridge, z1 + ov))
		for z: float in [z0, z1]:
			var n := Vector3(0, 0, signf(z))
			LowPolyBuilder.add_triangle_facing(st, Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(xc, ridge - 0.1, z),
				TIMBER.lightened(0.2), n)
			# Senkrechte Bretter auf der Stirnwand
			var x := x0 + 0.3
			while x < x1 - 0.2:
				var t := 1.0 - absf(x - xc) / (xc - x0)
				LowPolyBuilder.add_box(st, Vector3(x, y0 + (ridge - y0) * t * 0.5, z + n.z * 0.015),
					Vector3(0.04, (ridge - y0) * t, 0.03), TIMBER)
				x += 0.4
		LowPolyBuilder.add_box(st, Vector3(xc, y0 + 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0 - 0.3, 0.3, z1 - z0 - 0.1), TIMBER)

	func deck(x0: float, x1: float, z0: float, z1: float) -> void:
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, 0.25, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), TIMBER.lightened(0.15))
		for x: float in [x0 + 0.1, x1 - 0.1]:
			LowPolyBuilder.add_box(st, Vector3(x, 0.6, (z0 + z1) * 0.5), Vector3(0.08, 0.7, z1 - z0), TIMBER)
			LowPolyBuilder.add_box(st, Vector3(x, 0.98, (z0 + z1) * 0.5), Vector3(0.12, 0.05, z1 - z0 + 0.05), SNOW)
		for k in 6:
			var z := lerpf(z0 + 0.1, z1, k / 5.0)
			for x: float in [x0 + 0.1, x1 - 0.1]:
				LowPolyBuilder.add_box(st, Vector3(x, 0.55, z), Vector3(0.06, 0.6, 0.06), TIMBER)

	func balcony(x0: float, x1: float, z_wall: float, y: float) -> void:
		var z := z_wall - 0.9
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y, (z + z_wall) * 0.5), Vector3(x1 - x0, 0.14, z_wall - z), TIMBER)
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y + 0.95, z), Vector3(x1 - x0, 0.08, 0.1), TIMBER)
		LowPolyBuilder.add_box(st, Vector3((x0 + x1) * 0.5, y + 1.02, z), Vector3(x1 - x0, 0.05, 0.14), SNOW)
		var x := x0 + 0.1
		while x <= x1 - 0.05:
			LowPolyBuilder.add_box(st, Vector3(x, y + 0.5, z), Vector3(0.1, 0.85, 0.05), TIMBER.lightened(0.1))
			x += 0.24
		for xs: float in [x0 + 0.1, x1 - 0.1]:
			LowPolyBuilder.add_beam(st, Vector3(xs, y - 0.9, z_wall), Vector3(xs, y - 0.05, z + 0.1), 0.1, TIMBER)

	func bench_at_wall(base: Vector3) -> void:
		var z := base.z - 0.35
		LowPolyBuilder.add_box(st, Vector3(base.x, base.y + 0.42, z), Vector3(1.4, 0.07, 0.4), TIMBER.lightened(0.15))
		for x: float in [-0.55, 0.55]:
			LowPolyBuilder.add_box(st, Vector3(base.x + x, base.y + 0.2, z), Vector3(0.08, 0.4, 0.35), TIMBER)
		LowPolyBuilder.add_box(st, Vector3(base.x, base.y + 0.46, z), Vector3(1.2, 0.02, 0.3), SNOW)

	func chimney(base: Vector3, top: float) -> void:
		var bottom := 3.0
		LowPolyBuilder.add_box(st, Vector3(base.x, (bottom + top) * 0.5, base.z), Vector3(0.6, top - bottom, 0.6), BRICK)
		var y := bottom + 0.3
		while y < top - 0.2:
			LowPolyBuilder.add_box(st, Vector3(base.x, y, base.z), Vector3(0.62, 0.04, 0.62), BRICK.darkened(0.15))
			y += 0.35
		LowPolyBuilder.add_box(st, Vector3(base.x, top + 0.05, base.z), Vector3(0.78, 0.12, 0.78), STONE)
		LowPolyBuilder.add_box(st, Vector3(base.x, top + 0.14, base.z), Vector3(0.7, 0.07, 0.7), SNOW)
		chimneys.append(Vector3(base.x, top + 0.25, base.z))

	# Geometrie-Hilfen --------------------------------------------------------

	func _polygon(target: SurfaceTool, points: Array[Vector3], color: Color, outward: Vector3) -> void:
		for i in range(1, points.size() - 1):
			LowPolyBuilder.add_triangle_facing(target, points[0], points[i], points[i + 1], color, outward)

	## Fensterglas: Vertexfarbe Rot = Helligkeit bei Nacht, Grün = Höhe (1 oben).
	func _glass_quad(xf: Transform3D, width: float, height: float, lit: float) -> void:
		var hw := width * 0.5
		var hh := height * 0.5
		var a := xf * Vector3(-hw, -hh, 0.0)
		var b := xf * Vector3(hw, -hh, 0.0)
		var c := xf * Vector3(hw, hh, 0.0)
		var d := xf * Vector3(-hw, hh, 0.0)
		var normal := xf.basis.z.normalized()
		_glass_vertex_triangle([a, b, c], [0.0, 0.0, 1.0], normal, lit)
		_glass_vertex_triangle([a, c, d], [0.0, 1.0, 1.0], normal, lit)

	func _glass_triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, lit: float) -> void:
		_glass_vertex_triangle([a, b, c], [0.0, 0.0, 1.0], normal, lit)

	func _glass_vertex_triangle(points: Array, heights: Array, normal: Vector3, lit: float) -> void:
		var order := [0, 1, 2]
		if LowPolyBuilder.face_normal(points[0], points[1], points[2]).dot(normal) < 0.0:
			order = [0, 2, 1]
		for i: int in order:
			glass.set_color(Color(lit, float(heights[i]), 0.0))
			glass.set_normal(normal)
			glass.add_vertex(points[i])
