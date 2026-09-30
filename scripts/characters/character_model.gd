@tool
## Knuffige Spielzeug-Figur im Stil der Dorfbewohner: großer runder Kopf,
## kleiner rundlicher Körper, kurze Beinchen, Fäustlinge und Mütze
## (Erwachsene ca. 1,45 m groß).
##
## Das Modell wird aus einer [CharacterAppearance] per Code gebaut – so
## sehen Spieler und alle Bewohner einheitlich aus, aber jede Figur hat
## eigene Farben, Oberteil, Frisur, Mütze, Statur und evtl. Gepäck.
##
## Animation (prozedural, ohne Animationsdateien), alles weich überblendet:
## - [method move] treibt die Fortbewegung: Schrittfrequenz, Beinschwung und
##   Armpendel hängen vom Tempo ab; Sprinten mit Vorlage und pumpenden Armen;
##   beim Anfahren lehnt sich die Figur leicht vor, beim Abbremsen zurück, in
##   Kurven legt sie sich hinein; beim Drehen auf der Stelle trippelt sie.
## - [method set_pose] blendet in eine Grundhaltung (Sitzen, Hände hinter dem
##   Rücken, Uhr ansehen …), [method play_gesture] spielt eine kurze Geste
##   (Armbanduhr, Winken, Dehnen, Nicken, Hände wärmen) und kehrt danach zurück.
## - Im Stehen atmet die Figur, verlagert das Gewicht, schaut sich um und blinzelt.
## Bei jedem Schritt meldet [signal footstep] den Bodenkontakt (für Schrittgeräusche).
class_name CharacterModel
extends Node3D

## Ein Fuß hat den Boden berührt.
signal footstep

enum Pose { STAND, SIT, LOOK_UP, CHECK_WATCH, WAVE, HANDS_BEHIND, STRETCH, WARM_HANDS, NOD, TALK }
## Gepäck in der Hand oder auf dem Rücken.
## MUG = heißer Becher (Glühwein, Most) in beiden Händen, LANTERN = Laterne am Stab (Laternenumzug).
enum Carry { NONE, SUITCASE, BACKPACK, SHOPPING_BAG, MUG, LANTERN }

const PLAID_SHADER := preload("res://assets/materials/plaid.gdshader")
## Augenhöhe über den Füßen (für die Ich-Perspektive).
const EYE_HEIGHT := 1.16
## Hüfthöhe einer Erwachsenen-Figur (Sitzhöhe = Sitzfläche minus diese Höhe).
const HIP_HEIGHT := 0.24
const HEAD_Y := 1.13
## Augenhöhe im Kopf (etwas unter der Mitte – das wirkt kindlich und freundlich).
const EYE_Y := 0.004
## Überblendgeschwindigkeit der Haltungen (1/s). Hinsetzen/Aufstehen ist langsamer.
const POSE_BLEND := 3.0
const SIT_BLEND := 1.7
## Kleine Details (Augen, Knöpfe, Brille …) werden ab dieser Entfernung nicht mehr gezeichnet.
const DETAIL_RANGE := 45.0

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
@export var carry := Carry.NONE:
	set(value):
		if value == carry:
			return
		carry = value
		if is_node_ready():
			_rebuild_carry()
## Temperament des Gangs: 0,7 = gemütlich schlendernd, 1,0 = normal, 1,2 = lebhaft.
@export_range(0.5, 1.4, 0.05) var gait_energy := 1.0
## Ab dieser Entfernung wird die ganze Figur nicht mehr gezeichnet (0 = immer sichtbar).
var view_distance := 0.0

var pose := Pose.STAND

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _hip_left: Node3D
var _hip_right: Node3D
var _shoulder_left: Node3D
var _shoulder_right: Node3D
var _carried: Node3D
var _meshes: Array[MeshInstance3D] = []
var _details: Array[MeshInstance3D] = []
var _eyes: Array[MeshInstance3D] = []
var _shadows_only := false
var _height := 1.0

# Fortbewegung (weich geglättet)
var _speed := 0.0
var _move_amount := 0.0
var _sprint := 0.0
var _lean := 0.0
var _roll := 0.0
var _phase := 0.0
var _last_step := 0
var _external_phase := false
var _target_amount := 0.0
var _target_sprint := 0.0
var _target_lean := 0.0
var _target_roll := 0.0

