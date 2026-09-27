## Ein Hauptsignal. Es steht an einem Knoten und sichert die Einfahrt in
## ein Gleisstück: Züge, die vom Knoten aus in [member segment_id] fahren,
## müssen es beachten.
##
## Das Signalbild (Rot/Grün) berechnet [RailInterlocking] aus Blockbelegung
## und Fahrwegreservierung.
class_name RailSignal
extends RefCounted

enum Mode {
	## Automatik: zeigt Grün, sobald der Fahrweg frei ist und reserviert werden konnte.
	AUTO,
	## Halt: bleibt immer rot (manuell gesetzt).
	HALT,
	## Zuglenkung: bleibt rot, bis ein Zug einen Fahrweg anfordert (Bahnhöfe).
	ROUTE,
}
enum Aspect { STOP, CLEAR }

var id: int
var node_id: int
## Das Gleis hinter dem Signal (in Fahrtrichtung).
var segment_id: int
var mode := Mode.AUTO
## Modus, zu dem ein auf Halt gestelltes Signal zurückkehrt.
var resume_mode := Mode.AUTO
## Laufzeitzustand – wird nicht gespeichert, sondern immer neu berechnet.
var aspect := Aspect.STOP
## Kurze Begründung für das aktuelle Signalbild (für die UI).
var reason := ""


func _init(p_id: int, p_node_id: int, p_segment_id: int, p_mode := Mode.AUTO) -> void:
	id = p_id
	node_id = p_node_id
	segment_id = p_segment_id
	mode = p_mode
	resume_mode = p_mode if p_mode != Mode.HALT else Mode.AUTO


func to_dict() -> Dictionary:
	return {"id": id, "node": node_id, "segment": segment_id, "mode": mode, "resume_mode": resume_mode}
