## Automatischer Test für Etappe 10: Feste, Zug-Ereignisse und Gespräche.
##
## Prüft Festkalender, Aufbau (nie in Häusern, auf Wegen oder Gleisen), Öffnungszeiten,
## Sonderzüge, Besucher und Einkäufe, das Lichterfest, das Herbstfest mit Reigen
## und Laternenumzug, Gespräche mit der Taste E, Verspätungen, den
## Schneeräumzug, den vergessenen Koffer samt Finderlohn, Festklänge,
## die Notizbuch-Seite und Speichern/Laden.
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/festival_test.tscn
extends Node

var failures := 0
var main: Node3D
var festivals: FestivalDirector
var events: TrainEvents
var village: VillageManager
var director: NpcDirector
var dispatcher: TrainDispatcher
var player: PlayerController


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Spielzeit laufen lassen, bis [param hours] erreicht ist (mit Zeitraffer).
func run_until(hours: float, scale := 10.0, limit := 30000) -> void:
	WorldClock.paused = false
	WorldClock.time_scale = scale
	var steps := 0
	while WorldClock.time_of_day < hours and steps < limit:
		await get_tree().physics_frame
		steps += 1
	WorldClock.time_scale = 1.0


func _ready() -> void:
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	WorldClock.set_time(12.0)
	WorldClock.paused = true
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	festivals = main.get_node("Festivals")
	events = main.get_node("TrainEvents")
	village = main.get_node("World/Village")
	director = main.get_node("NpcDirector")
	dispatcher = main.get_node("World/Railway/TrainDispatcher")
	player = main.get_node("Player")
	(main.get_node("Weather") as WeatherSystem).enabled = false
	dispatcher.enabled = false
	events.enabled = false
	await frames(10)
	festivals.tick()

	_test_calendar()
	_test_site()
	await _test_opening()
	await _test_visitors()
	await _test_lichterfest()
	await _test_harvest()
	await _test_conversation()
	await _test_delay_and_plough()
	await _test_lost_luggage()
	_test_sounds()
	await _test_notebook_and_save()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Kalender und Aufbau ----------------------------------------------------------------

func _test_calendar() -> void:
	print("--- Calendar")
	check(festivals.get_active_id() == FestivalDirector.CHRISTMAS, "mid-winter: the Christmas market is on")
	var calendar := festivals.get_calendar()
	check(calendar.size() == 2 and bool(calendar[0]["running"]), "calendar lists both festivals, the running one first")
	Seasons.set_season(Seasons.Season.SUMMER, 0.5)
	festivals.tick()
	check(festivals.get_active_id() == "" and festivals.get_stalls().is_empty(), "summer: no festival, site removed")
	Seasons.set_season(Seasons.Season.AUTUMN, 0.5)
	festivals.tick()
	check(festivals.get_active_id() == FestivalDirector.HARVEST, "mid-autumn: harvest festival")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	festivals.tick()
	check(festivals.get_active_id() == FestivalDirector.CHRISTMAS, "back in winter: market rebuilt")


func _test_site() -> void:
	print("--- Site")
	var stalls := festivals.get_stalls()
	check(stalls.size() == 5, "five market stalls (%d)" % stalls.size())
	check(festivals.get_tree_feature() != null, "big Christmas tree")
	check(festivals.get_carousel() != null, "children's carousel")
	check(festivals.get_fires().size() == 1, "fire basket on the plaza")
	check(festivals.get_spot_count("chat") >= 8 and festivals.get_spot_count("watch") >= 6, "standing tables and viewing spots")
	var overlaps := 0
	var on_paths := 0
	var network: RailNetwork = main.get_node("World/Railway/RailNetwork")
	var features: Array[Vector3] = []
	for stall in stalls:
		features.append(stall.global_position)
	features.append(festivals.get_tree_feature().global_position)
	features.append(festivals.get_carousel().global_position)
	for p in features:
		for obj in village.get_objects():
			if obj is VillageHouse and VillageFootprint.contains(obj.get_footprint(), Vector2(p.x, p.z), 1.0):
				overlaps += 1
			if obj is VillagePath and (obj as VillagePath).distance_to(p) < (obj as VillagePath).get_width() * 0.5 + 0.8:
				on_paths += 1
		if network.find_segment_near(p, 3.0):
			overlaps += 1
	check(overlaps == 0, "nothing stands in houses or on tracks (%d)" % overlaps)
	check(on_paths == 0, "nothing blocks a path (%d)" % on_paths)
	# Wilde Bäume in der Budengasse werden gerodet
	var center := festivals.get_center()
	check(festivals.clears(center.x, center.z - 9.0), "wild trees are cleared in the stall lane")


