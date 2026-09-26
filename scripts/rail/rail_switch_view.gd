## Sichtbare Weiche: bewegliche Weichenzungen, Stellstange, Weichenantrieb
## und eine Weichenlaterne. Beim Umstellen gleiten die Zungen hinüber und die
## Laterne dreht sich (Stellanimation).
##
## Lokal: -Z zeigt entlang der Weichenäste, der Ursprung ist der Weichenanfang.
class_name RailSwitchView
extends Node3D

const ANIMATION_TIME := 0.7
## Seitlicher Weg der Zungenspitzen beim Umstellen.
const THROW := 0.12
## Abstand der anliegenden Zungenspitze zur Schienenmitte.
const CLOSED_OFFSET := 0.045
const HEEL_OFFSET := 0.07

var node_id := -1

var _blades: Array[Node3D] = []
var _tie_bar: Node3D
var _lantern: Node3D
var _lamp_material: StandardMaterial3D
var _diverging_side := 1.0
var _tween: Tween


func build(switch: RailSwitch, network: RailNetwork, material: Material) -> void:
	node_id = switch.node_id
	name = "Switch%d" % node_id
	_diverging_side = switch.diverging_side
	var node := network.get_rail_node(node_id)
	var axis := network.get_segment(switch.branch_segment_ids[0]).get_direction_away_from(node_id)
	transform = Transform3D(Basis.looking_at(axis, Vector3.UP), node.position)

	var blade_mesh := RailMeshes.create_switch_blade()
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * (RailConfig.RAIL_OFFSET - HEEL_OFFSET), RailConfig.RAIL_BASE, -RailMeshes.BLADE_LENGTH)
		add_child(pivot)
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.material_override = material
		pivot.add_child(blade)
		_blades.append(pivot)

	# Stellstange quer unter den Zungenspitzen und Weichenantrieb auf der ruhigen Seite
	var motor_side := -_diverging_side
	var steel := StandardMaterial3D.new()
	steel.albedo_color = RailMeshes.IRON_DARK
	steel.roughness = 0.5
	steel.metallic = 0.4
	_tie_bar = Node3D.new()
	_tie_bar.position = Vector3(0.0, RailConfig.RAIL_BASE + 0.03, -0.35)
	add_child(_tie_bar)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.5, 0.05, 0.08)
	bar.mesh = bar_mesh
	bar.material_override = steel
	_tie_bar.add_child(bar)
	var rod := MeshInstance3D.new()
	var rod_mesh := BoxMesh.new()
	rod_mesh.size = Vector3(1.0, 0.04, 0.04)
	rod.mesh = rod_mesh
	rod.material_override = steel
	rod.position = Vector3(motor_side * 1.2, -0.05, 0.0)
	_tie_bar.add_child(rod)

	var motor := MeshInstance3D.new()
	motor.mesh = RailMeshes.create_switch_motor()
	motor.material_override = material
	motor.position = Vector3(motor_side * 2.1, -TerrainDeformer.GROUND_OFFSET, -0.35)
	motor.rotation.y = 0.0 if motor_side < 0.0 else PI
	add_child(motor)

	_lantern = Node3D.new()
	_lantern.position = motor.position + Vector3(motor_side * 0.2, 1.25, 0.0)
	add_child(_lantern)
	var lantern_mesh := MeshInstance3D.new()
	lantern_mesh.mesh = RailMeshes.create_switch_lantern()
	lantern_mesh.material_override = material
	_lantern.add_child(lantern_mesh)
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = Color(1.0, 0.85, 0.55)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color(1.0, 0.75, 0.4)
	_lamp_material.emission_energy_multiplier = 1.5
	var glow := MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.12, 0.12, 0.23)
	glow.mesh = glow_mesh
	glow.material_override = _lamp_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0.0, 0.0, 0.0)
	_lantern.add_child(glow)

	set_state(switch.state, false)


## Stellt die Optik auf Stellung [param state] (0 = gerade, 1 = abzweigend).
func set_state(state: int, animate := true) -> void:
	# Für den geraden Strang liegt die Zunge auf der Abzweigseite an, sonst die andere.
	var closed_side := _diverging_side if state == 0 else -_diverging_side
	var shift := -closed_side * THROW * 0.5
	var angles: Array[float] = []
	for i in _blades.size():
		var side := -1.0 if i == 0 else 1.0
		var tip_x := side * (RailConfig.RAIL_OFFSET - CLOSED_OFFSET)
		if side != closed_side:
			tip_x -= side * THROW
		var heel_x := side * (RailConfig.RAIL_OFFSET - HEEL_OFFSET)
		angles.append(asin(clampf((tip_x - heel_x) / RailMeshes.BLADE_LENGTH, -1.0, 1.0)))
	var lantern_angle := 0.0 if state == 0 else PI * 0.5

	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate:
		for i in _blades.size():
			_blades[i].rotation.y = angles[i]
		_tie_bar.position.x = shift
		_lantern.rotation.y = lantern_angle
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _blades.size():
		_tween.tween_property(_blades[i], "rotation:y", angles[i], ANIMATION_TIME)
	_tween.tween_property(_tie_bar, "position:x", shift, ANIMATION_TIME)
	_tween.tween_property(_lantern, "rotation:y", lantern_angle, ANIMATION_TIME)


func is_animating() -> bool:
	return _tween != null and _tween.is_running()


func get_blade_angle(index: int) -> float:
	return _blades[index].rotation.y
