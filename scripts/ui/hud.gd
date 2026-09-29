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
var _village_row: HBoxContainer
var _item_row: HFlowContainer
var _item_buttons: Dictionary[String, Button] = {}
var _cost_row: HBoxContainer
var _money_label: Label
var _day_value: Label
var _time_value: Label
var _bar_speed_label: Label
var _status_bar: Control
var _money_tween: Tween
var _shown_money := -1

const COIN_ICON := preload("res://assets/ui/icons/coin.svg")
const NOTEBOOK_ICON := preload("res://assets/ui/icons/notebook.svg")
const STATUS_BAR_ART := preload("res://assets/ui/hud_status_bar.png")

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
	# Zweite Zeile für die Dorf-Werkzeuge, darunter die Objekte der gewählten Kategorie
	_village_row = HBoxContainer.new()
	_village_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_village_row.add_theme_constant_override("separation", 6)
	_tool_row.add_sibling(_village_row)
	_item_row = HFlowContainer.new()
	_item_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_row.custom_minimum_size = Vector2(560, 0)
	_item_row.add_theme_constant_override("h_separation", 4)
	_item_row.add_theme_constant_override("v_separation", 4)
	_item_row.visible = false
	_village_row.add_sibling(_item_row)
	Events.village_items_changed.connect(_on_village_items_changed)
	# Baukosten des Objekts unter dem Mauszeiger (Icons, fehlendes rot)
	_cost_row = HBoxContainer.new()
	_cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_row.add_theme_constant_override("separation", 6)
	_cost_row.visible = false
	_item_row.add_sibling(_cost_row)
	Events.build_cost_changed.connect(_on_build_cost_changed)
	_build_money_display()
	for entry: Dictionary in InputConfig.BUILD_TOOLS:
		var button := Button.new()
		button.text = entry["label"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = tool_group
		button.tooltip_text = "Taste %s" % InputConfig.get_action_label(entry["action"])
		button.pressed.connect(Events.build_tool_requested.emit.bind(entry["id"]))
		if entry.get("group", "") == "village":
			_village_row.add_child(button)
		else:
			_tool_row.add_child(button)
		_tool_buttons[entry["id"]] = button

	# Fest-Banner und Interaktionshinweis (Etappe 10)
	var overlay := EventOverlay.new()
	overlay.name = "EventOverlay"
	add_child(overlay)
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
		var tool_name := String(_build_tool)
		_legend.show_mode(&"build_village" if tool_name.begins_with("village_") else StringName("build_" + tool_name))
	elif _view_mode == GameDefs.ViewMode.BIRD_EYE:
		_legend.show_mode(&"bird_eye")
	else:
		_legend.show_mode(&"explore")


func _update_clock() -> void:
	_clock_label.text = "Tag %d  ·  %s" % [WorldClock.day, WorldClock.get_time_string()]
	if _day_value:
		var day_text := "Tag %d" % WorldClock.day
		_day_value.text = day_text
		_day_value.add_theme_font_size_override("font_size", 68 if day_text.length() <= 5 else 56)
	if _time_value:
		_time_value.text = WorldClock.get_time_string()


func _on_minute_changed(_hour: int, _minute: int) -> void:
	_update_clock()


func _on_day_changed(_day: int) -> void:
	_update_clock()


func _on_time_scale_changed(time_scale: float) -> void:
	_speed_label.visible = time_scale > 1.0
	_speed_label.text = "×%d" % int(time_scale)
	if _bar_speed_label:
		_bar_speed_label.visible = time_scale > 1.0
		_bar_speed_label.text = "×%d" % int(time_scale)


func _on_view_mode_changed(mode: GameDefs.ViewMode) -> void:
	_view_mode = mode
	_update_legend()


func _on_build_mode_changed(active: bool) -> void:
	_build_active = active
	_build_panel.visible = active
	if not active:
		_on_build_status_changed("")
		_cost_row.visible = false
	_update_legend()


func _on_build_tool_changed(tool_id: StringName) -> void:
	_build_tool = tool_id
	_item_row.visible = String(tool_id).begins_with("village_")
	if not _item_row.visible:
		_cost_row.visible = false
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


## Der Referenzrahmen bleibt erhalten; Geld, Tag und Uhrzeit sind echte Live-Werte.
func _build_money_display() -> void:
	$Root/ClockPanel.visible = false
	_status_bar = Control.new()
	_status_bar.name = "PremiumStatusBar"
	_status_bar.size = Vector2(1410, 213)
	_status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_status_bar)
	var crop := AtlasTexture.new()
	crop.atlas = STATUS_BAR_ART
	crop.region = Rect2(130, 83, 1410, 213)
	var artwork := TextureRect.new()
	artwork.name = "StatusBarArtwork"
	artwork.texture = crop
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.size = _status_bar.size
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_bar.add_child(artwork)
	_money_label = _status_value("MoneyValue", Vector2(263, 58), Vector2(253, 105), 71)
	_day_value = _status_value("DayValue", Vector2(688, 58), Vector2(250, 105), 68)
	_time_value = _status_value("TimeValue", Vector2(1100, 58), Vector2(235, 105), 68)
	_bar_speed_label = _status_value("SpeedValue", Vector2(1217, 155), Vector2(112, 32), 20)
	_bar_speed_label.visible = false
	var book := Button.new()
	book.name = "NotebookButton"
	book.icon = NOTEBOOK_ICON
	book.expand_icon = true
	book.flat = true
	book.focus_mode = Control.FOCUS_NONE
	book.position = Vector2(1413, 82)
	book.size = Vector2(43, 43)
	book.tooltip_text = "Notizbuch (Taste %s)" % InputConfig.get_action_label(&"toggle_notebook")
	book.pressed.connect(Events.notebook_requested.emit.bind(""))
	_status_bar.add_child(book)
	_layout_status_bar()
	get_viewport().size_changed.connect(_layout_status_bar)
	Economy.money_changed.connect(_on_money_changed)
	_on_money_changed(Economy.money)