# Haltungen, Gesten, Leerlauf
var _base_pose := Pose.STAND
var _gesture_until := -1.0
var _gesture_start := 0.0
var _time := 0.0
var _weights := {}
var _glance := 0.0
var _glance_target := 0.0
var _glance_timer := 2.0
var _blink_timer := 3.0
var _blink := 0.0
var _rng := RandomNumberGenerator.new()
var _lantern_swing := 0.0

static var _material_cache := {}


func _ready() -> void:
	_rng.seed = hash(name) + get_instance_id()
	_time = _rng.randf() * 10.0
	for key: Pose in Pose.values():
		_weights[key] = 1.0 if key == Pose.STAND else 0.0
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_meshes.clear()
	_details.clear()
	_eyes.clear()

	var look := appearance if appearance else CharacterAppearance.new()
	var winter := outfit == CharacterAppearance.Outfit.WINTER
	_height = look.height_scale
	var skin := _material(look.skin_color, 0.5, 0.32)  # leicht glänzend wie Vinyl-Spielzeug
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
		# Dunkle Sohle
		_detail(_part(hip, _sphere(0.09, 14, 6), _material(look.shoe_color.darkened(0.45), 0.8), Vector3(0.0, -0.215, -0.035),
			Vector3(0.98, 0.3, 1.38)))

	# Rundlicher Rumpf: Hosenboden und Oberteil
	_torso = _pivot(_body, "Torso", Vector3.ZERO)
	_part(_torso, _sphere(0.235, 24, 12), pants, Vector3(0.0, 0.34, 0.0), Vector3(1.0, 0.66, 0.88))
	_build_top(look, winter, skin)

	_build_arms(look, winter, skin)
	_build_head(look, winter, skin)
	_build_carry(look)
	set_shadows_only(_shadows_only)
	if view_distance > 0.0:
		for mesh in _meshes:
			if not mesh in _details:
				mesh.visibility_range_end = view_distance
				mesh.visibility_range_end_margin = 10.0


## Fortbewegung für diesen Frame. [param speed] m/s, [param sprint] 0..1,
## [param accel] Beschleunigung in Laufrichtung (m/s², negativ = bremsen),
## [param turn_rate] Drehgeschwindigkeit (rad/s, positiv = links).
func move(speed: float, delta: float, sprint := 0.0, accel := 0.0, turn_rate := 0.0) -> void:
	_external_phase = false
	_speed = speed
	var relaxed := clampf(speed / 1.2, 0.0, 1.0)
	# Auf der Stelle drehen: kleine Trippelschritte
	var shuffle := clampf((absf(turn_rate) - 0.8) * 0.2, 0.0, 0.4) * (1.0 - relaxed)
	_target_amount = maxf(relaxed, shuffle)
	_target_sprint = sprint
	_target_lean = clampf(speed * 0.022 + sprint * 0.13 + clampf(accel, -4.0, 4.0) * 0.03, -0.12, 0.26)
	_target_roll = clampf(-turn_rate * minf(speed, 5.0) * 0.03, -0.2, 0.2)
	# Kurze Beine trippeln: Schrittfrequenz wächst mit dem Tempo (Schritte pro Sekunde)
	var cadence := clampf(1.7 + speed * 0.75, 1.9, 5.6) * lerpf(0.94, 1.06, gait_energy - 0.5)
	if shuffle > relaxed:
		cadence = 3.0
	if _target_amount > 0.01 or _move_amount > 0.05:
		_phase += delta * cadence * PI
	_emit_steps()


## Alte Schnittstelle: Laufbewegung mit fester Schrittphase (0 = Stehen, 1 = Gehen).
func animate(amount: float, phase: float) -> void:
	_external_phase = true
	_target_amount = amount
	_speed = amount * 1.1
	_phase = phase
	_emit_steps()


## Grundhaltung setzen (bleibt, bis eine andere gesetzt wird). Bricht Gesten ab.
func set_pose(new_pose: Pose) -> void:
	_base_pose = new_pose
	_gesture_until = -1.0
	pose = new_pose


