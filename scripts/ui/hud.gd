## Schlankes HUD: Uhrzeit, kurze Hinweise, dauerhafte Tastenlegende (unten
## rechts) und im Build-Mode eine kleine Werkzeugleiste (unten links).
##
## Das HUD hört nur auf Signale (WorldClock, Events) und kennt keine anderen
## Spielsysteme direkt. Werkzeugwahl per Klick läuft über
## Events.build_tool_requested.
class_name GameHUD
extends CanvasLayer

var _view_mode := GameDefs.ViewMode.EXPLORE
var _build_active := false
var _build_tool: StringName = &"rail"
var _tool_buttons: Dictionary[StringName, Button] = {}
var _toast_tween: Tween

@onready var _clock_label: Label = %ClockLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _build_panel: PanelContainer = %BuildPanel
@onready var _tool_row: HBoxContainer = %ToolRow
@onready var _status_label: Label = %StatusLabel
@onready var _legend: KeyLegend = %Legend
@onready var _toast_label: Label = %ToastLabel
@onready var _follow_label: Label = %FollowLabel

var _followed: Node


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
	Events.followed_train_changed.connect(_on_followed_train_changed)

	var tool_group := ButtonGroup.new()
	for entry: Dictionary in InputConfig.BUILD_TOOLS:
		var button := Button.new()
		button.text = entry["label"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = tool_group
		button.tooltip_text = "Taste %s" % InputConfig.get_action_label(entry["action"])
		button.pressed.connect(Events.build_tool_requested.emit.bind(entry["id"]))
		_tool_row.add_child(button)
		_tool_buttons[entry["id"]] = button

	_toast_label.modulate.a = 0.0
	_update_clock()
	_on_time_scale_changed(WorldClock.time_scale)
	_legend.set_expanded(GameSettings.legend_expanded)
	_update_legend()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		_legend.set_expanded(not _legend.is_expanded())
		GameSettings.set_legend_expanded(_legend.is_expanded())
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _followed and is_instance_valid(_followed) and _followed.has_method("get_info_text"):
		_follow_label.text = _followed.get_info_text()
	elif _follow_label.visible:
		_follow_label.visible = false


func _on_followed_train_changed(train: Node) -> void:
	_followed = train
	_follow_label.visible = train != null


## Zeigt kurz eine Nachricht oben in der Bildmitte.
func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func get_legend() -> KeyLegend:
	return _legend


## Legende passend zum aktuellen Modus (Erkunden, Vogelperspektive, Werkzeug).
func _update_legend() -> void:
	if _build_active:
		_legend.show_mode(StringName("build_" + String(_build_tool)))
	elif _view_mode == GameDefs.ViewMode.BIRD_EYE:
		_legend.show_mode(&"bird_eye")
	else:
		_legend.show_mode(&"explore")


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
	_update_legend()


func _on_build_mode_changed(active: bool) -> void:
	_build_active = active
	_build_panel.visible = active
	if not active:
		_on_build_status_changed("")
	_update_legend()


func _on_build_tool_changed(tool_id: StringName) -> void:
	_build_tool = tool_id
	for id: StringName in _tool_buttons:
		_tool_buttons[id].set_pressed_no_signal(id == tool_id)
	_update_legend()


func _on_build_status_changed(text: String) -> void:
	_status_label.text = text
	_status_label.visible = text != ""


func _on_game_saved(_slot: String) -> void:
	show_toast("Spiel gespeichert")


func _on_game_loaded(_slot: String) -> void:
	show_toast("Spielstand geladen")
