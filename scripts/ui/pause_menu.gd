## Pausenmenü im Spiel (Esc, wenn gerade nichts anderes Esc braucht).
##
## Gestaltung wie das Hauptmenü: Holzlogo über dem Pergament, echte Buttons mit
## Symbol, Auswahlrahmen und Papiergeräusch. Solange das Menü offen ist, steht
## die ganze Welt still (SceneTree.paused) – Züge, Bewohner und Uhr warten.
## Einstellungen öffnen die vorhandenen Settings-Seiten (MenuGallery) und
## wirken sofort. Hauptmenü und Beenden fragen vorher, ob gespeichert werden soll.
class_name PauseMenu
extends CanvasLayer

signal opened
signal closed

const DESIGN_SIZE := Vector2(1672.0, 941.0)
const LOGO := preload("res://assets/ui/main_menu/wood_logo.png")
const PARCHMENT := preload("res://assets/ui/main_menu/parchment_panel.png")
const SELECTION := preload("res://assets/ui/main_menu/selection_frame.svg")
const GALLERY_SCENE := preload("res://scenes/ui/menu_gallery.tscn")
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const ENTRIES := [
	{"id": "resume", "text": "Weiterspielen", "icon": preload("res://assets/ui/main_menu/icons/continue_train.svg")},
	{"id": "save", "text": "Spiel speichern", "icon": preload("res://assets/ui/main_menu/icons/save_journal.svg")},
	{"id": "settings", "text": "Einstellungen", "icon": preload("res://assets/ui/main_menu/icons/settings_gear.svg")},
	{"id": "main_menu", "text": "Hauptmenü", "icon": preload("res://assets/ui/main_menu/icons/station_home.svg")},
	{"id": "quit", "text": "Spiel beenden", "icon": preload("res://assets/ui/main_menu/icons/quit_door.svg")},
]
const INK := Color("4b3025")
const GOLD := Color("d7924a")
const PANEL_POS := Vector2(586.0, 250.0)

var is_open := false
var _shade: ColorRect
var _canvas: Control
var _panel: Control
var _buttons: Array[Button] = []
var _status: Label
var _dialog: PanelContainer
var _gallery: Control
var _sound: AudioStreamPlayer
var _was_paused_clock := false
var _busy := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.color = Color(0.05, 0.035, 0.05, 0.58)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.name = "ReferenceCanvas"
	_canvas.size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_panel = Control.new()
	_panel.name = "PausePanel"
	_panel.size = DESIGN_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_panel)
	var paper := AtlasTexture.new()
	paper.atlas = PARCHMENT
	paper.region = Rect2(0, 260, 1172, 1082)
	_add_image(paper, PANEL_POS, Vector2(500, 580), "Parchment")
	_add_image(LOGO, Vector2(560, 15), Vector2(552, 263), "WoodLogo")
	for i in ENTRIES.size():
		_add_entry(i)
	_status = Label.new()
	_status.name = "Status"
	_status.position = PANEL_POS + Vector2(40, 405)
	_status.size = Vector2(420, 40)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", _serif())
	_status.add_theme_font_size_override("font_size", 21)
	_status.add_theme_color_override("font_color", Color("7a5238"))
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_status)
	_sound = AudioStreamPlayer.new()
	_sound.stream = SoundLibrary.get_sound("page")
	_sound.bus = &"WintervaleUI"
	add_child(_sound)
	get_viewport().size_changed.connect(_rescale)
	_rescale()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	# Die Settings-Seiten behandeln Esc selbst (MenuGallery schließt sich dann).
	if _gallery and _gallery.visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"release_mouse"):
		if _dialog:
			_close_dialog()
		else:
			close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open or _busy:
		return
	is_open = true
	visible = true
	_status.text = ""
	_panel.visible = true
	_was_paused_clock = WorldClock.paused
	WorldClock.paused = true
	get_tree().paused = true
	GameInput.capture_mouse(false)
	SoundLibrary.play(_sound)
	_fade(_canvas, 1.0)
	_buttons[0].grab_focus.call_deferred()
	opened.emit()


func close() -> void:
	if not is_open or _busy:
		return
	_close_dialog()
	if _gallery:
		_gallery.visible = false
	is_open = false
	visible = false
	get_tree().paused = false
	WorldClock.paused = _was_paused_clock
	SoundLibrary.play(_sound)
	closed.emit()


func _activate(id: String) -> void:
	if _busy or _dialog:
		return
	match id:
		"resume":
			close()
		"save":
			await save_now()
		"settings":
			_open_settings()
		"main_menu":
			_ask("Zurück zum Hauptmenü?", "Nicht gespeicherte Fortschritte dieser Reise gehen sonst verloren.",
				"Speichern & Hauptmenü", "Ohne Speichern", _leave.bind(false))
		"quit":
			_ask("Spiel beenden?", "Nicht gespeicherte Fortschritte dieser Reise gehen sonst verloren.",
				"Speichern & beenden", "Ohne Speichern", _leave.bind(true))


## Speichert die Reise. Das Menü wird dafür kurz ausgeblendet, damit das
## Vorschaubild die Welt zeigt und nicht das Pausenmenü.
func save_now() -> bool:
	_busy = true
	visible = false
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var ok := SaveManager.save_game(SaveManager.active_slot)
	visible = true
	_busy = false
	_status.text = ("Gespeichert um %s Uhr (Spielzeit)" % WorldClock.get_time_string()) if ok \
		else "Speichern fehlgeschlagen – bitte erneut versuchen."
	return ok


