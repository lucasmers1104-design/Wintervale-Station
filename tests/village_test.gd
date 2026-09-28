## Automatischer Test für Etappe 6: Dorf und Bausystem.
##
## Prüft Katalog und Modelle, das Startdorf, Bauen/Entfernen mit Undo/Redo,
## Platzierungsregeln, Wege (Einrasten, Netz, Vorliebe der Bewohner),
## Geländeanpassung, Bewohner neuer Häuser inkl. Tagesablauf mit Zugfahrt,
## Licht bei Nacht und Speichern/Laden.
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/village_test.tscn
extends Node

var failures := 0
var main: Node3D
var village: VillageManager
var director: NpcDirector
var build: BuildMode
var terrain: LowPolyTerrain
var graph: WalkGraph
var dispatcher: TrainDispatcher


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
	build = main.get_node("BuildMode")
	terrain = main.get_node("World/Terrain")
	graph = main.get_node("World/WalkGraph")
	dispatcher = main.get_node("World/Railway/TrainDispatcher")
	dispatcher.enabled = false
	await frames(10)

	_test_catalog()
	_test_starter_village()
	await _test_build_house()
	await _test_rules()
	await _test_paths()
	await _test_remove_tool()
	await _test_lights()
	await _test_save_load()
	await _test_resident_day()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Katalog -------------------------------------------------------------------------

func _test_catalog() -> void:
	print("--- Catalog and models")
	var counts := {}
	for category: Dictionary in VillageCatalog.CATEGORIES:
		counts[category["id"]] = VillageCatalog.get_items(category["id"]).size()
	check(counts[&"houses"] == 8, "8 houses (%d)" % counts[&"houses"])
	check(counts[&"paths"] == 3, "gravel path, stone path, small road")
	var trees := VillageCatalog.get_items(&"nature").filter(func(id: String) -> bool: return id.begins_with("tree"))
	var bushes := VillageCatalog.get_items(&"nature").filter(func(id: String) -> bool: return id.begins_with("bush"))
	check(trees.size() == 6 and bushes.size() == 4, "6 trees and 4 bushes")
	for id in ["flower_bed", "fence", "hedge", "rocks_small", "log_pile", "grass_tuft", "lantern", "garden_lamp",
			"string_lights", "street_lamp", "bench", "fountain", "signpost", "bike_rack", "mailbox", "planter", "plaza"]:
		check(VillageCatalog.has_item(id), "catalog has %s" % id)
	# Jedes Haus hat eine eigene Form (nicht nur Farbvarianten)
	var shapes := {}
	for type in HouseMeshes.TYPES:
		var house := HouseMeshes.build(type, 0)
		var body: ArrayMesh = house["body"]
		var key := "%s|%d" % [house["size"], body.surface_get_array_len(0)]
		shapes[key] = true
		check(body.surface_get_array_len(0) > 2000 and (house["glass"] as ArrayMesh).get_surface_count() == 1
			and not (house["chimneys"] as Array).is_empty(), "%s: windows, chimney, detailed body" % type)
	check(shapes.size() == 8, "all 8 houses have distinct shapes")
	var built := 0
	for item_id: String in VillageCatalog.ITEMS:
		var meshes := VillageCatalog.build_meshes(item_id, 0, 6.0)
		if meshes["body"] != null and (meshes["body"] as ArrayMesh).get_surface_count() > 0:
			built += 1
	check(built == VillageCatalog.ITEMS.size() - 3, "every non-path item builds a mesh (%d)" % built)


# --- Startdorf -------------------------------------------------------------------------

func _test_starter_village() -> void:
	print("--- Starter village")
	check(village.get_houses().size() == 5, "five family houses (%d)" % village.get_houses().size())
	for family in ["Berger", "Kellner", "Sommer", "Winter", "Hofer"]:
		var home := director.get_home(family)
		check(home is VillageHouse, "%s lives in a real house" % family)
	check(village.get_object_count("plaza") == 1, "village square built")
	check(village.get_object_count("path") >= 7, "street and garden paths (%d)" % village.get_object_count("path"))
	check(graph.get_dynamic_point_count() > 10, "paths extend the walk network (%d points)" % graph.get_dynamic_point_count())
	# Eingeebnetes Gelände unter einem Haus
	var house := director.get_home("Hofer") as VillageHouse
	var worst := 0.0
	for p in VillageFootprint.samples(house.get_footprint(), 1.0):
		worst = maxf(worst, absf(terrain.get_height(p.x, p.y) - house.position.y))
	check(worst < 0.15, "terrain levelled under the farmhouse (%.2f m)" % worst)


