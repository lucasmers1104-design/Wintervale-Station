@tool
## Verteilt prozedurale Tannen und Steine auf dem Terrain.
##
## Nutzt MultiMeshes (ein Draw-Call pro Variante), damit auch viele
## Objekte performant bleiben. Die Kartenmitte und der See bleiben frei.
## Gleicher Seed = gleiche Verteilung.
class_name PropScatter
extends Node3D

@export var terrain: LowPolyTerrain
@export var prop_material: Material
@export var scatter_seed := 7

@export_group("Anzahl")
@export_range(0, 2000) var tree_count := 320
@export_range(0, 1000) var rock_count := 110
@export_range(1, 8) var tree_variants := 4
@export_range(1, 8) var rock_variants := 3

@export_group("Platzierung")
## Radius um die Kartenmitte, der frei bleibt (Platz für Bahnhof & Dorf).
@export var clear_radius := 20.0
## Anteil der Karte (vom Rand gemessen), der bepflanzt werden darf.
@export_range(0.1, 1.0) var coverage := 0.92
## Bis zu welchem Anteil der Berghöhe noch Bäume wachsen.
@export_range(0.0, 1.0) var tree_line := 0.7

@export_tool_button("Neu verteilen", "Reload")
var rescatter_action: Callable = scatter

## Nodes dieser Gruppe roden Natur in ihrer Umgebung (Methode clears(x, z) -> bool).
const GROUP_CLEARING := &"prop_clearing"
## Ab diesem Einfluss einer Gleistrasse wird gerodet.
const CLEARING_INFLUENCE := 0.2

## Jede Instanz: {"key", "index", "xform", "xz", "sink", "collider", "lift", "cleared"} – damit
## Bäume und Steine der Geländeanpassung folgen können.
var _records: Array[Dictionary] = []
var _multimeshes: Dictionary[String, MultiMesh] = {}


func _ready() -> void:
	scatter()
	if terrain and not terrain.terrain_changed.is_connected(_on_terrain_changed):
		terrain.terrain_changed.connect(_on_terrain_changed)


