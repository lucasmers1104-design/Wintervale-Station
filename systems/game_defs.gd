## Gemeinsame Konstanten und Aufzählungen, die mehrere Systeme nutzen.
##
## Bewusst ohne Logik: Diese Datei ist die zentrale Stelle für Werte, die
## sonst an mehreren Orten dupliziert würden.
class_name GameDefs
extends RefCounted

## Die zwei großen Spielansichten.
enum ViewMode {
	## Spielfigur: das Dorf zu Fuß erkunden (Third- oder First-Person).
	EXPLORE,
	## Vogelperspektive: Bauen & Management.
	BIRD_EYE,
}

## Gruppe aller Nodes, die vom SaveManager gespeichert werden.
## Mitglieder implementieren get_save_id(), save_state() und load_state().
const GROUP_SAVEABLE := &"saveable"

## Sonnenaufgang und -untergang in Spielstunden (kurze Wintertage).
const SUNRISE_HOUR := 7.0
const SUNSET_HOUR := 17.0
