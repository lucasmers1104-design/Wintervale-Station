@tool
## Prozedurales Low-Poly-Terrain mit flacher Schattierung.
##
## Erzeugt aus Rauschen das Gelände, seine Kollision und einen zugefrorenen
## See. Die Kartenmitte bleibt bewusst flach – dort entstehen Bahnhof und
## Dorf. Am Rand rahmen Berge die Welt ein.
##
## Gleise formen das Gelände über [TerrainDeformer]: Das Terrain ist in
## Kacheln (Chunks) aufgeteilt, und nur die Kacheln, die ein Gleis berührt,
## werden neu gebaut – schnell genug für eine Live-Vorschau beim Bauen.
##
## Zwei Höhen:
## - [method get_base_height]: natürliches Gelände (Grundlage für die Gleisplanung)
## - [method get_height]: tatsächliches Gelände inkl. Gleisanpassungen
class_name LowPolyTerrain
extends StaticBody3D

## Gelände in [param region] (x/z-Rechteck) hat sich verändert.
signal terrain_changed(region: Rect2)

const COLOR_SNOW := Color(0.90, 0.93, 0.97)
const COLOR_SNOW_SHADE := Color(0.80, 0.85, 0.93)
const COLOR_TRACKSIDE := Color(0.80, 0.82, 0.87)
const COLOR_ROCK := Color(0.42, 0.43, 0.48)
const COLOR_ROCK_DARK := Color(0.31, 0.32, 0.37)
const COLOR_EARTH := Color(0.45, 0.39, 0.33)
const COLOR_LAKE_BED := Color(0.55, 0.63, 0.70)
## Zellen pro Kachel-Kante.
const CHUNK_CELLS := 16
## Korridor-ID der Bauvorschau.
const PREVIEW_ID := -1

## Gleicher Seed = gleiche Welt. Wichtig für Spielstände.
@export var terrain_seed := 1887
@export_range(16, 256, 16) var cells_per_side := 128
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
var _deformer := TerrainDeformer.new()

# Gitter: versetzte Punktpositionen, natürliche und angepasste Höhen
var _grid_xz := PackedVector2Array()
var _base_heights := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _weights := PackedFloat32Array()
var _chunk_meshes: Array[MeshInstance3D] = []
var _chunk_collisions: Array[CollisionShape3D] = []

# Ausstehende Neuberechnung (wird gebündelt am Frame-Ende ausgeführt)
var _dirty_region := Rect2()
var _has_dirty := false
var _dirty_collision := false
var _rebuild_queued := false


func _ready() -> void:
	generate()


## Baut Gitter, alle Kacheln, Kollision und Eisfläche komplett neu auf.
func generate() -> void:
	_setup_noise()
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	_chunk_meshes.clear()
	_chunk_collisions.clear()

	_build_grid()
	var chunks := get_chunks_per_side()
	for cz in chunks:
		for cx in chunks:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = "Chunk_%d_%d" % [cx, cz]
			mesh_instance.material_override = terrain_material
			_add_generated(mesh_instance)
			_chunk_meshes.append(mesh_instance)
			var collision := CollisionShape3D.new()
			collision.name = "ChunkCollision_%d_%d" % [cx, cz]
			_add_generated(collision)
			_chunk_collisions.append(collision)
			_rebuild_chunk(cz * chunks + cx, true)
	_build_ice()


# --- Höhenabfragen ---------------------------------------------------------------

## Tatsächliche Geländehöhe inklusive Gleisanpassungen.
func get_height(x: float, z: float) -> float:
	var base := get_base_height(x, z)
	if not _deformer.has_corridors():
		return base
	return _deformer.sample(x, z, base).x


## Natürliche Geländehöhe ohne Gleisanpassungen. Funktioniert schon vor generate().
func get_base_height(x: float, z: float) -> float:
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


## Wie stark ein Gleis das Gelände an (x, z) formt (0 = gar nicht, 1 = eingeebnet).
func get_track_influence(x: float, z: float) -> float:
	if not _deformer.has_corridors():
		return 0.0
	return _deformer.sample(x, z, get_base_height(x, z)).y


## Halbe Kantenlänge der Karte in Metern (die Karte reicht von -x bis +x).
func get_half_extent() -> float:
	return cells_per_side * cell_size * 0.5


func get_chunks_per_side() -> int:
	return maxi(1, ceili(float(cells_per_side) / CHUNK_CELLS))


