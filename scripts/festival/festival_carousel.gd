## Kinderkarussell auf dem Weihnachtsmarkt: gestreiftes Zeltdach, sechs
## Pferdchen, die beim Drehen auf und ab wippen, Lauflicht am Dachrand und eine
## Spieluhr-Melodie. Läuft, solange der Markt offen ist – fährt weich an und aus.
class_name FestivalCarousel
extends Node3D

const TURN_SPEED := 0.55

var radius := 2.6

var _rotor: Node3D
var _horses: Array[Node3D] = []
var _speed := 0.0
var _running := false
var _lights: ShaderMaterial
var _light: OmniLight3D
var _music: AudioStreamPlayer3D
var _dark := false


func build(body_material: Material, glow_template: ShaderMaterial, rng: RandomNumberGenerator) -> void:
	var base := TrainMeshes._new_st()
	radius = FestivalMeshes.carousel_base(base)
	var base_mesh := MeshInstance3D.new()
	base_mesh.mesh = base.commit()
	base_mesh.material_override = body_material
	add_child(base_mesh)
	_rotor = Node3D.new()
	_rotor.name = "Rotor"
	add_child(_rotor)
	var top := TrainMeshes._new_st()
	var glow := TrainMeshes._new_st()
	FestivalMeshes.carousel_top(top, glow, rng, radius)
	var top_mesh := MeshInstance3D.new()
	top_mesh.mesh = top.commit()
	top_mesh.material_override = body_material
	_rotor.add_child(top_mesh)
	_lights = glow_template.duplicate() as ShaderMaterial
	var glow_mesh := MeshInstance3D.new()
	glow_mesh.mesh = glow.commit()
	glow_mesh.material_override = _lights
	glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rotor.add_child(glow_mesh)
	var colors := [Color(0.95, 0.93, 0.88), Color(0.62, 0.42, 0.28), Color(0.95, 0.93, 0.88), Color(0.4, 0.4, 0.44),
		Color(0.95, 0.93, 0.88), Color(0.82, 0.62, 0.4)]
	for i in 6:
		var angle := TAU * i / 6.0
		var holder := Node3D.new()
		holder.position = Vector3(cos(angle), 0.27, sin(angle)) * Vector3(radius * 0.72, 1.0, radius * 0.72)
		# Pferde schauen in Fahrtrichtung (tangential)
		holder.rotation.y = -angle
		var horse := MeshInstance3D.new()
		horse.mesh = FestivalMeshes.carousel_horse(rng, colors[i])
		horse.material_override = body_material
		holder.add_child(horse)
		_rotor.add_child(holder)
		_horses.append(horse)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 2.4, 0)
	_light.light_color = Color(1.0, 0.76, 0.46)
	_light.omni_range = 6.5
	_light.light_energy = 0.0
	add_child(_light)
	_music = AudioStreamPlayer3D.new()
	_music.stream = FestivalSounds.get_sound("carol")
	_music.volume_db = -13.0
	_music.unit_size = 7.0
	_music.max_distance = 45.0
	_music.position = Vector3(0, 2.0, 0)
	add_child(_music)
	SoundLibrary.stop_on_exit(_music)
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius + 0.3
	cylinder.height = 2.6
	shape.shape = cylinder
	shape.position = Vector3(0, 1.3, 0)
	body.add_child(shape)
	add_child(body)
	set_running(false, true)


func set_running(running: bool, instant := false) -> void:
	_running = running
	_lights.set_shader_parameter(&"lit", 1.0 if running else 0.15)
	_lights.set_shader_parameter(&"chase", 0.6 if running else 0.0)
	if instant:
		_speed = TURN_SPEED if running else 0.0
	if running and not _music.playing:
		SoundLibrary.play(_music)
	elif not running:
		_music.stop()
	_light.light_energy = 0.9 if running and _dark else 0.0


func set_dark(dark: bool) -> void:
	_dark = dark
	_light.light_energy = 0.9 if _running and dark else 0.0


func is_running() -> bool:
	return _running


func get_speed() -> float:
	return _speed


func _process(delta: float) -> void:
	_speed = move_toward(_speed, TURN_SPEED if _running else 0.0, delta * 0.12)
	if _speed <= 0.0:
		return
	_rotor.rotation.y += _speed * delta
	for i in _horses.size():
		_horses[i].position.y = 0.14 + sin(_rotor.rotation.y * 3.0 + i * 1.9) * 0.14
