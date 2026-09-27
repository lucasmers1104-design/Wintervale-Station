@tool
## Aussehen einer Figur (Spieler und alle Dorfbewohner).
##
## Als .tres-Datei gespeichert lassen sich beliebig viele Varianten anlegen,
## z.B. assets/characters/player_appearance.tres. Das Modell baut
## [CharacterModel] daraus zusammen – alle Figuren teilen denselben Stil,
## unterscheiden sich aber in Farben, Oberteil, Frisur, Mütze und Statur.
class_name CharacterAppearance
extends Resource

enum HatStyle { NONE, BEANIE, POMPOM_BEANIE, FLAT_CAP }
enum HairStyle { NONE, SHORT, SIDES, BOB, BUN, PONYTAIL, CURLY }
## Oberteil: Karohemd (Markenzeichen), Strickpulli oder Mantel.
enum TopStyle { PLAID_SHIRT, SWEATER, COAT }
## Kleidung passend zur Jahreszeit (Grundlage – noch ohne Jahreszeiten-System).
## Im Sommer entfallen Mütze, Schal und Handschuhe, Pulli und Mantel werden zum T-Shirt.
enum Outfit { WINTER, SUMMER }

@export var skin_color := Color(0.93, 0.76, 0.64)

@export_group("Oberteil")
@export var top_style := TopStyle.PLAID_SHIRT
## Grundfarbe von Karohemd, Pulli oder Mantel.
@export var shirt_color := Color(0.62, 0.12, 0.12)
@export var shirt_stripe_color := Color(0.08, 0.06, 0.07)
@export var shirt_line_color := Color(0.85, 0.75, 0.6)
## Knöpfe, Bündchen und Kragen.
@export var accent_color := Color(0.86, 0.78, 0.64)

@export_group("Hose & Schuhe")
@export var pants_color := Color(0.2, 0.22, 0.28)
@export var shoe_color := Color(0.25, 0.17, 0.12)

@export_group("Kopf")
@export var hat_style := HatStyle.BEANIE
@export var hat_color := Color(0.42, 0.28, 0.18)
@export var hair_style := HairStyle.NONE
@export var hair_color := Color(0.72, 0.70, 0.68)
@export var beard := false
@export var glasses := false
@export var glasses_color := Color(0.12, 0.12, 0.14)

@export_group("Winter")
@export var scarf := true
@export var scarf_color := Color(0.82, 0.62, 0.30)
## Fäustlinge im Winter (sonst bloße Hände).
@export var mittens := true

@export_group("Statur")
## 1 = Erwachsene (ca. 1,45 m), 0,75 = Kind.
@export_range(0.6, 1.2, 0.01) var height_scale := 1.0
@export_range(0.8, 1.3, 0.01) var width_scale := 1.0
@export_range(0.8, 1.2, 0.01) var head_scale := 1.0
