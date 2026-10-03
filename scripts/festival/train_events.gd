## Zufällige, ruhige Zug-Ereignisse (Etappe 10):
##
## - **Verspätung:** Bei Schneefall oder Nebel kommt ab und zu ein Zug ein paar
##   Minuten später. Die Anzeigetafel zeigt es, Wartende schauen auf die Uhr.
## - **Schneeräumzug:** Nach starkem Schneefall räumt eine gelbe Lok mit großem
##   Keilpflug die Strecke – mit Schneefontäne und orangen Rundumleuchten.
## - **Fundsache:** Nach einer Abfahrt steht manchmal ein vergessener Koffer am
##   Bahnsteig. Der Besitzer kommt mit dem nächsten Zug zurück und sucht ihn –
##   bringt die Spielfigur ihn hin, gibt es Dank und Finderlohn.
##
## Nichts davon ist hektisch oder hat Folgen, die man verhindern müsste.
class_name TrainEvents
extends Node3D

const SAVE_ID := "train_events"
const REWARD := 30

@export var dispatcher: TrainDispatcher
@export var npc_director: NpcDirector
@export var weather: WeatherSystem
@export var network: RailNetwork
@export var enabled := true
## Wahrscheinlichkeit für einen vergessenen Koffer nach einer Abfahrt.
@export var luggage_chance := 0.2

var luggage: LostLuggage
var _owner: Npc
var _owner_waiting_since := -1.0
var _owner_destination := ""
var _plough_entry: TimetableEntry
var _plough_day := -1
var _plough_added_at := 0.0
var _departures_seen: Dictionary = {}
var _arrivals_seen: Dictionary = {}
var _delay_checked_hour := -1
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _hint_timer := 0.0
var _stats := {"delays": 0, "ploughs": 0, "luggage_returned": 0, "luggage_found": 0}


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	add_to_group(&"train_events")
	_rng.randomize()


func _process(delta: float) -> void:
	if not enabled or dispatcher == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	tick()


func tick() -> void:
	var now := WorldClock.time_of_day
	if int(now) != _delay_checked_hour:
		_delay_checked_hour = int(now)
		_maybe_delay(now)
	_maybe_plough(now)
	_watch_departures(now)
	_watch_arrivals()
	_update_owner(now)
	_update_luggage_timeout(now)


func get_stats() -> Dictionary:
	return _stats


# --- Verspätungen ---------------------------------------------------------------------------

func _maybe_delay(now: float) -> void:
	if weather == null or dispatcher.timetable == null or WorldClock.paused:
		return
	var chance := 0.0
	var minutes := Vector2i(0, 0)
	match weather.current:
		WeatherSystem.Weather.HEAVY_SNOW:
			chance = 0.6
			minutes = Vector2i(8, 16)
		WeatherSystem.Weather.FOG:
			chance = 0.45
			minutes = Vector2i(5, 11)
		WeatherSystem.Weather.LIGHT_SNOW:
			chance = 0.22
			minutes = Vector2i(4, 8)
	if chance <= 0.0 or _rng.randf() > chance:
		return
	var entry := _next_passenger_entry(now, 0.4, 1.5)
	if entry:
		delay_train(entry, _rng.randi_range(minutes.x, minutes.y))


## Den Zug [param entry] um [param minutes] Minuten verspäten (mit Ansage).
func delay_train(entry: TimetableEntry, minutes: int) -> void:
	dispatcher.set_delay(entry, minutes / 60.0)
	_stats["delays"] = int(_stats["delays"]) + 1
	var reason := "Schnee auf der Strecke" if weather == null or weather.current != WeatherSystem.Weather.FOG else "Nebel im Tal"
	Events.notification_requested.emit("%s aus %s: etwa %d Minuten später – %s" % [entry.train_number, entry.origin, minutes, reason])
	# Wer am Bahnsteig wartet, schaut auf die Uhr
	if npc_director:
		for npc in npc_director.get_npcs() + npc_director.get_travellers():
			if is_instance_valid(npc) and npc.state == Npc.State.AT_STATION and _rng.randf() < 0.7:
				npc.show_icon("clock", 3.0)


func _next_passenger_entry(now: float, from_hours: float, to_hours: float) -> TimetableEntry:
	var best: TimetableEntry = null
	var best_ahead := INF
	for i in dispatcher.timetable.entries.size():
		var entry := dispatcher.timetable.entries[i]
		if entry == null or not entry.stops or entry.has_meta(&"festival") or entry.train_type == null:
			continue
		if entry.train_type.category != TrainType.Category.PASSENGER or dispatcher.get_delay(entry) > 0.0:
			continue
		var ahead := fposmod(entry.get_arrival_hours() - now, 24.0)
		if ahead >= from_hours and ahead <= to_hours and ahead < best_ahead and dispatcher._train_for_entry(i) == null:
			best_ahead = ahead
			best = entry
	return best


# --- Schneeräumzug ----------------------------------------------------------------------------

