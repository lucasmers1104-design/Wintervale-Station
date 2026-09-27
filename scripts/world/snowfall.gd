## Leichter Schneefall rund um die aktive Kamera.
##
## Das "Wetter" ändert sich langsam über den Tag (ruhiges Rauschen über die
## Spielzeit): mal klar, mal leise rieselnder Schnee. Die Flocken sind kleine,
## weiche Punkte, die sanft taumelnd fallen.
class_name Snowfall
extends GPUParticles3D

## Maximale Dichte (0..1) bei stärkstem Schneefall.
@export var max_intensity := 1.0
## Wie schnell das Wetter wechselt (Zyklen pro Spieltag).
@export var weather_speed := 2.5
@export var weather_seed := 7

var intensity := 0.0

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = weather_seed
	_noise.frequency = 1.0
	amount = 1400
	lifetime = 9.0
	preprocess = 9.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(32.0, 1.0, 32.0)
	process.direction = Vector3(0.2, -1.0, 0.1)
	process.spread = 12.0
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 2.2
	process.gravity = Vector3(0.0, -0.3, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 6.0
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.15
	process.scale_min = 0.6
	process.scale_max = 1.4
	process_material = process

	var flake := QuadMesh.new()
	flake.size = Vector2(0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	material.albedo_texture = _flake_texture()
	flake.material = material
	draw_pass_1 = flake


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + Vector3(0.0, 14.0, 0.0)
	intensity = get_weather_intensity(WorldClock.day + WorldClock.time_of_day / 24.0)
	amount_ratio = intensity * max_intensity
	emitting = amount_ratio > 0.02


## Schneefall-Stärke (0..1) zu einem Zeitpunkt (Tage als Kommazahl).
func get_weather_intensity(days: float) -> float:
	var value := _noise.get_noise_1d(days * weather_speed) * 0.5 + 0.5
	return smoothstep(0.35, 0.8, value)


## Weiche, runde Schneeflocke als kleine Verlaufstextur.
func _flake_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
