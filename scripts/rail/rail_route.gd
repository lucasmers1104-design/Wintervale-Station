## Ein Fahrweg (Fahrstraße) von einem Signal bis zum nächsten Signal oder Gleisende.
##
## Ein Fahrweg reserviert ganze Gleisabschnitte (Blöcke). Ein Block kann nie
## von zwei Fahrwegen gleichzeitig reserviert sein – so kann ein grünes Signal
## nie einen Konflikt mit einem anderen Fahrweg erlauben.
class_name RailRoute
extends RefCounted

var signal_id: int
## Befahrene Gleisstücke in Fahrtreihenfolge.
var segments: Array[int] = []
## Reservierte Gleisabschnitte.
var blocks: Array[int] = []
## Benötigte Weichenstellungen: Knoten-ID → Stellung.
var switch_positions: Dictionary[int, int] = {}
## Block-Zuordnung beim Reservieren (erkennt spätere Umbauten).
var segment_blocks: Dictionary[int, int] = {}
## Wurde der Fahrweg schon befahren (Belegung erkannt)?
var entered := false
## Von einem Zug angefordert (statt automatisch vom Signal gebildet).
var requested := false
## Zug, dem der Fahrweg gehört (-1 = keinem bestimmten). Ein Fahrweg wird nie
## an einen anderen Zug weitergereicht.
var owner_id := -1
## Blöcke, die der Zug schon befahren hat – werden nach dem Räumen einzeln
## freigegeben (Teilauflösung), damit nachfolgende Züge früher fahren können.
var seen_blocks: Dictionary[int, bool] = {}
## Grund, falls der Fahrweg nicht gebildet werden konnte ("" = gültig).
var error := ""
