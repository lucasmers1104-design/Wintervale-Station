## Ein sichtbares Fahrzeug eines Zuges (Lok oder Wagen).
##
## Der Wagenkasten liegt auf zwei Drehgestellen, die jeweils der Gleisrichtung
## an ihrer Position folgen – so fahren die Wagen sauber durch Kurven.
## Außerdem: drehende Radsätze, Schiebetüren, Stirn-/Schlusslichter,
## Scheinwerfer, aufgewirbelter Schnee und Klänge (Schienenstoß, Türen).
##
## Etappe 9.5: Der Wagenkasten ("Body") ist federnd gelagert – er neigt sich in
## Kurven leicht nach außen, nickt beim Bremsen und Anfahren und wiegt sich sanft
## bei der Fahrt ([method update_motion]). Das Innenlicht wird im Stand und bei
## Dunkelheit warm hell ([method set_cabin_light]); Scheinwerfer blenden im Stand ab.
class_name TrainCar
extends Node3D

## Schienenoberkante über der Gleisachse.
const RAIL_TOP := RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT

var kind := ""
var length := 12.0
## Abstand Wagenmitte → Drehgestellmitte.
var bogie_offset := 4.3
## Abstand von der Zugspitze bis zur Vorderkante dieses Wagens.
var offset_from_head := 0.0
## Push-pull services reverse their direction without turning the models around.
var travel_reversed := false

var _bogies: Array[Node3D] = []
var _wheelsets: Array[Node3D] = []
var _doors: Array[Dictionary] = []
var _headlight: SpotLight3D
var _tail_glow: OmniLight3D
var _snow: GPUParticles3D
var _clack_player: AudioStreamPlayer3D
var _door_player: AudioStreamPlayer3D
var _pick_area: Area3D
var _wheel_angle := 0.0
var _door_amount := 0.0
var _steps: Array[Dictionary] = []
var _step_amount := 0.0
## Ladeplätze (Güterwagen): {"slot": Vector3, "piece", "goods", "amount", "state": "full" | "empty" | "none",
## "node": MeshInstance3D, "portions": int (Schüttgut)}
var _cargo: Array[Dictionary] = []
var _cargo_material: Material
var _exhaust: GPUParticles3D
var _body: Node3D
var _glass_nodes: Array[GeometryInstance3D] = []
var _cabin := 0.0
var _dark := false
var _standing := true
var _roll := 0.0
var _pitch := 0.0
var _travel := 0.0
var _display: Label3D
var _beacons: Array[Dictionary] = []
var _front_lens: MeshInstance3D
var _rear_lens: MeshInstance3D
var _end_materials: Dictionary

## Größte Neigung des Wagenkastens in Kurven und beim Bremsen (Bogenmaß).
const MAX_ROLL := 0.035
const MAX_PITCH := 0.012
## Drehpunkt der Federung (Höhe über Schienenoberkante).
const SUSPENSION_Y := 1.0