## Kurze Geste für [param duration] Sekunden, danach zurück zur Grundhaltung.
func play_gesture(gesture: Pose, duration: float) -> void:
	pose = gesture
	_gesture_start = _time
	_gesture_until = _time + duration


func is_gesturing() -> bool:
	return _gesture_until > _time


## Wie weit die Haltung schon eingeblendet ist (0..1).
func get_pose_weight(which: Pose) -> float:
	return float(_weights.get(which, 0.0))


## Höhe der Hüfte über den Füßen (Sitzfläche minus diesen Wert = Standpunkt beim Sitzen).
func get_hip_height() -> float:
	return HIP_HEIGHT * _height


## Wie weit die Augen gerade offen sind (1 = offen, ~0,1 = beim Blinzeln zu) – für Tests.
func get_eye_openness() -> float:
	return 1.0 - sin(_blink * PI) * 0.9


## Aktuelle Vorlage des Oberkörpers (Bogenmaß, positiv = nach vorn) – für Tests.
func get_lean() -> float:
	return _lean


## Unsichtbar, aber mit Schatten (für die Ich-Perspektive).
func set_shadows_only(enabled: bool) -> void:
	_shadows_only = enabled
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if enabled \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in _meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mesh in _details else mode


## Gar keine Schatten (z.B. Verkäufer im Schatten ihrer Bude – spart Zeichenaufrufe).
func disable_shadows() -> void:
	for mesh in _meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	if _gesture_until >= 0.0 and _time >= _gesture_until:
		_gesture_until = -1.0
		pose = _base_pose
	for key: Pose in _weights:
		var target := 1.0 if pose == key else 0.0
		var rate := SIT_BLEND if key == Pose.SIT else POSE_BLEND
		_weights[key] = move_toward(float(_weights[key]), target, delta * rate)
	# Fortbewegung weich nachführen: nichts springt, Start und Stopp federn aus
	_move_amount = lerpf(_move_amount, _target_amount, 1.0 - exp(-(7.0 if _target_amount > _move_amount else 5.0) * delta))
	_sprint = lerpf(_sprint, _target_sprint, 1.0 - exp(-4.0 * delta))
	_lean = lerpf(_lean, _target_lean, 1.0 - exp(-5.0 * delta))
	_roll = lerpf(_roll, _target_roll, 1.0 - exp(-4.0 * delta))
	if not _external_phase and _target_amount < 0.01:
		_target_lean = lerpf(_target_lean, 0.0, 1.0 - exp(-3.0 * delta))
		_target_roll = 0.0
	_update_glance(delta)
	_update_blink(delta)
	_apply_animation()


# --- Animation --------------------------------------------------------------------

func _w(which: Pose) -> float:
	return smoothstep(0.0, 1.0, float(_weights[which]))


