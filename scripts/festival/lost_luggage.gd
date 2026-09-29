## Ein vergessener Koffer am Bahnsteig (Zug-Event "Fundsache").
##
## Die Spielfigur kann ihn aufheben (Taste E) und trägt ihn dann in der Hand.
## Der Besitzer kommt mit dem nächsten Zug zurück, sucht ihn ("?") – bringt man
## ihn hin, bedankt er sich überglücklich. Findet er ihn selbst, nimmt er ihn mit.
class_name LostLuggage
extends Node3D

signal picked_up(luggage: LostLuggage)

## Aus diesem Zug wurde er vergessen – der Besitzer fuhr nach [member destination].
var destination := ""
var owner_look: CharacterAppearance
var owner_npc: Npc
var created_hours := 0.0
var created_day := 0
var carried := false

var _mesh: Node3D
var _marker: SpeechBubble
var _time := 0.0


func _ready() -> void:
	add_to_group(PlayerInteraction.GROUP)
	_mesh = Node3D.new()
	add_child(_mesh)
	# Derselbe Koffer, den die Figuren tragen: Leder, zwei Riemen, Griff
	var case := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.36, 0.27, 0.13)
	case.mesh = box
	case.position = Vector3(0, 0.14, 0)
	case.material_override = _material(Color(0.58, 0.36, 0.22))
	_mesh.add_child(case)
	for x: float in [-0.12, 0.12]:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.03, 0.275, 0.14)
		strap.mesh = strap_mesh
		strap.position = Vector3(x, 0.14, 0)
		strap.material_override = _material(Color(0.32, 0.2, 0.14))
		_mesh.add_child(strap)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.12, 0.04, 0.03)
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 0.3, 0)
	handle.material_override = _material(Color(0.32, 0.2, 0.14))
	_mesh.add_child(handle)
	# Ein kleiner Anhänger mit Adresse (hell, damit man den Koffer findet)
	var tag := MeshInstance3D.new()
	var tag_mesh := BoxMesh.new()
	tag_mesh.size = Vector3(0.06, 0.08, 0.005)
	tag.mesh = tag_mesh
	tag.position = Vector3(0.05, 0.36, 0.02)
	tag.material_override = _material(Color(0.96, 0.92, 0.8))
	_mesh.add_child(tag)
	_marker = SpeechBubble.new()
	_marker.position = Vector3(0, 1.0, 0)
	add_child(_marker)


func _process(delta: float) -> void:
	if carried:
		return
	_time += delta
	# Ab und zu ein "!" darüber, damit man ihn sieht
	if not _marker.is_showing() and fmod(_time, 7.0) < delta:
		_marker.show_icon("suitcase", 2.8)


func get_interaction_point() -> Vector3:
	return global_position


func get_interaction_text(player: Node) -> String:
	if carried or not visible:
		return ""
	var controller := player as PlayerController
	if controller and controller.get_model().carry != CharacterModel.Carry.NONE:
		return ""
	return "Koffer aufheben"


func interact(player: Node) -> void:
	var controller := player as PlayerController
	if controller == null or carried:
		return
	carried = true
	controller.get_model().carry = CharacterModel.Carry.SUITCASE
	visible = false
	_marker.hide_now()
	remove_from_group(PlayerInteraction.GROUP)
	Events.notification_requested.emit("Koffer aufgehoben – der Besitzer kommt bestimmt zurück.")
	picked_up.emit(self)


static var _materials := {}


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		_materials[key] = material
	return _materials[key]
