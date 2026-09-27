@tool
## Eine Fahrplanzeile: ein Zug, der täglich zu einer festen Zeit fährt.
##
## Beispiel:  RE 201  Nordtal → Südtal  an 17:42  ab 17:48  Gleis 1
## Herkunft und Ziel sind die Namen von Tunnelportalen ([TrainPortal]).
class_name TimetableEntry
extends Resource

## Zugnummer, z.B. "RE 201".
@export var train_number := "RE 201"
## Anzeigename der Strecke, z.B. "Nordtal → Südtal".
@export var train_name := "Nordtal → Südtal"
@export var train_type: TrainType
## Portal, aus dem der Zug kommt.
@export var origin := "Nordtal"
## Portal, in dem der Zug verschwindet.
@export var destination := "Südtal"
## Bahnhof, an dem gehalten wird.
@export var station := "Wintervale"
## Geplantes Gleis (bei Belegung wählt der Fahrdienstleiter automatisch ein freies).
@export var platform := 1
## Ankunft und Abfahrt als "HH:MM".
@export var arrival := "17:42"
@export var departure := "17:48"
## false = Durchfahrt ohne Halt (z.B. Güterzüge).
@export var stops := true
## Höchstgeschwindigkeit in km/h (0 = Wert der Zuggattung).
@export var max_speed_kmh := 0.0


func get_arrival_hours() -> float:
	return parse_time(arrival)


func get_departure_hours() -> float:
	return parse_time(departure) if stops else parse_time(arrival)


func get_max_speed() -> float:
	if max_speed_kmh > 0.0:
		return max_speed_kmh / 3.6
	return train_type.get_max_speed() if train_type else 12.0


## "17:42" → 17.7
static func parse_time(text: String) -> float:
	var parts := text.strip_edges().split(":")
	if parts.size() != 2:
		return 0.0
	return clampf(parts[0].to_float() + parts[1].to_float() / 60.0, 0.0, 23.99)


## 17.7 → "17:42"
@warning_ignore("integer_division")
static func format_time(hours: float) -> String:
	var total := roundi(fposmod(hours, 24.0) * 60.0) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]
