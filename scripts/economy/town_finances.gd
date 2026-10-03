## Gemeindekasse: Einnahmen aus dem Dorfleben (Ausgaben entstehen beim
## Materialeinkauf im Güterbahnhof und beim Bauen).
##
## - Fahrkarten: Wer in Wintervale in einen Zug steigt, zahlt [member ticket_price].
## - Gemeindeabgaben: Jeden Abend um [member tax_hour] Uhr zahlt jeder Einwohner
##   [member tax_per_resident] – mehr Häuser, mehr Einwohner, mehr Einnahmen.
## - Trassengebühr und Leergut-Pfand bucht der [FreightYard] selbst.
class_name TownFinances
extends Node

@export var npc_director: NpcDirector
@export var ticket_price := 4
@export var tax_per_resident := 14
@export var tax_hour := 18


func _ready() -> void:
	if npc_director:
		npc_director.passenger_boarded.connect(_on_passenger_boarded)
	WorldClock.hour_changed.connect(_on_hour_changed)


func _on_passenger_boarded(_npc: Npc, _train: Train) -> void:
	Economy.earn(ticket_price, "Fahrkarten Wintervale", "tickets")


func _on_hour_changed(hour: int) -> void:
	if hour != tax_hour or npc_director == null:
		return
	var residents := _population()
	if residents > 0:
		Economy.earn(residents * tax_per_resident, "Gemeindeabgaben (%d Einwohner)" % residents, "taxes")


## Voraussichtliche Einnahmen pro Tag aus Abgaben (für das Notizbuch).
func get_daily_taxes() -> int:
	return _population() * tax_per_resident

func _population() -> int:
	var progress := RegionProgression.find(get_tree())
	return int(progress.metrics()["population"]) if progress else (npc_director.get_npcs().size() if npc_director else 0)
