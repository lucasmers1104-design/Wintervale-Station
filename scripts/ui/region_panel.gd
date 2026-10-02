## Das Reisebuch (Taste P): Epochen, Orte & Bahnhöfe, Fuhrpark und Linien.
##
## Gestaltung wie die Menüseiten: Pergament im verschneiten Holzrahmen,
## Messingknöpfe, Serifenschrift, eigene Symbole (assets/ui/journey). Die Seite
## liegt unter der Statusleiste, damit Geld, Tag und Uhr sichtbar bleiben.
## Solange das Buch offen ist, steht die Weltuhr still.
##
## Seiten: "epochs" (Reise), "stations" (Orte), "station" (ein Bahnhof),
## "fleet" (Fuhrpark mit drehbarer 3D-Vorschau), "lines" (Linien), "debug" (F8).
class_name RegionPanel
extends CanvasLayer

const S = preload("res://scripts/ui/journey_style.gd")
const BOARD_POS := Vector2(96.0, 116.0)
const BOARD_SIZE := Vector2(1480.0, 806.0)
const TABS := [
	{"id": "epochs", "text": "Reise", "icon": "journey"},
	{"id": "stations", "text": "Orte", "icon": "station"},
	{"id": "fleet", "text": "Fuhrpark", "icon": "trips"},
	{"id": "lines", "text": "Linien", "icon": "lines"},
]
const TITLES := {
	"epochs": ["Unsere Eisenbahnreise", "Jede Epoche entsteht aus deiner Bahn"],
	"stations": ["Orte an deiner Strecke", "Hier wächst Wintervale"],
	"station": ["Bahnhof & Nachbarschaft", ""],
	"fleet": ["Dein Fuhrpark", "Züge auswählen und auf die Strecke schicken"],
	"lines": ["Verbindungen", "Züge pendeln zwischen zwei Orten"],
	"debug": ["Entwicklungswerkzeuge", "F8 · nur im Entwicklungsbuild"],
}
const METRIC_ICONS := {"passengers": "passengers", "goods": "goods", "services": "trips", "connected": "station", "rail_length": "rail", "population": "population", "lines": "lines"}

var region: RegionRailway
var _shade: ColorRect
var _canvas: Control
var _panel: Control
var _content: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _subtitle: Label
var _hint_row: HBoxContainer
var _hint_label: Label
var _tab_buttons := {}
var _launcher: HBoxContainer
var _epoch_button: Button
var _fleet_button: Button
var _assign_button: Button
var _page := "epochs"
var _station_id := 0
var _selected_train := "diesel_heritage"
var _selected_epoch := 0
var _previous_pause := false
var _was_captured := false
var _preview: Node3D
var _viewport: SubViewport
var _preview_camera: Camera3D
var _preview_length := 16.0
var _debug := false
var _refresh_pending := false


func _ready() -> void:
	layer = 65
	_shade = ColorRect.new()
	_shade.color = Color(0.07, 0.05, 0.09, 0.42)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	_shade.hide()
	add_child(_shade)
	_canvas = Control.new()
	_canvas.size = S.DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = S.make_theme()
	add_child(_canvas)
	_build_launcher()
	_build_board()
	get_viewport().size_changed.connect(_rescale)
	_rescale()
	region.changed.connect(_schedule_refresh)
	region.progression.changed.connect(_schedule_refresh)
	region.progression.epoch_unlocked.connect(_on_unlock)
	Events.region_station_requested.connect(func(id: int) -> void:
		_station_id = id
		open_page("station"))
	_update_launcher()


# --- Aufbau ----------------------------------------------------------------

## Zwei kleine Holzschilder oben rechts: Reise und Fuhrpark.
func _build_launcher() -> void:
	_launcher = HBoxContainer.new()
	_launcher.add_theme_constant_override("separation", 10)
	_launcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_launcher)
	_launcher.theme = _canvas.theme
	_epoch_button = _sign_button("Reise · Epoche 1", "journey", func() -> void: open_page("epochs"))
	_fleet_button = _sign_button("Fuhrpark", "trips", func() -> void: open_page("fleet"))


func _sign_button(text: String, icon_name: String, action: Callable) -> Button:
	var sign := Button.new()
	sign.text = text
	sign.icon = S.icon(icon_name)
	sign.focus_mode = Control.FOCUS_NONE
	sign.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sign.tooltip_text = "Reisebuch (Taste %s)" % InputConfig.get_action_label(&"region_overview")
	var base := S.flat(Color("f3dfb8"), S.WOOD, 4, 12, 14.0)
	base.shadow_color = Color(0.1, 0.05, 0.02, 0.35)
	base.shadow_size = 5
	base.shadow_offset = Vector2(0, 3)
	base.content_margin_top = 7
	base.content_margin_bottom = 7
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color("fbeccb")
	hover.border_color = Color("7a4a2a")
	sign.add_theme_stylebox_override("normal", base)
	sign.add_theme_stylebox_override("hover", hover)
	sign.add_theme_stylebox_override("pressed", hover)
	sign.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	sign.add_theme_font_override("font", S.serif())
	sign.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		sign.add_theme_color_override(state, Color("542a1b"))
	sign.add_theme_constant_override("icon_max_width", 30)
	sign.add_theme_constant_override("h_separation", 8)
	sign.pressed.connect(action)
	sign.pressed.connect(S.play_page)
	var snow := S.SnowCap.new(text.length())
	snow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	snow.offset_top = -7
	snow.offset_bottom = 5
	snow.offset_left = 4
	snow.offset_right = -4
	sign.add_child(snow)
	_launcher.add_child(sign)
	return sign


