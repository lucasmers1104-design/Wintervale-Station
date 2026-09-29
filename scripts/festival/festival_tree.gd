## Der große Weihnachtsbaum auf dem Markt.
##
## Beim Lichterfest ([method light_up]) laufen die Lichter als Welle von unten
## nach oben den Baum hinauf (Shader-Parameter reveal_height), zuletzt strahlt der
## Stern auf und sprüht Funken. Danach leuchtet der Baum, bis der Markt schließt.
class_name FestivalTree
extends Node3D

var height := 7.4

var _lights: ShaderMaterial
var _star_light: OmniLight3D
var _glow_light: OmniLight3D
var _sparkles: GPUParticles3D
var _lit := false
var _tween: Tween


func build(body_material: Material, glow_template: ShaderMaterial, rng: RandomNumberGenerator) -> void:
	var st := TrainMeshes._new_st()
	var glow := TrainMeshes._new_st()
	var info := FestivalMeshes.christmas_tree(st, glow, rng)
	height = float(info["height"])
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = body_material
	add_child(body)
	_lights = glow_template.duplicate() as ShaderMaterial
	_lights.set_shader_parameter(&"reveal_soft", 0.9)
	var lights := MeshInstance3D.new()
	lights.mesh = glow.commit()
	lights.material_override = _lights
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)
	var star: Vector3 = info["star"]
	_star_light = OmniLight3D.new()
	_star_light.position = star
	_star_light.light_color = Color(1.0, 0.86, 0.55)
	_star_light.omni_range = 7.0
	_star_light.light_energy = 0.0
	add_child(_star_light)
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, 2.6, 0)
	_glow_light.light_color = Color(1.0, 0.72, 0.4)
	_glow_light.omni_range = 9.0
	_glow_light.light_energy = 0.0
	_glow_light.shadow_enabled = false
	add_child(_glow_light)
	_sparkles = _make_sparkles()
	_sparkles.position = star
	add_child(_sparkles)
	var collision := StaticBody3D.new()
	collision.collision_layer = GameDefs.LAYER_OBJECTS
	collision.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.3
	cylinder.height = 3.0
	shape.shape = cylinder
	shape.position = Vector3(0, 1.5, 0)
	collision.add_child(shape)
	add_child(collision)
	set_lit(false)


func is_lit() -> bool:
	return _lit


## Sofort an oder aus (ohne Zeremonie).
func set_lit(lit: bool) -> void:
	_lit = lit
	if _tween and _tween.is_valid():
		_tween.kill()
	_lights.set_shader_parameter(&"reveal_height", height + 1.5 if lit else -1.0)
	_star_light.light_energy = 1.4 if lit else 0.0
	_glow_light.light_energy = 1.1 if lit else 0.0


## Die Lichterwelle: in [param duration] Sekunden von unten bis zum Stern.
func light_up(duration := 4.5) -> void:
	_lit = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(func(h: float) -> void: _lights.set_shader_parameter(&"reveal_height", h), 0.4, height - 0.2,
		duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_glow_light, "light_energy", 1.1, duration)
	_tween.chain().tween_callback(func() -> void:
		_lights.set_shader_parameter(&"reveal_height", height + 1.5)
		_sparkles.restart()
		_sparkles.emitting = true)
	_tween.chain().tween_property(_star_light, "light_energy", 3.2, 0.25)
	_tween.chain().tween_property(_star_light, "light_energy", 1.4, 1.6)


func get_reveal_height() -> float:
	return float(_lights.get_shader_parameter(&"reveal_height"))


## Goldene Funken, die aus dem Stern sprühen und sanft herabrieseln.
func _make_sparkles() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.6
	process.gravity = Vector3(0, -1.2, 0)
	process.damping_min = 0.8
	process.damping_max = 1.4
	process.scale_min = 0.5
	process.scale_max = 1.1
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	fade.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = MarketStall._puff()
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.4)
	material.emission_energy_multiplier = 3.0
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = 70
	particles.lifetime = 2.8
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-5, -8, -5), Vector3(10, 12, 10))
	return particles
