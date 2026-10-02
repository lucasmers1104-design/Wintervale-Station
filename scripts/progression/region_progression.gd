## World-owned progression; uses the existing saveable protocol, railway and village.
class_name RegionProgression
extends Node

signal changed
signal epoch_unlocked(level: int)
const GROUP := &"region_progression"
const SAVE_ID := "progression"
var epoch := 1
var passengers := 0
var goods := 0
var services := 0
var unlocked: Array[String] = ["diesel_heritage", "special_winter", "special_autumn", "snowplough"]
var region: RegionRailway
var loading := false
var debug_used := false

static func find(tree: SceneTree) -> RegionProgression:
	return tree.get_first_node_in_group(GROUP) as RegionProgression

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GameDefs.GROUP_SAVEABLE)

func metrics() -> Dictionary:
	var result := {"passengers":passengers,"goods":goods,"services":services,"connected":0,"lines":0,"rail_length":0.0,"population":0}
	if region:
		for segment in region.network.get_segments():
			if not segment.tunnel:
				result["rail_length"] += segment.length
		var connected := {}
		for line in region.lines:
			if region.line_is_valid(line):
				result["lines"] += 1
				connected[int(line["a"])] = true
				connected[int(line["b"])] = true
		result["connected"] = connected.size()
		for station in region.stations:
			result["population"] += station.population
	return result

func requirements(level: int) -> Array[Dictionary]:
	var values := metrics()
	var rows: Array[Dictionary] = []
	var required: Dictionary = EpochCatalog.epoch(level)["requirements"]
	for key: String in required:
		rows.append({"key":key,"label":EpochCatalog.METRIC_LABELS.get(key,key),"value":values.get(key,0),"target":required[key],"met":float(values.get(key,0)) >= float(required[key])})
	return rows

func refresh() -> void:
	if loading:
		return
	while epoch < EpochCatalog.all().size():
		var ready := true
		for row in requirements(epoch + 1):
			ready = ready and row["met"]
		if not ready:
			break
		set_epoch(epoch + 1)
	changed.emit()

func set_epoch(level: int, debug := false) -> void:
	if debug and not OS.is_debug_build():
		return
	var old := epoch
	epoch = clampi(level,1,EpochCatalog.all().size())
	debug_used = debug_used or debug
	for definition in EpochCatalog.all():
		if int(definition["id"]) <= epoch:
			for id: String in definition["trains"]:
				if not unlocked.has(id):
					unlocked.append(id)
	for id in EpochCatalog.TRAIN_IDS:
		if EpochCatalog.train(id).required_epoch<=epoch and not unlocked.has(id):
			unlocked.append(id)
	if epoch > old and not loading:
		epoch_unlocked.emit(epoch)
		var data := EpochCatalog.epoch(epoch)
		Events.event_banner_requested.emit("Epoche %d · %s" % [epoch,data["name"]], "%s · %s" % [data["station"],EpochCatalog.train(data["trains"][0]).display_name], "train")
		Events.chronicle_entry.emit("Epoche %d: %s" % [epoch,data["name"]],"train")
	changed.emit()

func is_train_unlocked(id: String) -> bool:
	return unlocked.has(id)

func tool_unlocked(id: StringName) -> bool:
	if id == &"test":
		return OS.is_debug_build()
	return epoch >= int(EpochCatalog.TOOL_EPOCHS.get(String(id),1))

func debug_simulate(passenger_count: int, goods_count := 0) -> void:
	if not OS.is_debug_build():
		return
	debug_used = true
	passengers += maxi(0,passenger_count)
	goods += maxi(0,goods_count)
	refresh()

func get_save_id() -> String:
	return SAVE_ID

func save_state() -> Dictionary:
	return {"epoch":epoch,"passengers":passengers,"goods":goods,"services":services,"unlocked":unlocked.duplicate(),"debug_used":debug_used}

func load_state(data: Dictionary) -> void:
	loading = true
	epoch = clampi(int(data.get("epoch",1)),1,EpochCatalog.all().size())
	passengers = maxi(0,int(data.get("passengers",0)))
	goods = maxi(0,int(data.get("goods",0)))
	services = maxi(0,int(data.get("services",0)))
	debug_used = bool(data.get("debug_used",false))
	unlocked.assign(["diesel_heritage","special_winter","special_autumn","snowplough"])
	for id: Variant in data.get("unlocked",[]):
		if id is String and EpochCatalog.TRAIN_IDS.has(id) and not unlocked.has(id):
			unlocked.append(id)
	set_epoch(epoch)
	loading = false