func _maybe_plough(now: float) -> void:
	if _plough_entry and (WorldClock.day != _plough_day or _hours_since(_plough_added_at) > 2.0):
		dispatcher.remove_entries([_plough_entry])
		_plough_entry = null
	if weather == null or _plough_day == WorldClock.day or WorldClock.paused:
		return
	if weather.current != WeatherSystem.Weather.HEAVY_SNOW or Seasons.get_snow_cover() < 0.5:
		return
	if now < 6.0 or now > 21.0:
		return
	send_plough()


## Schickt den Schneeräumzug los (Nordtal → Südtal, ohne Halt).
func send_plough() -> TimetableEntry:
	var entry := TimetableEntry.new()
	entry.train_number = "SR 1"
	entry.train_name = "Schneeräumzug · Nordtal → Südtal"
	entry.train_type = load("res://assets/trains/snowplough.tres")
	entry.origin = "Nordtal"
	entry.destination = "Südtal"
	entry.station = npc_director.station_name if npc_director else "Wintervale"
	entry.platform = 1
	entry.stops = false
	var at := WorldClock.time_of_day + 0.3
	entry.arrival = TimetableEntry.format_time(at)
	entry.departure = entry.arrival
	entry.set_meta(&"plough", true)
	_plough_entry = entry
	_plough_day = WorldClock.day
	_plough_added_at = WorldClock.time_of_day
	dispatcher.add_entries([entry])
	_stats["ploughs"] = int(_stats["ploughs"]) + 1
	Events.event_banner_requested.emit("Der Schneeräumzug kommt", "Nach dem Schneetreiben wird die Strecke frei geräumt", "snowflake")
	Events.chronicle_entry.emit("Der Schneeräumzug hat die Strecke frei geräumt.", "snowflake")
	return entry


func get_plough_entry() -> TimetableEntry:
	return _plough_entry


# --- Fundsache: der vergessene Koffer -----------------------------------------------------------

func _watch_departures(now: float) -> void:
	for train in dispatcher.get_trains():
		if train.departed_at < 0.0 or _departures_seen.has(train.train_id):
			continue
		_departures_seen[train.train_id] = true
		if luggage or train.entry.has_meta(&"plough") or train.platform_stop == null:
			continue
		if now < 8.0 or now > 20.0 or _rng.randf() > luggage_chance:
			continue
		leave_luggage(train)


## Nach der Abfahrt von [param train] steht ein Koffer am Bahnsteig.
func leave_luggage(train: Train) -> LostLuggage:
	var stop := train.platform_stop
	luggage = LostLuggage.new()
	luggage.name = "LostLuggage"
	luggage.destination = train.entry.destination
	luggage.created_hours = WorldClock.time_of_day
	luggage.created_day = WorldClock.day
	var look_rng := RandomNumberGenerator.new()
	look_rng.seed = train.train_id * 97 + WorldClock.day
	luggage.owner_look = NpcDirector.random_appearance(look_rng)
	add_child(luggage)
	# Auf dem Bahnsteig, ein Stück von der Kante weg, dort wo der Zug stand
	var side := stop.platform_direction.normalized() if stop.platform_direction.length() > 0.1 else Vector3.RIGHT
	var along := side.cross(Vector3.UP).normalized()
	var p := stop.global_position + side * 2.7 + along * _rng.randf_range(-4.0, 4.0)
	p.y = npc_director.ground_height(p, stop.global_position.y + 0.6) if npc_director else stop.global_position.y + 0.55
	luggage.global_position = p
	luggage.rotation.y = _rng.randf() * TAU
	luggage.picked_up.connect(func(_l: LostLuggage) -> void: _offer_return())
	Events.notification_requested.emit("Am Bahnsteig steht ein vergessener Koffer (Richtung %s)." % luggage.destination)
	return luggage


## Kommt der Besitzer mit einem Zug aus der Richtung zurück, in die er gefahren ist?
func _watch_arrivals() -> void:
	if luggage == null or _owner or npc_director == null:
		return
	for train in dispatcher.get_trains():
		if train.state != Train.State.DWELLING or not train.doors_open() or _arrivals_seen.has(train.train_id):
			continue
		_arrivals_seen[train.train_id] = true
		if train.entry.origin != luggage.destination:
			continue
		# Erst ein späterer Zug (nicht der, mit dem er weggefahren ist)
		if train.arrived_at >= 0.0 and _hours_since(luggage.created_hours) < 0.15:
			continue
		_owner = npc_director.spawn_traveller(_rng)
		_owner_destination = luggage.destination
		_owner.model.appearance = luggage.owner_look
		_owner.model.carry = CharacterModel.Carry.NONE
		_owner.after_alight = _on_owner_arrived
		_owner.alight_from(train, true)
		return


