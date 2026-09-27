@tool
## Ein Punkt im Tagesablauf eines Bewohners.
##
## - STATION_VISIT: von [member start] bis [member until] am Bahnhof verweilen
##   (sitzen, stehen, Uhr ansehen, spazieren), danach heimgehen.
## - TRAVEL: ab [member start] zum Bahnhof gehen und mit dem nächsten Zug nach
##   [member destination] fahren. Kommt bis [member until] keiner, geht der
##   Bewohner wieder heim. Zurück kommt er mit dem ersten Zug aus
##   [member destination], der nach [member return_after] in Wintervale hält.
class_name NpcRoutine
extends Resource

enum Activity { STATION_VISIT, TRAVEL }

@export var activity := Activity.STATION_VISIT
## Uhrzeit "HH:MM", zu der der Bewohner losgeht.
@export var start := "09:00"
## STATION_VISIT: Ende des Besuchs. TRAVEL: späteste Abfahrt, sonst geht er heim.
@export var until := "11:00"
## Nur TRAVEL: Zielort (Name eines Tunnelportals, z.B. "Südtal").
@export var destination := "Südtal"
## Nur TRAVEL: frühestens um diese Zeit geht es zurück.
@export var return_after := "17:00"


func get_start_hours() -> float:
	return TimetableEntry.parse_time(start)


func get_until_hours() -> float:
	return TimetableEntry.parse_time(until)


func get_return_hours() -> float:
	return TimetableEntry.parse_time(return_after)


## Gilt diese Routine zur Uhrzeit [param hours] noch (Losgehen bis Ende bzw. Rückkehr)?
func covers(hours: float) -> bool:
	var end := get_until_hours() if activity == Activity.STATION_VISIT else get_return_hours() + 4.0
	return hours >= get_start_hours() and hours < end


func describe() -> String:
	if activity == Activity.TRAVEL:
		return "%s fährt nach %s, zurück ab %s" % [start, destination, return_after]
	return "%s–%s am Bahnhof" % [start, until]
