## Visual menu pages supplied by the art director. All seven images are 1672x941.
## Navigation controls are Buttons with visible cropped art from each page.
## Approved artwork is retained. Live parchment areas cover its sample values.
extends Control

signal closed
signal start_requested(name: String, season: int)
signal load_requested(slot: String)
signal action_requested(action: String)

const DESIGN_SIZE := Vector2(1672, 941)
const PAGE_ART := {
	"new_game": preload("res://assets/ui/menu_screens/load_save.png"),
	"load_save": preload("res://assets/ui/menu_screens/load_save.png"),
	"achievements": preload("res://assets/ui/menu_screens/achievements.png"),
	"settings_graphics": preload("res://assets/ui/menu_screens/settings_graphics.png"),
	"settings_audio": preload("res://assets/ui/menu_screens/settings_audio.png"),
	"settings_controls": preload("res://assets/ui/menu_screens/settings_controls.png"),
	"settings_gameplay": preload("res://assets/ui/menu_screens/settings_gameplay.png"),
	"credits": preload("res://assets/ui/menu_screens/credits.png"),
}

var _art: TextureRect
var _hotspots: Control
var _live: MenuLiveContent
var _blocker: ColorRect
var _paper_sound: AudioStreamPlayer
var _hover_sound: AudioStreamPlayer
var _page := ""
var _transition: Tween
var _transitioning := false


func _ready() -> void:
	size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_art = TextureRect.new()
	_art.name = "PageArt"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.size = DESIGN_SIZE
	_hotspots = Control.new()
	_hotspots.name = "VisibleControls"
	_hotspots.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_hotspots)
	_hotspots.size = DESIGN_SIZE
	_live = MenuLiveContent.new()
	_live.name = "LiveContent"
	add_child(_live)
	_live.start_requested.connect(func(name: String, season: int) -> void: start_requested.emit(name, season))
	_live.load_requested.connect(func(slot: String) -> void: load_requested.emit(slot))
	_live.action_requested.connect(func(action: String) -> void: action_requested.emit(action))
	_paper_sound = AudioStreamPlayer.new()
	_paper_sound.stream = SoundLibrary.get_sound("page")
	_paper_sound.bus = &"WintervaleUI"
	add_child(_paper_sound)
	_hover_sound = AudioStreamPlayer.new()
	_hover_sound.stream = SoundLibrary.get_sound("page")
	_hover_sound.bus = &"WintervaleUI"
	_hover_sound.volume_db = -23.0
	add_child(_hover_sound)
	_blocker = ColorRect.new()
	_blocker.color = Color.TRANSPARENT
	_blocker.size = DESIGN_SIZE
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.focus_mode = Control.FOCUS_ALL
	add_child(_blocker)
	_blocker.visible = false
	visible = false


func show_page(page: String) -> void:
	if not PAGE_ART.has(page):
		push_warning("No visual reference is available for menu page '%s'." % page)
		return
	if _transitioning:
		return
	visible = true
	SoundLibrary.play(_paper_sound)
	_set_page(page)
	modulate.a = 1.0
	position = Vector2.ZERO
	_finish_open()


func _finish_open() -> void:
	_transitioning = false
	_blocker.visible = false
	if _page == "new_game":
		var name_input := _live.find_child("JourneyName", true, false) as LineEdit
		if name_input:
			name_input.grab_focus()
	else:
		var buttons := _live.find_children("*", "Button", true, false)
		if not buttons.is_empty():
			(buttons[0] as Button).grab_focus()


func close_page() -> void:
	if _transitioning:
		return
	_live.cancel_settings()
	_blocker.visible = true
	_blocker.grab_focus()
	SoundLibrary.play(_paper_sound)
	if GameSettings.get_pref("reduced_motion"):
		_finish_close()
		return
	_transitioning = true
	_transition = create_tween().set_parallel(true)
	_transition.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	_transition.tween_property(self, "position:x", 16.0, 0.25).set_trans(Tween.TRANS_SINE)
	_transition.finished.connect(_finish_close)


func _finish_close() -> void:
	visible = false
	modulate.a = 1.0
	position = Vector2.ZERO
	_page = ""
	_transitioning = false
	_blocker.visible = false
	closed.emit()