func _build_board() -> void:
	_panel = Control.new()
	_panel.name = "Board"
	_panel.position = BOARD_POS
	_panel.size = BOARD_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_panel)
	_panel.add_child(S.frame(BOARD_SIZE))
	var header := HBoxContainer.new()
	header.position = Vector2(96, 44)
	header.size = Vector2(BOARD_SIZE.x - 192 - 56, 70)
	header.add_theme_constant_override("separation", 14)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(header)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", -2)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	_title = S.label("Unsere Eisenbahnreise", 40, S.INK)
	heading.add_child(_title)
	_subtitle = S.label("", 19, S.INK_SOFT)
	heading.add_child(_subtitle)
	_hint_row = HBoxContainer.new()
	_hint_row.add_theme_constant_override("separation", 8)
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.visible = false
	heading.add_child(_hint_row)
	_hint_row.add_child(S.icon_rect(S.icon("conductor"), 34))
	_hint_label = S.label("", 18, S.RED.darkened(0.15))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_row.add_child(_hint_label)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_END
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tabs)
	for tab: Dictionary in TABS:
		var id := String(tab["id"])
		var button := S.button(tabs, String(tab["text"]), open_page.bind(id), false, String(tab["icon"]), 20)
		button.custom_minimum_size = Vector2(150, 52)
		_tab_buttons[id] = button
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Schließen (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var round := S.flat(S.WOOD, S.GOLD, 3, 40, 0.0)
	var round_hover := S.flat(Color("7a4a2a"), S.GOLD_LIGHT, 3, 40, 0.0)
	close_button.add_theme_stylebox_override("normal", round)
	close_button.add_theme_stylebox_override("hover", round_hover)
	close_button.add_theme_stylebox_override("pressed", round_hover)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.add_theme_font_override("font", S.serif())
	close_button.add_theme_font_size_override("font_size", 34)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		close_button.add_theme_color_override(state, S.PAPER_LIGHT)
	close_button.position = Vector2(BOARD_SIZE.x - 82, 22)
	close_button.size = Vector2(54, 54)
	close_button.pressed.connect(close)
	_panel.add_child(close_button)
	var line := S.Divider.new()
	line.position = Vector2(96, 124)
	line.size = Vector2(BOARD_SIZE.x - 192, 14)
	_panel.add_child(line)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(92, 146)
	_scroll.size = Vector2(BOARD_SIZE.x - 184, BOARD_SIZE.y - 146 - 88)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	_scroll.add_child(_content)
	_panel.hide()


func _rescale() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := S.screen_factor(viewport)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (viewport - S.DESIGN_SIZE * factor) * 0.5
	_launcher.scale = Vector2.ONE * factor
	_launcher.reset_size()
	_launcher.position = Vector2(viewport.x - (_launcher.size.x + 24.0) * factor, 24.0 * factor)


# --- Öffnen / Schließen ----------------------------------------------------

func is_open() -> bool:
	return _panel.visible


func get_page() -> String:
	return _page if _panel.visible else ""


## Ziel für Tutorial-Hinweise (Knopf "Zug einsetzen", Fuhrpark-Schild …).
func get_tutorial_target(id: String) -> Control:
	match id:
		"fleet_sign":
			return _fleet_button
		"journey_sign":
			return _epoch_button
		"assign":
			return _assign_button if is_instance_valid(_assign_button) and _panel.visible else null
		"fleet_tab":
			return _tab_buttons.get("fleet")
	return null


## Scrollt ein Tutorial-Ziel (z.B. "assign") einmal pro Seitenaufbau ins Bild.
func reveal_tutorial_target(id: String) -> void:
	var target := get_tutorial_target(id)
	if target and not target.has_meta("revealed"):
		target.set_meta("revealed", true)
		_scroll.ensure_control_visible.call_deferred(target)


## Satz der Tutorial-Begleiterin anstelle des Untertitels ("" = Untertitel).
func set_tutorial_hint(text: String) -> void:
	if _hint_label.text == text and _hint_row.visible == (text != ""):
		return
	_hint_label.text = text
	_hint_row.visible = text != ""
	_subtitle.visible = text == ""


func open_page(page: String) -> void:
	if not _panel.visible:
		_previous_pause = WorldClock.paused
		WorldClock.paused = true
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_panel.show()
		_shade.show()
		_panel.modulate.a = 0.0
		_panel.position = BOARD_POS + Vector2(0, 18)
		var tween := _panel.create_tween().set_parallel()
		tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
		tween.tween_property(_panel, "position", BOARD_POS, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if page == "epochs" and _page != "epochs":
		_selected_epoch = 0
	_page = page
	_refresh()


func close() -> void:
	if not _panel.visible:
		return
	_panel.hide()
	_shade.hide()
	WorldClock.paused = _previous_pause
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_preview = null
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_assign_button = null


func _exit_tree() -> void:
	if _panel and _panel.visible:
		WorldClock.paused = _previous_pause


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"region_overview"):
		if _panel.visible:
			close()
		else:
			open_page("epochs")
	elif _panel.visible and event.is_action_pressed(&"build_cancel"):
		close()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_debug = not _debug
		open_page("debug" if _debug else "epochs")
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _panel.visible and is_instance_valid(_preview):
		_preview.rotation.y += delta * 0.12
		_frame_preview()


func _schedule_refresh() -> void:
	_update_launcher()
	if _panel.visible and not _refresh_pending:
		_refresh_pending = true
		_refresh.call_deferred()


func _update_launcher() -> void:
	_epoch_button.text = "Reise · Epoche %d" % region.progression.epoch
	_launcher.reset_size()
	_rescale()


# --- Seiten ----------------------------------------------------------------

func _refresh() -> void:
	_refresh_pending = false
	if not _panel.visible:
		return
	var scroll_back := _scroll.scroll_vertical
	_preview = null
	_viewport = null
	_assign_button = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var titles: Array = TITLES.get(_page, ["Wintervale", ""])
	_title.text = titles[0]
	_subtitle.text = titles[1]
	for id: String in _tab_buttons:
		var active: bool = id == _page or (id == "stations" and _page == "station")
		S.style_button(_tab_buttons[id], active, 20)
	match _page:
		"epochs": _epochs()
		"stations": _stations()
		"station": _station()
		"fleet": _fleet()
		"lines": _lines()
		"debug": _debug_tools()
	_scroll.scroll_vertical = scroll_back


func _row(parent: Node, separation := 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


func _epochs() -> void:
	var progress := region.progression
	var current := progress.epoch
	if _selected_epoch <= 0:
		_selected_epoch = mini(current + 1, EpochCatalog.all().size())
	var timeline := EpochTimeline.new()
	timeline.current = current
	timeline.selected = _selected_epoch
	timeline.custom_minimum_size = Vector2(0, 196)
	timeline.selected_changed.connect(func(level: int) -> void:
		_selected_epoch = level
		S.play_page()
		_refresh())
	_content.add_child(timeline)
	var data := EpochCatalog.epoch(_selected_epoch)
	var row := _row(_content, 20)
	var about := S.card(row, true)
	about.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.get_parent().size_flags_stretch_ratio = 1.0
	var state := "Erreicht" if _selected_epoch < current else ("Deine Epoche" if _selected_epoch == current else "Vor dir")
	about.add_child(S.label("Epoche %d · %s" % [_selected_epoch, state], 18, S.GOLD.darkened(0.25)))
	about.add_child(S.label(String(data["name"]), 34, S.INK))
	var train := EpochCatalog.train(data["trains"][0])
	var unlocks := _row(about, 18)
	var station_box := _row(unlocks, 10)
	station_box.add_child(S.icon_rect(S.icon("station"), 46))
	var station_text := VBoxContainer.new()
	station_text.add_theme_constant_override("separation", -4)
	station_box.add_child(station_text)
	station_text.add_child(S.label("Bahnhof", 15, S.INK_SOFT))
	station_text.add_child(S.label(String(data["station"]), 22))
	var train_box := _row(unlocks, 10)
	train_box.add_child(S.icon_rect(S.icon("trips"), 46))
	var train_text := VBoxContainer.new()
	train_text.add_theme_constant_override("separation", -4)
	train_box.add_child(train_text)
	train_text.add_child(S.label("Neuer Zug", 15, S.INK_SOFT))
	train_text.add_child(S.label(train.display_name, 22))
	var livery := LiveryStrip.new()
	livery.type = train
	livery.custom_minimum_size = Vector2(0, 74)
	about.add_child(livery)
	var features := HFlowContainer.new()
	features.add_theme_constant_override("h_separation", 8)
	features.add_theme_constant_override("v_separation", 8)
	about.add_child(features)
	for feature: String in data["features"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", S.flat(Color("efe0bf"), Color("cfb07c"), 2, 16, 12.0))
		chip.add_child(S.label(feature, 17, S.INK))
		features.add_child(chip)
	var goals := S.card(row)
	goals.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals.get_parent().size_flags_stretch_ratio = 1.15
	if _selected_epoch <= 1:
		goals.add_child(S.label("Der Anfang", 26))
		goals.add_child(S.paragraph("Gleise, Holz-Haltepunkte und der alte Dieseltriebwagen stehen dir von Beginn an zur Verfügung. Alles Weitere entsteht aus deinem Verkehr."))
		return
	goals.add_child(S.label("Erreicht" if _selected_epoch <= current else "So erreichst du diese Epoche", 26))
	for requirement in progress.requirements(_selected_epoch):
		_requirement_row(goals, requirement, _selected_epoch <= current)
	if _selected_epoch > current:
		var tip := _next_tip(_selected_epoch)
		if tip != "":
			var hint := _row(goals, 10)
			hint.add_child(S.icon_rect(S.icon("journey"), 30))
			hint.add_child(S.paragraph(tip, 18, S.INK_SOFT))


func _requirement_row(parent: Node, requirement: Dictionary, reached: bool) -> void:
	var row := _row(parent, 12)
	var met := reached or bool(requirement["met"])
	row.add_child(S.icon_rect(S.icon(METRIC_ICONS.get(String(requirement["key"]), "journey")), 38))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var top := _row(texts, 8)
	var caption := S.label(String(requirement["label"]).replace(" (m)", ""), 19, S.INK)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(caption)
	var unit := " m" if String(requirement["key"]) == "rail_length" else ""
	var value := mini(int(requirement["value"]), int(requirement["target"])) if met else int(requirement["value"])
	top.add_child(S.label("%d / %d%s" % [value, int(requirement["target"]), unit], 19, S.GREEN if met else S.INK_SOFT))
	var bar := S.TrackBar.new(float(requirement["target"]) if reached else float(requirement["value"]), float(requirement["target"]))
	bar.custom_minimum_size = Vector2(200, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(bar)
	if met:
		row.add_child(S.icon_rect(S.icon("check"), 30))


## Ein freundlicher Satz zum ersten offenen Ziel.
func _next_tip(level: int) -> String:
	for requirement in region.progression.requirements(level):
		if bool(requirement["met"]):
			continue
		var missing := int(ceil(float(requirement["target"]) - float(requirement["value"])))
		match String(requirement["key"]):
			"passengers": return "Noch %d Fahrgäste: Jede Ankunft mit Reisenden zählt. Mehr Einwohner bringen größere Reisegruppen." % missing
			"services": return "Noch %d erfolgreiche Fahrten – deine Züge pendeln von selbst." % missing
			"connected": return "Verbinde %d weitere Orte: Gleis verlängern, Haltepunkt bauen (H) und eine Linie anlegen." % missing
			"rail_length": return "Noch %d m Gleis bauen (B)." % missing
			"population": return "Noch %d Einwohner: Häuser entstehen von selbst an Orten mit regem Bahnverkehr." % missing
			"lines": return "Noch %d funktionierende Linien – im Fuhrpark einen Zug auf eine neue Verbindung schicken." % missing
			"goods": return "Noch %d gelieferte Güter – ein Güterzug beliefert dein Lager." % missing
	return "Alle Bedingungen erfüllt – die neue Epoche beginnt gleich."


func _stations() -> void:
	if region.stations.is_empty():
		var empty := S.card(_content)
		empty.add_child(S.label("Noch kein Ort", 28))
		empty.add_child(S.paragraph("Die Landschaft wartet auf deinen ersten Haltepunkt. Baue Gleise (B) und wähle dann den Haltepunkt (H)."))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	_content.add_child(grid)
	for portal in region.portals:
		var tunnel := S.card(grid, true)
		tunnel.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tunnel_head := _row(tunnel, 12)
		tunnel_head.add_child(S.icon_rect(S.icon("trips"), 56))
		var tunnel_names := VBoxContainer.new()
		tunnel_names.add_theme_constant_override("separation", -4)
		tunnel_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tunnel_head.add_child(tunnel_names)
		tunnel_names.add_child(S.label(portal.station_name, 30))
		tunnel_names.add_child(S.label("Tunnel in die weite Welt", 17, S.INK_SOFT))
		tunnel.add_child(S.paragraph("Von hier kommen Züge, Gäste und neue Familien. %d Fahrgäste sind schon hierher gereist." % portal.passenger_total, 17))
	for station in region.stations:
		var card := S.card(grid)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := _row(card, 12)
		head.add_child(S.icon_rect(S.icon("station"), 56))
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -4)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(names)
		names.add_child(S.label(station.station_name, 30))
		names.add_child(S.label("Stufe %d · %s" % [station.level, EpochCatalog.epoch(station.level)["station"]], 17, S.INK_SOFT))
		head.add_child(LevelPips.make(station.level))
		var stats := _row(card, 26)
		S.stat(stats, "population", str(station.population), "Einwohner")
		S.stat(stats, "passengers", str(station.passenger_total), "Fahrgäste")
		S.stat(stats, "trips", str(station.services), "Ankünfte")
		var open_button := S.button(card, "Bahnhof öffnen  ›", func() -> void:
			_station_id = station.station_id
			open_page("station"), false, "", 19)
		open_button.size_flags_horizontal = Control.SIZE_SHRINK_END


func _station() -> void:
	var station := region.station_by_id(_station_id)
	if station == null:
		_page = "stations"
		_stations()
		return
	_subtitle.text = "Stufe %d · %s" % [station.level, EpochCatalog.epoch(station.level)["station"]]
	var head := _row(_content, 16)
	head.add_child(S.icon_rect(S.icon("station"), 70))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(S.label(station.station_name, 40))
	names.add_child(LevelPips.make(station.level))
	var edit := LineEdit.new()
	edit.text = station.station_name
	edit.max_length = 32
	edit.custom_minimum_size = Vector2(300, 50)
	edit.add_theme_font_size_override("font_size", 20)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(edit)
	var rename := func() -> void:
		if not station.rename_station(edit.text):
			Events.notification_requested.emit("Dieser Name ist schon vergeben")
	edit.text_submitted.connect(func(_text: String) -> void: rename.call())
	var rename_button := S.button(head, "Umbenennen", rename, false, "pencil", 19)
	rename_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stats_card := S.card(_content)
	var stats := _row(stats_card, 48)
	S.stat(stats, "population", str(station.population), "Einwohner")
	S.stat(stats, "passengers", str(station.passenger_total), "beförderte Gäste")
	S.stat(stats, "trips", str(station.services), "Ankünfte")
	S.stat(stats, "goods", str(station.delivered_goods), "gelieferte Güter")
	S.stat(stats, "population", str(station.house_ids.size()), "Häuser")
	if not station.waiting_houses.is_empty():
		var waiting := _row(stats_card, 10)
		waiting.add_child(S.icon_rect(S.icon("passengers"), 30))
		var served := false
		for line in region.lines:
			var other := station_other_end(line, station.station_id)
			served = served or (other != null and other.is_portal())
		waiting.add_child(S.paragraph(("%d Familien sitzen schon im Zug aus dem Tunnel." if served else "%d Familien warten im Tunnel auf einen Zug – richte eine Linie vom Tunnel hierher ein.") % station.waiting_houses.size(), 17, S.GREEN if served else S.RED.lightened(0.1)))
	var row := _row(_content, 18)
	var upgrade_card := S.card(row, true)
	upgrade_card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := _row(upgrade_card, 10)
	title_row.add_child(S.icon_rect(S.icon("upgrade"), 40))
	if station.level >= 6:
		title_row.add_child(S.label("Vollständig ausgebaut", 26))
		upgrade_card.add_child(S.paragraph("Der Hauptbahnhof ist das Herz der Region."))
	else:
		var next := EpochCatalog.epoch(station.level + 1)
		title_row.add_child(S.label("Ausbau: %s" % next["station"], 26))
		upgrade_card.add_child(S.paragraph("Platz für %d Bahnsteige · längere Züge halten hier." % int(next["platforms"])))
		var reason := station.upgrade_reason()
		var action_row := _row(upgrade_card, 14)
		var upgrade := S.button(action_row, "Ausbauen · %s" % Economy.format_money(int(next["cost"])), func() -> void:
			if station.upgrade():
				S.play_chime()
			_refresh(), true, "upgrade", 20)
		upgrade.disabled = reason != ""
		upgrade.tooltip_text = reason
		var status := S.paragraph(reason if reason != "" else "Bereit für den nächsten Schritt", 18, S.RED.lightened(0.1) if reason != "" else S.GREEN)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action_row.add_child(status)
	var platform_card := S.card(row)
	platform_card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var platform_title := _row(platform_card, 10)
	platform_title.add_child(S.icon_rect(S.icon("platform"), 40))
	var possible := int(EpochCatalog.epoch(station.level)["platforms"])
	platform_title.add_child(S.label("Bahnsteige · %d von %d" % [station.platform_tracks.size() + 1, possible], 26))
	if station.get_stops().size() < possible:
		platform_card.add_child(S.paragraph("Ein weiteres Gleis neben dem Bahnhof bauen, dann den Bahnsteig daneben setzen."))
		S.button(platform_card, "Bahnsteig anlegen · %s" % Economy.format_money(120), func() -> void:
			close()
			var build := region.get_parent().get_node("BuildMode") as BuildMode
			build.set_active(true)
			build.select_tool(&"station")
			(build.get_tool(&"station") as StationBuildTool).expand_station_id = station.station_id, false, "platform", 19)
	else:
		platform_card.add_child(S.paragraph("Mehr Bahnsteige gibt es mit dem nächsten Ausbau." if station.level < 6 else "Alle Bahnsteige sind angelegt."))
	platform_card.add_child(S.paragraph("Abreißen: Baumodus (B) → Entfernen (%s)" % InputConfig.get_action_label(&"build_tool_remove"), 16, S.INK_FADED))
	var served := false
	for line in region.lines:
		if int(line["a"]) == station.station_id or int(line["b"]) == station.station_id:
			if not served:
				_content.add_child(S.label("Linien ab %s" % station.station_name, 26))
				served = true
			_line_card(line)
	S.button(_content, "Neue Verbindung planen  ›", open_page.bind("lines"), false, "lines", 20).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _fleet() -> void:
	var columns := _row(_content, 22)
	var shelf := ScrollContainer.new()
	shelf.custom_minimum_size = Vector2(420, 560)
	shelf.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(shelf)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	shelf.add_child(list)
	for id in EpochCatalog.TRAIN_IDS:
		list.add_child(_train_tile(id))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	columns.add_child(detail)
	var type := EpochCatalog.train(_selected_train)
	var unlocked := region.progression.is_train_unlocked(_selected_train)
	var head := _row(detail, 12)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(S.label(type.display_name, 34))
	var assigned := 0
	for line in region.lines:
		assigned += 1 if line["train"] == _selected_train else 0
	var status := "Sonderzug" if type.special else ("Freigeschaltet" if unlocked else "Ab Epoche %d" % type.required_epoch)
	names.add_child(S.label("%s · %s%s" % [type.service_role, status, " · %d Linien" % assigned if assigned > 0 else ""], 18, S.INK_SOFT))
	if not unlocked:
		head.add_child(S.icon_rect(S.icon("lock"), 44))
	_train_preview(detail, type)
	var stats := _row(detail, 34)
	S.stat(stats, "speed", "%d km/h" % int(type.max_speed_kmh), "Höchstgeschwindigkeit")
	if type.passenger_capacity > 0:
		S.stat(stats, "seat", str(type.passenger_capacity), "Plätze")
	if type.cargo_capacity > 0:
		S.stat(stats, "goods", str(type.cargo_capacity), "Gütereinheiten")
	S.stat(stats, "cars", str(type.consist.size()), "Fahrzeuge")
	S.stat(stats, "station", "Stufe %d" % type.required_station_level, "Bahnhof nötig")
	if unlocked:
		_line_form(detail, _selected_train)
	else:
		var locked := S.card(detail)
		locked.add_child(S.paragraph("Diese Reise liegt noch vor dir. Mit Epoche %d kommt dieser Zug in deinen Fuhrpark – deine bisherigen Züge bleiben im Einsatz." % type.required_epoch))


## Zug im Regal: Lackierungs-Silhouette, Name, Status; gewählter Zug in Gold.
func _train_tile(id: String) -> Button:
	var type := EpochCatalog.train(id)
	var unlocked := region.progression.is_train_unlocked(id)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0, 92)
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var selected := id == _selected_train
	var base := S.flat(Color("fff6dc") if selected else S.PAPER_LIGHT, S.GOLD if selected else Color("d6bd92"), 3 if selected else 2, 12, 10.0)
	var hover := S.flat(Color("fff8e6"), S.GOLD, 2, 12, 10.0)
	tile.add_theme_stylebox_override("normal", base)
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", hover)
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tile.pressed.connect(func() -> void:
		_selected_train = id
		S.play_page()
		_refresh())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)
	var strip := LiveryStrip.new()
	strip.type = type
	strip.compact = true
	strip.custom_minimum_size = Vector2(96, 0)
	strip.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	row.add_child(strip)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var caption := S.label(type.display_name, 19, S.INK if unlocked else S.INK_FADED)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(caption)
	var sub := "Sonderzug" if type.special else ("Bereit" if unlocked else "Epoche %d" % type.required_epoch)
	texts.add_child(S.label(sub, 16, S.GREEN if unlocked and not type.special else S.INK_SOFT))
	if not unlocked:
		row.add_child(S.icon_rect(S.icon("lock"), 28))
	return tile


func _train_preview(parent: Node, type: TrainType) -> void:
	var window := PanelContainer.new()
	var frame_style := S.flat(Color("2b2733"), S.WOOD, 6, 14, 0.0)
	frame_style.shadow_color = Color(0.2, 0.1, 0.05, 0.3)
	frame_style.shadow_size = 6
	window.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(window)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(0, 236)
	container.stretch = true
	container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	container.tooltip_text = "Mit gedrückter Maustaste drehen"
	window.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(900, 280)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)
	_preview = Node3D.new()
	_viewport.add_child(_preview)
	var factory := region.dispatcher
	var length := EpochCatalog.consist_length(type)
	_preview_length = length
	var offset := -length / 2
	for i in type.consist.size():
		var car := TrainCar.new()
		_preview.add_child(car)
		car.build(type.consist[i], type, i == 0, i == type.consist.size() - 1, factory._materials, i)
		car.position.z = offset + car.length / 2
		offset += car.length + TrainMeshes.COUPLING_GAP
		car.set_cabin_light(0.85)
		car.set_snow_spray(0)
		if car._exhaust:
			car._exhaust.emitting = false
	_preview.add_child(_preview_track(length + 6.0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -32, 0)
	light.light_energy = 1.15
	light.light_color = Color(1.0, 0.9, 0.76)
	light.shadow_enabled = true
	_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.72, 0.76, 1.0)
	_viewport.add_child(fill)
	var camera := Camera3D.new()
	_preview_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = length * 0.85 + 10
	_viewport.add_child(camera)
	camera.position = Vector3(length * 0.65, length * 0.10 + 3, -length * 0.20)
	camera.look_at(Vector3(0, 2.0, 0))
	_frame_preview()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("2f2d3b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e6dccb")
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_viewport.add_child(environment)
	container.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and is_instance_valid(_preview):
			_preview.rotation.y += event.relative.x * 0.012)


