## Gemeinsamer Look von Reisebuch (RegionPanel) und Tutorial (JourneyTutorial).
##
## Holzrahmen, Pergament, Messing und Serifenschrift – dieselbe Bildsprache wie
## die freigegebenen Menüseiten. Der Rahmen ist das Pergament-Brett des
## Hauptmenüs (parchment_panel.png) als Neun-Feld-Grafik, Buttons nutzen die
## Knopfgrafiken der Spielstand-Seite. Alles Weitere wird per Code gezeichnet.
class_name JourneyStyle
extends RefCounted

## Referenz-Leinwand aller Menüs; alles wird proportional auf den Bildschirm skaliert.
const DESIGN_SIZE := Vector2(1672.0, 941.0)
const FRAME_ART := preload("res://assets/ui/main_menu/parchment_panel.png")
const BUTTON_GOLD := preload("res://assets/ui/save_art/button_gold.png")
const BUTTON_PLAIN := preload("res://assets/ui/save_art/button_plain.png")
const COIN := preload("res://assets/ui/icons/coin.svg")

const INK := Color("3f2a1e")
const INK_SOFT := Color("6e5240")
const INK_FADED := Color("a08a74")
const GOLD := Color("c98a3d")
const GOLD_LIGHT := Color("f4c64a")
const GREEN := Color("4f7a4c")
const RED := Color("a8321e")
const PAPER := Color("f4e8cc")
const PAPER_LIGHT := Color("fbf4e3")
const PAPER_DARK := Color("e6d3ad")
const WOOD := Color("5b3422")
const WOOD_DARK := Color("3a2116")
const SNOW := Color("f6f8fc")
const SNOW_SHADE := Color("c9c8e2")

static var _serif: Font
static var _icons := {}


static func serif() -> Font:
	if _serif == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman"])
		_serif = font
	return _serif


## Symbol aus assets/ui/journey (eigene SVGs im Stil der Spiel-Icons).
static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		_icons[icon_name] = load("res://assets/ui/journey/%s.svg" % icon_name)
	return _icons[icon_name]


## Faktor, mit dem die Referenz-Leinwand auf den Bildschirm passt.
static func screen_factor(viewport: Vector2) -> float:
	return minf(viewport.x / DESIGN_SIZE.x, viewport.y / DESIGN_SIZE.y)


