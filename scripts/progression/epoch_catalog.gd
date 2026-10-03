## Balancing lives in one editable data file; progress is measured from play.
class_name EpochCatalog
extends RefCounted

const REFERENCE_IDS := ["diesel_heritage", "nostalgic_regional", "reference_freight", "modern_local", "intercity", "high_speed"]
const TRAIN_IDS := ["diesel_heritage", "nostalgic_regional", "reference_freight", "modern_local", "intercity", "high_speed", "special_winter", "special_autumn", "snowplough", "regional_bahn", "regional_express", "freight", "freight_timber", "freight_building", "freight_bulk"]
const METRIC_LABELS := {"passengers":"Beförderte Fahrgäste", "goods":"Gelieferte Güter", "services":"Erfolgreiche Fahrten", "connected":"Verbundene Orte", "rail_length":"Streckenlänge (m)", "population":"Einwohner", "lines":"Funktionierende Linien"}
## Das Dorf baut der Spieler selbst: Häuser, Wege, Natur und Licht ab Start.
const TOOL_EPOCHS := {"rail":1,"station":1,"remove":1,"switch":2,"signal":2,"village_houses":1,"village_paths":1,"village_nature":1,"village_lighting":1,"village_decor":2,"test":0}
const DATA = preload("res://assets/progression/epochs.tres")

static func all() -> Array:
	return DATA.definitions

static func epoch(level: int) -> Dictionary:
	return all()[clampi(level, 1, all().size()) - 1]

static func train(id: String) -> TrainType:
	return load("res://assets/trains/%s.tres" % id) as TrainType if TRAIN_IDS.has(id) else null

static func consist_length(type: TrainType) -> float:
	var result := 0.0
	for kind in type.consist:
		result += float(TrainMeshes.get_spec(kind)["length"]) + TrainMeshes.COUPLING_GAP
	return result - TrainMeshes.COUPLING_GAP

## Ab welcher Epoche ein Dorf-Objekt gebaut werden darf. Einfache Häuser,
## Kieswege, Natur und Laternen gleich zum Start, Größeres mit der Zeit.
static func item_epoch(id: String) -> int:
	var category := String(VillageCatalog.get_item(id).get("category", ""))
	if id in ["path_road", "house_tower", "house_villa", "street_lamp"]:
		return 4
	if id in ["path_stone", "house_townhouse", "house_barn", "plaza", "fountain", "bike_rack"]:
		return 3
	if id in ["house_farmhouse", "string_lights"] or category == "decor":
		return 2
	return 1
