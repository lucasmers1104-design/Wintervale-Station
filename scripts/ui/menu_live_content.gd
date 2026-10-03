## Data-driven parchment areas over the approved menu artwork.
class_name MenuLiveContent
extends Control

signal start_requested(name: String, season: int)
signal load_requested(slot: String)
signal action_requested(action: String)

const PAPER := Color("efcfaa")
const INK := Color("40271e")
const GOLD := Color("bd7635")
const MUTED := Color("755440")
const PARCHMENT_TEXTURE := preload("res://assets/ui/main_menu/parchment_panel.png")
const SETTINGS_ICONS := "res://assets/ui/settings_icons/%s.png"
const CHEVRON := preload("res://assets/ui/settings_icons/chevron.svg")
const CARD_UNLOCKED := preload("res://assets/ui/achievement_art/card_unlocked.png")
const CARD_LOCKED := preload("res://assets/ui/achievement_art/card_locked.png")
const CHECK_ICON := preload("res://assets/ui/achievement_art/check.png")
const LOCKED_BADGE := preload("res://assets/materials/badge_locked.tres")
const SAVE_CARD := preload("res://assets/ui/save_art/card.png")
const SAVE_CARD_HIGHLIGHT := preload("res://assets/ui/save_art/card_highlight.png")
const SAVE_CARD_EMPTY := preload("res://assets/ui/save_art/card_empty.png")
const SAVE_BUTTON_GOLD := preload("res://assets/ui/save_art/button_gold.png")
const SAVE_BUTTON_PLAIN := preload("res://assets/ui/save_art/button_plain.png")
const EMPTY_SKETCH := preload("res://assets/ui/save_art/empty_sketch.png")
const SAVE_ICONS := {
	"calendar": preload("res://assets/ui/save_art/calendar.png"),
	"season_winter": preload("res://assets/ui/save_art/season_winter.png"),
	"season_autumn": preload("res://assets/ui/save_art/season_autumn.png"),
	"season_spring": preload("res://assets/ui/save_art/season_spring.png"),
	"trains": preload("res://assets/ui/save_art/trains.png"),
	"population": preload("res://assets/ui/save_art/population.png"),
	"playtime": preload("res://assets/ui/save_art/playtime.png"),
	"load": preload("res://assets/ui/save_art/load.png"),
	"delete": preload("res://assets/ui/save_art/delete.png"),
	"plus": preload("res://assets/ui/save_art/plus.png"),
}
## Schriftfarben der Jahreszeiten wie in der Load-Save-Vorlage (Sommer ergänzt).
const SEASON_COLORS := {"Winter": Color("3f78a3"), "Autumn": Color("b8612a"), "Spring": Color("c05a7a"), "Summer": Color("6f8a2a")}
const NEW_GAME_ART := preload("res://assets/ui/menu_screens/new_game.png")
## Auswahlfelder der New-Game-Vorlage (inkl. Rand für das Leuchten, siehe Werkzeug).
const NEW_GAME_CHARACTERS := {"male": Rect2(1016, 400, 205, 226), "female": Rect2(1219, 400, 205, 226)}
const NEW_GAME_SEASONS := {"winter": Rect2(1016, 678, 105, 101), "spring": Rect2(1119, 678, 105, 101),
	"summer": Rect2(1221, 678, 105, 101), "autumn": Rect2(1324, 678, 105, 101)}
const SEASON_INDEX := {"spring": 0, "summer": 1, "autumn": 2, "winter": 3}
const SEASON_NAMES_BY_INDEX := ["Spring", "Summer", "Autumn", "Winter"]
## Credits: [Position der Namen in der Vorlage, Zeilen]. Nur belegte Angaben.
const CREDITS := [
	[Vector2(488, 336), ["Luca Warmers"]],
	[Vector2(488, 456), ["Luca Warmers"]],
	[Vector2(488, 601), ["Handmade procedural low-poly", "models, made in-project"]],
	[Vector2(1047, 336), ["Self-composed in-project", "music and sounds"]],
	[Vector2(1047, 470), ["Reference artwork supplied", "by the project creator"]],
	[Vector2(1049, 601), ["The Godot Engine community", "All our playtesters", "And everyone who believes", "in the magic of small places."]],
]
## Kategorien mit Symbol und Motto aus der Achievements-Vorlage.
const ACHIEVEMENT_CATEGORIES := [
	{"name": "Railway", "icon": "cat_railway", "motto": "Keep the trains running and master the station."},
	{"name": "Village", "icon": "cat_village", "motto": "Help Wintervale grow and bring warmth to the community."},
	{"name": "Cozy", "icon": "cat_cozy", "motto": "Find the little moments that make Wintervale home."},
]


## Schlanker Fortschrittsbalken der Achievements-Vorlage (ProgressBar erzwingt Schrifthöhe).
class ThinBar extends Control:
	var ratio := 0.0
	var track := Color("a08571")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius := int(size.y * 0.5)
		var back := StyleBoxFlat.new()
		back.bg_color = track
		back.border_color = Color(0.25, 0.14, 0.08, 0.35)
		back.set_border_width_all(1)
		back.set_corner_radius_all(radius)
		draw_style_box(back, Rect2(Vector2.ZERO, size))
		if ratio > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color("d38e45")
			fill.set_corner_radius_all(radius)
			draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * ratio), size.y)))