func scatter() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_records.clear()
	_multimeshes.clear()
	if terrain == null:
		push_warning("PropScatter: Kein Terrain zugewiesen.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = scatter_seed
	forest_noise.frequency = 0.02

	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	colliders.collision_layer = GameDefs.LAYER_NATURE
	add_child(colliders)

	_scatter_trees(rng, forest_noise, colliders)
	_scatter_rocks(rng, colliders)


func _scatter_trees(rng: RandomNumberGenerator, forest_noise: FastNoiseLite, colliders: StaticBody3D) -> void:
	var meshes: Array[Mesh] = []
	for i in tree_variants:
		meshes.append(NatureMeshes.create_pine(rng))
	var transforms := _empty_lists(meshes.size())
	var limit := terrain.get_half_extent() * coverage

	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < tree_count * 25:
		attempts += 1
		var x := rng.randf_range(-limit, limit)
		var z := rng.randf_range(-limit, limit)
		if not _is_free_spot(x, z):
			continue
		# Waldflecken statt gleichmäßiger Verteilung
		var forest := forest_noise.get_noise_2d(x, z) * 0.5 + 0.5
		if rng.randf() > forest * forest * 1.6 + 0.04:
			continue
		var y := terrain.get_height(x, z)
		if y > terrain.mountain_height * tree_line:
			continue

		var s := rng.randf_range(0.75, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		var variant := rng.randi() % meshes.size()
		transforms[variant].append(Transform3D(basis, Vector3(x, y - 0.15, z)))

		var shape := CylinderShape3D.new()
		shape.radius = 0.3 * s
		shape.height = 3.0 * s
		var collider := _add_collider(colliders, shape, Vector3(x, y + 1.5 * s, z))
		_record("Trees%d" % variant, transforms[variant], -0.15, collider, 1.5 * s)
		placed += 1

	_create_multimeshes("Trees", meshes, transforms)


func _scatter_rocks(rng: RandomNumberGenerator, colliders: StaticBody3D) -> void:
	var meshes: Array[Mesh] = []
	for i in rock_variants:
		meshes.append(NatureMeshes.create_rock(rng))
	var transforms := _empty_lists(meshes.size())
	var limit := terrain.get_half_extent() * coverage

	var placed := 0
	var attempts := 0
	while placed < rock_count and attempts < rock_count * 25:
		attempts += 1
		var x := rng.randf_range(-limit, limit)
		var z := rng.randf_range(-limit, limit)
		if not _is_free_spot(x, z):
			continue
		var y := terrain.get_height(x, z)
		var s := rng.randf_range(0.35, 1.6)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
		var variant := rng.randi() % meshes.size()
		transforms[variant].append(Transform3D(basis.scaled(Vector3.ONE * s), Vector3(x, y - 0.2 * s, z)))

		var shape := SphereShape3D.new()
		shape.radius = 0.75 * s
		var collider := _add_collider(colliders, shape, Vector3(x, y, z))
		_record("Rocks%d" % variant, transforms[variant], -0.2 * s, collider, 0.0)
		placed += 1

	_create_multimeshes("Rocks", meshes, transforms)


func _is_free_spot(x: float, z: float) -> bool:
	return Vector2(x, z).length() >= clear_radius and not terrain.is_in_lake(x, z)


func _create_multimeshes(prefix: String, meshes: Array[Mesh], transforms: Array[Array]) -> void:
	for i in meshes.size():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[i]
		multimesh.instance_count = transforms[i].size()
		for j in transforms[i].size():
			multimesh.set_instance_transform(j, transforms[i][j])

		var instance := MultiMeshInstance3D.new()
		instance.name = "%s%d" % [prefix, i]
		instance.multimesh = multimesh
		instance.material_override = prop_material
		add_child(instance)
		_multimeshes[String(instance.name)] = multimesh


func _add_collider(body: StaticBody3D, shape: Shape3D, pos: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	body.add_child(collision)
	return collision


## Merkt sich die zuletzt hinzugefügte Instanz einer Variante (Transformation
## wird hier gespeichert, weil MultiMeshes sie nicht überall zurückliefern).
func _record(key: String, variant_transforms: Array, sink: float, collider: CollisionShape3D, lift: float) -> void:
	var xform: Transform3D = variant_transforms[-1]
	_records.append({"key": key, "index": variant_transforms.size() - 1, "xform": xform,
		"xz": Vector2(xform.origin.x, xform.origin.z), "sink": sink, "collider": collider, "lift": lift})


## Gelände hat sich verändert (z.B. durch ein Gleis): betroffene Bäume und
## Steine auf die neue Bodenhöhe setzen, damit nichts schwebt oder versinkt.
## Auf Gleistrassen und an Tunnelportalen werden sie gerodet (ausgeblendet) –
## wird das Gleis wieder entfernt, wachsen sie zurück.
func _on_terrain_changed(region: Rect2) -> void:
	var area := region.grow(1.0)
	var clearings: Array = get_tree().get_nodes_in_group(GROUP_CLEARING) if is_inside_tree() else []
	for record in _records:
		var xz: Vector2 = record["xz"]
		if not area.has_point(xz):
			continue
		var ground := terrain.get_height(xz.x, xz.y)
		var xform: Transform3D = record["xform"]
		xform.origin.y = ground + float(record["sink"])
		record["xform"] = xform
		var cleared := terrain.get_track_influence(xz.x, xz.y) > CLEARING_INFLUENCE
		for clearing in clearings:
			if clearing.has_method("clears") and clearing.clears(xz.x, xz.y):
				cleared = true
		record["cleared"] = cleared
		var shown := xform if not cleared else Transform3D(Basis().scaled(Vector3.ZERO), xform.origin)
		_multimeshes[record["key"]].set_instance_transform(record["index"], shown)
		var collider: CollisionShape3D = record["collider"]
		collider.position.y = ground + float(record["lift"])
		collider.disabled = cleared


## Prüft alle Bäume und Steine erneut (z.B. nachdem ein Tunnelportal platziert wurde).
func refresh_clearings() -> void:
	var half := terrain.get_half_extent() if terrain else 0.0
	_on_terrain_changed(Rect2(-half, -half, half * 2.0, half * 2.0))


## Anzahl gerodeter Bäume und Steine (für Tests).
func get_cleared_count() -> int:
	var count := 0
	for record in _records:
		if record.get("cleared", false):
			count += 1
	return count


## Abstand jeder Instanz zum Boden (0 = sitzt korrekt) – für Tests.
func get_instance_ground_errors() -> PackedFloat32Array:
	var errors := PackedFloat32Array()
	for record in _records:
		var xz: Vector2 = record["xz"]
		var xform: Transform3D = record["xform"]
		errors.append(xform.origin.y - float(record["sink"]) - terrain.get_height(xz.x, xz.y))
	return errors


func _empty_lists(count: int) -> Array[Array]:
	var lists: Array[Array] = []
	for i in count:
		lists.append([])
	return lists


## Rodung in einem Bereich neu prüfen (z.B. nachdem im Dorf etwas gebaut wurde).
func refresh_area(region: Rect2) -> void:
	_on_terrain_changed(region)
