## Regen rund um die aktive Kamera: feine, schräg fallende Tropfenstriche.
## Stärke und Wind gibt das [WeatherSystem] vor ([method set_weather]).
class_name Rainfall
extends GPUParticles3D

var intensity := 0.0
var _wind := -1.0


func _ready() -> void:
	amount = 2600
	lifetime = 1.2
	preprocess = 1.2
	local_coords = false
	visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount_ratio = 0.0
	emitting = false

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Hoher Kasten vor der Kamera: Regen fällt überall im Bild, auch aus der Vogelperspektive
	process.emission_box_extents = Vector3(26.0, 10.0, 26.0)
	process.direction = Vector3(0.1, -1.0, 0.05)
	process.spread = 3.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 17.0
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.particle_flag_align_y = true
	process.scale_min = 0.7
	process.scale_max = 1.2
	process_material = process

	var drop := QuadMesh.new()
	drop.size = Vector2(0.018, 0.55)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.albedo_color = Color(0.78, 0.84, 0.92, 0.32)
	drop.material = material
	draw_pass_1 = drop


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position - camera.global_basis.z * 12.0 + Vector3(0.0, 4.0, 0.0)
	amount_ratio = intensity
	emitting = intensity > 0.02


## Stärke (0..1) und Wind (0..1): Wind lässt den Regen schräg fallen.
func set_weather(strength: float, wind: float) -> void:
	intensity = clampf(strength, 0.0, 1.0)
	var process := process_material as ParticleProcessMaterial
	if process and absf(wind - _wind) > 0.02:
		_wind = wind
		process.direction = Vector3(0.1 + wind * 0.45, -1.0, 0.05 + wind * 0.15)