## Kurzes Schaugleis unter dem Vorschauzug (Schotter, Schwellen, Schienen).
func _preview_track(length: float) -> MeshInstance3D:
	var st := TrainMeshes._new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.12, 0), Vector3(3.6, 0.24, length), Color(0.55, 0.5, 0.47))
	var count := int(length / 0.65)
	for i in count:
		LowPolyBuilder.add_box(st, Vector3(0, 0.29, -length / 2 + (i + 0.5) * length / count), Vector3(2.5, 0.12, 0.26), Color(0.42, 0.29, 0.19))
	for side: float in [-0.7175, 0.7175]:
		LowPolyBuilder.add_box(st, Vector3(side, 0.41, 0), Vector3(0.08, 0.13, length), Color(0.55, 0.56, 0.58))
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position.y = TrainCar.RAIL_TOP - 0.475
	return mesh


func _frame_preview() -> void:
	if not is_instance_valid(_preview_camera) or not is_instance_valid(_viewport) or not is_instance_valid(_preview):
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for x: float in [-1.6, 1.6]:
		for y: float in [0, 4.4]:
			for z: float in [-_preview_length / 2, _preview_length / 2]:
				var point := _preview_camera.to_local(_preview.to_global(Vector3(x, y, z)))
				minimum = minimum.min(Vector2(point.x, point.y))
				maximum = maximum.max(Vector2(point.x, point.y))
	var aspect := float(_viewport.size.x) / maxf(1, _viewport.size.y)
	var extent := maximum - minimum
	_preview_camera.size = maxf(extent.x, extent.y * aspect) * 1.1


