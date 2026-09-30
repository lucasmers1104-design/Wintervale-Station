## Automatischer Test für Etappe 8: Güterbahnhof, Materialsystem, Güterzüge,
## Dorf-Wirtschaft, Bauprojekte, Bewohner und Notizbuch.
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/economy_test.tscn
extends Node

var failures := 0
var main: Node3D
var village: VillageManager
var director: NpcDirector
var dispatcher: TrainDispatcher
var yard: FreightYard
var notebook: Notebook
var build: BuildMode


func check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	WorldClock.set_time(12.0)
	WorldClock.paused = true
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	village = main.get_node("World/Village")
	director = main.get_node("NpcDirector")
	dispatcher = main.get_node("World/Railway/TrainDispatcher")
	yard = main.get_node("World/FreightYard")
	notebook = main.get_node("Notebook")
	build = main.get_node("BuildMode")
	dispatcher.enabled = false
	await frames(10)
	dispatcher.clear_trains()

	_test_materials()
	_test_economy_rules()
	_test_yard()
	_test_trains()
	await _test_unloading()
	await _test_construction()
	await _test_arrival_by_train()
	await _test_stroll()
	await _test_income()
	await _test_notebook()
	await _test_save_load()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Materialsystem ------------------------------------------------------------------

func _test_materials() -> void:
	print("--- Materials")
	var goods := Economy.get_goods()
	var ids := goods.map(func(g: GoodsType) -> String: return g.id)
	check(ids == ["wood", "brick", "glass", "steel", "stone"], "five materials in order (%s)" % [ids])
	for g in goods:
		check(g.display_name != "" and g.origin != "" and g.max_stock > 0 and g.start_stock <= g.max_stock,
			"%s: name, origin, stock limits" % g.display_name)
		check(g.icon != null and g.icon.get_width() >= 32, "%s has its own icon" % g.display_name)
		check(Economy.get_stock(g.id) == g.start_stock, "%s starts with %d" % [g.display_name, g.start_stock])
	check(Economy.money == Economy.START_MONEY, "start money %d Taler" % Economy.START_MONEY)


func _test_economy_rules() -> void:
	print("--- Economy rules")
	var wood := Economy.get_stock("wood")
	var space := Economy.get_space("wood")
	check(Economy.add_stock("wood", space + 50) == space and Economy.get_stock("wood") == Economy.get_max("wood"),
		"storage never exceeds its maximum")
	Economy.remove_stock("wood", Economy.get_stock("wood") - wood)
	var money := Economy.money
	var cost := {"money": 100, "wood": 20, "glass": 4}
	check(Economy.charge_build("test:1", cost, "Test"), "charge a construction project")
	check(Economy.money == money - 100 and Economy.get_reserved("wood") == 20 and Economy.get_available("wood") == wood - 20,
		"money paid, material reserved (still in stock)")
	check(Economy.consume("test:1", "wood", 12) == 12 and Economy.get_stock("wood") == wood - 12, "reserved wood used on site")
	Economy.refund_build("test:1", cost, "Test")
	check(Economy.money == money and Economy.get_stock("wood") == wood and Economy.get_reserved("wood") == 0,
		"demolition refunds money and material exactly")
	var too_much := {"money": Economy.money + 1, "steel": 999}
	check(not Economy.can_afford(too_much) and Economy.describe_missing(too_much).contains("Stahl"),
		"missing material is named (%s)" % Economy.describe_missing(too_much))
	check(Economy.format_money(12345) == "12.345 Taler", "money formatting")
	check(VillageCatalog.get_cost("house_cottage") == {"money": 350, "wood": 30, "brick": 12, "glass": 8},
		"small house: 30 wood, 12 bricks, 8 glass (+350 Taler)")
	check(VillageCatalog.get_cost("lantern").get("steel", 0) == 2, "lantern needs 2 steel")
	check(VillageCatalog.get_cost("path_stone", 10.0).get("stone", 0) == 10, "paths cost stone per metre")


# --- Güterbahnhof ------------------------------------------------------------------

