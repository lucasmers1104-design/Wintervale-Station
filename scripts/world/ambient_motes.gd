## Leichte Partikel im Abendlicht: winzige, warm glitzernde Schneekristalle,
## die um die Kamera schweben. Am stärksten zur goldenen Stunde, tagsüber
## kaum sichtbar, nachts ganz leise.
class_name AmbientMotes
extends GPUParticles3D

@export var max_amount := 90


func _ready() -> void:
	amount = max_amount
	lifetime = 7.0
	preprocess = 7.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(22, 7, 22)
	process.direction = Vector3(0.3, 0.1, 0.2)
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.25
	process.gravity = Vector3(0.05, -0.04, 0.03)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_speed_random = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.7, 0.0))
	ramp.set_color(1, Color(1, 0.9, 0.7, 0.0))
	ramp.add_point(0.3, Color(1, 0.88, 0.62, 1.0))
	ramp.add_point(0.7, Color(1, 0.94, 0.8, 0.8))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	process.scale_min = 0.5
	process.scale_max = 1.2
	process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	material.albedo_texture = texture
	mesh.material = material
	draw_pass_1 = mesh


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + (-camera.global_basis.z) * 12.0
	var hour := WorldClock.time_of_day
	# Goldene Stunde: 15:00–17:15 am stärksten
	var golden := smoothstep(14.6, 15.6, hour) * (1.0 - smoothstep(16.9, 17.6, hour))
	var strength := maxf(golden, 0.15 if hour > 8.0 and hour < 15.0 else 0.08)
	amount_ratio = strength
	emitting = strength > 0.02
