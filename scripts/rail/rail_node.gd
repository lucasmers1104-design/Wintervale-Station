## Verbindungspunkt im Gleisnetz – dort, wo Gleisstücke beginnen oder enden.
##
## Ein Knoten mit einem Gleis ist ein offenes Ende (Prellbock), mit zwei
## Gleisen eine Stoßstelle. Drei und mehr sind für Weichen vorgesehen.
class_name RailNode
extends RefCounted

enum ConnectionType {
	## Offenes Gleisende – hier steht ein Prellbock, hier kann weitergebaut werden.
	END,
	## Zwei Gleise sind durchgehend verbunden.
	JOINT,
	## Drei oder mehr Gleise: Weiche (folgt in einer späteren Etappe).
	SWITCH,
}

var id: int
var position: Vector3
## IDs aller Gleisstücke, die hier beginnen oder enden.
var segment_ids: Array[int] = []


func _init(p_id: int, p_position: Vector3) -> void:
	id = p_id
	position = p_position


func get_connection_type() -> ConnectionType:
	match segment_ids.size():
		0, 1:
			return ConnectionType.END
		2:
			return ConnectionType.JOINT
		_:
			return ConnectionType.SWITCH


func is_open() -> bool:
	return segment_ids.size() == 1