## Baut das Fahrzeug. [param materials]: {"paint", "glass", "lamp_white", "lamp_red", "snow"}.
func build(p_kind: String, train_type: TrainType, is_first: bool, is_last: bool, materials: Dictionary,
		variant := 0) -> void:
	kind = p_kind
	name = "%s_%d" % [kind, variant]
	var parts := TrainMeshes.build_car(kind, train_type.get_livery(), variant)
	length = parts["length"]
	bogie_offset = parts["bogie"]
	var reference: bool = parts.get("reference_railcar", false)
	_end_materials = materials
	var paint_material: Material = preload("res://assets/materials/railcar_paint.tres") if reference else materials["paint"]
	var glass_material: Material = preload("res://assets/materials/railcar_glass.tres") if reference else materials["glass"]

	# Wagenkasten auf der Federung: alles, was mitschwingt, hängt an _body
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_add_mesh(parts["paint"], paint_material, _body)
	if parts["glass"]:
		var glass := _add_mesh(parts["glass"], glass_material, _body)
		# Die Scheiben liegen auf dem Wagenkasten – dessen Schatten genügt
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glass_nodes.append(glass)
	if parts.get("interior"):
		var interior := _add_mesh(parts["interior"], preload("res://assets/materials/railcar_interior.tres"), _body)
		interior.name = "CabinInterior"
		interior.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glass_nodes.append(interior)
	for door: Dictionary in parts["doors"]:
		var leaf := MeshInstance3D.new()
		leaf.mesh = door["mesh"]
		if leaf.mesh.get_surface_count() > 1:
			# Türblatt aus Lack, Türfenster aus Glas (leuchtet mit dem Innenlicht)
			leaf.set_surface_override_material(0, paint_material)
			leaf.set_surface_override_material(1, glass_material)
			_glass_nodes.append(leaf)
		else:
			leaf.material_override = paint_material
		leaf.position = door["position"]
		# Kleine Teile unter bzw. im Schatten des Wagenkastens werfen keinen eigenen Schatten (Leistung)
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if float(door["side"]) < 0.0:
			leaf.rotation.y = PI
		_body.add_child(leaf)
		_doors.append({"node": leaf, "closed": door["position"], "open_offset": door["open_offset"], "side": door["side"]})
	_build_steps(paint_material)
	for beacon: Vector3 in parts.get("beacons", []):
		_add_beacon(beacon)
	if parts.get("glow"):
		var festive := _add_mesh(parts["glow"], preload("res://assets/materials/railcar_winter_lights.tres"), _body)
		festive.name = "WinterLights"
		festive.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif train_type.festive_lights and materials.has("festive"):
		_add_festive_lights(materials["festive"], train_type.festive_colors, variant)
	_cargo_material = materials.get("cargo", materials["paint"])
	_build_cargo(variant)
	if kind in ["loco_freight","reference_freight_loco","heritage_diesel","heritage_loco","heritage_loco_rear"]:
		_exhaust = _make_exhaust(materials.get("steam", materials["snow"]))
		add_child(_exhaust)

	var bogie_mesh := TrainMeshes.create_bogie(parts["wheel_base"])
	var wheel_mesh := TrainMeshes.create_wheelset()
	var wheel_faces: Mesh = ReferenceRailcarMeshes.wheel_faces(train_type.winter_special) if reference else null
	for z in [-bogie_offset, bogie_offset]:
		var bogie := Node3D.new()
		bogie.position = Vector3(0.0, 0.0, z)
		add_child(bogie)
		_add_mesh(bogie_mesh, paint_material, bogie).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for axle: float in [-0.5, 0.5]:
			var wheelset := Node3D.new()
			wheelset.position = Vector3(0.0, TrainMeshes.WHEEL_RADIUS, axle * float(parts["wheel_base"]))
			bogie.add_child(wheelset)
			_add_mesh(wheel_mesh, paint_material, wheelset).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if wheel_faces:
				_add_mesh(wheel_faces, paint_material, wheelset).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_wheelsets.append(wheelset)
		_bogies.append(bogie)

	# Lampen, die in dieser Fahrtrichtung nicht leuchten (z.B. Schlusslichter am Zuganfang)
	for idle: Dictionary in parts.get("lamps_idle", []):
		var idle_material: Material = materials.get("lamp_idle_%s" % idle["color"], materials["paint"])
		_add_lamp(idle["position"], float(idle["facing"]), idle_material)
	if parts.get("light_front"):
		var front_lens: Material = materials["lamp_white"] if is_first else materials["lamp_idle_white"]
		if train_type.winter_special and is_first:
			var warm_lens := StandardMaterial3D.new()
			warm_lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			warm_lens.albedo_color = Color(0.90, 0.85, 0.67)
			warm_lens.emission_enabled = true
			warm_lens.emission = Color(1.0, 0.91, 0.68)
			warm_lens.emission_energy_multiplier = 0.25
			front_lens = warm_lens
		_front_lens = _add_mesh(parts["light_front"], front_lens, _body)
		_front_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parts.get("light_rear"):
		var rear_lens: Material = materials["lamp_red"] if is_last else materials["lamp_idle_red"]
		_rear_lens = _add_mesh(parts["light_rear"], rear_lens, _body)
		_rear_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parts.has("display"):
		_add_display(parts["display"])
	if is_first:
		if not reference:
			for lamp_position: Vector3 in parts["lamps_front"]:
				_add_lamp(lamp_position, -1.0, materials["lamp_white"])
		_headlight = SpotLight3D.new()
		_headlight.position = Vector3(0.0, 1.7, -length * 0.5 - 0.2)
		_headlight.light_color = Color(1.0, 0.9, 0.72)
		_headlight.spot_range = 45.0
		_headlight.spot_angle = 26.0
		_headlight.spot_attenuation = 0.8
		_headlight.shadow_enabled = false
		add_child(_headlight)
		_snow = _make_snow_spray(materials["snow"])
		_snow.position = Vector3(0.0, 0.3, -bogie_offset)
		add_child(_snow)
		if kind == "loco_plough":
			_make_plough_spray()
	if is_last:
		if not reference:
			for lamp_position: Vector3 in parts["lamps_rear"]:
				_add_lamp(lamp_position, 1.0, materials["lamp_red"])
		_tail_glow = OmniLight3D.new()
		_tail_glow.position = Vector3(0.0, 1.45, length * 0.5 + 0.4)
		_tail_glow.light_color = Color(1.0, 0.15, 0.1)
		_tail_glow.omni_range = 3.0
		_tail_glow.light_energy = 0.5
		add_child(_tail_glow)

	# Zum Anklicken (Kamera folgt dem Zug)
	_pick_area = Area3D.new()
	_pick_area.collision_layer = GameDefs.LAYER_TRAINS
	_pick_area.collision_mask = 0
	_pick_area.monitoring = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 3.6, length)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 2.0, 0.0)
	_pick_area.add_child(collision)
	add_child(_pick_area)

	_clack_player = _make_player(SoundLibrary.get_sound("clack"), -8.0, 45.0)
	if not _doors.is_empty():
		_door_player = _make_player(null, -9.0, 25.0)