func _lines() -> void:
	_line_form(_content, _selected_train)
	if region.lines.is_empty():
		_content.add_child(S.paragraph("Noch keine Linie. Wähle oben zwei Orte und einen Zug.", 19))
	for line in region.lines:
		_line_card(line)


func _line_form(parent: Node, train_id: String) -> void:
	var form := S.card(parent, true)
	var title := _row(form, 10)
	title.add_child(S.icon_rect(S.icon("lines"), 40))
	title.add_child(S.label("Zug auf die Strecke schicken", 26))
	if region.stations.is_empty():
		form.add_child(S.paragraph("Für eine Verbindung brauchst du einen Haltepunkt am Gleis, das vom Tunnel kommt. Baue ihn im Baumodus (B) mit dem Haltepunkt-Werkzeug (H)."))
		return
	var row := _row(form, 10)
	var a := OptionButton.new()
	var b := OptionButton.new()
	var types := OptionButton.new()
	for picker in [a, b, types]:
		picker.add_theme_font_size_override("font_size", 20)
		picker.custom_minimum_size = Vector2(0, 50)
		picker.focus_mode = Control.FOCUS_NONE
		picker.get_popup().add_theme_font_size_override("font_size", 20)
	a.custom_minimum_size.x = 230
	b.custom_minimum_size.x = 230
	types.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Tunnel zuerst: die erste Linie fährt Nordtal ⇄ eigener Ort.
	for portal in region.portals:
		a.add_item("%s (Tunnel)" % portal.station_name, portal.station_id)
	for station in region.stations:
		a.add_item(station.station_name, station.station_id)
		b.add_item(station.station_name, station.station_id)
	for portal in region.portals:
		b.add_item("%s (Tunnel)" % portal.station_name, portal.station_id)
	b.select(0)
	if region.portals.is_empty() and region.stations.size() > 1:
		b.select(1)
	for id in EpochCatalog.TRAIN_IDS:
		if region.progression.is_train_unlocked(id):
			types.add_item(EpochCatalog.train(id).display_name)
			types.set_item_metadata(types.item_count - 1, id)
			if id == train_id:
				types.select(types.item_count - 1)
	row.add_child(a)
	row.add_child(S.label("⇄", 28, S.GOLD.darkened(0.2)))
	row.add_child(b)
	row.add_child(types)
	var bottom := _row(form, 14)
	var hint := S.paragraph("", 18)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var action := S.button(bottom, "Zug einsetzen", func() -> void:
		var line := region.add_line(a.get_selected_id(), b.get_selected_id(), String(types.get_selected_metadata()))
		if not line.is_empty():
			S.play_chime()
			_show_arrival(line)
			return
		_refresh(), true, "trips", 22)
	action.custom_minimum_size = Vector2(260, 56)
	bottom.add_child(hint)
	_assign_button = action
	var update := func(_index := 0) -> void:
		var selected := String(types.get_selected_metadata())
		var reason := region.line_reason(a.get_selected_id(), b.get_selected_id(), selected)
		var price := EpochCatalog.train(selected).purchase_price
		hint.text = reason if reason != "" else ("Bereit · %s · fährt regelmäßig hin und her" % ("kostenlos" if price == 0 else Economy.format_money(price)))
		hint.add_theme_color_override("font_color", S.RED.lightened(0.1) if reason != "" else S.GREEN)
		action.disabled = reason != ""
	a.item_selected.connect(update)
	b.item_selected.connect(update)
	types.item_selected.connect(update)
	update.call()


