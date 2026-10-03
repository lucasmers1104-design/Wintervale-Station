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

## Legacy journeys retain their built world; all new journeys start undeveloped.
@export var legacy_world := false
var progression: RegionProgression
var region: RegionRailway

func _enter_tree() -> void:
	# Baustoffhandel nur im Epochen-Spiel (dort baut man das Dorf ohne Güterzüge an).
	Economy.material_shop = not legacy_world
	if legacy_world:
		return
	for path in ["World/TestArea","World/Railway/NordtalPortal","World/Railway/SuedtalPortal","World/Railway/Platform1Stop","World/Railway/Platform2Stop","World/Railway/FreightStop"]:
		var old := get_node_or_null(path)
		if old:
			old.get_parent().remove_child(old)
			old.free()
	var graph := get_node("World/WalkGraph") as WalkGraph
	graph.links = PackedStringArray()
	for child in graph.get_children():
		graph.remove_child(child)
		child.free()
	var director := get_node("NpcDirector") as NpcDirector
	director.auto_load_profiles = false
	director.enabled = false
	var yard := get_node("World/FreightYard") as FreightYard
	yard.enabled = false
	yard.progressive_dormant = true
	get_node("Festivals").set("enabled",false)
	get_node("TrainEvents").set("enabled",false)
	var dispatch := get_node("World/Railway/TrainDispatcher") as TrainDispatcher
	dispatch.timetable = Timetable.new()
	progression = RegionProgression.new()
	progression.name = "Progression"
	add_child(progression)
	region = RegionRailway.new()
	region.name = "RegionRailway"
	region.network = get_node("World/Railway/RailNetwork")
	region.dispatcher = dispatch
	region.terrain = get_node("World/Terrain")
	region.village = get_node("World/Village")
	region.progression = progression
	progression.region = region
	add_child(region)
	var tool := StationBuildTool.new()
	tool.tool_id = &"station"
	tool.region = region
	get_node("BuildMode").add_child(tool)


func _ready() -> void:
	var spawn := Vector3(player_spawn.x, terrain.get_height(player_spawn.x, player_spawn.z) + 0.2, player_spawn.z)
	player.global_position = spawn
	player.set_spawn_point(spawn)
	player.snap_camera()

	if legacy_world and starter_railway:
		starter_railway.build_if_empty()
	if legacy_world and village:
		StarterVillage.build_if_empty(village)
	network.topology_changed.connect(_align_portals)
	_align_portals()
	if nature:
		nature.refresh_clearings.call_deferred()
	var achievement_toast := AchievementToast.new()
	achievement_toast.name = "AchievementToast"
	add_child(achievement_toast)
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	Events.pause_menu_requested.connect(pause_menu.open)
	Achievements.attach_world(self)
	Events.notification_requested.emit("Willkommen in Wintervale")
	GameSettings.apply_gameplay.call_deferred()
	WorldClock.day_changed.connect(_on_autosave_day)
	if region:
		var panel := RegionPanel.new()
		panel.region = region
		panel.name = "RegionPanel"
		add_child(panel)
		get_node("HUD").bind_progression(progression)
		var tutorial := JourneyTutorial.new()
		tutorial.name = "JourneyTutorial"
		tutorial.region = region
		tutorial.panel = panel
		tutorial.build_mode = get_node("BuildMode")
		tutorial.hud = get_node("HUD")
		add_child(tutorial)
		var guide := JourneyGuide.new()
		guide.name = "JourneyGuide"
		guide.region = region
		guide.panel = panel
		guide.tutorial = tutorial
		guide.build_mode = get_node("BuildMode")
		guide.hud = get_node("HUD")
		tutorial.guide = guide
		add_child(guide)
	else:
		get_node("HUD")._tool_buttons[&"station"].hide()


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