func _test_yard() -> void:
	print("--- Freight yard")
	check(yard.is_ready(), "freight yard built")
	for node_name in ["GoodsShed", "Warehouse", "Crane", "Forklift"]:
		check(yard.get_node_or_null(node_name) != null, "%s exists" % node_name)
	check(yard.get_light_count() >= 14, "warm yard lighting (%d lights)" % yard.get_light_count())
	for g in Economy.get_goods():
		if g.id == "stone":
			check(yard.get_visible_pieces("stone") >= 1, "stone heaps in the bays")
			continue
		var unit := int(yard._storage[g.id]["unit"])
		var expected := mini(ceili(float(Economy.get_stock(g.id)) / unit), yard.get_storage_capacity(g.id))
		check(yard.get_visible_pieces(g.id) == expected, "%s stock is visible as %d pieces" % [g.display_name, expected])
	var shed_smoke := yard.get_node("GoodsShed").find_children("*", "GPUParticles3D", true, false)
	check(not shed_smoke.is_empty(), "smoke rises from the goods shed")
	check(village.check_placement("house_cottage", Vector3(18.0, 0.0, -30.0), 0.0) != ""
		and village.check_placement("tree_birch", Vector3(30.0, 0.0, -24.0), 0.0) != "", "nothing of the village is built on the freight yard")
	var flags := yard.find_children("Flag*", "MeshInstance3D", false, false)
	check(flags.size() == 3 and (flags[0] as MeshInstance3D).material_override is ShaderMaterial, "three waving flags")


func _test_trains() -> void:
	print("--- Freight trains")
	var lengths := {}
	var kinds := {}
	for entry in dispatcher.timetable.entries:
		if entry.station != "Güterbahnhof":
			continue
		check(entry.stops and entry.platform == 3, "%s stops at the freight yard" % entry.train_number)
		lengths[entry.train_type.consist.size()] = true
		for kind in entry.train_type.consist:
			kinds[kind] = true
	check(lengths.size() >= 2, "different train lengths (%s)" % [lengths.keys()])
	for kind in ["wagon_timber", "wagon_container", "wagon_flat", "wagon_stake", "wagon_hopper"]:
		check(kinds.has(kind), "wagon type %s in service" % kind)
	var livery := (load("res://assets/trains/freight.tres") as TrainType).get_livery()
	for kind: String in TrainMeshes.CARGO:
		var parts := TrainMeshes.build_car(kind, livery)
		check(parts["paint"] != null, "%s builds without its cargo" % kind)
		var piece := TrainMeshes.create_cargo(TrainMeshes.CARGO[kind]["piece"])
		check(piece.get_aabb().size.length() > 1.0, "%s cargo is a separate piece" % kind)


