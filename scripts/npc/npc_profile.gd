@tool
## Steckbrief eines Bewohners: Name, Aussehen, Zuhause, Tagesablauf, Vorlieben.
##
## Neue Bewohner entstehen allein durch eine neue .tres-Datei in assets/npcs/
## (siehe docs/NPCS.md) – der [NpcDirector] lädt alle Steckbriefe automatisch.
class_name NpcProfile
extends Resource

@export var display_name := "Greta Berger"
@export var appearance: CharacterAppearance
## Name des Wohnhauses ([member NpcHome.home_name]) – vorläufig ein Platzhalter.
@export var home_name := "Berger"
## Gehgeschwindigkeit in m/s (gemütlich: 0,9 – 1,4).
@export_range(0.6, 1.8, 0.05) var walk_speed := 1.1
## Tagesablauf, nach Uhrzeit sortiert.
@export var routines: Array[NpcRoutine] = []
## Gepäck, das der Bewohner dabeihat (Koffer, Rucksack, Einkaufstasche).
@export var carry := CharacterModel.Carry.NONE

@export_group("Vorlieben am Bahnsteig")
## Wie gern sitzt, steht, spaziert der Bewohner, schaut auf Uhr oder Tafel? (Gewichte)
@export_range(0.0, 1.0, 0.05) var likes_sitting := 0.5
@export_range(0.0, 1.0, 0.05) var likes_standing := 0.4
@export_range(0.0, 1.0, 0.05) var likes_strolling := 0.3
@export_range(0.0, 1.0, 0.05) var likes_clock := 0.3
@export_range(0.0, 1.0, 0.05) var likes_board := 0.2


## Routine, die zur Uhrzeit [param hours] gilt (oder null = zu Hause).
func get_routine_at(hours: float) -> NpcRoutine:
	for routine in routines:
		if routine and routine.covers(hours):
			return routine
	return null