## Positioniert Wagenkasten und Drehgestelle anhand der Drehgestell-Punkte auf dem Gleis.
func place(front: Vector3, front_direction: Vector3, rear: Vector3, rear_direction: Vector3) -> void:
	if travel_reversed:
		var swap := front
		front = rear
		rear = swap
		var swap_direction := front_direction
		front_direction = -rear_direction
		rear_direction = -swap_direction
	var lift := Vector3.UP * RAIL_TOP
	var axis := front - rear
	var forward := axis.normalized() if axis.length() > 0.01 else front_direction
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), (front + rear) * 0.5 + lift)
	_bogies[0].global_transform = Transform3D(Basis.looking_at(front_direction, Vector3.UP), front + lift)
	_bogies[1].global_transform = Transform3D(Basis.looking_at(rear_direction, Vector3.UP), rear + lift)


## Räder um die gefahrene Strecke weiterdrehen.
func roll(distance: float) -> void:
	_wheel_angle = fmod(_wheel_angle + distance / TrainMeshes.WHEEL_RADIUS, TAU)
	for wheelset in _wheelsets:
		wheelset.rotation.x = -_wheel_angle


## Türen auf der Seite [param side] (±1) öffnen: 0 = zu, 1 = offen (weich animiert).
func set_doors(amount: float, side: float) -> void:
	if travel_reversed:
		side = -side
	_door_amount = clampf(amount, 0.0, 1.0)
	var eased := ease(_door_amount, -1.8)
	for door in _doors:
		var node: Node3D = door["node"]
		var offset: Vector3 = door["open_offset"] if float(door["side"]) == side else Vector3.ZERO
		# Erst leicht nach außen (Schwenkschiebetür), dann zur Seite gleiten
		var outward := Vector3(offset.x, 0.0, 0.0) * clampf(eased * 3.0, 0.0, 1.0)
		var slide := Vector3(0.0, 0.0, offset.z) * clampf(eased * 1.25 - 0.25, 0.0, 1.0)
		node.position = door["closed"] + outward + slide


## Mitten der Türöffnungen auf Seite [param side] (±1) in Weltkoordinaten,
## auf Höhe des Wagenbodens. Zwei Türflügel bilden eine Öffnung.
func get_door_centers(side: float) -> Array[Vector3]:
	if travel_reversed:
		side = -side
	var result: Array[Vector3] = []
	for opening in _door_openings(side):
		result.append(_body.global_transform * opening)
	return result


