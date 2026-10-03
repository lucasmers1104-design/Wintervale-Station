## Schneidet die Zeilen-Symbole aus den freigegebenen Settings-Referenzbildern
## und speichert sie als freigestellte PNGs nach assets/ui/settings_icons/.
##
## Die Symbole sind dunkle Tinte auf hellem Pergament. Pro Symbol wird im
## Suchfenster der Hintergrund (Median der Randpixel) bestimmt; die Deckkraft
## jedes Pixels ergibt sich aus seinem Helligkeitsabstand zum Hintergrund, die
## Farbe ist die Tintenfarbe. So passen die Symbole auf jedes Pergament, ohne
## sichtbare Kästchen.
##
## Start: godot --headless --path . -s res://tools/extract_settings_icons.gd
extends SceneTree

const OUT := "res://assets/ui/settings_icons/"
const SIZE := 48
## Bild, Name, Mittelpunkt, halbe Fensterbreite/-höhe (Fenster nur um das Symbol).
const ICONS := [
	["settings_graphics", "resolution", Vector2(526, 371), Vector2(24, 21)],
	["settings_graphics", "fullscreen", Vector2(526, 420), Vector2(24, 20)],
	["settings_graphics", "vsync", Vector2(526, 468), Vector2(24, 20)],
	["settings_graphics", "shadows", Vector2(526, 521), Vector2(24, 21)],
	["settings_graphics", "bloom", Vector2(526, 626), Vector2(24, 21)],
	["settings_graphics", "particles", Vector2(526, 735), Vector2(24, 22)],
	["settings_audio", "master", Vector2(524, 373), Vector2(24, 21)],
	["settings_audio", "music", Vector2(524, 428), Vector2(24, 21)],
	["settings_audio", "ambient", Vector2(524, 482), Vector2(24, 21)],
	["settings_audio", "ui_sounds", Vector2(524, 538), Vector2(24, 21)],
	["settings_audio", "train", Vector2(524, 595), Vector2(24, 21)],
	["settings_audio", "weather", Vector2(524, 652), Vector2(24, 23)],
	["settings_controls", "camera", Vector2(532, 373), Vector2(22, 20)],
	["settings_controls", "sensitivity", Vector2(531, 437), Vector2(22, 20)],
	["settings_controls", "pan", Vector2(531, 492), Vector2(22, 18)],
	["settings_controls", "zoom", Vector2(531, 549), Vector2(22, 20)],
	["settings_controls", "invert", Vector2(531, 624), Vector2(22, 20)],
	["settings_controls", "keyboard", Vector2(1066, 373), Vector2(24, 20)],
	["settings_controls", "build", Vector2(1076, 445), Vector2(22, 20)],
	["settings_controls", "rotate", Vector2(1076, 497), Vector2(22, 20)],
	["settings_controls", "notebook", Vector2(1076, 662), Vector2(22, 20)],
	["settings_controls", "pause", Vector2(1076, 718), Vector2(22, 20)],
	["settings_gameplay", "autosave", Vector2(528, 355), Vector2(22, 20)],
	["settings_gameplay", "camera_smoothing", Vector2(528, 491), Vector2(22, 20)],
	["settings_gameplay", "day_speed", Vector2(528, 561), Vector2(22, 21)],
	["settings_gameplay", "achievements", Vector2(528, 702), Vector2(22, 21)],
	["settings_gameplay", "cozy", Vector2(528, 774), Vector2(22, 22)],
	["achievements", "trophy", Vector2(515, 266), Vector2(24, 24)],
	["achievements", "cat_railway", Vector2(512, 338), Vector2(32, 19)],
	["achievements", "cat_village", Vector2(515, 537), Vector2(34, 19)],
	["achievements", "cat_cozy", Vector2(512, 722), Vector2(24, 18)],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sources := {}
	for spec: Array in ICONS:
		var page: String = spec[0]
		if not sources.has(page):
			var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/menu_screens/%s.png" % page))
			image.convert(Image.FORMAT_RGBA8)
			sources[page] = image
		var icon := _extract(sources[page], spec[2], spec[3])
		var path: String = OUT + String(spec[1]) + ".png"
		icon.save_png(ProjectSettings.globalize_path(path))
		print("icon ", path)
	quit()


func _extract(source: Image, center: Vector2, half: Vector2) -> Image:
	var window := Rect2i(Vector2i(center - half), Vector2i(half * 2.0))
	# Hintergrund: Median der Randpixel des Fensters
	var border: Array[float] = []
	for x in range(window.position.x, window.end.x):
		border.append(source.get_pixel(x, window.position.y).get_luminance())
		border.append(source.get_pixel(x, window.end.y - 1).get_luminance())
	for y in range(window.position.y, window.end.y):
		border.append(source.get_pixel(window.position.x, y).get_luminance())
		border.append(source.get_pixel(window.end.x - 1, y).get_luminance())
	border.sort()
	var paper := border[int(border.size() / 2.0)]
	# Tintenfarbe: Mittel der dunkelsten Pixel
	var ink := Color(0, 0, 0)
	var ink_count := 0
	var darkest := 1.0
	for y in range(window.position.y, window.end.y):
		for x in range(window.position.x, window.end.x):
			darkest = minf(darkest, source.get_pixel(x, y).get_luminance())
	for y in range(window.position.y, window.end.y):
		for x in range(window.position.x, window.end.x):
			var c := source.get_pixel(x, y)
			if c.get_luminance() < darkest + 0.08:
				ink += c
				ink_count += 1
	ink = ink / float(maxi(ink_count, 1))
	var dims := Vector2i(maxi(SIZE, window.size.x), maxi(SIZE, window.size.y))
	var result := Image.create(dims.x, dims.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(ink.r, ink.g, ink.b, 0.0))
	var offset := Vector2i((Vector2(dims) - Vector2(window.size)) * 0.5)
	for y in range(window.position.y, window.end.y):
		for x in range(window.position.x, window.end.x):
			var lum := source.get_pixel(x, y).get_luminance()
			var alpha := clampf((paper - lum) / maxf(paper - darkest, 0.05), 0.0, 1.0)
			# Leichte Kurve: Papierstruktur verschwindet, Kanten bleiben weich
			alpha = smoothstep(0.12, 0.85, alpha)
			var target := Vector2i(x, y) - window.position + offset
			if target.x >= 0 and target.y >= 0 and target.x < dims.x and target.y < dims.y:
				result.set_pixelv(target, Color(ink.r, ink.g, ink.b, alpha))
	return result
