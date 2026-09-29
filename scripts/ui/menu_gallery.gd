## Visual menu pages supplied by the art director. All seven images are 1672x941.
## Navigation controls are Buttons with visible cropped art from each page.
## These pages carry sample values only; data and setting changes come later.
extends Control

signal closed

const DESIGN_SIZE := Vector2(1672, 941)
const PAGE_ART := {
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
var _page := ""


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
	visible = false


func show_page(page: String) -> void:
	if not PAGE_ART.has(page):
		push_warning("No visual reference is available for menu page '%s'." % page)
		return
	_page = page
	_art.texture = PAGE_ART[page]
	visible = true
	_rebuild_controls()


func close_page() -> void:
	visible = false
	_page = ""
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_page()
		get_viewport().set_input_as_handled()


func _rebuild_controls() -> void:
	for child in _hotspots.get_children():
		_hotspots.remove_child(child)
		child.queue_free()

	# The logo acts as a return target on every supplied visual page.
	_add_art_button("LogoBack", Rect2(110, 24, 580, 209), close_page)
	match _page:
		"load_save":
			_add_art_button("Back", Rect2(296, 844, 235, 69), close_page)
		"achievements":
			_add_art_button("Back", Rect2(456, 877, 201, 53), close_page)
			_add_art_button("LoadSave", Rect2(176, 358, 265, 70), func() -> void: show_page("load_save"))
			_add_art_button("Settings", Rect2(176, 427, 265, 70), func() -> void: show_page("settings_graphics"))
			_add_art_button("Credits", Rect2(176, 566, 265, 70), func() -> void: show_page("credits"))
		"credits":
			_add_art_button("Back", Rect2(374, 776, 215, 81), close_page)
		_:
			if _page.begins_with("settings_"):
				_add_art_button("Graphics", Rect2(178, 261, 279, 70), func() -> void: show_page("settings_graphics"))
				_add_art_button("Audio", Rect2(178, 337, 279, 70), func() -> void: show_page("settings_audio"))
				_add_art_button("Controls", Rect2(178, 412, 279, 70), func() -> void: show_page("settings_controls"))
				_add_art_button("Gameplay", Rect2(178, 489, 279, 70), func() -> void: show_page("settings_gameplay"))
				_add_art_button("Back", Rect2(497, 801, 239, 66), close_page)


func _add_art_button(label: String, region: Rect2, action: Callable) -> void:
	var button := Button.new()
	button.name = label
	button.tooltip_text = label.replace("Back", "Back to main menu") if label == "Back" or label == "LogoBack" else label
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.pressed.connect(action)
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
