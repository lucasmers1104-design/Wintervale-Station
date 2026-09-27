@tool
## Der Fahrplan: eine Liste von [TimetableEntry], die jeden Tag gilt.
## Gespeichert als assets/timetables/*.tres – im Godot-Inspector bearbeitbar.
class_name Timetable
extends Resource

@export var entries: Array[TimetableEntry] = []


## Alle Halte an einem Bahnhof, nach Abfahrtszeit sortiert.
func get_departures(station: String) -> Array[TimetableEntry]:
	var list: Array[TimetableEntry] = []
	for entry in entries:
		if entry and entry.station == station and entry.stops:
			list.append(entry)
	list.sort_custom(func(a: TimetableEntry, b: TimetableEntry) -> bool: return a.get_departure_hours() < b.get_departure_hours())
	return list