## Weg durch eine Tür über die Trittstufe (Weltkoordinaten), von innen nach außen:
## {"inside", "door", "upper", "lower", "platform"} – "platform" liegt auf Stufenhöhe über
## der Bahnsteigkante; die Bodenhöhe dort bestimmt der Fahrgast selbst.
func get_boarding_paths(side: float) -> Array[Dictionary]:
	if travel_reversed:
		side = -side
	var paths: Array[Dictionary] = []
	var floor_y := TrainMeshes.FLOOR_HEIGHT
	var hinge_x := TrainMeshes.STEP_EXTENDED_X + TrainMeshes.STEP_DEPTH * 0.5
	var lower_x := hinge_x + TrainMeshes.STEP_LOWER_OFFSET.x
	var lower_y := TrainMeshes.STEP_UPPER_Y - 0.02 + TrainMeshes.STEP_LOWER_OFFSET.y
	var boarding_transform := _body.global_transform
	for opening in _door_openings(side):
		var z := opening.z
		paths.append({
			"inside": boarding_transform * Vector3(side * 0.85, floor_y, z),
			"door": boarding_transform * Vector3(side * 1.3, floor_y, z),
			"upper": boarding_transform * Vector3(side * TrainMeshes.STEP_EXTENDED_X, TrainMeshes.STEP_UPPER_Y, z),
			"lower": boarding_transform * Vector3(side * lower_x, lower_y, z),
			"platform": boarding_transform * Vector3(side * (lower_x + 0.5), lower_y, z),
		})
	return paths


## Türöffnungen (lokal): zwei Türflügel bilden eine Öffnung.
func _door_openings(side: float) -> Array[Vector3]:
	var openings: Array[Vector3] = []
	for door in _doors:
		if float(door["side"]) != side:
			continue
		var closed: Vector3 = door["closed"]
		var merged := false
		for i in openings.size():
			if absf(openings[i].z - closed.z) < 0.8:
				openings[i].z = (openings[i].z + closed.z) * 0.5
				merged = true
		if not merged:
			openings.append(Vector3(closed.x, TrainMeshes.FLOOR_HEIGHT, closed.z))
	return openings


## Trittstufen auf Seite [param side] ausfahren: 0 = eingefahren, 1 = ausgefahren.
## Erst gleitet die Stufe heraus, dann klappt die untere Stufe herunter.
func set_steps(amount: float, side: float) -> void:
	if travel_reversed:
		side = -side
	_step_amount = clampf(amount, 0.0, 1.0)
	var slide := smoothstep(0.0, 1.0, clampf(_step_amount / 0.55, 0.0, 1.0))
	var unfold := smoothstep(0.0, 1.0, clampf((_step_amount - 0.55) / 0.45, 0.0, 1.0))
	for step in _steps:
		var active := 1.0 if float(step["side"]) == side else 0.0
		var unit: Node3D = step["unit"]
		var hinge: Node3D = step["hinge"]
		unit.position.x = float(step["side"]) * lerpf(TrainMeshes.STEP_RETRACTED_X, TrainMeshes.STEP_EXTENDED_X, slide * active)
		# Eingefahren liegt die Stufe unsichtbar unter dem Wagen: gar nicht erst zeichnen
		unit.visible = slide * active > 0.001
		hinge.rotation.z = -TrainMeshes.STEP_FOLD_ANGLE * (1.0 - unfold * active)


func get_step_amount() -> float:
	return _step_amount


func has_doors() -> bool:
	return not _doors.is_empty()


func get_door_amount() -> float:
	return _door_amount


## Lichtstärke der Scheinwerfer (nachts heller, im Stand abgeblendet).
func set_light_level(dark: bool) -> void:
	_dark = dark
	if _headlight:
		_headlight.light_energy = (3.0 if dark else 0.6) * (0.35 if _standing else 1.0)
	if _tail_glow:
		_tail_glow.light_energy = 0.6 if dark else 0.15

## Physical end lenses and headlamp beam follow push-pull direction.
func set_service_ends(leading: bool, trailing: bool) -> void:
	if _front_lens:
		_front_lens.material_override = _end_materials["lamp_white"] if (leading and not travel_reversed) else (_end_materials["lamp_red"] if trailing and travel_reversed else _end_materials["lamp_idle_white"])
	if _rear_lens:
		_rear_lens.material_override = _end_materials["lamp_white"] if (leading and travel_reversed) else (_end_materials["lamp_red"] if trailing and not travel_reversed else _end_materials["lamp_idle_red"])
	if leading and _headlight==null:
		_headlight = SpotLight3D.new()
		_headlight.light_color = Color(1.0,0.9,0.72)
		_headlight.spot_range = 45
		_headlight.spot_angle = 26
		add_child(_headlight)
	if _headlight:
		_headlight.visible = leading
		_headlight.position = Vector3(0,1.7,(1 if travel_reversed else -1)*(length/2+0.2))
		_headlight.rotation.y = PI if travel_reversed else 0.0
	if _tail_glow:
		_tail_glow.visible = trailing
	set_light_level(_dark)