## Pill-Schalter wie in den Settings-Vorlagen: goldene Bahn mit hellem Knopf (an),
## helle Bahn mit Knopf links (aus). Ein echter Toggle-Button mit Tastaturfokus.
class PillSwitch extends Button:
	const TRACK := Vector2(54, 28)

	func _init() -> void:
		toggle_mode = true
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = TRACK + Vector2(6, 6)
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(state, empty)
		toggled.connect(func(_on: bool) -> void: queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var origin := (size - TRACK) * 0.5
		var track := StyleBoxFlat.new()
		track.set_corner_radius_all(int(TRACK.y * 0.5))
		track.bg_color = Color("c48b48") if button_pressed else Color("ddd3c7")
		track.border_color = Color("9c6630") if button_pressed else Color("b3a08c")
		track.set_border_width_all(1)
		if is_hovered():
			track.bg_color = track.bg_color.lightened(0.08)
		draw_style_box(track, Rect2(origin, TRACK))
		if has_focus():
			var ring := StyleBoxFlat.new()
			ring.draw_center = false
			ring.set_corner_radius_all(int(TRACK.y * 0.5) + 3)
			ring.border_color = Color("f0bf6f")
			ring.set_border_width_all(2)
			draw_style_box(ring, Rect2(origin - Vector2(3, 3), TRACK + Vector2(6, 6)))
		var radius := TRACK.y * 0.5 - 3.0
		var knob := origin + Vector2(TRACK.x - TRACK.y * 0.5 if button_pressed else TRACK.y * 0.5, TRACK.y * 0.5)
		draw_circle(knob + Vector2(0, 1.5), radius, Color(0.25, 0.13, 0.05, 0.28), true, -1.0, true)
		draw_circle(knob, radius, Color("fbf6ee"), true, -1.0, true)
		draw_circle(knob, radius, Color("cdb89f"), false, 1.0, true)

var page := ""
var draft_settings: Dictionary = {}
var _root: Control
var _status: Label
var _rebind_action: StringName = &""
var _rebind_button: Button
var _detail: VBoxContainer
var achievement_slot := ""
var _achievement_state: Dictionary = {}
var _pending_bindings: Dictionary = {}
var _restore_bindings_pending := false
var _display_pending := false
var _display_confirmation_nonce := 0
var _modal_shade: ColorRect
var _modal_dialog: PanelContainer
var _hover_sound: AudioStreamPlayer
var _new_game_character := "male"
var _new_game_season := 3
var _state_tiles: Array[TextureRect] = []
var _season_icon_rect: TextureRect
var _season_label: Label


func _ready() -> void:
	size = Vector2(1672, 941)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(next_page: String) -> void:
	page = next_page
	_rebind_action = &""
	_rebind_button = null
	_modal_shade = null
	_modal_dialog = null
	_status = null
	_state_tiles.clear()
	_season_icon_rect = null
	_season_label = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_root = Control.new()
	_root.size = size
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hover_sound = AudioStreamPlayer.new()
	_hover_sound.stream = SoundLibrary.get_sound("page")
	_hover_sound.bus = &"WintervaleUI"
	_hover_sound.volume_db = -23.0
	_root.add_child(_hover_sound)
	match page:
		"new_game": _build_new_game()
		"load_save": _build_saves()
		"achievements": _build_achievements()
		"credits": _build_credits()
		_:
			if page.begins_with("settings_"):
				if draft_settings.is_empty():
					draft_settings = GameSettings.values.duplicate(true)
				_build_settings()


func cancel_settings() -> void:
	draft_settings.clear()
	_rebind_action = &""
	_pending_bindings.clear()
	_restore_bindings_pending = false


func handle_escape() -> bool:
	if _display_pending:
		return true
	if _modal_dialog:
		_dismiss_modal()
		return true
	return false


func _dismiss_modal() -> void:
	if _modal_dialog:
		_modal_dialog.queue_free()
	if _modal_shade:
		_modal_shade.queue_free()
	_modal_dialog = null
	_modal_shade = null


func apply_settings() -> void:
	if draft_settings.is_empty() or _display_pending:
		return
	var prior := GameSettings.values.duplicate(true)
	var display_changed: bool = prior["fullscreen"] != draft_settings["fullscreen"] or prior["resolution"] != draft_settings["resolution"]
	var safe_values := draft_settings.duplicate(true)
	if display_changed:
		safe_values["fullscreen"] = prior["fullscreen"]
		safe_values["resolution"] = prior["resolution"]
		GameSettings.apply_values(safe_values)
		GameSettings.apply_values(draft_settings, false)
	else:
		GameSettings.apply_values(draft_settings)
	if _restore_bindings_pending:
		GameInput.restore_default_bindings()
	for action in _pending_bindings:
		GameInput.rebind_key(action, _pending_bindings[action])
	_pending_bindings.clear()
	_restore_bindings_pending = false
	_show_status("Settings applied.")
	if display_changed:
		_confirm_display(safe_values)


func reset_settings() -> void:
	draft_settings = GameSettings.DEFAULTS.duplicate(true)
	_restore_bindings_pending = true
	_pending_bindings.clear()
	build(page)
	_show_status("Defaults selected. Choose Apply to keep changes.")


func _confirm_display(safe_values: Dictionary) -> void:
	_display_pending = true
	_display_confirmation_nonce += 1
	var nonce := _display_confirmation_nonce
	var shade := ColorRect.new()
	shade.color = Color(0.09, 0.05, 0.04, 0.62)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	var dialog := _panel(Vector2(545, 340), Vector2(580, 242))
	var box := _column(dialog, 17)
	box.add_child(_label("Keep display settings?", 30, true))
	box.add_child(_label("They will revert automatically in 10 seconds.", 21))
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var revert := _button("Revert", 180)
	buttons.add_child(revert)
	var keep := _button("Keep Changes", 200)
	buttons.add_child(keep)
	revert.pressed.connect(func() -> void:
		GameSettings.apply_values(safe_values)
		draft_settings = safe_values.duplicate(true)
		_display_pending = false
		_display_confirmation_nonce += 1
		build(page))
	keep.pressed.connect(func() -> void:
		GameSettings.persist_preferences()
		_display_pending = false
		_display_confirmation_nonce += 1
		dialog.queue_free()
		shade.queue_free()
		_show_status("Display settings kept."))
	revert.grab_focus()
	await get_tree().create_timer(10.0).timeout
	if nonce == _display_confirmation_nonce and _display_pending:
		GameSettings.apply_values(safe_values)
		draft_settings = safe_values.duplicate(true)
		_display_pending = false
		_display_confirmation_nonce += 1
		build(page)
		_show_status("Display settings reverted.")


## New Game exakt nach der freigegebenen Vorlage (new_game.png): Bild, Rahmen, Texte
## und Knöpfe kommen aus der Vorlage; live sind Name, Figur, Jahreszeit und die
## Jahreszeit in der Infozeile. Auswahlzustände: tools/extract_new_game_states.gd.
func _build_new_game() -> void:
	_new_game_character = SaveManager.journey_character
	_new_game_season = 3
	# Namensfeld: gemalten Beispieltext abdecken, echtes Eingabefeld darüber
	_paper_patch(Rect2(1034, 302, 318, 40), Color("f4d0aa"))
	var name_input := LineEdit.new()
	name_input.name = "JourneyName"
	name_input.text = "Wintervale - Year 1"
	name_input.max_length = 40
	name_input.position = Vector2(1030, 297)
	name_input.size = Vector2(326, 48)
	name_input.add_theme_font_override("font", _serif())
	name_input.add_theme_font_size_override("font_size", 25)
	name_input.add_theme_color_override("font_color", Color("2c1b14"))
	name_input.add_theme_color_override("caret_color", Color("2c1b14"))
	name_input.add_theme_color_override("selection_color", Color(0.85, 0.58, 0.28, 0.45))
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 8
	name_input.add_theme_stylebox_override("normal", clear)
	var focused := StyleBoxFlat.new()
	focused.draw_center = false
	focused.border_color = Color("e0a95c")
	focused.set_border_width_all(2)
	focused.set_corner_radius_all(4)
	focused.content_margin_left = 8
	name_input.add_theme_stylebox_override("focus", focused)
	_root.add_child(name_input)
	# Figur
	for id: String in NEW_GAME_CHARACTERS:
		_state_tile("Character_" + id, NEW_GAME_CHARACTERS[id], "res://assets/ui/new_game_art/character_%s_%s.png" % [id, "%s"],
			func() -> bool: return _new_game_character == id,
			func() -> void:
				_new_game_character = id
				_refresh_new_game())
	# Jahreszeit (Reihenfolge wie Seasons.Season: Frühling 0 … Winter 3)
	for season: String in NEW_GAME_SEASONS:
		var index: int = SEASON_INDEX[season]
		_state_tile("Season_" + season, NEW_GAME_SEASONS[season], "res://assets/ui/new_game_art/season_%s_%s.png" % [season, "%s"],
			func() -> bool: return _new_game_season == index,
			func() -> void:
				_new_game_season = index
				_refresh_new_game())
	# Infozeile: gewählte Jahreszeit mit Symbol und Farbe
	_paper_patch(Rect2(295, 748, 118, 38), Color("e9c3a0"))
	_season_icon_rect = TextureRect.new()
	_season_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_season_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_season_icon_rect.position = Vector2(297, 752)
	_season_icon_rect.size = Vector2(38, 30)
	_season_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_season_icon_rect)
	_season_label = _label("", 21)
	_season_label.position = Vector2(343, 753)
	_season_label.size = Vector2(90, 30)
	_root.add_child(_season_label)
	# Start Journey (Knopffläche aus der Vorlage)
	var start := _art_region_button("StartJourney", Rect2(1060, 823, 373, 69))
	start.pressed.connect(func() -> void:
		var name_text := name_input.text.strip_edges()
		if name_text.is_empty():
			_show_status("Please enter a name for your journey.")
			return
		SaveManager.journey_character = _new_game_character
		start_requested.emit(name_text, _new_game_season))
	_status = _label("", 18)
	_status.add_theme_color_override("font_color", Color("ffe4b5"))
	_status.position = Vector2(700, 845)
	_status.size = Vector2(340, 30)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_status)
	_refresh_new_game()
	name_input.grab_focus()


