@tool
## Knuffige Spielzeug-Figur im Stil der Dorfbewohner: großer runder Kopf,
## kleiner rundlicher Körper, kurze Beinchen, Fäustlinge und Mütze
## (Erwachsene ca. 1,45 m groß).
##
## Das Modell wird aus einer [CharacterAppearance] per Code gebaut – so
## sehen Spieler und alle Bewohner einheitlich aus, aber jede Figur hat
## eigene Farben, Oberteil, Frisur, Mütze und Statur.
##
## Animation (prozedural, ohne Animationsdateien):
## - [method animate] setzt die Laufbewegung (Beine, Arme, Wippen),
## - [method set_pose] blendet ruhig in eine Haltung (Sitzen, Uhr ansehen …),
## - dazu atmet die Figur im Stehen sanft und schaut sich ab und zu um.
## Bei jedem Schritt meldet [signal footstep] den Bodenkontakt (für Schrittgeräusche).
class_name CharacterModel
extends Node3D

## Ein Fuß hat den Boden berührt.
signal footstep

enum Pose { STAND, SIT, LOOK_UP, CHECK_WATCH, WAVE }

const PLAID_SHADER := preload("res://assets/materials/plaid.gdshader")
## Augenhöhe über den Füßen (für die Ich-Perspektive).
const EYE_HEIGHT := 1.16
## Hüfthöhe einer Erwachsenen-Figur (Sitzhöhe = Sitzfläche minus diese Höhe).
const HIP_HEIGHT := 0.24
const HEAD_Y := 1.13
const POSE_BLEND := 3.5

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			rebuild()
## Winter- oder Sommerkleidung (Grundlage für spätere Jahreszeiten).
@export var outfit := CharacterAppearance.Outfit.WINTER:
	set(value):
		outfit = value
		if is_node_ready():
			rebuild()

var pose := Pose.STAND

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _hip_left: Node3D
var _hip_right: Node3D
var _shoulder_left: Node3D
var _shoulder_right: Node3D
var _meshes: Array[MeshInstance3D] = []
var _shadows_only := false
var _height := 1.0

# Animationszustand
var _walk_amount := 0.0
var _walk_phase := 0.0
var _last_step := 0
var _time := 0.0
var _weights := {Pose.SIT: 0.0, Pose.LOOK_UP: 0.0, Pose.CHECK_WATCH: 0.0, Pose.WAVE: 0.0}
var _glance := 0.0
var _glance_target := 0.0
var _glance_timer := 2.0
var _rng := RandomNumberGenerator.new()

static var _material_cache := {}


func _ready() -> void:
	_rng.seed = hash(name) + get_instance_id()
	_time = _rng.randf() * 10.0
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_meshes.clear()

	var look := appearance if appearance else CharacterAppearance.new()
	var winter := outfit == CharacterAppearance.Outfit.WINTER
	_height = look.height_scale
	var skin := _material(look.skin_color, 0.65, 0.25)
	var pants := _material(look.pants_color, 0.9)
	var shoes := _material(look.shoe_color, 0.55)

	_body = _pivot(self, "Body", Vector3.ZERO)
	_body.scale = Vector3(look.width_scale, look.height_scale, look.width_scale)

	# Kurze Beinchen mit kleinen runden Schuhen
	_hip_left = _pivot(_body, "HipLeft", Vector3(-0.1, HIP_HEIGHT, 0.0))
	_hip_right = _pivot(_body, "HipRight", Vector3(0.1, HIP_HEIGHT, 0.0))
	for hip in [_hip_left, _hip_right]:
		_part(hip, _capsule(0.078, 0.26), pants, Vector3(0.0, -0.1, 0.0))
		_part(hip, _sphere(0.088, 16, 8), shoes, Vector3(0.0, -0.195, -0.035), Vector3(0.95, 0.58, 1.35))

	# Rundlicher Rumpf: Hosenboden und Oberteil
	_torso = _pivot(_body, "Torso", Vector3.ZERO)
	_part(_torso, _sphere(0.235, 24, 12), pants, Vector3(0.0, 0.34, 0.0), Vector3(1.0, 0.66, 0.88))
	_build_top(look, winter, skin)

	_build_arms(look, winter, skin)
	_build_head(look, winter, skin)
	set_shadows_only(_shadows_only)


