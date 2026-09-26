## Eine Weiche: ein Knoten mit drei Gleisen.
##
## Das Stammgleis (trunk) führt auf die Weiche zu, dahinter teilt sie sich in
## zwei Äste. Ast 0 ist der gerade(re) Strang, Ast 1 der abzweigende.
## [member state] gibt an, welcher Ast befahrbar ist.
class_name RailSwitch
extends RefCounted

var node_id: int
var trunk_segment_id: int
## [gerader Ast, abzweigender Ast]
var branch_segment_ids: Array[int] = []
## 0 = gerader Ast, 1 = abzweigender Ast
var state := 0
## Seite, zu der der abzweigende Ast wegführt (+1 rechts, -1 links) – für die Optik.
var diverging_side := 1.0


func get_active_branch() -> int:
	return branch_segment_ids[state]


func is_branch(segment_id: int) -> bool:
	return branch_segment_ids.has(segment_id)
