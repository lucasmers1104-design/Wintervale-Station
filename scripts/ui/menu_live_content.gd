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


func _build_new_game() -> void:
	var heading := Panel.new()
	heading.position = Vector2(734, 159)
	heading.size = Vector2(214, 52)
	var heading_crop := AtlasTexture.new()
	heading_crop.atlas = PARCHMENT_TEXTURE
	heading_crop.region = Rect2(260, 395, 640, 115)
	var heading_paper := StyleBoxTexture.new()
	heading_paper.texture = heading_crop
	heading.add_theme_stylebox_override("panel", heading_paper)
	_root.add_child(heading)
	var heading_text := _label("New Game", 33, true)
	heading_text.size = heading.size
	heading_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(heading_text)
	var panel := _panel(Vector2(300, 250), Vector2(1090, 585))
	var content := _column(panel, 8)
	content.add_child(_label("Begin a New Journey", 34, true))
	content.add_child(_label("Choose a name and a starting season for your own Wintervale.", 23))
	content.add_child(_spacer(18))
	content.add_child(_label("Journey Name", 25))
	var name_input := LineEdit.new()
	name_input.name = "JourneyName"
	name_input.text = "My Wintervale"
	name_input.max_length = 48
	name_input.add_theme_font_override("font", _serif())
	name_input.add_theme_font_size_override("font_size", 24)
	name_input.add_theme_color_override("font_color", INK)
	name_input.add_theme_stylebox_override("normal", _button_style(false))
	name_input.add_theme_stylebox_override("focus", _button_style(true))
	name_input.custom_minimum_size = Vector2(600, 48)
	content.add_child(name_input)
	content.add_child(_spacer(13))
	content.add_child(_label("Starting Season", 25))
	var seasons := OptionButton.new()
	for season_name in ["Spring", "Summer", "Autumn", "Winter"]:
		seasons.add_item(season_name)
	seasons.select(3)
	seasons.custom_minimum_size = Vector2(330, 48)
	_style_option(seasons)
	content.add_child(seasons)
	content.add_child(_spacer(13))
	content.add_child(_label("Scenario  ·  Wintervale Valley", 25))
	content.add_child(_label("The available starter world. More destinations will appear when they are playable.", 19))
	content.add_child(_spacer(20))
	var start := _button("Start Your Journey", 250)
	content.add_child(start)
	start.pressed.connect(func() -> void:
		var name_text := name_input.text.strip_edges()
		if name_text.is_empty():
			_show_status("Please enter a name for your journey.")
			return
		start_requested.emit(name_text, seasons.selected))
	_status = _label("", 20)
	content.add_child(_status)
	name_input.grab_focus()


func _build_saves() -> void:
	var panel := _panel(Vector2(297, 250), Vector2(1096, 586))
	var content := _column(panel, 5)
	content.add_child(_label("Your Journeys", 32, true))
	var entries := SaveManager.list_saves(true)
	var valid_count := SaveManager.list_saves().size()
	content.add_child(_label("%d saved journey%s" % [valid_count, "" if valid_count == 1 else "s"], 19))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1030, 400)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)
	if entries.is_empty():
		var empty := HBoxContainer.new()
		empty.add_theme_constant_override("separation", 23)
		list.add_child(empty)
		var illustration := TextureRect.new()
		illustration.texture = preload("res://assets/ui/main_menu/station_background.png")
		illustration.custom_minimum_size = Vector2(320, 218)
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		empty.add_child(illustration)
		var message := VBoxContainer.new()
		message.add_theme_constant_override("separation", 15)
		empty.add_child(message)
		message.add_child(_label("No saved journeys yet", 29, true))
		message.add_child(_label("A new story is waiting at Wintervale Station.", 21))
		message.add_child(_label("Select New Journey below to begin.", 19))
	for entry in entries:
		list.add_child(_save_card(entry))
	var create := _button("＋  New Journey", 240)
	content.add_child(create)
	create.pressed.connect(func() -> void: action_requested.emit("new_game"))
	_status = _label("", 19)
	content.add_child(_status)


