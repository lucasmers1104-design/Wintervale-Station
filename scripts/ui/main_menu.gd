## The title screen is composed at the 1672x941 reference size and scaled uniformly.
## Artwork never contains the interactive labels: every menu entry is a real Button.
extends Control

const DESIGN_SIZE := Vector2(1672.0, 941.0)
const BACKGROUND := preload("res://assets/ui/main_menu/station_background.png")
const LOGO := preload("res://assets/ui/main_menu/wood_logo.png")
const PARCHMENT := preload("res://assets/ui/main_menu/parchment_panel.png")
const ENTRIES := ["Continue", "New Game", "Load Save", "Settings", "Achievements", "Credits", "Quit"]
const INK := Color("4b3025")
const GOLD := Color("d7924a")

var _canvas: Control
var _buttons: Array[Button] = []
var _notice: PanelContainer
var _notice_text: Label
var _snow: MenuSnow


class MenuIcon extends Control:
	var kind := 0
	var ink := Color("54382b")

	func _draw() -> void:
		var w := 2.4
		match kind:
			0: # locomotive
				draw_rect(Rect2(5, 18, 30, 16), ink, false, w)
				draw_rect(Rect2(14, 10, 15, 9), ink, false, w)
				draw_rect(Rect2(29, 14, 7, 5), ink, true)
				draw_line(Vector2(3, 34), Vector2(38, 34), ink, w)
				draw_circle(Vector2(11, 37), 3.8, ink)
				draw_circle(Vector2(31, 37), 3.8, ink)
				draw_line(Vector2(19, 10), Vector2(19, 4), ink, w)
				draw_line(Vector2(16, 4), Vector2(22, 4), ink, w)
			1: # pocket watch
				draw_arc(Vector2(21, 23), 16, 0, TAU, 32, ink, w)
				draw_line(Vector2(21, 23), Vector2(21, 13), ink, w)
				draw_line(Vector2(21, 23), Vector2(14, 28), ink, w)
				draw_rect(Rect2(17, 4, 8, 4), ink, true)
				for angle in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]:
					var v := Vector2(cos(angle), sin(angle))
					draw_line(Vector2(21, 23) + v * 11, Vector2(21, 23) + v * 14, ink, 1.7)
			2: # folder
				draw_colored_polygon(PackedVector2Array([Vector2(4, 13), Vector2(17, 13), Vector2(21, 17), Vector2(38, 17), Vector2(38, 36), Vector2(4, 36)]), ink)
				draw_line(Vector2(5, 11), Vector2(17, 11), ink, 3)
			3: # cog
				for n in 8:
					var a := float(n) * TAU / 8.0
					var radial := Vector2(cos(a), sin(a))
					draw_line(Vector2(21, 23) + radial * 14, Vector2(21, 23) + radial * 20, ink, 6)
				draw_circle(Vector2(21, 23), 15, ink)
				draw_circle(Vector2(21, 23), 6, Color("ead0ad"))
			4: # trophy
				draw_colored_polygon(PackedVector2Array([Vector2(11, 8), Vector2(31, 8), Vector2(29, 22), Vector2(25, 27), Vector2(17, 27), Vector2(13, 22)]), ink)
				draw_arc(Vector2(9, 16), 7, PI * .5, PI * 1.5, 14, ink, w)
				draw_arc(Vector2(33, 16), 7, -PI * .5, PI * .5, 14, ink, w)
				draw_line(Vector2(21, 27), Vector2(21, 35), ink, 4)
				draw_line(Vector2(12, 36), Vector2(30, 36), ink, 4)
			5: # open book
				draw_colored_polygon(PackedVector2Array([Vector2(4, 9), Vector2(13, 8), Vector2(21, 12), Vector2(21, 36), Vector2(12, 32), Vector2(4, 32)]), ink)
				draw_colored_polygon(PackedVector2Array([Vector2(38, 9), Vector2(29, 8), Vector2(21, 12), Vector2(21, 36), Vector2(30, 32), Vector2(38, 32)]), ink)
				draw_line(Vector2(21, 12), Vector2(21, 36), Color("ead0ad"), 1.5)
			6: # exit door and arrow
				draw_rect(Rect2(12, 6, 25, 32), ink, false, 3)
				draw_line(Vector2(3, 22), Vector2(26, 22), ink, 4)
				draw_line(Vector2(18, 14), Vector2(26, 22), ink, 4)
				draw_line(Vector2(18, 30), Vector2(26, 22), ink, 4)


