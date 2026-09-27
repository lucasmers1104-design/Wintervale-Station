@tool
## Ein Platz am Bahnsteig, an dem ein Bewohner verweilt.
##
## -Z des Markers ist die Blickrichtung. Sitzplätze liegen auf der Sitzfläche
## (werden von [StationProp]-Bänken selbst angelegt), alle anderen Plätze auf
## dem Boden. Ein Platz kann immer nur von einem Bewohner belegt werden.
class_name StationSpot
extends Marker3D

const GROUP := &"station_spot"

enum Kind {
	## Sitzplatz auf einer Bank.
	SEAT,
	## Stehplatz mit Blick zu den Gleisen – hier wartet man auf den Zug.
	STAND,
	## Blick auf die Bahnhofsuhr.
	CLOCK,
	## Vor der Abfahrtstafel oder dem Fahrplanaushang.
	BOARD,
}

@export var kind := Kind.STAND
@export var station_name := "Wintervale"

var occupant: Node = null


func _ready() -> void:
	add_to_group(GROUP)


func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)


func reserve(who: Node) -> bool:
	if not is_free() and occupant != who:
		return false
	occupant = who
	return true


func release(who: Node) -> void:
	if occupant == who:
		occupant = null


## Blickrichtung (Draufsicht).
func get_facing() -> Vector3:
	var facing := -global_basis.z
	facing.y = 0.0
	return facing.normalized()


## Hierhin läuft man, bevor man den Platz einnimmt (bei Bänken: vor die Sitzfläche).
func get_approach_point() -> Vector3:
	if kind == Kind.SEAT:
		return global_position + get_facing() * 0.5
	return global_position


## Passende Haltung für diesen Platz.
func get_pose() -> CharacterModel.Pose:
	match kind:
		Kind.SEAT:
			return CharacterModel.Pose.SIT
		Kind.CLOCK, Kind.BOARD:
			return CharacterModel.Pose.LOOK_UP
	return CharacterModel.Pose.STAND
