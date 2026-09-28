@tool
## Katalog aller Dorf-Objekte: Kategorie, Name, Art und Maße – und die Fabrik
## für ihre Meshes. Ein neues Objekt braucht nur einen Eintrag in [constant ITEMS]
## und (falls neu) eine Mesh-Funktion in [VillageMeshes].
##
## Arten ("kind"):
##   house  Wohnhaus (8 Formen aus [HouseMeshes]) – bekommt Bewohner
##   point  frei platzierbares Einzelobjekt (Baum, Laterne, Brunnen …)
##   line   zwischen zwei Punkten gezogen (Zaun, Hecke, Lichterkette)
##   path   Weg zwischen zwei Punkten, verbindet sich automatisch
##   plaza  Dorfplatz (fertig zusammengestellt)
class_name VillageCatalog
extends RefCounted

const CATEGORIES: Array[Dictionary] = [
	{"id": &"houses", "label": "Wohnhäuser"},
	{"id": &"paths", "label": "Wege"},
	{"id": &"nature", "label": "Natur"},
	{"id": &"lighting", "label": "Beleuchtung"},
	{"id": &"decor", "label": "Dekoration"},
]

## radius = Grundfläche (Kreis) für Kollision und Vorschau; sway = wiegt sich im Wind;
## light = {"energy", "range"} für warmes Licht bei Nacht; solid = blockiert andere Objekte.
const ITEMS := {
	"house_cottage": {"category": &"houses", "label": "Häuschen", "kind": "house", "house": "cottage"},
	"house_chalet": {"category": &"houses", "label": "Chalet", "kind": "house", "house": "chalet"},
	"house_townhouse": {"category": &"houses", "label": "Stadthaus", "kind": "house", "house": "townhouse"},
	"house_farmhouse": {"category": &"houses", "label": "Bauernhaus", "kind": "house", "house": "farmhouse"},
	"house_tower": {"category": &"houses", "label": "Turmhaus", "kind": "house", "house": "tower"},
	"house_aframe": {"category": &"houses", "label": "A-Frame", "kind": "house", "house": "aframe"},
	"house_barn": {"category": &"houses", "label": "Scheunenhaus", "kind": "house", "house": "barn"},
	"house_villa": {"category": &"houses", "label": "Gaubenhaus", "kind": "house", "house": "villa"},

	"path_gravel": {"category": &"paths", "label": "Kiesweg", "kind": "path", "max_length": 30.0},
	"path_stone": {"category": &"paths", "label": "Steinweg", "kind": "path", "max_length": 30.0},
	"path_road": {"category": &"paths", "label": "Kleine Straße", "kind": "path", "max_length": 40.0},

	"tree_pine_tall": {"category": &"nature", "label": "Hohe Fichte", "kind": "point", "radius": 1.4, "sway": true, "solid": true},
	"tree_fir_full": {"category": &"nature", "label": "Tanne", "kind": "point", "radius": 1.9, "sway": true, "solid": true},
	"tree_spruce_snowy": {"category": &"nature", "label": "Schneefichte", "kind": "point", "radius": 1.6, "sway": true, "solid": true},
	"tree_birch": {"category": &"nature", "label": "Birke", "kind": "point", "radius": 1.0, "sway": true, "solid": true},
	"tree_round": {"category": &"nature", "label": "Laubbaum", "kind": "point", "radius": 1.6, "sway": true, "solid": true},
	"tree_small": {"category": &"nature", "label": "Bäumchen", "kind": "point", "radius": 0.8, "sway": true, "solid": true},
	"bush_round": {"category": &"nature", "label": "Busch", "kind": "point", "radius": 0.9, "sway": true},
	"bush_holly": {"category": &"nature", "label": "Stechpalme", "kind": "point", "radius": 0.9, "sway": true},
	"bush_juniper": {"category": &"nature", "label": "Wacholder", "kind": "point", "radius": 0.7, "sway": true},
	"bush_snowy": {"category": &"nature", "label": "Schneebusch", "kind": "point", "radius": 0.8},
	"flower_bed": {"category": &"nature", "label": "Blumenbeet", "kind": "point", "radius": 1.1},
	"hedge": {"category": &"nature", "label": "Hecke", "kind": "line", "max_length": 16.0, "sway": true},
	"fence": {"category": &"nature", "label": "Zaun", "kind": "line", "max_length": 20.0},
	"rocks_small": {"category": &"nature", "label": "Felsen", "kind": "point", "radius": 0.8, "solid": true},
	"log_pile": {"category": &"nature", "label": "Baumstämme", "kind": "point", "radius": 1.0, "solid": true},
	"grass_tuft": {"category": &"nature", "label": "Grasbüschel", "kind": "point", "radius": 0.35},

	"lantern": {"category": &"lighting", "label": "Laterne", "kind": "point", "radius": 0.35, "solid": true,
		"light": {"energy": 1.6, "range": 8.0}},
	"garden_lamp": {"category": &"lighting", "label": "Gartenlampe", "kind": "point", "radius": 0.25,
		"light": {"energy": 0.6, "range": 3.5}},
	"street_lamp": {"category": &"lighting", "label": "Straßenlaterne", "kind": "point", "radius": 0.35, "solid": true,
		"light": {"energy": 2.0, "range": 10.0}},
	"string_lights": {"category": &"lighting", "label": "Lichterkette", "kind": "line", "max_length": 14.0,
		"light": {"energy": 0.45, "range": 4.0}},

	"plaza": {"category": &"decor", "label": "Dorfplatz", "kind": "plaza", "radius": 6.3, "solid": true,
		"light": {"energy": 2.0, "range": 10.0}},
	"bench": {"category": &"decor", "label": "Bank", "kind": "point", "radius": 0.9, "solid": true},
	"fountain": {"category": &"decor", "label": "Brunnen", "kind": "point", "radius": 1.7, "solid": true},
	"signpost": {"category": &"decor", "label": "Wegweiser", "kind": "point", "radius": 0.5, "solid": true},
	"bike_rack": {"category": &"decor", "label": "Fahrradständer", "kind": "point", "radius": 1.0, "solid": true},
	"mailbox": {"category": &"decor", "label": "Briefkasten", "kind": "point", "radius": 0.35, "solid": true},
	"planter": {"category": &"decor", "label": "Pflanzkübel", "kind": "point", "radius": 0.5, "solid": true},
	"snowman": {"category": &"decor", "label": "Schneemann", "kind": "point", "radius": 0.55, "solid": true},
	"sled": {"category": &"decor", "label": "Schlitten", "kind": "point", "radius": 0.6},
}