func is_in_lake(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(lake_center) < lake_radius * 1.05


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


# --- Gleiskorridore ------------------------------------------------------------

## Formt das Gelände entlang eines Gleises. [param axis_points]: Gleisachse (x, Höhe, z).
func set_track_corridor(id: int, axis_points: PackedVector3Array) -> void:
	_mark_dirty(_deformer.set_corridor(id, axis_points), true)


func remove_track_corridor(id: int) -> void:
	_mark_dirty(_deformer.remove_corridor(id), true)


## Zeigt die Geländeanpassung eines geplanten Gleises (nur Optik, ohne Kollision).
## Leeres Array = Vorschau entfernen.
func set_preview_corridor(axis_points: PackedVector3Array) -> void:
	if axis_points.size() < 2:
		if _deformer.has_corridor(PREVIEW_ID):
			_mark_dirty(_deformer.remove_corridor(PREVIEW_ID), false)
		return
	_mark_dirty(_deformer.set_corridor(PREVIEW_ID, axis_points), false)


## Führt ausstehende Geländeänderungen sofort aus (sonst passiert das am Frame-Ende).
@warning_ignore("integer_division")
func flush_changes() -> void:
	_rebuild_queued = false
	if not _has_dirty or _grid_xz.is_empty():
		_has_dirty = false
		return
	var region := _dirty_region
	var with_collision := _dirty_collision
	_has_dirty = false
	_dirty_collision = false

	var n := cells_per_side
	var half := get_half_extent()
	var x0 := clampi(floori((region.position.x + half) / cell_size) - 1, 0, n)
	var x1 := clampi(ceili((region.end.x + half) / cell_size) + 1, 0, n)
	var z0 := clampi(floori((region.position.y + half) / cell_size) - 1, 0, n)
	var z1 := clampi(ceili((region.end.y + half) / cell_size) + 1, 0, n)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * (n + 1) + x
			var p := _grid_xz[i]
			var result := _deformer.sample(p.x, p.y, _base_heights[i])
			_heights[i] = result.x
			_weights[i] = result.y

	var chunks := get_chunks_per_side()
	for cz in range(clampi(z0 / CHUNK_CELLS, 0, chunks - 1), clampi(z1 / CHUNK_CELLS, 0, chunks - 1) + 1):
		for cx in range(clampi(x0 / CHUNK_CELLS, 0, chunks - 1), clampi(x1 / CHUNK_CELLS, 0, chunks - 1) + 1):
			_rebuild_chunk(cz * chunks + cx, with_collision)
	terrain_changed.emit(region)


func _mark_dirty(region: Rect2, with_collision: bool) -> void:
	if region.size == Vector2.ZERO:
		return
	_dirty_region = region if not _has_dirty else _dirty_region.merge(region)
	_has_dirty = true
	_dirty_collision = _dirty_collision or with_collision
	if not _rebuild_queued:
		_rebuild_queued = true
		flush_changes.call_deferred()


# --- Aufbau --------------------------------------------------------------------

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


## Gitterpunkte (Randpunkte bleiben gerade, damit die Kante sauber ist).
func _build_grid() -> void:
	var n := cells_per_side
	var half := get_half_extent()
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	var count := (n + 1) * (n + 1)
	_grid_xz.resize(count)
	_base_heights.resize(count)
	_heights.resize(count)
	_weights.resize(count)
	for z in n + 1:
		for x in n + 1:
			var px := x * cell_size - half
			var pz := z * cell_size - half
			if x > 0 and x < n and z > 0 and z < n:
				px += rng.randf_range(-vertex_jitter, vertex_jitter) * cell_size
				pz += rng.randf_range(-vertex_jitter, vertex_jitter) * cell_size
			var i := z * (n + 1) + x
			_grid_xz[i] = Vector2(px, pz)
			_base_heights[i] = get_base_height(px, pz)
			var result := _deformer.sample(px, pz, _base_heights[i])
			_heights[i] = result.x
			_weights[i] = result.y


@warning_ignore("integer_division")
func _rebuild_chunk(index: int, with_collision: bool) -> void:
	var n := cells_per_side
	var chunks := get_chunks_per_side()
	var cx := index % chunks
	var cz := index / chunks
	var x_start := cx * CHUNK_CELLS
	var z_start := cz * CHUNK_CELLS
	var x_end := mini(x_start + CHUNK_CELLS, n)
	var z_end := mini(z_start + CHUNK_CELLS, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed * 31 + index

	# Direkt in Arrays schreiben – deutlich schneller als SurfaceTool (wichtig für die Live-Vorschau).
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var triangle_count := (x_end - x_start) * (z_end - z_start) * 2
	vertices.resize(triangle_count * 3)
	normals.resize(triangle_count * 3)
	colors.resize(triangle_count * 3)
	var cursor := 0
	for z in range(z_start, z_end):
		for x in range(x_start, x_end):
			var ia := z * (n + 1) + x
			var ib := ia + 1
			var ic := ia + n + 1
			var id := ic + 1
			# Wechselnde Diagonalen vermeiden sichtbare Streifenmuster.
			if (x + z) % 2 == 0:
				cursor = _write_triangle(vertices, normals, colors, cursor, ia, ib, id, rng)
				cursor = _write_triangle(vertices, normals, colors, cursor, ia, id, ic, rng)
			else:
				cursor = _write_triangle(vertices, normals, colors, cursor, ia, ib, ic, rng)
				cursor = _write_triangle(vertices, normals, colors, cursor, ib, id, ic, rng)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_chunk_meshes[index].mesh = mesh
	if with_collision:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(vertices)
		_chunk_collisions[index].shape = shape


func _vertex(i: int) -> Vector3:
	return Vector3(_grid_xz[i].x, _heights[i], _grid_xz[i].y)


## Schreibt ein flach schattiertes Dreieck (Vorderseite nach oben) in die Arrays.
func _write_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		cursor: int, ia: int, ib: int, ic: int, rng: RandomNumberGenerator) -> int:
	var a := _vertex(ia)
	var b := _vertex(ib)
	var c := _vertex(ic)
	var normal := LowPolyBuilder.face_normal(a, b, c)
	if normal.y < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	var influence := (_weights[ia] + _weights[ib] + _weights[ic]) / 3.0
	var color := _terrain_color((a + b + c) / 3.0, normal, influence, rng)
	vertices[cursor] = a
	vertices[cursor + 1] = b
	vertices[cursor + 2] = c
	for k in 3:
		normals[cursor + k] = normal
		colors[cursor + k] = color
	return cursor + 3


func _terrain_color(center: Vector3, normal: Vector3, influence: float, rng: RandomNumberGenerator) -> Color:
	var slope := 1.0 - normal.y
	var color: Color
	if center.y < ice_level + 0.1 and is_in_lake(center.x, center.z):
		color = COLOR_LAKE_BED
	elif influence > 0.85:
		# Festgetretener Schnee neben den Gleisen
		color = COLOR_TRACKSIDE
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
