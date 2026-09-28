## Baustelle eines Hauses (Kind von [VillageHouse], lokal zum Haus).
##
## - Bauzaun rundum (mit Einfahrt vor der Haustür), Baustellenschild, Laterne
## - Gerüst, das Etage für Etage mit dem Rohbau wächst
## - Materialstapel je Baumaterial, die mit dem Verbrauch kleiner werden
## - kleiner Baukran, der langsam schwenkt und Lasten hebt
## - zwei Bauarbeiter, die zwischen Stapel und Haus hin- und hergehen
## - Hammer- und Sägegeräusche während der Arbeitszeit
## Nachts ruht die Baustelle: Arbeiter sind heim, nur die Laterne brennt.
class_name ConstructionSite
extends Node3D

const FENCE_MARGIN := 1.5
const PANEL := 2.3
const WORK_SOUNDS := ["hammer", "saw", "hammer"]

var material: Material
var _size := Vector2(8, 8)
var _center := Vector2.ZERO
var _height := 6.0
var _door := Vector3(0, 0, -4)
var _cost := {}
var _levels: Array[MeshInstance3D] = []
var _stacks := {}
var _crane_top: Node3D
var _crane_hook: Node3D
var _crane_rope: MeshInstance3D
var _crane_jib := 6.0
var _crane_height := 8.0
var _workers: Array[Dictionary] = []
var _lamp: OmniLight3D
var _glow: StandardMaterial3D
var _sound: AudioStreamPlayer3D
var _progress := 0.0
var _working := false
var _time := 0.0
var _sound_timer := 2.0
var _rng := RandomNumberGenerator.new()


## [param size]/[param center]: Grundfläche des Hauses (lokal), [param height]: Firsthöhe,
## [param door]: Haustür (lokal), [param cost]: Baukosten (Materialstapel).
func setup(size: Vector2, center: Vector2, height: float, door: Vector3, cost: Dictionary, body_material: Material,
		seed_value: int) -> void:
	_size = size
	_center = center
	_height = height
	_door = door
	_cost = cost
	material = body_material
	_rng.seed = seed_value
	name = "ConstructionSite"
	var glow_source := VillageCatalog.GLOW_MATERIAL as StandardMaterial3D
	_glow = glow_source.duplicate() if glow_source else StandardMaterial3D.new()
	_build_fence()
	_build_scaffold()
	_build_stacks()
	_build_crane()
	_build_workers()
	_sound = AudioStreamPlayer3D.new()
	_sound.max_distance = 45.0
	_sound.unit_size = 5.0
	_sound.volume_db = -13.0
	_sound.position = Vector3(_center.x, 2.0, _center.y)
	add_child(_sound)
	SoundLibrary.stop_on_exit(_sound)