func _line_card(line: Dictionary) -> void:
	var a := region.station_by_id(int(line["a"]))
	var b := region.station_by_id(int(line["b"]))
	if a == null or b == null:
		return
	var type := EpochCatalog.train(String(line["train"]))
	var card := S.card(_content)
	var head := _row(card, 12)
	var strip := LiveryStrip.new()
	strip.type = type
	strip.compact = true
	strip.custom_minimum_size = Vector2(96, 54)
	head.add_child(strip)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(S.label("Linie %d · %s ⇄ %s" % [int(line["id"]), a.station_name, b.station_name], 26))
	var train := region.train_for_line(int(line["id"]))
	var state := _line_state(line, train)
	names.add_child(S.label("%s · %s" % [type.display_name, state], 17, S.INK_SOFT))
	var stats := _row(card, 30)
	S.stat(stats, "trips", str(int(line.get("trips", 0))), "Fahrten")
	S.stat(stats, "passengers", str(int(line.get("passengers", 0))), "Fahrgäste")
	if type.cargo_capacity > 0:
		S.stat(stats, "goods", str(int(line.get("goods", 0))), "Güter")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer)
	var enabled := bool(line.get("enabled", true))
	var toggle := S.button(stats, "Pausieren" if enabled else "Fortsetzen", func() -> void:
		line["enabled"] = not bool(line.get("enabled", true))
		if train:
			region.dispatcher.retire(train, "")
		region.refresh()
		_refresh(), false, "", 19)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var remove := S.button(stats, "Aufheben", func() -> void:
		region.remove_line(int(line["id"]))
		_refresh(), false, "", 19)
	remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Nach dem Einsetzen: Buch schließen und die Kamera zum Tunnel schwenken,