func _apply_animation() -> void:
	var sit_raw := float(_weights[Pose.SIT])
	var sit := smoothstep(0.0, 1.0, sit_raw)
	var look_up := _w(Pose.LOOK_UP)
	var watch := _w(Pose.CHECK_WATCH)
	var wave := _w(Pose.WAVE)
	var behind := _w(Pose.HANDS_BEHIND)
	var stretch := _w(Pose.STRETCH)
	var warm := _w(Pose.WARM_HANDS)
	var nod := _w(Pose.NOD)
	var talk := _w(Pose.TALK)
	var energy := gait_energy
	var walk := _move_amount * (1.0 - sit)
	var still := 1.0 - clampf(walk * 1.5, 0.0, 1.0)
	var breath := sin(_time * 1.6)
	var sprint := _sprint
	# Beim Hinsetzen und Aufstehen beugt sich die Figur kurz vor und stützt die Hände auf die Knie
	var sit_motion := sin(sit_raw * PI) * (1.0 - absf(sit_raw - 0.5) * 0.4)

	# Beine: Schwung wächst mit Tempo und Sprint; beim Sitzen baumeln sie
	var leg_amp := lerpf(0.42, 0.85, sprint) * lerpf(0.85, 1.1, energy - 0.5)
	var swing := sin(_phase) * leg_amp * walk
	var lift := maxf(0.0, sin(_phase + PI * 0.5)) * 0.12 * walk * (0.6 + sprint)  # Knie vorne leicht anheben
	var dangle := sin(_time * 1.3) * 0.12 * sit
	var weight_shift := sin(_time * 0.5) * still * (1.0 - sit)
	_hip_left.rotation.x = swing + lift * 0.3 + sit * 1.4 + dangle
	_hip_right.rotation.x = -swing + lift * 0.3 + sit * 1.4 - dangle
	_hip_left.rotation.z = -weight_shift * 0.03
	_hip_right.rotation.z = -weight_shift * 0.03

	# Arme: lockeres Pendeln, beim Sprinten angewinkelt und kräftiger
	var arm_amp := lerpf(0.5, 1.05, sprint) * lerpf(0.7, 1.1, energy - 0.5)
	var arm_swing := -sin(_phase) * arm_amp * walk
	var arm_forward := sprint * 0.45 * walk + sit * 0.55 + sit_motion * 0.5
	var arm_rest := breath * 0.03 * still
	var left_x := arm_swing + arm_forward
	var right_x := -arm_swing + arm_forward
	var left_z := -0.28 - arm_rest - sprint * 0.1 * walk
	var right_z := 0.28 + arm_rest + sprint * 0.1 * walk
	# Gepäck in der Hand: dieser Arm pendelt kaum und hängt gerade
	if carry == Carry.SUITCASE:
		right_x *= 0.25
		right_z = lerpf(right_z, 0.12, 1.0 - sit)
	elif carry == Carry.SHOPPING_BAG:
		left_x *= 0.3
		left_z = lerpf(left_z, -0.14, 1.0 - sit)
	# Hände hinter dem Rücken
	left_x = lerpf(left_x, -0.5, behind)
	right_x = lerpf(right_x, -0.5, behind)
	left_z = lerpf(left_z, -0.05, behind)
	right_z = lerpf(right_z, 0.05, behind)
	# Hände wärmen: vor der Brust aneinander reiben
	var rub := sin(_time * 14.0) * 0.08
	left_x = lerpf(left_x, 1.05 + rub, warm)
	right_x = lerpf(right_x, 1.05 - rub, warm)
	left_z = lerpf(left_z, 0.5, warm)
	right_z = lerpf(right_z, -0.5, warm)
	# Armbanduhr ansehen (linker Arm)
	left_x = lerpf(left_x, 1.3, watch)
	left_z = lerpf(left_z, 0.75, watch)
	# Winken (rechter Arm)
	right_x = lerpf(right_x, -0.2, wave)
	right_z = lerpf(right_z, 2.5 + sin(_time * 9.0) * 0.28, wave)
	# Erzählen: eine Hand vor dem Körper, die sich locker mitbewegt
	right_x = lerpf(right_x, 0.75 + sin(_time * 3.1) * 0.14, talk)
	right_z = lerpf(right_z, 0.4 + sin(_time * 2.3) * 0.08, talk)
	# Dehnen: beide Arme hoch über den Kopf
	var reach := sin(_time * 2.2) * 0.06
	left_x = lerpf(left_x, 0.15, stretch)
	right_x = lerpf(right_x, 0.15, stretch)
	left_z = lerpf(left_z, -2.75 - reach, stretch)
	right_z = lerpf(right_z, 2.75 + reach, stretch)
	_shoulder_left.rotation.x = left_x
	_shoulder_left.rotation.z = left_z
	_shoulder_right.rotation.x = right_x
	_shoulder_right.rotation.z = right_z

	# Rumpf: wippen, Hüftdrehung, Vorlage beim Anfahren/Sprinten, Schräglage in Kurven
	var bounce := absf(sin(_phase)) * (0.028 + sprint * 0.03) * walk * lerpf(0.8, 1.15, energy - 0.5)
	_body.position.y = bounce - sit * HIP_HEIGHT * _height + stretch * 0.03 + warm * absf(sin(_time * 5.0)) * 0.008
	_body.position.x = weight_shift * 0.012
	_body.rotation.x = -(_lean * (1.0 - sit) + sit_motion * 0.3) + stretch * 0.08
	_body.rotation.z = sin(_phase) * 0.045 * walk + _roll + weight_shift * 0.015
	_torso.rotation.y = sin(_phase) * 0.1 * walk
	_torso.scale = Vector3(1.0 - breath * 0.006, 1.0 + breath * 0.012 * still, 1.0)

	# Kopf: bleibt ruhig (gleicht Wippen und Schräglage aus), schaut sich um, nickt
	var nod_curve := maxf(0.0, sin((_time - _gesture_start) * 9.0)) * nod
	_head.rotation.x = look_up * 0.42 - watch * 0.38 + breath * 0.015 * still + (_lean + sit_motion * 0.3) * 0.6 \
		+ stretch * 0.35 - warm * 0.12 - nod_curve * 0.28 + behind * 0.06 + talk * sin(_time * 4.0) * 0.05
	_head.rotation.y = _glance * still * (1.0 - watch) * (1.0 - look_up) + watch * 0.3 - _torso.rotation.y * 0.8
	_head.rotation.z = sin(_time * 0.6) * 0.03 * still - _roll * 0.6 - sin(_phase) * 0.03 * walk

	# Wer mit der Hand, die das Gepäck trägt, eine Geste macht, stellt es kurz ab.
	var hand_busy := maxf(maxf(warm, stretch), maxf(behind, talk if carry == Carry.SUITCASE else watch))
	_lantern_swing = sin(_phase) * 0.18 * walk + sin(_time * 1.3) * 0.05
	if carry == Carry.SUITCASE:
		hand_busy = maxf(hand_busy, wave)
	_update_carried(sit, hand_busy)


