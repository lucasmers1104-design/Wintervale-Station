## Eine Marktbude auf dem Fest: Holzbude mit Waren, Lichterkette und Schild.
##
## Geöffnet klappt der Laden vorne nach oben (wird zum Vordach), der Verkäufer
## steht hinter der Theke, drinnen brennt eine warme Lampe, über Glühweintopf,
## Maronenofen und Zwiebelkuchen steigt Dampf auf. Geschlossen hängt der Laden
## vor der Öffnung und die Bude ist dunkel.
##
## Vor der Theke gibt es einen Kundenplatz ([member customer_spot]). Kauft
## jemand, erzählt der Verkäufer kurz (Geste) und reicht die Ware über die Theke.
class_name MarketStall
extends Node3D

const SHUTTER_OPEN := 1.75
const OPEN_TIME := 2.2

var kind := ""
var label := ""
var customer_spot: StationSpot
## Gibt es hier etwas Heißes zu trinken (Becher)?
var sells_drinks := false

var _shutter: Node3D
var _keeper: CharacterModel
var _light: OmniLight3D
var _steam: GPUParticles3D
var _glow: ShaderMaterial
var _open := false
var _dark := false
var _tween: Tween
var _sales := 0


## Baut die Bude. [param glow] ist das (geteilte) Material der Lichter.
func build(p_kind: String, body_material: Material, glow: ShaderMaterial, rng: RandomNumberGenerator,
		keeper_look: CharacterAppearance) -> void:
	kind = p_kind
	_glow = glow
	sells_drinks = kind in ["gluehwein", "apfelmost"]
	var st := TrainMeshes._new_st()
	var glow_st := TrainMeshes._new_st()
	var info := FestivalMeshes.stall(st, glow_st, rng, kind)
	label = String(info["label"])
	_add_mesh(st.commit(), body_material)
	var lights := _add_mesh(glow_st.commit(), glow)
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shutter = Node3D.new()
	_shutter.name = "Shutter"
	_shutter.position = info["shutter_pivot"]
	add_child(_shutter)
	var shutter_mesh := MeshInstance3D.new()
	shutter_mesh.mesh = info["shutter"]
	shutter_mesh.material_override = body_material
	_shutter.add_child(shutter_mesh)
	var sign := Label3D.new()
	sign.text = label
	sign.font_size = 46
	sign.pixel_size = 0.0034
	sign.modulate = Color(0.3, 0.16, 0.08)
	sign.outline_size = 0
	sign.double_sided = false
	sign.transform = info["sign"]
	add_child(sign)
	_keeper = CharacterModel.new()
	_keeper.name = "Keeper"
	_keeper.appearance = keeper_look
	_keeper.view_distance = 60.0
	_keeper.position = info["keeper"]
	add_child(_keeper)
	_keeper.set_pose(CharacterModel.Pose.STAND)
	_keeper.disable_shadows()
	_light = OmniLight3D.new()
	_light.position = info["lamp"] - Vector3(0, 0.15, 0.3)
	_light.light_color = Color(1.0, 0.74, 0.45)
	_light.omni_range = 4.8
	_light.omni_attenuation = 1.3
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 55.0
	_light.distance_fade_length = 15.0
	add_child(_light)
	var steam_at: Vector3 = info["steam"]
	if steam_at != Vector3.INF:
		_steam = _make_steam()
		_steam.position = steam_at
		add_child(_steam)
	customer_spot = StationSpot.new()
	customer_spot.name = "Customer"
	customer_spot.kind = StationSpot.Kind.STAND
	customer_spot.station_name = FestivalDirector.SPOT_STATION
	customer_spot.position = info["customer"]
	customer_spot.rotation.y = PI  # Blick zur Theke (+Z)
	add_child(customer_spot)
	# Die Spielfigur läuft nicht durch die Bude
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FestivalMeshes.STALL_WIDTH + 0.1, 2.4, FestivalMeshes.STALL_DEPTH + 0.1)
	shape.shape = box
	shape.position = Vector3(0, 1.2, 0)
	body.add_child(shape)
	add_child(body)
	set_open(false, true)