## aus dem der neue Zug gleich herausrollt.
func _show_arrival(line: Dictionary) -> void:
	var a := region.station_by_id(int(line["a"]))
	var b := region.station_by_id(int(line["b"]))
	var portal := (a if a.is_portal() else (b if b.is_portal() else region.portal_for(a))) as RegionPortal
	close()
	if portal == null:
		return
	var build := region.get_parent().get_node_or_null("BuildMode") as BuildMode
	if build == null:
		return
	if build.view_mode_controller.mode != GameDefs.ViewMode.BIRD_EYE:
		build.view_mode_controller.set_mode(GameDefs.ViewMode.BIRD_EYE)
	build.bird_eye.stop_following()
	build.bird_eye.focus_on(portal.get_mouth() + portal.global_basis.z * 14.0)
	Events.notification_requested.emit("Der Zug ist unterwegs – gleich kommt er aus dem Tunnel %s" % portal.station_name)


func station_other_end(line: Dictionary, station_id: int) -> RegionStation:
	if int(line["a"]) == station_id:
		return region.station_by_id(int(line["b"]))
	if int(line["b"]) == station_id:
		return region.station_by_id(int(line["a"]))
	return null


func _line_state(line: Dictionary, train: Train) -> String:
	if not bool(line.get("enabled", true)):
		return "pausiert"
	if train == null:
		var a := region.station_by_id(int(line["a"]))
		var b := region.station_by_id(int(line["b"]))
		var portal: RegionStation = a if a and a.is_portal() else (b if b and b.is_portal() else null)
		if portal and region.line_is_valid(line):
			return "nächster Zug kommt bald aus %s" % portal.station_name
		return "wartet auf freie Gleise" if region.line_is_valid(line) else "Verbindung prüfen – Gleis unterbrochen?"
	if train.doors_open() or train.speed < 0.05:
		return "hält in %s" % train.entry.station
	return "unterwegs nach %s · %d km/h" % [train.entry.destination, int(train.speed * 3.6)]