## Ab und zu schaut die Figur ruhig zur Seite.
func _update_glance(delta: float) -> void:
	_glance_timer -= delta
	if _glance_timer <= 0.0:
		_glance_timer = _rng.randf_range(2.5, 6.0)
		_glance_target = 0.0 if _rng.randf() < 0.45 else _rng.randf_range(-0.6, 0.6)
	_glance = lerpf(_glance, _glance_target, 1.0 - exp(-2.0 * delta))


## Blinzeln: alle paar Sekunden schließen sich die Knopfaugen kurz.
func _update_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = _rng.randf_range(2.2, 5.5)
		_blink = 1.0
	_blink = maxf(0.0, _blink - delta * 7.0)
	var open := 1.0 - sin(_blink * PI) * 0.9
	for eye in _eyes:
		eye.scale.y = 1.15 * open


func _emit_steps() -> void:
	# Ein Schritt je halber Periode – nur, wenn wirklich gegangen wird.
	var step := floori(_phase / PI)
	if step != _last_step:
		_last_step = step
		if _target_amount > 0.3 or (_speed < 0.3 and _target_amount > 0.2):
			footstep.emit()


# --- Gepäck ----------------------------------------------------------------------------

## Koffer und Einkaufstasche hängen in der Hand, beim Sitzen stehen sie neben der Figur,
## bei Gesten mit dieser Hand kurz auf dem Boden.
func _update_carried(sit: float, hand_busy: float) -> void:
	if _carried == null or carry == Carry.BACKPACK:
		return
	if carry == Carry.MUG or carry == Carry.LANTERN:
		# In der rechten Hand; der Becher bleibt aufrecht, die Laterne pendelt am Stab
		var grip := to_local(_shoulder_right.to_global(Vector3(0.0, -0.33, 0.0)))
		_carried.position = grip
		_carried.rotation = Vector3.ZERO
		if carry == Carry.LANTERN and _carried.get_child_count() > 0:
			(_carried.get_child(0) as Node3D).rotation.x = _lantern_swing
		return
	var shoulder := _shoulder_right if carry == Carry.SUITCASE else _shoulder_left
	var hand := to_local(shoulder.to_global(Vector3(0.0, -0.33, 0.0)))
	var side := 1.0 if carry == Carry.SUITCASE else -1.0
	var beside := Vector3(side * 0.5, 0.0, -0.02)
	var on_ground := Vector3(side * 0.32, 0.29 if carry == Carry.SUITCASE else 0.26, -0.06)
	_carried.position = hand.lerp(on_ground, hand_busy).lerp(beside, sit)
	_carried.rotation = Vector3(0.0, 0.0, _body.rotation.z * 0.5 * (1.0 - sit) * (1.0 - hand_busy))


