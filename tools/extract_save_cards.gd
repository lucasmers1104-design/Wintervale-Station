## Erzeugt Kartenrahmen, Knopfrahmen und Symbole der Spielstand-Seite aus der
## freigegebenen Referenz assets/ui/menu_screens/load_save.png.
##
## Rahmen: Der Rand bleibt pixelgleich; die Innenfläche mit Beispielinhalt wird
## durch einen Verlauf aus vier sauberen Papierstellen ersetzt (9-Slice-tauglich).
## Symbole: dunkle Tinte vom Papier freigestellt (wie extract_settings_icons.gd),
## farbige Jahreszeitensymbole behalten ihre Farbe.
##
## Start: godot --headless --path . -s res://tools/extract_save_cards.gd
extends SceneTree

const SOURCE := "res://assets/ui/menu_screens/load_save.png"
const OUT := "res://assets/ui/save_art/"
## Name: [Rechteck, Innenabstand, vier saubere Papierstellen (absolut: oben links/rechts, unten links/rechts)]
const FRAMES := {
	"card_highlight": [Rect2i(296, 249, 1101, 153), 13, [Vector2i(626, 262), Vector2i(1150, 260), Vector2i(626, 392), Vector2i(1152, 392)]],
	"card": [Rect2i(304, 410, 1088, 146), 12, [Vector2i(628, 420), Vector2i(1172, 420), Vector2i(628, 547), Vector2i(1172, 545)]],
	"card_empty": [Rect2i(304, 722, 1088, 114), 12, [Vector2i(630, 732), Vector2i(1150, 732), Vector2i(630, 826), Vector2i(1150, 826)]],
	"button_gold": [Rect2i(1163, 270, 214, 52), 9, [Vector2i(1175, 279), Vector2i(1364, 279), Vector2i(1175, 313), Vector2i(1364, 313)]],
	"button_plain": [Rect2i(1176, 333, 193, 45), 8, [Vector2i(1186, 341), Vector2i(1360, 341), Vector2i(1186, 370), Vector2i(1360, 370)]],
}
## Name: [Mitte, halbe Fenstergröße]
const ICONS := {
	"calendar": [Vector2(654, 343), Vector2(13, 13)],
	"season_winter": [Vector2(654, 371), Vector2(13, 13)],
	"season_autumn": [Vector2(656, 530), Vector2(13, 13)],
	"season_spring": [Vector2(656, 686), Vector2(13, 13)],
	"trains": [Vector2(911, 296), Vector2(14, 12)],
	"population": [Vector2(911, 325), Vector2(14, 12)],
	"playtime": [Vector2(911, 353), Vector2(13, 13)],
	"load": [Vector2(1217, 297), Vector2(22, 16)],
	"delete": [Vector2(1227, 356), Vector2(14, 15)],
	"plus": [Vector2(1215, 777), Vector2(15, 15)],
}
const SKETCH := Rect2i(316, 737, 301, 88)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	for frame_name: String in FRAMES:
		var spec: Array = FRAMES[frame_name]
		var frame := _clean(source, spec[0], spec[1], spec[2])
		if frame_name == "card_empty":
			# In der Vorlage ragt der Stempel "Good Journeys Ahead" in die Ecke unten
			# rechts – dort die gespiegelte Ecke unten links einsetzen.
			_mirror_corner(frame, Vector2i(90, 34))
		frame.save_png(ProjectSettings.globalize_path(OUT + frame_name + ".png"))
		print("frame ", frame_name, " ", frame.get_size())
	for icon_name: String in ICONS:
		var spec: Array = ICONS[icon_name]
		_icon(source, spec[0], spec[1]).save_png(ProjectSettings.globalize_path(OUT + icon_name + ".png"))
		print("icon ", icon_name)
	source.get_region(SKETCH).save_png(ProjectSettings.globalize_path(OUT + "empty_sketch.png"))
	print("sketch")
	quit()


func _clean(source: Image, rect: Rect2i, inset: int, samples: Array) -> Image:
	var image := source.get_region(rect)
	var corners: Array[Color] = []
	for p: Vector2i in samples:
		corners.append(_average(source, p))
	var w := rect.size.x
	var h := rect.size.y
	for y in range(inset, h - inset):
		for x in range(inset, w - inset):
			var u := clampf(float(x + rect.position.x - samples[0].x) / float(samples[1].x - samples[0].x), 0.0, 1.0)
			var v := clampf(float(y + rect.position.y - samples[0].y) / float(samples[2].y - samples[0].y), 0.0, 1.0)
			var fill := corners[0].lerp(corners[1], u).lerp(corners[2].lerp(corners[3], u), v)
			image.set_pixel(x, y, fill)
	return image


func _mirror_corner(image: Image, corner: Vector2i) -> void:
	var w := image.get_width()
	var h := image.get_height()
	# Nur das Randband spiegeln; die Innenfläche ist schon bereinigt.
	var band := 12
	for y in range(h - corner.y, h):
		for x in range(w - corner.x, w):
			if x >= w - band or y >= h - band:
				image.set_pixel(x, y, image.get_pixel(w - 1 - x, y))


func _average(image: Image, p: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in range(p.y - 2, p.y + 3):
		for x in range(p.x - 2, p.x + 3):
			sum += image.get_pixel(x, y)
	return sum / 25.0


func _icon(source: Image, center: Vector2, half: Vector2) -> Image:
	var window := Rect2i(Vector2i(center - half), Vector2i(half * 2.0))
	var border: Array[float] = []
	var paper_color := Color(0, 0, 0, 0)
	for x in range(window.position.x, window.end.x):
		for y: int in [window.position.y, window.end.y - 1]:
			border.append(source.get_pixel(x, y).get_luminance())
			paper_color += source.get_pixel(x, y)
	paper_color /= float(border.size())
	border.sort()
	var paper := border[int(border.size() / 2.0)]
	var image := Image.create(window.size.x, window.size.y, false, Image.FORMAT_RGBA8)
	for y in window.size.y:
		for x in window.size.x:
			var c := source.get_pixel(window.position.x + x, window.position.y + y)
			# Abstand zur Papierfarbe (Helligkeit und Farbton) ergibt die Deckkraft
			var difference := Vector3(c.r - paper_color.r, c.g - paper_color.g, c.b - paper_color.b).length()
			var alpha := smoothstep(0.08, 0.38, maxf(difference, paper - c.get_luminance()))
			image.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	return image
