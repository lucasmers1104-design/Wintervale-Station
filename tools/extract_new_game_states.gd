## Erzeugt die Auswahlzustände der New-Game-Seite aus der freigegebenen Vorlage
## assets/ui/menu_screens/new_game.png (dort ist "Male" und "Winter" ausgewählt).
##
## Jahreszeiten: Der leere goldene Rahmen (aus "Winter") und der leere normale
## Rahmen (aus "Spring") entstehen durch Ausfüllen von Symbol und Schrift
## (Laplace-Glättung aus der Umgebung). Symbol und Schrift jeder Jahreszeit werden
## dann auf beide Rahmen übertragen – die Pixel stammen alle aus der Vorlage.
## Figuren: Rahmen samt Leuchten kommt vom ausgewählten bzw. normalen Feld, das
## Porträt vom eigenen Feld; sein Farbton wird an den Zustand angeglichen, das
## Häkchen wird übertragen bzw. entfernt.
## Außerdem: kleine Jahreszeiten-Symbole für die Infozeile links.
##
## Start: godot --headless --path . -s res://tools/extract_new_game_states.gd
extends SceneTree

const SOURCE := "res://assets/ui/menu_screens/new_game.png"
const OUT := "res://assets/ui/new_game_art/"
const SEASONS := {"winter": 1020, "spring": 1123, "summer": 1225, "autumn": 1328}
const SEASON_Y := 682
const SEASON_SIZE := Vector2i(97, 93)
const SEASON_MARGIN := 4
const SEASON_INSET := 6
const CHARACTERS := {"male": 1022, "female": 1225}
const CHAR_Y := 406
const CHAR_SIZE := Vector2i(193, 214)
const CHAR_MARGIN := 6
const CHAR_INSET := 7
## Häkchen im ausgewählten Figurenfeld (Mitte, Radius) – in Feldkoordinaten.
const CHECK_CENTER := Vector2(167.0, 25.0)
const CHECK_RADIUS := 13.0

var _source: Image


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_source = Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	_source.convert(Image.FORMAT_RGBA8)
	_build_seasons()
	_build_characters()
	quit()


# --- Jahreszeiten ------------------------------------------------------------------------

func _season_tile(season: String) -> Image:
	var origin := Vector2i(SEASONS[season] - SEASON_MARGIN, SEASON_Y - SEASON_MARGIN)
	return _source.get_region(Rect2i(origin, SEASON_SIZE + Vector2i.ONE * SEASON_MARGIN * 2))


func _build_seasons() -> void:
	var on_base := _empty(_season_tile("winter"), true)
	var off_base := _empty(_season_tile("spring"), false)
	for season: String in SEASONS:
		var tile := _season_tile(season)
		var selected_in_art := season == "winter"
		var own_background := _empty(tile, selected_in_art)
		for state: String in ["on", "off"]:
			var result := _transfer(tile, own_background, on_base if state == "on" else off_base)
			result.save_png(ProjectSettings.globalize_path("%sseason_%s_%s.png" % [OUT, season, state]))
		# Kleines Symbol (obere Hälfte des Feldes) für die Infozeile
		var icon_rect := Rect2i(SEASON_MARGIN + 18, SEASON_MARGIN + 8, 61, 48)
		var icon := Image.create(icon_rect.size.x, icon_rect.size.y, false, Image.FORMAT_RGBA8)
		for y in icon_rect.size.y:
			for x in icon_rect.size.x:
				var p := icon_rect.position + Vector2i(x, y)
				var c := tile.get_pixelv(p)
				var bg := own_background.get_pixelv(p)
				var alpha := smoothstep(0.06, 0.3, _distance(c, bg))
				icon.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
		icon.save_png(ProjectSettings.globalize_path("%sicon_%s.png" % [OUT, season]))
		print("season ", season)