# --- Bauen -----------------------------------------------------------------------------

func _test_build_house() -> void:
	print("--- Build a house")
	build.set_active(true)
	build.select_tool(&"village_houses")
	var tool := build.get_current_tool() as VillagePlaceTool
	check(tool != null and tool.get_items().size() == 8, "house tool with 8 houses")
	tool.select_item("house_chalet")
	var spot := Vector3(-61.0, 0.0, 21.0)
	tool.preview_at(spot)
	var before_npcs := director.get_npcs().size()
	var before := village.get_houses().size()
	check(tool.is_valid(), "free spot is valid (%s)" % tool.get_status())
	var money := Economy.money
	var wood := Economy.get_stock("wood")
	check(tool.click_at(spot), "house placed by click")
	await frames(3)
	check(village.get_houses().size() == before + 1, "house exists")
	var house: VillageHouse = village.get_houses()[-1]
	# Etappe 8: erst Baustelle, dann Einzug
	check(not house.is_finished() and house.get_site() != null, "a construction site appears (%s)" % house.get_stage_text())
	check(village.get_residents(house).is_empty(), "nobody moves in before the house is finished")
	check(Economy.money == money - 450 and Economy.get_reserved("wood") >= 45, "money paid, wood reserved for the site")
	village.advance_project(house, 1.0)
	await frames(3)
	check(house.is_finished() and house.get_site() == null, "construction finished")
	check(Economy.get_stock("wood") == wood - 45, "the wood was used up on the site")
	check(village.get_residents(house).size() >= 1 and director.get_npcs().size() > before_npcs,
		"a family moves in (%d)" % village.get_residents(house).size())
	check(director.get_home(house.home_name) == house, "residents know their new home (%s)" % house.home_name)
	# Tür zeigt zur Straße (automatische Ausrichtung zum nächsten Weg)
	var door := house.get_front_point()
	var to_street := village.nearest_path_point(house.position, 20.0)
	check(door.distance_to(to_street) < house.position.distance_to(to_street), "door faces the nearest path")
	build.undo()
	await frames(3)
	check(village.get_houses().size() == before and director.get_npcs().size() == before_npcs, "undo removes house and family")
	check(Economy.money == money and Economy.get_stock("wood") == wood, "undo refunds money and wood exactly")
	build.redo()
	await frames(3)
	check(village.get_houses().size() == before + 1 and Economy.money == money - 450, "redo builds (and pays) again")
	village.advance_project(village.get_houses()[-1], 1.0)
	await frames(3)
	check(director.get_npcs().size() > before_npcs, "and the family moves in again")


func _test_rules() -> void:
	print("--- Placement rules")
	check(village.check_placement("house_cottage", Vector3(3.8, 0, 40), 0.0) != "", "not on the tracks")
	check(village.check_placement("house_cottage", Vector3(0, 0, -9), 0.0) != "", "not on the platform")
	check(village.check_placement("house_cottage", Vector3(-15.0, 0, 1.5), 0.0) != "", "not inside another house")
	check(village.check_placement("house_cottage", Vector3(-30.0, 0, 12.5), 0.0) != "", "not on the street")
	check(village.check_placement("tree_birch", Vector3(-27.0, 0, 4.0), 0.0) != "", "no tree in the fountain")
	check(village.check_placement("grass_tuft", Vector3(-27.0, 0, 14.0), 0.0) == "", "grass may grow beside the street")
	check(village.check_placement("path_gravel", Vector3(-60, 0, 30), 0.0, 0, Vector3(-60.2, 0, 30)) != "", "too short path refused")
	check(village.check_placement("fence", Vector3(-60, 0, 30), 0.0, 0, Vector3(-60, 0, 60)) != "", "too long fence refused")
	check(village.check_placement("path_gravel", Vector3(-16.0, 0, -5.0), 0.0, 0, Vector3(-14.0, 0, 7.0)) != "",
		"no path through a house")