## Auswahlfeld mit zwei Bildzuständen (…_on / …_off) aus der Vorlage.
func _state_tile(tile_name: String, region: Rect2, path_pattern: String, is_selected: Callable, choose: Callable) -> void:
	var button := Button.new()
	button.name = tile_name
	button.position = region.position
	button.size = region.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	var picture := TextureRect.new()
	picture.name = "State"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = region.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_meta(&"on", load(path_pattern % "on"))
	picture.set_meta(&"off", load(path_pattern % "off"))
	picture.set_meta(&"selected", is_selected)
	button.add_child(picture)
	var outline := _focus_outline(region.size, 4)
	button.add_child(outline)
	button.focus_entered.connect(outline.show)
	button.focus_exited.connect(outline.hide)
	button.pressed.connect(choose)
	button.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	_root.add_child(button)
	_state_tiles.append(picture)


func _refresh_new_game() -> void:
	for picture: TextureRect in _state_tiles:
		if not is_instance_valid(picture):
			continue
		var selected: Callable = picture.get_meta(&"selected")
		picture.texture = picture.get_meta(&"on") if selected.call() else picture.get_meta(&"off")
	var season_name: String = SEASON_NAMES_BY_INDEX[_new_game_season]
	if _season_icon_rect:
		_season_icon_rect.texture = load("res://assets/ui/new_game_art/icon_%s.png" % season_name.to_lower())
	if _season_label:
		_season_label.text = season_name
		_season_label.add_theme_color_override("font_color", SEASON_COLORS.get(season_name, INK))


## Knopf, dessen sichtbare Fläche unverändert aus der Vorlage stammt (mit Fokusrahmen).
func _art_region_button(button_name: String, region: Rect2) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = region.position
	button.size = region.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	var crop := AtlasTexture.new()
	crop.atlas = NEW_GAME_ART
	crop.region = region
	var surface := TextureRect.new()
	surface.texture = crop
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.size = region.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(surface)
	var outline := _focus_outline(region.size, 7)
	button.add_child(outline)
	button.focus_entered.connect(outline.show)
	button.focus_exited.connect(outline.hide)
	button.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	_root.add_child(button)
	return button


