## Stellwerk: Sicherungslogik für Blöcke, Fahrwege, Signale und Weichen.
##
## Regeln (einfaches, aber sicheres Blocksystem):
## - Ein Block (Gleise zwischen Signalen) ist belegt, sobald eines seiner
##   Gleise belegt ist (heute: Testsimulation, später: Züge).
## - Ein Signal auf Automatik bildet einen Fahrweg bis zum nächsten Signal in
##   Fahrtrichtung (oder bis zum Gleisende) und folgt dabei der Weichenstellung.
## - Ein Fahrweg reserviert alle berührten Blöcke exklusiv. Ist ein Block
##   belegt oder schon von einem anderen Fahrweg reserviert, bleibt das Signal rot.
##   → Ein grünes Signal kann nie einen Konflikt mit einem anderen Fahrweg erlauben.
## - Wird der Fahrweg befahren, fällt das Signal auf Rot. Ist er danach wieder
##   frei, wird er aufgelöst.
## - Weichen lassen sich nicht umstellen, wenn ihr Block belegt ist oder ein
##   befahrener Fahrweg über sie führt. Unbefahrene Automatik-Fahrwege werden
##   beim Umstellen aufgelöst und danach neu gebildet.
##
## Züge nutzen später dieselbe Schnittstelle: set_segment_occupied() und
## die Fahrwege (get_route()).
class_name RailInterlocking
extends Node

## Signalbilder, Belegung oder Reservierungen haben sich geändert.
signal state_changed

const SAVE_ID := "rail_interlocking"

@export var network: RailNetwork
## Wie oft Fahrwege und Signale neu bewertet werden (Sekunden).
@export var update_interval := 0.25

var _occupied: Dictionary[int, bool] = {}
var _routes: Dictionary[int, RailRoute] = {}
var _reserved_blocks: Dictionary[int, int] = {}
var _timer := 0.0
var _last_snapshot := ""


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	network.topology_changed.connect(_on_topology_changed)
	network.switch_changed.connect(func(_node_id: int) -> void: evaluate())
	network.signal_mode_changed.connect(func(_signal_id: int) -> void: evaluate())


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		evaluate()


# --- Belegung ------------------------------------------------------------------------

func set_segment_occupied(segment_id: int, occupied: bool) -> void:
	if occupied:
		_occupied[segment_id] = true
	else:
		_occupied.erase(segment_id)
	evaluate()


func is_segment_occupied(segment_id: int) -> bool:
	return _occupied.has(segment_id)


func is_block_occupied(block_id: int) -> bool:
	for segment_id in network.get_block_segments(block_id):
		if _occupied.has(segment_id):
			return true
	return false


func get_occupied_segments() -> Array[int]:
	var list: Array[int] = []
	list.assign(_occupied.keys())
	return list


# --- Fahrwege ------------------------------------------------------------------------

func get_route(signal_id: int) -> RailRoute:
	return _routes.get(signal_id)


func is_block_reserved(block_id: int) -> bool:
	return _reserved_blocks.has(block_id)


## Signal-ID, deren Fahrweg den Block reserviert hat (-1 = frei).
func get_block_owner(block_id: int) -> int:
	return _reserved_blocks.get(block_id, -1)


func get_reserved_segments() -> Array[int]:
	var list: Array[int] = []
	for route: RailRoute in _routes.values():
		for block_id in route.blocks:
			list.append_array(network.get_block_segments(block_id))
	return list


## Ermittelt den Fahrweg eines Signals anhand der aktuellen Weichenstellung.
func build_route(rail_signal: RailSignal) -> RailRoute:
	var route := RailRoute.new()
	route.signal_id = rail_signal.id
	var segment_id := rail_signal.segment_id
	var node_id := rail_signal.node_id
	var visited := {}
	while true:
		var segment := network.get_segment(segment_id)
		if segment == null or visited.has(segment_id):
			if visited.has(segment_id):
				route.error = "Fahrweg bildet eine Schleife"
			break
		visited[segment_id] = true
		route.segments.append(segment_id)
		route.segment_blocks[segment_id] = segment.block_id
		if not route.blocks.has(segment.block_id):
			route.blocks.append(segment.block_id)

		var exit_node := segment.get_other_node(node_id)
		var switch := network.get_switch(exit_node)
		var next := network.get_next_segments(segment_id, exit_node, true)
		if switch:
			if next.is_empty():
				route.error = "Weiche falsch gestellt"
				break
			route.switch_positions[exit_node] = switch.state
		if next.is_empty():
			break  # Gleisende: Fahrweg endet am Prellbock
		if network.get_signal_for(exit_node, next[0]):
			break  # Nächstes Signal in Fahrtrichtung erreicht
		node_id = exit_node
		segment_id = next[0]
	return route


## Warum ein Fahrweg gerade nicht reserviert werden kann ("" = möglich).
func check_route(route: RailRoute) -> String:
	if route.error != "":
		return route.error
	for block_id in route.blocks:
		if is_block_occupied(block_id):
			return "Abschnitt belegt"
		var holder := get_block_owner(block_id)
		if holder >= 0 and holder != route.signal_id:
			return "Fahrweg von Signal %d reserviert" % holder
	return ""