func _leave(save_first: bool, to_desktop: bool) -> void:
	# Dialog ohne Fokuswechsel schließen – die Welt wird gleich entladen.
	if _dialog:
		_dialog.queue_free()
		_dialog = null
	if save_first and not await save_now():
		_buttons[0].grab_focus()
		return
	_busy = true
	get_tree().paused = false
	WorldClock.paused = false
	if to_desktop:
		get_tree().quit()
		return
	# Weltbezogene Autoload-Zustände gehören nicht ins Hauptmenü mit.
	Achievements.detach_world()
	get_tree().change_scene_to_file(MAIN_MENU)


func _open_settings() -> void:
	if _gallery == null:
		_gallery = GALLERY_SCENE.instantiate()
		_gallery.process_mode = Node.PROCESS_MODE_ALWAYS
		_canvas.add_child(_gallery)
		_gallery.connect("closed", _on_settings_closed)
	_panel.visible = false
	_gallery.call("show_page", "settings_graphics")


func _on_settings_closed() -> void:
	_panel.visible = true
	_status.text = ""
	_buttons[2].grab_focus()


func get_entry_button(id: String) -> Button:
	for i in ENTRIES.size():
		if ENTRIES[i]["id"] == id:
			return _buttons[i]
	return null


# --- Bestätigungsdialog -------------------------------------------------------------

func _ask(title: String, text: String, save_label: String, discard_label: String, action: Callable) -> void:
	_dialog = PanelContainer.new()
	_dialog.name = "ConfirmDialog"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efdcbc")
	style.border_color = Color("9c6a3a")
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(26)
	style.shadow_color = Color(0.05, 0.02, 0.01, 0.55)
	style.shadow_size = 18
	_dialog.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_dialog.add_child(column)
	var heading := _text(title, 32, INK)
	column.add_child(heading)
	var body := _text(text, 21, Color("6e4a32"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 0)
	column.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var save_button := _dialog_button(save_label, true)
	save_button.pressed.connect(func() -> void: action.call(true))
	row.add_child(save_button)
	var discard := _dialog_button(discard_label, false)
	discard.pressed.connect(func() -> void: action.call(false))
	row.add_child(discard)
	var cancel := _dialog_button("Abbrechen", false)
	cancel.pressed.connect(_close_dialog)
	row.add_child(cancel)
	for button: Button in [save_button, discard, cancel]:
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	# Größe folgt dem Inhalt; mittig über dem Pergament.
	_dialog.reset_size()
	_dialog.position = ((DESIGN_SIZE - _dialog.get_combined_minimum_size()) * 0.5).round()
	cancel.grab_focus.call_deferred()
	SoundLibrary.play(_sound)


func _close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null
		if is_open and _panel.visible:
			_buttons[0].grab_focus.call_deferred()


func _dialog_button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 54)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _serif())
	button.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		var lit := state != "normal"
		style.bg_color = Color("6a4027") if primary else Color("8a5a36")
		if lit:
			style.bg_color = style.bg_color.lightened(0.12)
		style.border_color = Color("f1c47d") if state == "focus" else Color("c28a45")
		style.set_border_width_all(3 if state == "focus" else 2)
		style.set_corner_radius_all(7)
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(state, style)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, Color("fbecd2"))
	return button


# --- Aufbau ---------------------------------------------------------------------------

func _add_entry(index: int) -> void:
	var entry: Dictionary = ENTRIES[index]
	var button := Button.new()
	button.name = String(entry["id"]).to_pascal_case()
	button.position = PANEL_POS + Vector2(38, 50 + index * 70)
	button.size = Vector2(413, 60)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var clear := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, clear)
	button.pressed.connect(_activate.bind(String(entry["id"])))
	button.mouse_entered.connect(button.grab_focus)
	_panel.add_child(button)
	_buttons.append(button)
	var selection := TextureRect.new()
	selection.texture = SELECTION
	selection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selection.stretch_mode = TextureRect.STRETCH_SCALE
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection.size = button.size
	selection.visible = false
	button.add_child(selection)
	var icon := TextureRect.new()
	icon.texture = entry["icon"]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(29, 10)
	icon.size = Vector2(42, 42)
	button.add_child(icon)
	var title := _text(String(entry["text"]), 29, INK)
	title.position = Vector2(104, 5)
	title.size = Vector2(280, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(title)
	var arrow := _text("›", 43, INK)
	arrow.position = Vector2(375, 4)
	arrow.size = Vector2(28, 52)
	arrow.visible = false
	button.add_child(arrow)
	# Gebundene Methoden statt Lambdas: beim Freigeben automatisch getrennt.
	for part: CanvasItem in [selection, arrow]:
		button.focus_entered.connect(part.show)
		button.focus_exited.connect(part.hide)
	if index < ENTRIES.size() - 1:
		var separator := ColorRect.new()
		separator.color = Color(0.43, 0.28, 0.20, 0.18)
		separator.position = Vector2(19, 65)
		separator.size = Vector2(365, 1)
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(separator)


func _add_image(texture: Texture2D, pos: Vector2, dimensions: Vector2, label: String) -> void:
	var image := TextureRect.new()
	image.name = label
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.position = pos
	image.size = dimensions
	_panel.add_child(image)


func _text(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", _serif())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _serif() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
	return font


func _rescale() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(viewport.x / DESIGN_SIZE.x, viewport.y / DESIGN_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (viewport - DESIGN_SIZE * factor) * 0.5


func _fade(target: CanvasItem, to: float) -> void:
	if GameSettings.get_pref("reduced_motion"):
		target.modulate.a = to
		return
	target.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(target, "modulate:a", to, 0.18).set_trans(Tween.TRANS_SINE)
