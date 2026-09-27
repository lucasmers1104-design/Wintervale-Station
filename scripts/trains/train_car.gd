## Ein sichtbares Fahrzeug eines Zuges (Lok oder Wagen).
##
## Der Wagenkasten liegt auf zwei Drehgestellen, die jeweils der Gleisrichtung
## an ihrer Position folgen – so fahren die Wagen sauber durch Kurven.
## Außerdem: drehende Radsätze, Schiebetüren, Stirn-/Schlusslichter,
## Scheinwerfer, aufgewirbelter Schnee und Klänge (Schienenstoß, Türen).
class_name TrainCar
extends Node3D

## Schienenoberkante über der Gleisachse.
const RAIL_TOP := RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT

var kind := ""
var length := 12.0
## Abstand Wagenmitte → Drehgestellmitte.
var bogie_offset := 4.3
## Abstand von der Zugspitze bis zur Vorderkante dieses Wagens.
var offset_from_head := 0.0

var _bogies: Array[Node3D] = []
var _wheelsets: Array[Node3D] = []
var _doors: Array[Dictionary] = []
var _headlight: SpotLight3D
var _tail_glow: OmniLight3D
var _snow: GPUParticles3D
var _clack_player: AudioStreamPlayer3D
var _door_player: AudioStreamPlayer3D
var _pick_area: Area3D
var _wheel_angle := 0.0
var _door_amount := 0.0


## Baut das Fahrzeug. [param materials]: {"paint", "glass", "lamp_white", "lamp_red", "snow"}.
func build(p_kind: String, train_type: TrainType, is_first: bool, is_last: bool, materials: Dictionary,
		variant := 0) -> void:
	kind = p_kind
	name = "%s_%d" % [kind, variant]
	var parts := TrainMeshes.build_car(kind, train_type.get_livery(), variant)
	length = parts["length"]
	bogie_offset = parts["bogie"]

	_add_mesh(parts["paint"], materials["paint"])
	if parts["glass"]:
		_add_mesh(parts["glass"], materials["glass"])
	for door: Dictionary in parts["doors"]:
		var leaf := MeshInstance3D.new()
		leaf.mesh = door["mesh"]
		leaf.material_override = materials["paint"]
		leaf.position = door["position"]
		if float(door["side"]) < 0.0:
			leaf.rotation.y = PI
		add_child(leaf)
		_doors.append({"node": leaf, "closed": door["position"], "open_offset": door["open_offset"], "side": door["side"]})

	var bogie_mesh := TrainMeshes.create_bogie(parts["wheel_base"])
	var wheel_mesh := TrainMeshes.create_wheelset()
	for z in [-bogie_offset, bogie_offset]:
		var bogie := Node3D.new()
		bogie.position = Vector3(0.0, 0.0, z)
		add_child(bogie)
		_add_mesh(bogie_mesh, materials["paint"], bogie)
		for axle: float in [-0.5, 0.5]:
			var wheelset := Node3D.new()
			wheelset.position = Vector3(0.0, TrainMeshes.WHEEL_RADIUS, axle * float(parts["wheel_base"]))
			bogie.add_child(wheelset)
			_add_mesh(wheel_mesh, materials["paint"], wheelset)
			_wheelsets.append(wheelset)
		_bogies.append(bogie)

	if is_first:
		for lamp_position: Vector3 in parts["lamps_front"]:
			_add_lamp(lamp_position, -1.0, materials["lamp_white"])
		_headlight = SpotLight3D.new()
		_headlight.position = Vector3(0.0, 1.7, -length * 0.5 - 0.2)
		_headlight.light_color = Color(1.0, 0.9, 0.72)
		_headlight.spot_range = 45.0
		_headlight.spot_angle = 26.0
		_headlight.spot_attenuation = 0.8
		_headlight.shadow_enabled = false
		add_child(_headlight)
		_snow = _make_snow_spray(materials["snow"])
		_snow.position = Vector3(0.0, 0.3, -bogie_offset)
		add_child(_snow)
	if is_last:
		for lamp_position: Vector3 in parts["lamps_rear"]:
			_add_lamp(lamp_position, 1.0, materials["lamp_red"])
		_tail_glow = OmniLight3D.new()
		_tail_glow.position = Vector3(0.0, 1.45, length * 0.5 + 0.4)
		_tail_glow.light_color = Color(1.0, 0.15, 0.1)
		_tail_glow.omni_range = 3.0
		_tail_glow.light_energy = 0.5
		add_child(_tail_glow)

	# Zum Anklicken (Kamera folgt dem Zug)
	_pick_area = Area3D.new()
	_pick_area.collision_layer = GameDefs.LAYER_TRAINS
	_pick_area.collision_mask = 0
	_pick_area.monitoring = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 3.6, length)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 2.0, 0.0)
	_pick_area.add_child(collision)
	add_child(_pick_area)

	_clack_player = _make_player(SoundLibrary.get_sound("clack"), -8.0, 45.0)
	if not _doors.is_empty():
		_door_player = _make_player(null, -9.0, 25.0)