class MenuSnow extends Control:
	var flakes: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()

	func _ready() -> void:
		rng.seed = 71217
		for i in 70:
			flakes.append(Vector3(rng.randf_range(0, 1672), rng.randf_range(0, 941), rng.randf_range(1.0, 2.8)))
		set_process(true)

	func _process(delta: float) -> void:
		for i in flakes.size():
			var p := flakes[i]
			p.y += delta * (13.0 + p.z * 8.0)
			p.x -= delta * (3.0 + p.z * 2.0)
			if p.y > 945.0:
				p.y = -5.0
			if p.x < -5.0:
				p.x = 1677.0
			flakes[i] = p
		queue_redraw()

	func _draw() -> void:
		for p in flakes:
			draw_circle(Vector2(p.x, p.y), p.z, Color(1.0, 0.95, 0.88, 0.27))


func _ready() -> void:
	_build()
	_rescale()
	get_viewport().size_changed.connect(_rescale)
	_buttons[0].grab_focus.call_deferred()


func _build() -> void:
	var matte := ColorRect.new()
	matte.color = Color("17131b")
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(matte)

	_canvas = Control.new()
	_canvas.name = "ReferenceCanvas"
	_canvas.custom_minimum_size = DESIGN_SIZE
	_canvas.size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)

	_add_image(BACKGROUND, Vector2.ZERO, DESIGN_SIZE, "WinterStation")
	# The clean plate keeps the train, clock, lanterns and platform in their reference positions.
	_add_station_signs()
	_add_image(PARCHMENT, Vector2(195, 214), Vector2(500, 634), "Parchment")
	_add_image(LOGO, Vector2(188, 43), Vector2(552, 263), "WoodLogo")

	_snow = MenuSnow.new()
	_snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snow.position = Vector2.ZERO
	_snow.size = DESIGN_SIZE
	_canvas.add_child(_snow)

	for i in ENTRIES.size():
		_add_entry(i)

	var card := PanelContainer.new()
	card.position = Vector2(595, 665)
	card.size = Vector2(116, 161)
	card.rotation = -0.105
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("c9aa83")
	card_style.border_color = Color("826047")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(5)
	card_style.shadow_color = Color(0.12, 0.06, 0.03, 0.45)
	card_style.shadow_size = 8
	card.add_theme_stylebox_override("panel", card_style)
	_canvas.add_child(card)
	var card_text := Label.new()
	card_text.text = "Good\nJourneys\nAhead\n\n♠"
	card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_text.add_theme_color_override("font_color", INK)
	card_text.add_theme_font_size_override("font_size", 18)
	card_text.add_theme_font_override("font", _serif())
	card_text.position = Vector2(601, 673)
	card_text.size = Vector2(108, 144)
	card_text.rotation = -0.105
	card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(card_text)

	var motto := Label.new()
	motto.text = "Small Stations\nBrighter Stories"
	motto.position = Vector2(34, 821)
	motto.size = Vector2(190, 74)
	motto.rotation = -0.11
	var script_font := SystemFont.new()
	script_font.font_names = PackedStringArray(["Segoe Script", "Bradley Hand", "Georgia"])
	script_font.font_italic = true
	motto.add_theme_font_override("font", script_font)
	motto.add_theme_font_size_override("font_size", 23)
	motto.add_theme_color_override("font_color", Color("f6dfbd"))
	motto.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	motto.add_theme_constant_override("shadow_offset_x", 2)
	motto.add_theme_constant_override("shadow_offset_y", 3)
	motto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(motto)

	var version := Label.new()
	version.text = "v1.0.0"
	version.position = Vector2(1588, 896)
	version.size = Vector2(76, 34)
	version.add_theme_font_override("font", _serif())
	version.add_theme_font_size_override("font_size", 19)
	version.add_theme_color_override("font_color", Color("f6e4cc"))
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(version)

	_build_notice()


func _add_image(texture: Texture2D, pos: Vector2, dimensions: Vector2, label: String) -> void:
	var image := TextureRect.new()
	image.name = label
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(image)
	image.position = pos
	image.size = dimensions


func _add_station_signs() -> void:
	var station := _decorative_sign(Vector2(1348, 318), Vector2(213, 61), -0.095, "Wintervale", 28,
		Color("2b211c"), Color("db9552"), Color("dc9960"))
	station.name = "StationNameSign"
	var direction := _decorative_sign(Vector2(1216, 357), Vector2(98, 50), 0.0, "To New\nHorizons  ➜", 14,
		Color("593519"), Color("a36a35"), Color("e5a766"))
	direction.name = "DirectionSign"
	var train := _decorative_sign(Vector2(772, 432), Vector2(77, 25), 0.0, "WINTERVALE", 11,
		Color("312018"), Color("a6753d"), Color("ffcf86"))
	train.name = "TrainDestination"
	var board := _decorative_sign(Vector2(1563, 391), Vector2(95, 214), -0.05,
		"TRAINS\nBRING\nPEOPLE\nCLOSER\n\n✦", 14,
		Color("302019"), Color("865831"), Color("a17a5e"))
	board.name = "Chalkboard"