func _save_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1010, 131)
	card.add_theme_stylebox_override("panel", _paper_style(true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 17)
	card.add_child(row)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(206, 116)
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var image_path := SaveManager.SAVE_DIR + String(entry["slot"]) + ".png"
	if FileAccess.file_exists(image_path):
		var image := Image.new()
		if image.load(image_path) == OK:
			thumbnail.texture = ImageTexture.create_from_image(image)
	if thumbnail.texture == null:
		thumbnail.texture = preload("res://assets/ui/main_menu/station_background.png")
	row.add_child(thumbnail)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(525, 105)
	row.add_child(info)
	info.add_child(_label(String(entry.get("name", entry["slot"])), 26, true))
	if bool(entry["valid"]):
		info.add_child(_label("Day %s  ·  %s  ·  %s" % [entry.get("day", "?"), entry.get("season", "Season unknown"), entry.get("time", "")], 19))
		var playtime := _format_playtime(float(entry["playtime_seconds"])) if entry.has("playtime_seconds") else "Unknown"
		info.add_child(_label("Population %s  ·  Playtime %s" % [entry.get("population", "Unknown"), playtime], 18))
		info.add_child(_label("Saved %s" % String(entry.get("saved_at", "Date unknown")), 17))
	else:
		info.add_child(_label("This save file is damaged and cannot be loaded.", 19))
	var actions := VBoxContainer.new()
	row.add_child(actions)
	var load_button := _button("Load", 150)
	load_button.disabled = not bool(entry["valid"])
	load_button.pressed.connect(func() -> void: load_requested.emit(String(entry["slot"])))
	actions.add_child(load_button)
	var delete_button := _button("Delete", 150)
	delete_button.pressed.connect(_confirm_delete.bind(String(entry["slot"]), String(entry.get("name", entry["slot"]))))
	actions.add_child(delete_button)
	return card


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
	var wide := page == "settings_controls"
	var panel := _panel(Vector2(485, 334), Vector2(998 if wide else 540, 441 if page != "settings_gameplay" else 490))
	var content := _column(panel, 5)
	var section := page.trim_prefix("settings_").capitalize()
	content.add_child(_label(section + " Preferences", 29 if not wide else 32, true))
	match page:
		"settings_graphics":
			_add_choice(content, "Window Resolution", "resolution", ["1280x720", "1600x900", "1920x1080"])
			_add_toggle(content, "Fullscreen", "fullscreen")
			_add_toggle(content, "VSync", "vsync")
			_add_choice(content, "Frame Rate Limit", "fps_limit", ["30", "60", "120", "0"])
			var support := _label("Renderer effects are unavailable in this build.", 18)
			support.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			support.custom_minimum_size.x = 480
			content.add_child(support)
			var preview := _panel(Vector2(1044, 522), Vector2(440, 253))
			var preview_content := _column(preview, 5)
			preview_content.add_child(_label("Display Changes", 25, true))
			var display_note := _label("Choose Apply to see your display settings. Resolution and fullscreen changes can be kept or reverted within 10 seconds.", 19)
			display_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			display_note.custom_minimum_size = Vector2(390, 175)
			preview_content.add_child(display_note)
		"settings_audio":
			_add_slider(content, "Master Volume", "master_volume", 0, 100)
			_add_slider(content, "Music", "music_volume", 0, 100)
			_add_slider(content, "Ambient", "ambient_volume", 0, 100)
			_add_slider(content, "Train Sounds", "train_volume", 0, 100)
			_add_slider(content, "Weather", "weather_volume", 0, 100)
			_add_slider(content, "UI Sounds", "ui_volume", 0, 100)
			var preview := _panel(Vector2(1044, 564), Vector2(440, 211))
			var preview_content := _column(preview, 7)
			preview_content.add_child(_label("Audio Preview", 26, true))
			preview_content.add_child(_label("Hear Wintervale's station chime.", 20))
			var sample := AudioStreamPlayer.new()
			sample.stream = SoundLibrary.get_sound("chime")
			sample.bus = &"WintervaleUI"
			preview.add_child(sample)
			var play := _button("▶  Play Sample", 230)
			preview_content.add_child(play)
			play.pressed.connect(func() -> void: SoundLibrary.play(sample))
		"settings_controls":
			_add_slider(content, "Camera Sensitivity", "camera_sensitivity", 0.25, 2.0)
			_add_slider(content, "Pan Speed", "pan_speed", 0.25, 2.0)
			_add_slider(content, "Zoom Speed", "zoom_speed", 0.25, 2.0)
			_add_toggle(content, "Invert Camera Y", "invert_camera_y")
			var keys := HBoxContainer.new()
			content.add_child(keys)
			for spec in [["Build", &"build_mode"], ["Rotate Left", &"camera_rotate_left"], ["Rotate Right", &"camera_rotate_right"], ["Notebook", &"toggle_notebook"]]:
				var key_button := _button("%s: %s" % [spec[0], _binding_label(spec[1])], 207)
				keys.add_child(key_button)
				key_button.pressed.connect(_begin_rebind.bind(spec[1], key_button))
		"settings_gameplay":
			_add_toggle(content, "Autosave Each Day", "autosave")
			_add_slider(content, "Camera Smoothing", "camera_smoothing", 0.25, 2.0)
			_add_slider(content, "Day Speed", "day_speed", 0.5, 2.0)
			_add_toggle(content, "Achievement Notifications", "achievement_notifications")
			_add_toggle(content, "Reduced Motion", "reduced_motion")
			var note := _panel(Vector2(1044, 522), Vector2(440, 302))
			var note_content := _column(note, 12)
			note_content.add_child(_label("Your Comfortable Pace", 26, true))
			var note_text := _label("Choose the day speed and motion level that make Wintervale feel like home.", 21)
			note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note_text.custom_minimum_size = Vector2(390, 110)
			note_content.add_child(note_text)
	_status = _label("", 18)
	content.add_child(_status)


func _add_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float) -> void:
	var row := _setting_row(parent, title)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(200 if page != "settings_controls" else 310, 35)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1 if maximum == 100 else 0.05
	slider.value = float(draft_settings[key])
	var track := StyleBoxFlat.new()
	track.bg_color = Color("a98266")
	track.set_corner_radius_all(5)
	track.set_content_margin_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bb793c")
	fill.set_corner_radius_all(5)
	fill.set_content_margin_all(5)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := preload("res://assets/ui/achievements/slider_knob.svg")
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	row.add_child(slider)
	var readout := _label(_number_text(slider.value, maximum), 19)
	readout.custom_minimum_size = Vector2(60 if page != "settings_controls" else 70, 35)
	row.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void:
		draft_settings[key] = value
		readout.text = _number_text(value, maximum))