func _test_opening() -> void:
	print("--- Opening hours")
	WorldClock.set_time(12.0)
	festivals.tick()
	check(not festivals.is_open() and not festivals.get_stalls()[0].is_open(), "12:00: stalls closed")
	WorldClock.set_time(15.2)
	festivals.tick()
	await frames(10)
	check(festivals.is_open() and festivals.get_stalls()[0].is_open(), "15:12: market open, shutters up")
	check(festivals.get_carousel().is_running(), "carousel turns while open")
	check(festivals.get_fires()[0].is_burning(), "fire basket burns")
	var entries := festivals.get_special_entries()
	check(entries.size() == 2 and dispatcher.timetable.entries.has(entries[0]), "special trains are in the timetable")
	check(festivals.get_return_trip().has("entry"), "visitors know their train home")


func _test_visitors() -> void:
	print("--- Visitors")
	WorldClock.set_time(15.3)
	await run_until(16.1)
	var visitors := festivals.get_visitors_now()
	check(visitors >= 5, "the market fills up (%d visitors)" % visitors)
	var buying := false
	var mugs := 0
	for step in 900:
		await get_tree().physics_frame
		for npc in director.get_npcs() + director.get_travellers():
			if not is_instance_valid(npc):
				continue
			if npc.get_festival_behaviour() == "buy":
				buying = true
			if npc.model.carry == CharacterModel.Carry.MUG:
				mugs = maxi(mugs, 1)
		if buying and mugs > 0 and int(festivals.get_stats()["sold"]) > 0:
			break
	check(buying, "visitors queue at the stalls")
	check(int(festivals.get_stats()["sold"]) > 0, "stalls sell goods (%d)" % int(festivals.get_stats()["sold"]))
	check(mugs > 0, "someone holds a steaming mug")


func _test_lichterfest() -> void:
	print("--- Lichterfest")
	await run_until(16.7)
	check(festivals.get_highlight_phase() == "gathering", "16:42: everyone gathers at the tree")
	check(not festivals.get_tree_feature().is_lit(), "the tree is still dark")
	await run_until(17.0)
	var waited := 0
	while festivals.get_highlight_phase() != "done" and waited < 2400:
		await get_tree().physics_frame
		waited += 1
	await frames(330)
	check(festivals.get_highlight_phase() == "done", "the ceremony ran through")
	check(festivals.get_tree_feature().is_lit() and festivals.get_tree_feature().get_reveal_height() > 7.0,
		"the lights ran up the whole tree")
	check(int(festivals.get_stats()["lights"]) == 1, "counted one Lichterfest")
	check(not festivals.chronicle.is_empty() and String(festivals.chronicle[0]["text"]).contains("Lichterfest"),
		"the village chronicle remembers it")


