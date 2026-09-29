## Sprechblase über einer Figur: Text (erscheint Buchstabe für Buchstabe) oder
## ein kleines Bild (Herz, Becher, Stern, Zug …). Die Blase dreht sich immer zur
## Kamera, springt weich auf, schwebt minimal und verschwindet nach [param duration]
## Sekunden wieder. Aus großer Entfernung wird sie nicht gezeichnet.
##
## Bilder: assets/ui/bubbles/<name>.svg (selbst gezeichnet).
class_name SpeechBubble
extends Node3D

const SHADER := preload("res://assets/materials/speech_bubble.gdshader")
const ICON_DIR := "res://assets/ui/bubbles/"
const PIXEL := 0.0034
const WRAP_PIXELS := 430.0
const FONT_SIZE := 34
## Buchstaben pro Sekunde beim Erscheinen.
const TYPE_SPEED := 42.0
const MAX_DISTANCE := 32.0

static var _icons := {}

var _label: Label3D
var _icon: Sprite3D
var _bubble: MeshInstance3D
var _material: ShaderMaterial
var _text := ""
var _typed := 0.0
var _time_left := 0.0
var _tween: Tween
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_bubble = MeshInstance3D.new()
	_bubble.mesh = quad
	_bubble.material_override = _material
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Das Quad wird erst im Shader zur Kamera gedreht und skaliert – großzügige Grenzen
	_bubble.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	_material.render_priority = 1
	add_child(_bubble)
	_label = Label3D.new()
	_label.font_size = FONT_SIZE
	_label.pixel_size = PIXEL
	_label.modulate = Color(0.24, 0.17, 0.12)
	_label.outline_size = 0
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = WRAP_PIXELS
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.fixed_size = false
	_label.shaded = false
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Immer lesbar, auch wenn ein Pfosten oder Ast davor steht
	_label.no_depth_test = true
	_label.render_priority = 2
	add_child(_label)
	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = 0.0052
	_icon.shaded = false
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_icon.no_depth_test = true
	_icon.render_priority = 2
	add_child(_icon)
	visible = false


## Zeigt [param text] für [param duration] Sekunden (0 = nach Textlänge).
func say(text: String, duration := 0.0) -> void:
	_icon.visible = false
	_label.visible = true
	_text = text
	_typed = 0.0
	_label.text = ""
	var font := _label.font if _label.font else ThemeDB.fallback_font
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, WRAP_PIXELS, FONT_SIZE)
	var world := Vector2(minf(size.x, WRAP_PIXELS), size.y) * PIXEL
	_material.set_shader_parameter(&"size", world + Vector2(0.24, 0.18))
	_material.set_shader_parameter(&"radius", minf(0.12, (world.y + 0.18) * 0.45))
	_time_left = duration if duration > 0.0 else clampf(2.2 + text.length() * 0.065, 3.0, 9.0)
	_pop()


## Zeigt ein kleines Bild ([param icon_name], z.B. "heart", "cup", "train").
func show_icon(icon_name: String, duration := 2.4) -> void:
	var texture := icon_texture(icon_name)
	if texture == null:
		return
	_label.visible = false
	_text = ""
	_icon.visible = true
	_icon.texture = texture
	_material.set_shader_parameter(&"size", Vector2(0.44, 0.4))
	_material.set_shader_parameter(&"radius", 0.18)
	_time_left = duration
	_pop()


func is_showing() -> bool:
	return visible and _time_left > 0.0


func get_text() -> String:
	return _text


func hide_now() -> void:
	_time_left = 0.0
	visible = false


static func clear_cache() -> void:
	_icons.clear()


static func icon_texture(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var path := ICON_DIR + icon_name + ".svg"
		_icons[icon_name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[icon_name]


func _pop() -> void:
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = Vector3.ONE * 0.2
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	if _text != "" and _typed < _text.length():
		_typed = minf(_typed + delta * TYPE_SPEED, _text.length())
		_label.text = _text.substr(0, int(_typed))
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.002) * 0.015
	var camera := get_viewport().get_camera_3d()
	if camera:
		var far := camera.global_position.distance_to(global_position) > MAX_DISTANCE
		_bubble.visible = not far
		_label.visible = not far and _text != ""
		_icon.visible = not far and _text == ""
	_time_left -= delta
	if _time_left <= 0.0 and (_tween == null or not _tween.is_running()):
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func() -> void: visible = false)
