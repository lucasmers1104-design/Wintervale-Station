## Einstiegspunkt der Spielwelt (scenes/main/main.tscn).
##
## Setzt die Spielfigur auf den Startpunkt, baut beim ersten Start die
## Strecke Nordtal – Wintervale – Südtal sowie das Startdorf und verarbeitet globale
## Spielaktionen: Zeitraffer, Schnellspeichern und Schnellladen.
extends Node3D

@export var terrain: LowPolyTerrain
@export var player: PlayerController
@export var network: RailNetwork
@export var starter_railway: StarterRailway
@export var nature: PropScatter
@export var village: VillageManager
## Startpunkt der Spielfigur (Höhe wird automatisch auf das Terrain gesetzt).
@export var player_spawn := Vector3(0.0, 0.0, 6.0)


func _ready() -> void:
	var spawn := Vector3(player_spawn.x, terrain.get_height(player_spawn.x, player_spawn.z) + 0.2, player_spawn.z)
	player.global_position = spawn
	player.set_spawn_point(spawn)
	player.snap_camera()

	if starter_railway:
		starter_railway.build_if_empty()
	if village:
		StarterVillage.build_if_empty(village)
	network.topology_changed.connect(_align_portals)
	_align_portals()
	if nature:
		nature.refresh_clearings.call_deferred()
	var achievement_toast := AchievementToast.new()
	achievement_toast.name = "AchievementToast"
	add_child(achievement_toast)
	Achievements.attach_world(self)
	Events.notification_requested.emit("Willkommen in Wintervale")
	GameSettings.apply_gameplay.call_deferred()
	WorldClock.day_changed.connect(_on_autosave_day)


func _on_autosave_day(_day: int) -> void:
	if GameSettings.get_pref("autosave"):
		SaveManager.save_game(SaveManager.active_slot)


func _exit_tree() -> void:
	Achievements.detach_world()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"time_speed"):
		var time_factor := WorldClock.cycle_time_scale()
		Events.notification_requested.emit("Zeit ×%d" % int(time_factor))
	elif event.is_action_pressed(&"quick_save"):
		SaveManager.save_game(SaveManager.active_slot)
	elif event.is_action_pressed(&"quick_load"):
		if not SaveManager.load_game(SaveManager.active_slot):
			Events.notification_requested.emit("Noch kein Spielstand vorhanden")
	else:
		return
	get_viewport().set_input_as_handled()


## Tunnelportale und Bohlenübergänge auf die Höhe ihres Gleises setzen.
func _align_portals() -> void:
	for portal in get_tree().get_nodes_in_group(TrainPortal.GROUP):
		(portal as TrainPortal).align_to_track(network)
	for prop in get_tree().get_nodes_in_group(StationProp.RAIL_ALIGNED_GROUP):
		(prop as StationProp).align_to_track(network)
