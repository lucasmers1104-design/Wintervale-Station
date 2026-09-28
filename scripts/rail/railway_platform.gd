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
@export_group("Bahnsteigdach")
## Länge des Dachs in der Bahnsteigmitte (0 = kein Dach).
@export var canopy_length := 0.0
@export var canopy_height := 3.5
## Helligkeit der warmen Hängelampen bei Nacht.
@export var lamp_energy := 1.3

var _lamp_lights: Array[OmniLight3D] = []
var _lamp_glow: StandardMaterial3D

@export_tool_button("Bahnsteig neu erzeugen", "Reload")
var rebuild_action: Callable = rebuild


func _ready() -> void:
	collision_layer = GameDefs.LAYER_OBJECTS
	rebuild()
	if not Engine.is_editor_hint():
		WorldClock.darkness_changed.connect(_set_lamps)
		_set_lamps(WorldClock.is_dark())


## Hängelampen am Bahnsteigdach ein-/ausschalten.
func _set_lamps(on: bool) -> void:
	for light in _lamp_lights:
		light.light_energy = lamp_energy if on else 0.0
	if _lamp_glow:
		_lamp_glow.emission_energy_multiplier = 2.0 if on else 0.3


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
	var lamps: Array[Vector3] = []
	if canopy_length > 0.0:
		lamps = StationMeshes.add_canopy(st, Vector3(0.0, height, 0.0), canopy_length, width + 0.6, canopy_height, rng)
	var mesh := st.commit()

	_lamp_lights.clear()
	_lamp_glow = StandardMaterial3D.new()
	_lamp_glow.albedo_color = Color(1.0, 0.86, 0.62)
	_lamp_glow.emission_enabled = true
	_lamp_glow.emission = Color(1.0, 0.72, 0.4)
	_lamp_glow.emission_energy_multiplier = 0.3
	for i in lamps.size():
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.material = _lamp_glow
		bulb.mesh = sphere
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.position = lamps[i] - Vector3(0.0, 0.06, 0.0)
		_add_generated(bulb)
		# Nur jede zweite Lampe bekommt ein echtes Licht (sparsam, wirkt trotzdem warm)
		if i % 2 == 0:
			var light := OmniLight3D.new()
			light.position = lamps[i] - Vector3(0.0, 0.25, 0.0)
			light.light_color = Color(1.0, 0.74, 0.45)
			light.omni_range = 6.5
			light.light_energy = 0.0
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 70.0
			light.distance_fade_length = 20.0
			_add_generated(light)
			_lamp_lights.append(light)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	_add_generated(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
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