static func label(text: String, font_size := 20, color := INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", serif())
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func paragraph(text: String, font_size := 19, color := INK_SOFT) -> Label:
	var result := label(text, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


static func icon_rect(texture: Texture2D, edge: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(edge, edge)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func flat(color: Color, border: Color, width := 2, radius := 12, margin := 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.75
	style.content_margin_bottom = margin * 0.75
	style.anti_aliasing = true
	return style


## Karte auf dem Pergament: helleres Papier mit feinem Messingrand.
static func card_style(accent := false) -> StyleBoxFlat:
	var style := flat(PAPER_LIGHT if not accent else Color("fff6dc"), GOLD if accent else Color("d6bd92"), 3 if accent else 2, 14, 18.0)
	style.shadow_color = Color(0.35, 0.22, 0.1, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


static func card(parent: Node, accent := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(accent))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


static func _texture_box(texture: Texture2D, margin: float, modulate := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(margin)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.modulate_color = modulate
	return style


## Messingknopf (gold = Hauptaktion, sonst schlicht).
static func style_button(button: Button, gold := false, font_size := 21) -> void:
	var texture := BUTTON_GOLD if gold else BUTTON_PLAIN
	button.add_theme_stylebox_override("normal", _texture_box(texture, 12))
	button.add_theme_stylebox_override("hover", _texture_box(texture, 12, Color(1.08, 1.04, 0.94)))
	button.add_theme_stylebox_override("pressed", _texture_box(texture, 12, Color(0.86, 0.8, 0.7)))
	button.add_theme_stylebox_override("hover_pressed", _texture_box(texture, 12, Color(0.86, 0.8, 0.7)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", _texture_box(BUTTON_PLAIN, 12, Color(0.84, 0.8, 0.74, 0.75)))
	button.add_theme_font_override("font", serif())
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", INK_FADED)
	button.add_theme_constant_override("icon_max_width", int(font_size * 1.5))
	button.add_theme_constant_override("h_separation", 10)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func button(parent: Node, text: String, action: Callable, gold := false, icon_name := "", font_size := 21) -> Button:
	var result := Button.new()
	result.text = text
	style_button(result, gold, font_size)
	if icon_name != "":
		result.icon = icon(icon_name)
	result.pressed.connect(action)
	result.pressed.connect(play_page)
	parent.add_child(result)
	return result


## Theme für Auswahllisten, Eingabefelder, Bildlaufleisten und Tooltips.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = serif()
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", INK)
	var field := flat(Color("fbf3e1"), Color("c9a877"), 2, 10, 12.0)
	var field_hover := flat(Color("fff9ea"), GOLD, 2, 10, 12.0)
	for state in ["normal", "focus", "disabled"]:
		theme.set_stylebox(state, "OptionButton", field)
		theme.set_stylebox(state, "LineEdit", field)
	theme.set_stylebox("hover", "OptionButton", field_hover)
	theme.set_stylebox("pressed", "OptionButton", field_hover)
	theme.set_stylebox("focus", "LineEdit", field_hover)
	for type in ["OptionButton", "LineEdit"]:
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color(0.86, 0.64, 0.3, 0.4))
	var popup := flat(PAPER_LIGHT, WOOD, 3, 10, 8.0)
	popup.shadow_color = Color(0, 0, 0, 0.25)
	popup.shadow_size = 8
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", flat(Color("f1d9a8"), Color("f1d9a8"), 0, 6, 6.0))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", INK_FADED)
	theme.set_stylebox("panel", "TooltipPanel", flat(PAPER_LIGHT, WOOD, 2, 8, 10.0))
	theme.set_color("font_color", "TooltipLabel", INK)
	var bar := flat(Color(0.36, 0.24, 0.15, 0.18), Color(0, 0, 0, 0), 0, 6, 0.0)
	var grabber := flat(Color("b98445"), Color("8a5a2c"), 1, 6, 0.0)
	var grabber_hover := flat(Color("d7a25e"), Color("8a5a2c"), 1, 6, 0.0)
	theme.set_stylebox("scroll", "VScrollBar", bar)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_hover)
	return theme


## Pergamentbrett mit Holzrahmen. [param board] ist die gewünschte Größe in
## Leinwand-Einheiten; die Grafik wird halb so groß gezeichnet, damit Rahmen,
## Nieten und Schneekappen ihre Originalproportionen behalten.
static func frame(board: Vector2) -> NinePatchRect:
	var art := AtlasTexture.new()
	art.atlas = FRAME_ART
	art.region = Rect2(0, 236, 1172, 1106)
	var patch := NinePatchRect.new()
	patch.texture = art
	patch.patch_margin_left = 262
	patch.patch_margin_right = 262
	patch.patch_margin_top = 150
	patch.patch_margin_bottom = 270
	patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	patch.size = board * 2.0
	patch.scale = Vector2(0.5, 0.5)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return patch


## Tastenkappe wie in der Tastenlegende, nur größer und auf Papier.
static func keycap(text: String, font_size := 20) -> PanelContainer:
	var cap := PanelContainer.new()
	var style := flat(Color("fffaf0"), Color("8a6a4e"), 2, 7, 9.0)
	style.border_width_bottom = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", style)
	var caption := label(text, font_size, INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(caption)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cap


## Kurze Zeile „Symbol + Wert + Beschriftung“ (z.B. für Kennzahlen).
static func stat(parent: Node, icon_name: String, value: String, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	row.add_child(icon_rect(icon(icon_name), 40))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -4)
	row.add_child(texts)
	texts.add_child(label(value, 27, INK))
	texts.add_child(label(caption, 16, INK_SOFT))
	return row


## Ornamentlinie: Linie mit kleiner Raute in der Mitte.
static func divider(parent: Node) -> Control:
	var line := Divider.new()
	line.custom_minimum_size = Vector2(0, 14)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


static func play_page() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = SoundLibrary.get_sound("page")
	sound.volume_db = -10.0
	sound.bus = &"WintervaleUI" if AudioServer.get_bus_index(&"WintervaleUI") >= 0 else &"Master"
	tree.root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	SoundLibrary.play(sound)


static func play_chime() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = SoundLibrary.get_sound("done_chime")
	sound.volume_db = -9.0
	sound.bus = &"WintervaleUI" if AudioServer.get_bus_index(&"WintervaleUI") >= 0 else &"Master"
	tree.root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	SoundLibrary.play(sound)


## Fortschritt als kleines Gleis: Schwellen im Schotterbett, Messingfüllung,
## bei Erfüllung tannengrün. Der Wert läuft weich zum Ziel.
class TrackBar extends Control:
	var value := 0.0
	var max_value := 1.0
	var _shown := 0.0

	func _init(current := 0.0, target := 1.0) -> void:
		value = current
		max_value = maxf(target, 0.001)
		_shown = 0.0
		custom_minimum_size = Vector2(160, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var tween := create_tween()
		tween.tween_property(self, "_shown", clampf(value / max_value, 0.0, 1.0), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.7)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var radius := size.y * 0.5
		var bed := StyleBoxFlat.new()
		bed.bg_color = Color("6b5240")
		bed.set_corner_radius_all(int(radius))
		bed.border_color = Color("3f2a1e")
		bed.set_border_width_all(2)
		draw_style_box(bed, rect)
		var done := value >= max_value
		var fill := rect.grow(-3.0)
		fill.size.x = maxf(0.0, fill.size.x * _shown)
		if fill.size.x > 1.0:
			var paint := StyleBoxFlat.new()
			paint.bg_color = Color("6f9a5f") if done else Color("e3a84f")
			paint.set_corner_radius_all(int(radius - 3))
			draw_style_box(paint, fill)
			var shine := Rect2(fill.position + Vector2(4, 2), Vector2(maxf(0.0, fill.size.x - 8), fill.size.y * 0.3))
			draw_rect(shine, Color(1, 1, 1, 0.28))
		# Schwellen über die ganze Länge – der Balken liest sich als Gleis.
		var count := int(size.x / 14.0)
		for i in range(1, count):
			var x := i * size.x / count
			draw_line(Vector2(x, 4), Vector2(x, size.y - 4), Color(0.24, 0.16, 0.1, 0.32), 2.0)


## Ornamentlinie mit Raute.
class Divider extends Control:
	func _draw() -> void:
		var y := size.y * 0.5
		var center := size.x * 0.5
		var color := Color(0.6, 0.42, 0.26, 0.55)
		draw_line(Vector2(0, y), Vector2(center - 14, y), color, 2.0)
		draw_line(Vector2(center + 14, y), Vector2(size.x, y), color, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(center, y - 6), Vector2(center + 9, y), Vector2(center, y + 6), Vector2(center - 9, y)]), Color("c98a3d"))


## Schneekappe auf Holzrahmen (wie bei den Menüschildern).
class SnowCap extends Control:
	var lumps := PackedVector3Array()

	func _init(seed_value := 7) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in 26:
			lumps.append(Vector3(rng.randf(), rng.randf_range(0.55, 1.0), rng.randf_range(0.0, 1.0)))

	func _draw() -> void:
		# Eine zusammenhängende Wehe: oben gewellt, an den Ecken dicker,
		# unten ein Hauch Lavendel als kalter Schatten.
		var h := size.y
		var w := size.x
		var top := PackedVector2Array()
		var steps := maxi(12, int(w / 9.0))
		for i in steps + 1:
			var t := float(i) / steps
			var edge := absf(t - 0.5) * 2.0
			var lump: Vector3 = lumps[i % lumps.size()]
			var depth := h * lerpf(0.35, 0.95, edge * edge) * lerpf(0.75, 1.0, lump.y)
			top.append(Vector2(t * w, h - depth))
		var shade := PackedVector2Array(top)
		shade.append(Vector2(w, h + 2.5))
		shade.append(Vector2(0, h + 2.5))
		draw_colored_polygon(shade, JourneyStyle.SNOW_SHADE)
		var body := PackedVector2Array(top)
		body.append(Vector2(w, h))
		body.append(Vector2(0, h))
		draw_colored_polygon(body, JourneyStyle.SNOW)
		for i in range(1, top.size() - 1, 3):
			draw_circle(top[i] + Vector2(0, h * 0.22), h * 0.3, JourneyStyle.SNOW)