func _focus_outline(dimensions: Vector2, radius: int) -> Panel:
	var outline := Panel.new()
	outline.size = dimensions
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("fbd78a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	outline.add_theme_stylebox_override("panel", style)
	outline.visible = false
	return outline


func _build_saves() -> void:
	# Aufbau exakt nach der freigegebenen Load-Save-Vorlage: Karten mit Vorschaubild,
	# Kalender-, Jahreszeiten-, Zug-, Einwohner- und Uhrsymbol, "Load" (die neueste Reise
	# gold hervorgehoben) und "Delete", am Ende die Karte "Empty Slot" mit "New Save".
	# Rahmen, Knöpfe und Symbole stammen aus der Vorlage (tools/extract_save_cards.gd).
	var cover := _panel(Vector2(292, 245), Vector2(1110, 596))
	cover.name = "SaveListPaper"
	# Der Stempel "Good Journeys Ahead" der Vorlage liegt über dem Papier.
	var stamp := AtlasTexture.new()
	stamp.atlas = preload("res://assets/ui/menu_screens/load_save.png")
	stamp.region = Rect2(1338, 812, 92, 90)
	var stamp_rect := TextureRect.new()
	stamp_rect.texture = stamp
	stamp_rect.position = stamp.region.position
	stamp_rect.size = stamp.region.size
	stamp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(296, 249)
	scroll.size = Vector2(1106, 590)
	_style_scrollbar(scroll)
	_root.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var entries := SaveManager.list_saves(true)
	for i in entries.size():
		list.add_child(_save_card(entries[i], i == 0 and bool(entries[i]["valid"])))
	list.add_child(_empty_slot_card())
	_root.add_child(stamp_rect)
	_status = null


func _save_card(entry: Dictionary, highlight := false) -> Control:
	var card := PanelContainer.new()
	card.name = "SaveCard_" + String(entry["slot"])
	card.custom_minimum_size = Vector2(1101, 153) if highlight else Vector2(1088, 146)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if highlight else Control.SIZE_SHRINK_CENTER
	var frame := StyleBoxTexture.new()
	frame.texture = SAVE_CARD_HIGHLIGHT if highlight else SAVE_CARD
	frame.set_texture_margin_all(16)
	frame.content_margin_left = 16 if highlight else 12
	frame.content_margin_top = 11 if highlight else 8
	frame.content_margin_right = 20
	frame.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 17)
	card.add_child(row)
	var picture := PanelContainer.new()
	var picture_frame := StyleBoxFlat.new()
	picture_frame.bg_color = Color("2a1a12")
	picture_frame.border_color = Color("5b3a26")
	picture_frame.set_border_width_all(2)
	picture_frame.set_corner_radius_all(6)
	picture.add_theme_stylebox_override("panel", picture_frame)
	row.add_child(picture)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(301, 126)
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var image_path := SaveManager.save_dir + String(entry["slot"]) + ".png"
	if FileAccess.file_exists(image_path):
		var image := Image.new()
		if image.load(image_path) == OK:
			thumbnail.texture = ImageTexture.create_from_image(image)
	if thumbnail.texture == null:
		thumbnail.texture = preload("res://assets/ui/main_menu/station_background.png")
	picture.add_child(thumbnail)
	var valid := bool(entry["valid"])
	var season := String(entry.get("season", ""))
	# Spalte 1: Name, Untertitel, Tag/Uhrzeit, Jahreszeit
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var title := _label(String(entry.get("name", entry["slot"])), 25, true)
	title.add_theme_font_override("font", _serif(true))
	title.clip_text = true
	title.custom_minimum_size.x = 250
	left.add_child(title)
	if not valid:
		var damaged := _label("This save file is damaged and cannot be loaded.", 17)
		damaged.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		damaged.custom_minimum_size.x = 520
		left.add_child(damaged)
	else:
		var subtitle := _label("A %s Journey" % season if season != "" else "A Wintervale Journey", 19)
		subtitle.add_theme_font_override("font", _serif_italic())
		subtitle.add_theme_color_override("font_color", Color("c0692c"))
		left.add_child(subtitle)
		left.add_child(_spacer(6))
		left.add_child(_icon_line(SAVE_ICONS["calendar"], "Day %d  ·  %s" % [int(entry.get("day", 1)), String(entry.get("time", ""))], INK))
		if season != "":
			left.add_child(_icon_line(_season_icon(season), season, SEASON_COLORS.get(season, INK)))
	# Spalte 2: Züge, Einwohner, Spielzeit, zuletzt gespeichert
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(255, 0)
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	if valid:
		right.add_child(_spacer(8))
		var trains := int(entry.get("trains", 0))
		right.add_child(_icon_line(SAVE_ICONS["trains"], "%d Train%s Running" % [trains, "" if trains == 1 else "s"], INK, 15))
		right.add_child(_icon_line(SAVE_ICONS["population"], "Population: %d" % int(entry.get("population", 0)), INK, 15))
		var playtime := _format_playtime(float(entry["playtime_seconds"])) if entry.has("playtime_seconds") else "–"
		right.add_child(_icon_line(SAVE_ICONS["playtime"], playtime, INK, 15))
		var saved := String(entry.get("saved_at", ""))
		var saved_text := _format_saved_at(saved) if saved != "" else _format_unix(float(entry.get("saved_unix", 0.0)))
		right.add_child(_label("Last Saved: %s" % saved_text, 15))
	# Knöpfe
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	row.add_child(actions)
	var load_button := _art_button("Load", SAVE_ICONS["load"], SAVE_BUTTON_GOLD if highlight else SAVE_BUTTON_PLAIN,
		Vector2(214, 52) if highlight else Vector2(193, 46))
	load_button.disabled = not valid
	load_button.pressed.connect(func() -> void: load_requested.emit(String(entry["slot"])))
	actions.add_child(load_button)
	var delete_button := _art_button("Delete", SAVE_ICONS["delete"], SAVE_BUTTON_PLAIN, Vector2(193, 44))
	delete_button.pressed.connect(_confirm_delete.bind(String(entry["slot"]), String(entry.get("name", entry["slot"]))))
	actions.add_child(delete_button)
	return card


func _empty_slot_card() -> Control:
	var card := PanelContainer.new()
	card.name = "EmptySlot"
	card.custom_minimum_size = Vector2(1088, 114)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := StyleBoxTexture.new()
	frame.texture = SAVE_CARD_EMPTY
	frame.set_texture_margin_all(16)
	frame.content_margin_left = 12
	frame.content_margin_top = 13
	frame.content_margin_right = 14
	frame.content_margin_bottom = 11
	card.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)
	var sketch := TextureRect.new()
	sketch.texture = EMPTY_SKETCH
	sketch.custom_minimum_size = Vector2(301, 88)
	sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sketch.stretch_mode = TextureRect.STRETCH_SCALE
	row.add_child(sketch)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var title := _label("Empty Slot", 25, true)
	title.add_theme_font_override("font", _serif(true))
	words.add_child(title)
	var hint := _label("Start a new journey in Wintervale...", 18)
	hint.add_theme_font_override("font", _serif_italic())
	words.add_child(hint)
	var create := _art_button("New Save", SAVE_ICONS["plus"], SAVE_BUTTON_GOLD, Vector2(210, 54))
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(func() -> void: action_requested.emit("new_game"))
	row.add_child(create)
	return card


## Knopf mit Rahmen aus der Vorlage, Symbol und Beschriftung.
func _art_button(caption: String, icon: Texture2D, texture: Texture2D, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.icon = icon
	button.custom_minimum_size = dimensions
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _serif(true))
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_constant_override("h_separation", 22)
	button.add_theme_constant_override("icon_max_width", 34)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var frame := StyleBoxTexture.new()
	frame.texture = texture
	frame.set_texture_margin_all(10)
	frame.content_margin_left = 24
	frame.content_margin_right = 24
	var lit := frame.duplicate() as StyleBoxTexture
	lit.modulate_color = Color(1.06, 1.04, 1.0)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("f0bf6f")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", frame)
	button.add_theme_stylebox_override("disabled", frame)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("hover_pressed", lit)
	button.add_theme_stylebox_override("focus", focus)
	button.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	return button


## Schmale, dezente Bildlaufleiste in Holzbraun statt des grauen Standard-Themes.
func _style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.45, 0.3, 0.2, 0.12)
	track.set_corner_radius_all(4)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.45, 0.28, 0.17, 0.55)
	grabber.set_corner_radius_all(4)
	var grabber_lit := grabber.duplicate() as StyleBoxFlat
	grabber_lit.bg_color = Color(0.55, 0.34, 0.19, 0.8)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_lit)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_lit)


func _icon_line(icon: Texture2D, text: String, color: Color, font_size := 17) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var symbol := TextureRect.new()
	symbol.texture = icon
	symbol.custom_minimum_size = Vector2(24, 24)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(symbol)
	var words := _label(text, font_size)
	words.add_theme_color_override("font_color", color)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(words)
	return line


func _season_icon(season: String) -> Texture2D:
	match season:
		"Winter": return SAVE_ICONS["season_winter"]
		"Autumn": return SAVE_ICONS["season_autumn"]
		"Spring": return SAVE_ICONS["season_spring"]
	return load(SETTINGS_ICONS % "bloom") as Texture2D


func _serif_italic() -> Font:
	var font := _serif() as SystemFont
	font.font_italic = true
	return font


