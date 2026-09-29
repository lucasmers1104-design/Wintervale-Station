## A single queued, non-interactive achievement announcement.
class_name AchievementToast
extends CanvasLayer

var _queue: Array[String] = []
var _showing := false
var _panel: PanelContainer
var _badge: TextureRect
var _title: Label
var _description: Label
var _sound: AudioStreamPlayer


func _ready() -> void:
	layer = 60
	Achievements.unlocked.connect(_on_unlocked)
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -424
	_panel.offset_right = -22
	_panel.offset_top = 440
	_panel.offset_bottom = 550
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e8c397")
	style.border_color = Color("aa6b2e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_badge = TextureRect.new()
	_badge.custom_minimum_size = Vector2(86, 86)
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(_make_label("Achievement Unlocked", 17, Color("9a5b29")))
	_title = _make_label("", 24, Color("46291c"))
	words.add_child(_title)
	_description = _make_label("", 16, Color("6e4a32"))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.x = 270
	words.add_child(_description)
	_sound = AudioStreamPlayer.new()
	_sound.stream = SoundLibrary.get_sound("done_chime")
	_sound.bus = &"WintervaleUI"
	add_child(_sound)


func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1672.0, viewport_size.y / 941.0)
	_panel.offset_top = 440.0 * factor
	_panel.offset_bottom = _panel.offset_top + 110.0 * factor


func _on_unlocked(id: String) -> void:
	if not GameSettings.get_pref("achievement_notifications"):
		return
	_queue.append(id)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var id: String = _queue.pop_front()
	var definition := Achievements.get_definition(id)
	_badge.texture = load("res://assets/ui/achievements/%s.svg" % id)
	_title.text = String(definition["name"])
	_description.text = String(definition["description"])
	_panel.visible = true
	_panel.modulate.a = 0.0
	_badge.modulate = Color(1.35, 1.12, 0.78)
	if SoundLibrary.audible:
		_sound.play()
	if GameSettings.get_pref("reduced_motion"):
		_panel.modulate.a = 1.0
		await get_tree().create_timer(3.0).timeout
		_panel.visible = false
	else:
		_panel.offset_left = -396
		_panel.offset_right = 6
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "offset_left", -424.0, 0.35).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_panel, "offset_right", -22.0, 0.35).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_panel, "modulate:a", 1.0, 0.35)
		tween.tween_property(_badge, "modulate", Color.WHITE, 0.65)
		await tween.finished
		await get_tree().create_timer(3.0).timeout
		var outro := create_tween()
		outro.tween_property(_panel, "modulate:a", 0.0, 0.45)
		await outro.finished
		_panel.visible = false
	_show_next()


func _make_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
