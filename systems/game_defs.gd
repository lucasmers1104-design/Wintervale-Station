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

## Physik-Ebenen als Bitmasken (siehe Projekteinstellungen → Layer Names).
const LAYER_WORLD := 1      ## Ebene 1: Terrain, Eis
const LAYER_PLAYER := 2     ## Ebene 2: Spielfigur
const LAYER_OBJECTS := 4    ## Ebene 3: Bäume, Steine, Laternen, Bahnsteige … (blockieren Gleisbau)
const LAYER_RAILS := 8      ## Ebene 4: Gleise
const LAYER_NATURE := 16    ## Ebene 5: Bäume, Steine (werden beim Gleisbau gerodet)
const LAYER_TRAINS := 32    ## Ebene 6: Züge (anklickbar, die Spielfigur prallt ab)
const LAYER_CHARACTERS := 64 ## Ebene 7: Bewohner (die Spielfigur weicht ihnen aus)

## Sonnenaufgang und -untergang in Spielstunden (kurze Wintertage).
const SUNRISE_HOUR := 7.0
const SUNSET_HOUR := 17.0
