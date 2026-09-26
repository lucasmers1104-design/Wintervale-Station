@tool
## Einfacher Bahnsteig mit Rampen, Bank und Stationsschild.
##
## Wird komplett per Code erzeugt (auch im Editor sichtbar). Liegt entlang
## der Z-Achse; ein Gleis passt mit der Achse bei x = ±(Breite/2 + 1,7 m)
## an die Bahnsteigkante.
class_name RailwayPlatform
extends StaticBody3D

@export var length := 24.0
@export var width := 4.0
## Oberkante über dem Gelände – knapp unter der Schienenoberkante.
@export var height := 0.55
@export var station_name := "Wintervale"
@export var with_bench := true
@export var variation_seed := 3
@export var material: Material

@export_tool_button("Bahnsteig neu erzeugen", "Reload")
var rebuild_action: Callable = rebuild


func _ready() -> void:
	collision_layer = GameDefs.LAYER_OBJECTS
	rebuild()


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	var platform_mesh := StationMeshes.create_platform(length, width, height, rng)

	# Ausstattung auf der Rückseite (-X), Blick zur Gleisseite (+X)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(platform_mesh, 0, Transform3D.IDENTITY)
	var back_x := -width * 0.5 + 0.55
	var sign_z := length * 0.17
	var board_y := StationMeshes.add_sign(st, Vector3(back_x, height, sign_z), 2.2)
	if with_bench:
		StationMeshes.add_bench(st, Vector3(back_x + 0.1, height, -length * 0.17), rng)
	var mesh := st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	_add_generated(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = platform_mesh.create_trimesh_shape()
	_add_generated(collision)

	for facing in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = station_name
		label.font_size = 64
		label.pixel_size = 0.005
		label.modulate = Color(0.97, 0.93, 0.82)
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(back_x + facing * 0.04, height + board_y, sign_z)
		label.rotation.y = PI * 0.5 * facing
		_add_generated(label)


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