## Nur das Getragene neu bauen (z.B. wenn jemand am Stand einen Becher bekommt).
func _rebuild_carry() -> void:
	if _carried:
		for mesh in _carried.find_children("*", "MeshInstance3D", true, false):
			_meshes.erase(mesh)
			_details.erase(mesh)
		_carried.get_parent().remove_child(_carried)
		_carried.queue_free()
		_carried = null
	_build_carry(appearance if appearance else CharacterAppearance.new())
	if _carried:
		var alpha := 1.0 - (_meshes[0].transparency if not _meshes.is_empty() else 0.0)
		for mesh in _carried.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).transparency = 1.0 - alpha
			if view_distance > 0.0:
				(mesh as MeshInstance3D).visibility_range_end = view_distance


func _build_carry(look: CharacterAppearance) -> void:
	_carried = null
	if carry == Carry.NONE:
		return
	if carry == Carry.MUG or carry == Carry.LANTERN:
		_build_festive_carry(look)
		return
	var color := look.accent_color.lerp(look.shirt_color, 0.5)
	match carry:
		Carry.SUITCASE:
			_carried = _pivot(self, "Suitcase", Vector3.ZERO)
			var case_color := _material(Color(0.55, 0.33, 0.22).lerp(color, 0.25), 0.6)
			var trim := _material(Color(0.32, 0.2, 0.14), 0.5)
			var box := BoxMesh.new()
			box.size = Vector3(0.13, 0.27, 0.36)
			_part(_carried, box, case_color, Vector3(0.0, -0.17, 0.0))
			for z: float in [-0.12, 0.12]:
				var strap := BoxMesh.new()
				strap.size = Vector3(0.14, 0.275, 0.03)
				_part(_carried, strap, trim, Vector3(0.0, -0.17, z))
			var handle := BoxMesh.new()
			handle.size = Vector3(0.03, 0.04, 0.12)
			_part(_carried, handle, trim, Vector3(0.0, -0.01, 0.0))
		Carry.SHOPPING_BAG:
			_carried = _pivot(self, "ShoppingBag", Vector3.ZERO)
			var paper := _material(Color(0.78, 0.62, 0.42), 0.9)
			var bag := BoxMesh.new()
			bag.size = Vector3(0.12, 0.22, 0.2)
			_part(_carried, bag, paper, Vector3(0.0, -0.15, 0.0))
			# Ein Baguette und etwas Lauch schauen heraus
			var bread := _part(_carried, _capsule(0.028, 0.26, 8, 3), _material(Color(0.86, 0.62, 0.32), 0.8), Vector3(0.0, -0.02, 0.05))
			bread.rotation.x = 0.3
			var leek := _part(_carried, _capsule(0.02, 0.18, 8, 2), _material(Color(0.4, 0.62, 0.3), 0.8), Vector3(0.02, -0.02, -0.05))
			leek.rotation.x = -0.25
		Carry.BACKPACK:
			_carried = _pivot(_torso, "Backpack", Vector3.ZERO)
			var pack := _material(color.darkened(0.1), 0.85)
			_part(_carried, _capsule(0.15, 0.36, 12, 4), pack, Vector3(0.0, 0.6, 0.27), Vector3(1.0, 1.0, 0.6))
			_part(_carried, _sphere(0.12, 12, 6), _material(color.darkened(0.25), 0.85), Vector3(0.0, 0.7, 0.3), Vector3(1.1, 0.5, 0.7))
			for x: float in [-0.12, 0.12]:
				var strap := _part(_carried, _capsule(0.022, 0.4, 6, 2), pack, Vector3(x, 0.66, -0.02))
				strap.rotation.x = 0.1
				strap.scale = Vector3(1.0, 1.0, 0.5)



