## Erzeugt assets/ui/hud_status_bar_clean.png aus der freigegebenen HUD-Leiste.
##
## Die Vorlage hat eine aufgemalte Uhr, die fest 4:00 zeigt. Im Spiel laufen
## die Zeiger live mit (HudClockHands), deshalb werden die gemalten Zeiger hier
## entfernt, alles andere bleibt Pixel für Pixel erhalten:
## 1. Jeder Pixel unter einem Zeiger wird entlang seines Kreises (gleicher
##    Radius) zwischen den nächsten freien Pixeln links und rechts interpoliert.
##    So bleiben Papierfarbe und Schattierung des Zifferblatts erhalten.
## 2. Der 12-Uhr-Strich lag unter dem Minutenzeiger. Er entsteht neu als
##    gespiegelte Abdunklung des (gleich geformten) 6-Uhr-Strichs.
##
## Start: godot --headless --path . -s res://tools/generate_hud_clock_face.gd
extends SceneTree

const SOURCE := "res://assets/ui/hud_status_bar.png"
const TARGET := "res://assets/ui/hud_status_bar_clean.png"
## Mitte und Innenradius des Zifferblatts in der 1672×941-Vorlage (gemessen an
## den Strichen bei 3, 6 und 9 Uhr und am Messingring).
const CENTER := Vector2(1167.0, 196.8)
const FACE_RADIUS := 39.0
const MINUTE_ANGLE := 0.0
const MINUTE_LENGTH := 39.5
const MINUTE_HALF_WIDTH := 5.0
const HOUR_ANGLE := 129.0
const HOUR_LENGTH := 31.0
const HOUR_HALF_WIDTH := 6.5
const TAIL := 6.0
const CAP_RADIUS := 7.5
const TICK_HALF_WIDTH := 3.5
const TICK_RADII := Vector2(28.5, 39.0)


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	var result := source.duplicate() as Image
	var changed := 0
	# Erst die Zeiger, danach die Mittelkappe aus dem schon bereinigten Ring.
	for cap_pass: bool in [false, true]:
		changed += _clean(source, result, cap_pass)
	result.save_png(ProjectSettings.globalize_path(TARGET))
	print("hud clock face cleaned: %d pixels -> %s" % [changed, TARGET])
	quit()


func _clean(source: Image, result: Image, cap_pass: bool) -> int:
	var changed := 0
	for y in range(int(CENTER.y - FACE_RADIUS) - 1, int(CENTER.y + FACE_RADIUS) + 2):
		for x in range(int(CENTER.x - FACE_RADIUS) - 1, int(CENTER.x + FACE_RADIUS) + 2):
			var d := Vector2(x + 0.5, y + 0.5) - CENTER
			if d.length() > FACE_RADIUS or not _masked(d) or (d.length() < CAP_RADIUS) != cap_pass:
				continue
			var color := _bilinear(result, CENTER + d.normalized() * (CAP_RADIUS + 1.0)) if cap_pass \
				else _along_circle(source, d)
			if _in_top_tick(d):
				color = _with_tick(source, color, x, y)
			result.set_pixel(x, y, color)
			changed += 1
	return changed


func _masked(d: Vector2) -> bool:
	return d.length() < CAP_RADIUS \
		or _near_hand(d, MINUTE_ANGLE, MINUTE_LENGTH, MINUTE_HALF_WIDTH) \
		or _near_hand(d, HOUR_ANGLE, HOUR_LENGTH, HOUR_HALF_WIDTH)


## Liegt [param d] auf einem Zeiger (Winkel ab 12 Uhr im Uhrzeigersinn)?
func _near_hand(d: Vector2, degrees: float, length: float, half_width: float) -> bool:
	var axis := _direction(degrees)
	var along := d.dot(axis)
	if along < -TAIL or along > length:
		return false
	return absf(d.dot(Vector2(-axis.y, axis.x))) <= half_width


## Interpoliert entlang des Kreises zwischen den nächsten ungedeckten Pixeln.
func _along_circle(image: Image, d: Vector2) -> Color:
	var radius := d.length()
	var angle := atan2(d.x, -d.y)
	var step := 0.5 / radius
	var left := angle
	while _masked(_polar(left, radius)) and left > angle - PI:
		left -= step
	var right := angle
	while _masked(_polar(right, radius)) and right < angle + PI:
		right += step
	left -= 1.5 / radius
	right += 1.5 / radius
	var t := (angle - left) / (right - left)
	return _bilinear(image, CENTER + _polar(left, radius)).lerp(
		_bilinear(image, CENTER + _polar(right, radius)), t)


func _in_top_tick(d: Vector2) -> bool:
	return absf(d.x) <= TICK_HALF_WIDTH and -d.y >= TICK_RADII.x and -d.y <= TICK_RADII.y


## Überträgt die Abdunklung des 6-Uhr-Strichs (gespiegelt) auf die 12.
func _with_tick(image: Image, base: Color, x: int, y: int) -> Color:
	var mirror_y := int(round(2.0 * CENTER.y - float(y) - 1.0))
	var tick := image.get_pixel(x, mirror_y)
	var paper := image.get_pixel(int(CENTER.x) - 5, mirror_y).lerp(
		image.get_pixel(int(CENTER.x) + 5, mirror_y), 0.5)
	var shade := clampf(tick.get_luminance() / maxf(paper.get_luminance(), 0.01), 0.0, 1.0)
	var dark := Color(tick.r, tick.g, tick.b, base.a)
	return dark.lerp(base, shade)


func _direction(degrees: float) -> Vector2:
	return Vector2(sin(deg_to_rad(degrees)), -cos(deg_to_rad(degrees)))


func _polar(angle: float, radius: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle)) * radius


func _bilinear(image: Image, p: Vector2) -> Color:
	p -= Vector2(0.5, 0.5)
	var x0 := int(floor(p.x))
	var y0 := int(floor(p.y))
	var fx := p.x - x0
	var fy := p.y - y0
	var top := image.get_pixel(x0, y0).lerp(image.get_pixel(x0 + 1, y0), fx)
	var bottom := image.get_pixel(x0, y0 + 1).lerp(image.get_pixel(x0 + 1, y0 + 1), fx)
	return top.lerp(bottom, fy)