# --- Weichen -------------------------------------------------------------------------

## Warum die Weiche gerade nicht umgestellt werden darf ("" = erlaubt).
func can_toggle_switch(node_id: int) -> String:
	var switch := network.get_switch(node_id)
	if switch == null:
		return "Hier ist keine Weiche"
	var block_id := network.get_segment(switch.trunk_segment_id).block_id
	if is_block_occupied(block_id):
		return "Weiche ist belegt"
	for route: RailRoute in _routes.values():
		if route.entered and route.switch_positions.has(node_id):
			return "Weiche liegt in einem befahrenen Fahrweg"
	return ""


## Stellt die Weiche um, wenn es sicher ist. Gibt "" oder den Ablehnungsgrund zurück.
func request_switch_toggle(node_id: int) -> String:
	var reason := can_toggle_switch(node_id)
	if reason != "":
		return reason
	for signal_id: int in _routes.keys():
		if _routes[signal_id].switch_positions.has(node_id):
			_release(signal_id)
	var switch := network.get_switch(node_id)
	network.set_switch_state(node_id, 1 - switch.state)
	evaluate()
	return ""


# --- Bewertung -----------------------------------------------------------------------

## Prüft alle Fahrwege und setzt die Signalbilder. Wird regelmäßig und nach
## jeder Änderung aufgerufen.
func evaluate() -> void:
	# 1. Bestehende Fahrwege prüfen und ggf. auflösen
	for signal_id: int in _routes.keys():
		var route := _routes[signal_id]
		var rail_signal := network.get_signal(signal_id)
		if rail_signal == null or rail_signal.mode == RailSignal.Mode.HALT or not _is_still_valid(route):
			_release(signal_id)
		elif _any_block_occupied(route.blocks):
			route.entered = true
		elif route.entered:
			_release(signal_id)  # Fahrweg wurde befahren und wieder geräumt

	# 2. Automatik-Signale versuchen, einen Fahrweg zu bilden (feste Reihenfolge)
	for rail_signal in network.get_signals():
		if _routes.has(rail_signal.id):
			continue
		if rail_signal.mode == RailSignal.Mode.HALT:
			rail_signal.reason = "Auf Halt gestellt"
			continue
		var route := build_route(rail_signal)
		var reason := check_route(route)
		if reason == "":
			_reserve(route)
		rail_signal.reason = reason

	# 3. Signalbilder
	for rail_signal in network.get_signals():
		var route := get_route(rail_signal.id)
		if route and not route.entered and not _any_block_occupied(route.blocks):
			rail_signal.aspect = RailSignal.Aspect.CLEAR
			rail_signal.reason = "Fahrt frei"
		else:
			rail_signal.aspect = RailSignal.Aspect.STOP
			if route and route.entered:
				rail_signal.reason = "Fahrweg wird befahren"

	var snapshot := _snapshot()
	if snapshot != _last_snapshot:
		_last_snapshot = snapshot
		state_changed.emit()


func _reserve(route: RailRoute) -> void:
	_routes[route.signal_id] = route
	for block_id in route.blocks:
		_reserved_blocks[block_id] = route.signal_id


func _release(signal_id: int) -> void:
	var route: RailRoute = _routes.get(signal_id)
	if route == null:
		return
	for block_id in route.blocks:
		if _reserved_blocks.get(block_id, -1) == signal_id:
			_reserved_blocks.erase(block_id)
	_routes.erase(signal_id)


## Stimmen Gleise, Blöcke und Weichenstellungen noch mit dem Fahrweg überein?
func _is_still_valid(route: RailRoute) -> bool:
	for segment_id: int in route.segment_blocks:
		var segment := network.get_segment(segment_id)
		if segment == null or segment.block_id != route.segment_blocks[segment_id]:
			return false
	for node_id: int in route.switch_positions:
		var switch := network.get_switch(node_id)
		if switch == null or switch.state != route.switch_positions[node_id]:
			return false
	return true


func _any_block_occupied(blocks: Array[int]) -> bool:
	for block_id in blocks:
		if is_block_occupied(block_id):
			return true
	return false


func _on_topology_changed() -> void:
	# Umbau: alle Fahrwege neu bilden, Belegung entfernter Gleise vergessen
	for signal_id: int in _routes.keys():
		_release(signal_id)
	for segment_id: int in _occupied.keys():
		if network.get_segment(segment_id) == null:
			_occupied.erase(segment_id)
	evaluate()


func _snapshot() -> String:
	var parts: Array[String] = []
	for rail_signal in network.get_signals():
		parts.append("%d:%d" % [rail_signal.id, rail_signal.aspect])
	var occupied := _occupied.keys()
	occupied.sort()
	var reserved := _reserved_blocks.keys()
	reserved.sort()
	return "%s|%s|%s" % [",".join(parts), str(occupied), str(reserved)]


# --- Speichern -------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"occupied": _occupied.keys()}


func load_state(data: Dictionary) -> void:
	_occupied.clear()
	for value: Variant in data.get("occupied", []):
		if network.get_segment(int(value)):
			_occupied[int(value)] = true
	for signal_id: int in _routes.keys():
		_release(signal_id)
	evaluate()
