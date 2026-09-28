@tool
## Ein Baumaterial (Holz, Ziegel, Glas …) – als .tres-Datei in assets/goods/.
##
## Neue Materialien entstehen allein durch eine neue Datei in diesem Ordner
## (plus Icon in assets/ui/icons/): [code]Economy[/code] lädt alle Dateien
## automatisch, Lager-Seite im Notizbuch und Güterbahnhof zeigen sie an.
## Damit Güterzüge ein neues Material bringen, braucht es noch einen Wagen,
## der es geladen hat ([code]TrainMeshes.CARGO[/code]).
class_name GoodsType
extends Resource

## Kurzer, stabiler Schlüssel (Spielstände, Baukosten), z.B. "wood".
@export var id := "wood"
@export var display_name := "Holz"
@export var icon: Texture2D
## Woher das Material kommt (Text fürs Notizbuch).
@export var origin := "Sägewerk Nordtal"
## Aus diesem Tunnelportal kommen die Güterzüge mit diesem Material.
@export var origin_portal := "Nordtal"
## So viel passt ins Lager.
@export var max_stock := 100
## Bestand bei einem neuen Spiel.
@export var start_stock := 20
## Einkaufspreis je Einheit in Talern (wird beim Entladen bezahlt).
@export var unit_price := 2
## Farbe für Balken und Beschriftung im Notizbuch.
@export var color := Color(0.7, 0.5, 0.3)
## Reihenfolge in Listen (kleiner = weiter oben).
@export var sort_order := 0
@export_multiline var description := ""
