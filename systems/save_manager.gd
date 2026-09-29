## Speichersystem (Autoload "SaveManager") – Vorbereitung für spätere Etappen.
##
## Funktionsweise:
##   Jeder Node in der Gruppe [constant GameDefs.GROUP_SAVEABLE] liefert über
##   save_state() ein Dictionary und bekommt es über load_state() zurück.
##   get_save_id() gibt einen stabilen Schlüssel, unter dem die Daten liegen.
##
## Die Spielstände liegen als lesbares JSON unter user://saves/ (Windows:
## %APPDATA%/Godot/app_userdata/Wintervale Station/saves/). res:// ist in
## exportierten Spielen schreibgeschützt und daher nur für Vorlagen gedacht.
extends Node

const SAVE_DIR := "user://saves/"
## Tatsächlicher Ordner – in Tests (siehe QaSandbox) umgeleitet.
var save_dir := QaSandbox.redirect(SAVE_DIR)
const DEFAULT_SLOT := "quicksave"
## Wird erhöht, sobald sich das Format ändert (siehe _migrate()).
const SAVE_VERSION := 2
const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]
var active_slot := DEFAULT_SLOT
var journey_name := "Wintervale"
var playtime_seconds := 0.0


func _ready() -> void:
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return
	for filename in dir.get_files():
		if not filename.ends_with(".json.bak"):
			continue
		var slot := filename.trim_suffix(".json.bak")
		if _valid_slot(slot) and not FileAccess.file_exists(get_save_path(slot)):
			DirAccess.rename_absolute(save_dir + filename, get_save_path(slot))


func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://scenes/main/main.tscn" and not WorldClock.paused:
		playtime_seconds += delta


func save_game(slot: String = DEFAULT_SLOT) -> bool:
	if not _valid_slot(slot):
		return false
	var objects := {}
	for node in get_tree().get_nodes_in_group(GameDefs.GROUP_SAVEABLE):
		if not _is_saveable(node):
			continue
		objects[node.get_save_id()] = node.save_state()

	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"saved_unix": Time.get_unix_time_from_system(),
		"metadata": _current_metadata(),
		"objects": objects,
	}

	DirAccess.make_dir_recursive_absolute(save_dir)
	var path := get_save_path(slot)
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Konnte '%s' nicht schreiben (%s)." % [
			temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(path, backup) != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	if DirAccess.rename_absolute(temp_path, path) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if DisplayServer.get_name() != "headless" and get_tree().current_scene \
			and get_tree().current_scene.scene_file_path == "res://scenes/main/main.tscn":
		var capture := get_viewport().get_texture().get_image()
		if capture:
			capture.resize(480, 270, Image.INTERPOLATE_LANCZOS)
			capture.save_png(save_dir + slot + ".png")

	active_slot = slot
	Events.game_saved.emit(slot)
	return true


func load_game(slot: String = DEFAULT_SLOT) -> bool:
	var data := read_save_data(slot)
	if not _is_restorable(data):
		return false
	var objects: Dictionary = data.get("objects", {})
	Achievements.suspend(true)
	if not objects.has(Achievements.SAVE_ID):
		Achievements.reset()
	for node in get_tree().get_nodes_in_group(GameDefs.GROUP_SAVEABLE):
		if not _is_saveable(node):
			continue
		var id: String = node.get_save_id()
		if objects.has(id):
			node.load_state(objects[id])
	Achievements.suspend(false)
	Achievements.refresh_after_load()

	var metadata: Dictionary = data.get("metadata", {})
	journey_name = String(metadata.get("name", slot))
	playtime_seconds = float(metadata.get("playtime_seconds", 0.0))
	active_slot = slot
	Events.game_loaded.emit(slot)
	return true


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return _valid_slot(slot) and FileAccess.file_exists(get_save_path(slot))


func delete_save(slot: String = DEFAULT_SLOT) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(get_save_path(slot))
		var backup := get_save_path(slot) + ".bak"
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		var thumbnail := save_dir + slot + ".png"
		if FileAccess.file_exists(thumbnail):
			DirAccess.remove_absolute(thumbnail)
		if active_slot == slot:
			active_slot = DEFAULT_SLOT


func get_save_path(slot: String) -> String:
	return save_dir + slot + ".json" if _valid_slot(slot) else ""


func read_save_data(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(get_save_path(slot))) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = _migrate(parsed)
	if int(data.get("version", -1)) < 1 or int(data.get("version", -1)) > SAVE_VERSION:
		return {}
	var objects: Variant = data.get("objects")
	if not objects is Dictionary or objects.is_empty():
		return {}
	if data.has("metadata") and not data["metadata"] is Dictionary:
		return {}
	for value: Variant in objects.values():
		if not value is Dictionary:
			return {}
	return data