## Becher (rot mit weißem Stern, dampfend) oder Papierlaterne am Holzstab.
func _build_festive_carry(look: CharacterAppearance) -> void:
	_carried = _pivot(self, "Mug" if carry == Carry.MUG else "Lantern", Vector3.ZERO)
	if carry == Carry.MUG:
		var mug := _material(Color(0.72, 0.16, 0.14).lerp(look.accent_color, 0.2), 0.45)
		_part(_carried, _cylinder(0.042, 0.038, 0.1, 12), mug, Vector3(0.0, 0.03, -0.07))
		_part(_carried, _cylinder(0.036, 0.036, 0.004, 10), _material(Color(0.38, 0.06, 0.08), 0.2), Vector3(0.0, 0.078, -0.07))
		var handle := _part(_carried, _torus(0.012, 0.03, 10), mug, Vector3(0.05, 0.03, -0.07))
		handle.rotation.x = PI * 0.5
		# Ein Hauch Dampf
		var steam := _part(_carried, _sphere(0.03, 8, 4), _steam_material(), Vector3(0.0, 0.13, -0.07), Vector3(0.8, 1.6, 0.8))
		steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	# Laterne: Stab schräg nach vorne oben, Laterne hängt am Ende und pendelt
	var stick_pivot := _pivot(_carried, "Stick", Vector3.ZERO)
	var stick := _part(stick_pivot, _cylinder(0.01, 0.01, 0.62, 5), _material(Color(0.5, 0.34, 0.2), 0.8), Vector3(0.0, 0.2, -0.2))
	stick.rotation.x = -0.75
	var tip := Vector3(0.0, 0.42, -0.42)
	var string := _part(stick_pivot, _cylinder(0.003, 0.003, 0.12, 4), _material(Color(0.2, 0.18, 0.16), 0.8), tip - Vector3(0.0, 0.06, 0.0))
	string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var colors := [Color(1.0, 0.55, 0.2), Color(1.0, 0.8, 0.35), Color(0.95, 0.32, 0.25), Color(0.5, 0.8, 1.0)]
	var color: Color = colors[absi(hash(look.resource_path + str(look.shirt_color))) % colors.size()]
	var paper := StandardMaterial3D.new()
	paper.albedo_color = color
	paper.emission_enabled = true
	paper.emission = color
	paper.emission_energy_multiplier = 3.4
	paper.roughness = 0.6
	var lantern := _part(stick_pivot, _sphere(0.15, 12, 6), paper, tip - Vector3(0.0, 0.24, 0.0), Vector3(1.0, 0.85, 1.0))
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y: float in [-0.12, -0.36]:
		_part(stick_pivot, _cylinder(0.075, 0.075, 0.02, 10), _material(Color(0.2, 0.18, 0.16), 0.7), tip + Vector3(0.0, y, 0.0))
	var light := OmniLight3D.new()
	light.light_color = color.lerp(Color(1.0, 0.8, 0.5), 0.5)
	light.light_energy = 1.1
	light.omni_range = 3.2
	light.shadow_enabled = false
	light.position = tip - Vector3(0.0, 0.24, 0.0)
	stick_pivot.add_child(light)


static var _steam: StandardMaterial3D


static func _steam_material() -> StandardMaterial3D:
	if _steam == null:
		_steam = StandardMaterial3D.new()
		_steam.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
		_steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_steam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _steam


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
				_detail(_part(_torso, _sphere(0.018, 8, 4), accent, Vector3(0.0, 0.72 - i * 0.12, -0.245 + i * 0.012)))
		CharacterAppearance.TopStyle.SWEATER:
			var rib := _material(look.shirt_color.darkened(0.14), 0.95)
			_part(_torso, _torus(0.215, 0.26), rib, Vector3(0.0, 0.37, 0.0), Vector3(1.0, 1.0, 0.9))
			if winter:
				_part(_torso, _torus(0.1, 0.16), rib, Vector3(0.0, 0.86, 0.0))
		CharacterAppearance.TopStyle.COAT:
			# Etwas längerer Mantel mit Knopfleiste und Kragen
			_part(_torso, _cylinder(0.262, 0.29, 0.22, 24), top, Vector3(0.0, 0.34, 0.0), Vector3(1.0, 1.0, 0.9))
			for i in 3:
				_detail(_part(_torso, _sphere(0.022, 8, 4), accent, Vector3(0.0, 0.66 - i * 0.13, -0.25 + i * 0.006)))
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
		if hand != skin:
			# Gestricktes Bündchen am Fäustling
			_detail(_part(shoulder, _torus(0.05, 0.078, 14), _material(look.hat_color.lightened(0.1), 1.0),
				Vector3(0.0, -0.265, 0.0), Vector3(1.0, 1.4, 1.0)))