func _decorative_sign(pos: Vector2, dimensions: Vector2, angle: float, caption: String,
		font_size: int, fill: Color, edge: Color, lettering: Color) -> Panel:
	var sign := Panel.new()
	sign.position = pos
	sign.size = dimensions
	sign.rotation = angle
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.03, 0.01, 0.01, 0.52)
	style.shadow_size = 5
	sign.add_theme_stylebox_override("panel", style)
	_canvas.add_child(sign)
	var writing := Label.new()
	writing.text = caption
	writing.position = Vector2(5, 1)
	writing.size = dimensions - Vector2(10, 2)
	writing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	writing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	writing.add_theme_font_override("font", _serif())
	writing.add_theme_font_size_override("font_size", font_size)
	writing.add_theme_color_override("font_color", lettering)
	writing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(writing)
	return sign


func _add_entry(index: int) -> void:
	var button := Button.new()
	button.name = ENTRIES[index].replace(" ", "")
	button.position = Vector2(233, 321 + index * 65)
	button.size = Vector2(413, 60)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("focus", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	button.add_theme_stylebox_override("hover_pressed", _button_style(true))
	button.pressed.connect(_activate.bind(index))
	button.mouse_entered.connect(button.grab_focus)
	_canvas.add_child(button)
	_buttons.append(button)

	var icon := MenuIcon.new()
	icon.kind = index
	icon.position = Vector2(28, 8)
	icon.size = Vector2(43, 44)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var title := Label.new()
	title.text = ENTRIES[index]
	title.position = Vector2(104, 5)
	title.size = Vector2(280, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _serif())
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)

	if index == 0:
		var arrow := Label.new()
		arrow.text = "›"
		arrow.position = Vector2(375, 4)
		arrow.size = Vector2(28, 52)
		arrow.add_theme_font_override("font", _serif())
		arrow.add_theme_font_size_override("font_size", 43)
		arrow.add_theme_color_override("font_color", INK)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(arrow)
	if index < ENTRIES.size() - 1:
		var separator := ColorRect.new()
		separator.color = Color(0.43, 0.28, 0.20, 0.18)
		separator.position = Vector2(19, 62)
		separator.size = Vector2(365, 1)
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(separator)


func _button_style(highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	if highlight:
		style.bg_color = Color("ffe1a6")
		style.border_color = Color("f7bd67")
		style.set_border_width_all(2)
		style.shadow_color = Color(1.0, 0.64, 0.21, 0.32)
		style.shadow_size = 8
	else:
		style.bg_color = Color(1, 1, 1, 0)
	return style


func _serif() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
	font.font_italic = false
	return font


func _rescale() -> void:
	if _canvas == null:
		return
	var viewport := get_viewport_rect().size
	var factor: float = minf(viewport.x / DESIGN_SIZE.x, viewport.y / DESIGN_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (viewport - DESIGN_SIZE * factor) * 0.5


func _activate(index: int) -> void:
	match index:
		0:
			if SaveManager.has_save():
				_start_game(true)
			else:
				_show_notice("No saved journey yet. Start a New Game to visit Wintervale.")
		1:
			_start_game(false)
		2:
			if SaveManager.has_save():
				_start_game(true)
			else:
				_show_notice("No save files found. The current game supports a quicksave slot.")
		3:
			_show_notice("Settings screen is not implemented in this project yet. Press F11 in the game for fullscreen.")
		4:
			_show_notice("Achievements screen is not implemented in this project yet.")
		5:
			_show_notice("Credits screen is not implemented in this project yet.")
		6:
			get_tree().quit()


func _start_game(load_save: bool) -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	if scene == null:
		_show_notice("Unable to open the game world.")
		return
	var world := scene.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	if load_save and not SaveManager.load_game():
		push_warning("The saved game could not be loaded after entering the world.")
	queue_free()


func _build_notice() -> void:
	_notice = PanelContainer.new()
	_notice.position = Vector2(746, 747)
	_notice.size = Vector2(540, 112)
	_notice.visible = false
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c1b19")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_notice.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_notice)
	_notice_text = Label.new()
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_text.add_theme_font_override("font", _serif())
	_notice_text.add_theme_font_size_override("font_size", 23)
	_notice_text.add_theme_color_override("font_color", Color("ffebc9"))
	_notice_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(_notice_text)


func _show_notice(message: String) -> void:
	_notice_text.text = message
	_notice.visible = true
	var tween := create_tween()
	_notice.modulate.a = 1.0
	tween.tween_interval(4.0)
	tween.tween_property(_notice, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void: _notice.visible = false)