func _add_toggle(parent: VBoxContainer, title: String, key: String) -> void:
	var row := _setting_row(parent, title)
	var toggle := _button("●  On" if bool(draft_settings[key]) else "○  Off", 105)
	toggle.toggle_mode = true
	toggle.button_pressed = bool(draft_settings[key])
	row.add_child(toggle)
	toggle.toggled.connect(func(value: bool) -> void:
		draft_settings[key] = value
		toggle.text = "●  On" if value else "○  Off")


func _add_choice(parent: VBoxContainer, title: String, key: String, choices: Array) -> void:
	var row := _setting_row(parent, title)
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(255, 36)
	_style_option(select)
	for choice in choices:
		select.add_item(String(choice))
	var value := str(draft_settings[key])
	var index := choices.find(value)
	select.select(maxi(index, 0))
	row.add_child(select)
	select.item_selected.connect(func(selected: int) -> void:
		draft_settings[key] = int(choices[selected]) if key == "fps_limit" else String(choices[selected]))


func _setting_row(parent: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var compact := page != "settings_controls"
	row.custom_minimum_size = Vector2(478 if compact else 900, 45)
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var caption := _label(title, 19 if compact else 22)
	caption.custom_minimum_size = Vector2(205 if compact else 390, 40)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(caption)
	return row


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
	var saves := SaveManager.list_saves()
	if achievement_slot == "" and not saves.is_empty():
		achievement_slot = String(saves[0]["slot"])
	_achievement_state = {}
	if achievement_slot != "":
		_achievement_state = SaveManager.read_save_data(achievement_slot).get("objects", {}).get(Achievements.SAVE_ID, {})
	var panel := _panel(Vector2(470, 230), Vector2(810, 640))
	var content := _column(panel, 5)
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation", 24)
	content.add_child(overview)
	overview.add_child(_label("Unlocked: %d / %d" % [_achievement_unlocks().size(), Achievements.DEFINITIONS.size()], 26, true))
	if not saves.is_empty():
		var journey := OptionButton.new()
		journey.custom_minimum_size.x = 280
		_style_option(journey)
		for entry in saves:
			journey.add_item(String(entry["name"]))
			journey.set_item_metadata(journey.item_count - 1, String(entry["slot"]))
			if entry["slot"] == achievement_slot:
				journey.select(journey.item_count - 1)
		overview.add_child(journey)
		journey.item_selected.connect(func(index: int) -> void:
			achievement_slot = String(journey.get_item_metadata(index))
			build("achievements"))
	else:
		content.add_child(_label("Start a journey to record achievements.", 18))
	var total_bar := _progress_bar(float(_achievement_unlocks().size()), float(Achievements.DEFINITIONS.size()), 760, 12)
	content.add_child(total_bar)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 485)
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	for category in ["Railway", "Village", "Cozy"]:
		list.add_child(_label(category, 26, true))
		for definition in Achievements.DEFINITIONS:
			if definition["category"] != category:
				continue
			var id: String = definition["id"]
			var value := minf(float(_achievement_progress().get(id, 0)), float(definition["target"]))
			var status := "Unlocked" if _achievement_unlocks().has(id) else "%d / %d" % [int(value), int(definition["target"])]
			var card := HBoxContainer.new()
			card.add_theme_constant_override("separation", 8)
			list.add_child(card)
			var badge := TextureRect.new()
			badge.texture = _badge(id)
			badge.custom_minimum_size = Vector2(60, 60)
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.modulate = Color.WHITE if _achievement_unlocks().has(id) else Color(0.63, 0.56, 0.50)
			card.add_child(badge)
			var card_button := _button("", 660)
			card_button.custom_minimum_size.y = 64
			card.add_child(card_button)
			var name_label := _label(String(definition["name"]), 21, true)
			name_label.position = Vector2(13, 5)
			name_label.size = Vector2(440, 26)
			card_button.add_child(name_label)
			var description := _label(String(definition["description"]), 16)
			description.position = Vector2(13, 31)
			description.size = Vector2(500, 25)
			card_button.add_child(description)
			var count := _label(status, 17)
			count.position = Vector2(525, 5)
			count.size = Vector2(124, 25)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			card_button.add_child(count)
			var bar := _progress_bar(value, float(definition["target"]), 125, 8)
			bar.position = Vector2(521, 39)
			card_button.add_child(bar)
			card_button.pressed.connect(_show_achievement_detail.bind(id))
	var detail_panel := _panel(Vector2(1320, 305), Vector2(264, 495))
	_detail = _column(detail_panel, 18)
	_show_achievement_detail(String(Achievements.DEFINITIONS[0]["id"]))