## Füllt Symbol und Schrift im Inneren des Feldes aus der Umgebung auf.
func _empty(tile: Image, golden: bool) -> Image:
	var result := tile.duplicate() as Image
	var inset := SEASON_MARGIN + SEASON_INSET
	var mask := {}
	for y in range(inset, tile.get_height() - inset):
		for x in range(inset, tile.get_width() - inset):
			var c := tile.get_pixel(x, y)
			var content := c.get_luminance() < 0.62 or c.b > c.r - 0.05
			if not golden:
				content = content or c.g < 0.62 or c.b < 0.5
			if content:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var q := Vector2i(x + dx, y + dy)
						if q.x >= inset and q.y >= inset and q.x < tile.get_width() - inset and q.y < tile.get_height() - inset:
							mask[q] = true
	_laplace_fill(result, mask, 500)
	# Zweiter Durchgang: auch helle Kantenpixel, die noch vom geglätteten Hintergrund
	# abweichen, gehören zum Inhalt (sonst bleiben Reste von Symbol und Schrift).
	var refined := {}
	for y in range(inset, tile.get_height() - inset):
		for x in range(inset, tile.get_width() - inset):
			if _distance(tile.get_pixel(x, y), result.get_pixel(x, y)) > 0.05:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q := Vector2i(x + dx, y + dy)
						if q.x >= inset and q.y >= inset and q.x < tile.get_width() - inset and q.y < tile.get_height() - inset:
							refined[q] = true
	result = tile.duplicate() as Image
	mask.merge(refined)
	_laplace_fill(result, mask, 700)
	return result


## Überträgt Symbol/Schrift von [param tile] (Hintergrund [param background]) auf [param base].
func _transfer(tile: Image, background: Image, base: Image) -> Image:
	var result := base.duplicate() as Image
	var inset := SEASON_MARGIN + SEASON_INSET
	for y in range(inset, tile.get_height() - inset):
		for x in range(inset, tile.get_width() - inset):
			var c := tile.get_pixel(x, y)
			var bg := background.get_pixel(x, y)
			var target := base.get_pixel(x, y)
			# Deckkraft aus dem Abstand zum Hintergrund, Vordergrundfarbe entmischt
			# (c = bg + a·(f − bg)); so bleiben Kanten weich ohne Farbsaum.
			var a := clampf(_distance(c, bg) / 0.28, 0.0, 1.0)
			if a < 0.04:
				continue
			var f := Color(clampf(bg.r + (c.r - bg.r) / a, 0, 1), clampf(bg.g + (c.g - bg.g) / a, 0, 1),
				clampf(bg.b + (c.b - bg.b) / a, 0, 1), 1.0)
			result.set_pixel(x, y, target.lerp(f, a))
	return result


# --- Figuren -----------------------------------------------------------------------------

func _char_tile(id: String) -> Image:
	var origin := Vector2i(CHARACTERS[id] - CHAR_MARGIN, CHAR_Y - CHAR_MARGIN)
	return _source.get_region(Rect2i(origin, CHAR_SIZE + Vector2i.ONE * CHAR_MARGIN * 2))


func _build_characters() -> void:
	var male := _char_tile("male")        # ausgewählt
	var female := _char_tile("female")    # normal
	# Links neben "Female" leuchtet in der Vorlage noch der Rand von "Male" herein:
	# dort den (sauberen) rechten Rand gespiegelt einsetzen.
	var w := female.get_width()
	for y in female.get_height():
		for x in CHAR_MARGIN + 2:
			female.set_pixel(x, y, female.get_pixel(w - 1 - x, y))
	# Farbton ausgewählt ↔ normal aus Namensschild und Hintergrund der Porträts
	var gain := Vector3.ZERO
	var samples := [[Rect2i(24, 186, 36, 14), Rect2i(24, 186, 36, 14)], [Rect2i(14, 36, 26, 26), Rect2i(14, 36, 26, 26)]]
	for pair: Array in samples:
		var selected := _mean(male, pair[0])
		var normal := _mean(female, pair[1])
		gain += Vector3(normal.r / selected.r, normal.g / selected.g, normal.b / selected.b)
	gain /= float(samples.size())
	print("tone gain selected→normal ", gain)
	var check := _cut_check(male)
	var male_clean := male.duplicate() as Image
	_remove_check(male_clean)
	_save_char("male_on", male)
	_save_char("male_off", _swap_ring(male_clean, female, gain))
	_save_char("female_off", female)
	var female_on := _swap_ring(female, male, Vector3(1.0 / gain.x, 1.0 / gain.y, 1.0 / gain.z))
	_paste(female_on, check)
	_save_char("female_on", female_on)


