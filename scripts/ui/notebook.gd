## Das Notizbuch (Taste N): ein kleines Spiralnotizbuch mit Ledereinband,
## liniertem Papier, Papierreitern und handschriftlichen Überschriften.
##
## Seiten:
##   Lager       – Bestände, Herkunft, Daueraufträge, Kran, letzte Lieferungen
##   Einwohner   – Haushalte, Mitglieder, Tagesrhythmus, Lieblingsweg, was sie gerade tun
##   Fahrplan    – Personenzüge und Güterzüge mit ihrer Ladung
##   Bauprojekte – Baustellen mit Fortschritt und Material, Baukosten aller Häuser
##   Finanzen    – Gemeindekasse, Tagesbilanz, Kassenbuch
##   Feste       – Festkalender, heutiges Programm, Sonderzüge, Dorfchronik (Etappe 10)
##
## Das Buch wird komplett per Code gezeichnet (keine Texturen außer den eigenen
## Icons). Es liest nur Daten ([code]Economy[/code], Dorf, Güterbahnhof,
## Fahrdienstleiter) und ändert selbst nur die Daueraufträge.
class_name Notebook
extends CanvasLayer

const PAGES: Array[Dictionary] = [
	{"id": "storage", "label": "Lager", "icon": preload("res://assets/ui/icons/tab_storage.svg"), "color": Color(0.86, 0.74, 0.52)},
	{"id": "residents", "label": "Einwohner", "icon": preload("res://assets/ui/icons/tab_residents.svg"), "color": Color(0.72, 0.82, 0.62)},
	{"id": "timetable", "label": "Fahrplan", "icon": preload("res://assets/ui/icons/tab_timetable.svg"), "color": Color(0.64, 0.76, 0.86)},
	{"id": "projects", "label": "Bauprojekte", "icon": preload("res://assets/ui/icons/tab_projects.svg"), "color": Color(0.93, 0.72, 0.48)},
	{"id": "finances", "label": "Finanzen", "icon": preload("res://assets/ui/icons/tab_finances.svg"), "color": Color(0.93, 0.83, 0.46)},
	{"id": "festivals", "label": "Feste", "icon": preload("res://assets/ui/icons/tab_festivals.svg"), "color": Color(0.9, 0.62, 0.6)},
]
const COIN := preload("res://assets/ui/icons/coin.svg")
const INK := Color(0.2, 0.16, 0.13)
const INK_SOFT := Color(0.42, 0.36, 0.3)
const INK_FADED := Color(0.6, 0.55, 0.5)
const INK_RED := Color(0.64, 0.2, 0.15)
const INK_GREEN := Color(0.22, 0.45, 0.25)
const INK_BLUE := Color(0.2, 0.32, 0.55)
const BOOK_SIZE := Vector2(1280, 780)
const REFRESH := 1.2

@export var village: VillageManager
@export var freight_yard: FreightYard
@export var dispatcher: TrainDispatcher
@export var npc_director: NpcDirector
@export var finances: TownFinances

var is_open := false
var _page := "storage"
var _root: Control
var _dim: ColorRect
var _book: Control
var _tabs_layer: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _tab_buttons: Dictionary = {}
var _flip: ColorRect
var _hand: SystemFont
var _refresh_timer := 0.0
var _selected_home := ""
var _sound: AudioStreamPlayer
var _tween: Tween
var _restore_capture := false
var _restore_player := false


func _ready() -> void:
	layer = 20
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Comic Sans MS", "Chalkboard SE", "Noteworthy"])
	_hand.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_build()
	_root.visible = false
	Events.notebook_requested.connect(func(page: String) -> void:
		if is_open and (page == "" or page == _page):
			close()
		else:
			open(page))
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -8.0
	add_child(_sound)
	SoundLibrary.stop_on_exit(_sound)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_notebook"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed(&"build_cancel") or event.is_action_pressed(&"release_mouse"):
		close()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var index := key.physical_keycode - KEY_1
		if index >= 0 and index < PAGES.size():
			show_page(PAGES[index]["id"])
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"camera_rotate_left") or event.is_action_pressed(&"camera_rotate_right"):
			var step := -1 if event.is_action_pressed(&"camera_rotate_left") else 1
			show_page(PAGES[posmod(_page_index() + step, PAGES.size())]["id"])
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH
		_fill_page()


# --- Öffnen, Schließen, Blättern ------------------------------------------------------------

func open(page := "") -> void:
	if page != "":
		_page = page
	if not is_open:
		is_open = true
		_restore_capture = GameInput.is_mouse_captured()
		GameInput.capture_mouse(false)
		var player := get_tree().get_first_node_in_group(&"player") as PlayerController
		if player == null:
			player = get_node_or_null("../Player") as PlayerController
		if player:
			_restore_player = player.input_enabled
			player.input_enabled = false
		_root.visible = true
		_kill_tween()
		_root.modulate.a = 0.0
		_book.position.y = _book_origin().y + 40.0
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_root, "modulate:a", 1.0, 0.22)
		_tween.tween_property(_book, "position:y", _book_origin().y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_play_page()
	_update_tabs()
	_fill_page()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 0.0, 0.18)
	_tween.tween_property(_book, "position:y", _book_origin().y + 30.0, 0.18)
	_tween.chain().tween_callback(func() -> void: _root.visible = false)
	var player := get_node_or_null("../Player") as PlayerController
	if player:
		player.input_enabled = _restore_player
	if _restore_capture:
		GameInput.capture_mouse(true)
	_play_page()