## Baukosten: Geld ("money") und Material (Schlüssel wie in assets/goods/).
## "per_m" = zusätzlich je Meter (Wege, Zäune, Hecken, Lichterketten).
## Häuser haben außerdem "hours" = Bauzeit in Arbeitsstunden (06–20 Uhr).
const COSTS := {
	"house_cottage": {"money": 350, "wood": 30, "brick": 12, "glass": 8, "hours": 5.0},
	"house_chalet": {"money": 450, "wood": 45, "brick": 6, "glass": 10, "steel": 2, "hours": 6.0},
	"house_townhouse": {"money": 600, "wood": 20, "brick": 36, "glass": 12, "steel": 4, "stone": 6, "hours": 7.0},
	"house_farmhouse": {"money": 650, "wood": 50, "brick": 18, "glass": 10, "stone": 12, "hours": 7.0},
	"house_tower": {"money": 700, "wood": 24, "brick": 24, "glass": 14, "steel": 6, "stone": 16, "hours": 8.0},
	"house_aframe": {"money": 380, "wood": 40, "glass": 12, "hours": 4.0},
	"house_barn": {"money": 520, "wood": 55, "brick": 12, "glass": 6, "steel": 4, "hours": 6.0},
	"house_villa": {"money": 800, "wood": 36, "brick": 30, "glass": 16, "steel": 4, "stone": 10, "hours": 8.0},
	"path_gravel": {"per_m": {"money": 3, "stone": 0.5}},
	"path_stone": {"per_m": {"money": 5, "stone": 1.0}},
	"path_road": {"per_m": {"money": 8, "stone": 1.5}},
	"tree_pine_tall": {"money": 30}, "tree_fir_full": {"money": 35}, "tree_spruce_snowy": {"money": 35},
	"tree_birch": {"money": 30}, "tree_round": {"money": 35}, "tree_small": {"money": 15},
	"bush_round": {"money": 12}, "bush_holly": {"money": 15}, "bush_juniper": {"money": 12}, "bush_snowy": {"money": 12},
	"flower_bed": {"money": 20, "wood": 2},
	"hedge": {"per_m": {"money": 5}},
	"fence": {"per_m": {"money": 3, "wood": 1.0}},
	"rocks_small": {"money": 10, "stone": 4},
	"log_pile": {"money": 5, "wood": 6},
	"grass_tuft": {"money": 3},
	"lantern": {"money": 30, "steel": 2},
	"garden_lamp": {"money": 20, "steel": 1},
	"street_lamp": {"money": 60, "steel": 3, "glass": 1},
	"string_lights": {"money": 20, "per_m": {"money": 2, "glass": 0.25}},
	"plaza": {"money": 500, "stone": 40, "wood": 10, "steel": 4},
	"bench": {"money": 30, "wood": 4, "steel": 1},
	"fountain": {"money": 120, "stone": 12, "steel": 1},
	"signpost": {"money": 15, "wood": 2},
	"bike_rack": {"money": 25, "steel": 2},
	"mailbox": {"money": 15, "steel": 1},
	"planter": {"money": 15, "stone": 2},
	"snowman": {},
	"sled": {"money": 10, "wood": 2},
}

