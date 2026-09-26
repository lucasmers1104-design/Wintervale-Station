@tool
## Prozedurales Low-Poly-Terrain mit flacher Schattierung.
##
## Erzeugt aus Rauschen das Geländemesh, seine Kollision und einen
## zugefrorenen See. Die Kartenmitte bleibt bewusst flach – dort entstehen
## später Bahnhof, Gleise und Dorf. Am Rand rahmen Berge die Welt ein.
##
## Läuft auch im Editor (@tool), damit das Gelände dort sichtbar ist.
## Nach Änderungen an den Werten: Button "Terrain neu erzeugen" im Inspector.
class_name LowPolyTerrain
extends StaticBody3D

const COLOR_SNOW := Color(0.90, 0.93, 0.97)
const COLOR_SNOW_SHADE := Color(0.80, 0.85, 0.93)
const COLOR_ROCK := Color(0.42, 0.43, 0.48)
const COLOR_ROCK_DARK := Color(0.31, 0.32, 0.37)
const COLOR_EARTH := Color(0.45, 0.39, 0.33)
const COLOR_LAKE_BED := Color(0.55, 0.63, 0.70)

## Gleicher Seed = gleiche Welt. Wichtig für Spielstände.
@export var terrain_seed := 1887
@export_range(16, 256, 1) var cells_per_side := 128
@export_range(0.5, 8.0, 0.1) var cell_size := 2.0
## Zufälliger Versatz der Gitterpunkte (Anteil einer Zelle) für einen organischen Look.
@export_range(0.0, 0.45, 0.01) var vertex_jitter := 0.3

@export_group("Höhen")
@export var hill_height := 5.0
@export var mountain_height := 30.0
## Radius der flachen Mitte in Metern.
@export var flat_radius := 38.0

@export_group("Zugefrorener See")
@export var lake_center := Vector2(52.0, -38.0)
@export var lake_radius := 16.0
@export var ice_level := -0.6

@export_group("Materialien")
@export var terrain_material: Material
@export var ice_material: Material

@export_tool_button("Terrain neu erzeugen", "Reload")
var regenerate_action: Callable = generate

var _height_noise: FastNoiseLite
var _detail_noise: FastNoiseLite


func _ready() -> void:
	generate()