func _set_page(page: String) -> void:
	_page = page
	_art.texture = PAGE_ART[page]
	_rebuild_controls()
	_live.build(page)
	_live.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if not _live.handle_escape():
			close_page()
		get_viewport().set_input_as_handled()


func _rebuild_controls() -> void:
	for child in _hotspots.get_children():
		_hotspots.remove_child(child)
		child.queue_free()

	# The logo acts as a return target on every supplied visual page.
	_add_art_button("LogoBack", Rect2(110, 24, 580, 209), close_page)
	match _page:
		"new_game":
			_add_art_button("Back", Rect2(296, 844, 235, 69), close_page)
		"load_save":
			_add_art_button("Back", Rect2(296, 844, 235, 69), close_page)
		"achievements":
			_add_art_button("Back", Rect2(456, 877, 201, 53), close_page)
			_add_art_button("Continue", Rect2(176, 234, 265, 70), func() -> void: action_requested.emit("continue"))
			_add_art_button("NewGame", Rect2(176, 298, 265, 70), func() -> void: action_requested.emit("new_game"))
			_add_art_button("LoadSave", Rect2(176, 358, 265, 70), func() -> void: show_page("load_save"))
			_add_art_button("Settings", Rect2(176, 427, 265, 70), func() -> void: show_page("settings_graphics"))
			_add_art_button("Credits", Rect2(176, 566, 265, 70), func() -> void: show_page("credits"))
			_add_art_button("Quit", Rect2(176, 628, 265, 70), func() -> void: action_requested.emit("quit"))
		"credits":
			_add_art_button("Back", Rect2(374, 776, 215, 81), close_page)
		_:
			if _page.begins_with("settings_"):
				_add_art_button("Graphics", Rect2(178, 261, 279, 70), func() -> void: show_page("settings_graphics"))
				_add_art_button("Audio", Rect2(178, 337, 279, 70), func() -> void: show_page("settings_audio"))
				_add_art_button("Controls", Rect2(178, 412, 279, 70), func() -> void: show_page("settings_controls"))
				_add_art_button("Gameplay", Rect2(178, 489, 279, 70), func() -> void: show_page("settings_gameplay"))
				_add_art_button("Back", Rect2(497, 801, 239, 66), close_page)
				_add_art_button("Reset", Rect2(801, 801, 287, 66), _live.reset_settings)
				_add_art_button("Apply", Rect2(1126, 801, 305, 66), _live.apply_settings)


func _add_art_button(label: String, region: Rect2, action: Callable) -> void:
	var button := Button.new()
	button.name = label
	button.tooltip_text = label.replace("Back", "Back to main menu") if label == "Back" or label == "LogoBack" else label
	if label == "Continue" and SaveManager.most_recent_valid_slot() == "":
		button.disabled = true
		button.tooltip_text = "No saved journey yet. Choose New Game."
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.pressed.connect(action)
	button.mouse_entered.connect(func() -> void: SoundLibrary.play(_hover_sound))
	_hotspots.add_child(button)
	button.position = region.position
	button.size = region.size

	# This is the actual visible control surface, sampled without alteration from
	# the corresponding art. It is a separate TextureRect, not an invisible hit box.
	var crop := AtlasTexture.new()
	crop.atlas = PAGE_ART[_page]
	crop.region = region
	var surface := TextureRect.new()
	surface.name = "ArtSurface"
	surface.texture = crop
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(surface)
	surface.size = region.size
	var focus_outline := Panel.new()
	focus_outline.size = region.size
	focus_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline_style := StyleBoxFlat.new()
	outline_style.bg_color = Color.TRANSPARENT
	outline_style.border_color = Color("fbd78a")
	outline_style.set_border_width_all(3)
	outline_style.set_corner_radius_all(7)
	focus_outline.add_theme_stylebox_override("panel", outline_style)
	button.add_child(focus_outline)
	focus_outline.visible = false
	button.focus_entered.connect(func() -> void: focus_outline.visible = true)
	button.focus_exited.connect(func() -> void: focus_outline.visible = false)
