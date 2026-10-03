@tool
## Einstiegspunkt und Maße der dreiteiligen Regionaltriebzüge.
## Die Referenzgeometrie entsteht in ReferenceRailcarMeshes; Fahrwerk und
## Einstiegsschnittstellen bleiben für TrainMeshes/TrainCar kompatibel.
class_name RailcarMeshes
extends RefCounted

const SPECS := {
	"railcar_front": {"length": 12.0, "bogie": 4.35, "wheel_base": 2.1},
	"railcar_middle": {"length": 11.0, "bogie": 3.9, "wheel_base": 2.1},
	"railcar_rear": {"length": 12.0, "bogie": 4.35, "wheel_base": 2.1},
}
const NOSE_LENGTH := 2.35
const DOOR_HALF := 0.67
const UNDER := TrainMeshes.UNDER
const FRAME := TrainMeshes.FRAME
const METAL := TrainMeshes.METAL


static func build(kind: String, livery: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return ReferenceRailcarMeshes.build(kind, livery, rng)


## Schürzen lassen Drehgestelle und die ausfahrbaren Einstiege frei.
static func _skirts(paint: SurfaceTool, livery: Dictionary, half: float, bogie: float, door_zs: Array[float],
		start: float) -> void:
	var cuts: Array = [[-bogie - 1.45, -bogie + 1.45], [bogie - 1.45, bogie + 1.45]]
	for door_z in door_zs:
		cuts.append([door_z - DOOR_HALF - 0.08, door_z + DOOR_HALF + 0.08])
	var pieces: Array = [[start, half - 0.15]]
	for cut: Array in cuts:
		var next: Array = []
		for piece: Array in pieces:
			if cut[1] <= piece[0] or cut[0] >= piece[1]:
				next.append(piece)
				continue
			if cut[0] > piece[0]:
				next.append([piece[0], cut[0]])
			if cut[1] < piece[1]:
				next.append([cut[1], piece[1]])
		pieces = next
	var color: Color = livery["secondary"] if livery.get("winter_special", false) else livery["primary"].darkened(0.12)
	var profile: Array[Vector2] = [Vector2(1.3, 1.02), Vector2(1.31, 0.82), Vector2(1.25, 0.66)]
	for piece: Array in pieces:
		if float(piece[1]) - float(piece[0]) < 0.25:
			continue
		for side: float in [-1.0, 1.0]:
			for i in profile.size() - 1:
				var a := profile[i]
				var b := profile[i + 1]
				var outward := Vector3(side, (a.x - b.x) * 2.0, 0.0)
				LowPolyBuilder.add_quad_facing(paint, Vector3(side * a.x, a.y, piece[0]), Vector3(side * a.x, a.y, piece[1]),
					Vector3(side * b.x, b.y, piece[1]), Vector3(side * b.x, b.y, piece[0]), color, outward)
			# Stirnkanten der Schürze
			for z: float in [piece[0], piece[1]]:
				LowPolyBuilder.add_quad_facing(paint, Vector3(side * 1.3, 1.02, z), Vector3(side * 1.18, 1.02, z),
					Vector3(side * 1.18, 0.66, z), Vector3(side * 1.25, 0.66, z), color.darkened(0.2), Vector3(0, 0, signf(z)))


static func _underfloor(paint: SurfaceTool, bogie: float) -> void:
	var span := bogie - 1.6
	LowPolyBuilder.add_box(paint, Vector3(0.0, 0.8, 0.0), Vector3(2.2, 0.36, span * 2.0), UNDER)
	LowPolyBuilder.add_cylinder_between(paint, Vector3(-0.55, 0.72, -span * 0.8), Vector3(-0.55, 0.72, span * 0.2), 0.3, 10, FRAME)
	LowPolyBuilder.add_box(paint, Vector3(0.6, 0.7, span * 0.4), Vector3(0.8, 0.4, span * 0.8), FRAME)
	for x: float in [-1.0, 1.0]:
		LowPolyBuilder.add_cylinder_between(paint, Vector3(x * 0.9, 0.93, -bogie + 1.4), Vector3(x * 0.9, 0.93, bogie - 1.4),
			0.025, 5, METAL)


static func _mirror_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in vertices.size():
			vertices[i].z = -vertices[i].z
			normals[i].z = -normals[i].z
		# Spiegeln dreht den Umlaufsinn um: je Dreieck zwei Ecken tauschen
		for i in range(0, vertices.size() - 2, 3):
			var v := vertices[i + 1]
			vertices[i + 1] = vertices[i + 2]
			vertices[i + 2] = v
			var nn := normals[i + 1]
			normals[i + 1] = normals[i + 2]
			normals[i + 2] = nn
			var c := colors[i + 1]
			colors[i + 1] = colors[i + 2]
			colors[i + 2] = c
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
