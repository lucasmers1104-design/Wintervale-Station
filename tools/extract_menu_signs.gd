## Schneidet die gemalten Bahnhofsschilder aus der freigegebenen Ladescreen-Grafik
## (assets/ui/loading_screen_reference.png) und speichert sie freigestellt nach
## assets/ui/main_menu/signs/. Das Hauptmenü setzt sie an die Stelle der früher
## per Code gezeichneten, flachen Schild-Nachbauten.
##
## Jedes Schild wird über ein Vieleck (Kanten an der Vorlage vermessen) ausgeschnitten;
## der Rand bekommt 1,5 px weiche Deckkraft, damit keine harte Treppenkante entsteht.
##
## Start: godot --headless --path . -s res://tools/extract_menu_signs.gd
extends SceneTree

const SOURCE := "res://assets/ui/loading_screen_reference.png"
const OUT := "res://assets/ui/main_menu/signs/"
const FEATHER := 1.5
## Name: Umriss in Pixeln der 1672×941-Vorlage (im Uhrzeigersinn).
const SIGNS := {
	# Hängeschild unter der Bahnhofsuhr
	"station_name": [Vector2(1382, 357), Vector2(1597, 300), Vector2(1597, 347), Vector2(1382, 419)],
	# Wegweiser (ohne Pfosten)
	"direction": [Vector2(312, 449.5), Vector2(442, 460), Vector2(451, 475), Vector2(451, 502),
		Vector2(442, 514.5), Vector2(312, 513.5)],
	# Tafel "Trains bring people closer" samt Schneekante unten
	"chalkboard": [Vector2(1565, 408), Vector2(1672, 398), Vector2(1672, 596), Vector2(1565, 596)],
}
## Zielanzeige am Zug: abgerundetes Rechteck (x0, y0, x1, y1, Eckradius).
const TRAIN_DISPLAY := [794.0, 427.0, 890.0, 453.0, 6.0]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	for sign_name: String in SIGNS:
		var outline := PackedVector2Array(SIGNS[sign_name])
		_cut(source, sign_name, func(p: Vector2) -> float: return _polygon_coverage(outline, p), _bounds(outline))
	var r: Array = TRAIN_DISPLAY
	_cut(source, "train_display", func(p: Vector2) -> float: return _rounded_rect_coverage(r, p),
		Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]))
	quit()


func _cut(source: Image, sign_name: String, coverage: Callable, bounds: Rect2) -> void:
	var rect := Rect2i(Vector2i(bounds.position.floor()), Vector2i((bounds.end - bounds.position.floor()).ceil()))
	var image := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for y in rect.size.y:
		for x in rect.size.x:
			var p := Vector2(rect.position.x + x + 0.5, rect.position.y + y + 0.5)
			var color := source.get_pixelv(Vector2i(p))
			color.a = float(coverage.call(p))
			image.set_pixel(x, y, color)
	image.save_png(ProjectSettings.globalize_path(OUT + sign_name + ".png"))
	print("sign ", sign_name, " origin ", rect.position, " size ", rect.size)


func _bounds(outline: PackedVector2Array) -> Rect2:
	var box := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		box = box.expand(p)
	return box


## 1 innen, 0 außen, weicher Übergang über [constant FEATHER] Pixel an der Kante.
func _polygon_coverage(outline: PackedVector2Array, p: Vector2) -> float:
	var distance := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	var inside := Geometry2D.is_point_in_polygon(p, outline)
	var signed := distance if inside else -distance
	return clampf(signed / FEATHER + 0.5, 0.0, 1.0)


func _rounded_rect_coverage(r: Array, p: Vector2) -> float:
	var radius: float = r[4]
	var center := Vector2((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5)
	var half := Vector2((r[2] - r[0]) * 0.5 - radius, (r[3] - r[1]) * 0.5 - radius)
	var q := (p - center).abs() - half
	var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
	return clampf(-outside / FEATHER + 0.5, 0.0, 1.0)