## Laufbewegung setzen. [param amount] 0 = Stehen, 1 = Gehen; [param phase] Schrittphase.
func animate(amount: float, phase: float) -> void:
	_walk_amount = amount
	_walk_phase = phase
	# Ein Schritt je halber Periode – nur, wenn wirklich gegangen wird.
	var step := floori(phase / PI)
	if step != _last_step:
		_last_step = step
		if amount > 0.35:
			footstep.emit()


## Ruhig in eine Haltung überblenden (Sitzen, Uhr ansehen, winken …).
func set_pose(new_pose: Pose) -> void:
	pose = new_pose


## Wie weit die Haltung schon eingeblendet ist (0..1).
func get_pose_weight(which: Pose) -> float:
	return float(_weights.get(which, 1.0 if which == Pose.STAND else 0.0))


## Höhe der Hüfte über den Füßen (Sitzfläche minus diesen Wert = Standpunkt beim Sitzen).
func get_hip_height() -> float:
	return HIP_HEIGHT * _height


## Unsichtbar, aber mit Schatten (für die Ich-Perspektive).
func set_shadows_only(enabled: bool) -> void:
	_shadows_only = enabled
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in _meshes:
		mesh.cast_shadow = mode


## Sanft ein-/ausblenden (1 = sichtbar, 0 = unsichtbar), z.B. beim Heimgehen.
func set_fade(alpha: float) -> void:
	var transparency := clampf(1.0 - alpha, 0.0, 1.0)
	for mesh in _meshes:
		mesh.transparency = transparency
	visible = alpha > 0.01


func get_mesh_count() -> int:
	return _meshes.size()


## Materialien werden zwischen allen Figuren geteilt (spart Speicher und Draw-Setup).
static func clear_cache() -> void:
	_material_cache.clear()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	_time += delta
	for key: Pose in _weights:
		var target := 1.0 if pose == key else 0.0
		_weights[key] = move_toward(float(_weights[key]), target, delta * POSE_BLEND)
	_update_glance(delta)
	_apply_animation()


# --- Animation --------------------------------------------------------------------

func _apply_animation() -> void:
	var sit := smoothstep(0.0, 1.0, float(_weights[Pose.SIT]))
	var look_up := smoothstep(0.0, 1.0, float(_weights[Pose.LOOK_UP]))
	var watch := smoothstep(0.0, 1.0, float(_weights[Pose.CHECK_WATCH]))
	var wave := smoothstep(0.0, 1.0, float(_weights[Pose.WAVE]))
	var walk := _walk_amount * (1.0 - sit)
	var swing := sin(_walk_phase) * 0.6 * walk
	var still := 1.0 - clampf(walk * 1.5, 0.0, 1.0)
	var breath := sin(_time * 1.7)

	# Beine: gehen oder beim Sitzen nach vorne (die kurzen Beinchen baumeln)
	var dangle := sin(_time * 1.3) * 0.12 * sit
	_hip_left.rotation.x = swing + sit * 1.4 + dangle
	_hip_right.rotation.x = -swing + sit * 1.4 - dangle

	# Arme: pendeln beim Gehen, liegen beim Sitzen im Schoß
	var arm_rest := breath * 0.03 * still
	_shoulder_left.rotation.x = -swing * 0.8 + sit * 0.55 + watch * 1.3
	_shoulder_left.rotation.z = -0.28 - arm_rest + watch * 0.75
	_shoulder_right.rotation.x = swing * 0.8 + sit * 0.55 - wave * 0.2
	_shoulder_right.rotation.z = 0.28 + arm_rest + wave * (2.3 + sin(_time * 9.0) * 0.25)

	# Rumpf: wippen beim Gehen, atmen im Stehen, beim Sitzen abgesenkt
	_body.position.y = absf(sin(_walk_phase)) * 0.035 * walk - sit * HIP_HEIGHT * _height
	_body.rotation.z = sin(_walk_phase) * 0.05 * walk + sin(_time * 0.45) * 0.012 * still
	_torso.scale = Vector3(1.0 - breath * 0.006, 1.0 + breath * 0.012 * still, 1.0)

	# Kopf: schaut sich um, nach oben (Uhr) oder aufs Handgelenk
	_head.rotation.x = look_up * 0.42 - watch * 0.38 + breath * 0.015 * still
	_head.rotation.y = _glance * still * (1.0 - watch) * (1.0 - look_up) + watch * 0.3
	_head.rotation.z = sin(_time * 0.6) * 0.03 * still


