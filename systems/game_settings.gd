## Dauerhafte Einstellungen (Autoload "GameSettings").
##
## Unabhängig von Spielständen: Gilt für jede Partie und bleibt nach einem
## Neustart erhalten. Gespeichert in user://settings.cfg.
extends Node

signal changed

const PATH := "user://settings.cfg"

## Tastenlegende ausgeklappt (true) oder nur als kleiner Hinweis (false).
var legend_expanded := true
var fullscreen := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		legend_expanded = bool(config.get_value("ui", "legend_expanded", legend_expanded))
		fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	_apply_fullscreen()


func set_legend_expanded(value: bool) -> void:
	legend_expanded = value
	_save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	_save()


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "legend_expanded", legend_expanded)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(PATH)
	changed.emit()