func _test_harvest() -> void:
	print("--- Harvest festival")
	festivals.forced_festival = FestivalDirector.HARVEST
	Seasons.set_season(Seasons.Season.AUTUMN, 0.5)
	WorldClock.set_time(15.0)
	festivals.tick()
	check(festivals.get_active_id() == FestivalDirector.HARVEST and festivals.get_stalls().size() == 4, "harvest: four stalls")
	check(festivals.get_fires().size() == 1 and festivals.get_tree_feature() == null, "bonfire instead of a tree")
	check(festivals.get_spot_count("sit") >= 6, "hay bales and log benches to sit on")
	await run_until(15.8)
	var behaviours := []
	for npc in director.get_npcs() + director.get_travellers():
		if is_instance_valid(npc) and npc.state == Npc.State.FESTIVAL:
			behaviours.append(npc.get_festival_behaviour())
	print("      at the festival: ", behaviours, " guests=", director.get_travellers().size())
	festivals.start_dance()
	var dancers := festivals.get_dancers()
	check(dancers.size() >= 3, "a round dance starts (%d dancers)" % dancers.size())
	var moved := false
	var start_positions := {}
	for step in 1500:
		await get_tree().physics_frame
		for npc in dancers:
			if not is_instance_valid(npc) or not npc.is_dancing():
				continue
			if not start_positions.has(npc):
				start_positions[npc] = npc.global_position
			elif npc.global_position.distance_to(start_positions[npc]) > 1.5:
				moved = true
		if moved:
			break
	var states := []
	for npc in dancers:
		if is_instance_valid(npc):
			states.append("%s/%s/%s" % [npc.get_festival_behaviour(), npc.is_dancing(), npc.is_moving()])
	print("      dancers: ", states)
	check(moved, "dancers circle around the fountain")
	festivals.stop_dance()
	var route := festivals.procession_route()
	var length := 0.0
	for i in route.size() - 1:
		length += route[i].distance_to(route[i + 1])
	check(length > 25.0, "lantern route leads along the village street (%.0f m)" % length)
	await run_until(18.52)
	var lanterns := 0
	for step in 600:
		await get_tree().physics_frame
		lanterns = 0
		for npc in director.get_npcs() + director.get_travellers():
			if is_instance_valid(npc) and npc.model.carry == CharacterModel.Carry.LANTERN:
				lanterns += 1
		if lanterns >= 3:
			break
	check(lanterns >= 3, "lantern procession (%d lanterns)" % lanterns)
	festivals.forced_festival = ""
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	WorldClock.set_time(12.0)
	festivals.tick()


# --- Gespräche ----------------------------------------------------------------------

func _test_conversation() -> void:
	print("--- Conversations")
	var npc: Npc = null
	for candidate in director.get_npcs():
		if candidate.profile and not NpcDialogue.is_child(candidate):
			npc = candidate
			break
	if npc == null:
		check(false, "a resident to talk to")
		return
	npc.visit_festival(festivals, 23.0)
	await frames(5)
	player.global_position = npc.global_position + Vector3(0, 0, 1.4)
	var interaction: PlayerInteraction = player.get_node("Interaction")
	# Spielfigur schaut zum Bewohner
	player.get_model().rotation.y = atan2(-(npc.global_position.x - player.global_position.x), -(npc.global_position.z - player.global_position.z))
	await frames(3)
	var target := interaction.find_target()
	check(target == npc, "E targets the resident in front of the player")
	check(String(npc.get_interaction_text(player)).begins_with("Mit "), "prompt: '%s'" % npc.get_interaction_text(player))
	npc.interact(player)
	await frames(2)
	check(npc.is_talking() and npc.get_bubble().get_text().contains(NpcDialogue.first_name(npc)),
		"first line introduces the resident ('%s')" % npc.get_bubble().get_text())
	var lines := NpcDialogue.conversation(npc, true)
	check(lines.size() >= 3, "a conversation has greeting, topics and farewell (%d lines)" % lines.size())
	var festive := false
	for line in lines:
		if line.contains("Markt") or line.contains("Baum") or line.contains("Glühwein") or line.contains("Lichter"):
			festive = true
	check(festive, "residents talk about the market")
	npc.interact(player)
	check(npc.get_bubble().get_text() != "" and npc.is_talking(), "E again: next line")
	check(director.small_talk_icon(RandomNumberGenerator.new()) != "", "small talk icons for chatting residents")


# --- Zug-Ereignisse -----------------------------------------------------------------------