func show_page(page: String) -> void:
	if page == _page and is_open:
		return
	_page = page
	_update_tabs()
	if not is_open:
		open(page)
		return
	# Umblättern: ein Blatt klappt über die rechte Seite, dann steht der neue Inhalt da
	_play_page()
	_flip.visible = true
	_flip.scale = Vector2(1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_flip, "scale:x", 0.02, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_fill_page)
	tween.tween_property(_flip, "scale:x", 1.0, 0.0)
	tween.tween_callback(func() -> void: _flip.visible = false)


func get_page() -> String:
	return _page


func _page_index() -> int:
	for i in PAGES.size():
		if PAGES[i]["id"] == _page:
			return i
	return 0


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _play_page() -> void:
	_sound.stream = SoundLibrary.get_sound("page")
	_sound.pitch_scale = randf_range(0.92, 1.08)
	SoundLibrary.play(_sound)


func _book_origin() -> Vector2:
	var size := _root.size if _root.size.x > 0.0 else Vector2(1920, 1080)
	return (size - BOOK_SIZE) * 0.5 + Vector2(-50, 10)


# --- Aufbau ------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.04, 0.06, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			close())
	_root.add_child(_dim)
	_tabs_layer = Control.new()
	_tabs_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tabs_layer)
	_book = BookArt.new()
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_book)
	_root.resized.connect(_layout)
	var half := BOOK_SIZE.x * 0.5
	_left = _page_column(Rect2(Vector2(82, 58), Vector2(half - 128, BOOK_SIZE.y - 108)))
	_right = _page_column(Rect2(Vector2(half + 52, 58), Vector2(half - 118, BOOK_SIZE.y - 108)))
	_flip = ColorRect.new()
	_flip.color = BookArt.PAPER
	_flip.position = Vector2(half + 10, 22)
	_flip.size = Vector2(half - 40, BOOK_SIZE.y - 44)
	_flip.pivot_offset = Vector2(0, _flip.size.y * 0.5)
	_flip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip.visible = false
	_book.add_child(_flip)
	# Reiter rechts am Buch (stecken zwischen den Seiten)
	for i in PAGES.size():
		var page: Dictionary = PAGES[i]
		var tab := Button.new()
		tab.focus_mode = Control.FOCUS_NONE
		tab.text = "  " + String(page["label"])
		tab.icon = page["icon"]
		tab.expand_icon = true
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_constant_override("icon_max_width", 34)
		tab.add_theme_font_override("font", _hand)
		tab.add_theme_font_size_override("font_size", 19)
		for state_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			tab.add_theme_color_override(state_name, INK)
		var color: Color = page["color"]
		for style_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			tab.add_theme_stylebox_override(style_name, _tab_style(color.lightened(0.12) if style_name.begins_with("hover") else color))
		tab.custom_minimum_size = Vector2(196, 62)
		tab.size = Vector2(196, 62)
		tab.tooltip_text = "Taste %d" % (i + 1)
		tab.pressed.connect(show_page.bind(page["id"]))
		_tabs_layer.add_child(tab)
		_tab_buttons[page["id"]] = tab
	# Schließen-Knopf: kleines, gezeichnetes Kreuz oben rechts auf dem Einband
	var close_button := Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override("font_color", Color(0.93, 0.86, 0.74))
	close_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	close_button.position = Vector2(BOOK_SIZE.x - 22, -30)
	close_button.size = Vector2(40, 40)
	close_button.tooltip_text = "Schließen (N / Esc)"
	close_button.pressed.connect(close)
	_book.add_child(close_button)
	_layout.call_deferred()


func _page_column(rect: Rect2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.position = rect.position
	column.size = rect.size
	column.custom_minimum_size = rect.size
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.clip_contents = true
	_book.add_child(column)
	return column


func _tab_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.3)
	style.set_border_width_all(2)
	style.border_width_left = 0
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	return style


func _layout() -> void:
	_book.position = _book_origin()
	_update_tabs()


func _update_tabs() -> void:
	if _book == null:
		return
	var origin := _book_origin()
	for i in PAGES.size():
		var id: String = PAGES[i]["id"]
		var tab: Button = _tab_buttons[id]
		var active := id == _page
		tab.position = origin + Vector2(BOOK_SIZE.x - 4 + (16 if active else 0), 70 + i * 74)
		tab.modulate = Color(1, 1, 1) if active else Color(0.93, 0.93, 0.93)


# --- Seiteninhalte -----------------------------------------------------------------------

func _fill_page() -> void:
	var scrolls := _remember_scroll()
	for column in [_left, _right]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	match _page:
		"storage":
			_page_storage()
		"residents":
			_page_residents()
		"timetable":
			_page_timetable()
		"projects":
			_page_projects()
		"finances":
			_page_finances()
		"festivals":
			_page_festivals()
	_restore_scroll.call_deferred(scrolls)


