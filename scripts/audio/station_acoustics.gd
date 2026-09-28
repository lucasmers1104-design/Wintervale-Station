## Bahnhofshall: Unter dem Bahnsteigdach klingen Gong, Türen, Schritte und
## Stimmen mit einem dezenten Nachhall. Ein eigener Audio-Bus mit Hall wird
## beim Start angelegt; der Bereich (Area3D) leitet einen Teil der Klänge
## aller 3D-Klangquellen darin auf diesen Bus.
class_name StationAcoustics
extends Area3D

const BUS_NAME := &"Bahnhof"

@export var size := Vector3(9.0, 6.0, 48.0)
## Anteil, der in den Hall geht (0..1) – bewusst dezent.
@export_range(0.0, 1.0) var amount := 0.3


func _ready() -> void:
	_ensure_bus()
	monitoring = false
	monitorable = true
	collision_layer = GameDefs.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(shape)
	reverb_bus_enabled = true
	reverb_bus_name = BUS_NAME
	reverb_bus_amount = amount
	reverb_bus_uniformity = 0.4


static func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS_NAME)
	AudioServer.set_bus_send(index, &"Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.55
	reverb.damping = 0.65
	reverb.spread = 0.8
	reverb.hipass = 0.15
	reverb.dry = 0.0
	reverb.wet = 0.6
	AudioServer.add_bus_effect(index, reverb)
