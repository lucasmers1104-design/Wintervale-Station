@tool
## Prozedurale Natur-Assets: verschneite Tannen und Steine.
##
## Jede Funktion liefert ein fertiges ArrayMesh mit Vertexfarben.
## Unterschiedliche Zufallswerte ergeben unterschiedliche Varianten.
class_name NatureMeshes
extends RefCounted

const SNOW_COLOR := Color(0.90, 0.93, 0.97)
const ROCK_COLOR := Color(0.48, 0.46, 0.46)
const ROCK_COLOR_DARK := Color(0.38, 0.36, 0.37)


## Tanne – seit Etappe 7 dieselben Modelle wie im Dorf (hohe Fichte oder Tanne),
## damit alle Nadelbäume einheitlich aussehen. Ursprung = Stammfuß.
static func create_pine(rng: RandomNumberGenerator) -> ArrayMesh:
	var village_st := SurfaceTool.new()
	village_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if rng.randf() < 0.5:
		VillageMeshes.tree_pine_tall(village_st, rng)
	else:
		VillageMeshes.tree_fir_full(village_st, rng)
	return village_st.commit()


## Stein mit Schnee auf den oberen Flächen. Ursprung = Mittelpunkt, Radius ca. 1 m.
static func create_rock(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := ROCK_COLOR.lerp(ROCK_COLOR_DARK, rng.randf())
	LowPolyBuilder.add_rock(st, rng, Vector3.ZERO, 1.0, color, SNOW_COLOR)
	return st.commit()
