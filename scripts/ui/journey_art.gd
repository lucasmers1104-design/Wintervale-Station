## Reference illustrations and reusable UI textures; all labels stay live controls.
class_name JourneyArt
extends RefCounted
const ROOT := "res://assets/ui/journey_art/"
static var _textures := {}
const REGIONS := {
	"conductor":["tutorial",Rect2(203,245,283,289)],
	"tunnel":["places",Rect2(112,352,685,229)],
	"station":["places",Rect2(849,293,701,187)],
	"station_icon":["places",Rect2(1005,300,325,170)],
	"tunnel_icon":["places",Rect2(141,372,213,192)],
	"epoch":["epochs",Rect2(121,635,742,131)],
	"freight":["fleet",Rect2(626,304,906,318)],
	"route":["lines",Rect2(1082,647,455,106)],
	"regional":["lines",Rect2(123,644,409,205)],
	"landscape":["places",Rect2(114,662,1418,189)],
	"mountains":["epochs",Rect2(125,196,244,61)],
	"diesel_heritage":["fleet",Rect2(117,204,186,73)],
	"nostalgic_regional":["fleet",Rect2(116,320,187,72)],
	"reference_freight":["fleet",Rect2(111,443,202,74)],
	"modern_local":["fleet",Rect2(119,558,192,70)],
	"intercity":["fleet",Rect2(114,675,193,68)],
	"high_speed":["fleet",Rect2(112,792,193,68)],
}
static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		if REGIONS.has(id):
			var art := AtlasTexture.new()
			art.atlas = load(ROOT+"references/"+REGIONS[id][0]+".png")
			art.region = REGIONS[id][1]
			art.filter_clip = true
			_textures[id] = art
		else:
			var source := load(ROOT+id+".png") as Texture2D
			# Load the large illustration at its UI pixel density. Nine-patch
			# corners must stay small on short stat and information cards.
			if id=="card":
				var raster := source.get_image()
				raster.resize(585,329,Image.INTERPOLATE_LANCZOS)
				source = ImageTexture.create_from_image(raster)
			var trimmed := AtlasTexture.new()
			trimmed.atlas = source
			trimmed.region = Rect2(9,17,566,291) if id=="card" else Rect2(source.get_image().get_used_rect())
			trimmed.filter_clip = true
			_textures[id] = trimmed
	return _textures[id]
static func illustration(parent: Node,id: String,height: float) -> TextureRect:
	var rect := TextureRect.new()
	parent.add_child(rect)
	rect.texture = texture(id)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.custom_minimum_size = Vector2(0,height)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
static func panel_style(id: String,margin := 24.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(id)
	style.set_texture_margin_all(40)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

## A quiet six-stop chapter indicator on the launcher.
class ChapterPips extends Control:
	var current := 1
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y*0.5
		var first := 9.0
		var last := size.x-9.0
		draw_line(Vector2(first,y),Vector2(last,y),Color("ba9470"),4,true)
		draw_line(Vector2(first,y),Vector2(lerpf(first,last,float(current-1)/5.0),y),Color("d38b28"),4,true)
		for i in 6:
			var at := Vector2(lerpf(first,last,float(i)/5.0),y)
			draw_circle(at,6,Color("86532b"),true,-1,true)
			draw_circle(at,4.2,Color("ffd268") if i<current else Color("e3cba5"),true,-1,true)

class StepRail extends Control:
	var current := 0
	var count := 9
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var x := size.x*0.5
		draw_line(Vector2(x,12),Vector2(x,size.y-12),Color("b58449"),2,true)
		for i in count:
			var center := Vector2(x,lerpf(22,size.y-22,float(i)/maxi(1,count-1)))
			draw_circle(center,12 if i==current else 9,Color("835025"),true,-1,true)
			draw_circle(center,9 if i==current else 6,Color("ffce58") if i==current else (Color("bb8742") if i<current else Color("dac3a1")),true,-1,true)

## Decorative snow on the brass tabs, with no mouse interception.
static func tab_snow(button: Button) -> void:
	var snow := TabSnow.new()
	snow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	snow.offset_top = -5
	snow.offset_bottom = 3
	snow.offset_left = 3
	snow.offset_right = -3
	button.add_child(snow)

class TabSnow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for side in [0,1]:
			var x := 4.0 if side==0 else size.x-4.0
			for i in 5:
				var at := Vector2(x+(i*5 if side==0 else -i*5),4+sin(float(i)*1.7)*1.5)
				draw_circle(at+Vector2(0,1.8),4.5-i*0.4,JourneyStyle.SNOW_SHADE,true,-1,true)
				draw_circle(at,4.3-i*0.4,JourneyStyle.SNOW,true,-1,true)