const SWAY_MATERIAL := preload("res://assets/materials/foliage.tres")
const GLOW_MATERIAL := preload("res://assets/materials/village_glow.tres")
const WINDOW_MATERIAL := preload("res://assets/materials/house_window.tres")
const STRING_SHADER := preload("res://assets/materials/string_lights.gdshader")

static var _cache := {}


static func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func get_kind(item_id: String) -> String:
	return String(get_item(item_id).get("kind", "point"))


static func get_label(item_id: String) -> String:
	return String(get_item(item_id).get("label", item_id))


## Objekte einer Kategorie in Katalog-Reihenfolge.
static func get_items(category: StringName) -> Array[String]:
	var items: Array[String] = []
	for item_id: String in ITEMS:
		if ITEMS[item_id]["category"] == category:
			items.append(item_id)
	return items


## Baukosten eines Objekts ({"money": …, "<material>": …}); [param length] für Linien.
static func get_cost(item_id: String, length := 0.0) -> Dictionary:
	var entry: Dictionary = COSTS.get(item_id, {})
	var cost := {}
	for key: String in entry:
		if key != "per_m" and key != "hours":
			cost[key] = int(entry[key])
	var per_m: Dictionary = entry.get("per_m", {})
	for key: String in per_m:
		cost[key] = int(cost.get(key, 0)) + ceili(float(per_m[key]) * maxf(length, 0.0))
	for key: String in cost.keys():
		if int(cost[key]) <= 0:
			cost.erase(key)
	return cost


## Bauzeit eines Hauses in Arbeitsstunden (0 = sofort fertig).
static func get_build_hours(item_id: String) -> float:
	return float((COSTS.get(item_id, {}) as Dictionary).get("hours", 0.0))


static func is_line(item_id: String) -> bool:
	var kind := get_kind(item_id)
	return kind == "line" or kind == "path"


## Farbvarianten, die man mit "Farbe" durchschalten kann.
static func get_variant_count(item_id: String) -> int:
	return HouseMeshes.PALETTES.size() if get_kind(item_id) == "house" else 3


## Grundfläche: {"size": Vector2 (Rechteck, lokal) oder "radius": float}.
static func get_footprint(item_id: String, variant := 0, length := 0.0) -> Dictionary:
	var item := get_item(item_id)
	match String(item.get("kind", "point")):
		"house":
			var house := HouseMeshes.build(item["house"], variant)
			return {"size": house["size"], "center": house["center"]}
		"line":
			return {"size": Vector2(length, 0.9)}
		"path":
			return {"size": Vector2(length, PathMeshes.get_width(item_id))}
	return {"radius": float(item.get("radius", 0.6))}