func _debug_tools() -> void:
	if not OS.is_debug_build() or not _debug:
		return
	_content.add_child(S.paragraph("Änderungen werden im Spielstand als Debug-Nutzung markiert."))
	var row := _row(_content, 6)
	for level in range(1, 7):
		S.button(row, "Epoche %d" % level, region.progression.set_epoch.bind(level, true), false, "", 18)
	var row2 := _row(_content, 6)
	S.button(row2, "Epoche +1", func() -> void: region.progression.set_epoch(region.progression.epoch + 1, true), false, "", 18)
	S.button(row2, "20 Fahrgäste & 24 Güter", region.progression.debug_simulate.bind(20, 24), false, "", 18)
	S.button(row2, "Tutorial neu starten", func() -> void:
		region.progression.tutorial_step = 0
		region.progression.changed.emit(), false, "", 18)
	for station in region.stations:
		var card := S.card(_content)
		card.add_child(S.label(station.station_name, 24))
		var stages := _row(card, 6)
		for level in range(1, 7):
			S.button(stages, "Stufe %d" % level, func() -> void:
				station.level = level
				station.rebuild()
				region.progression.debug_used = true
				region.refresh(), false, "", 17)
		S.button(card, "Stadtwachstum simulieren", region.grow_station.bind(station, true), false, "", 17)
	var unlocks := HFlowContainer.new()
	_content.add_child(unlocks)
	for id in EpochCatalog.TRAIN_IDS:
		S.button(unlocks, EpochCatalog.train(id).display_name, func() -> void:
			if not region.progression.unlocked.has(id):
				region.progression.unlocked.append(id)
			region.progression.debug_used = true
			region.refresh(), false, "", 17)


