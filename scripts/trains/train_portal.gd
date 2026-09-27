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


## Rodet Bäume und Steine rund um Portal und Hügel.
func clears(x: float, z: float) -> bool:
	var local := global_transform.affine_inverse() * Vector3(x, global_position.y, z)
	return absf(local.x) < 18.0 and local.z < 6.0 and local.z > -tunnel_length - 8.0


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	for mesh in [TunnelMeshes.create_portal(tunnel_length, rng), TunnelMeshes.create_mound(tunnel_length, rng)]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		_add_generated(instance)
	# Felsbrocken an den Seiten
	for side in [-1.0, 1.0]:
		var rock := MeshInstance3D.new()
		rock.mesh = NatureMeshes.create_rock(rng)
		rock.material_override = material
		rock.position = Vector3(side * rng.randf_range(8.0, 10.0), 0.2, rng.randf_range(0.5, 2.5))
		rock.scale = Vector3.ONE * rng.randf_range(1.2, 1.8)
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


func _on_darkness_changed(dark: bool) -> void:
	if _lamp:
		_lamp.light_energy = 1.4 if dark else 0.0


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