## GZ 802: Ziegel, Stahl (nicht bestellt!) und Stein – mit Leergut zurück.
func _test_unloading() -> void:
	print("--- Unloading GZ 802")
	Economy.set_ordered("steel", false)
	yard._empty_pallet_stacks = 2
	yard._refresh_empties(false)
	var brick := Economy.get_stock("brick")
	var stone := Economy.get_stock("stone")
	var steel := Economy.get_stock("steel")
	var money := Economy.money
	var index := _entry_index("GZ 802")
	WorldClock.set_time(dispatcher.get_spawn_hours(index) + 0.02)
	WorldClock.paused = false
	var train := dispatcher.spawn_train(index)
	check(train != null and train.cars.size() == 4, "GZ 802 spawned with 3 wagons")
	var hopper: TrainCar = null
	var flat: TrainCar = null
	for car in train.cars:
		if car.kind == "wagon_hopper":
			hopper = car
		if car.kind == "wagon_flat":
			flat = car
	check(hopper.count_full("stone") == 1 and flat.count_full("brick") == 6, "wagons arrive fully loaded (visible cargo)")
	var exhaust := train.cars[0].find_children("Exhaust", "GPUParticles3D", true, false)
	check(not exhaust.is_empty(), "the freight loco puffs little clouds")
	dispatcher.enabled = true
	WorldClock.time_scale = 10.0
	var held_seen := false
	var birds_seen := false
	var serviced: Array = []
	var stored: Array = []
	yard.train_serviced.connect(func(number: String, goods: Dictionary) -> void: serviced.append([number, goods]))
	yard.piece_stored.connect(func(goods: String, amount: int) -> void: stored.append([goods, amount]))
	var frames_run := 0
	while is_instance_valid(train) and train.state != Train.State.DONE and frames_run < 40000:
		await get_tree().physics_frame
		frames_run += 1
		if is_instance_valid(train) and train.state == Train.State.DWELLING:
			held_seen = held_seen or train.is_departure_held()
			birds_seen = birds_seen or yard._birds.any(func(b: Dictionary) -> bool: return b["car"] != null)
	WorldClock.time_scale = 1.0
	WorldClock.paused = true
	dispatcher.enabled = false
	check(held_seen, "the train waits while the crane works")
	check(birds_seen, "birds sit on the freight wagons")
	check(stored.size() == 9, "crane moved 9 pieces into storage (%d)" % stored.size())
	check(Economy.get_stock("brick") == mini(brick + 36, Economy.get_max("brick")), "36 bricks unloaded")
	check(Economy.get_stock("stone") == mini(stone + 24, Economy.get_max("stone")), "3 grab loads of stone unloaded")
	check(Economy.get_stock("steel") == steel, "steel was not ordered – it stayed on the train")
	check(Economy.money < money, "purchase was paid (%d → %d)" % [money, Economy.money])
	check(not serviced.is_empty() and serviced[0][0] == "GZ 802", "service finished before departure")
	check(yard.get_empties()["pallet_stack"] == 0, "empty pallets were loaded back onto the train")
	check(not is_instance_valid(train) or train.state == Train.State.DONE, "train left afterwards")
	Economy.set_ordered("steel", true)
	check(yard.get_deliveries().size() >= 1, "delivery recorded for the notebook")


# --- Bauprojekte -------------------------------------------------------------------

func _test_construction() -> void:
	print("--- Construction")
	for g in Economy.get_goods():
		Economy.add_stock(g.id, g.max_stock)
	build.set_active(true)
	build.select_tool(&"village_houses")
	var tool := build.get_current_tool() as VillagePlaceTool
	tool.select_item("house_cottage")
	var spot := Vector3(-61.0, 0.0, 21.0)
	var saved := Economy.get_stock("glass")
	Economy.remove_stock("glass", saved - 2)
	tool.preview_at(spot)
	check(not tool.is_valid() and tool.get_status().contains("Glas"), "not enough glass: cannot build (%s)" % tool.get_status())
	Economy.add_stock("glass", saved)
	tool.preview_at(spot + Vector3(0.01, 0, 0))
	check(tool.is_valid(), "with enough material the spot is valid")
	var wood := Economy.get_stock("wood")
	check(tool.click_at(spot), "house placed")
	build.set_active(false)
	var house: VillageHouse = village.get_houses()[-1]
	check(house.get_site() != null and not house.is_finished(), "construction site with fence, scaffold, crane")
	var site := house.get_site()
	check(site.find_children("*", "CharacterModel", true, false).size() == 2, "two builders on site")
	check(village.get_projects().has(house), "listed as a construction project")
	# Nachts ruht die Baustelle
	WorldClock.set_time(22.0)
	WorldClock.paused = false
	WorldClock.time_scale = 60.0
	var start := house.build_progress
	await frames(120)
	check(is_equal_approx(house.build_progress, start), "no work at night")
	WorldClock.set_time(8.0)
	await frames(2)
	var stages := {}
	var t := 0
	while not house.is_finished() and t < 20000:
		await get_tree().process_frame
		stages[house.get_stage_text()] = true
		t += 1
	WorldClock.time_scale = 1.0
	WorldClock.paused = true
	check(house.is_finished(), "the house was finished during the day")
	check(stages.size() >= 4, "construction went through stages (%s)" % [stages.keys()])
	check(Economy.get_stock("wood") == wood - 30, "exactly 30 wood used")
	check(not Economy.has_reservation(VillageManager.cost_key(house.object_id)), "reservation closed")
	check(village.get_finished_log().size() >= 1, "finished project logged")


