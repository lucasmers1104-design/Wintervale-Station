@tool
## Bahnhofsuhr mit zwei Zifferblättern (Blick nach ±X), Zeigern nach der
## Spielzeit und leichter Hinterleuchtung bei Nacht.
## Steht auf einem Mast oder hängt (mounted) unter dem Bahnsteigdach.
class_name StationClock
extends Node3D

## true = hängt unter einem Dach (ohne Mast).
@export var mounted := false
@export var face_height := 2.9
@export var radius := 0.38

var _hour_hands: Array[Node3D] = []
var _minute_hands: Array[Node3D] = []
var _face_material: StandardMaterial3D


func _ready() -> void:
	_build()
	_update_hands(15.0 if Engine.is_editor_hint() else WorldClock.time_of_day)
	if not Engine.is_editor_hint():
		WorldClock.darkness_changed.connect(_on_darkness_changed)
		_on_darkness_changed(WorldClock.is_dark())


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_update_hands(WorldClock.time_of_day)


## Zeigerwinkel (Minuten- und Stundenzeiger) für Tests.
func get_hand_angles() -> Vector2:
	return Vector2(_minute_hands[0].rotation.x, _hour_hands[0].rotation.x)


func _update_hands(hours: float) -> void:
	var minute_angle := fmod(hours, 1.0) * TAU
	var hour_angle := fmod(hours, 12.0) / 12.0 * TAU
	for i in _hour_hands.size():
		# Auf der +X-Seite dreht "im Uhrzeigersinn" negativ um X, auf der -X-Seite positiv.
		var direction := -1.0 if i == 0 else 1.0
		_minute_hands[i].rotation.x = direction * minute_angle
		_hour_hands[i].rotation.x = direction * hour_angle


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	_hour_hands.clear()
	_minute_hands.clear()
	var iron := _material(Color(0.14, 0.15, 0.17), 0.5)
	_face_material = _material(Color(0.95, 0.93, 0.86), 0.6)
	_face_material.emission_enabled = true
	_face_material.emission = Color(1.0, 0.9, 0.7)
	_face_material.emission_energy_multiplier = 0.0
	var hand_material := _material(Color(0.08, 0.08, 0.09), 0.4)

	if mounted:
		_add_box(Vector3(0.0, face_height + radius + 0.35, 0.0), Vector3(0.05, 0.7, 0.05), iron)
	else:
		_add_cylinder(Vector3(0.0, face_height * 0.5 - 0.1, 0.0), 0.07, face_height - 0.2, iron, false)
		_add_cylinder(Vector3(0.0, 0.1, 0.0), 0.18, 0.2, iron, false)
	# Gehäuse (dunkler Ring) und zwei Zifferblätter
	_add_cylinder(Vector3(0.0, face_height, 0.0), radius + 0.05, 0.16, iron, true)
	for side: float in [1.0, -1.0]:
		_add_cylinder(Vector3(side * 0.085, face_height, 0.0), radius, 0.02, _face_material, true)
		# Stundenmarken
		for i in 12:
			var angle := TAU * i / 12.0
			var mark := Vector3(side * 0.1, face_height + cos(angle) * radius * 0.82, sin(angle) * radius * 0.82)
			_add_box(mark, Vector3(0.01, 0.05 if i % 3 == 0 else 0.03, 0.02), hand_material)
		_hour_hands.append(_add_hand(side, radius * 0.5, 0.035, hand_material))
		_minute_hands.append(_add_hand(side, radius * 0.78, 0.022, hand_material))
	_add_box(Vector3(0.0, face_height + radius + 0.07, 0.0), Vector3(0.14, 0.04, radius * 1.6), _material(Color(0.9, 0.93, 0.97), 1.0))


func _add_hand(side: float, hand_length: float, width: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.11, face_height, 0.0)
	_add_generated(pivot)
	var hand := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, hand_length, width)
	hand.mesh = box
	hand.material_override = material
	hand.position = Vector3(0.0, hand_length * 0.5 - 0.03, 0.0)
	pivot.add_child(hand)
	return pivot


func _add_box(center: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = center
	_add_generated(instance)


func _add_cylinder(center: Vector3, cylinder_radius: float, height: float, material: Material, along_x: bool) -> void:
	var instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = cylinder_radius
	cylinder.bottom_radius = cylinder_radius
	cylinder.height = height
	cylinder.radial_segments = 20
	cylinder.rings = 0
	instance.mesh = cylinder
	instance.material_override = material
	instance.position = center
	if along_x:
		instance.rotation.z = PI * 0.5
	_add_generated(instance)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _on_darkness_changed(dark: bool) -> void:
	_face_material.emission_energy_multiplier = 0.9 if dark else 0.0


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
