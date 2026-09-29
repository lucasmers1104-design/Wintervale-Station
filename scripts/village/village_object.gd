## Ein platziertes Dorf-Objekt (Baum, Laterne, Brunnen, Zaun, Dorfplatz …).
##
## Wird vom [VillageManager] aus seinen gespeicherten Daten erzeugt und kennt
## nur sich selbst: Aussehen (über [VillageVisual]), Kollision, Grundfläche,
## Lichter bei Nacht und das Roden von Bäumen unter sich. Linienobjekte (Zaun,
## Hecke, Lichterkette) liegen am Startpunkt, ihre lokale X-Achse zeigt zum Endpunkt.
class_name VillageObject
extends StaticBody3D

var object_id := 0
var item_id := ""
var variant := 0
var angle := 0.0
var end_point := Vector3.INF
var material: Material

var _parts := {}
var _footprint := {}


## Vor dem Einfügen in den Baum aufrufen.
func configure(data: Dictionary, body_material: Material) -> void:
	object_id = int(data["id"])
	item_id = String(data["item"])
	variant = int(data.get("variant", 0))
	angle = float(data.get("rot", 0.0))
	material = body_material
	var start := SaveUtils.array_to_vec3(data.get("pos"), Vector3.ZERO)
	if data.has("end"):
		end_point = SaveUtils.array_to_vec3(data["end"], start)
	position = start
	if VillageCatalog.is_line(item_id) and end_point != Vector3.INF:
		transform = Transform3D(line_basis(start, end_point), start)
	else:
		rotation.y = angle
	_footprint = VillageFootprint.for_item(item_id, start, angle, variant, end_point)
	name = "%s_%d" % [item_id, object_id]


func _ready() -> void:
	collision_layer = GameDefs.LAYER_OBJECTS
	collision_mask = 0
	add_to_group(PropScatter.GROUP_CLEARING)
	var length := get_length()
	_parts = VillageVisual.attach(self, item_id, variant, length, material)
	_add_collision(length)
	_add_signs()
	_add_seats()
	if bool(VillageCatalog.get_item(item_id).get("winter_only", false)):
		set_process(true)
		_update_winter(true)
	else:
		set_process(false)


## Nur im Winter da (Schneemann, Schlitten): taut die Schneedecke, sinkt er
## sanft zusammen und verschwindet samt Kollision; im nächsten Winter ist er wieder da.
var _winter_visible := true
var _winter_timer := 0.0


func _process(delta: float) -> void:
	_winter_timer -= delta
	if _winter_timer <= 0.0:
		_winter_timer = 1.0
		_update_winter(false)


func _update_winter(instant: bool) -> void:
	var show := Seasons.get_snow_cover() > 0.45
	if show == _winter_visible and not instant:
		return
	_winter_visible = show
	collision_layer = GameDefs.LAYER_OBJECTS if show else 0
	if instant or not is_inside_tree():
		visible = show
		scale = Vector3.ONE
		return
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0) if show else Vector3(1.0, 0.05, 1.0), 1.5) \
		.from(Vector3(1.0, 0.05, 1.0) if show else Vector3.ONE).set_trans(Tween.TRANS_SINE)
	if not show:
		tween.tween_callback(hide)


func is_winter_visible() -> bool:
	return _winter_visible


func get_data() -> Dictionary:
	var data := {"id": object_id, "item": item_id, "pos": SaveUtils.vec3_to_array(position), "rot": angle,
		"variant": variant}
	if end_point != Vector3.INF:
		data["end"] = SaveUtils.vec3_to_array(end_point)
	return data


func get_footprint() -> Dictionary:
	return _footprint


func get_length() -> float:
	if end_point == Vector3.INF:
		return 0.0
	return Vector2(position.x, position.z).distance_to(Vector2(end_point.x, end_point.z))


func is_solid() -> bool:
	return bool(VillageCatalog.get_item(item_id).get("solid", false)) or VillageCatalog.get_kind(item_id) == "line"


## Keine wilden Bäume auf und direkt neben dem Objekt.
func clears(x: float, z: float) -> bool:
	return VillageFootprint.contains(_footprint, Vector2(x, z), 0.8)


func set_dark(dark: bool) -> void:
	VillageVisual.set_lit(_parts, dark, self)


func set_highlight(highlight: Material) -> void:
	VillageVisual.set_overlay(_parts, highlight)


func get_light_count() -> int:
	return (_parts.get("lights", []) as Array).size()


## Lage für ein Linienobjekt: X entlang der Linie (leicht dem Hang folgend), Y nach oben.
static func line_basis(start: Vector3, end: Vector3) -> Basis:
	var dir := end - start
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return Basis.IDENTITY
	# Steigung begrenzen, damit Zäune nicht umkippen
	var slope := clampf(dir.y / flat.length(), -0.35, 0.35)
	var x_axis := (flat.normalized() + Vector3.UP * slope).normalized()
	var z_axis := x_axis.cross(Vector3.UP).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _add_collision(length: float) -> void:
	if not is_solid():
		return
	if item_id == "string_lights":
		for x: float in [0.0, length]:
			_box(Vector3(0.2, 2.6, 0.2), Vector3(x, 1.3, 0.0))
		return
	var shape := CollisionShape3D.new()
	match VillageCatalog.get_kind(item_id):
		"line":
			var box := BoxShape3D.new()
			box.size = Vector3(length, 1.0, 0.5)
			shape.shape = box
			shape.position = Vector3(length * 0.5, 0.5, 0.0)
		"plaza":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 1.6
			cylinder.height = 1.8
			shape.shape = cylinder
			shape.position = Vector3(0, 0.9, 0)
			for k in 4:
				var a := PI * 0.25 + k * PI * 0.5
				_box(Vector3(1.7, 0.9, 0.5), Vector3(cos(a), 0, sin(a)) * 3.65 + Vector3(0, 0.45, 0), a)
		_:
			var radius := float(VillageCatalog.get_item(item_id).get("radius", 0.5))
			var cylinder := CylinderShape3D.new()
			cylinder.radius = maxf(0.2, radius * (0.35 if item_id.begins_with("tree") else 0.8))
			cylinder.height = 2.4
			shape.shape = cylinder
			shape.position = Vector3(0, 1.2, 0)
	add_child(shape)


func _box(size: Vector3, center: Vector3, yaw := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, -yaw + PI * 0.5), center)
	add_child(shape)


func _add_signs() -> void:
	var boards: Array = _parts["data"]["signs"]
	if boards.is_empty():
		return
	var texts := ["Bahnhof", "Dorfplatz", "Wanderweg"] if item_id == "plaza" else ["Bahnhof", "Dorf"]
	for i in mini(boards.size(), texts.size()):
		for face: float in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = texts[i]
			label.font_size = 44
			label.pixel_size = 0.0032
			label.modulate = Color(0.25, 0.16, 0.1)
			label.outline_size = 0
			label.double_sided = false
			var xform: Transform3D = (boards[i] as Transform3D).translated_local(Vector3(-0.02, -0.005, face * 0.021))
			if face < 0.0:
				xform.basis = xform.basis.rotated(xform.basis.y.normalized(), PI)
			label.transform = xform
			add_child(label)


## Sitzplätze auf Bänken (Grundlage für spätere Dorfbewohner-Ziele).
func _add_seats() -> void:
	var seats: Array = _parts["data"]["seats"]
	for i in seats.size():
		var seat := StationSpot.new()
		seat.name = "Seat%d" % i
		seat.kind = StationSpot.Kind.SEAT
		seat.station_name = "Dorfplatz"
		seat.transform = seats[i]
		add_child(seat)