func _show_achievement_detail(id: String) -> void:
	if _detail == null:
		return
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var definition := Achievements.get_definition(id)
	var badge := TextureRect.new()
	badge.texture = _badge(id)
	badge.custom_minimum_size = Vector2(115, 115)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.modulate = Color.WHITE if _achievement_unlocks().has(id) else Color(0.63, 0.56, 0.50)
	_detail.add_child(badge)
	_detail.add_child(_label(String(definition["name"]), 26, true))
	var description := _label(String(definition["description"]), 19)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(213, 80)
	_detail.add_child(description)
	var value := minf(float(_achievement_progress().get(id, 0)), float(definition["target"]))
	_detail.add_child(_label("Progress: %d / %d" % [int(value), int(definition["target"])], 19))
	_detail.add_child(_progress_bar(value, float(definition["target"]), 208, 12))
	_detail.add_child(_label("Unlocked" if _achievement_unlocks().has(id) else "Locked", 19))
	if _achievement_unlocks().has(id):
		_detail.add_child(_label(String(_achievement_unlocks()[id]), 17))


func _achievement_progress() -> Dictionary:
	return _achievement_state.get("progress", {})


func _achievement_unlocks() -> Dictionary:
	return _achievement_state.get("unlocked", {})


func _progress_bar(value: float, maximum: float, width: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("a98266")
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bd7935")
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _build_credits() -> void:
	var panel := _panel(Vector2(365, 271), Vector2(1010, 475))
	var content := _column(panel, 19)
	content.add_child(_label("Wintervale Station", 38, true))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 100)
	content.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 13)
	columns.add_child(left)
	left.add_child(_label("Creative Director", 27, true))
	left.add_child(_label("Luca Warmers", 25))
	left.add_child(_spacer(25))
	left.add_child(_label("Project Development", 27, true))
	left.add_child(_label("Luca Warmers", 25))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 13)
	columns.add_child(right)
	right.add_child(_label("Game Engine", 27, true))
	right.add_child(_label("Godot Engine", 25))
	right.add_child(_spacer(25))
	right.add_child(_label("Reference Artwork", 27, true))
	right.add_child(_label("Supplied by the project creator", 23))
	content.add_child(_spacer(28))
	content.add_child(_label("Thank you for visiting our little station.", 25))


func _style_option(select: OptionButton) -> void:
	select.add_theme_font_override("font", _serif())
	select.add_theme_font_size_override("font_size", 21)
	select.add_theme_color_override("font_color", INK)
	select.add_theme_color_override("font_focus_color", INK)
	select.add_theme_stylebox_override("normal", _button_style(false))
	select.add_theme_stylebox_override("hover", _button_style(true))
	select.add_theme_stylebox_override("focus", _button_style(true))


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


func _serif() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
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


func _number_text(value: float, maximum: float) -> String:
	return "%d%%" % int(value) if maximum == 100 else "%.2f" % value


func _format_playtime(seconds: float) -> String:
	return "%dh %02dm" % [int(seconds / 3600), int(seconds / 60) % 60]


func _badge(id: String) -> Texture2D:
	return load("res://assets/ui/achievements/%s.svg" % id) as Texture2D
