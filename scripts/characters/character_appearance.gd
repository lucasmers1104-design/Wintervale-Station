@tool
## Aussehen einer Figur (Spieler und alle Dorfbewohner).
##
## Jede Figur der freigegebenen Charakterblätter (docs/character_references/) ist
## ein eigenes .tres unter assets/characters/designs/. [CharacterModel] baut daraus
## Kopf, Gesicht, Haare, Kopfbedeckung und Kleidung im einheitlichen Spielzeugstil.
class_name CharacterAppearance
extends Resource

enum HatStyle { NONE, BEANIE, POMPOM_BEANIE, FLAT_CAP, HEADSCARF, STRAW_HAT, CHEF_HAT, BUCKET_HAT, BERET,
	ELF_HAT, TRAPPER_HAT, EARMUFFS }
## Frisuren. SHORT…LONG stammen aus früheren Etappen; ab SPIKY die Formen der Charakterblätter.
enum HairStyle { NONE, SHORT, SIDES, BOB, BUN, PONYTAIL, CURLY, LONG,
	SPIKY, FRINGE, BALD_RING, CURLY_TOP, MESSY }
## Zusätzlich zur Frisur: Dutt, Zöpfe …
enum HairExtra { NONE, BUN_TOP, BUN_BACK, TWIN_BUNS, LOW_TAIL }
## Oberteil unter allem anderen.
enum TopStyle { PLAID_SHIRT, SWEATER, COAT, TURTLENECK, COLLAR_SHIRT, BLOUSE }
enum Sleeves { ROLLED, LONG, PUFF }
## Was über dem Oberteil getragen wird.
enum Outer { NONE, OVERALLS, SUSPENDERS, VEST, PUFFER_VEST, PUFFER_JACKET, CARDIGAN, WORK_APRON, PINAFORE,
	DRESS_APRON, TUNIC, LONG_COAT, DUFFLE_COAT, PARKA, KNIT_DRESS }
enum Bottom { SHORTS, TROUSERS, SKIRT, LONG_SKIRT, NONE }
enum Shoes { BOOTS, LACED_BOOTS, MARY_JANES, LOAFERS }
enum ScarfStyle { NONE, WRAP, NECKERCHIEF }
enum Pattern { SOLID, PLAID, GINGHAM, STRIPES, RIBS, FAIR_ISLE, DIAMONDS, QUILT, TARTAN }
## Kleidung passend zur Jahreszeit: Im Sommer entfallen Wintermützen, Schals und Fäustlinge.
enum Outfit { WINTER, SUMMER }

@export var skin_color := Color(0.93, 0.66, 0.48)

@export_group("Gesicht")
@export var freckles := false
@export var glasses := false
@export var glasses_color := Color(0.32, 0.18, 0.1)
@export var beard := false
@export var mustache := false
## Brauen (Alpha 0 = Haarfarbe, etwas dunkler).
@export var brow_color := Color(0, 0, 0, 0)
## Zusätzliche Dicke der Augenbrauen (0 = normal, 1 = buschig).
@export_range(0.0, 1.0, 0.05) var brow_thickness := 0.0

@export_group("Haare")
@export var hair_style := HairStyle.NONE
@export var hair_extra := HairExtra.NONE
@export var hair_color := Color(0.45, 0.25, 0.15)
## Schleife im Haar (Alpha 0 = keine).
@export var bow_color := Color(0, 0, 0, 0)

@export_group("Kopfbedeckung")
@export var hat_style := HatStyle.NONE
@export var hat_color := Color(0.42, 0.28, 0.18)
## Band, Umschlag oder Fell.
@export var hat_color2 := Color(0, 0, 0, 0)
## Bommel, Feder, Knopf.
@export var hat_color3 := Color(0, 0, 0, 0)
@export var hat_pattern := Pattern.SOLID

@export_group("Oberteil")
@export var top_style := TopStyle.TURTLENECK
@export var shirt_color := Color(0.93, 0.88, 0.78)
## Zweite Farbe des Musters (Streifen, Karo).
@export var shirt_stripe_color := Color(0.08, 0.06, 0.07)
## Dritte Farbe (feine Linien im Karo).
@export var shirt_line_color := Color(0.85, 0.75, 0.6)
@export var shirt_pattern := Pattern.SOLID
@export var sleeves := Sleeves.ROLLED
## Knöpfe und Schnallen.
@export var accent_color := Color(0.82, 0.6, 0.22)

@export_group("Darüber")
@export var outer := Outer.NONE
@export var outer_color := Color(0.4, 0.5, 0.25)
## Besatz, Fell, Schürzenstreifen, Muster.
@export var outer_color2 := Color(0, 0, 0, 0)
@export var outer_pattern := Pattern.SOLID

@export_group("Hose & Schuhe")
@export var bottom := Bottom.SHORTS
@export var pants_color := Color(0.4, 0.5, 0.25)
@export var bottom_color2 := Color(0, 0, 0, 0)
@export var bottom_pattern := Pattern.SOLID
## Strumpfhose (Alpha 0 = keine).
@export var tights_color := Color(0, 0, 0, 0)
## Socken/Stulpen über dem Schuh (Alpha 0 = keine).
@export var sock_color := Color(0, 0, 0, 0)
@export var shoes := Shoes.BOOTS
@export var shoe_color := Color(0.45, 0.26, 0.15)

@export_group("Winter")
@export var scarf_style := ScarfStyle.NONE
@export var scarf_color := Color(0.75, 0.2, 0.18)
@export var scarf_color2 := Color(0, 0, 0, 0)
@export var scarf_pattern := Pattern.SOLID
## Fäustlinge oder Arbeitshandschuhe (Alpha 0 = bloße Hände).
@export var mitten_color := Color(0, 0, 0, 0)
## Bündchen der Fäustlinge (Alpha 0 = keins).
@export var mitten_cuff_color := Color(0, 0, 0, 0)
## Arbeitshandschuhe aus Leder in mitten_color (auch im Sommer; Stulpe in mitten_cuff_color).
@export var gloves := false

@export_group("Taschen")
## Umhängetasche quer über die Brust.
@export var bag := false
@export var bag_color := Color(0.45, 0.27, 0.17)

@export_group("Statur")
## 1 = Erwachsene (ca. 1,45 m), 0,75 = Kind.
@export_range(0.6, 1.2, 0.01) var height_scale := 1.0
@export_range(0.8, 1.3, 0.01) var width_scale := 1.0
@export_range(0.8, 1.2, 0.01) var head_scale := 1.0

## Frühere Felder (Etappe 4–10) – werden noch gelesen, damit ältere Daten laden.
@export_group("Alt")
@export var scarf := false
@export var mittens := false


## Kennung für den Mesh-Zwischenspeicher: gleiche Werte → gleiche Meshes.
func get_signature() -> String:
	var parts := PackedStringArray()
	for property in get_property_list():
		if property["usage"] & PROPERTY_USAGE_STORAGE and property["name"] not in ["resource_name", "resource_path",
				"resource_local_to_scene", "script", "metadata/_custom_type_script"]:
			parts.append(str(get(property["name"])))
	return "|".join(parts)