func _page_storage() -> void:
	_heading(_left, "Lager am Güterbahnhof")
	_note(_left, "Güterzüge bringen das Material, der Kran legt es ins Lager. Häkchen = Dauerauftrag (wird abgenommen und bezahlt).")
	for goods in Economy.get_goods():
		var row := _row(_left, 12)
		_icon(row, goods.icon, 52)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		row.add_child(column)
		var title := _row(column, 8)
		_label(title, goods.display_name, 23, INK, true)
		var stock := Economy.get_stock(goods.id)
		var numbers := _label(title, "%d / %d" % [stock, goods.max_stock], 17, INK_SOFT)
		numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var check := InkCheck.new()
		check.button_pressed = Economy.is_ordered(goods.id)
		check.caption = "bestellen"
		check.tooltip_text = "Dauerauftrag: Güterzüge liefern %s und der Güterbahnhof bezahlt es (%d Taler je Einheit)." % [
			goods.display_name, goods.unit_price]
		check.toggled.connect(func(on: bool) -> void: Economy.set_ordered(goods.id, on))
		title.add_child(check)
		var bar := InkBar.new()
		bar.value = stock
		bar.max_value = goods.max_stock
		bar.reserved = Economy.get_reserved(goods.id)
		bar.color = goods.color
		bar.custom_minimum_size = Vector2(0, 16)
		column.add_child(bar)
		var reserved := Economy.get_reserved(goods.id)
		var detail := "aus: %s · %d Taler/Stück" % [goods.origin, goods.unit_price]
		if reserved > 0:
			detail = "%d für Baustellen zurückgelegt · " % reserved + detail
		_label(column, detail, 14, INK_SOFT)
	_heading(_right, "Kran & Lieferungen")
	_label(_right, freight_yard.get_status_text() if freight_yard else "–", 17, INK_BLUE)
	_divider(_right)
	_label(_right, "Nächste Güterzüge", 21, INK, true)
	for line in _next_freight_trains(3):
		var row := _row(_right, 8)
		_label(row, line["time"], 17, INK, true)
		_label(row, line["text"], 16, INK_SOFT)
		_cargo_icons(row, line["cargo"])
	_divider(_right)
	_label(_right, "Zuletzt geliefert", 21, INK, true)
	var deliveries: Array[Dictionary] = []
	if freight_yard:
		deliveries = freight_yard.get_deliveries()
	if deliveries.is_empty():
		_note(_right, "Noch keine Lieferung – der erste Güterzug kommt morgens um 07:05.")
	for entry in deliveries.slice(0, 5):
		var row := _row(_right, 8)
		_label(row, "Tag %d, %s" % [int(entry["day"]), TimetableEntry.format_time(float(entry["hours"]))], 15, INK_SOFT)
		_label(row, String(entry["train"]), 16, INK, true)
		_cargo_icons(row, entry["goods"])
	if freight_yard:
		var empties := freight_yard.get_empties()
		_divider(_right)
		_note(_right, "Leergut für die Rückfahrt: %d Palettenstapel, %d leere Container (Pfand %d bzw. %d Taler)." % [
			int(empties["pallet_stack"]), int(empties["container_empty"]), freight_yard.pallet_deposit, freight_yard.container_deposit])


func _page_residents() -> void:
	var homes := _households()
	var total := 0
	for home in homes:
		total += (home["npcs"] as Array).size()
	_heading(_left, "Einwohner: %d" % total)
	_note(_left, "%d Haushalte · neue Familien kommen mit dem Zug, sobald ihr Haus fertig ist." % homes.size())
	if _selected_home == "" and not homes.is_empty():
		_selected_home = homes[0]["home"]
	var scroll := _scroll(_left, "residents_list")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var selected: Dictionary = {}
	for home in homes:
		var active := String(home["home"]) == _selected_home
		if active:
			selected = home
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", _hand)
		button.add_theme_font_size_override("font_size", 19)
		var npcs: Array = home["npcs"]
		var state := String(home["state"])
		button.text = "%s Familie %s  ·  %s" % ["→" if active else "  ", home["home"],
			state if state != "" else "%d %s" % [npcs.size(), "Person" if npcs.size() == 1 else "Personen"]]
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(color_name, INK_RED if active else (INK_BLUE if color_name == "font_hover_color" else INK))
		button.pressed.connect(func() -> void:
			_selected_home = String(home["home"])
			_fill_page())
		list.add_child(button)
	if selected.is_empty():
		_heading(_right, "Noch niemand da")
		return
	_heading(_right, "Familie %s" % selected["home"])
	_label(_right, String(selected["house"]), 17, INK_SOFT)
	var npcs: Array = selected["npcs"]
	if npcs.is_empty():
		_note(_right, String(selected["state"]) if String(selected["state"]) != "" else "Das Haus steht noch leer.")
	for npc: Npc in npcs:
		_divider(_right)
		var profile := npc.profile
		var row := _row(_right, 8)
		_label(row, npc.display_name, 21, INK, true)
		var doing := _label(row, "– " + npc.get_status_text(), 16, INK_BLUE)
		doing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if profile:
			var lines: PackedStringArray = []
			if profile.role != "":
				lines.append(profile.role.capitalize() if profile.role == "Kind" else profile.role)
			if profile.rhythm != "":
				lines.append(profile.rhythm)
			var way := profile.favourite_way if profile.favourite_way != "" else "den kürzesten Weg über die Dorfstraße"
			lines.append("Lieblingsweg: %s" % way)
			var times: PackedStringArray = []
			for routine in profile.routines:
				if routine:
					times.append(routine.describe())
			if not times.is_empty():
				lines.append("Tag: " + "; ".join(times))
			_label(_right, "\n".join(lines), 15, INK_SOFT)


