## Automatischer Test für Etappe 9: Jahreszeiten, Wetter und Welt-Feinschliff.
##
## Prüft den Jahreslauf (Jahreszeiten, weiche Übergänge, Tageslänge, Shader-
## Globals), das Wetter (Profile, Auswahl passend zur Jahreszeit, Partikel,
## Speichern), die neuen Wege (Material, Höhe über dem Gelände, keine Spur-Ringe
## an Knoten), die Geländemarkierungen, Fußspuren, Wintersachen (Schneemann,
## Schneebänke), schwingende Laternen, Funken und die Klangkulisse.
##
## Start: godot --headless --path . --fixed-fps 60 res://tests/world_test.tscn
extends Node

var failures := 0
var main: Node3D
var village: VillageManager
var terrain: LowPolyTerrain
var weather: WeatherSystem


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
	terrain = main.get_node("World/Terrain")
	weather = main.get_node("Weather")
	(main.get_node("World/Railway/TrainDispatcher") as TrainDispatcher).enabled = false
	await frames(10)

	_test_seasons()
	_test_weather()
	_test_paths()
	_test_terrain_markers()
	await _test_footprints()
	await _test_winter_objects()
	await _test_village_details()
	await _test_audio()
	_test_save_load()

	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- Jahreszeiten ------------------------------------------------------------------------

func _test_seasons() -> void:
	print("--- Seasons")
	check(Seasons.get_season() == Seasons.Season.WINTER, "the game starts in winter")
	check(is_equal_approx(Seasons.get_snow_cover(), 1.0), "full snow cover in winter")
	for season: int in 4:
		Seasons.set_season(season, 0.5)
		var weights := Seasons.get_weights()
		var total := 0.0
		for w in weights:
			total += w
		check(Seasons.get_season() == season, "set_season → %s" % Seasons.get_season_name())
		check(is_equal_approx(total, 1.0) and is_equal_approx(weights[season], 1.0),
			"%s: mid-season is purely this season" % Seasons.get_season_name())
	Seasons.set_season(Seasons.Season.SUMMER, 0.5)
	var summer_day := Seasons.get_sunset() - Seasons.get_sunrise()
	check(is_zero_approx(Seasons.get_snow_cover()), "no snow in summer")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	var winter_day := Seasons.get_sunset() - Seasons.get_sunrise()
	check(summer_day > winter_day + 5.0, "summer days are much longer (%.1f h vs %.1f h)" % [summer_day, winter_day])
	# Übergang: an der Grenze Winter → Frühling mischen sich beide etwa zur Hälfte
	Seasons.set_season(Seasons.Season.WINTER, 0.9999)
	var weights := Seasons.get_weights()
	check(weights[Seasons.Season.WINTER] > 0.35 and weights[Seasons.Season.SPRING] > 0.35,
		"soft transition at the season boundary (%.2f / %.2f)" % [weights[3], weights[0]])
	var cover := Seasons.get_snow_cover()
	check(cover > 0.2 and cover < 0.8, "snow is half melted at the boundary (%.2f)" % cover)
	# Nächste Jahreszeit (Taste J) ohne Animation
	Seasons.set_season(Seasons.Season.AUTUMN, 0.5)
	Seasons.skip_to_next(0.0)
	check(Seasons.get_season() == Seasons.Season.WINTER, "skip_to_next: autumn → winter")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)


# --- Wetter ------------------------------------------------------------------------------

