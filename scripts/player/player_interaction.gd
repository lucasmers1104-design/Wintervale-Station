## Interaktion der Spielfigur (Taste E): mit Bewohnern sprechen, einen vergessenen
## Koffer aufheben und seinem Besitzer zurückbringen …
##
## Alles, womit man etwas tun kann, ist in der Gruppe [constant GROUP] und bietet:
##   get_interaction_point() -> Vector3       wo es steht
##   get_interaction_text(player) -> String   Hinweis ("" = gerade nicht möglich)
##   interact(player) -> void                 die Handlung
## Gewählt wird das Nächste in Reichweite vor der Figur. Der Hinweis erscheint im
## HUD ([code]Events.interaction_prompt_changed[/code]). Nur beim Erkunden.
class_name PlayerInteraction
extends Node

const GROUP := &"interactable"
const REACH := 2.4
const SCAN_INTERVAL := 0.12

var _player: PlayerController
var _target: Node
var _prompt := ""
var _timer := 0.0
var _exploring := true


func _ready() -> void:
	_player = get_parent() as PlayerController
	Events.view_mode_changed.connect(func(mode: GameDefs.ViewMode) -> void:
		_exploring = mode == GameDefs.ViewMode.EXPLORE
		if not _exploring:
			_set_target(null))


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SCAN_INTERVAL
	if _player == null or not _exploring or not _player.input_enabled:
		_set_target(null)
		return
	_set_target(find_target())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or _target == null or not is_instance_valid(_target):
		return
	if not _exploring or not _player.input_enabled:
		return
	_target.call(&"interact", _player)
	get_viewport().set_input_as_handled()
	# Hinweis sofort auffrischen (z.B. "Koffer aufheben" → "Koffer zurückgeben")
	_prompt = ""
	_set_target(find_target())


## Das Nächste, womit die Figur gerade etwas tun kann (oder null).
func find_target() -> Node:
	var here := _player.global_position
	var facing := _player.get_facing()
	var best: Node = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(GROUP):
		if not node.is_inside_tree():
			continue
		var point: Vector3 = node.call(&"get_interaction_point")
		var offset := point - here
		offset.y = 0.0
		var distance := offset.length()
		if distance > REACH or absf(point.y - here.y) > 1.6:
			continue
		if String(node.call(&"get_interaction_text", _player)) == "":
			continue
		# Was vor der Figur liegt, gewinnt – ganz nah zählt auch seitlich
		var ahead := offset.normalized().dot(facing) if distance > 0.3 else 1.0
		if ahead < -0.2:
			continue
		var score := distance * (1.6 - ahead * 0.6)
		if score < best_score:
			best_score = score
			best = node
	return best


func get_target() -> Node:
	return _target


func _set_target(target: Node) -> void:
	_target = target
	var text := String(target.call(&"get_interaction_text", _player)) if target else ""
	if text != _prompt:
		_prompt = text
		Events.interaction_prompt_changed.emit(text)