func _build_head(look: CharacterAppearance, winter: bool, skin: Material) -> void:
	_head = _pivot(_body, "Head", Vector3(0.0, HEAD_Y, 0.0))
	var head_size := look.head_scale
	_head.scale = Vector3(head_size / look.width_scale, head_size / look.height_scale, head_size / look.width_scale)
	_part(_head, _sphere(0.3, 32, 16), skin, Vector3.ZERO, Vector3(1.0, 0.94, 0.97))
	for x: float in [-0.29, 0.29]:
		_part(_head, _sphere(0.055, 10, 5), skin, Vector3(x, -0.01, 0.01), Vector3(0.6, 1.0, 1.0))

	# Gesicht: nur Knopfaugen, Näschen und rosige Wangen
	var eyes := _material(Color(0.08, 0.065, 0.06), 0.3)
	# Kindchenschema: Augen etwas tiefer und weiter auseinander, mit kleinem Glanzpunkt
	var catchlight := _material(Color(1.0, 0.98, 0.94), 0.2)
	for x: float in [-0.105, 0.105]:
		var eye := _part(_head, _sphere(0.031, 12, 6), eyes, Vector3(x, EYE_Y, -0.27), Vector3(0.9, 1.15, 0.55))
		_eyes.append(eye)
		_detail(eye)
		# Glanzpunkt als Kind des Auges – blinzelt mit
		_detail(_part(eye, _sphere(0.012, 6, 3), catchlight, Vector3(0.011, 0.012, -0.031)))
	_detail(_part(_head, _sphere(0.042, 12, 6), _material(look.skin_color.darkened(0.07), 0.55, 0.3), Vector3(0.0, -0.058, -0.283)))
	var blush := _material(look.skin_color.lerp(Color(0.96, 0.45, 0.42), 0.36), 0.8)
	for x: float in [-0.17, 0.17]:
		_detail(_part(_head, _sphere(0.052, 10, 5), blush, Vector3(x, -0.078, -0.232), Vector3(1.0, 0.6, 0.4)))

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
		for x: float in [-0.105, 0.105]:
			var lens := _detail(_part(_head, _torus(0.047, 0.061, 18), frame, Vector3(x, EYE_Y, -0.284)))
			lens.rotation.x = PI * 0.5
		var bridge := BoxMesh.new()
		bridge.size = Vector3(0.075, 0.014, 0.014)
		_part(_head, bridge, frame, Vector3(0.0, EYE_Y + 0.01, -0.295))


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
		CharacterAppearance.HairStyle.LONG:
			# Lange, wellige Haare: fallen hinten bis auf die Schultern und rahmen das
			# Gesicht mit zwei Strähnen, die unten in einer weichen Welle enden.
			if not under_hat:
				var cap := _part(_head, _sphere(0.315, 28, 14, true), hair, Vector3(0.0, 0.03, 0.02))
				cap.rotation.x = -0.3
			_part(_head, _sphere(0.27, 20, 10), hair, Vector3(0.0, -0.12, 0.13), Vector3(1.12, 1.3, 0.8))
			for x: float in [-0.25, 0.25]:
				_part(_head, _sphere(0.13, 14, 7), hair, Vector3(x, -0.12, 0.02), Vector3(0.62, 1.45, 0.95))
				_part(_head, _sphere(0.085, 12, 6), hair, Vector3(x * 1.08, -0.31, 0.05), Vector3(1.0, 0.9, 1.0))
				_part(_head, _sphere(0.08, 12, 6), hair, Vector3(x * 0.75, -0.34, 0.16))


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


## Kleines Detail: wirft keinen Schatten und wird aus der Ferne nicht gezeichnet.
func _detail(mesh: MeshInstance3D) -> MeshInstance3D:
	mesh.visibility_range_end = DETAIL_RANGE
	mesh.visibility_range_end_margin = 5.0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_details.append(mesh)
	return mesh