func _test_weather() -> void:
	print("--- Weather")
	check(WeatherSystem.NAMES.size() == 7, "7 weather types")
	var snowfall: Snowfall = main.get_node("Snowfall")
	var rainfall: Rainfall = main.get_node("Rainfall")
	weather.set_weather(WeatherSystem.Weather.HEAVY_SNOW, true)
	check(is_equal_approx(snowfall._weather_intensity, 1.0) and rainfall.intensity == 0.0, "heavy snow: full snowfall, no rain")
	check(WeatherSystem.wind > 0.7, "heavy snow is windy (%.2f)" % WeatherSystem.wind)
	weather.set_weather(WeatherSystem.Weather.RAIN, true)
	check(rainfall.intensity > 0.9 and snowfall._weather_intensity == 0.0, "rain: rain particles, no snow")
	weather.set_weather(WeatherSystem.Weather.FOG, true)
	check(weather.get_value("fog") > 4.0 and weather.get_value("wind") < 0.1, "fog: dense and calm")
	weather.set_weather(WeatherSystem.Weather.SUNNY, true)
	check(weather.get_value("cloud") < 0.2 and weather.get_value("sun") > 0.9, "sunny: clear sky, full sun")
	# Weicher Wechsel: direkt nach dem Umschalten noch fast das alte Wetter
	weather.set_weather(WeatherSystem.Weather.CLOUDY)
	check(weather.is_transitioning() and weather.get_value("cloud") < 0.2, "weather changes softly, not instantly")
	# Auswahl passend zur Jahreszeit
	Seasons.set_season(Seasons.Season.SUMMER, 0.5)
	var snow_in_summer := false
	for i in 150:
		weather._choose_next()
		if weather.current in [WeatherSystem.Weather.LIGHT_SNOW, WeatherSystem.Weather.HEAVY_SNOW]:
			snow_in_summer = true
	check(not snow_in_summer, "no snowfall in summer")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	var rain_in_winter := false
	var snow_seen := false
	for i in 150:
		weather._choose_next()
		rain_in_winter = rain_in_winter or weather.current == WeatherSystem.Weather.RAIN
		snow_seen = snow_seen or weather.current == WeatherSystem.Weather.LIGHT_SNOW
	check(not rain_in_winter and snow_seen, "winter: snow, never rain")
	weather.set_weather(WeatherSystem.Weather.LIGHT_SNOW, true)


# --- Wege --------------------------------------------------------------------------------

func _test_paths() -> void:
	print("--- Paths")
	var height := func(x: float, z: float) -> float: return terrain.get_height(x, z)
	var styles := {}
	for id in ["path_gravel", "path_stone", "path_road"]:
		var material := PathMeshes.material(id) as ShaderMaterial
		check(material != null and material.shader.resource_path.ends_with("path.gdshader"), "%s uses the path shader" % id)
		if material:
			styles[int(material.get_shader_parameter(&"style"))] = true
		var a := Vector3(-60.0, 0.0, 40.0)
		var b := Vector3(-52.0, 0.0, 44.0)
		var mesh := PathMeshes.build(id, a, b, height)
		check(mesh.get_surface_count() == 2, "%s: path surface + detail surface" % id)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var buried := 0
		var disc_lanes := 0.0
		for i in vertices.size():
			var v := vertices[i]
			if absf(uvs[i].x) <= 1.0 and v.y < terrain.get_height(v.x, v.z) + 0.02:
				buried += 1
			if is_zero_approx(uvs[i].y) and absf(uvs[i].x) < 0.9:
				disc_lanes = maxf(disc_lanes, colors[i].r)
		check(buried == 0, "%s: the path band never sinks into the ground (%d)" % [id, buried])
		check(disc_lanes == 0.0, "%s: node discs have no wheel ruts (no rings)" % id)
	check(styles.size() == 3, "gravel, stone and road look different")


# --- Gelände -----------------------------------------------------------------------------