func list_saves(include_invalid := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return result
	for filename in dir.get_files():
		if not filename.ends_with(".json"):
			continue
		var slot := filename.trim_suffix(".json")
		if not _valid_slot(slot):
			continue
		var data := read_save_data(slot)
		var restorable := _is_restorable(data)
		if not restorable and not include_invalid:
			continue
		var entry: Dictionary = data.get("metadata", {}).duplicate()
		if not data.is_empty() and not entry.has("season"):
			entry.merge(_legacy_metadata(data), false)
		entry["slot"] = slot
		entry["valid"] = restorable
		entry["saved_at"] = data.get("saved_at", "")
		entry["saved_unix"] = float(data.get("saved_unix", 0.0))
		if entry["saved_unix"] == 0:
			entry["saved_unix"] = float(FileAccess.get_modified_time(get_save_path(slot)))
		if not entry.has("name"):
			entry["name"] = slot.capitalize()
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["saved_unix"]) > float(b["saved_unix"]))
	return result


func most_recent_valid_slot() -> String:
	var saves := list_saves()
	return String(saves[0]["slot"]) if not saves.is_empty() else ""


func _is_restorable(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var objects: Dictionary = data.get("objects", {})
	for id in ["world_clock", "rail_network", "village"]:
		if not objects.has(id) or not objects[id] is Dictionary:
			return false
	return objects["rail_network"].get("segments", null) is Array \
		and objects["village"].get("objects", null) is Array \
		and objects["world_clock"].has("day")


func make_unique_slot(name: String) -> String:
	var base := name.to_lower().strip_edges().replace(" ", "_")
	var safe := ""
	for character in base:
		if "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			safe += character
	if safe.is_empty():
		safe = "journey"
	var candidate := safe
	var suffix := 2
	while has_save(candidate):
		candidate = "%s_%d" % [safe, suffix]
		suffix += 1
	return candidate


func _current_metadata() -> Dictionary:
	var population := 0
	var train_count := 0
	for node in get_tree().get_nodes_in_group(GameDefs.GROUP_SAVEABLE):
		if node.has_method("get_population"):
			population = int(node.get_population())
		if node.has_method("get_trains"):
			train_count = node.get_trains().size()
	return {
		"name": journey_name,
		"day": WorldClock.day,
		"time": WorldClock.get_time_string(),
		"season": SEASON_NAMES[Seasons.get_season()],
		"population": population,
		"trains": train_count,
		"playtime_seconds": playtime_seconds,
	}


func _legacy_metadata(data: Dictionary) -> Dictionary:
	var objects: Dictionary = data.get("objects", {})
	var clock: Dictionary = objects.get("world_clock", {})
	var season_state: Dictionary = objects.get("seasons", {})
	var game_day := int(clock.get("day", 1))
	var hour := float(clock.get("time_of_day", 0.0))
	var winter_start := Seasons.LENGTHS[0] + Seasons.LENGTHS[1] + Seasons.LENGTHS[2]
	var year_length := winter_start + Seasons.LENGTHS[3]
	var year_day := fposmod(winter_start + Seasons.START_IN_WINTER + float(game_day - 1)
		+ hour / 24.0 + float(season_state.get("offset_days", 0.0)), year_length)
	var season_index := 3
	var start := 0.0
	for i in Seasons.LENGTHS.size():
		if year_day < start + Seasons.LENGTHS[i]:
			season_index = i
			break
		start += Seasons.LENGTHS[i]
	return {"day": game_day, "time": "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)],
		"season": SEASON_NAMES[season_index]}


func _valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 64:
		return false
	for character in slot:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-".contains(character):
			return false
	return true


## Hebt ältere Spielstände auf das aktuelle Format an.
## Neue Formatversionen bekommen hier einen eigenen Schritt.
## Version 1 → 2: Gleise ohne Höhenprofil laufen linear weiter, Signale und
## Weichen fehlen einfach – beides lädt ohne Umrechnung.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: Spielstand stammt aus einer neueren Version (%d)." % version)
	return data


func _is_saveable(node: Node) -> bool:
	var ok := node.has_method("get_save_id") and node.has_method("save_state") \
		and node.has_method("load_state")
	if not ok:
		push_warning("SaveManager: '%s' ist in der Gruppe saveable, implementiert aber nicht alle Methoden." % node.name)
	return ok