func _add(mesh: Mesh, pos: Vector3, rot := 0.0, mat: Material = null, shadows := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat if mat else material
	instance.position = pos
	instance.rotation.y = rot
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Bauzaun rund um das Grundstück, vor der Haustür bleibt eine Lücke.
func _build_fence() -> void:
	var half := _size * 0.5 + Vector2(FENCE_MARGIN, FENCE_MARGIN)
	var corners := [_center + Vector2(-half.x, -half.y), _center + Vector2(half.x, -half.y),
		_center + Vector2(half.x, half.y), _center + Vector2(-half.x, half.y)]
	var door2 := Vector2(_door.x, _door.z)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var count := maxi(1, roundi(length / PANEL))
		var panel := length / count
		var dir := (b - a) / length
		for k in count:
			var mid := a + dir * panel * (k + 0.5)
			# Einfahrt vor der Tür frei lassen
			if mid.distance_to(door2) < 2.2:
				continue
			_add(ConstructionMeshes.fence_panel(panel - 0.05), Vector3(mid.x, 0, mid.y), -atan2(dir.y, dir.x), null, false)
	# Schild und Laterne neben der Einfahrt
	var out := (door2 - _center).normalized()
	var side := Vector2(-out.y, out.x)
	var gate := door2 + out * (FENCE_MARGIN - 0.2)
	var sign_pos := gate + side * 2.6
	_add(ConstructionMeshes.site_sign(), Vector3(sign_pos.x, 0, sign_pos.y), atan2(out.x, out.y) + PI)
	var label := Label3D.new()
	label.text = "Hier entsteht\nein neues Zuhause"
	label.font_size = 36
	label.pixel_size = 0.0045
	label.modulate = Color(0.35, 0.2, 0.12)
	label.outline_size = 0
	label.position = Vector3(sign_pos.x, 1.36, sign_pos.y) + Vector3(out.x, 0, out.y) * 0.04
	label.rotation.y = atan2(out.x, out.y)
	add_child(label)
	var lamp_pos := gate - side * 2.3
	var lamp := ConstructionMeshes.site_lamp()
	_add(lamp["body"], Vector3(lamp_pos.x, 2.05, lamp_pos.y), 0.0, null, false)
	_add(lamp["glow"], Vector3(lamp_pos.x, 2.05, lamp_pos.y), 0.0, _glow, false)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(lamp_pos.x, 2.3, lamp_pos.y)
	_lamp.light_color = VillageVisual.LIGHT_COLOR
	_lamp.omni_range = 6.0
	_lamp.omni_attenuation = 1.4
	_lamp.light_energy = 0.0
	_lamp.visible = false
	_lamp.distance_fade_enabled = true
	_lamp.distance_fade_begin = 60.0
	_lamp.distance_fade_length = 20.0
	add_child(_lamp)


## Gerüst: eine Etage je 1,9 m, sichtbar bis knapp über der Baukante.
func _build_scaffold() -> void:
	var walls := _size - Vector2(0.8, 0.8) + Vector2(0.4, 0.4)
	var count := maxi(1, ceili((_height * 0.72) / ConstructionMeshes.SCAFFOLD_LEVEL))
	for i in count:
		var level := _add(ConstructionMeshes.scaffold_level(walls, i == count - 1),
			Vector3(_center.x, i * ConstructionMeshes.SCAFFOLD_LEVEL, _center.y), 0.0, null, i == 0)
		level.visible = false
		_levels.append(level)


## Materialstapel entlang der Seiten (nur für Material, das der Bau braucht).
func _build_stacks() -> void:
	var goods_order := ["wood", "brick", "glass", "steel", "stone"]
	var half := _size * 0.5
	var spots := [Vector3(-half.x - 0.75, 0, -half.y * 0.35), Vector3(-half.x - 0.75, 0, half.y * 0.45),
		Vector3(half.x * 0.1, 0, half.y + 0.75), Vector3(-half.x * 0.55, 0, half.y + 0.75), Vector3(half.x + 0.75, 0, 0.0)]
	var k := 0
	for goods_id: String in goods_order:
		if int(_cost.get(goods_id, 0)) <= 0:
			continue
		var spot: Vector3 = spots[k % spots.size()] + Vector3(_center.x, 0, _center.y)
		var rot := 0.0 if absf(spot.x - _center.x) > half.x else PI * 0.5
		var node := _add(ConstructionMeshes.stack(goods_id), spot, rot)
		if goods_id == "stone":
			node.scale = Vector3(0.7, 0.6, 0.7)
		node.set_meta(&"base_scale", node.scale)
		_stacks[goods_id] = node
		k += 1


func _build_crane() -> void:
	var half := _size * 0.5
	var base := Vector3(_center.x + half.x + 0.9, 0, _center.y + half.y + 0.9)
	_crane_height = _height + 3.6
	_crane_jib = maxf(_size.x, _size.y) * 0.95 + 1.5
	_add(ConstructionMeshes.tower_crane_mast(_crane_height), base)
	_crane_top = Node3D.new()
	_crane_top.position = base + Vector3(0, _crane_height, 0)
	add_child(_crane_top)
	var top := ConstructionMeshes.tower_crane_top(_crane_jib)
	var body := MeshInstance3D.new()
	body.mesh = top["body"]
	body.material_override = material
	_crane_top.add_child(body)
	var glow := MeshInstance3D.new()
	glow.mesh = top["glow"]
	glow.material_override = _glow
	_crane_top.add_child(glow)
	_crane_hook = Node3D.new()
	_crane_hook.position = Vector3(0, 0.3, -_crane_jib * 0.6)
	_crane_top.add_child(_crane_hook)
	var hook := MeshInstance3D.new()
	hook.mesh = ConstructionMeshes.tower_crane_hook()
	hook.material_override = material
	_crane_hook.add_child(hook)
	var load_piece := MeshInstance3D.new()
	load_piece.mesh = ConstructionMeshes.stack("wood")
	load_piece.material_override = material
	load_piece.scale = Vector3(0.45, 0.45, 0.45)
	load_piece.position = Vector3(0, -0.85, 0)
	load_piece.name = "Load"
	_crane_hook.add_child(load_piece)
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.02
	rope_mesh.bottom_radius = 0.02
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 4
	rope_mesh.rings = 0
	_crane_rope = MeshInstance3D.new()
	_crane_rope.mesh = rope_mesh
	_crane_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crane_top.add_child(_crane_rope)
	# Aufstellrichtung: Ausleger zeigt zum Haus
	var to_house := Vector2(_center.x - base.x, _center.y - base.z)
	_crane_top.rotation.y = atan2(-to_house.x, -to_house.y)
	_crane_top.set_meta(&"home_yaw", _crane_top.rotation.y)


func _build_workers() -> void:
	var half := _size * 0.5
	var routes := [
		[Vector3(-half.x - 0.8, 0, -half.y * 0.35 + 1.2), Vector3(-half.x + 0.9, 0, -half.y + 0.6)],
		[Vector3(half.x * 0.1 + 1.3, 0, half.y + 0.8), Vector3(half.x - 0.8, 0, half.y - 0.6)],
	]
	for i in 2:
		var model := CharacterModel.new()
		var look := NpcDirector.random_appearance(_rng)
		model.appearance = look
		model.view_distance = 80.0
		add_child(model)
		var a: Vector3 = routes[i][0] + Vector3(_center.x, 0, _center.y)
		var b: Vector3 = routes[i][1] + Vector3(_center.x, 0, _center.y)
		model.position = a
		_workers.append({"model": model, "a": a, "b": b, "to_b": true, "wait": _rng.randf_range(0.5, 3.0)})


# --- Fortschritt ---------------------------------------------------------------------

## [param progress] 0..1, [param remaining]: noch nicht verbautes Material je Sorte,
## [param working]: gerade Arbeitszeit (tagsüber).
func set_progress(progress: float, remaining: Dictionary, working: bool) -> void:
	_progress = progress
	_working = working
	var built_height := clampf((progress - 0.08) / 0.77, 0.0, 1.0) * _height
	for i in _levels.size():
		_levels[i].visible = progress > 0.05 and i * ConstructionMeshes.SCAFFOLD_LEVEL <= built_height + 0.4
	for goods_id: String in _stacks:
		var total := maxf(float(_cost.get(goods_id, 0)), 1.0)
		var left := clampf(float(remaining.get(goods_id, 0)) / total, 0.0, 1.0)
		var node: MeshInstance3D = _stacks[goods_id]
		var base: Vector3 = node.get_meta(&"base_scale")
		node.visible = left > 0.02
		node.scale = Vector3(base.x, base.y * (0.25 + 0.75 * left), base.z)
	for worker in _workers:
		(worker["model"] as CharacterModel).visible = working


func set_dark(dark: bool) -> void:
	if not is_inside_tree():
		return
	var tween := create_tween().set_parallel(true)
	_lamp.visible = true
	tween.tween_property(_lamp, "light_energy", 0.9 if dark else 0.0, 2.0)
	tween.tween_property(_glow, "emission_energy_multiplier", 1.6 if dark else 0.15, 2.0)


## Fertig: Zaun, Gerüst und Kran verschwinden nacheinander (sanft), dann weg.
func finish() -> void:
	set_process(false)
	if not is_inside_tree():
		queue_free()
		return
	var tween := create_tween()
	var children := get_children()
	children.reverse()
	for child in children:
		if child is Node3D and child.visible:
			tween.parallel().tween_property(child, "scale", Vector3(1.0, 0.02, 1.0), 1.2).set_trans(Tween.TRANS_SINE) \
				.set_delay(randf() * 0.6)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	var speed := WorldClock.time_scale if not WorldClock.paused else 0.0
	_time += delta * minf(speed, 3.0)
	if not _working or speed <= 0.0:
		return
	_animate_crane()
	_animate_workers(delta * minf(speed, 3.0))
	_sound_timer -= delta
	if _sound_timer <= 0.0:
		_sound_timer = _rng.randf_range(3.5, 8.0)
		if WorldClock.time_scale <= 10.0:
			_sound.stream = SoundLibrary.get_sound(WORK_SOUNDS[_rng.randi() % WORK_SOUNDS.size()])
			_sound.pitch_scale = _rng.randf_range(0.94, 1.06)
			SoundLibrary.play(_sound)


## Der Kran schwenkt ruhig hin und her, die Last geht auf und ab.
func _animate_crane() -> void:
	var home: float = _crane_top.get_meta(&"home_yaw")
	_crane_top.rotation.y = home + sin(_time * 0.12) * 0.75
	var reach := 0.45 + 0.35 * (0.5 + 0.5 * sin(_time * 0.2 + 1.0))
	var drop := lerpf(1.2, _crane_height - 1.5, 0.5 + 0.5 * sin(_time * 0.17))
	_crane_hook.position = Vector3(0, 0.3 - drop, -_crane_jib * reach)
	_crane_rope.position = Vector3(0, 0.3 - drop * 0.5, -_crane_jib * reach)
	_crane_rope.scale = Vector3(1, drop, 1)


func _animate_workers(delta: float) -> void:
	for worker in _workers:
		var model: CharacterModel = worker["model"]
		if float(worker["wait"]) > 0.0:
			worker["wait"] = float(worker["wait"]) - delta
			model.move(0.0, delta)
			continue
		var target: Vector3 = worker["b"] if worker["to_b"] else worker["a"]
		var to := target - model.position
		to.y = 0.0
		if to.length() < 0.08:
			worker["to_b"] = not worker["to_b"]
			worker["wait"] = _rng.randf_range(2.0, 5.0)
			# Am Haus: arbeiten, am Stapel: kurz strecken oder nicken
			var gesture: CharacterModel.Pose = CharacterModel.Pose.TALK if worker["to_b"] == false \
				else [CharacterModel.Pose.STRETCH, CharacterModel.Pose.NOD][_rng.randi() % 2]
			model.play_gesture(gesture, 1.6)
			continue
		var step := minf(1.0 * delta, to.length())
		model.position += to.normalized() * step
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 8.0))
		model.move(1.0, delta)
