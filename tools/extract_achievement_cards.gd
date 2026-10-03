## Erzeugt die Achievement-Kartenrahmen und das Häkchen aus der freigegebenen
## Referenz assets/ui/menu_screens/achievements.png.
##
## Kartenrahmen: Der Rand (verzierte Doppellinie mit eingekerbten Ecken) bleibt
## pixelgleich; die Innenfläche mit Beispielinhalt wird durch einen weichen
## Verlauf aus den vier sauberen Innenecken ersetzt. Das Ergebnis dient als
## 9-Slice-Rahmen (StyleBoxTexture) für echte Karten.
## Häkchen: runder Ausschnitt mit weichem Rand.
##
## Start: godot --headless --path . -s res://tools/extract_achievement_cards.gd
extends SceneTree

const SOURCE := "res://assets/ui/menu_screens/achievements.png"
const OUT := "res://assets/ui/achievement_art/"
## Freigeschaltet: "First Departure", gesperrt: "Busy Platform" (vermessen).
const CARDS := {"card_unlocked": Rect2i(475, 367, 263, 130), "card_locked": Rect2i(747, 367, 250, 130)}
## Ab diesem Abstand vom Kartenrand beginnt die bereinigte Innenfläche.
const INSET := 12
const CHECK_CENTER := Vector2(608.3, 467.3)
const CHECK_RADIUS := 12.5


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	for card_name: String in CARDS:
		var card := _clean_card(source.get_region(CARDS[card_name]))
		card.save_png(ProjectSettings.globalize_path(OUT + card_name + ".png"))
		print("card ", card_name, " ", card.get_size())
	_check_icon(source).save_png(ProjectSettings.globalize_path(OUT + "check.png"))
	print("check icon")
	quit()


func _clean_card(card: Image) -> Image:
	var w := card.get_width()
	var h := card.get_height()
	var corners := [_average(card, INSET + 2, INSET + 2), _average(card, w - INSET - 3, INSET + 2),
		_average(card, INSET + 2, h - INSET - 3), _average(card, w - INSET - 3, h - INSET - 3)]
	for y in range(INSET, h - INSET):
		for x in range(INSET, w - INSET):
			var u := float(x - INSET) / float(w - 2 * INSET - 1)
			var v := float(y - INSET) / float(h - 2 * INSET - 1)
			var top: Color = corners[0].lerp(corners[1], u)
			var bottom: Color = corners[2].lerp(corners[3], u)
			var fill := top.lerp(bottom, v)
			# Weicher Übergang an der Innenkante, damit keine Naht entsteht
			var edge := mini(mini(x - INSET, w - INSET - 1 - x), mini(y - INSET, h - INSET - 1 - y))
			var keep := 0.35 if edge == 0 else 0.0
			card.set_pixel(x, y, fill.lerp(card.get_pixel(x, y), keep))
	return card


func _average(image: Image, cx: int, cy: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			sum += image.get_pixel(x, y)
	return sum / 9.0


func _check_icon(source: Image) -> Image:
	var size := int(ceil(CHECK_RADIUS * 2.0)) + 2
	var icon := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var origin := CHECK_CENTER - Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := origin + Vector2(x + 0.5, y + 0.5)
			var color := source.get_pixelv(Vector2i(p))
			var distance := p.distance_to(CHECK_CENTER)
			color.a = clampf(CHECK_RADIUS + 0.5 - distance, 0.0, 1.0)
			icon.set_pixel(x, y, color)
	return icon