func _format_unix(unix: float) -> String:
	if unix <= 0.0:
		return "Date unknown"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return _format_saved_at(Time.get_datetime_string_from_unix_time(int(unix) + bias))


func _confirm_delete(slot: String, name_text: String) -> void:
	if _modal_dialog:
		return
	var shade := ColorRect.new()
	shade.color = Color(0.09, 0.05, 0.04, 0.62)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	var dialog := _panel(Vector2(550, 340), Vector2(570, 250))
	_modal_shade = shade
	_modal_dialog = dialog
	_root.move_child(dialog, _root.get_child_count() - 1)
	var box := _column(dialog, 22)
	box.add_child(_label("Delete this journey?", 30, true))
	box.add_child(_label("%s will be removed permanently." % name_text, 22))
	box.add_child(_spacer(16))
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var cancel := _button("Keep Save", 170)
	buttons.add_child(cancel)
	cancel.pressed.connect(_dismiss_modal)
	var confirm := _button("Delete Save", 170)
	buttons.add_child(confirm)
	confirm.pressed.connect(func() -> void:
		_modal_dialog = null
		_modal_shade = null
		SaveManager.delete_save(slot)
		build("load_save"))
	cancel.grab_focus()


func _build_settings() -> void:
	# Aufbau wie in den freigegebenen Settings-Bildern: Zeilen mit Symbol, Trennlinie,
	# Pill-Schalter, Pergament-Auswahl und goldenen Reglern. Die Symbole stammen aus
	# denselben Bildern (tools/extract_settings_icons.gd).
	var wide := page == "settings_controls"
	var gameplay := page == "settings_gameplay"
	var panel := _panel(Vector2(485, 334), Vector2(998 if wide else 540, 490 if gameplay else 441))
	var content := _column(panel, 0)
	var side: VBoxContainer = null
	match page:
		"settings_graphics":
			_add_choice(content, "Window Resolution", "resolution", ["1280x720", "1600x900", "1920x1080"], "resolution")
			_add_toggle(content, "Fullscreen", "fullscreen", "fullscreen")
			_add_toggle(content, "VSync", "vsync", "vsync")
			_add_choice(content, "Frame Rate Limit", "fps_limit", ["30", "60", "120", "0"], "day_speed")
			_add_choice(content, "Shadow Quality", "shadow_quality", ["Low", "Medium", "High"], "shadows")
			_add_toggle(content, "Bloom", "bloom", "bloom")
			_add_slider(content, "Particle Density", "particle_density", 0.25, 1.0, "particles", true)
			var preview := _panel(Vector2(1044, 522), Vector2(440, 253))
			side = _column(preview, 8)
			side.add_child(_label("Display Changes", 25, true))
			var display_note := _label("Choose Apply to see your display settings. Resolution and fullscreen changes can be kept or reverted within 10 seconds. The whole valley is always drawn in full.", 18)
			display_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			display_note.custom_minimum_size = Vector2(395, 0)
			side.add_child(display_note)
		"settings_audio":
			_add_slider(content, "Master Volume", "master_volume", 0, 100, "master")
			_add_slider(content, "Music", "music_volume", 0, 100, "music")
			_add_slider(content, "Ambient", "ambient_volume", 0, 100, "ambient")
			_add_slider(content, "Train Sounds", "train_volume", 0, 100, "train")
			_add_slider(content, "Weather", "weather_volume", 0, 100, "weather")
			_add_slider(content, "UI Sounds", "ui_volume", 0, 100, "ui_sounds")
			var preview := _panel(Vector2(1044, 564), Vector2(440, 211))
			side = _column(preview, 8)
			side.add_child(_icon_heading("Audio Preview", "music", 26))
			side.add_child(_label("Hear Wintervale's station chime.", 19))
			var sample := AudioStreamPlayer.new()
			sample.stream = SoundLibrary.get_sound("chime")
			sample.bus = &"WintervaleUI"
			preview.add_child(sample)
			var play := _button("▶  Play Sample", 230)
			side.add_child(play)
			play.pressed.connect(func() -> void: SoundLibrary.play(sample))
		"settings_controls":
			var columns := HBoxContainer.new()
			columns.add_theme_constant_override("separation", 26)
			content.add_child(columns)
			var camera := VBoxContainer.new()
			camera.add_theme_constant_override("separation", 0)
			camera.custom_minimum_size.x = 468
			columns.add_child(camera)
			camera.add_child(_icon_heading("Camera Settings", "camera", 25))
			camera.add_child(_divider(468))
			_add_slider(camera, "Camera Sensitivity", "camera_sensitivity", 0.25, 2.0, "sensitivity")
			_add_slider(camera, "Pan Speed", "pan_speed", 0.25, 2.0, "pan")
			_add_slider(camera, "Zoom Speed", "zoom_speed", 0.25, 2.0, "zoom")
			_add_toggle(camera, "Invert Camera Y-Axis", "invert_camera_y", "invert")
			var rule := ColorRect.new()
			rule.color = Color(0.45, 0.3, 0.2, 0.22)
			rule.custom_minimum_size = Vector2(1, 360)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			columns.add_child(rule)
			var keys := VBoxContainer.new()
			keys.add_theme_constant_override("separation", 0)
			keys.custom_minimum_size.x = 420
			columns.add_child(keys)
			keys.add_child(_icon_heading("Key Bindings", "keyboard", 25))
			var hint := _label("Choose a key box, then press the new key.", 17)
			hint.custom_minimum_size.x = 400
			keys.add_child(hint)
			keys.add_child(_divider(420))
			for spec in [["Build Mode", &"build_mode", "build"], ["Rotate Left", &"camera_rotate_left", "rotate"],
					["Rotate Right", &"camera_rotate_right", "rotate"], ["Open Notebook", &"toggle_notebook", "notebook"]]:
				var row := _setting_row(keys, String(spec[0]), String(spec[2]), 420)
				var key_button := _key_box(_binding_label(spec[1]))
				row.add_child(key_button)
				key_button.pressed.connect(_begin_rebind.bind(spec[1], key_button))
			side = keys
		"settings_gameplay":
			_add_toggle(content, "Autosave", "autosave", "autosave",
				"Save your journey automatically at the start of each new day.")
			_add_slider(content, "Camera Smoothing", "camera_smoothing", 0.25, 2.0, "camera_smoothing", false,
				"Adjust how smoothly the camera moves.")
			_add_slider(content, "Day Speed", "day_speed", 0.5, 2.0, "day_speed", false,
				"Controls how quickly time passes in Wintervale.")
			_add_toggle(content, "Achievement Popups", "achievement_notifications", "achievements",
				"Show a small notification when you unlock achievements.")
			_add_toggle(content, "Reduced Motion", "reduced_motion", "cozy",
				"Calmer menus and transitions with less movement.")
			var note := _panel(Vector2(1044, 522), Vector2(440, 302))
			side = _column(note, 12)
			side.add_child(_icon_heading("Your Comfortable Pace", "cozy", 25))
			var note_text := _label("Choose the day speed and motion level that make Wintervale feel like home.", 20)
			note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note_text.custom_minimum_size = Vector2(395, 0)
			side.add_child(note_text)
	# Rückmeldungen ("Settings applied.") stehen im Seitenfeld, damit die Zeilen Platz behalten.
	_status = _label("", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 395
	_status.add_theme_color_override("font_color", GOLD.darkened(0.25))
	(side if side else content).add_child(_status)


func _add_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float,
		icon := "", percent := false, description := "") -> void:
	var row := _setting_row(parent, title, icon, -1.0, description)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(170 if description != "" else 190, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1 if maximum == 100 else 0.05
	slider.value = float(draft_settings[key])
	var track := StyleBoxFlat.new()
	track.bg_color = Color("dcd1c3")
	track.border_color = Color("b9a58f")
	track.set_border_width_all(1)
	track.set_corner_radius_all(5)
	track.set_content_margin_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c48b48")
	fill.border_color = Color("a8702f")
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(5)
	fill.set_content_margin_all(4)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := preload("res://assets/ui/achievements/slider_knob.svg")
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	row.add_child(slider)
	var readout := _label(_number_text(slider.value, maximum, percent), 19)
	readout.custom_minimum_size = Vector2(58, 32)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void:
		draft_settings[key] = value
		readout.text = _number_text(value, maximum, percent))


