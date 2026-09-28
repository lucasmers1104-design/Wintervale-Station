## Erfindet Bewohner für neu gebaute Häuser.
##
## Alles hängt nur vom Startwert des Hauses ab – dieselbe Zahl ergibt immer
## dieselbe Familie. Deshalb müssen Bewohner nicht gespeichert werden: Das
## Haus merkt sich seinen Startwert, der Rest wird beim Laden neu abgeleitet.
##
## Tagesablauf (noch ohne Berufe):
## - Pendler (in jeder Familie mindestens einer): verlassen morgens das Haus, gehen zum Bahnhof, fahren mit
##   dem Zug nach Nordtal oder Südtal und kommen am Nachmittag/Abend zurück.
## - Daheimbleibende: gehen vormittags und/oder abends zum Bahnhof, sehen den
##   Zügen zu und spazieren wieder heim.
class_name VillageResidents
extends RefCounted

const FAMILIES: Array[String] = ["Lindner", "Fischer", "Brandt", "Vogel", "Engel", "Frost", "Kraus", "Adler",
	"Busch", "Roth", "Hartmann", "Keller", "Lange", "Seidel", "Weiß", "Albrecht", "Schöne", "Holm",
	"Birke", "Tanner", "Falk", "Morgen", "Stern", "Wendt"]
const FIRST_NAMES: Array[String] = ["Anna", "Paul", "Marie", "Felix", "Lina", "Oskar", "Frieda", "Theo", "Clara",
	"Anton", "Mia", "Karl", "Hanna", "Leo", "Rosa", "Johann", "Elsa", "Fritz", "Ella", "Moritz", "Martha", "Jakob",
	"Tilda", "Henri", "Luise", "Otto"]
const DESTINATIONS: Array[String] = ["Nordtal", "Südtal"]


## Familienname für ein neues Haus (nicht bereits vergeben).
static func family_name(seed_value: int, taken: Array) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt in FAMILIES.size() * 2:
		var candidate: String = FAMILIES[rng.randi() % FAMILIES.size()]
		if not taken.has(candidate):
			return candidate
	return "%s %d" % [FAMILIES[rng.randi() % FAMILIES.size()], seed_value % 100]


## Steckbriefe der [param count] Bewohner eines Hauses.
static func generate(home_name: String, seed_value: int, count: int) -> Array[NpcProfile]:
	var profiles: Array[NpcProfile] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var used_first: Array[String] = []
	for i in count:
		var profile := NpcProfile.new()
		var first: String = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
		while used_first.has(first):
			first = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
		used_first.append(first)
		profile.display_name = "%s %s" % [first, home_name]
		profile.home_name = home_name
		profile.appearance = NpcDirector.random_appearance(rng)
		if i == count - 1 and count >= 3:
			# Das Jüngste der Familie ist ein Kind
			profile.appearance.height_scale = 0.74
			profile.appearance.head_scale = 0.92
		profile.walk_speed = snappedf(rng.randf_range(0.95, 1.35), 0.05)
		profile.likes_sitting = rng.randf_range(0.2, 0.9)
		profile.likes_standing = rng.randf_range(0.2, 0.8)
		profile.likes_strolling = rng.randf_range(0.1, 0.7)
		profile.likes_clock = rng.randf_range(0.1, 0.5)
		profile.likes_board = rng.randf_range(0.1, 0.5)
		var roll := rng.randf()
		profile.carry = CharacterModel.Carry.BACKPACK if roll < 0.3 else (CharacterModel.Carry.SHOPPING_BAG if roll < 0.45
			else CharacterModel.Carry.NONE)
		# In jeder Familie pendelt mindestens die erste erwachsene Person
		var commuter := (i == 0 or rng.randf() < 0.5) and profile.appearance.height_scale > 0.8
		profile.routines = _commuter_day(rng) if commuter else _homebody_day(rng)
		profiles.append(profile)
	return profiles


static func _commuter_day(rng: RandomNumberGenerator) -> Array[NpcRoutine]:
	var trip := NpcRoutine.new()
	trip.activity = NpcRoutine.Activity.TRAVEL
	var leave := 6.6 + rng.randi_range(0, 12) * (1.0 / 6.0)  # 06:36–08:36
	trip.start = TimetableEntry.format_time(leave)
	# Genug Zeit für den Fußweg (~35 Spielminuten) und den nächsten Zug in die richtige Richtung
	trip.until = TimetableEntry.format_time(leave + 2.6)
	trip.destination = DESTINATIONS[rng.randi() % DESTINATIONS.size()]
	trip.return_after = TimetableEntry.format_time(15.0 + rng.randi_range(0, 7) * 0.5)
	var routines: Array[NpcRoutine] = [trip]
	if rng.randf() < 0.3:
		routines.append(_visit(20.0 + rng.randf_range(0.0, 0.5), 1.2))
	return routines


static func _homebody_day(rng: RandomNumberGenerator) -> Array[NpcRoutine]:
	var routines: Array[NpcRoutine] = []
	routines.append(_visit(9.5 + rng.randi_range(0, 6) * 0.25, rng.randf_range(1.0, 2.0)))
	if rng.randf() < 0.6:
		routines.append(_visit(15.5 + rng.randi_range(0, 6) * 0.25, rng.randf_range(0.8, 1.6)))
	return routines


static func _visit(start: float, hours: float) -> NpcRoutine:
	var routine := NpcRoutine.new()
	routine.activity = NpcRoutine.Activity.STATION_VISIT
	routine.start = TimetableEntry.format_time(start)
	routine.until = TimetableEntry.format_time(start + hours)
	return routine