func _test_terrain_markers() -> void:
	print("--- Terrain")
	var markers := {}
	for node in terrain.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh and node.name.begins_with("Chunk"):
			var colors: PackedColorArray = (node as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			for c in colors:
				markers[snappedf(c.a, 0.05)] = true
	check(markers.has(0.5) and markers.has(0.75) and markers.has(1.0),
		"terrain faces are marked snow / bare ground / rock (%s)" % str(markers.keys()))
	check(markers.size() == 3, "no other markers")


# --- Fußspuren ---------------------------------------------------------------------------

func _test_footprints() -> void:
	print("--- Footprints")
	var prints: Footprints = get_tree().get_first_node_in_group(Footprints.GROUP)
	check(prints != null, "footprints exist")
	if not prints:
		return
	var walker := Node.new()
	add_child(walker)
	var before := prints.get_active_count()
	for i in 6:
		prints.add_step(walker, Vector3(-30.0 + i * 0.7, 0.0, 30.0))
	check(prints.get_active_count() == before + 6, "winter: every step leaves a print")
	Seasons.set_season(Seasons.Season.SUMMER, 0.5)
	var summer_before := prints.get_active_count()
	prints.add_step(walker, Vector3(-25.0, 0.0, 30.0))
	check(prints.get_active_count() == summer_before, "summer: no prints")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	walker.queue_free()


# --- Wintersachen ------------------------------------------------------------------------

func _test_winter_objects() -> void:
	print("--- Winter objects")
	var snowman: VillageObject = null
	for obj in village.get_objects():
		if obj is VillageObject and (obj as VillageObject).item_id == "snowman":
			snowman = obj
	check(snowman != null and snowman.is_winter_visible() and snowman.visible, "snowman stands in winter")
	var bank: StationProp = null
	for node in main.find_children("*", "StationProp", true, false):
		if (node as StationProp).kind == StationProp.Kind.SNOW_BANK:
			bank = node
			break
	check(bank != null and bank.collision_layer != 0, "snow bank is solid in winter")
	Seasons.set_season(Seasons.Season.SUMMER, 0.5)
	await frames(150)
	if snowman:
		check(not snowman.is_winter_visible() and snowman.collision_layer == 0, "snowman melts away in summer")
	if bank:
		check(bank.collision_layer == 0, "melted snow bank has no collision")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	await frames(150)
	if snowman:
		check(snowman.is_winter_visible() and snowman.visible, "snowman is back next winter")


# --- Dorfdetails -------------------------------------------------------------------------

func _test_village_details() -> void:
	print("--- Village details")
	var sways := main.find_children("*", "LampSway", true, false)
	check(sways.size() >= 4, "street lamps have swinging heads (%d)" % sways.size())
	var sparks := 0
	for house in village.get_houses():
		for node in house.find_children("Sparks", "GPUParticles3D", true, false):
			sparks += 1
	check(sparks >= 3, "chimneys have sparks (%d)" % sparks)
	if not sways.is_empty():
		var sway: LampSway = sways[0]
		weather.set_weather(WeatherSystem.Weather.HEAVY_SNOW, true)
		var biggest := 0.0
		for i in 90:
			await get_tree().process_frame
			biggest = maxf(biggest, absf(sway.rotation.x))
		weather.set_weather(WeatherSystem.Weather.CLEAR_EVENING, true)
		var calm := 0.0
		for i in 90:
			await get_tree().process_frame
			calm = maxf(calm, absf(sway.rotation.x))
		check(biggest > calm * 2.0 and biggest < 0.12, "lanterns swing more in storm (%.3f) than calm (%.3f)" % [biggest, calm])
	weather.set_weather(WeatherSystem.Weather.LIGHT_SNOW, true)


# --- Klang -------------------------------------------------------------------------------

func _test_audio() -> void:
	print("--- Soundscape")
	for sound in ["tree_wind", "snow_hiss", "rain_roof", "fireplace", "church_bell", "fog_horn", "crickets",
			"winter_bird_0", "winter_bird_1", "step_grass"]:
		check(SoundLibrary.get_sound(sound) != null, "sound %s" % sound)
	var soundscape := main.get_node("AmbientSoundscape")
	var volumes: Dictionary = soundscape.call(&"get_loop_volumes")
	check(volumes.has_all(["trees", "snow", "rain", "crickets", "fire", "wind"]), "weather loops exist")


# --- Speichern ---------------------------------------------------------------------------

func _test_save_load() -> void:
	print("--- Save/load")
	Seasons.set_season(Seasons.Season.AUTUMN, 0.3)
	weather.set_weather(WeatherSystem.Weather.FOG, true)
	var season_data := Seasons.save_state()
	var weather_data := weather.save_state()
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
	weather.set_weather(WeatherSystem.Weather.SUNNY, true)
	Seasons.load_state(season_data)
	weather.load_state(weather_data)
	check(Seasons.get_season() == Seasons.Season.AUTUMN, "season restored")
	check(weather.current == WeatherSystem.Weather.FOG and weather.get_value("fog") > 4.0, "weather restored")
	Seasons.set_season(Seasons.Season.WINTER, 0.5)
