@tool
## Zuggattung: Aussehen, Wagenreihung und Fahrverhalten eines Zugs.
##
## Als .tres-Datei in assets/trains/ gespeichert – neue Züge entstehen, indem
## man eine Datei kopiert und Farben, Wagen oder Geschwindigkeit anpasst.
## Die Fahrzeugtypen in [member consist] stammen aus [TrainMeshes].
class_name TrainType
extends Resource

enum Category { PASSENGER, FREIGHT }

## Kürzel für Anzeigen, z.B. "RE", "RB", "GZ".
@export var type_code := "RE"
@export var display_name := "Regional-Express"
@export var category := Category.PASSENGER
## Wagenreihung von vorne nach hinten, z.B. ["railcar_front", "railcar_middle", "railcar_rear"].
## Verfügbar: railcar_front, railcar_middle, railcar_rear (moderner Triebzug), loco_regional, coach, loco_freight, wagon_timber, wagon_container, wagon_hopper,
## wagon_flat, wagon_stake (Güterwagen kommen beladen an, siehe TrainMeshes.CARGO)
@export var consist: PackedStringArray = PackedStringArray(["loco_regional", "coach", "coach"])

@export_group("Fahrverhalten")
## Höchstgeschwindigkeit in km/h (Spielmaßstab – gemütlich, nicht realistisch schnell).
@export var max_speed_kmh := 55.0
## Anfahrbeschleunigung in m/s².
@export var acceleration := 0.45
## Betriebsbremsung in m/s² (sanft; bei Bedarf wird etwas stärker gebremst).
@export var braking := 0.6
## So lange bleiben die Türen mindestens offen (Sekunden Spielzeit, egal wie spät).
@export var min_dwell_seconds := 8.0

@export_group("Lackierung")
## Untere Wagenkastenhälfte
@export var primary_color := Color(0.66, 0.13, 0.12)
## Fensterband und obere Hälfte
@export var secondary_color := Color(0.93, 0.89, 0.8)
## Türen, Zierstreifen, Warnfarbe an der Front
@export var accent_color := Color(0.95, 0.72, 0.22)
@export var roof_color := Color(0.42, 0.43, 0.45)

@export_group("Klang")
## Tonhöhe des Signalhorns (1 = normal, kleiner = tiefer).
@export var horn_pitch := 1.0


## Höchstgeschwindigkeit in m/s.
func get_max_speed() -> float:
	return max_speed_kmh / 3.6


func get_livery() -> Dictionary:
	return {"primary": primary_color, "secondary": secondary_color, "accent": accent_color, "roof": roof_color}
