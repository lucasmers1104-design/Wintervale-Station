## Basisklasse aller Bauwerkzeuge.
##
## Ein Werkzeug ist ein Kind-Node von [BuildMode]. Es bekommt Eingaben nur,
## solange es aktiv ist, und zeigt seine Vorschau als eigene Kind-Nodes an
## (sie verschwinden automatisch mit dem Werkzeug).
##
## Neues Werkzeug anlegen: von BuildTool erben, [member tool_id] setzen und
## die virtuellen Methoden überschreiben.
class_name BuildTool
extends Node3D

## Eindeutiger Name, z.B. &"rail" – wird von UI und Tastenkürzeln benutzt.
@export var tool_id: StringName

var context: BuildContext

var _status := ""


## Einmalige Einrichtung durch den BuildMode.
func setup(p_context: BuildContext) -> void:
	context = p_context
	visible = false
	_on_setup()


func activate() -> void:
	visible = true


func deactivate() -> void:
	cancel()
	visible = false
	set_status("")


## Bricht eine laufende Aktion ab. true = es gab etwas abzubrechen.
func cancel() -> bool:
	return false


## Eingabe verarbeiten. true = Eingabe wurde verbraucht.
func handle_input(_event: InputEvent) -> bool:
	return false


## Wird jeden Frame aufgerufen, solange das Werkzeug aktiv ist.
func update_tool(_delta: float) -> void:
	pass


## Kurzer Hinweis für die UI (z.B. warum etwas nicht gebaut werden kann).
func set_status(text: String) -> void:
	if text != _status:
		_status = text
		Events.build_status_changed.emit(text)


func get_status() -> String:
	return _status


func _on_setup() -> void:
	pass
