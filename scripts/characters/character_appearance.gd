@tool
## Aussehen einer Figur (Spieler und später alle Dorfbewohner).
##
## Als .tres-Datei gespeichert lassen sich beliebig viele Varianten anlegen,
## z.B. assets/characters/player_appearance.tres. Das Modell baut
## [CharacterModel] daraus zusammen.
class_name CharacterAppearance
extends Resource

enum HatStyle { NONE, BEANIE }
enum HairStyle { NONE, SHORT, SIDES }

@export var skin_color := Color(0.93, 0.76, 0.64)

@export_group("Hemd (Karo)")
@export var shirt_color := Color(0.62, 0.12, 0.12)
@export var shirt_stripe_color := Color(0.08, 0.06, 0.07)
@export var shirt_line_color := Color(0.85, 0.75, 0.6)

@export_group("Hose & Schuhe")
@export var pants_color := Color(0.2, 0.22, 0.28)
@export var shoe_color := Color(0.25, 0.17, 0.12)

@export_group("Kopf")
@export var hat_style := HatStyle.BEANIE
@export var hat_color := Color(0.42, 0.28, 0.18)
@export var hair_style := HairStyle.NONE
@export var hair_color := Color(0.72, 0.70, 0.68)
@export var glasses := false
@export var glasses_color := Color(0.12, 0.12, 0.14)