func _page_timetable() -> void:
	_heading(_left, "Personenzüge")
	var now := WorldClock.time_of_day
	var entries: Array[TimetableEntry] = []
	if dispatcher and dispatcher.timetable:
		entries = dispatcher.timetable.entries.duplicate()
	entries.sort_custom(func(a: TimetableEntry, b: TimetableEntry) -> bool:
		return a.get_arrival_hours() < b.get_arrival_hours())
	var next_marked := false
	var scroll := _scroll(_left, "timetable")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	for entry in entries:
		if entry.station != "Wintervale":
			continue
		var past := entry.get_departure_hours() < now - 0.02
		var mark := not past and not next_marked
		next_marked = next_marked or mark
		var row := _row(list, 10)
		_label(row, "→" if mark else " ", 18, INK_RED)
		_label(row, TimetableEntry.format_time(entry.get_departure_hours()), 18, INK_FADED if past else INK, true)
		_label(row, entry.train_number, 17, INK_FADED if past else INK_BLUE)
		var route := _label(row, "nach %s" % entry.destination, 16, INK_FADED if past else INK_SOFT)
		route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(row, "Gl. %d" % entry.platform, 16, INK_FADED if past else INK_SOFT)
	_heading(_right, "Güterzüge")
	_note(_right, "Halten am Güterbahnhof (Gleis 3). Der Kran entlädt, danach geht Leergut zurück.")
	for entry in entries:
		if entry.station == "Wintervale" or entry.train_type == null:
			continue
		_divider(_right)
		var row := _row(_right, 10)
		_label(row, "%s–%s" % [entry.arrival, entry.departure], 18, INK, true)
		_label(row, entry.train_number, 17, INK_BLUE)
		_label(row, entry.train_type.display_name, 16, INK_SOFT)
		var status := _freight_status(entry)
		if status != "":
			_label(row, status, 15, INK_RED)
		var cargo_row := _row(_right, 8)
		_label(cargo_row, "aus %s:" % entry.origin, 15, INK_SOFT)
		_cargo_icons(cargo_row, consist_cargo(entry.train_type))


func _page_projects() -> void:
	_heading(_left, "Baustellen")
	var projects: Array[VillageHouse] = []
	if village:
		projects = village.get_projects()
	if projects.is_empty():
		_note(_left, "Gerade wird nichts gebaut.\nIm Bau-Modus (B) unter „Häuser“ (6) ein Haus setzen – das Material wird reserviert, dann beginnt die Baustelle. Gebaut wird von 6 bis 20 Uhr.")
	for house in projects:
		_divider(_left)
		var row := _row(_left, 8)
		_label(row, VillageCatalog.get_label(house.item_id), 22, INK, true)
		_label(row, "für Familie %s" % house.home_name, 16, INK_SOFT)
		var bar := InkBar.new()
		bar.value = house.build_progress * 100.0
		bar.max_value = 100.0
		bar.color = Color(0.9, 0.62, 0.25)
		bar.custom_minimum_size = Vector2(0, 16)
		_left.add_child(bar)
		var hours := village.get_project_hours_left(house)
		_label(_left, "%s · %d %% · noch etwa %s Arbeitsstunden%s" % [house.get_stage_text(), roundi(house.build_progress * 100.0),
			_hours_text(hours), "" if VillageManager.is_work_time() else " (nachts ruht die Baustelle)"], 15, INK_SOFT)
		var cost := VillageCatalog.get_cost(house.item_id)
		var left := Economy.get_reservation(VillageManager.cost_key(house.object_id))
		var used_row := _row(_left, 6)
		_label(used_row, "verbaut:", 15, INK_SOFT)
		for goods in Economy.get_goods():
			if int(cost.get(goods.id, 0)) > 0:
				_icon(used_row, goods.icon, 22)
				_label(used_row, "%d/%d" % [int(cost[goods.id]) - int(left.get(goods.id, 0)), int(cost[goods.id])], 15, INK)
	var finished: Array[Dictionary] = []
	if village:
		finished = village.get_finished_log()
	if not finished.is_empty():
		_divider(_left)
		_label(_left, "Zuletzt fertig", 20, INK, true)
		for entry in finished.slice(0, 4):
			_label(_left, "Tag %d: %s für Familie %s" % [int(entry["day"]), VillageCatalog.get_label(String(entry["item"])), entry["home"]], 15, INK_SOFT)
	_heading(_right, "Was ein Haus kostet")
	for item_id in VillageCatalog.get_items(&"houses"):
		var row := _row(_right, 6)
		var name_label := _label(row, VillageCatalog.get_label(item_id), 18, INK, true)
		name_label.custom_minimum_size = Vector2(150, 0)
		var cost := VillageCatalog.get_cost(item_id)
		_cost_icons(row, cost)
		_label(row, "· %dh" % roundi(VillageCatalog.get_build_hours(item_id)), 15, INK_SOFT)
	_divider(_right)
	var small := _row(_right, 6)
	_label(small, "Laterne", 17, INK, true)
	_cost_icons(small, VillageCatalog.get_cost("lantern"))
	_label(small, " Straßenlaterne", 17, INK, true)
	_cost_icons(small, VillageCatalog.get_cost("street_lamp"))
	var paths := _row(_right, 6)
	_label(paths, "Steinweg je 10 m", 17, INK, true)
	_cost_icons(paths, VillageCatalog.get_cost("path_stone", 10.0))
	_note(_right, "Abreißen gibt alles zurück. Material fehlt? Im Lager Daueraufträge prüfen – der nächste Güterzug bringt Nachschub.")


