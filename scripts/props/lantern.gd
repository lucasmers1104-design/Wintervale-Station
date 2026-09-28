## Laterne, die sich in der Dämmerung mit warmem Licht einschaltet (dazu ein
## ganz leises Summen, wenn man daneben steht).
##
## Reagiert auf [code]WorldClock.darkness_changed[/code]. Jede Laterne
## wartet eine kleine Zufallszeit, damit nicht alle gleichzeitig angehen.
class_name Lantern
extends StaticBody3D

@export var light_energy := 1.7
@export var glass_emission := 1.9
@export var fade_duration := 2.0
@export var max_switch_delay := 1.5

var _glass_material: StandardMaterial3D
var _tween: Tween
var _hum: AudioStreamPlayer3D

@onready var _light: OmniLight3D = $Light
@onready var _glass: MeshInstance3D = $Glass


func _ready() -> void:
	# Eigene Materialkopie, damit jede Laterne unabhängig leuchten kann.
	_glass_material = (_glass.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_glass.material_override = _glass_material
	# Ganz leises, warmes Summen – nur hörbar, wenn man direkt daneben steht
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = SoundLibrary.get_sound("lamp_hum")
	_hum.volume_db = -30.0
	_hum.unit_size = 1.2
	_hum.max_distance = 7.0
	_hum.position = Vector3(0.0, 2.85, 0.0)
	add_child(_hum)
	SoundLibrary.stop_on_exit(_hum)
	WorldClock.darkness_changed.connect(_on_darkness_changed)
	_set_lit(WorldClock.is_dark(), true)


func is_lit() -> bool:
	return _light.visible and _light.light_energy > 0.0


func _on_darkness_changed(is_dark: bool) -> void:
	_set_lit(is_dark, false)


func _set_lit(lit: bool, instant: bool) -> void:
	if _hum:
		if lit and not _hum.playing:
			_hum.pitch_scale = randf_range(0.95, 1.05)
			SoundLibrary.play(_hum)
		elif not lit:
			_hum.stop()
	var energy := light_energy if lit else 0.0
	var emission := glass_emission if lit else 0.0
	if _tween and _tween.is_valid():
		_tween.kill()

	if instant:
		_light.light_energy = energy
		_light.visible = lit
		_glass_material.emission_energy_multiplier = emission
		return

	_light.visible = true
	_tween = create_tween()
	_tween.tween_interval(randf() * max_switch_delay)
	_tween.tween_property(_light, "light_energy", energy, fade_duration)
	_tween.parallel().tween_property(_glass_material, "emission_energy_multiplier", emission, fade_duration)
	if not lit:
		_tween.tween_callback(_light.hide)
