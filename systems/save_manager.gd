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
const DEFAULT_SLOT := "quicksave"
## Wird erhöht, sobald sich das Format ändert (siehe _migrate()).
const SAVE_VERSION := 2


func save_game(slot: String = DEFAULT_SLOT) -> bool:
	var objects := {}
	for node in get_tree().get_nodes_in_group(GameDefs.GROUP_SAVEABLE):
		if not _is_saveable(node):
			continue
		objects[node.get_save_id()] = node.save_state()

	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"objects": objects,
	}

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Konnte '%s' nicht schreiben (%s)." % [
			get_save_path(slot), error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	Events.game_saved.emit(slot)
	return true


func load_game(slot: String = DEFAULT_SLOT) -> bool:
	if not has_save(slot):
		return false

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(get_save_path(slot)))
	if not parsed is Dictionary:
		push_error("SaveManager: Spielstand '%s' ist beschädigt." % slot)
		return false

	var data: Dictionary = _migrate(parsed)
	var objects: Dictionary = data.get("objects", {})
	for node in get_tree().get_nodes_in_group(GameDefs.GROUP_SAVEABLE):
		if not _is_saveable(node):
			continue
		var id: String = node.get_save_id()
		if objects.has(id):
			node.load_state(objects[id])

	Events.game_loaded.emit(slot)
	return true


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


func delete_save(slot: String = DEFAULT_SLOT) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(get_save_path(slot))


func get_save_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"


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
