## Baut beim ersten Spielstart das kleine Startdorf hinter dem Bahnhof.
##
## Nur wenn das Dorf leer ist (neues Spiel). Gebaut wird ausschließlich über
## [method VillageManager.place] – alles ist also normal speicherbar und kann
## abgerissen oder ergänzt werden.
##
##   Bahnhof ─ Übergang ─ Dorfstraße (z ≈ 12,5) ────────────── Dorfrand
##                          │ Berger     Dorfplatz   Kellner  Sommer   (Nordseite)
##                          │            Winter      Hofer              (Südseite)
##
## Die Häuser der fünf bekannten Familien ersetzen die Platzhalter aus Etappe 4.
class_name StarterVillage
extends RefCounted

const STREET_Z := 12.5

## [param village] bauen, falls leer. Rückgabe: true = gebaut.
static func build_if_empty(village: VillageManager) -> bool:
	if not village.is_empty():
		return false
	build(village)
	return true


static func build(village: VillageManager) -> void:
	# Dorfstraße vom Bahnhofsvorplatz bis zum Dorfrand
	_line(village, "path_road", Vector3(-13.0, 0, 12.7), Vector3(-33.0, 0, STREET_Z))
	_line(village, "path_road", Vector3(-33.0, 0, STREET_Z), Vector3(-53.0, 0, STREET_Z))
	# Dorfplatz nördlich der Straße – der Mittelpunkt zwischen Bahnhof und Häusern
	_point(village, "plaza", Vector3(-27.0, 0, 4.0), 0.0)
	# Häuser der bekannten Familien: Nordseite Tür nach +Z (Drehung 180°), Südseite Tür nach -Z
	_house(village, "house_cottage", Vector3(-15.0, 0, 1.5), PI, 0, "Berger")
	_house(village, "house_chalet", Vector3(-38.5, 0, 3.0), PI, 1, "Kellner")
	_house(village, "house_townhouse", Vector3(-46.5, 0, 4.0), PI, 2, "Sommer")
	_house(village, "house_tower", Vector3(-24.0, 0, 21.8), 0.0, 4, "Winter")
	_house(village, "house_farmhouse", Vector3(-37.0, 0, 22.8), 0.0, 3, "Hofer")
	# Kieswege von den Haustüren zur Straße
	for house in village.get_houses():
		var door := house.get_front_point()
		var toward := 1.0 if door.z < STREET_Z else -1.0
		_line(village, "path_gravel", Vector3(door.x, 0, door.z), Vector3(door.x, 0, STREET_Z - toward * 1.2))
	# Steinweg vom Platz zur Straße ist der Platz selbst; ein kleiner Steinweg zum Winterhaus-Garten
	# Straßenlaternen entlang der Dorfstraße
	for x: float in [-19.5, -41.5]:
		_point(village, "street_lamp", Vector3(x, 0, STREET_Z - 2.3), PI)
	_point(village, "street_lamp", Vector3(-31.0, 0, STREET_Z + 2.4), 0.0)
	_point(village, "street_lamp", Vector3(-50.5, 0, STREET_Z + 2.4), 0.0)
	# Lichterkette nördlich des Dorfplatzes
	_line(village, "string_lights", Vector3(-33.0, 0, -3.3), Vector3(-21.0, 0, -3.3))
	# Gärten: Zäune, Hecken, Beete, Gartenlampen
	_line(village, "fence", Vector3(-18.6, 0, 5.8), Vector3(-16.1, 0, 5.8))
	_line(village, "fence", Vector3(-13.9, 0, 5.8), Vector3(-11.6, 0, 5.8))
	_point(village, "flower_bed", Vector3(-17.4, 0, 7.4), 0.0)
	_point(village, "garden_lamp", Vector3(-15.9, 0, 8.6), 0.0)
	_line(village, "hedge", Vector3(-29.0, 0, 26.2), Vector3(-29.0, 0, 18.4))
	_point(village, "garden_lamp", Vector3(-25.9, 0, 16.0), 0.0)
	_point(village, "garden_lamp", Vector3(-35.6, 0, 16.9), 0.0)
	_line(village, "fence", Vector3(-42.0, 0, 18.0), Vector3(-42.0, 0, 27.2))
	_point(village, "log_pile", Vector3(-43.6, 0, 22.4), 0.0)
	_point(village, "flower_bed", Vector3(-39.4, 0, 8.0), 0.3)
	_point(village, "garden_lamp", Vector3(-45.9, 0, 9.6), 0.0)
	_point(village, "bush_holly", Vector3(-48.4, 0, 8.4), 0.0)
	# Bäume und Büsche rund ums Dorf
	var trees := [["tree_round", -18.2, -2.8], ["tree_birch", -12.8, -6.8], ["tree_fir_full", -33.5, -6.5],
		["tree_birch", -42.5, -3.5], ["tree_pine_tall", -51.5, -2.0], ["tree_round", -30.5, 29.5],
		["tree_spruce_snowy", -45.5, 29.0], ["tree_birch", -18.2, 26.0], ["tree_small", -34.4, 9.2],
		["tree_small", -52.0, 17.5], ["tree_fir_full", -56.5, 7.0]]
	for tree: Array in trees:
		_point(village, tree[0], Vector3(tree[1], 0, tree[2]), float(tree[1]) * 0.7)
	for bush: Array in [["bush_round", -11.4, 7.8], ["bush_juniper", -18.4, 17.6], ["bush_snowy", -34.2, 17.1],
			["bush_round", -40.6, 16.9], ["grass_tuft", -22.6, 16.3], ["grass_tuft", -48.7, 16.0],
			["rocks_small", -54.5, 20.5], ["bush_snowy", -35.6, -3.6]]:
		_point(village, bush[0], Vector3(bush[1], 0, bush[2]), float(bush[1]))
	_point(village, "snowman", Vector3(-19.6, 0, 7.6), 0.4)
	_point(village, "sled", Vector3(-18.9, 0, 8.6), 1.1)


static func _house(village: VillageManager, item: String, pos: Vector3, angle: float, variant: int, family: String) -> void:
	var data := village.prepare(item, pos, angle, variant)
	data["home"] = family
	village.place(data)


static func _point(village: VillageManager, item: String, pos: Vector3, angle: float) -> void:
	village.place(village.prepare(item, pos, angle))


static func _line(village: VillageManager, item: String, a: Vector3, b: Vector3) -> void:
	village.place(village.prepare(item, a, 0.0, 0, b))