func _page_finances() -> void:
	var header := _row(_left, 10)
	_icon(header, COIN, 54)
	_heading(header, Economy.format_money(Economy.money))
	_note(_left, "Gemeindekasse von Wintervale")
	var today := Economy.get_day_summary(WorldClock.day)
	var yesterday := Economy.get_day_summary(WorldClock.day - 1)
	_divider(_left)
	_label(_left, "Heute (Tag %d)" % WorldClock.day, 21, INK, true)
	_money_line(_left, "Einnahmen", int(today["income"]))
	_money_line(_left, "Ausgaben", -int(today["expense"]))
	var kinds: Dictionary = today["kinds"]
	for kind: String in Economy.KIND_LABELS:
		if kinds.has(kind):
			_money_line(_left, "   " + String(Economy.KIND_LABELS[kind]), int(kinds[kind]), 15)
	if WorldClock.day > 1:
		_divider(_left)
		_label(_left, "Gestern", 19, INK, true)
		_money_line(_left, "Bilanz", int(yesterday["income"]) - int(yesterday["expense"]))
	_divider(_left)
	var taxes := finances.get_daily_taxes() if finances else 0
	_note(_left, "Jeden Abend um 18 Uhr: Gemeindeabgaben (%d Taler je Einwohner, heute etwa %d Taler). Jede Fahrkarte in Wintervale bringt %d Taler, jeder Güterzug %d Taler Trassengebühr." % [
		finances.tax_per_resident if finances else 0, taxes, finances.ticket_price if finances else 0,
		freight_yard.freight_fee if freight_yard else 0])
	_heading(_right, "Kassenbuch")
	var scroll := _scroll(_right, "ledger")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 1)
	scroll.add_child(list)
	var ledger := Economy.get_ledger()
	if ledger.is_empty():
		_note(list, "Noch keine Buchungen.")
	for entry in ledger:
		var row := _row(list, 8)
		_label(row, "T%d %s" % [int(entry["day"]), TimetableEntry.format_time(float(entry["hours"]))], 14, INK_FADED)
		var count := int(entry.get("count", 1))
		var text := _label(row, String(entry["text"]) + (" ×%d" % count if count > 1 else ""), 15, INK)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		var amount := int(entry["amount"])
		_label(row, ("+" if amount > 0 else "") + Economy.format_money(amount, false), 16, INK_GREEN if amount > 0 else INK_RED, true)