## Baut Mesh, Kollision und Eisfläche komplett neu auf.
func generate() -> void:
	_setup_noise()
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()

	var mesh := _build_terrain_mesh()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	_add_generated(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = mesh.create_trimesh_shape()
	_add_generated(collision)

	_build_ice()


## Geländehöhe an einer Weltposition. Funktioniert schon vor generate().
func get_height(x: float, z: float) -> float:
	if _height_noise == null:
		_setup_noise()
	var pos := Vector2(x, z)

	var height := _height_noise.get_noise_2d(x, z) * hill_height

	# Berge am quadratischen Kartenrand
	var edge_distance := maxf(absf(x), absf(z)) / get_half_extent()
	var edge := smoothstep(0.55, 0.95, edge_distance)
	var ridge := 1.0 - absf(_detail_noise.get_noise_2d(x * 0.6, z * 0.6))
	height += edge * mountain_height * (0.45 + 0.55 * ridge)

	# Flache Mitte mit nur ganz leichten Wellen
	var center_blend := 1.0 - smoothstep(flat_radius * 0.55, flat_radius, pos.length())
	height = lerpf(height, _detail_noise.get_noise_2d(x * 2.0, z * 2.0) * 0.12, center_blend)

	# See: erhöhter Uferrand, damit die Eisfläche nie in der Luft hängt, dann eine Mulde
	var lake_distance := pos.distance_to(lake_center) / lake_radius
	if lake_distance < 1.6:
		var rim := ice_level + 0.45
		height = lerpf(height, maxf(height, rim), 1.0 - smoothstep(1.0, 1.6, lake_distance))
		var bowl := 1.0 - smoothstep(0.45, 0.95, lake_distance)
		height = lerpf(height, ice_level - 1.4, bowl)

	return height


## Halbe Kantenlänge der Karte in Metern (die Karte reicht von -x bis +x).
func get_half_extent() -> float:
	return cells_per_side * cell_size * 0.5


## Schnittpunkt eines Strahls (z.B. vom Mauszeiger) mit dem Gelände.
## Tastet die Höhenfunktion schrittweise ab und verfeinert per Bisektion.
## Gibt [code]Vector3.INF[/code] zurück, wenn der Strahl das Gelände nicht trifft.
func intersect_ray(origin: Vector3, direction: Vector3, max_distance := 1000.0) -> Vector3:
	var half := get_half_extent()
	var previous := 0.0
	var t := 0.0
	while t < max_distance:
		var p := origin + direction * t
		var above := p.y - get_height(p.x, p.z)
		if above <= 0.0:
			var low := previous
			var high := t
			for i in 14:
				var mid := (low + high) * 0.5
				var q := origin + direction * mid
				if q.y - get_height(q.x, q.z) <= 0.0:
					high = mid
				else:
					low = mid
			var hit := origin + direction * high
			if absf(hit.x) > half or absf(hit.z) > half:
				return Vector3.INF
			return hit
		previous = t
		t += clampf(above * 0.5, 0.25, 8.0)
	return Vector3.INF


func is_in_lake(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(lake_center) < lake_radius * 1.05


func _setup_noise() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = terrain_seed
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.012
	_height_noise.fractal_octaves = 4

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = terrain_seed + 101
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.03
	_detail_noise.fractal_octaves = 2


func _build_terrain_mesh() -> ArrayMesh:
	var n := cells_per_side
	var half := get_half_extent()
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed

	# Gitterpunkte (Randpunkte bleiben gerade, damit die Kante sauber ist)
	var points := PackedVector3Array()
	points.resize((n + 1) * (n + 1))
	for z in n + 1:
		for x in n + 1:
			var px := x * cell_size - half
			var pz := z * cell_size - half
			if x > 0 and x < n and z > 0 and z < n:
				px += rng.randf_range(-vertex_jitter, vertex_jitter) * cell_size
				pz += rng.randf_range(-vertex_jitter, vertex_jitter) * cell_size
			points[z * (n + 1) + x] = Vector3(px, get_height(px, pz), pz)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in n:
		for x in n:
			var a := points[z * (n + 1) + x]
			var b := points[z * (n + 1) + x + 1]
			var c := points[(z + 1) * (n + 1) + x]
			var d := points[(z + 1) * (n + 1) + x + 1]
			# Wechselnde Diagonalen vermeiden sichtbare Streifenmuster.
			if (x + z) % 2 == 0:
				_add_terrain_triangle(st, a, b, d, rng)
				_add_terrain_triangle(st, a, d, c, rng)
			else:
				_add_terrain_triangle(st, a, b, c, rng)
				_add_terrain_triangle(st, b, d, c, rng)
	return st.commit()


func _add_terrain_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		rng: RandomNumberGenerator) -> void:
	var normal := LowPolyBuilder.face_normal(a, b, c)
	if normal.y < 0.0:
		normal = -normal
	var color := _terrain_color((a + b + c) / 3.0, normal, rng)
	LowPolyBuilder.add_triangle_facing(st, a, b, c, color, Vector3.UP)


func _terrain_color(center: Vector3, normal: Vector3, rng: RandomNumberGenerator) -> Color:
	var slope := 1.0 - normal.y
	var color: Color
	if center.y < ice_level + 0.1 and is_in_lake(center.x, center.z):
		color = COLOR_LAKE_BED
	elif slope > 0.42:
		color = COLOR_ROCK_DARK
	elif slope > 0.25:
		color = COLOR_ROCK
	elif slope > 0.12 and _detail_noise.get_noise_2d(center.x * 3.0, center.z * 3.0) > 0.3:
		color = COLOR_EARTH
	else:
		var shade := clampf(_detail_noise.get_noise_2d(center.x * 1.5, center.z * 1.5) * 0.5 + 0.5, 0.0, 1.0)
		color = COLOR_SNOW_SHADE.lerp(COLOR_SNOW, shade)
	# Leichte Variation pro Fläche betont die Facetten.
	var variation := rng.randf_range(-0.025, 0.025)
	return Color(color.r + variation, color.g + variation, color.b + variation)


func _build_ice() -> void:
	var center := Vector3(lake_center.x, ice_level, lake_center.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 20
	for i in segments:
		var p0 := center + Vector3(cos(TAU * i / segments), 0.0, sin(TAU * i / segments)) * lake_radius
		var p1 := center + Vector3(cos(TAU * (i + 1) / segments), 0.0, sin(TAU * (i + 1) / segments)) * lake_radius
		LowPolyBuilder.add_triangle_facing(st, center, p0, p1, Color.WHITE, Vector3.UP)

	var ice := MeshInstance3D.new()
	ice.name = "Ice"
	ice.mesh = st.commit()
	ice.material_override = ice_material
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(ice)

	var shape := CylinderShape3D.new()
	shape.radius = lake_radius * 0.95
	shape.height = 0.4
	var collision := CollisionShape3D.new()
	collision.name = "IceCollision"
	collision.shape = shape
	collision.position = center - Vector3(0.0, 0.2, 0.0)
	_add_generated(collision)


## Generierte Nodes haben keinen Owner und werden daher nie in die Szene gespeichert.
func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
