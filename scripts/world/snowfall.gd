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
	amount = 2200
	lifetime = 9.0
	preprocess = 9.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Hoher Kasten: Flocken entstehen in allen Höhen, das Bild ist sofort gefüllt
	process.emission_box_extents = Vector3(32.0, 12.0, 32.0)
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
	# Kein Nebel auf den Flocken: sie fallen nah vor der Kamera und sollen
	# auch bei dichtem Schneetreiben sichtbar bleiben (sonst verschwinden sie im Grau).
	material.disable_fog = true
	material.albedo_texture = _flake_texture()
	flake.material = material
	draw_pass_1 = flake


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Etwas vor der Kamera, damit die Flocken im Bild fallen. Aus der
		# Vogelperspektive (hohe Kamera) werden sie größer, sonst sähe man sie nicht.
		var forward := -camera.global_basis.z
		global_position = camera.global_position + forward * 12.0 + Vector3(0.0, 6.0, 0.0)
		# Hohe Kamera: größere, dafür weniger Flocken (große halbtransparente Flächen kosten Leistung)
		_height_factor = clampf((camera.global_position.y - 4.0) / 16.0, 0.0, 1.0)
		var size := 0.08 * lerpf(1.0, 3.0, _height_factor)
		var flake := draw_pass_1 as QuadMesh
		if flake and absf(flake.size.x - size) > size * 0.05:
			flake.size = Vector2(size, size)
	if _weather_intensity >= 0.0:
		intensity = _weather_intensity
	else:
		intensity = get_weather_intensity(WorldClock.day + WorldClock.time_of_day / 24.0)
	amount_ratio = intensity * max_intensity * lerpf(1.0, 0.5, _height_factor)
	emitting = amount_ratio > 0.02


## Das Wettersystem gibt Stärke (0..1) und Wind vor: Bei starkem Schneefall
## fallen die Flocken schneller und treiben schräg im Wind.
func set_weather(strength: float, wind: float) -> void:
	_weather_intensity = clampf(strength, 0.0, 1.0)
	var process := process_material as ParticleProcessMaterial
	if process and absf(wind - _wind) > 0.02:
		_wind = wind
		process.direction = Vector3(0.2 + wind * 1.4, -1.0, 0.1 + wind * 0.4)
		process.initial_velocity_min = 1.4 + wind * 1.2
		process.initial_velocity_max = 2.2 + wind * 2.0
		process.turbulence_influence_max = 0.15 + wind * 0.2


var _weather_intensity := -1.0
var _height_factor := 0.0
var _wind := -1.0


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