## Seite "Feste": Festkalender, heutiges Programm, Sonderzüge und die Dorfchronik.
func _page_festivals() -> void:
	var festivals := FestivalDirector.find(get_tree())
	var events := get_tree().get_first_node_in_group(&"train_events") as TrainEvents
	_heading(_left, "Feste im Dorf")
	if festivals == null:
		_note(_left, "Keine Feste geplant.")
		return
	for row: Dictionary in festivals.get_calendar():
		var line := _row(_left, 12)
		_icon(line, SpeechBubble.icon_texture(String(row["icon"])), 46)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", -2)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(column)
		_label(column, String(row["name"]), 22, INK, true)
		var when := ""
		if bool(row["running"]):
			var left := roundi(float(row["days_left"]))
			when = "Jetzt – %s · täglich %s–%s Uhr" % ["letzter Tag" if left < 1 else ("noch 1 Tag" if left == 1 else "noch %d Tage" % left),
				TimetableEntry.format_time(float(row["open"])), TimetableEntry.format_time(float(row["close"]))]
		else:
			when = "in %s" % _days_text(float(row["days_until"]))
		_label(column, when, 15, INK_GREEN if bool(row["running"]) else INK_SOFT)
		_label(column, "%s um %s" % [row["highlight_name"], TimetableEntry.format_time(float(row["highlight"]))], 15, INK_SOFT)
	_divider(_left)
	if festivals.is_active():
		_label(_left, "Heute beim %s" % festivals.get_display_name(), 21, INK, true)
		var program: Array[Array] = [
			[festivals.get_open_hour(), "Die Buden öffnen"],
			[festivals.get_highlight_hour(), "%s" % FestivalDirector.FESTIVALS[festivals.get_active_id()]["highlight_name"]],
			[festivals.get_close_hour(), "Die Buden schließen"],
		]
		for entry in festivals.get_special_entries():
			var arrival := entry.get_arrival_hours()
			program.append([arrival, "%s aus %s (Gleis %d)" % [entry.train_number, entry.origin, entry.platform]])
		program.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for item: Array in program:
			var line := _row(_left, 10)
			var past := WorldClock.time_of_day > float(item[0])
			_label(line, TimetableEntry.format_time(float(item[0])), 17, INK_FADED if past else INK_BLUE, true)
			_label(line, String(item[1]), 16, INK_FADED if past else INK)
		var stats := festivals.get_stats()
		_note(_left, "Gerade auf dem Fest: %d · Besucher bisher: %d · an den Buden verkauft: %d" % [
			festivals.get_visitors_now(), int(stats["visitors"]), int(stats["sold"])])
	else:
		_note(_left, "Zwischen den Festen ist es ruhig im Dorf – der Weihnachtsmarkt steht im Winter, das Herbstfest im Herbst.")
	if events:
		var train_stats := events.get_stats()
		_note(_left, "Zug-Ereignisse: %d Verspätungen, %d× Schneeräumzug, %d Koffer zurückgebracht" % [
			int(train_stats["delays"]), int(train_stats["ploughs"]), int(train_stats["luggage_returned"])])
	_heading(_right, "Dorfchronik")
	var scroll := _scroll(_right, "chronicle")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if festivals.chronicle.is_empty():
		_note(list, "Noch ist nichts Besonderes passiert. Das ändert sich bestimmt bald …")
	for entry: Dictionary in festivals.chronicle:
		var line := _row(list, 10)
		_icon(line, SpeechBubble.icon_texture(String(entry.get("icon", "star"))), 30)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", -3)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(column)
		_label(column, "Tag %d · %s" % [int(entry["day"]), entry["time"]], 13, INK_FADED)
		var text := _label(column, String(entry["text"]), 16, INK)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _days_text(days: float) -> String:
	if days < 1.0:
		return "weniger als einem Tag" if days > 0.05 else "heute"
	var whole := roundi(days)
	return "einem Tag" if whole == 1 else "%d Tagen" % whole


# --- Daten -------------------------------------------------------------------------------

## Haushalte: [{"home", "house", "state", "npcs": Array[Npc]}] – bekannte Familien und Zugezogene.
func _households() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if village == null or npc_director == null:
		return result
	for house in village.get_houses():
		var npcs: Array = []
		for npc in npc_director.get_npcs():
			if npc.profile and npc.profile.home_name == house.home_name:
				npcs.append(npc)
		var state := ""
		if not house.is_finished():
			state = "Baustelle %d %%" % roundi(house.build_progress * 100.0)
		elif npcs.is_empty():
			state = "Haus bereit, Familie noch nicht da"
		else:
			var household := village.get_household(house).size() if not npc_director.has_family(house.home_name) else npcs.size()
			if household > npcs.size():
				state = "%d von %d eingezogen" % [npcs.size(), household]
		result.append({"home": house.home_name, "house": "%s (%s)" % [VillageCatalog.get_label(house.item_id),
			"fertig seit Tag %d" % house.finished_day if house.finished_day > 0 else "von Anfang an"],
			"state": state, "npcs": npcs})
	return result


## Die nächsten Güterzüge ab jetzt: [{"time", "text", "cargo"}].
func _next_freight_trains(count: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if dispatcher == null or dispatcher.timetable == null:
		return rows
	var now := WorldClock.time_of_day
	for entry in dispatcher.timetable.entries:
		if entry.station == "Wintervale" or entry.train_type == null:
			continue
		var ahead := fposmod(entry.get_arrival_hours() - now, 24.0)
		rows.append({"time": entry.arrival, "text": "%s aus %s" % [entry.train_number, entry.origin],
			"cargo": consist_cargo(entry.train_type), "sort": ahead})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["sort"] < b["sort"])
	return rows.slice(0, count)


func _freight_status(entry: TimetableEntry) -> String:
	if freight_yard and freight_yard.get_current_train() and freight_yard.get_current_train().entry == entry:
		return "wird be- und entladen"
	if dispatcher:
		for train in dispatcher.get_trains():
			if train.entry == entry:
				return "unterwegs"
	return ""


## Was eine Zuggattung geladen hat: {goods_id: Menge}.
static func consist_cargo(train_type: TrainType) -> Dictionary:
	var cargo := {}
	for kind in train_type.consist:
		var spec: Dictionary = TrainMeshes.CARGO.get(kind, {})
		if spec.is_empty():
			continue
		var pieces := (spec["slots"] as Array).size() * maxi(1, int(spec.get("bulk", 1)))
		cargo[spec["goods"]] = int(cargo.get(spec["goods"], 0)) + pieces * int(spec["amount"])
	return cargo


# --- Bausteine ---------------------------------------------------------------------------

func _heading(parent: Control, text: String) -> Label:
	var label := _label(parent, text, 34, INK, true)
	label.add_theme_font_override("font", _hand)
	return label