func _status_value(node_name: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var value := Label.new()
	value.name = node_name
	value.position = at
	value.size = dimensions
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
	value.add_theme_font_override("font", font)
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", Color("542a1b"))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_bar.add_child(value)
	return value


func _layout_status_bar() -> void:
	if _status_bar == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var viewport_factor := minf(viewport_size.x / 1672.0, viewport_size.y / 941.0)
	var factor := viewport_factor * 0.62
	_status_bar.scale = Vector2.ONE * factor
	_status_bar.position = Vector2((viewport_size.x - 1410.0 * factor) * 0.5, 28.0 * viewport_factor)
	var toast_top := _status_bar.position.y + 213.0 * factor + 12.0 * viewport_factor
	_toast_label.offset_top = toast_top
	_toast_label.offset_bottom = toast_top + 36.0 * viewport_factor


## Der Betrag zählt weich zum neuen Wert (kein hektisches Springen).
func _on_money_changed(money: int) -> void:
	if _shown_money < 0:
		_shown_money = money
		_set_money_text(money)
		return
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()
	_money_tween = create_tween()
	_money_tween.tween_method(func(value: float) -> void:
		_shown_money = roundi(value)
		_set_money_text(_shown_money), float(_shown_money), float(money), 0.6)


func _set_money_text(amount: int) -> void:
	var amount_text := Economy.format_money(amount, false)
	_money_label.text = amount_text
	_money_label.add_theme_font_size_override("font_size", 71 if amount_text.length() <= 6 else (59 if amount_text.length() <= 8 else 48))


func get_money_text() -> String:
	return _money_label.text


func _on_build_cost_changed(cost: Dictionary) -> void:
	for child in _cost_row.get_children():
		child.queue_free()
	_cost_row.visible = not cost.is_empty() and _build_active
	if cost.is_empty():
		return
	var missing := Economy.get_missing(cost)
	var title := Label.new()
	title.text = "Kosten:"
	title.add_theme_font_size_override("font_size", 14)
	_cost_row.add_child(title)
	var entries: Array = []
	if int(cost.get("money", 0)) > 0:
		entries.append([COIN_ICON, int(cost["money"]), missing.has("money")])
	for goods in Economy.get_goods():
		if int(cost.get(goods.id, 0)) > 0:
			entries.append([goods.icon, int(cost[goods.id]), missing.has(goods.id)])
	for entry: Array in entries:
		var icon := TextureRect.new()
		icon.texture = entry[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(22, 22)
		_cost_row.add_child(icon)
		var amount := Label.new()
		amount.text = str(entry[1])
		amount.add_theme_font_size_override("font_size", 14)
		amount.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if entry[2] else Color(0.98, 0.94, 0.86))
		_cost_row.add_child(amount)
	if cost.size() == 0 or entries.is_empty():
		title.text = "Kostenlos"


## Objekte der gewählten Dorf-Kategorie als kleine Buttons.
func _on_village_items_changed(_category: StringName, items: Array[String], selected: String) -> void:
	for child in _item_row.get_children():
		child.queue_free()
	_item_buttons.clear()
	var group := ButtonGroup.new()
	for item_id in items:
		var button := Button.new()
		button.text = VillageCatalog.get_label(item_id)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_group = group
		button.add_theme_font_size_override("font_size", 13)
		button.button_pressed = item_id == selected
		var cost_text := Economy.format_cost(VillageCatalog.get_cost(item_id, 10.0 if VillageCatalog.is_line(item_id) else 0.0))
		button.tooltip_text = ("Kosten%s: %s" % [" je 10 m" if VillageCatalog.is_line(item_id) else "", cost_text]) if cost_text != "" else "kostenlos"
		button.pressed.connect(Events.village_item_requested.emit.bind(item_id))
		_item_row.add_child(button)
		_item_buttons[item_id] = button
	_item_row.visible = _build_active and String(_build_tool).begins_with("village_")