func _on_unlock(level: int) -> void:
	_epoch_button.pivot_offset = _epoch_button.size * 0.5
	var tween := _epoch_button.create_tween()
	for i in 3:
		tween.tween_property(_epoch_button, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_epoch_button, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	S.play_chime()
	_selected_epoch = mini(level + 1, EpochCatalog.all().size())


# --- Gezeichnete Bausteine -------------------------------------------------

## Die sechs Epochen als Haltestellen an einem Gleis. Erreichte Stationen sind
## grün gestempelt, die aktuelle leuchtet wie eine Laterne, kommende tragen ein
## Schloss. Ein kleiner Zug steht an der aktuellen Epoche. Klick wählt aus.
class EpochTimeline extends Control:
	signal selected_changed(level: int)
	var current := 1
	var selected := 2
	var _time := 0.0
	var _names: Array[Label] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for data in EpochCatalog.all():
			var caption := JourneyStyle.label(String(data["name"]), 18, JourneyStyle.INK)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			caption.size = Vector2(190, 50)
			add_child(caption)
			_names.append(caption)
		resized.connect(_place_names)
		_place_names()

	func _x(level: int) -> float:
		return lerpf(90.0, size.x - 90.0, float(level - 1) / 5.0)

	func _place_names() -> void:
		for i in _names.size():
			_names[i].position = Vector2(_x(i + 1) - 95, 128)
			var level := i + 1
			_names[i].add_theme_color_override("font_color", JourneyStyle.INK if level <= current + 1 else JourneyStyle.INK_FADED)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for level in range(1, 7):
				if event.position.distance_to(Vector2(_x(level), 74)) < 52:
					selected_changed.emit(level)
					accept_event()
					return

	func _draw() -> void:
		var y := 74.0
		var left := _x(1)
		var right := _x(6)
		# Gleis: Schwellen, dann zwei Schienen; der gefahrene Teil in Messing.
		var sleeper := Color(0.45, 0.31, 0.2, 0.7)
		var x := left
		while x <= right:
			draw_rect(Rect2(x - 3, y - 13, 6, 26), sleeper)
			x += 17.0
		var done_x := _x(current)
		for offset: float in [-7.0, 7.0]:
			draw_line(Vector2(left, y + offset), Vector2(right, y + offset), Color(0.42, 0.4, 0.38), 3.0)
			draw_line(Vector2(left, y + offset), Vector2(done_x, y + offset), JourneyStyle.GOLD, 3.5)
		for level in range(1, 7):
			var center := Vector2(_x(level), y)
			var reached := level < current
			var now := level == current
			if level == selected:
				draw_circle(center, 55, Color(0.79, 0.54, 0.24, 0.22))
				draw_arc(center, 55, 0, TAU, 48, Color(0.79, 0.54, 0.24, 0.8), 2.5, true)
			if now:
				var pulse := 0.5 + 0.5 * sin(_time * 2.4)
				for ring in 3:
					draw_circle(center, 46 + ring * 7 + pulse * 5, Color(1.0, 0.8, 0.4, 0.10 - ring * 0.025))
			var fill := Color("e7f0d8") if reached else (Color("ffe3a3") if now else Color("efe6d3"))
			draw_circle(center, 40, JourneyStyle.WOOD_DARK)
			draw_circle(center, 37, JourneyStyle.GOLD if (reached or now) else Color("b9a58a"))
			draw_circle(center, 31, fill)
			var font := JourneyStyle.serif()
			if reached:
				draw_texture_rect(JourneyStyle.icon("check"), Rect2(center - Vector2(22, 22), Vector2(44, 44)), false)
			else:
				var number := str(level)
				var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_CENTER, -1, 34)
				draw_string(font, center + Vector2(-text_size.x / 2, 12), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, JourneyStyle.INK if now else JourneyStyle.INK_FADED)
				if level > current:
					draw_texture_rect(JourneyStyle.icon("lock"), Rect2(center + Vector2(14, 12), Vector2(24, 24)), false)
		# Kleiner Zug an der aktuellen Epoche.
		var train_at := Vector2(_x(current) - 26, y - 78)
		draw_texture_rect(JourneyStyle.icon("trips"), Rect2(train_at, Vector2(52, 52)), false)


## Seitenansicht eines Zuges in seiner Lackierung (Dach, Fensterband, Zierlinie,
## Räder). Kompakt = nur das führende Fahrzeug für Listen.
class LiveryStrip extends Control:
	var type: TrainType
	var compact := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if type == null:
			return
		var count := 1 if compact else mini(type.consist.size(), 5)
		var gap := 5.0
		var height := minf(size.y * 0.78, 64.0)
		var car_width := (size.x - gap * (count - 1)) / count
		if not compact:
			car_width = minf(car_width, height * 3.4)
		var top := (size.y - height) * 0.5
		var outline := JourneyStyle.WOOD_DARK
		var freight := type.category == TrainType.Category.FREIGHT
		for i in count:
			var x := i * (car_width + gap)
			var body := Rect2(x, top + height * 0.14, car_width, height * 0.66)
			var roof := Rect2(x + 3, top, car_width - 6, height * 0.18)
			draw_rect(roof, type.roof_color)
			draw_rect(roof, outline, false, 1.5)
			draw_rect(body, type.primary_color)
			var upper := Rect2(body.position, Vector2(body.size.x, body.size.y * 0.55))
			draw_rect(upper, type.secondary_color if not freight else type.primary_color.lightened(0.08))
			draw_rect(Rect2(body.position.x, body.position.y + body.size.y * 0.58, body.size.x, maxf(2.0, body.size.y * 0.07)), type.accent_color)
			if not freight or i == 0:
				var windows := maxi(1, int(car_width / 22.0))
				for w in windows:
					var wx := body.position.x + 6 + w * (body.size.x - 12) / windows
					draw_rect(Rect2(wx + 2, body.position.y + body.size.y * 0.14, (body.size.x - 12) / windows - 5, body.size.y * 0.3), Color("ffd98a"))
			draw_rect(body, outline, false, 2.0)
			for wheel: float in [0.18, 0.32, 0.68, 0.82]:
				draw_circle(Vector2(x + car_width * wheel, top + height * 0.86), height * 0.085, Color("4a3c33"))
		draw_line(Vector2(0, top + height * 0.95), Vector2(size.x, top + height * 0.95), Color(0.36, 0.3, 0.26, 0.6), 2.0)


## Sechs kleine Punkte für die Bahnhofsstufe.
class LevelPips extends HBoxContainer:
	static func make(level: int) -> LevelPips:
		var pips := LevelPips.new()
		pips.add_theme_constant_override("separation", 5)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for i in 6:
			var dot := Pip.new()
			dot.on = i < level
			dot.custom_minimum_size = Vector2(16, 16)
			pips.add_child(dot)
		return pips

	class Pip extends Control:
		var on := false
		func _draw() -> void:
			var center := size * 0.5
			draw_circle(center, 7.5, JourneyStyle.WOOD_DARK)
			draw_circle(center, 5.5, JourneyStyle.GOLD_LIGHT if on else Color("e7dcc6"))
