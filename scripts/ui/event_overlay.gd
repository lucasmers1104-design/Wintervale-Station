## Fest-Banner und Interaktionshinweis (Teil des HUD, per Code gebaut).
##
## - Banner: großer Titel mit Untertitel und Bild in der oberen Bildmitte, z.B.
##   "Weihnachtsmarkt eröffnet" – schwebt weich herein, bleibt ein paar Sekunden,
##   blendet aus. Mehrere Banner warten in einer Schlange.
## - Hinweis: unten mittig "[E] Mit Greta sprechen", sobald die Spielfigur vor
##   jemandem oder etwas steht, mit dem sie etwas tun kann.
##
## Hört nur auf [code]Events.event_banner_requested[/code] und
## [code]Events.interaction_prompt_changed[/code].
class_name EventOverlay
extends Control

const INK := Color(0.24, 0.17, 0.12)
const PAPER := Color(0.99, 0.95, 0.87, 0.96)
const GOLD := Color(0.78, 0.58, 0.24)

var _banner: PanelContainer
var _title: Label
var _subtitle: Label
var _banner_icon: TextureRect
var _queue: Array[Array] = []
var _banner_tween: Tween
var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_text: Label
var _prompt_tween: Tween
var _hand: SystemFont


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Comic Sans MS", "Chalkboard SE", "Noteworthy"])
	_build_banner()
	_build_prompt()
	Events.event_banner_requested.connect(show_banner)
	Events.interaction_prompt_changed.connect(show_prompt)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 30
	style.content_margin_right = 34
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	_banner.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	_banner_icon = TextureRect.new()
	_banner_icon.custom_minimum_size = Vector2(64, 64)
	_banner_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_banner_icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	_title = Label.new()
	_title.add_theme_font_override("font", _hand)
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", INK)
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 19)
	_subtitle.add_theme_color_override("font_color", INK.lightened(0.25))
	column.add_child(_subtitle)
	add_child(_banner)
	_banner.modulate.a = 0.0
	_banner.visible = false


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.09, 0.72)
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_prompt.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_prompt.add_child(row)
	_prompt_key = Label.new()
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.99, 0.95, 0.87)
	key_style.set_corner_radius_all(6)
	key_style.content_margin_left = 9
	key_style.content_margin_right = 9
	key_style.content_margin_top = 1
	key_style.content_margin_bottom = 2
	_prompt_key.add_theme_stylebox_override("normal", key_style)
	_prompt_key.add_theme_color_override("font_color", INK)
	_prompt_key.add_theme_font_size_override("font_size", 18)
	row.add_child(_prompt_key)
	_prompt_text = Label.new()
	_prompt_text.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	_prompt_text.add_theme_font_size_override("font_size", 19)
	row.add_child(_prompt_text)
	add_child(_prompt)
	_prompt.modulate.a = 0.0
	_prompt.visible = false


## Großes Banner (wird angereiht, falls gerade eines zu sehen ist).
func show_banner(title: String, subtitle: String, icon: String) -> void:
	_queue.append([title, subtitle, icon])
	if _banner_tween == null or not _banner_tween.is_running():
		_next_banner()


func get_banner_title() -> String:
	return _title.text if _banner.visible else ""


func _next_banner() -> void:
	if _queue.is_empty():
		return
	var entry: Array = _queue.pop_front()
	_title.text = entry[0]
	_subtitle.text = entry[1]
	_subtitle.visible = entry[1] != ""
	_banner_icon.texture = SpeechBubble.icon_texture(entry[2]) if entry[2] != "" else null
	_banner_icon.visible = _banner_icon.texture != null
	_banner.visible = true
	_banner.reset_size()
	var size := _banner.get_combined_minimum_size()
	var target := Vector2((get_viewport_rect().size.x - size.x) * 0.5,
		get_viewport_rect().size.y * 0.34)
	_banner.position = target - Vector2(0, 26)
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.6)
	_banner_tween.tween_property(_banner, "position", target, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(4.2)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.9)
	_banner_tween.chain().tween_callback(func() -> void:
		_banner.visible = false
		_next_banner())


## Interaktionshinweis unten mittig ("" = ausblenden).
func show_prompt(text: String) -> void:
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	if text == "":
		_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.2)
		_prompt_tween.tween_callback(func() -> void: _prompt.visible = false)
		return
	_prompt_key.text = InputConfig.get_action_label(&"interact")
	_prompt_text.text = text
	_prompt.visible = true
	_prompt.reset_size()
	var size := _prompt.get_combined_minimum_size()
	var viewport := get_viewport_rect().size
	_prompt.position = Vector2((viewport.x - size.x) * 0.5, viewport.y * 0.72)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.18)


func get_prompt_text() -> String:
	return _prompt_text.text if _prompt.visible and _prompt.modulate.a > 0.0 else ""