## Warmes Innenlicht (0..1): scheint durch alle Fenster und Türfenster.
func set_cabin_light(level: float) -> void:
	if absf(level - _cabin) < 0.005:
		return
	_cabin = level
	for node in _glass_nodes:
		node.set_instance_shader_parameter(&"cabin", level)


func get_cabin_light() -> float:
	return _cabin


## Federung des Wagenkastens: [param speed] (m/s), [param acceleration] (m/s², negativ =
## bremsen). Neigt sich in Kurven nach außen, nickt beim Bremsen nach vorne, beim
## Anfahren leicht zurück, und wiegt sich bei der Fahrt ganz sanft.
func update_motion(speed: float, acceleration: float, delta: float) -> void:
	var standing := speed < 0.05
	if standing != _standing:
		_standing = standing
		set_light_level(_dark)
	if _body == null or _bogies.size() < 2:
		return
	# Krümmung aus dem Winkel zwischen den beiden Drehgestellen
	var front := -_bogies[0].global_basis.z
	var rear := -_bogies[1].global_basis.z
	var turn := atan2(rear.cross(front).y, rear.dot(front))
	var curvature := turn / maxf(bogie_offset * 2.0, 1.0)
	var lateral := speed * speed * curvature
	var target_roll := clampf(-lateral * 0.03, -MAX_ROLL, MAX_ROLL)
	# Bremsen (negativ) senkt die Front (Drehung um +X hebt -Z an, daher gleiches Vorzeichen)
	var target_pitch := clampf(acceleration * 0.012, -MAX_PITCH, MAX_PITCH)
	var blend := 1.0 - exp(-delta * 3.0)
	_roll = lerpf(_roll, target_roll, blend)
	_pitch = lerpf(_pitch, target_pitch, blend)
	_travel += speed * delta
	var sway := sin(_travel * 0.9) * 0.0035 * clampf(speed / 8.0, 0.0, 1.0)
	var bounce := sin(_travel * 2.3) * 0.006 * clampf(speed / 10.0, 0.0, 1.0)
	var basis := Basis.from_euler(Vector3(_pitch, 0.0, _roll + sway))
	var pivot := Vector3(0.0, SUSPENSION_Y, 0.0)
	_body.transform = Transform3D(basis, pivot - basis * pivot + Vector3(0.0, bounce, 0.0))


func get_body_tilt() -> Vector2:
	return Vector2(_roll, _pitch)


## Zielanzeige an der Front (orange Leuchtschrift).
func set_destination(text: String) -> void:
	if _display:
		_display.text = text
		# Die Zielanzeige bleibt auch bei langen Orts- und Zugnamen in ihrer Blende.
		var text_width := _display.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _display.font_size).x
		_display.pixel_size = minf(0.0036, 1.20 / maxf(text_width, 1.0))


func get_destination() -> String:
	return _display.text if _display else ""


## Aufgewirbelter Schnee an der Lok – nur bei zügiger Fahrt und nur, wenn Schnee liegt.
func set_snow_spray(speed: float) -> void:
	if not _beacons.is_empty():
		_update_beacons()
	if _snow:
		_snow.emitting = speed > 4.0 and Seasons.get_snow_cover() > 0.3
		_snow.amount_ratio = clampf((speed - 4.0) / 10.0, 0.1, 1.0)


func play_clack(intensity: float) -> void:
	if _clack_player and intensity > 0.05:
		_clack_player.pitch_scale = randf_range(0.9, 1.1)
		_clack_player.volume_db = -8.0 + linear_to_db(clampf(intensity, 0.05, 1.0))
		SoundLibrary.play(_clack_player)


func play_door_sound(opening: bool) -> void:
	if _door_player:
		_door_player.stream = SoundLibrary.get_sound("door_open" if opening else "door_close")
		_door_player.pitch_scale = randf_range(0.96, 1.04)
		SoundLibrary.play(_door_player)


## Leises Entriegeln der Türen bzw. Surren der Trittstufe.
func play_mechanism_sound(sound_name: String) -> void:
	if _door_player:
		_door_player.stream = SoundLibrary.get_sound(sound_name)
		_door_player.pitch_scale = randf_range(0.97, 1.03)
		SoundLibrary.play(_door_player)


