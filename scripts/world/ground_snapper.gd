## Setzt beim Start alle direkten Kinder auf die Terrainhöhe.
##
## Die ursprüngliche Y-Position eines Kindes bleibt als Versatz erhalten –
## so bleibt z.B. eine gestapelte Kiste (y = 1) auf der unteren liegen.
## Erwartet, dass dieser Node selbst auf Höhe 0 liegt.
class_name GroundSnapper
extends Node3D

@export var terrain: LowPolyTerrain


func _ready() -> void:
	if terrain == null:
		push_warning("GroundSnapper: Kein Terrain zugewiesen.")
		return
	for child in get_children():
		var node := child as Node3D
		if node:
			var world := node.global_position
			node.position.y = terrain.get_height(world.x, world.z) + node.position.y
