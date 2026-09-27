## Haltepunkt eines Bahnsteiggleises.
##
## Liegt auf der Gleisachse in der Bahnsteigmitte. Züge halten so, dass ihre
## Mitte hier steht. [member platform_direction] zeigt vom Gleis zum
## Bahnsteig – daran erkennt der Zug, auf welcher Seite er die Türen öffnet.
class_name PlatformStop
extends Node3D

const GROUP := &"platform_stop"

@export var station_name := "Wintervale"
@export var platform_number := 1
## Richtung vom Gleis zum Bahnsteig (Draufsicht).
@export var platform_direction := Vector3(-1.0, 0.0, 0.0)


func _ready() -> void:
	add_to_group(GROUP)


func get_platform_direction() -> Vector3:
	return platform_direction.normalized()


## Das Bahnsteiggleis (nächstes Gleis am Haltepunkt).
func get_segment(network: RailNetwork) -> RailSegment:
	return network.find_segment_near(global_position, 2.0)
