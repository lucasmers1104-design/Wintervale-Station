## Erzeugt assets/ui/menu_screens/credits_clean.png aus der freigegebenen
## Credits-Vorlage: Nur die erfundenen Beispielnamen unter den Überschriften
## werden entfernt (zeilenweise zwischen linkem und rechtem Rand des Bereichs
## interpoliert). Überschriften, Symbole, Linien, Sterne und Skizzen bleiben
## Pixel für Pixel erhalten; das Spiel setzt echte Namen an dieselben Stellen.
##
## Start: godot --headless --path . -s res://tools/clean_credits_names.gd
extends SceneTree

const SOURCE := "res://assets/ui/menu_screens/credits.png"
const TARGET := "res://assets/ui/menu_screens/credits_clean.png"
## Namensbereiche (x0, y0, x1, y1) in der 1672×941-Vorlage, vermessen.
const REGIONS := [
	Rect2i(484, 336, 124, 30),   # Creative Director
	Rect2i(484, 455, 110, 57),   # Programming
	Rect2i(484, 600, 134, 86),   # Art & Environment
	Rect2i(1043, 336, 112, 56),  # Sound & Music
	Rect2i(1043, 469, 150, 56),  # UI / UX Design
	Rect2i(1045, 600, 250, 136), # Special Thanks
]


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	image.convert(Image.FORMAT_RGBA8)
	for region: Rect2i in REGIONS:
		for y in range(region.position.y, region.end.y):
			var left := _sample(image, region.position.x - 3, y)
			var right := _sample(image, region.end.x + 2, y)
			for x in range(region.position.x, region.end.x):
				var t := float(x - region.position.x) / float(region.size.x)
				image.set_pixel(x, y, left.lerp(right, t))
	image.save_png(ProjectSettings.globalize_path(TARGET))
	print("credits cleaned -> ", TARGET)
	quit()


## Heller Papierwert: Median von fünf Nachbarpixeln (Tintenreste fallen heraus).
func _sample(image: Image, x: int, y: int) -> Color:
	var values: Array[Color] = []
	for dy in range(-2, 3):
		values.append(image.get_pixel(x, clampi(y + dy, 0, image.get_height() - 1)))
	values.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	return values[2]