## Ab und zu schaut die Figur ruhig zur Seite.
func _update_glance(delta: float) -> void:
	_glance_timer -= delta
	if _glance_timer <= 0.0:
		_glance_timer = _rng.randf_range(2.5, 6.0)
		_glance_target = 0.0 if _rng.randf() < 0.45 else _rng.randf_range(-0.55, 0.55)
	_glance = lerpf(_glance, _glance_target, 1.0 - exp(-2.0 * delta))


# --- Aufbau -----------------------------------------------------------------------

## Im Sommer werden Pulli und Mantel zum T-Shirt in derselben Farbe.
func _effective_top(look: CharacterAppearance, winter: bool) -> CharacterAppearance.TopStyle:
	if not winter and look.top_style != CharacterAppearance.TopStyle.PLAID_SHIRT:
		return CharacterAppearance.TopStyle.SWEATER
	return look.top_style


func _build_top(look: CharacterAppearance, winter: bool, _skin: Material) -> void:
	var style := _effective_top(look, winter)
	var top := _top_material(look, style)
	var accent := _material(look.accent_color, 0.6)
	_part(_torso, _sphere(0.27, 28, 14), top, Vector3(0.0, 0.58, 0.0), Vector3(1.0, 1.12, 0.9))
	match style:
		CharacterAppearance.TopStyle.PLAID_SHIRT:
			for i in 3:
				_part(_torso, _sphere(0.018, 8, 4), accent, Vector3(0.0, 0.72 - i * 0.12, -0.245 + i * 0.012))
		CharacterAppearance.TopStyle.SWEATER:
			var rib := _material(look.shirt_color.darkened(0.14), 0.95)
			_part(_torso, _torus(0.215, 0.26), rib, Vector3(0.0, 0.37, 0.0), Vector3(1.0, 1.0, 0.9))
			if winter:
				_part(_torso, _torus(0.1, 0.16), rib, Vector3(0.0, 0.86, 0.0))
		CharacterAppearance.TopStyle.COAT:
			# Etwas längerer Mantel mit Knopfleiste und Kragen
			_part(_torso, _cylinder(0.262, 0.29, 0.22, 24), top, Vector3(0.0, 0.34, 0.0), Vector3(1.0, 1.0, 0.9))
			for i in 3:
				_part(_torso, _sphere(0.022, 8, 4), accent, Vector3(0.0, 0.66 - i * 0.13, -0.25 + i * 0.006))
			_part(_torso, _torus(0.12, 0.19), top, Vector3(0.0, 0.85, 0.0))


func _build_arms(look: CharacterAppearance, winter: bool, skin: Material) -> void:
	var top := _top_material(look, _effective_top(look, winter))
	var hand := _material(look.scarf_color.lerp(look.hat_color, 0.35), 0.95) if winter and look.mittens else skin
	_shoulder_left = _pivot(_body, "ShoulderLeft", Vector3(-0.25, 0.8, 0.0))
	_shoulder_right = _pivot(_body, "ShoulderRight", Vector3(0.25, 0.8, 0.0))
	for shoulder in [_shoulder_left, _shoulder_right]:
		if winter:
			_part(shoulder, _capsule(0.072, 0.36, 14, 5), top, Vector3(0.0, -0.13, 0.0))
		else:
			_part(shoulder, _capsule(0.074, 0.18, 14, 4), top, Vector3(0.0, -0.05, 0.0))
			_part(shoulder, _capsule(0.056, 0.28, 12, 4), skin, Vector3(0.0, -0.17, 0.0))
		# Einfache runde Hände (im Winter Fäustlinge)
		_part(shoulder, _sphere(0.072 if hand != skin else 0.064, 14, 7), hand, Vector3(0.0, -0.32, -0.005))