func _add_mesh(mesh: Mesh, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Orange Rundumleuchte (Schneeräumlok): blinkt im Umlauf.
func _add_beacon(at: Vector3) -> void:
	var cap := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.11
	sphere.radial_segments = 8
	sphere.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.5, 0.08)
	material.emission_energy_multiplier = 1.0
	sphere.material = material
	cap.mesh = sphere
	cap.position = at
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(cap)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.15)
	light.omni_range = 7.0
	light.light_energy = 0.0
	light.position = at + Vector3(0, 0.1, 0)
	_body.add_child(light)
	_beacons.append({"light": light, "material": material, "phase": _beacons.size() * PI})


## Schneeräumlok: eine breite Schneefontäne vor dem Pflug.
func _make_plough_spray() -> void:
	var process := _snow.process_material as ParticleProcessMaterial
	process.direction = Vector3(0.0, 1.0, -0.35)
	process.spread = 75.0
	process.initial_velocity_min = 2.2
	process.initial_velocity_max = 5.2
	process.gravity = Vector3(0.0, -3.0, 0.0)
	process.emission_box_extents = Vector3(1.8, 0.2, 0.3)
	_snow.amount = 280
	_snow.lifetime = 1.6
	_snow.position = Vector3(0.0, 0.5, -length * 0.5 - 1.1)
	(_snow.draw_pass_1 as QuadMesh).size = Vector2(0.24, 0.24)


## Blinken der Rundumleuchten (aus Train.update_visuals über set_snow_spray).
func _update_beacons() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for beacon: Dictionary in _beacons:
		var pulse := pow(maxf(0.0, sin(t * 7.0 + float(beacon["phase"]))), 3.0)
		(beacon["light"] as OmniLight3D).light_energy = 2.4 * pulse
		(beacon["material"] as StandardMaterial3D).emission_energy_multiplier = 0.6 + 4.0 * pulse


## Festlicher Sonderzug: Lichterketten in Girlandenbögen entlang beider Dachkanten.
func _add_festive_lights(material: Material, colors: PackedColorArray, variant: int) -> void:
	var glow := TrainMeshes._new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + variant
	var half := length * 0.5 - 0.6
	# An den Endwagen fällt die Bugnase ab – dort gibt es keine Dachkante, an der die
	# Kette hängen könnte. Sie endet deshalb kurz vor dem Nasenbeginn (vorne bei
	# railcar_front, hinten beim gespiegelten railcar_rear).
	var z_from := -half
	var z_to := half
	if kind == "railcar_front":
		z_from = -length * 0.5 + RailcarMeshes.NOSE_LENGTH + 0.2
	elif kind == "railcar_rear":
		z_to = length * 0.5 - RailcarMeshes.NOSE_LENGTH - 0.2
	var hooks := maxi(2, int((z_to - z_from) / 1.4))
	var light_y := ReferenceRailcarMeshes._height(3.30) if RailcarMeshes.SPECS.has(kind) else 3.1
	for side: float in [-1.0, 1.0]:
		for k in hooks:
			var z0 := lerpf(z_from, z_to, float(k) / hooks)
			var z1 := lerpf(z_from, z_to, float(k + 1) / hooks)
			var a := Vector3(side * 1.37, light_y, z0)
			var b := Vector3(side * 1.37, light_y, z1)
			for i in 5:
				var t := (i + 0.5) / 5.0
				var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.13, 0) + Vector3(side * 0.02, 0, 0)
				FestivalMeshes._bulb(glow, p, 0.062, colors[(k * 5 + i) % colors.size()], rng.randf())
	var lights := MeshInstance3D.new()
	lights.name = "FestiveLights"
	lights.mesh = glow.commit()
	lights.material_override = material
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(lights)


func _add_display(xform: Transform3D) -> void:
	_display = Label3D.new()
	_display.name = "Display"
	_display.font = ThemeDB.fallback_font
	_display.text = ""
	_display.font_size = 40
	_display.pixel_size = 0.0036
	_display.modulate = Color(1.0, 0.62, 0.18)
	_display.outline_size = 0
	_display.double_sided = false
	_display.shaded = false
	_display.transform = xform
	_body.add_child(_display)