func _add_toggle(parent: VBoxContainer, title: String, key: String, icon := "", description := "") -> void:
	var row := _setting_row(parent, title, icon, -1.0, description)
	var toggle := PillSwitch.new()
	toggle.button_pressed = bool(draft_settings[key])
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	row.add_child(toggle)
	var state := _label("On" if toggle.button_pressed else "Off", 19)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	toggle.toggled.connect(func(value: bool) -> void:
		draft_settings[key] = value
		state.text = "On" if value else "Off")


func _add_choice(parent: VBoxContainer, title: String, key: String, choices: Array, icon := "") -> void:
	var row := _setting_row(parent, title, icon)
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(250, 36)
	select.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_option(select)
	for choice in choices:
		select.add_item(_choice_label(String(choice)))
	var value := str(draft_settings[key])
	var index := choices.find(value)
	select.select(maxi(index, 0))
	row.add_child(select)
	select.item_selected.connect(func(selected: int) -> void:
		draft_settings[key] = int(choices[selected]) if key == "fps_limit" else String(choices[selected]))


## Anzeigetext einer Auswahl (die gespeicherten Werte bleiben unverändert).
func _choice_label(value: String) -> String:
	if value == "0":
		return "Unlimited"
	if value.contains("x"):
		return value.replace("x", " × ")
	return value


## Eine Einstellungszeile: Symbol, Titel (optional mit Beschreibung darunter), Steuerelement.
## Unter jeder Zeile liegt eine feine Trennlinie wie in der Vorlage.
func _setting_row(parent: VBoxContainer, title: String, icon := "", width := -1.0, description := "") -> HBoxContainer:
	var compact := page != "settings_controls"
	var row_width := width if width > 0.0 else (500.0 if compact else 468.0)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	parent.add_child(block)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(row_width, 44 if description != "" else 52)
	row.add_theme_constant_override("separation", 12)
	block.add_child(row)
	var symbol := TextureRect.new()
	symbol.custom_minimum_size = Vector2(34, 34)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		symbol.texture = load(SETTINGS_ICONS % icon) as Texture2D
	row.add_child(symbol)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var caption := _label(title, 20 if description != "" else 19, description != "")
	words.add_child(caption)
	if description != "":
		# Wie in der Vorlage: Beschreibung als eigene Zeile unter Titel und Steuerelement
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 46)
		margin.add_theme_constant_override("margin_bottom", 8)
		block.add_child(margin)
		var detail := _label(description, 15)
		detail.custom_minimum_size.x = row_width - 46
		margin.add_child(detail)
	block.add_child(_divider(row_width))
	return row


func _divider(width: float) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.45, 0.3, 0.2, 0.18)
	line.custom_minimum_size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _icon_heading(title: String, icon: String, font_size: int) -> HBoxContainer:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	heading.custom_minimum_size.y = 48
	var symbol := TextureRect.new()
	symbol.texture = load(SETTINGS_ICONS % icon) as Texture2D
	symbol.custom_minimum_size = Vector2(34, 34)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(symbol)
	var caption := _label(title, font_size, true)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(caption)
	return heading


## Tastenfeld wie in der Vorlage: helles Pergament mit feinem Rahmen.
func _key_box(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(140, 38)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _serif())
	button.add_theme_font_size_override("font_size", 20)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f6ecdd") if state == "normal" else Color("fff4e2")
		style.border_color = Color("e0a95c") if state == "focus" else Color("a98567")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	return button


func _begin_rebind(action: StringName, button: Button) -> void:
	_rebind_action = action
	_rebind_button = button
	button.text = "Press a key..."
	_show_status("Press Escape to cancel. Choose Apply to save the new key.")


func _input(event: InputEvent) -> void:
	if _rebind_action == &"" or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_rebind_button.text = _binding_label(_rebind_action)
		_rebind_action = &""
		_show_status("Key change cancelled.")
		return
	var error := _binding_conflict(_rebind_action, event.physical_keycode)
	if error != "":
		_show_status(error)
		return
	_pending_bindings[_rebind_action] = event.physical_keycode
	_rebind_button.text = _binding_label(_rebind_action)
	_rebind_action = &""
	_show_status("Key selected. Choose Apply to save it.")


func _binding_label(action: StringName) -> String:
	var code := KEY_NONE
	if _pending_bindings.has(action):
		code = _pending_bindings[action]
	elif _restore_bindings_pending:
		code = InputConfig.KEY_BINDINGS[action][0]
	if code == KEY_NONE:
		return InputConfig.get_action_label(action)
	var key := InputEventKey.new()
	key.physical_keycode = code
	return InputConfig.event_label(key)


func _binding_conflict(action: StringName, code: Key) -> String:
	if code == KEY_NONE:
		return "That key cannot be used."
	for other: StringName in InputMap.get_actions():
		if other == action:
			continue
		var other_code := KEY_NONE
		if _pending_bindings.has(other):
			other_code = _pending_bindings[other]
		elif _restore_bindings_pending and InputConfig.KEY_BINDINGS.has(other):
			for default_code in InputConfig.KEY_BINDINGS[other]:
				if default_code == code:
					other_code = code
					break
		else:
			for bound in InputMap.action_get_events(other):
				if bound is InputEventKey and not bound.ctrl_pressed and not bound.alt_pressed \
						and not bound.shift_pressed and not bound.meta_pressed \
						and (bound.physical_keycode == code or
							(bound.physical_keycode == KEY_NONE and bound.keycode == code)):
					other_code = code
					break
		if other_code == code:
			return "Key already used for %s." % String(other).replace("_", " ").capitalize()
	return ""