func is_open() -> bool:
	return _open


## Laden hoch (offen) oder herunter. [param instant] ohne Animation.
func set_open(open: bool, instant := false) -> void:
	_open = open
	if _tween and _tween.is_valid():
		_tween.kill()
	if _steam:
		_steam.emitting = open
	if instant:
		_shutter.rotation.x = SHUTTER_OPEN if open else 0.0
		_keeper.visible = open
		_keeper.set_fade(1.0 if open else 0.0)
		_light.light_energy = 1.0 if open and _dark else 0.0
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_shutter, "rotation:x", SHUTTER_OPEN if open else 0.0, OPEN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if open:
		_keeper.visible = true
		_tween.tween_method(_keeper.set_fade, 0.0, 1.0, 1.2).set_delay(0.6)
		_tween.tween_callback(func() -> void: _keeper.play_gesture(CharacterModel.Pose.STRETCH, 2.2)).set_delay(1.8)
	else:
		_tween.tween_method(_keeper.set_fade, 1.0, 0.0, 0.8)
	_tween.tween_property(_light, "light_energy", 1.0 if open and _dark else 0.0, 1.5)


func set_dark(dark: bool) -> void:
	_dark = dark
	if not (_tween and _tween.is_running()):
		_light.light_energy = 1.0 if _open and dark else 0.0


## Jemand kauft etwas: der Verkäufer erzählt kurz und reicht es über die Theke.
func serve(customer: Node3D) -> void:
	_sales += 1
	if not _open:
		return
	var to_customer := customer.global_position - _keeper.global_position
	_keeper.rotation.y = atan2(-to_customer.x, -to_customer.z) - global_rotation.y
	_keeper.play_gesture(CharacterModel.Pose.TALK, 1.6)
	# Gebundene Methoden: Wird der Stand vorher entfernt, trennt Godot die Timer.
	get_tree().create_timer(1.7, false).timeout.connect(_finish_serving)
	if _steam:
		_steam.amount_ratio = 1.0
		get_tree().create_timer(2.0, false).timeout.connect(_calm_steam)


func _finish_serving() -> void:
	if is_instance_valid(_keeper):
		_keeper.play_gesture(CharacterModel.Pose.NOD, 1.0)
		_keeper.rotation.y = 0.0


func _calm_steam() -> void:
	if is_instance_valid(_steam):
		_steam.amount_ratio = 0.55


func get_sales() -> int:
	return _sales


func get_keeper() -> CharacterModel:
	return _keeper


## Kleine Gesten des Verkäufers, wenn gerade niemand kauft (vom Fest aufgerufen).
func idle_gesture(rng: RandomNumberGenerator) -> void:
	if not _open or _keeper.is_gesturing():
		return
	var poses := [CharacterModel.Pose.WARM_HANDS, CharacterModel.Pose.LOOK_UP, CharacterModel.Pose.HANDS_BEHIND,
		CharacterModel.Pose.WAVE]
	_keeper.play_gesture(poses[rng.randi() % poses.size()], 2.2)


func _add_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance


## Weicher Dampf über Topf oder Ofen.
func _make_steam() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 14.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.45
	process.gravity = Vector3(0.05, 0.12, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.4))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = grow
	process.scale_curve = scale_curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 0.35))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _puff()
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.name = "Steam"
	particles.amount = 10
	particles.lifetime = 2.4
	particles.amount_ratio = 0.55
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.local_coords = false
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	particles.visibility_range_end = 50.0
	return particles


static var _puff_texture: GradientTexture2D


static func _puff() -> GradientTexture2D:
	if _puff_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_puff_texture = GradientTexture2D.new()
		_puff_texture.gradient = gradient
		_puff_texture.fill = GradientTexture2D.FILL_RADIAL
		_puff_texture.fill_from = Vector2(0.5, 0.5)
		_puff_texture.fill_to = Vector2(0.5, 0.0)
		_puff_texture.width = 32
		_puff_texture.height = 32
	return _puff_texture