## Kleine leuchtende Lampenscheibe; [param facing] -1 = nach vorne, +1 = nach hinten.
func _add_lamp(lamp_position: Vector3, facing: float, material: Material) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.1
	disc.bottom_radius = 0.1
	disc.height = 0.04
	disc.radial_segments = 12
	disc.rings = 0
	var lamp := MeshInstance3D.new()
	lamp.mesh = disc
	lamp.material_override = material
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.rotation.x = PI * 0.5
	lamp.position = lamp_position + Vector3(0.0, 0.0, facing * 0.01)
	(_body if _body else self).add_child(lamp)


func _make_player(stream: AudioStream, volume: float, distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume
	player.max_distance = distance
	player.unit_size = 6.0
	add_child(player)
	SoundLibrary.stop_on_exit(player)
	return player


func _make_snow_spray(material: Material) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.6)
	process.spread = 55.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0.0, -1.2, 0.0)
	process.damping_min = 0.8
	process.damping_max = 1.6
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(1.2, 0.1, 0.4)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 1.4
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.local_coords = false
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


# --- Ladung (Güterwagen) ------------------------------------------------------------

## Ladeplätze nach [constant TrainMeshes.CARGO] anlegen – der Wagen kommt voll beladen an.
func _build_cargo(variant: int) -> void:
	var spec: Dictionary = TrainMeshes.CARGO.get(kind, {})
	if spec.is_empty():
		return
	var slots: Array = spec["slots"]
	for i in slots.size():
		var entry := {"slot": slots[i], "piece": spec["piece"], "goods": spec["goods"], "amount": spec["amount"],
			"state": "none", "node": null, "portions": int(spec.get("bulk", 0))}
		_cargo.append(entry)
		var node := MeshInstance3D.new()
		node.mesh = TrainMeshes.create_cargo(spec["piece"], variant * 3 + i)
		attach_cargo(i, node, spec["piece"], spec["goods"], int(spec["amount"]), "full")


func has_cargo_slots() -> bool:
	return not _cargo.is_empty()


## Alle Ladeplätze (nur lesen – ändern über die Methoden unten).
func get_cargo() -> Array[Dictionary]:
	return _cargo

func refill_region_cargo() -> void:
	var spec: Dictionary = TrainMeshes.CARGO.get(kind,{})
	for i in _cargo.size():
		if _cargo[i]["state"] == "full":
			continue
		var piece := MeshInstance3D.new()
		piece.mesh = TrainMeshes.create_cargo(String(spec["piece"]),i)
		_cargo[i]["portions"] = int(spec.get("bulk",0))
		attach_cargo(i,piece,String(spec["piece"]),String(spec["goods"]),int(spec["amount"]),"full")


## Schüttgut (Trichterwagen): wird portionsweise mit dem Greifer entladen.
func is_bulk() -> bool:
	return not _cargo.is_empty() and int(TrainMeshes.CARGO.get(kind, {}).get("bulk", 0)) > 0


## Welches Leergut passt auf die freien Plätze ("" = keins).
func get_empty_piece() -> String:
	return String(TrainMeshes.CARGO.get(kind, {}).get("empty", ""))


## Lage eines Ladeplatzes in der Welt (Mitte der Unterkante, Ausrichtung des Wagens).
func get_slot_transform(index: int) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, _cargo[index]["slot"])


## Stück vom Wagen nehmen (für den Kran). Rückgabe: der Node (ohne Eltern) oder null.
func detach_cargo(index: int) -> Node3D:
	var entry := _cargo[index]
	var node: Node3D = entry["node"]
	if node == null:
		return null
	var world := node.global_transform
	remove_child(node)
	node.transform = world
	entry["node"] = null
	entry["state"] = "none"
	return node


## Stück auf einen Ladeplatz setzen ([param state] "full" oder "empty").
func attach_cargo(index: int, node: Node3D, piece: String, goods: String, amount: int, state: String) -> void:
	var entry := _cargo[index]
	if entry["node"]:
		(entry["node"] as Node3D).queue_free()
	if node.get_parent():
		node.get_parent().remove_child(node)
	add_child(node)
	node.transform = Transform3D(Basis.IDENTITY, entry["slot"])
	if node is GeometryInstance3D and _cargo_material:
		(node as GeometryInstance3D).material_override = _cargo_material
	entry["node"] = node
	entry["piece"] = piece
	entry["goods"] = goods
	entry["amount"] = amount
	entry["state"] = state
	if int(entry["portions"]) > 0:
		_update_bulk(index, false)
	if bool(TrainMeshes.CARGO.get(kind,{}).get("enclosed",false)):
		node.hide()