func _test_delay_and_plough() -> void:
	print("--- Delays and snowplough")
	WorldClock.set_time(14.2)
	var entry := events._next_passenger_entry(WorldClock.time_of_day, 0.2, 2.0)
	check(entry != null, "found the next passenger train (%s)" % (entry.train_number if entry else "-"))
	if entry:
		events.delay_train(entry, 12)
		check(is_equal_approx(dispatcher.get_delay(entry), 0.2), "delay of 12 minutes stored")
		var shown := false
		for row in dispatcher.get_departure_rows("Wintervale", 6):
			if row["number"] == entry.train_number and int(row["delay"]) >= 12:
				shown = true
		check(shown, "departure board shows the delay")
	var plough := events.send_plough()
	var index := dispatcher.timetable.entries.find(plough)
	check(index >= 0 and not plough.stops, "snowplough runs through without stopping")
	var train := dispatcher.spawn_train(index)
	check(train != null and train.cars[0].kind == "loco_plough", "snowplough loco with its big plough")
	if train:
		check(train.cars[0].find_children("*", "OmniLight3D", true, false).size() >= 2, "orange beacons on the cab")
		dispatcher.retire(train, "")
	dispatcher.remove_entries([plough])
	check(not dispatcher.timetable.entries.has(plough), "snowplough leaves the timetable again")


func _test_lost_luggage() -> void:
	print("--- Lost luggage")
	WorldClock.set_time(10.0)
	var index := -1
	for i in dispatcher.timetable.entries.size():
		var e := dispatcher.timetable.entries[i]
		if e.stops and e.train_type and e.train_type.category == TrainType.Category.PASSENGER and not e.has_meta(&"festival"):
			index = i
			break
	var train := dispatcher.spawn_train(index)
	check(train != null, "a passenger train for the lost luggage")
	if train == null:
		return
	train.platform_stop = dispatcher.get_platform_stop("Wintervale", train.entry.platform)
	var luggage := events.leave_luggage(train)
	await frames(3)
	check(luggage != null and luggage.visible, "a suitcase waits on the platform")
	player.global_position = luggage.global_position + Vector3(0, 0, 0.8)
	check(luggage.get_interaction_text(player) == "Koffer aufheben", "prompt: pick up the suitcase")
	luggage.interact(player)
	check(player.get_model().carry == CharacterModel.Carry.SUITCASE and luggage.carried, "the player carries it")
	var owner := director.spawn_traveller(RandomNumberGenerator.new())
	owner.appear_at(luggage.global_position + Vector3(1.5, 0, 0))
	events._owner = owner
	events._owner_destination = luggage.destination
	events._on_owner_arrived(owner)
	check(String(owner.special_interaction.get("text", "")) == "Koffer zurückgeben", "the owner asks for it")
	var money := Economy.money
	owner.interact(player)
	check(player.get_model().carry == CharacterModel.Carry.NONE and owner.model.carry == CharacterModel.Carry.SUITCASE,
		"handed over to the owner")
	check(Economy.money == money + TrainEvents.REWARD, "finder's reward paid")
	check(int(events.get_stats()["luggage_returned"]) == 1, "counted as returned")
	dispatcher.retire(train, "")


func _test_sounds() -> void:
	print("--- Festival sounds")
	for sound_name in FestivalSounds.NAMES:
		var stream := FestivalSounds.get_sound(sound_name)
		var peak := SoundLibrary.peak(stream) if stream else 0.0
		check(stream != null and peak > 0.2 and peak < 0.75, "%s generated, gentle level (%.2f)" % [sound_name, peak])
	for loop_name in ["carol", "polka", "laterne"]:
		check(FestivalSounds.get_sound(loop_name).loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % loop_name)
	check(FestivalSounds.get_sound("carol").get_length() > 20.0, "the market waltz is a real tune (%.0f s)" %
		FestivalSounds.get_sound("carol").get_length())


func _test_notebook_and_save() -> void:
	print("--- Notebook and save")
	var notebook: Notebook = main.get_node("Notebook")
	notebook.open("festivals")
	await frames(3)
	check(notebook.is_open, "notebook opens on the festival page")
	notebook.close()
	var data := festivals.save_state()
	var count := festivals.chronicle.size()
	festivals.chronicle.clear()
	festivals.load_state(JSON.parse_string(JSON.stringify(data)))
	check(festivals.chronicle.size() == count and count > 0, "chronicle survives save/load (%d entries)" % count)
	var event_data := events.save_state()
	events.load_state(JSON.parse_string(JSON.stringify(event_data)))
	check(int(events.get_stats()["luggage_returned"]) == 1, "train event statistics survive save/load")
