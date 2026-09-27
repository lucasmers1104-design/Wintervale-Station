@tool
## Tunnelportal: Hier kommen Züge aus der Ferne an und verschwinden wieder.
##
## Das Gleis läuft vom Tunnelmund (Position dieses Nodes) [member tunnel_length]
## Meter in den Berg und endet dort. Züge erscheinen am Tunnelende und fahren
## aus der dunklen Röhre heraus – bzw. verschwinden, sobald sie ganz im Tunnel sind.
## Der Name (z.B. "Nordtal") wird im Fahrplan als Herkunft/Ziel verwendet.
## -Z dieses Nodes zeigt in den Tunnel hinein.
class_name TrainPortal
extends Node3D

const GROUP := &"train_portal"

@export var portal_name := "Nordtal"
@export var tunnel_length := 40.0
@export var material: Material
@export var variation_seed := 1

var _lamp: OmniLight3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PropScatter.GROUP_CLEARING)
	_build()
	if not Engine.is_editor_hint():
		WorldClock.darkness_changed.connect(_on_darkness_changed)
		_on_darkness_changed(WorldClock.is_dark())


## Punkt am Tunnelende (dort liegt das Gleisende).
func get_end_point() -> Vector3:
	return global_position - global_basis.z * tunnel_length


## Offenes Gleisende tief im Tunnel.
func get_end_node(network: RailNetwork) -> RailNode:
	return network.find_open_node_near(get_end_point(), 4.0)


## Das Gleis, das am Tunnelende beginnt.
func get_end_segment(network: RailNetwork) -> RailSegment:
	var node := get_end_node(network)
	if node == null or node.segment_ids.is_empty():
		return null
	return network.get_segment(node.segment_ids[0])


## Höhe an den Tunnelmund des Gleises anpassen.
func align_to_track(network: RailNetwork) -> void:
	var node := network.find_node_near(global_position, 4.0)
	if node:
		global_position.y = node.position.y


## Höhe des Berges über dem Tunnelmund an einer lokalen Stelle (-Z = in den Berg).
func get_mound_height(local_x: float, local_z: float) -> float:
	return TunnelMeshes.mound_height(local_x, local_z, tunnel_length, TunnelMeshes.mound_noise(_mound_seed()))


## Rodet Bäume und Steine rund um Portal und Berg (der Berg bringt eigene Tannen mit).
func clears(x: float, z: float) -> bool:
	var local := global_transform.affine_inverse() * Vector3(x, global_position.y, z)
	return absf(local.x) < 24.0 and local.z < 12.0 and local.z > -tunnel_length - 14.0


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	var portal_mesh := TunnelMeshes.create_portal(tunnel_length, rng)
	var mound_mesh := TunnelMeshes.create_mound(tunnel_length, _mound_seed())
	for mesh: ArrayMesh in [portal_mesh, mound_mesh]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		_add_generated(instance)
	_build_collision(portal_mesh, mound_mesh)
	_build_mound_trees(rng)
	# Felsbrocken am Fuß des Einschnitts
	for side: float in [-1.0, 1.0]:
		var rock := MeshInstance3D.new()
		rock.mesh = NatureMeshes.create_rock(rng)
		rock.material_override = material
		rock.position = Vector3(side * rng.randf_range(4.2, 4.5), 0.35, rng.randf_range(2.8, 4.2))
		rock.scale = Vector3.ONE * rng.randf_range(0.8, 1.0)
		_add_generated(rock)
	# Kleine Laterne über dem Tunnelmund
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0.0, TunnelMeshes.OPENING_HEIGHT + 0.9, 1.2)
	_lamp.light_color = Color(1.0, 0.74, 0.45)
	_lamp.omni_range = 9.0
	_lamp.light_energy = 0.0
	_add_generated(_lamp)
	var lamp_box := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.36, 0.3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.72, 0.4)
	glow.emission_energy_multiplier = 2.5
	box.material = glow
	lamp_box.mesh = box
	lamp_box.position = Vector3(0.0, TunnelMeshes.OPENING_HEIGHT + 0.6, 0.75)
	_add_generated(lamp_box)


## Berg und Mauer sind begehbar; eine unsichtbare Wand hält die Spielfigur aus der Röhre.
func _build_collision(portal_mesh: ArrayMesh, mound_mesh: ArrayMesh) -> void:
	var body := StaticBody3D.new()
	body.name = "PortalCollision"
	body.collision_layer = GameDefs.LAYER_WORLD
	body.collision_mask = 0
	for mesh in [portal_mesh, mound_mesh]:
		var shape := CollisionShape3D.new()
		shape.shape = (mesh as ArrayMesh).create_trimesh_shape()
		body.add_child(shape)
	var plug := CollisionShape3D.new()
	var plug_box := BoxShape3D.new()
	plug_box.size = Vector3(TunnelMeshes.OPENING_WIDTH, TunnelMeshes.OPENING_HEIGHT, 0.5)
	plug.shape = plug_box
	plug.position = Vector3(0.0, TunnelMeshes.OPENING_HEIGHT * 0.5, -3.0)
	body.add_child(plug)
	_add_generated(body)


## Ein paar verschneite Tannen auf dem Berg – nicht über der Röhre und nicht im Einschnitt.
func _build_mound_trees(rng: RandomNumberGenerator) -> void:
	var noise := TunnelMeshes.mound_noise(_mound_seed())
	var spots: Array[Vector2] = []
	var attempts := 0
	while spots.size() < 9 and attempts < 200:
		attempts += 1
		var spot := Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-tunnel_length - 4.0, 6.0))
		if absf(spot.x) < 9.0 and spot.y > -tunnel_length * 0.6:
			continue  # Hangkante und Blick auf das Portal frei halten
		if spot.y > -1.0 and absf(spot.x) < 12.0:
			continue
		var too_close := false
		for other in spots:
			if other.distance_to(spot) < 5.5:
				too_close = true
		if too_close:
			continue
		var height := TunnelMeshes.mound_height(spot.x, spot.y, tunnel_length, noise)
		var slope := absf(TunnelMeshes.mound_height(spot.x + 1.0, spot.y, tunnel_length, noise) - height) \
			+ absf(TunnelMeshes.mound_height(spot.x, spot.y + 1.0, tunnel_length, noise) - height)
		if height < 1.0 or slope > 1.1:
			continue
		spots.append(spot)
		var tree := MeshInstance3D.new()
		tree.mesh = NatureMeshes.create_pine(rng)
		tree.material_override = material
		tree.position = Vector3(spot.x, height - 0.45, spot.y)
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.15)
		_add_generated(tree)


func _mound_seed() -> int:
	return variation_seed * 7919 + 13


func _on_darkness_changed(dark: bool) -> void:
	if _lamp:
		_lamp.light_energy = 1.4 if dark else 0.0


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
