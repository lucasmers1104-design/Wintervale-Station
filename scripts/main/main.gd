## Einstiegspunkt der Spielwelt (scenes/main/main.tscn).
##
## Setzt die Spielfigur auf den Startpunkt und verarbeitet globale
## Spielaktionen: Zeitraffer, Schnellspeichern und Schnellladen.
extends Node3D

@export var terrain: LowPolyTerrain
@export var player: PlayerController
## Startpunkt der Spielfigur (Höhe wird automatisch auf das Terrain gesetzt).
@export var player_spawn := Vector3(0.0, 0.0, 6.0)


func _ready() -> void:
	var spawn := Vector3(player_spawn.x, terrain.get_height(player_spawn.x, player_spawn.z) + 0.2, player_spawn.z)
	player.global_position = spawn
	player.set_spawn_point(spawn)
	Events.notification_requested.emit("Willkommen in Wintervale")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"time_speed"):
		var time_factor := WorldClock.cycle_time_scale()
		Events.notification_requested.emit("Zeit ×%d" % int(time_factor))
	elif event.is_action_pressed(&"quick_save"):
		SaveManager.save_game()
	elif event.is_action_pressed(&"quick_load"):
		if not SaveManager.load_game():
			Events.notification_requested.emit("Noch kein Spielstand vorhanden")
	else:
		return
	get_viewport().set_input_as_handled()
