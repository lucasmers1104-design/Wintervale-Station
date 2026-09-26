@tool
## Prozedurale Natur-Assets: verschneite Tannen und Steine.
##
## Jede Funktion liefert ein fertiges ArrayMesh mit Vertexfarben.
## Unterschiedliche Zufallswerte ergeben unterschiedliche Varianten.
class_name NatureMeshes
extends RefCounted

const TRUNK_COLOR := Color(0.33, 0.23, 0.17)
const NEEDLE_COLOR := Color(0.17, 0.29, 0.24)
const NEEDLE_COLOR_DARK := Color(0.12, 0.21, 0.19)
const SNOW_COLOR := Color(0.90, 0.93, 0.97)
const ROCK_COLOR := Color(0.44, 0.45, 0.50)
const ROCK_COLOR_DARK := Color(0.35, 0.36, 0.41)


## Tanne aus gestapelten Kegeln, jede Stufe mit einer Schneehaube.
## Ursprung = Stammfuß. Höhe ca. 4–5 m.
static func create_pine(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	LowPolyBuilder.add_cylinder(st, Vector3(0.0, -0.3, 0.0), 0.2, 0.13, 1.6, 6, TRUNK_COLOR)

	var needle := NEEDLE_COLOR.lerp(NEEDLE_COLOR_DARK, rng.randf())
	var tiers := rng.randi_range(3, 4)
	var radius := rng.randf_range(1.45, 1.8)
	var y := 0.8
	for i in tiers:
		var tier_height := radius * 1.35
		var offset := rng.randf() * TAU
		LowPolyBuilder.add_cone(st, Vector3(0.0, y, 0.0), radius, tier_height, 7, needle, offset)
		# Die Schneehaube ist ein flacherer Kegel über der oberen Hälfte der Stufe.
		LowPolyBuilder.add_cone(st, Vector3(0.0, y + tier_height * 0.45, 0.0), radius * 0.64,
			tier_height * 0.6, 7, SNOW_COLOR, offset, false)
		y += tier_height * 0.5
		radius *= 0.72

	return st.commit()


## Stein mit Schnee auf den oberen Flächen. Ursprung = Mittelpunkt, Radius ca. 1 m.
static func create_rock(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := ROCK_COLOR.lerp(ROCK_COLOR_DARK, rng.randf())
	LowPolyBuilder.add_rock(st, rng, Vector3.ZERO, 1.0, color, SNOW_COLOR)
	return st.commit()