func _build_achievements() -> void:
	# Aufbau exakt nach der freigegebenen Achievements-Vorlage: Die Zeile "Total Progress"
	# bleibt aus dem Bild erhalten (nur Zahlen, Balken und Prozent sind live), darunter
	# Kategorien mit Symbol, Motto und Zähler und je drei Karten pro Reihe. Kartenrahmen,
	# Häkchen und Symbole stammen aus der Vorlage (tools/extract_achievement_cards.gd).
	var saves := SaveManager.list_saves()
	if achievement_slot == "" and not saves.is_empty():
		achievement_slot = String(saves[0]["slot"])
	_achievement_state = {}
	if achievement_slot != "":
		_achievement_state = SaveManager.read_save_data(achievement_slot).get("objects", {}).get(Achievements.SAVE_ID, {})
	var total := Achievements.DEFINITIONS.size()
	var unlocked := _achievement_unlocks().size()
	# Total Progress: gemalte Beispielwerte mit Papier abdecken, echte Werte darüber
	_paper_patch(Rect2(560, 270, 190, 24), Color("f8d6ad"))
	_paper_patch(Rect2(780, 254, 480, 30), Color("f5d3a9"))
	var summary := _label("%d / %d Achievements" % [unlocked, total], 17)
	summary.position = Vector2(563, 270)
	_root.add_child(summary)
	var total_bar := _progress_bar(float(unlocked), float(total), 388, 18, true)
	total_bar.position = Vector2(789, 259)
	_root.add_child(total_bar)
	var percent := _label("%d%%" % roundi(100.0 * unlocked / maxf(total, 1)), 24, true)
	percent.position = Vector2(1180, 250)
	percent.size = Vector2(70, 34)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(percent)

	var panel := _panel(Vector2(466, 305), Vector2(816, 568))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(776, 528)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(scroll)
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if saves.is_empty():
		list.add_child(_label("Start a journey to record achievements.", 18))
	for category: Dictionary in ACHIEVEMENT_CATEGORIES:
		var category_name: String = category["name"]
		var members := Achievements.DEFINITIONS.filter(func(d: Dictionary) -> bool: return d["category"] == category_name)
		var done := members.filter(func(d: Dictionary) -> bool: return _achievement_unlocks().has(d["id"])).size()
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 12)
		header.custom_minimum_size = Vector2(760, 42)
		list.add_child(header)
		var symbol := TextureRect.new()
		symbol.texture = load(SETTINGS_ICONS % String(category["icon"])) as Texture2D
		symbol.custom_minimum_size = Vector2(60, 34)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(symbol)
		var title := _label(category_name, 26, true)
		title.add_theme_font_override("font", _serif(true))
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(title)
		var motto := _label(String(category["motto"]), 15)
		motto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		motto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(motto)
		var count := _label("%d / %d" % [done, members.size()], 19, true)
		count.add_theme_font_override("font", _serif(true))
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(count)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		list.add_child(grid)
		for definition: Dictionary in members:
			grid.add_child(_achievement_card(definition))
		list.add_child(_spacer(4))
	# Wahl der Reise nur, wenn es mehrere gibt – als Pergament-Auswahl unten auf dem Holz
	if saves.size() > 1:
		var journey := OptionButton.new()
		journey.name = "JourneySelect"
		_style_option(journey)
		journey.position = Vector2(700, 884)
		journey.size = Vector2(300, 38)
		for entry in saves:
			journey.add_item(String(entry["name"]))
			journey.set_item_metadata(journey.item_count - 1, String(entry["slot"]))
			if entry["slot"] == achievement_slot:
				journey.select(journey.item_count - 1)
		_root.add_child(journey)
		journey.item_selected.connect(func(index: int) -> void:
			achievement_slot = String(journey.get_item_metadata(index))
			build("achievements"))
	_build_achievement_detail_card()
	var first := String(Achievements.DEFINITIONS[0]["id"])
	for definition in Achievements.DEFINITIONS:
		if _achievement_unlocks().has(definition["id"]):
			first = String(definition["id"])
			break
	_show_achievement_detail(first)


## Eine Karte wie in der Vorlage: Siegel links, Titel, Beschreibung und darunter
## Häkchen (freigeschaltet) oder Fortschrittsbalken mit Zahl (gesperrt).
func _achievement_card(definition: Dictionary) -> Button:
	var id: String = definition["id"]
	var done := _achievement_unlocks().has(id)
	var target := float(definition["target"])
	var value := minf(float(_achievement_progress().get(id, 0)), target)
	var card := Button.new()
	card.name = "Card_" + id
	card.custom_minimum_size = Vector2(248, 125)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = String(definition["name"])
	var frame := StyleBoxTexture.new()
	frame.texture = CARD_UNLOCKED if done else CARD_LOCKED
	frame.set_texture_margin_all(14)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(state, frame)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("f0bf6f")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(6)
	card.add_theme_stylebox_override("focus", focus)
	card.pressed.connect(_show_achievement_detail.bind(id))
	card.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	var badge := TextureRect.new()
	badge.texture = _badge(id)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.position = Vector2(12, 18)
	badge.size = Vector2(88, 88)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not done:
		badge.material = LOCKED_BADGE
	card.add_child(badge)
	var title := _label(String(definition["name"]), 17, true)
	title.add_theme_font_override("font", _serif(true))
	title.position = Vector2(106, 14)
	title.size = Vector2(134, 24)
	# Längere Namen etwas kleiner setzen statt abschneiden
	var font := _serif(true)
	var font_size := 17
	while font_size > 13 and font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 134.0:
		font_size -= 1
	title.add_theme_font_size_override("font_size", font_size)
	card.add_child(title)
	var description := _label(String(definition["description"]), 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.position = Vector2(106, 38)
	description.size = Vector2(134, 52)
	card.add_child(description)
	if done:
		var check := TextureRect.new()
		check.texture = CHECK_ICON
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.position = Vector2(116, 92)
		check.size = Vector2(24, 24)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(check)
	else:
		var bar := _progress_bar(value, target, 70, 9)
		bar.position = Vector2(108, 101)
		card.add_child(bar)
		var amount := _label("%d / %d" % [int(value), int(target)], 14, true)
		amount.add_theme_font_override("font", _serif(true))
		amount.position = Vector2(180, 94)
		amount.size = Vector2(58, 22)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(amount)
	return card


## Rechte Detailkarte: Bilderrahmen, Zitat und Brückenskizze bleiben aus der Vorlage.
## Live sind das Siegel (über dem gemalten) sowie Titel, Beschreibung und Status.
func _build_achievement_detail_card() -> void:
	var paper := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("eacaac"), Color("e5c1a0")])
	paper.gradient = gradient
	paper.fill_to = Vector2(1, 0)
	var cover := TextureRect.new()
	cover.texture = paper
	cover.position = Vector2(1352, 520)
	cover.size = Vector2(222, 96)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cover)
	_detail = VBoxContainer.new()
	_detail.name = "AchievementDetail"
	_detail.position = Vector2(1352, 324)
	_detail.size = Vector2(222, 320)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_detail)


