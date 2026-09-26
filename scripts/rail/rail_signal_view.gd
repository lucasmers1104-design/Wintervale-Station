## Sichtbares Hauptsignal mit Mast, Schirm und zwei Lampen (grün oben, rot unten).
## Beim Wechsel des Signalbilds blenden die Lampen weich über.
class_name RailSignalView
extends StaticBody3D

const LAMP_ON := 5.0
const LAMP_OFF := 0.0
const FADE_TIME := 0.25

var signal_id := -1

var _red: StandardMaterial3D
var _green: StandardMaterial3D
var _glow: OmniLight3D
var _meshes: Array[MeshInstance3D] = []
var _materials: Array[Material] = []
var _aspect := -1
var _tween: Tween


func build(rail_signal: RailSignal, xform: Transform3D, material: Material) -> void:
	signal_id = rail_signal.id
	name = "Signal%d" % signal_id
	transform = xform
	collision_layer = GameDefs.LAYER_OBJECTS
	collision_mask = 0

	var mast := MeshInstance3D.new()
	mast.mesh = RailMeshes.create_signal_mast()
	mast.material_override = material
	add_child(mast)
	_meshes.append(mast)
	_materials.append(material)

	_green = _lamp_material(Color(0.25, 1.0, 0.45))
	_red = _lamp_material(Color(1.0, 0.18, 0.12))
	_add_lamp(RailMeshes.SIGNAL_GREEN_Y, _green)
	_add_lamp(RailMeshes.SIGNAL_RED_Y, _red)

	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.0, (RailMeshes.SIGNAL_GREEN_Y + RailMeshes.SIGNAL_RED_Y) * 0.5, -0.5)
	_glow.omni_range = 3.5
	_glow.light_energy = 0.6
	_glow.shadow_enabled = false
	add_child(_glow)

	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 4.0, 0.6)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 2.0, 0.0)
	add_child(collision)

	set_aspect(rail_signal.aspect, false)


func set_aspect(aspect: RailSignal.Aspect, animate := true) -> void:
	if aspect == _aspect:
		return
	_aspect = aspect
	var clear := aspect == RailSignal.Aspect.CLEAR
	var green_target := LAMP_ON if clear else LAMP_OFF
	var red_target := LAMP_OFF if clear else LAMP_ON
	_glow.light_color = Color(0.3, 1.0, 0.5) if clear else Color(1.0, 0.25, 0.15)
	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate:
		_green.emission_energy_multiplier = green_target
		_red.emission_energy_multiplier = red_target
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_green, "emission_energy_multiplier", green_target, FADE_TIME)
	_tween.tween_property(_red, "emission_energy_multiplier", red_target, FADE_TIME)


func get_aspect() -> int:
	return _aspect


## Überlagert das Signal mit einem Hervorhebungs-Material (null = normal).
func set_highlight(material: Material) -> void:
	for i in _meshes.size():
		_meshes[i].material_override = material if material else _materials[i]


func _add_lamp(height: float, material: StandardMaterial3D) -> void:
	var lamp_mesh := CylinderMesh.new()
	lamp_mesh.top_radius = 0.085
	lamp_mesh.bottom_radius = 0.085
	lamp_mesh.height = 0.04
	lamp_mesh.radial_segments = 12
	lamp_mesh.rings = 0
	var lamp := MeshInstance3D.new()
	lamp.mesh = lamp_mesh
	lamp.material_override = material
	lamp.rotation.x = PI * 0.5
	lamp.position = Vector3(0.0, height, RailMeshes.SIGNAL_LAMP_Z)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	_meshes.append(lamp)
	_materials.append(material)


func _lamp_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.7)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0
	material.roughness = 0.3
	return material
