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

## Testbelegung (Simulation-Werkzeug) – wird gespeichert.
var _occupied: Dictionary[int, bool] = {}
## Belegung durch Züge: Zug-ID → Gleise (nicht gespeichert, Züge melden sich neu).
var _train_occupancy: Dictionary[int, Array] = {}
var _train_segments: Dictionary[int, bool] = {}
var _evaluate_suspended := false
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


## Belegt durch Testsimulation oder durch einen Zug.
func is_segment_occupied(segment_id: int) -> bool:
	return _occupied.has(segment_id) or _train_segments.has(segment_id)


## Nur die Testbelegung (Simulation-Werkzeug).
func is_segment_test_occupied(segment_id: int) -> bool:
	return _occupied.has(segment_id)


func is_block_occupied(block_id: int) -> bool:
	for segment_id in network.get_block_segments(block_id):
		if is_segment_occupied(segment_id):
			return true
	return false


func get_occupied_segments() -> Array[int]:
	var list: Array[int] = []
	list.assign(_occupied.keys())
	for segment_id: int in _train_segments:
		if not list.has(segment_id):
			list.append(segment_id)
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
		if not route.switch_positions.has(node_id) or not route.blocks.has(block_id):
			continue
		if route.entered:
			return "Weiche liegt in einem befahrenen Fahrweg"
		if route.requested:
			return "Weiche liegt im Fahrweg eines Zuges"
	return ""


# --- Fahrwege für Züge ----------------------------------------------------------------

## Ein Zug fordert am Signal einen Fahrweg entlang seines Weges an
## ([param path] = Gleis-IDs ab dem Gleis hinter dem Signal). Das Stellwerk
## stellt dafür die Weichen – aber nur, wenn alles frei und sicher ist.
## Gibt "" (Fahrt frei) oder den Grund zurück, warum der Zug warten muss.
func request_route(signal_id: int, path: Array[int], owner_id := -1) -> String:
	var rail_signal := network.get_signal(signal_id)
	if rail_signal == null:
		return "Kein Signal"
	if rail_signal.mode == RailSignal.Mode.HALT:
		return "Signal steht auf Halt"
	var existing := get_route(signal_id)
	# Ein befahrener Fahrweg gehört noch dem vorigen Zug – nie weiterreichen!
	if existing and existing.entered:
		return "Vorheriger Zug noch im Fahrweg"
	if existing and is_route_for_path(signal_id, path, owner_id):
		return ""

	var route := _route_along(rail_signal, path)
	if route.error != "":
		return route.error
	for node_id: int in route.switch_positions:
		var switch := network.get_switch(node_id)
		if switch.state != route.switch_positions[node_id]:
			var reason := can_toggle_switch(node_id)
			if reason != "":
				return reason
	var owner_before := _reserved_owner_excluding(route, signal_id)
	if owner_before != "":
		return owner_before

	_evaluate_suspended = true
	if existing:
		_release(signal_id)
	for node_id: int in route.switch_positions:
		network.set_switch_state(node_id, route.switch_positions[node_id])
	_evaluate_suspended = false
	route.requested = true
	route.owner_id = owner_id
	_reserve(route)
	evaluate()
	return ""


## Gehört der Fahrweg des Signals diesem Zug und deckt er dessen Weg ab?
func is_route_for_path(signal_id: int, path: Array[int], owner_id := -1) -> bool:
	var route := get_route(signal_id)
	if route == null or route.segments.is_empty():
		return false
	if route.owner_id != owner_id:
		return false
	for i in route.segments.size():
		if i >= path.size() or path[i] != route.segments[i]:
			return false
	return true


## Fahrweg entlang eines vorgegebenen Weges bis zum nächsten Signal (oder Wegende).
func _route_along(rail_signal: RailSignal, path: Array[int]) -> RailRoute:
	var route := RailRoute.new()
	route.signal_id = rail_signal.id
	if path.is_empty() or path[0] != rail_signal.segment_id:
		route.error = "Weg passt nicht zum Signal"
		return route
	var node_id := rail_signal.node_id
	for i in path.size():
		var segment := network.get_segment(path[i])
		if segment == null:
			route.error = "Gleis fehlt"
			return route
		route.segments.append(segment.id)
		route.segment_blocks[segment.id] = segment.block_id
		if not route.blocks.has(segment.block_id):
			route.blocks.append(segment.block_id)
		var exit_node := segment.get_other_node(node_id)
		if i + 1 >= path.size():
			break
		var next := path[i + 1]
		if not network.get_next_segments(segment.id, exit_node, false).has(next):
			route.error = "Weg nicht befahrbar"
			return route
		var switch := network.get_switch(exit_node)
		if switch:
			if segment.id == switch.trunk_segment_id:
				route.switch_positions[exit_node] = switch.branch_segment_ids.find(next)
			else:
				route.switch_positions[exit_node] = switch.branch_segment_ids.find(segment.id)
		if network.get_signal_for(exit_node, next):
			break
		node_id = exit_node
	return route


