## Schlankes HUD: Uhrzeit, kurze Hinweise, ausblendbare Tastenhilfe und
## im Build-Mode ein kleines Werkzeug-Panel unten links.
##
## Das HUD hört nur auf Signale (WorldClock, Events) und kennt keine
## anderen Spielsysteme direkt. Werkzeugwahl per Klick läuft über
## Events.build_tool_requested.
class_name GameHUD
extends CanvasLayer

const HELP_EXPLORE := "WASD  Gehen     Shift  Laufen     Leertaste  Springen\n" \
	+ "Maus  Umsehen     Mausrad  Abstand     V  Ich-/Verfolgerperspektive\n" \
	+ "Tab  Vogelperspektive"
const HELP_BIRD_EYE := "WASD  Verschieben     Q / E  Drehen     Mausrad  Zoom\n" \
	+ "Mittlere Maustaste  Drehen & Neigen     Rechte Maustaste  Ziehen\n" \
	+ "B  Bauen     Tab  Zur Spielfigur"
const HELP_BUILD := "Linksklick  Start setzen / Gleis bauen     Rechtsklick / Esc  Abbrechen\n" \
	+ "1  Schiene     2  Entfernen     Strg+Z  Rückgängig     Strg+Y  Wiederholen\n" \
	+ "Alt  Freier Winkel     B / Esc  Bauen beenden"
const HELP_GLOBAL := "T  Zeitraffer     F5  Speichern     F9  Laden     F1  Hilfe     F11  Vollbild     Esc  Maus frei"

## So lange bleibt die Hilfe nach dem Start sichtbar (Sekunden).
@export var help_visible_seconds := 14.0

var _help_visible := true
var _view_mode := GameDefs.ViewMode.EXPLORE
var _build_active := false
var _help_tween: Tween
var _toast_tween: Tween

@onready var _clock_label: Label = %ClockLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _help_panel: PanelContainer = %HelpPanel
@onready var _help_label: Label = %HelpLabel
@onready var _build_panel: PanelContainer = %BuildPanel
@onready var _rail_button: Button = %RailButton
@onready var _remove_button: Button = %RemoveButton
@onready var _status_label: Label = %StatusLabel
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)
	WorldClock.day_changed.connect(_on_day_changed)
	WorldClock.time_scale_changed.connect(_on_time_scale_changed)
	Events.view_mode_changed.connect(_on_view_mode_changed)
	Events.notification_requested.connect(show_toast)
	Events.game_saved.connect(_on_game_saved)
	Events.game_loaded.connect(_on_game_loaded)
	Events.build_mode_changed.connect(_on_build_mode_changed)
	Events.build_tool_changed.connect(_on_build_tool_changed)
	Events.build_status_changed.connect(_on_build_status_changed)

	var tool_group := ButtonGroup.new()
	_rail_button.button_group = tool_group
	_remove_button.button_group = tool_group
	_rail_button.pressed.connect(Events.build_tool_requested.emit.bind(&"rail"))
	_remove_button.pressed.connect(Events.build_tool_requested.emit.bind(&"remove"))

	_toast_label.modulate.a = 0.0
	_update_clock()
	_on_time_scale_changed(WorldClock.time_scale)
	_update_help_text()
	get_tree().create_timer(help_visible_seconds).timeout.connect(_set_help_visible.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		_set_help_visible(not _help_visible)
		get_viewport().set_input_as_handled()


## Zeigt kurz eine Nachricht oben in der Bildmitte.
func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func _set_help_visible(value: bool) -> void:
	_help_visible = value
	if _help_tween and _help_tween.is_valid():
		_help_tween.kill()
	_help_panel.visible = true
	_help_tween = create_tween()
	_help_tween.tween_property(_help_panel, "modulate:a", 1.0 if value else 0.0, 0.4)
	if not value:
		_help_tween.tween_callback(_help_panel.hide)


func _update_help_text() -> void:
	var mode_help := HELP_EXPLORE
	if _build_active:
		mode_help = HELP_BUILD
	elif _view_mode == GameDefs.ViewMode.BIRD_EYE:
		mode_help = HELP_BIRD_EYE
	_help_label.text = mode_help + "\n\n" + HELP_GLOBAL


func _update_clock() -> void:
	_clock_label.text = "Tag %d  ·  %s" % [WorldClock.day, WorldClock.get_time_string()]


func _on_minute_changed(_hour: int, _minute: int) -> void:
	_update_clock()


func _on_day_changed(_day: int) -> void:
	_update_clock()


func _on_time_scale_changed(time_scale: float) -> void:
	_speed_label.visible = time_scale > 1.0
	_speed_label.text = "×%d" % int(time_scale)


func _on_view_mode_changed(mode: GameDefs.ViewMode) -> void:
	_view_mode = mode
	_update_help_text()


func _on_build_mode_changed(active: bool) -> void:
	_build_active = active
	_build_panel.visible = active
	if not active:
		_on_build_status_changed("")
	_update_help_text()


func _on_build_tool_changed(tool_id: StringName) -> void:
	_rail_button.set_pressed_no_signal(tool_id == &"rail")
	_remove_button.set_pressed_no_signal(tool_id == &"remove")


func _on_build_status_changed(text: String) -> void:
	_status_label.text = text
	_status_label.visible = text != ""


func _on_game_saved(_slot: String) -> void:
	show_toast("Spiel gespeichert")


func _on_game_loaded(_slot: String) -> void:
	show_toast("Spielstand geladen")