func _build_head(look: CharacterAppearance, winter: bool, skin: Material) -> void:
	_head = _pivot(_body, "Head", Vector3(0.0, HEAD_Y, 0.0))
	var head_size := look.head_scale
	_head.scale = Vector3(head_size / look.width_scale, head_size / look.height_scale, head_size / look.width_scale)
	_part(_head, _sphere(0.3, 32, 16), skin, Vector3.ZERO, Vector3(1.0, 0.94, 0.97))
	for x: float in [-0.29, 0.29]:
		_part(_head, _sphere(0.055, 10, 5), skin, Vector3(x, -0.01, 0.01), Vector3(0.6, 1.0, 1.0))

	# Gesicht: nur Knopfaugen, Näschen und rosige Wangen
	var eyes := _material(Color(0.08, 0.065, 0.06), 0.3)
	for x: float in [-0.1, 0.1]:
		_part(_head, _sphere(0.031, 12, 6), eyes, Vector3(x, 0.025, -0.268), Vector3(0.9, 1.15, 0.55))
	_part(_head, _sphere(0.046, 12, 6), _material(look.skin_color.darkened(0.07), 0.65), Vector3(0.0, -0.045, -0.283))
	var blush := _material(look.skin_color.lerp(Color(0.95, 0.45, 0.42), 0.32), 0.8)
	for x: float in [-0.165, 0.165]:
		_part(_head, _sphere(0.05, 10, 5), blush, Vector3(x, -0.065, -0.235), Vector3(1.0, 0.6, 0.4))

	if look.beard:
		var beard := _material(look.hair_color, 0.95)
		_part(_head, _sphere(0.24, 20, 10), beard, Vector3(0.0, -0.125, -0.1), Vector3(1.04, 0.8, 0.82))

	var hat_style := look.hat_style if winter else CharacterAppearance.HatStyle.NONE
	_build_hair(look, hat_style != CharacterAppearance.HatStyle.NONE)
	_build_hat(look, hat_style)

	if winter and look.scarf:
		var scarf := _material(look.scarf_color, 1.0)
		var ring := _part(_body, _torus(0.13, 0.225), scarf, Vector3(0.0, 0.855, 0.0))
		ring.scale = Vector3(1.0, 1.25, 0.95)
		var tail := _part(_body, _capsule(0.05, 0.22, 10, 3), scarf, Vector3(0.09, 0.73, -0.232), Vector3(1.15, 1.0, 0.6))
		tail.rotation = Vector3(-0.12, 0.0, 0.12)

	if look.glasses:
		var frame := _material(look.glasses_color, 0.35)
		for x: float in [-0.1, 0.1]:
			var lens := _part(_head, _torus(0.047, 0.061, 18), frame, Vector3(x, 0.025, -0.282))
			lens.rotation.x = PI * 0.5
		var bridge := BoxMesh.new()
		bridge.size = Vector3(0.075, 0.014, 0.014)
		_part(_head, bridge, frame, Vector3(0.0, 0.035, -0.293))


func _build_hair(look: CharacterAppearance, under_hat: bool) -> void:
	var hair := _material(look.hair_color, 0.9)
	match look.hair_style:
		CharacterAppearance.HairStyle.SHORT:
			if not under_hat:
				var cap := _part(_head, _sphere(0.31, 28, 14, true), hair, Vector3(0.0, 0.03, 0.02))
				cap.rotation.x = -0.35
		CharacterAppearance.HairStyle.SIDES:
			for x: float in [-0.265, 0.265]:
				_part(_head, _sphere(0.12, 12, 6), hair, Vector3(x, 0.02, 0.06), Vector3(0.55, 0.85, 1.2))
			_part(_head, _sphere(0.2, 16, 8), hair, Vector3(0.0, 0.0, 0.16), Vector3(1.2, 0.7, 0.6))
		CharacterAppearance.HairStyle.BOB:
			if not under_hat:
				var cap := _part(_head, _sphere(0.315, 28, 14, true), hair, Vector3(0.0, 0.02, 0.03))
				cap.rotation.x = -0.3
			for x: float in [-0.25, 0.25]:
				_part(_head, _sphere(0.14, 14, 7), hair, Vector3(x, -0.06, 0.04), Vector3(0.6, 1.15, 1.05))
			_part(_head, _sphere(0.24, 18, 9), hair, Vector3(0.0, -0.04, 0.13), Vector3(1.1, 0.9, 0.7))
		CharacterAppearance.HairStyle.BUN:
			if not under_hat:
				var cap := _part(_head, _sphere(0.31, 28, 14, true), hair, Vector3(0.0, 0.03, 0.02))
				cap.rotation.x = -0.35
				_part(_head, _sphere(0.1, 14, 7), hair, Vector3(0.0, 0.2, 0.22))
			else:
				_part(_head, _sphere(0.1, 14, 7), hair, Vector3(0.0, -0.02, 0.29))
			for x: float in [-0.25, 0.25]:
				_part(_head, _sphere(0.1, 12, 6), hair, Vector3(x, -0.02, 0.07), Vector3(0.55, 0.9, 1.1))
		CharacterAppearance.HairStyle.PONYTAIL:
			if not under_hat:
				var cap := _part(_head, _sphere(0.31, 28, 14, true), hair, Vector3(0.0, 0.03, 0.02))
				cap.rotation.x = -0.35
			var tail := _part(_head, _capsule(0.07, 0.3, 12, 4), hair, Vector3(0.0, -0.1, 0.3))
			tail.rotation.x = 0.35
			var tie := _part(_head, _torus(0.035, 0.065), _material(look.scarf_color, 0.6), Vector3(0.0, 0.0, 0.295))
			tie.rotation.x = PI * 0.5
		CharacterAppearance.HairStyle.CURLY:
			for i in 16:
				var angle := TAU * i / 16.0
				var up := 0.15 + 0.35 * float(i % 2)
				var direction := Vector3(cos(angle) * cos(up), sin(up), sin(angle) * cos(up))
				if direction.z < -0.35 and direction.y < 0.5:
					continue  # Gesicht frei lassen
				if under_hat and direction.y > 0.3:
					continue
				_part(_head, _sphere(0.085, 10, 5), hair, direction * 0.28 + Vector3(0.0, 0.02, 0.0))
			if not under_hat:
				_part(_head, _sphere(0.1, 10, 5), hair, Vector3(0.0, 0.28, 0.02))