func _test_paths() -> void:
	print("--- Paths")
	build.select_tool(&"village_paths")
	var tool := build.get_current_tool() as VillagePlaceTool
	tool.select_item("path_stone")
	var start := Vector3(-56.0, 0, 13.4)  # nahe am Straßenende → rastet ein
	tool.click_at(start)
	check(tool.has_start(), "path start set")
	var before := village.get_object_count("path")
	check(tool.click_at(Vector3(-56.0, 0, 26.0)), "path segment built")
	check(tool.click_at(Vector3(-50.0, 0, 31.0)), "and continued from its end")
	tool.cancel()
	await frames(3)
	check(village.get_object_count("path") == before + 2, "two new path segments")
	var paths: Array = village.get_objects().filter(func(o) -> bool: return o is VillagePath)
	var first: VillagePath = paths[-2]
	var second: VillagePath = paths[-1]
	check(first.end_point.distance_to(second.start_point) < 0.05, "segments share their node (auto-connected)")
	var road_end := Vector3(-53.0, 0, 12.5)
	check(Vector2(first.start_point.x, first.start_point.z).distance_to(Vector2(road_end.x, road_end.z)) < 3.5
		and village.snap_path_point(Vector3(-55.8, 0, 13.3)) != Vector3(-55.8, 0, 13.3), "start snapped onto the street")
	await frames(2)
	# Bewohner laufen bevorzugt auf Wegen
	var share := graph.get_path_share_on_paths(Vector3(-50.0, 0, 31.0), Vector3(-30.0, 0, 12.5))
	check(share > 0.6, "route from the new path to the village mostly on paths (%.0f %%)" % (share * 100.0))
	var house := director.get_home("Kellner") as VillageHouse
	var share_home := graph.get_path_share_on_paths(house.get_front_point(), Vector3(-13.0, 0, 12.7))
	check(share_home > 0.6, "Kellner's way to the station follows the street (%.0f %%)" % (share_home * 100.0))
	# Wegart: Straße ist breiter als Kiesweg; Schrittgeräusch auf Wegen = Stein
	check(PathMeshes.get_width("path_road") > PathMeshes.get_width("path_gravel"), "road wider than gravel path")
	check(village.is_on_path(Vector3(-30.0, 0, 12.5)) and not village.is_on_path(Vector3(-30.0, 0, 30.0)), "path detection")


func _test_remove_tool() -> void:
	print("--- Remove")
	build.select_tool(&"remove")
	var tool := build.get_current_tool() as RailRemoveTool
	var target = village.pick(Vector3(-19.6, 0, 7.6))
	check(target != null and target.item_id == "snowman", "pick finds the snowman")
	var count := village.get_object_count()
	check(tool.remove_at(Vector3(-19.6, 0, 7.6)), "remove tool removes village objects")
	await frames(2)
	check(village.get_object_count() == count - 1, "one object fewer")
	build.undo()
	await frames(2)
	check(village.get_object_count() == count, "undo brings it back")
	build.set_active(false)


func _test_lights() -> void:
	print("--- Night lights")
	WorldClock.set_time(20.0)
	await frames(30)
	await get_tree().create_timer(3.5).timeout
	var lit := 0
	var warm := true
	for obj in village.get_objects():
		for child in obj.find_children("*", "OmniLight3D", true, false):
			var light := child as OmniLight3D
			if light.visible and light.light_energy > 0.1:
				lit += 1
				warm = warm and light.light_color.r > light.light_color.b + 0.3 and light.light_energy <= 2.1
	check(lit >= 10, "street lamps, door lamps and string lights glow at night (%d)" % lit)
	check(warm, "all village lights are warm yellow and gentle")
	var house := director.get_home("Berger") as VillageHouse
	await get_tree().create_timer(2.5).timeout
	check(house.get_window_glow() > 0.8, "windows glow warmly (%.2f)" % house.get_window_glow())
	WorldClock.set_time(12.0)
	await get_tree().create_timer(3.5).timeout
	var off := true
	for obj in village.get_objects():
		for child in obj.find_children("*", "OmniLight3D", true, false):
			off = off and not (child as OmniLight3D).visible
	check(off, "lights switch off by day")