## Meshes eines Objekts (lokal). [param length] nur für Linienobjekte (entlang +X).
## Rückgabe: {"body", "glow", "cable", "bulbs", "glass", "lights", "chimneys", "seats", "signs", "door", "height"}.
static func build_meshes(item_id: String, variant := 0, length := 0.0) -> Dictionary:
	var key := "%s|%d|%.2f" % [item_id, variant, length]
	if _cache.has(key):
		return _cache[key]
	var result := {"body": null, "glow": null, "cable": null, "bulbs": null, "glass": null, "lights": [],
		"chimneys": [], "seats": [], "signs": [], "door": Vector3.ZERO, "height": 2.0}
	var item := get_item(item_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item_id) + variant * 977
	var st := _new_st()
	var glow := _new_st()
	var has_glow := false
	match item_id:
		"tree_pine_tall":
			VillageMeshes.tree_pine_tall(st, rng)
		"tree_fir_full":
			VillageMeshes.tree_fir_full(st, rng)
		"tree_spruce_snowy":
			VillageMeshes.tree_spruce_snowy(st, rng)
		"tree_birch":
			VillageMeshes.tree_birch(st, rng)
		"tree_round":
			VillageMeshes.tree_round(st, rng)
		"tree_small":
			VillageMeshes.tree_small(st, rng)
		"bush_round":
			VillageMeshes.bush_round(st, rng)
		"bush_holly":
			VillageMeshes.bush_holly(st, rng)
		"bush_juniper":
			VillageMeshes.bush_juniper(st, rng)
		"bush_snowy":
			VillageMeshes.bush_snowy(st, rng)
		"flower_bed":
			VillageMeshes.flower_bed(st, rng)
		"rocks_small":
			VillageMeshes.rocks_small(st, rng)
		"log_pile":
			VillageMeshes.log_pile(st, rng)
		"grass_tuft":
			VillageMeshes.grass_tuft(st, rng)
		"fence":
			VillageMeshes.fence(st, maxf(length, 0.5), rng)
		"hedge":
			VillageMeshes.hedge(st, maxf(length, 0.5), rng)
		"lantern":
			result["lights"] = [_lantern(st, glow)]
			has_glow = true
		"garden_lamp":
			result["lights"] = [VillageMeshes.garden_lamp(st, glow)]
			has_glow = true
		"street_lamp":
			result["lights"] = [VillageMeshes.street_lamp(st, glow)]
			has_glow = true
		"string_lights":
			var cable := _new_st()
			var bulbs := _new_st()
			result["lights"] = VillageMeshes.string_lights(st, cable, bulbs, maxf(length, 1.0), rng)
			result["cable"] = cable.commit()
			result["bulbs"] = bulbs.commit()
		"bench":
			StationPropMeshes.add_bench(st, rng)
			result["seats"] = [Transform3D(Basis.IDENTITY, Vector3(-0.42, StationPropMeshes.BENCH_SEAT_HEIGHT, -0.02)),
				Transform3D(Basis.IDENTITY, Vector3(0.42, StationPropMeshes.BENCH_SEAT_HEIGHT, -0.02))]
		"fountain":
			VillageMeshes.fountain(st, rng)
		"signpost":
			result["signs"] = StationPropMeshes.add_signpost(st, [[0.0, 1.95, 0.9], [180.0, 1.63, 0.9]])
		"bike_rack":
			VillageMeshes.bike_rack(st, rng)
		"mailbox":
			VillageMeshes.mailbox(st)
		"planter":
			VillageMeshes.planter(st, rng)
		"snowman":
			VillageMeshes.snowman(st, rng)
		"sled":
			VillageMeshes.sled(st)
		"plaza":
			var data := VillageMeshes.plaza(st, glow, rng)
			result["lights"] = data["lights"]
			result["seats"] = data["seats"]
			result["signs"] = data["signs"]
			has_glow = true
		_:
			if String(item.get("kind", "")) == "house":
				var house := HouseMeshes.build(item["house"], variant)
				result["body"] = house["body"]
				result["glass"] = house["glass"]
				result["chimneys"] = house["chimneys"]
				result["lights"] = house["lights"]
				result["door"] = house["door"]
				result["height"] = house["height"]
				_cache[key] = result
				return result
	result["body"] = st.commit()
	if has_glow:
		result["glow"] = glow.commit()
	_cache[key] = result
	return result


static func clear_cache() -> void:
	_cache.clear()


## Material für den Körper: Pflanzen wiegen sich im Wind, alles andere Vertexfarben.
static func body_material(item_id: String, default_material: Material) -> Material:
	return SWAY_MATERIAL if bool(get_item(item_id).get("sway", false)) else default_material


static func string_material(emissive: bool) -> ShaderMaterial:
	var key := "string|%s" % emissive
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = STRING_SHADER
		material.set_shader_parameter(&"emissive", emissive)
		_cache[key] = material
	return _cache[key]


## Laterne im Stil der Bahnhofslaternen (schwarzer Mast, Glaskasten, Schneehaube).
static func _lantern(st: SurfaceTool, glow: SurfaceTool) -> Vector3:
	var iron := Color(0.14, 0.14, 0.16)
	LowPolyBuilder.add_cylinder(st, Vector3.ZERO, 0.17, 0.1, 0.35, 6, iron)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.35, 0), 0.06, 0.05, 2.3, 6, iron)
	LowPolyBuilder.add_box(st, Vector3(0, 2.66, 0), Vector3(0.36, 0.05, 0.36), iron)
	LowPolyBuilder.add_box(glow, Vector3(0, 2.86, 0), Vector3(0.28, 0.34, 0.28), VillageMeshes.GLASS_WARM)
	for x: float in [-0.15, 0.15]:
		for z: float in [-0.15, 0.15]:
			LowPolyBuilder.add_box(st, Vector3(x, 2.86, z), Vector3(0.03, 0.36, 0.03), iron)
	LowPolyBuilder.add_cone(st, Vector3(0, 3.03, 0), 0.27, 0.2, 4, iron, PI * 0.25)
	LowPolyBuilder.add_cone(st, Vector3(0, 3.1, 0), 0.2, 0.1, 4, VillageMeshes.SNOW, PI * 0.25, false)
	return Vector3(0, 2.86, 0)


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st