## Positioniert Wagenkasten und Drehgestelle anhand der Drehgestell-Punkte auf dem Gleis.
func place(front: Vector3, front_direction: Vector3, rear: Vector3, rear_direction: Vector3) -> void:
	var lift := Vector3.UP * RAIL_TOP
	var axis := front - rear
	var forward := axis.normalized() if axis.length() > 0.01 else front_direction
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), (front + rear) * 0.5 + lift)
	_bogies[0].global_transform = Transform3D(Basis.looking_at(front_direction, Vector3.UP), front + lift)
	_bogies[1].global_transform = Transform3D(Basis.looking_at(rear_direction, Vector3.UP), rear + lift)


## Räder um die gefahrene Strecke weiterdrehen.
func roll(distance: float) -> void:
	_wheel_angle = fmod(_wheel_angle + distance / TrainMeshes.WHEEL_RADIUS, TAU)
	for wheelset in _wheelsets:
		wheelset.rotation.x = -_wheel_angle


## Türen auf der Seite [param side] (±1) öffnen: 0 = zu, 1 = offen (weich animiert).
func set_doors(amount: float, side: float) -> void:
	_door_amount = clampf(amount, 0.0, 1.0)
	var eased := ease(_door_amount, -1.8)
	for door in _doors:
		var node: Node3D = door["node"]
		var offset: Vector3 = door["open_offset"] if float(door["side"]) == side else Vector3.ZERO
		# Erst leicht nach außen (Schwenkschiebetür), dann zur Seite gleiten
		var outward := Vector3(offset.x, 0.0, 0.0) * clampf(eased * 3.0, 0.0, 1.0)
		var slide := Vector3(0.0, 0.0, offset.z) * clampf(eased * 1.25 - 0.25, 0.0, 1.0)
		node.position = door["closed"] + outward + slide


func has_doors() -> bool:
	return not _doors.is_empty()


func get_door_amount() -> float:
	return _door_amount


## Lichtstärke der Scheinwerfer (nachts heller).
func set_light_level(dark: bool) -> void:
	if _headlight:
		_headlight.light_energy = 3.0 if dark else 0.6
	if _tail_glow:
		_tail_glow.light_energy = 0.6 if dark else 0.15


## Aufgewirbelter Schnee an der Lok – nur bei zügiger Fahrt.
func set_snow_spray(speed: float) -> void:
	if _snow:
		_snow.emitting = speed > 4.0
		_snow.amount_ratio = clampf((speed - 4.0) / 10.0, 0.1, 1.0)


func play_clack(intensity: float) -> void:
	if _clack_player and intensity > 0.05:
		_clack_player.pitch_scale = randf_range(0.9, 1.1)
		_clack_player.volume_db = -8.0 + linear_to_db(clampf(intensity, 0.05, 1.0))
		_clack_player.play()


func play_door_sound(opening: bool) -> void:
	if _door_player:
		_door_player.stream = SoundLibrary.get_sound("door_open" if opening else "door_close")
		_door_player.pitch_scale = randf_range(0.96, 1.04)
		_door_player.play()


func _add_mesh(mesh: Mesh, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Kleine leuchtende Lampenscheibe; [param facing] -1 = nach vorne, +1 = nach hinten.
func _add_lamp(lamp_position: Vector3, facing: float, material: Material) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.1
	disc.bottom_radius = 0.1
	disc.height = 0.04
	disc.radial_segments = 12
	disc.rings = 0
	var lamp := MeshInstance3D.new()
	lamp.mesh = disc
	lamp.material_override = material
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.rotation.x = PI * 0.5
	lamp.position = lamp_position + Vector3(0.0, 0.0, facing * 0.01)
	add_child(lamp)


func _make_player(stream: AudioStream, volume: float, distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume
	player.max_distance = distance
	player.unit_size = 6.0
	add_child(player)
	return player


func _make_snow_spray(material: Material) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.6)
	process.spread = 55.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0.0, -1.2, 0.0)
	process.damping_min = 0.8
	process.damping_max = 1.6
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(1.2, 0.1, 0.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 1.4
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.local_coords = false
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
