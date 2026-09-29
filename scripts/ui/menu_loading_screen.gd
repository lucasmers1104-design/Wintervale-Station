## Full-screen journey artwork with an actual scene-loading progress indicator.
class_name MenuLoadingScreen
extends CanvasLayer

const DESIGN_SIZE := Vector2(1672, 941)
const ART := preload("res://assets/ui/loading_screen_reference.png")

var _screen: Control
var _canvas: Control
var _progress: ProgressBar
var _progress_cap: TextureRect
var _progress_tween: Tween


func _ready() -> void:
	layer = 100
	_screen = Control.new()
	_screen.name = "LoadingRoot"
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var matte := ColorRect.new()
	matte.color = Color("211820")
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.name = "ReferenceCanvas"
	_canvas.size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_canvas)
	var picture := TextureRect.new()
	picture.name = "LoadingArtwork"
	picture.texture = ART
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = DESIGN_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(picture)
	_progress = ProgressBar.new()
	_progress.name = "RealProgress"
	_progress.position = Vector2(267, 720)
	_progress.size = Vector2(532, 33)
	_progress.min_value = 0
	_progress.max_value = 100
	_progress.value = 0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark_crop := AtlasTexture.new()
	dark_crop.atlas = ART
	dark_crop.region = Rect2(678, 728, 110, 19)
	var dark := StyleBoxTexture.new()
	dark.texture = dark_crop
	_progress.add_theme_stylebox_override("background", dark)
	var gold_crop := AtlasTexture.new()
	gold_crop.atlas = ART
	gold_crop.region = Rect2(352, 728, 260, 19)
	var gold := StyleBoxTexture.new()
	gold.texture = gold_crop
	_progress.add_theme_stylebox_override("fill", gold)
	_canvas.add_child(_progress)
	_progress_cap = TextureRect.new()
	var cap_crop := AtlasTexture.new()
	cap_crop.atlas = ART
	cap_crop.region = Rect2(646, 719, 31, 35)
	_progress_cap.texture = cap_crop
	_progress_cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_progress_cap.stretch_mode = TextureRect.STRETCH_SCALE
	_progress_cap.size = Vector2(31, 35)
	_progress_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_cap.visible = false
	_canvas.add_child(_progress_cap)
	get_viewport().size_changed.connect(_rescale)
	_rescale()


func _rescale() -> void:
	if _screen == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_screen.size = viewport_size
	var factor := maxf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (viewport_size - DESIGN_SIZE * factor) * 0.5


func set_progress(amount: float) -> void:
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_method(_draw_progress, _progress.value / 100.0,
		clampf(amount, 0.0, 1.0), 0.26).set_trans(Tween.TRANS_SINE)


func _draw_progress(amount: float) -> void:
	_progress.value = amount * 100.0
	_progress_cap.visible = amount > 0.04 and amount < 0.99
	_progress_cap.position = Vector2(267.0 + 532.0 * amount - 20.0, 719.0)


func reveal() -> void:
	_screen.modulate.a = 0.0
	if _reduced_motion():
		_screen.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_property(_screen, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	await tween.finished


func dismiss() -> void:
	if not _reduced_motion():
		var tween := create_tween()
		tween.tween_property(_screen, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		await tween.finished
	queue_free()


func _reduced_motion() -> bool:
	var settings := get_node_or_null(^"/root/GameSettings")
	return settings != null and bool(settings.call("get_pref", "reduced_motion"))