func _build_hat(look: CharacterAppearance, hat_style: CharacterAppearance.HatStyle) -> void:
	var hat := _material(look.hat_color, 1.0)
	match hat_style:
		CharacterAppearance.HatStyle.BEANIE, CharacterAppearance.HatStyle.POMPOM_BEANIE:
			_part(_head, _sphere(0.318, 28, 14, true), hat, Vector3(0.0, 0.075, 0.0), Vector3(1.0, 1.04, 1.0))
			# Weicher, gerollter Umschlag statt harter Kante
			_part(_head, _torus(0.28, 0.345, 32), _material(look.hat_color.darkened(0.1), 1.0),
				Vector3(0.0, 0.1, 0.0), Vector3(1.0, 1.3, 1.0))
			if hat_style == CharacterAppearance.HatStyle.POMPOM_BEANIE:
				_part(_head, _sphere(0.085, 14, 7), _material(look.scarf_color.lightened(0.15), 1.0),
					Vector3(0.0, 0.42, 0.0))
		CharacterAppearance.HatStyle.FLAT_CAP:
			_part(_head, _sphere(0.325, 28, 14, true), hat, Vector3(0.0, 0.1, 0.02), Vector3(1.02, 0.55, 1.08))
			_part(_head, _sphere(0.17, 16, 6), hat, Vector3(0.0, 0.11, -0.27), Vector3(1.35, 0.16, 0.9))


# --- Bausteine ------------------------------------------------------------------

func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, part_scale := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.scale = part_scale
	parent.add_child(instance)
	_meshes.append(instance)
	return instance


func _sphere(radius: float, segments: int, rings: int, hemisphere := false) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * (1.0 if hemisphere else 2.0)
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.is_hemisphere = hemisphere
	return mesh


func _cylinder(top: float, bottom: float, height: float, segments := 14) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _capsule(radius: float, height: float, segments := 20, rings := 6) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _torus(inner: float, outer: float, segments := 24) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = segments
	mesh.ring_segments = 10
	return mesh


## Weiches, leicht samtiges Material (Randlicht lässt die Figuren wie Spielzeug wirken).
func _material(color: Color, roughness: float, rim := 0.15) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, rim]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.rim_enabled = rim > 0.0
	material.rim = rim
	material.rim_tint = 0.6
	_material_cache[key] = material
	return material


func _top_material(look: CharacterAppearance, style: CharacterAppearance.TopStyle) -> Material:
	if style != CharacterAppearance.TopStyle.PLAID_SHIRT:
		return _material(look.shirt_color, 0.95, 0.2)
	var key := "plaid|%s|%s|%s" % [look.shirt_color.to_html(), look.shirt_stripe_color.to_html(),
		look.shirt_line_color.to_html()]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = PLAID_SHADER
	material.set_shader_parameter(&"base_color", look.shirt_color)
	material.set_shader_parameter(&"stripe_color", look.shirt_stripe_color)
	material.set_shader_parameter(&"line_color", look.shirt_line_color)
	_material_cache[key] = material
	return material
