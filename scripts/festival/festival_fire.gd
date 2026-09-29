## Lagerfeuer (Herbstfest) oder Feuerkorb (Weihnachtsmarkt): tanzende Flammen,
## aufsteigende Funken, flackerndes warmes Licht und leises Knistern.
class_name FestivalFire
extends Node3D

var _flames: GPUParticles3D
var _sparks: GPUParticles3D
var _light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _burning := false
var _time := 0.0
var _size := 1.0


## [param size] 1 = großes Lagerfeuer, ~0,5 = Feuerkorb.
func build(size: float, flame_height: float) -> void:
	_size = size
	_flames = _particles(24, 1.1, Vector2(0.55, 0.55) * size, Vector3(0.35, 0.05, 0.35) * size, 0.6, 1.2, 0.25,
		[Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.62, 0.2, 0.95), Color(0.95, 0.3, 0.08, 0.6), Color(0.4, 0.1, 0.05, 0.0)])
	_flames.position = Vector3(0, flame_height, 0)
	add_child(_flames)
	_sparks = _particles(14, 2.6, Vector2(0.05, 0.05), Vector3(0.3, 0.05, 0.3) * size, 1.2, 2.4, -0.1,
		[Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.5, 0.15, 0.8), Color(1.0, 0.3, 0.1, 0.0)])
	_sparks.position = Vector3(0, flame_height + 0.2, 0)
	add_child(_sparks)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, flame_height + 0.6 * size, 0)
	_light.light_color = Color(1.0, 0.6, 0.3)
	_light.omni_range = 7.0 * size + 1.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = SoundLibrary.get_sound("fireplace")
	_sound.volume_db = -12.0 + size * 4.0
	_sound.unit_size = 4.0
	_sound.max_distance = 25.0
	add_child(_sound)
	SoundLibrary.stop_on_exit(_sound)
	set_burning(false)


func set_burning(burning: bool) -> void:
	_burning = burning
	_flames.emitting = burning
	_sparks.emitting = burning
	if burning and not _sound.playing:
		SoundLibrary.play(_sound)
	elif not burning:
		_sound.stop()
	if not burning:
		_light.light_energy = 0.0


func is_burning() -> bool:
	return _burning


func _process(delta: float) -> void:
	if not _burning:
		return
	_time += delta
	# Flackern aus mehreren Sinuswellen
	var flicker := 0.8 + 0.12 * sin(_time * 9.1) + 0.08 * sin(_time * 23.0 + 1.3) + 0.06 * sin(_time * 4.2)
	_light.light_energy = (1.3 + _size * 0.8) * flicker


func _particles(amount: int, lifetime: float, size: Vector2, box: Vector3, speed_min: float, speed_max: float,
		gravity_up: float, colors: Array) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box
	process.direction = Vector3(0, 1, 0)
	process.spread = 10.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = Vector3(0.05, gravity_up, 0.0)
	process.damping_min = 0.3
	process.damping_max = 0.6
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.12
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.7))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1.0, 0.2))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = shrink
	process.scale_curve = scale_curve
	var gradient := Gradient.new()
	gradient.set_color(0, colors[0])
	gradient.set_color(1, colors[-1])
	for i in range(1, colors.size() - 1):
		gradient.add_point(float(i) / (colors.size() - 1), colors[i])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = MarketStall._puff()
	material.disable_fog = true
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.local_coords = false
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))
	particles.visibility_range_end = 80.0
	return particles