## Die neue Familie kommt mit dem nächsten Zug aus ihrer alten Heimat.
func _test_arrival_by_train() -> void:
	print("--- Arrival by train")
	var house: VillageHouse = village.get_houses()[-1]
	var residents := village.get_residents(house)
	check(not residents.is_empty(), "a family moves into the finished house (%d)" % residents.size())
	var household := village.get_household(house)
	check(household.size() >= residents.size() and household.size() <= 4, "household of %d" % household.size())
	var npcs: Array[Npc] = []
	for profile: NpcProfile in residents:
		npcs.append(director.get_npc(profile.display_name))
		check(profile.came_from in ["Nordtal", "Südtal"] and profile.favourite_way != "" and profile.rhythm != "",
			"%s: origin, favourite way, daily rhythm" % profile.display_name)
	check(npcs.all(func(n: Npc) -> bool: return n.is_moving_in() and n.state == Npc.State.AWAY),
		"they are still on the train (no random spawn)")
	WorldClock.paused = false
	dispatcher.enabled = true
	WorldClock.time_scale = 10.0
	var alighted: Array = []
	director.passenger_alighted.connect(func(npc: Npc, _train: Train) -> void: alighted.append(npc))
	var n := 0
	# Wer zuerst ankommt, lebt danach normal weiter (z.B. Abendspaziergang) –
	# deshalb pro Person merken, ob sie ihr neues Zuhause erreicht hat.
	var reached_home := {}
	while npcs.any(func(npc: Npc) -> bool: return npc.is_moving_in()) and n < 30000:
		await get_tree().physics_frame
		n += 1
		for npc in npcs:
			if npc.state == Npc.State.AT_HOME and not npc.is_moving_in():
				reached_home[npc] = true
	for npc in npcs:
		if npc.state == Npc.State.AT_HOME and not npc.is_moving_in():
			reached_home[npc] = true
	WorldClock.time_scale = 1.0
	WorldClock.paused = true
	dispatcher.enabled = false
	dispatcher.clear_trains()
	check(npcs.all(func(npc: Npc) -> bool: return alighted.has(npc)), "the family got off a train at Wintervale")
	for npc in npcs:
		if not reached_home.has(npc):
			print("      %s: state %d, moving %s, busy %s, at %s, frames %d, time %.2f" % [npc.display_name, npc.state, npc.is_moving(),
				npc.is_busy(), npc.global_position, n, WorldClock.time_of_day])
	check(npcs.all(func(npc: Npc) -> bool: return reached_home.has(npc)),
		"and walked home with their suitcases")


func _test_stroll() -> void:
	print("--- Daily rhythm: stroll")
	# Ein Spaziergang, der nicht von einem anderen Termin überdeckt wird (z.B. einer
	# Rückfahrt, die noch läuft) – die Familien sind in jedem Lauf andere
	var stroller: Npc = null
	var routine: NpcRoutine = null
	for npc in director.get_npcs():
		if npc.profile == null:
			continue
		for r in npc.profile.routines:
			if r.activity == NpcRoutine.Activity.STROLL and npc.profile.get_routine_at(r.get_start_hours() + 0.01) == r:
				stroller = npc
				routine = r
	if stroller == null:
		# Kein freier Spaziergänger: einem Bewohner einen Spaziergang in eine freie Stunde legen
		for npc in director.get_npcs():
			if stroller == null and npc.profile and npc.profile.get_routine_at(13.0) == null \
					and npc.profile.get_routine_at(14.2) == null:
				stroller = npc
		routine = VillageResidents._stroll(13.0, 1.0)
		stroller.profile.routines.append(routine)
	WorldClock.set_time(routine.get_start_hours() - 0.05)
	director.resume_all()
	WorldClock.paused = false
	WorldClock.time_scale = 3.0
	var strolled := false
	var n := 0
	while WorldClock.time_of_day < routine.get_until_hours() and n < 40000:
		await get_tree().physics_frame
		n += 1
		strolled = strolled or stroller.state == Npc.State.STROLLING
	var home_again := false
	n = 0
	while not home_again and n < 30000:
		await get_tree().physics_frame
		n += 1
		home_again = stroller.state == Npc.State.AT_HOME
	WorldClock.time_scale = 1.0
	WorldClock.paused = true
	check(strolled, "%s goes for a walk in the village" % stroller.display_name)
	check(home_again, "and comes home afterwards")