func _test_save_load() -> void:
	print("--- Save & load")
	var count := village.get_object_count()
	var residents := village.get_generated_resident_count()
	var names := director.get_npcs().map(func(n: Npc) -> String: return n.display_name)
	SaveManager.delete_save("villagetest")
	check(SaveManager.save_game("villagetest"), "save")
	village.clear_all()
	await frames(2)
	check(village.get_object_count() == 0 and village.get_generated_resident_count() == 0, "village cleared")
	check(SaveManager.load_game("villagetest"), "load")
	await frames(5)
	check(village.get_object_count() == count, "all objects restored (%d)" % village.get_object_count())
	check(village.get_generated_resident_count() == residents, "same number of residents")
	var names_after := director.get_npcs().map(func(n: Npc) -> String: return n.display_name)
	names.sort()
	names_after.sort()
	check(names == names_after, "the same families live in the same houses")
	SaveManager.delete_save("villagetest")


## Ein neu gebautes Haus: Die Bewohner verlassen morgens das Haus, gehen über
## die Wege zum Bahnhof und fahren mit dem Zug.
func _test_resident_day() -> void:
	print("--- A resident's day")
	var boarded: Array = []
	director.passenger_boarded.connect(func(npc: Npc, train: Train) -> void: boarded.append(npc.display_name))
	var generated: Array = []
	for house in village.get_houses():
		for profile: NpcProfile in village.get_residents(house):
			generated.append(profile)
	var commuters := generated.filter(func(p: NpcProfile) -> bool:
		return p.routines.any(func(r: NpcRoutine) -> bool: return r.activity == NpcRoutine.Activity.TRAVEL))
	check(not generated.is_empty(), "generated residents exist (%d)" % generated.size())
	if commuters.is_empty():
		check(false, "at least one commuter")
		return
	var commuter: NpcProfile = commuters[0]
	var trip: NpcRoutine = commuter.routines[0]
	WorldClock.set_time(trip.get_start_hours() - 0.1)
	director.resume_all()
	var npc: Npc = null
	for candidate in director.get_npcs():
		if candidate.profile == commuter:
			npc = candidate
	check(npc != null and npc.state == Npc.State.AT_HOME, "%s is at home before leaving" % commuter.display_name)
	WorldClock.paused = false
	dispatcher.enabled = true
	# Bewohner gehen höchstens 3× so schnell – bei 3× stimmt das Verhältnis zur Uhr
	WorldClock.time_scale = 3.0
	var left_home := false
	var on_paths := 0
	var samples := 0
	var end := trip.get_until_hours() + 0.1
	while WorldClock.time_of_day < end and not boarded.has(commuter.display_name):
		await get_tree().physics_frame
		if npc.is_present():
			left_home = true
			if npc.is_moving():
				samples += 1
				if village.is_on_path(npc.global_position) or _near_base_route(npc.global_position):
					on_paths += 1
	WorldClock.time_scale = 1.0
	WorldClock.paused = true
	dispatcher.enabled = false
	check(left_home, "%s leaves the house in the morning" % commuter.display_name)
	check(samples > 0 and float(on_paths) / samples > 0.7, "walks along paths (%d of %d samples)" % [on_paths, samples])
	check(boarded.has(commuter.display_name), "and takes the train to %s" % trip.destination)
	dispatcher.clear_trains()


## Liegt der Punkt auf dem festen Fußwegenetz (Bahnsteig, Übergang, Dorfstraße)?
func _near_base_route(p: Vector3) -> bool:
	var base := graph.get_base_points()
	for link in graph.links:
		var ends := link.split("-")
		var a: Vector3 = base[ends[0]]
		var b: Vector3 = base[ends[1]]
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
		if q.distance_to(Vector2(p.x, p.z)) < 2.0:
			return true
	return false
