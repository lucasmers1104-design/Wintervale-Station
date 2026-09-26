@tool
## Knuffige Spielzeug-Figur im Stil der Dorfbewohner: großer runder Kopf,
## Mütze, Karohemd und kurze Beinchen (ca. 1,45 m groß).
##
## Das Modell wird aus einer [CharacterAppearance] per Code gebaut – so
## sehen Spieler und alle späteren Bewohner einheitlich aus, aber jede Figur
## kann eigene Farben, Mütze, Frisur und Brille haben.
## Animationen laufen prozedural über [method animate].
class_name CharacterModel
extends Node3D

const PLAID_SHADER := preload("res://assets/materials/plaid.gdshader")
## Augenhöhe über den Füßen (für die Ich-Perspektive).
const EYE_HEIGHT := 1.16

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			rebuild()

var _body: Node3D
var _head: Node3D
var _hip_left: Node3D
var _hip_right: Node3D
var _shoulder_left: Node3D
var _shoulder_right: Node3D
var _meshes: Array[MeshInstance3D] = []
var _shadows_only := false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_meshes.clear()

	var look := appearance if appearance else CharacterAppearance.new()
	var skin := _material(look.skin_color, 0.7)
	var plaid := _plaid_material(look)
	var pants := _material(look.pants_color, 0.9)
	var shoes := _material(look.shoe_color, 0.6)

	_body = _pivot(self, "Body", Vector3.ZERO)

	# Beine mit Schuhen
	_hip_left = _pivot(_body, "HipLeft", Vector3(-0.11, 0.26, 0.0))
	_hip_right = _pivot(_body, "HipRight", Vector3(0.11, 0.26, 0.0))
	for hip in [_hip_left, _hip_right]:
		_part(hip, _cylinder(0.085, 0.09, 0.2), pants, Vector3(0.0, -0.1, 0.0))
		_part(hip, _sphere(0.1, 14, 7), shoes, Vector3(0.0, -0.2, -0.03), Vector3(1.0, 0.6, 1.3))

	# Rumpf im Karohemd, darunter die Hose
	_part(_body, _capsule(0.28, 0.66), plaid, Vector3(0.0, 0.56, 0.0), Vector3(1.0, 1.0, 0.9))
	_part(_body, _cylinder(0.25, 0.27, 0.14), pants, Vector3(0.0, 0.3, 0.0))

	# Arme mit Händen, leicht abgespreizt
	_shoulder_left = _pivot(_body, "ShoulderLeft", Vector3(-0.27, 0.8, 0.0))
	_shoulder_left.rotation.z = -0.3
	_shoulder_right = _pivot(_body, "ShoulderRight", Vector3(0.27, 0.8, 0.0))
	_shoulder_right.rotation.z = 0.3
	for shoulder in [_shoulder_left, _shoulder_right]:
		_part(shoulder, _capsule(0.075, 0.34, 12, 4), plaid, Vector3(0.0, -0.13, 0.0))
		_part(shoulder, _sphere(0.075, 12, 6), skin, Vector3(0.0, -0.31, 0.0))

	_build_head(look, skin)
	set_shadows_only(_shadows_only)


## Prozedurale Laufanimation. [param amount] 0 = Stehen, 1 = Gehen.
func animate(amount: float, phase: float) -> void:
	if _body == null:
		return
	var swing := sin(phase) * 0.6 * amount
	_hip_left.rotation.x = swing
	_hip_right.rotation.x = -swing
	_shoulder_left.rotation.x = -swing * 0.8
	_shoulder_right.rotation.x = swing * 0.8
	_body.position.y = absf(sin(phase)) * 0.035 * amount
	_body.rotation.z = sin(phase) * 0.05 * amount


## Unsichtbar, aber mit Schatten (für die Ich-Perspektive).
func set_shadows_only(enabled: bool) -> void:
	_shadows_only = enabled
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in _meshes:
		mesh.cast_shadow = mode


func get_mesh_count() -> int:
	return _meshes.size()


func _build_head(look: CharacterAppearance, skin: Material) -> void:
	_head = _pivot(_body, "Head", Vector3(0.0, 1.13, 0.0))
	_part(_head, _sphere(0.3, 28, 14), skin, Vector3.ZERO, Vector3(1.0, 0.95, 1.0))

	# Gesicht: Knopfaugen, Nase, rosige Wangen
	var eyes := _material(Color(0.07, 0.06, 0.06), 0.25)
	for x in [-0.1, 0.1]:
		_part(_head, _sphere(0.03, 10, 5), eyes, Vector3(x, 0.03, -0.272))
	_part(_head, _sphere(0.05, 12, 6), _material(look.skin_color.darkened(0.08), 0.7), Vector3(0.0, -0.04, -0.29))
	var blush := _material(look.skin_color.lerp(Color(0.95, 0.45, 0.45), 0.3), 0.8)
	for x in [-0.17, 0.17]:
		_part(_head, _sphere(0.05, 10, 5), blush, Vector3(x, -0.06, -0.24), Vector3(1.0, 0.6, 0.45))

	# Haare
	var hair := _material(look.hair_color, 0.9)
	match look.hair_style:
		CharacterAppearance.HairStyle.SHORT:
			var cap := _part(_head, _sphere(0.31, 24, 12, true), hair, Vector3(0.0, 0.03, 0.02))
			cap.rotation.x = -0.35
		CharacterAppearance.HairStyle.SIDES:
			for x in [-0.27, 0.27]:
				_part(_head, _sphere(0.13, 12, 6), hair, Vector3(x, 0.02, 0.05), Vector3(0.55, 0.9, 1.2))

	# Strickmütze mit Umschlag
	if look.hat_style == CharacterAppearance.HatStyle.BEANIE:
		var hat := _material(look.hat_color, 1.0)
		_part(_head, _sphere(0.315, 24, 12, true), hat, Vector3(0.0, 0.08, 0.0), Vector3(1.0, 0.95, 1.0))
		_part(_head, _cylinder(0.318, 0.322, 0.1, 24), _material(look.hat_color.darkened(0.12), 1.0), Vector3(0.0, 0.13, 0.0))

	# Brille
	if look.glasses:
		var frame := _material(look.glasses_color, 0.4)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.048
		ring.outer_radius = 0.062
		ring.rings = 16
		ring.ring_segments = 6
		for x in [-0.1, 0.1]:
			var lens := _part(_head, ring, frame, Vector3(x, 0.03, -0.29))
			lens.rotation.x = PI * 0.5
		var bridge := BoxMesh.new()
		bridge.size = Vector3(0.075, 0.014, 0.014)
		_part(_head, bridge, frame, Vector3(0.0, 0.04, -0.3))


# --- Bausteine ------------------------------------------------------------------

func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, part_scale := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.scale = part_scale
	parent.add_child(instance)
	_meshes.append(instance)
	return instance


func _sphere(radius: float, segments: int, rings: int, hemisphere := false) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * (1.0 if hemisphere else 2.0)
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.is_hemisphere = hemisphere
	return mesh


func _cylinder(top: float, bottom: float, height: float, segments := 14) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _capsule(radius: float, height: float, segments := 20, rings := 6) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _plaid_material(look: CharacterAppearance) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLAID_SHADER
	material.set_shader_parameter(&"base_color", look.shirt_color)
	material.set_shader_parameter(&"stripe_color", look.shirt_stripe_color)
	material.set_shader_parameter(&"line_color", look.shirt_line_color)
	return material