func _test_income() -> void:
	print("--- Income")
	var money := Economy.money
	var residents := director.get_npcs().size()
	WorldClock.set_time(17.98)
	WorldClock.paused = false
	await get_tree().create_timer(0.3).timeout
	WorldClock.advance(0.05)
	WorldClock.paused = true
	check(Economy.money == money + residents * 14, "evening taxes: %d residents × 14 Taler" % residents)
	var before := Economy.money
	director.passenger_boarded.emit(director.get_npcs()[0], null)
	check(Economy.money == before + 4, "a ticket brings 4 Taler")
	var summary := Economy.get_day_summary(WorldClock.day)
	check(int(summary["income"]) > 0 and (summary["kinds"] as Dictionary).has("taxes"), "day summary for the notebook")


func _test_notebook() -> void:
	print("--- Notebook")
	var hud: GameHUD = main.get_node("HUD")
	check(hud.get_money_text() != "", "money shown next to the clock (%s)" % hud.get_money_text())
	var key := InputEventKey.new()
	key.physical_keycode = KEY_N
	key.keycode = KEY_N
	key.pressed = true
	Input.parse_input_event(key)
	await frames(3)
	check(notebook.is_open, "N opens the notebook")
	for page: Dictionary in Notebook.PAGES:
		notebook.show_page(page["id"])
		await get_tree().create_timer(0.4).timeout
		var labels := notebook.find_children("*", "Label", true, false).size()
		check(notebook.get_page() == page["id"] and labels > 5, "page %s has content (%d labels)" % [page["label"], labels])
	notebook.show_page("storage")
	await get_tree().create_timer(0.4).timeout
	var checks := notebook.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b is Notebook.InkCheck)
	check(checks.size() == 5, "a standing-order tick for every material")
	(checks[0] as Button).button_pressed = false
	check(not Economy.is_ordered("wood"), "unticking stops wood orders")
	(checks[0] as Button).button_pressed = true
	notebook.close()
	await frames(10)
	check(not notebook.is_open, "notebook closes")


func _test_save_load() -> void:
	print("--- Save & load")
	# Eine halbfertige Baustelle
	var data := village.prepare("house_aframe", Vector3(-50.0, 0.0, 31.0), 0.0)
	data["paid"] = true
	data["build"] = 0.0
	var house: VillageHouse = village.build(data)
	check(house != null, "second construction site")
	village.advance_project(house, 0.5)
	var money := Economy.money
	var wood := Economy.get_stock("wood")
	var reserved := Economy.get_reserved("wood")
	var empties := yard.get_empties()
	SaveManager.delete_save("economytest")
	check(SaveManager.save_game("economytest"), "save")
	Economy.reset()
	village.clear_all()
	check(SaveManager.load_game("economytest"), "load")
	await frames(5)
	check(Economy.money == money and Economy.get_stock("wood") == wood and Economy.get_reserved("wood") == reserved,
		"money, stock and reservations restored")
	var restored: VillageHouse = null
	for h in village.get_houses():
		if h.item_id == "house_aframe":
			restored = h
	check(restored != null and absf(restored.build_progress - 0.5) < 0.01 and restored.get_site() != null,
		"construction site restored at 50 %")
	check(yard.get_empties() == empties, "yard empties restored")
	SaveManager.delete_save("economytest")


func _entry_index(number: String) -> int:
	for i in dispatcher.timetable.entries.size():
		if dispatcher.timetable.entries[i].train_number == number:
			return i
	return -1