## Porträt aus [param portrait] mit Ton-[param gain], Rahmen und Leuchten aus [param frame].
func _swap_ring(portrait: Image, frame: Image, gain: Vector3) -> Image:
	var result := frame.duplicate() as Image
	var inset := CHAR_MARGIN + CHAR_INSET
	for y in range(inset, result.get_height() - inset):
		for x in range(inset, result.get_width() - inset):
			var c := portrait.get_pixel(x, y)
			result.set_pixel(x, y, Color(clampf(c.r * gain.x, 0, 1), clampf(c.g * gain.y, 0, 1), clampf(c.b * gain.z, 0, 1), 1.0))
	return result


func _cut_check(tile: Image) -> Image:
	var center := CHECK_CENTER + Vector2.ONE * CHAR_MARGIN
	var icon := Image.create(tile.get_width(), tile.get_height(), false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	for y in range(int(center.y - CHECK_RADIUS) - 2, int(center.y + CHECK_RADIUS) + 3):
		for x in range(int(center.x - CHECK_RADIUS) - 2, int(center.x + CHECK_RADIUS) + 3):
			var c := tile.get_pixel(x, y)
			c.a = clampf(CHECK_RADIUS + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(center), 0.0, 1.0)
			icon.set_pixel(x, y, c)
	return icon


func _remove_check(tile: Image) -> void:
	var center := CHECK_CENTER + Vector2.ONE * CHAR_MARGIN
	var mask := {}
	for y in range(int(center.y - CHECK_RADIUS) - 6, int(center.y + CHECK_RADIUS) + 7):
		for x in range(int(center.x - CHECK_RADIUS) - 6, int(center.x + CHECK_RADIUS) + 7):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= CHECK_RADIUS + 4.5:
				mask[Vector2i(x, y)] = true
	_laplace_fill(tile, mask, 600)


func _paste(target: Image, overlay: Image) -> void:
	for y in overlay.get_height():
		for x in overlay.get_width():
			var o := overlay.get_pixel(x, y)
			if o.a > 0.0:
				target.set_pixel(x, y, target.get_pixel(x, y).lerp(Color(o.r, o.g, o.b, 1.0), o.a))


func _save_char(file_name: String, image: Image) -> void:
	image.save_png(ProjectSettings.globalize_path(OUT + "character_" + file_name + ".png"))
	print("character ", file_name)


# --- Hilfen ------------------------------------------------------------------------------

func _laplace_fill(image: Image, mask: Dictionary, iterations: int) -> void:
	var points: Array = mask.keys()
	# In Gleitkomma rechnen: im 8-Bit-Bild würde jede Runde abrunden und die Fläche
	# über viele Durchgänge dunkler statt glatter machen. Werte außerhalb der Maske
	# bleiben fest.
	var values := {}
	for p: Vector2i in points:
		values[p] = image.get_pixelv(p)
	for i in iterations:
		for p: Vector2i in points:
			var sum := Color(0, 0, 0, 0)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				sum += values[q] if values.has(q) else image.get_pixelv(q)
			values[p] = sum / 4.0
	for p: Vector2i in points:
		image.set_pixelv(p, values[p])


func _mean(image: Image, rect: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			sum += image.get_pixel(x, y)
	return sum / float(rect.get_area())


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