func _label(parent: Control, text: String, size: int, color: Color, hand := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if hand:
		label.add_theme_font_override("font", _hand)
	if parent is VBoxContainer:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _note(parent: Control, text: String) -> Label:
	var label := _label(parent, text, 15, INK_SOFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _row(parent: Control, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	return row


func _icon(parent: Control, texture: Texture2D, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(rect)
	return rect


func _divider(parent: Control) -> void:
	var line := InkLine.new()
	line.custom_minimum_size = Vector2(0, 12)
	parent.add_child(line)


func _scroll(parent: Control, key: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll_" + key
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta(&"key", key)
	parent.add_child(scroll)
	return scroll


func _cargo_icons(parent: Control, cargo: Dictionary) -> void:
	for goods in Economy.get_goods():
		if int(cargo.get(goods.id, 0)) > 0:
			_icon(parent, goods.icon, 24)
			_label(parent, str(int(cargo[goods.id])), 15, INK)


func _cost_icons(parent: Control, cost: Dictionary) -> void:
	if int(cost.get("money", 0)) > 0:
		_icon(parent, COIN, 20)
		_label(parent, str(int(cost["money"])), 15, INK)
	for goods in Economy.get_goods():
		if int(cost.get(goods.id, 0)) > 0:
			_icon(parent, goods.icon, 22)
			_label(parent, str(int(cost[goods.id])), 15, INK)


func _money_line(parent: Control, text: String, amount: int, size := 17) -> void:
	var row := _row(parent, 8)
	var label := _label(row, text, size, INK_SOFT if size < 17 else INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(row, ("+" if amount > 0 else "") + Economy.format_money(amount), size, INK_GREEN if amount >= 0 else INK_RED, true)


func _hours_text(hours: float) -> String:
	if hours < 1.0:
		return "%d Minuten" % maxi(1, roundi(hours * 60.0))
	return "%.1f" % hours


func _remember_scroll() -> Dictionary:
	var result := {}
	for column in [_left, _right]:
		for child in column.get_children():
			if child is ScrollContainer:
				result[child.get_meta(&"key")] = (child as ScrollContainer).scroll_vertical
	return result


func _restore_scroll(scrolls: Dictionary) -> void:
	for column in [_left, _right]:
		for child in column.get_children():
			if child is ScrollContainer and scrolls.has(child.get_meta(&"key")):
				(child as ScrollContainer).scroll_vertical = int(scrolls[child.get_meta(&"key")])


# --- Gezeichnete Teile -------------------------------------------------------------------

## Das Buch: Ledereinband mit Naht, zwei linierte Seiten, Spiralbindung,
## Lesebändchen, Gummiband und zwei Streifen Washi-Tape.
class BookArt extends Control:
	const PAPER := Color(0.97, 0.93, 0.84)
	const PAPER_SHADE := Color(0.88, 0.83, 0.72)
	const LEATHER := Color(0.36, 0.22, 0.15)
	const STITCH := Color(0.7, 0.54, 0.36)
	const RULE := Color(0.62, 0.7, 0.82, 0.38)
	const MARGIN := Color(0.86, 0.44, 0.4, 0.45)

	func _draw() -> void:
		var s := size
		var half := s.x * 0.5
		# Schatten und Einband
		draw_rect(Rect2(Vector2(10, 16), s + Vector2(24, 24)), Color(0, 0, 0, 0.28))
		_rounded(Rect2(Vector2(-12, -12), s + Vector2(24, 24)), LEATHER, 18)
		_dashed_rect(Rect2(Vector2(-3, -3), s + Vector2(6, 6)), STITCH)
		# Gummiband am rechten Einband
		draw_rect(Rect2(Vector2(s.x - 4, -12), Vector2(10, s.y + 24)), Color(0.55, 0.12, 0.1))
		# Seiten (leicht versetzte Papierkanten darunter)
		for i in 3:
			draw_rect(Rect2(Vector2(14 + i * 2, 16 + i * 2), Vector2(half - 20, s.y - 30)), PAPER_SHADE.darkened(0.04 * i))
			draw_rect(Rect2(Vector2(half + 6 - i * 2, 16 + i * 2), Vector2(half - 20, s.y - 30)), PAPER_SHADE.darkened(0.04 * i))
		_page(Rect2(Vector2(14, 12), Vector2(half - 22, s.y - 30)), true)
		_page(Rect2(Vector2(half + 8, 12), Vector2(half - 22, s.y - 30)), false)
		# Spiralbindung
		var y := 40.0
		while y < s.y - 30.0:
			draw_circle(Vector2(half - 22, y), 4.0, Color(0.3, 0.26, 0.22))
			draw_circle(Vector2(half + 22, y), 4.0, Color(0.3, 0.26, 0.22))
			draw_arc(Vector2(half, y - 2), 22.0, PI * 1.05, PI * 1.95, 12, Color(0.55, 0.56, 0.58), 3.0, true)
			draw_arc(Vector2(half, y - 1), 22.0, PI * 1.1, PI * 1.9, 12, Color(0.85, 0.86, 0.88), 1.2, true)
			y += 30.0
		# Lesebändchen: schaut unten zwischen den Seiten heraus
		var ribbon := PackedVector2Array([Vector2(half + 40, s.y - 22), Vector2(half + 56, s.y - 22), Vector2(half + 58, s.y + 46),
			Vector2(half + 49, s.y + 36), Vector2(half + 40, s.y + 46)])
		draw_colored_polygon(ribbon, Color(0.66, 0.16, 0.14))
		draw_line(Vector2(half + 48, s.y - 22), Vector2(half + 49, s.y + 36), Color(0.5, 0.1, 0.08), 1.0)
		# Washi-Tape an den Ecken
		_tape(Vector2(40, 22), -0.35, Color(0.62, 0.78, 0.72, 0.75))
		_tape(Vector2(s.x - 70, s.y - 30), -0.3, Color(0.92, 0.72, 0.48, 0.75))

	func _page(rect: Rect2, left: bool) -> void:
		draw_rect(rect, PAPER)
		# Schatten zum Falz hin
		var spine_x := rect.end.x if left else rect.position.x
		for i in 14:
			var w := 3.0
			var x := spine_x - (i + 1) * w if left else spine_x + i * w
			draw_rect(Rect2(Vector2(x, rect.position.y), Vector2(w, rect.size.y)), Color(0.55, 0.45, 0.32, 0.018 * (14 - i)))
		# Linien und roter Rand
		var y := rect.position.y + 96.0
		while y < rect.end.y - 18.0:
			draw_line(Vector2(rect.position.x + 14, y), Vector2(rect.end.x - 14, y), RULE, 1.0)
			y += 30.0
		var margin_x := rect.position.x + (54.0 if left else 30.0)
		draw_line(Vector2(margin_x, rect.position.y + 6), Vector2(margin_x, rect.end.y - 6), MARGIN, 1.4)

	func _rounded(rect: Rect2, color: Color, radius: float) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(int(radius))
		draw_style_box(style, rect)

	func _dashed_rect(rect: Rect2, color: Color) -> void:
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 1.6, 7.0)

	func _tape(center: Vector2, angle: float, color: Color) -> void:
		draw_set_transform(center, angle)
		draw_rect(Rect2(Vector2(-46, -12), Vector2(92, 24)), color)
		for i in 5:
			draw_line(Vector2(-40 + i * 18, -12), Vector2(-32 + i * 18, 12), Color(1, 1, 1, 0.25), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0)


## Balken wie mit Bleistift schraffiert: Umriss in Tinte, Füllung in Materialfarbe,
## reservierter Teil kreuzschraffiert.
class InkBar extends Control:
	var value := 0.0
	var max_value := 100.0
	var reserved := 0.0
	var color := Color(0.6, 0.45, 0.3)

	func _draw() -> void:
		var r := Rect2(Vector2(1, 2), size - Vector2(2, 4))
		var fill := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
		var fill_rect := Rect2(r.position, Vector2(r.size.x * fill, r.size.y))
		draw_rect(fill_rect, Color(color, 0.55))
		var x := r.position.x - r.size.y
		while x < fill_rect.end.x:
			var a := Vector2(maxf(x, r.position.x), r.end.y - maxf(0.0, r.position.x - x))
			var b := Vector2(minf(x + r.size.y, fill_rect.end.x), r.position.y + maxf(0.0, (x + r.size.y) - fill_rect.end.x))
			draw_line(a, b, color.darkened(0.25), 1.4)
			x += 6.0
		var reserved_w := r.size.x * clampf(reserved / maxf(max_value, 1.0), 0.0, fill)
		if reserved_w > 1.0:
			var start := fill_rect.end.x - reserved_w
			var xr := start
			while xr < fill_rect.end.x:
				draw_line(Vector2(xr, r.position.y), Vector2(minf(xr + 6, fill_rect.end.x), r.end.y), Color(0.2, 0.16, 0.13, 0.55), 1.2)
				xr += 5.0
		draw_rect(r, Color(0.2, 0.16, 0.13, 0.85), false, 1.6)


## Handgezogener Trennstrich.
class InkLine extends Control:
	func _draw() -> void:
		var points := PackedVector2Array()
		var y := size.y * 0.5
		var x := 0.0
		while x <= size.x:
			points.append(Vector2(x, y + sin(x * 0.07) * 1.2))
			x += 8.0
		draw_polyline(points, Color(0.42, 0.36, 0.3, 0.6), 1.3, true)


## Gezeichnetes Kästchen zum Abhaken (Dauerauftrag). Beschriftung: [member caption].
class InkCheck extends Button:
	var caption := ""

	func _init() -> void:
		toggle_mode = true
		flat = true
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_font_size_override("font_size", 15)
		for state_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			add_theme_color_override(state_name, Color(0.36, 0.3, 0.25))
		add_theme_constant_override("h_separation", 0)
		custom_minimum_size = Vector2(120, 26)
		toggled.connect(func(_on: bool) -> void: queue_redraw())

	func _get_minimum_size() -> Vector2:
		return Vector2(120, 26)

	func _draw() -> void:
		var box := Rect2(Vector2(2, 5), Vector2(16, 16))
		draw_rect(box, Color(0.2, 0.16, 0.13, 0.9), false, 1.6)
		if button_pressed:
			draw_polyline(PackedVector2Array([Vector2(4, 12), Vector2(9, 19), Vector2(21, 1)]), Color(0.22, 0.45, 0.25), 2.6, true)
		draw_string(get_theme_font("font"), Vector2(26, 19), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.36, 0.3, 0.25))
