@tool
## Wohnhaus eines Bewohners – vorläufig ein Platzhalter: Gartentor mit
## Briefkasten, Namensschild und einer kleinen Lampe, die abends leuchtet.
## Wer heimgeht, verschwindet hinter dem Tor. Echte Häuser folgen in einer
## späteren Etappe; dann ersetzt das Haus diesen Platzhalter (gleicher Name).
##
## -Z zeigt vom Tor zur Straße (dort kommt der Bewohner heraus).
class_name NpcHome
extends Node3D

const GROUP := &"npc_home"
const WOOD := Color(0.52, 0.34, 0.2)
const WOOD_DARK := Color(0.4, 0.26, 0.16)
const SNOW := Color(0.9, 0.93, 0.97, 0.5)
const MAILBOX := Color(0.72, 0.22, 0.18)
const IRON := Color(0.18, 0.18, 0.2)

@export var home_name := "Berger":
	set(value):
		home_name = value
		if is_node_ready():
			_build()
@export var material: Material

var _lamp: OmniLight3D
var _glow: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PropScatter.GROUP_CLEARING)
	_build()
	if not Engine.is_editor_hint():
		WorldClock.darkness_changed.connect(_on_darkness_changed)
		_on_darkness_changed(WorldClock.is_dark())


## Vor dem Tor (auf dem Weg).
func get_front_point() -> Vector3:
	return global_position - global_basis.z * 1.2


## Hinter dem Tor – hier ist der Bewohner "im Haus".
func get_inside_point() -> Vector3:
	return global_position + global_basis.z * 1.4


## Keine Bäume im Vorgarten.
func clears(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(Vector2(global_position.x, global_position.z)) < 4.0


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Zaunstück links und rechts vom Tor
	for side: float in [-1.0, 1.0]:
		LowPolyBuilder.add_box(st, Vector3(side * 0.75, 0.6, 0.0), Vector3(0.14, 1.2, 0.14), WOOD_DARK)
		LowPolyBuilder.add_box(st, Vector3(side * 0.75, 1.23, 0.0), Vector3(0.2, 0.06, 0.2), SNOW)
		for i in 4:
			var x := side * (1.05 + i * 0.3)
			LowPolyBuilder.add_box(st, Vector3(x, 0.42, 0.0), Vector3(0.09, 0.84 - i * 0.06, 0.05), WOOD)
			LowPolyBuilder.add_box(st, Vector3(x, 0.86 - i * 0.03, 0.0), Vector3(0.1, 0.04, 0.07), SNOW)
		for y: float in [0.28, 0.62]:
			LowPolyBuilder.add_box(st, Vector3(side * 1.5, y, 0.03), Vector3(1.4, 0.07, 0.03), WOOD_DARK)
	# Torbogen mit Schnee und das halb offene Tor
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.32, 0.0), Vector3(1.7, 0.12, 0.16), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(0.0, 1.41, 0.0), Vector3(1.72, 0.06, 0.22), SNOW)
	var gate := Transform3D(Basis(Vector3.UP, -1.1), Vector3(-0.68, 0.0, 0.0))
	for i in 4:
		LowPolyBuilder.add_oriented_box(st, gate.translated_local(Vector3(0.12 + i * 0.18, 0.5, 0.0)),
			Vector3(0.09, 0.8, 0.04), WOOD)
	LowPolyBuilder.add_oriented_box(st, gate.translated_local(Vector3(0.39, 0.62, 0.03)), Vector3(0.66, 0.07, 0.03), WOOD_DARK)
	# Briefkasten auf einem Pfosten
	LowPolyBuilder.add_box(st, Vector3(1.05, 0.55, -0.35), Vector3(0.08, 1.1, 0.08), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(1.05, 1.18, -0.35), Vector3(0.26, 0.24, 0.4), MAILBOX)
	LowPolyBuilder.add_box(st, Vector3(1.05, 1.32, -0.35), Vector3(0.28, 0.05, 0.42), SNOW)
	# Laterne am Torpfosten
	LowPolyBuilder.add_box(st, Vector3(0.75, 1.36, -0.12), Vector3(0.05, 0.05, 0.2), IRON)
	LowPolyBuilder.add_box(st, Vector3(0.75, 1.46, -0.22), Vector3(0.16, 0.04, 0.16), IRON)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = material
	_add_generated(mesh_instance)

	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(1.0, 0.86, 0.6)
	_glow.emission_enabled = true
	_glow.emission = Color(1.0, 0.7, 0.38)
	_glow.emission_energy_multiplier = 0.2
	var bulb := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.14, 0.11)
	box.material = _glow
	bulb.mesh = box
	bulb.position = Vector3(0.75, 1.37, -0.22)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(bulb)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0.75, 1.3, -0.45)
	_lamp.light_color = Color(1.0, 0.72, 0.42)
	_lamp.omni_range = 5.0
	_lamp.light_energy = 0.0
	_add_generated(_lamp)

	var label := Label3D.new()
	label.text = home_name
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(0.98, 0.93, 0.82)
	label.outline_size = 0
	label.position = Vector3(1.05, 1.18, -0.556)
	label.rotation.y = PI
	label.double_sided = false
	_add_generated(label)

	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	for x: float in [-0.75, 0.75, 1.05]:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.2, 1.3, 0.2)
		shape.shape = box_shape
		shape.position = Vector3(x, 0.65, -0.35 if x > 1.0 else 0.0)
		body.add_child(shape)
	_add_generated(body)


func _on_darkness_changed(dark: bool) -> void:
	if _lamp:
		_lamp.light_energy = 0.9 if dark else 0.0
	if _glow:
		_glow.emission_energy_multiplier = 2.4 if dark else 0.2


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