func _show_achievement_detail(id: String) -> void:
	if _detail == null:
		return
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var definition := Achievements.get_definition(id)
	var done := _achievement_unlocks().has(id)
	# Siegel genau über dem gemalten (Mitte 1462|412, Radius ≈ 81)
	var badge := TextureRect.new()
	badge.texture = _badge(id)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(222, 176)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not done:
		badge.material = LOCKED_BADGE
	_detail.add_child(badge)
	_detail.add_child(_spacer(20))
	var title := _label(String(definition["name"]), 24, true)
	title.add_theme_font_override("font", _serif(true))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = 222
	_detail.add_child(title)
	var description := _label(String(definition["description"]), 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size.x = 200
	_detail.add_child(description)
	var target := float(definition["target"])
	var value := minf(float(_achievement_progress().get(id, 0)), target)
	var state := "Unlocked %s" % _format_saved_at(String(_achievement_unlocks()[id])) if done \
		else "Progress %d / %d" % [int(value), int(target)]
	var status := _label(state, 14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size.x = 222
	_detail.add_child(status)


func _achievement_progress() -> Dictionary:
	return _achievement_state.get("progress", {})


func _achievement_unlocks() -> Dictionary:
	return _achievement_state.get("unlocked", {})


## Fortschrittsbalken wie in der Achievements-Vorlage: runde Enden, goldene Füllung
## auf graubrauner Bahn (der große Gesamtbalken etwas kräftiger).
func _progress_bar(value: float, maximum: float, width: float, height: float, large := false) -> Control:
	var bar := ThinBar.new()
	bar.ratio = clampf(value / maxf(maximum, 0.001), 0.0, 1.0)
	bar.track = Color("a07e64") if large else Color("a08571")
	bar.custom_minimum_size = Vector2(width, height)
	bar.size = Vector2(width, height)
	return bar


## Deckt gemalte Beispielwerte mit der Papierfarbe der Vorlage ab.
func _paper_patch(area: Rect2, color: Color) -> void:
	var patch := ColorRect.new()
	patch.color = color
	patch.position = area.position
	patch.size = area.size
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(patch)


## "2026-09-29T23:49:17" → "Sep 29, 2026 · 11:49 PM" (Schreibweise der Vorlagen).
func _format_saved_at(stamp: String) -> String:
	var parts := stamp.replace(" ", "T").split("T")
	if parts.size() < 2:
		return stamp
	var date := parts[0].split("-")
	var clock := parts[1].split(":")
	if date.size() < 3 or clock.size() < 2:
		return stamp
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var hour := int(clock[0])
	return "%s %d, %s · %d:%s %s" % [months[clampi(int(date[1]) - 1, 0, 11)], int(date[2]), date[0],
		(hour + 11) % 12 + 1, clock[1], "PM" if hour >= 12 else "AM"]


## Credits exakt wie die Vorlage: Überschriften, Symbole und Skizzen kommen aus dem Bild
## (credits_clean.png ohne die Beispielnamen), die echten Namen stehen an deren Stelle.
func _build_credits() -> void:
	for entry: Array in CREDITS:
		var names := _label("\n".join(entry[1]), 19)
		names.add_theme_color_override("font_color", Color("4b3025"))
		names.add_theme_constant_override("line_spacing", 1)
		names.position = entry[0]
		names.size = Vector2(300, 150)
		_root.add_child(names)


## Auswahlfeld wie in den Settings-Vorlagen: helles Pergament, feiner Rahmen, Winkel rechts.
## Auch die aufklappende Liste bekommt Pergament statt des dunklen Standard-Themes.
func _style_option(select: OptionButton) -> void:
	select.add_theme_font_override("font", _serif())
	select.add_theme_font_size_override("font_size", 20)
	for key: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		select.add_theme_color_override(key, INK)
	select.add_theme_icon_override("arrow", CHEVRON)
	select.add_theme_constant_override("arrow_margin", 12)
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f6ecdd") if state == "normal" else Color("fff4e2")
		style.border_color = Color("e0a95c") if state == "focus" else Color("a98567")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 10
		select.add_theme_stylebox_override(state, style)
	var popup := select.get_popup()
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = Color("f6ecdd")
	sheet.border_color = Color("a98567")
	sheet.set_border_width_all(1)
	sheet.set_corner_radius_all(4)
	sheet.set_content_margin_all(6)
	sheet.shadow_color = Color(0.15, 0.07, 0.03, 0.35)
	sheet.shadow_size = 6
	popup.add_theme_stylebox_override("panel", sheet)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("ecc98f")
	hover.set_corner_radius_all(3)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_font_override("font", _serif())
	popup.add_theme_font_size_override("font_size", 20)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)
	popup.add_theme_constant_override("v_separation", 8)


func _panel(at: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = dimensions
	panel.custom_minimum_size = dimensions
	var crop := AtlasTexture.new()
	crop.atlas = PARCHMENT_TEXTURE
	crop.region = Rect2(234, 362, 680, 700)
	var paper := StyleBoxTexture.new()
	paper.texture = crop
	paper.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", paper)
	_root.add_child(panel)
	return panel


func _paper_style(card := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f2d7b7") if card else PAPER
	style.border_color = Color("9e6c49")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(13 if card else 19)
	style.shadow_color = Color(0.12, 0.06, 0.02, 0.26)
	style.shadow_size = 6
	return style


func _column(panel: PanelContainer, gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	panel.add_child(column)
	return column


func _label(caption: String, font_size: int, bold := false) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", _serif())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK if bold else MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _serif(bold := false) -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
	if bold:
		font.font_weight = 700
	return font


func _button(caption: String, width: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(width, 42)
	button.add_theme_font_override("font", _serif())
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_hover_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("focus", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	button.add_theme_stylebox_override("hover_pressed", _button_style(true))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	return button


func _button_style(highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffe4a7") if highlight else Color("e7bc8f")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _show_status(message: String) -> void:
	if _status:
		_status.text = message


func _number_text(value: float, maximum: float, percent := false) -> String:
	if percent:
		return "%d%%" % roundi(value * 100.0)
	return "%d%%" % int(value) if maximum == 100 else "%.2f" % value


func _format_playtime(seconds: float) -> String:
	return "%dh %02dm" % [int(seconds / 3600), int(seconds / 60) % 60]


func _badge(id: String) -> Texture2D:
	return load("res://assets/ui/achievements/%s.svg" % id) as Texture2D