func _on_owner_arrived(owner: Npc) -> void:
	_owner_waiting_since = WorldClock.time_of_day
	owner.trip_destination = ""
	owner.trip_entry_index = -1
	owner.state = Npc.State.AT_STATION
	if luggage and not luggage.carried and is_instance_valid(luggage):
		# Selbst gefunden: hingehen, aufheben, erleichtert winken
		var target := luggage.global_position
		owner.say("Mein Koffer! Wo ist er nur …", 3.0)
		owner.walk_to(target + Vector3(0.4, 0, 0.4), func() -> void:
			if luggage and not luggage.carried:
				luggage.queue_free()
				luggage = null
				owner.model.carry = CharacterModel.Carry.SUITCASE
				owner.say("Da ist er ja! Puh, zum Glück.", 3.5)
				owner.show_icon("heart")
				_stats["luggage_found"] = int(_stats["luggage_found"]) + 1
				_owner_leaves(owner, 4.0))
		return
	owner.say("Hat jemand meinen Koffer gesehen? Ein brauner, mit Riemen …", 5.0)
	owner.show_icon("question", 3.0)
	_offer_return()


## Trägt die Spielfigur den Koffer, kann sie ihn dem Besitzer geben (Taste E).
func _offer_return() -> void:
	if _owner == null or not is_instance_valid(_owner) or luggage == null or not luggage.carried:
		return
	_owner.special_interaction = {"text": "Koffer zurückgeben", "callback": _on_returned}


func _on_returned(owner: Npc, player: Node) -> void:
	var controller := player as PlayerController
	if controller:
		controller.get_model().carry = CharacterModel.Carry.NONE
	if luggage:
		luggage.queue_free()
		luggage = null
	owner.model.carry = CharacterModel.Carry.SUITCASE
	owner.say("Mein Koffer! Sie sind ein Engel – tausend Dank!", 5.0)
	owner.model.play_gesture(CharacterModel.Pose.WAVE, 2.2)
	get_tree().create_timer(3.0, false).timeout.connect(owner.show_icon.bind("heart", 3.0))
	Economy.earn(REWARD, "Finderlohn: Koffer zurückgebracht", "reward")
	_stats["luggage_returned"] = int(_stats["luggage_returned"]) + 1
	Events.event_banner_requested.emit("Danke!", "Der Koffer ist wieder bei seinem Besitzer · Finderlohn %d" % REWARD, "heart")
	Events.chronicle_entry.emit("Jemand aus %s bekam den vergessenen Koffer zurück – dank dir." % _owner_destination, "suitcase")
	_owner_leaves(owner, 6.0)


## Der Besitzer fährt mit dem nächsten Zug wieder zurück.
func _owner_leaves(owner: Npc, after: float) -> void:
	# Gebundene Methode + WeakRef statt Lambda mit erfasstem Npc: Wird die Welt vorher
	# entladen, trennt Godot die Verbindung, und ein verschwundener Besitzer wird übersprungen.
	get_tree().create_timer(after, false).timeout.connect(_on_owner_leaves.bind(weakref(owner), _owner_destination))


func _on_owner_leaves(owner_ref: WeakRef, destination: String) -> void:
	var owner := owner_ref.get_ref() as Npc
	if owner == null:
		return
	owner.special_interaction = {}
	owner.trip_destination = destination if destination != "" else owner.trip_destination
	if owner.trip_destination == "":
		owner.leave_to_village()
	if owner == _owner:
		_owner = null


func _update_owner(now: float) -> void:
	if _owner == null or not is_instance_valid(_owner):
		_owner = null
		return
	if _owner_waiting_since < 0.0 or _owner.model.carry == CharacterModel.Carry.SUITCASE:
		return
	if _owner.special_interaction.is_empty() and luggage and not luggage.carried:
		return
	# Suchend auf dem Bahnsteig: ab und zu ein Fragezeichen
	_hint_timer -= 0.5
	if _hint_timer <= 0.0 and not _owner.is_talking():
		_hint_timer = 9.0
		_owner.show_icon("question", 2.5)
	_offer_return()
	# Nach zwei Stunden gibt er auf und fährt zurück (der Koffer kommt ins Fundbüro)
	if luggage and _hours_since(_owner_waiting_since) > 2.0:
		_owner.special_interaction = {}
		_owner.trip_destination = luggage.destination
		_owner = null


func _update_luggage_timeout(_now: float) -> void:
	if luggage == null or not is_instance_valid(luggage):
		luggage = null
		return
	var age := _hours_since(luggage.created_hours) + (WorldClock.day - luggage.created_day) * 24.0
	if age < 6.0 or _owner:
		return
	if luggage.carried:
		var player := get_tree().get_first_node_in_group(&"player") as PlayerController
		if player:
			player.get_model().carry = CharacterModel.Carry.NONE
	Events.notification_requested.emit("Der vergessene Koffer kommt ins Fundbüro.")
	luggage.queue_free()
	luggage = null


func get_owner_npc() -> Npc:
	return _owner


func _hours_since(hours: float) -> float:
	return fposmod(WorldClock.time_of_day - hours, 24.0)


# --- Speichern ----------------------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"stats": _stats, "plough_day": _plough_day}


func load_state(data: Dictionary) -> void:
	var stats: Dictionary = data.get("stats", {})
	for key: String in _stats:
		_stats[key] = int(stats.get(key, _stats[key]))
	_plough_day = int(data.get("plough_day", -1))
	if luggage:
		luggage.queue_free()
		luggage = null
	_owner = null
