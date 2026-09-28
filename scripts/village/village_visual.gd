## Baut die sichtbaren Teile eines Dorf-Objekts unter einen Node: Körper,
## Leuchtglas, Fenster, Lichterkette, warme Lichter, Schornsteinrauch.
## Wird von [VillageObject], [VillageHouse] und der Bauvorschau benutzt –
## so sieht die Vorschau exakt wie das fertige Objekt aus.
class_name VillageVisual
extends RefCounted

const LIGHT_COLOR := Color(1.0, 0.72, 0.42)

static var _smoke_process: ParticleProcessMaterial
static var _smoke_mesh: QuadMesh


## Hängt die Meshes von [param item_id] unter [param parent]. Mit [param preview]
## bekommen alle Teile [param preview_material] und es entstehen keine Lichter.
## Rückgabe: {"meshes": [MeshInstance3D], "lights": [OmniLight3D], "windows": ShaderMaterial,
##  "string_glow": ShaderMaterial, "smoke": [GPUParticles3D], "data": build_meshes-Ergebnis}.
static func attach(parent: Node3D, item_id: String, variant: int, length: float, material: Material,
		preview := false, preview_material: Material = null) -> Dictionary:
	var data := VillageCatalog.build_meshes(item_id, variant, length)
	var result := {"meshes": [], "lights": [], "windows": null, "string_glow": null, "smoke": [], "data": data}
	# Kleine Deko wirft keinen Schatten (spart Draw-Calls im Schattenpass, sieht man ohnehin kaum)
	var small := float(VillageCatalog.get_item(item_id).get("radius", 1.0)) < 0.6 and VillageCatalog.get_kind(item_id) == "point"
	var body_material := VillageCatalog.body_material(item_id, material)
	_add(parent, data["body"], preview_material if preview else body_material, result)
	_add(parent, data["glow"], preview_material if preview else VillageCatalog.GLOW_MATERIAL, result)
	if data["glass"]:
		var windows: Material = preview_material
		if not preview:
			windows = (VillageCatalog.WINDOW_MATERIAL as ShaderMaterial).duplicate()
			result["windows"] = windows
		_add(parent, data["glass"], windows, result)
	if data["cable"]:
		_add(parent, data["cable"], preview_material if preview else VillageCatalog.string_material(false), result)
		var bulbs: Material = preview_material
		if not preview:
			bulbs = VillageCatalog.string_material(true).duplicate()
			(bulbs as ShaderMaterial).set_shader_parameter(&"glow", 0.0)
			result["string_glow"] = bulbs
		_add(parent, data["bulbs"], bulbs, result)
	if small:
		for mesh: MeshInstance3D in result["meshes"]:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if preview:
		return result
	var light_info: Dictionary = VillageCatalog.get_item(item_id).get("light", {})
	var is_house := VillageCatalog.get_kind(item_id) == "house"
	for point: Vector3 in data["lights"]:
		var light := OmniLight3D.new()
		light.position = point
		light.light_color = LIGHT_COLOR
		light.omni_range = float(light_info.get("range", 4.5 if is_house else 5.0))
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		# Weit entfernte Lichter blenden aus (Leistung) – aus der Vogelperspektive bleiben die Gläser sichtbar
		light.distance_fade_enabled = true
		light.distance_fade_begin = 60.0
		light.distance_fade_length = 20.0
		light.light_energy = 0.0
		light.visible = false
		light.set_meta(&"energy", float(light_info.get("energy", 0.7 if is_house else 1.0)))
		parent.add_child(light)
		result["lights"].append(light)
	for chimney: Vector3 in data["chimneys"]:
		var smoke := create_smoke()
		smoke.position = chimney
		parent.add_child(smoke)
		result["smoke"].append(smoke)
	return result


## Lichter weich ein- bzw. ausblenden (nachts warm, gelblich, nicht zu hell).
static func set_lit(parts: Dictionary, lit: bool, owner: Node) -> void:
	if (parts.get("lights", []) as Array).is_empty() and parts.get("string_glow") == null:
		return
	var tween := owner.create_tween().set_parallel(true)
	for light: OmniLight3D in parts["lights"]:
		if lit:
			light.visible = true
		tween.tween_property(light, "light_energy", float(light.get_meta(&"energy")) if lit else 0.0, 2.5)
	if parts["string_glow"]:
		tween.tween_property(parts["string_glow"], "shader_parameter/glow", 1.0 if lit else 0.0, 2.5)
	if not lit:
		tween.chain().tween_callback(func() -> void:
			for light: OmniLight3D in parts["lights"]:
				if is_instance_valid(light):
					light.visible = false)


## Weicher, grauer Rauch aus einem Schornstein, der mit dem Wind abzieht.
static func create_smoke() -> GPUParticles3D:
	if _smoke_process == null:
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.15, 1.0, 0.05)
		process.spread = 8.0
		process.initial_velocity_min = 0.45
		process.initial_velocity_max = 0.7
		process.gravity = Vector3(0.28, 0.08, 0.1)
		process.damping_min = 0.05
		process.damping_max = 0.1
		var scale_curve := Curve.new()
		scale_curve.add_point(Vector2(0.0, 0.35))
		scale_curve.add_point(Vector2(1.0, 1.0))
		var scale_texture := CurveTexture.new()
		scale_texture.curve = scale_curve
		process.scale_curve = scale_texture
		process.scale_min = 0.8
		process.scale_max = 1.2
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.86, 0.85, 0.86, 0.0))
		ramp.set_color(1, Color(0.86, 0.85, 0.88, 0.0))
		ramp.add_point(0.15, Color(0.82, 0.8, 0.82, 0.45))
		ramp.add_point(0.6, Color(0.86, 0.85, 0.88, 0.25))
		var ramp_texture := GradientTexture1D.new()
		ramp_texture.gradient = ramp
		process.color_ramp = ramp_texture
		_smoke_process = process
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.7, 0.7)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.albedo_texture = _puff_texture()
		mesh.material = material
		_smoke_mesh = mesh
	var smoke := GPUParticles3D.new()
	smoke.amount = 12
	smoke.lifetime = 6.0
	smoke.preprocess = 6.0
	smoke.process_material = _smoke_process
	smoke.draw_pass_1 = _smoke_mesh
	smoke.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(10, 8, 8))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.visibility_range_end = 160.0
	return smoke


static func _puff_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture


static func _add(parent: Node3D, mesh: Mesh, material: Material, result: Dictionary) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	result["meshes"].append(instance)


## Markierung (z.B. rot beim Entfernen) über alle Meshes legen.
static func set_overlay(parts: Dictionary, material: Material) -> void:
	for mesh: MeshInstance3D in parts["meshes"]:
		if is_instance_valid(mesh):
			mesh.material_overlay = material


static func clear_cache() -> void:
	_smoke_process = null
	_smoke_mesh = null