## Prüft Belegung und fremde Reservierungen eines Fahrwegs ("" = frei).
func _reserved_owner_excluding(route: RailRoute, signal_id: int) -> String:
	for block_id in route.blocks:
		if is_block_occupied(block_id):
			return "Abschnitt belegt"
		var holder := get_block_owner(block_id)
		if holder >= 0 and holder != signal_id:
			return "Fahrweg von Signal %d reserviert" % holder
	return ""


# --- Zugbelegung ----------------------------------------------------------------------

## Meldet, welche Gleise ein Zug gerade belegt (ersetzt die vorige Meldung).
## Getrennt von der Testbelegung, damit Züge nichts in Spielstände schreiben.
func set_train_occupancy(train_id: int, segment_ids: Array[int]) -> void:
	var previous: Array = _train_occupancy.get(train_id, [])
	if previous == segment_ids:
		return
	_train_occupancy[train_id] = segment_ids.duplicate()
	_rebuild_train_segments()
	evaluate()


func clear_train_occupancy(train_id: int) -> void:
	if _train_occupancy.erase(train_id):
		_rebuild_train_segments()
		evaluate()


## Ein Zug verschwindet (Zieltunnel, Laden eines Spielstands): alle Fahrwege,
## die er angefordert hat, werden frei – sonst blieben ihre Weichen gesperrt.
func release_routes_of(owner_id: int) -> void:
	if owner_id < 0:
		return
	var released := false
	for signal_id: int in _routes.keys():
		if _routes[signal_id].owner_id == owner_id:
			_release(signal_id)
			released = true
	if released:
		evaluate()


## Welcher Zug belegt das Gleis (-1 = keiner)?
func get_train_on_segment(segment_id: int) -> int:
	for train_id: int in _train_occupancy:
		if (_train_occupancy[train_id] as Array).has(segment_id):
			return train_id
	return -1


func _rebuild_train_segments() -> void:
	_train_segments.clear()
	for train_id: int in _train_occupancy:
		for segment_id: int in _train_occupancy[train_id]:
			_train_segments[segment_id] = true


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
	if _evaluate_suspended:
		return
	# 1. Bestehende Fahrwege prüfen und ggf. auflösen
	for signal_id: int in _routes.keys():
		var route := _routes[signal_id]
		var rail_signal := network.get_signal(signal_id)
		if rail_signal == null or rail_signal.mode == RailSignal.Mode.HALT or not _is_still_valid(route):
			_release(signal_id)
		elif _any_block_occupied(route.blocks):
			route.entered = true
			_release_cleared_blocks(route)
			if _is_parked_at_destination(route):
				_release(signal_id)
		elif route.entered:
			_release(signal_id)  # Fahrweg wurde befahren und wieder geräumt

	# 2. Automatik-Signale versuchen, einen Fahrweg zu bilden (feste Reihenfolge)
	for rail_signal in network.get_signals():
		if _routes.has(rail_signal.id):
			continue
		if rail_signal.mode == RailSignal.Mode.HALT:
			rail_signal.reason = "Auf Halt gestellt"
			continue
		if rail_signal.mode == RailSignal.Mode.ROUTE:
			rail_signal.reason = "Wartet auf einen Zug"
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


## Zielgleis-Auflösung: Steht der Zug, der den Fahrweg angefordert hat, vollständig
## im letzten Abschnitt seines Fahrwegs (am Bahnsteig, beim Entladen im
## Güterbahnhof), ist der Fahrweg erfüllt und wird aufgelöst – sonst bliebe das
## Einfahrsignal gesperrt, solange der Zug dort steht. Der Abschnitt selbst bleibt
## durch die Belegung geschützt (kein anderer Fahrweg kann hinein).
func _is_parked_at_destination(route: RailRoute) -> bool:
	if route.owner_id < 0 or route.segments.is_empty() or route.blocks.size() != 1:
		return false
	var last := network.get_segment(route.segments[-1])
	if last == null or route.blocks[0] != last.block_id:
		return false
	var occupied: Array = _train_occupancy.get(route.owner_id, [])
	if occupied.is_empty():
		return false
	for segment_id: int in occupied:
		var segment := network.get_segment(segment_id)
		if segment == null or segment.block_id != last.block_id:
			return false
	return true


## Teilauflösung: Blöcke, die der Zug befahren und wieder geräumt hat, werden
## sofort freigegeben. Der Rest des Fahrwegs bleibt reserviert.
func _release_cleared_blocks(route: RailRoute) -> void:
	for block_id in route.blocks.duplicate():
		if is_block_occupied(block_id):
			route.seen_blocks[block_id] = true
		elif route.seen_blocks.has(block_id):
			route.blocks.erase(block_id)
			if _reserved_blocks.get(block_id, -1) == route.signal_id:
				_reserved_blocks.erase(block_id)
			for segment_id: int in route.segment_blocks.keys():
				if route.segment_blocks[segment_id] == block_id:
					route.segment_blocks.erase(segment_id)


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
	var occupied := get_occupied_segments()
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