## Oberkante der Schüttgut-Ladung (Welt) – hier greift der Kran zu.
func get_bulk_top(index: int) -> Vector3:
	var entry := _cargo[index]
	var total := int(TrainMeshes.CARGO[kind].get("bulk", 1))
	var depth := TrainMeshes.BULK_DEPTH * (1.0 - float(entry["portions"]) / total)
	return global_transform * Vector3(0.0, 3.3 - depth, 0.0)


## Eine Portion Schüttgut herausnehmen: die Oberfläche sinkt sanft. Rückgabe: noch übrige Portionen.
func take_bulk_portion(index: int) -> int:
	var entry := _cargo[index]
	if int(entry["portions"]) <= 0:
		return 0
	entry["portions"] = int(entry["portions"]) - 1
	_update_bulk(index, true)
	if int(entry["portions"]) == 0:
		entry["state"] = "none"
	return int(entry["portions"])


func _update_bulk(index: int, animated: bool) -> void:
	var entry := _cargo[index]
	var node: Node3D = entry["node"]
	if node == null:
		return
	var total := int(TrainMeshes.CARGO[kind].get("bulk", 1))
	var fraction := float(entry["portions"]) / total
	var target := Vector3(0.0, -TrainMeshes.BULK_DEPTH * (1.0 - fraction), 0.0)
	if animated and is_inside_tree():
		var tween := node.create_tween()
		tween.tween_property(node, "position", target, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if fraction <= 0.0:
			tween.tween_callback(node.hide)
	else:
		node.position = target
		node.visible = fraction > 0.0


## Wie viele Stücke dieses Materials noch voll geladen sind.
func count_full(goods_id := "") -> int:
	var count := 0
	for entry in _cargo:
		if entry["state"] == "full" and (goods_id == "" or entry["goods"] == goods_id):
			count += 1
	return count


## Kleine Abgaswolken der Güterlok: im Stand ein ruhiges Wölkchen, beim Anfahren mehr.
func set_exhaust(speed: float, accelerating: bool) -> void:
	if _exhaust == null:
		return
	_exhaust.emitting = true
	_exhaust.amount_ratio = 1.0 if accelerating and speed < 6.0 else (0.45 if speed < 0.2 else 0.3)


func _make_exhaust(material: Material) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.15)
	process.spread = 12.0
	process.initial_velocity_min = 0.9
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0.0, 0.25, 0.0)
	process.damping_min = 0.4
	process.damping_max = 0.8
	process.scale_min = 0.8
	process.scale_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 0.9))
	grow.add_point(Vector2(1.0, 1.6))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = grow
	process.scale_curve = scale_curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.12, Color(0.96, 0.96, 0.95, 0.55))
	fade.add_point(0.6, Color(0.92, 0.92, 0.93, 0.3))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var puff := SphereMesh.new()
	puff.radius = 0.28
	puff.height = 0.5
	puff.radial_segments = 8
	puff.rings = 4
	puff.material = material
	var particles := GPUParticles3D.new()
	particles.name = "Exhaust"
	particles.amount = 14
	particles.lifetime = 2.6
	particles.process_material = process
	particles.draw_pass_1 = puff
	particles.local_coords = false
	particles.position = Vector3(0.0, 3.15, -2.2)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 9, 8))
	return particles


## Unter jeder Türöffnung eine ausfahrbare Trittstufe (beide Seiten, eingefahren).
func _build_steps(material: Material) -> void:
	var upper := TrainMeshes.create_step_upper()
	var lower := TrainMeshes.create_step_lower()
	for side: float in [-1.0, 1.0]:
		for opening in _door_openings(side):
			var unit := Node3D.new()
			unit.position = Vector3(side * TrainMeshes.STEP_RETRACTED_X, 0.0, opening.z)
			if side < 0.0:
				unit.rotation.y = PI
			_body.add_child(unit)
			unit.visible = false
			_add_mesh(upper, material, unit).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var hinge := Node3D.new()
			hinge.position = Vector3(TrainMeshes.STEP_DEPTH * 0.5, TrainMeshes.STEP_UPPER_Y - 0.02, 0.0)
			hinge.rotation.z = -TrainMeshes.STEP_FOLD_ANGLE
			unit.add_child(hinge)
			_add_mesh(lower, material, hinge).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_steps.append({"unit": unit, "hinge": hinge, "side": side})
