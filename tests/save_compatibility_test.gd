extends Node
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("PASS " if ok else "FAIL ",label)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	WorldClock.paused = true
	var legacy: Node3D = load("res://scenes/main/main.tscn").instantiate()
	legacy.legacy_world = true
	get_tree().root.add_child(legacy)
	await frames(6)
	var rail_count: int = legacy.network.get_segment_count()
	var house_count: int = legacy.village.get_houses().size()
	check(rail_count>0 and house_count>0,"legacy fixture retains developed world")
	check(SaveManager.save_game("compat_legacy"),"archive legacy journey")
	var old_data := SaveManager.read_save_data("compat_legacy")
	old_data["version"] = 2
	var file := FileAccess.open(SaveManager.get_save_path("compat_legacy"),FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	legacy.queue_free()
	await frames(2)
	var fresh: Node3D = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(fresh)
	get_tree().current_scene = fresh
	await frames(6)
	check(fresh.region.stations.is_empty() and fresh.network.get_segment_count()==_tunnel_tracks(fresh),"fresh journey stays undeveloped (only the tunnel connection)")
	check(SaveManager.save_game("compat_fresh"),"archive new journey")
	check(SaveManager.load_game("compat_legacy"),"request version-two legacy load from new world")
	await frames(8)
	var restored := get_tree().current_scene
	check(restored.get("legacy_world")==true,"load rebuilds compatible legacy scene")
	check(restored.network.get_segment_count()==rail_count,"legacy rails are retained")
	check(restored.village.get_houses().size()==house_count,"legacy city is retained")
	check(restored.get_node("World/TestArea")!=null,"legacy station scenery is retained")
	check(RegionProgression.find(get_tree())==null,"legacy journey avoids artificial new progression")
	check(SaveManager.load_game("compat_fresh"),"request new journey from legacy world")
	await frames(8)
	var returned := get_tree().current_scene
	check(returned.get("legacy_world")==false and returned.get("region")!=null,"load restores progression scene generation")
	check(returned.network.get_segment_count()==_tunnel_tracks(returned) and returned.village.get_houses().is_empty(),"new save restores its empty world without inherited city")
	check(returned.progression.epoch==1,"new journey restores initial epoch")
	check(SaveManager.read_save_data("compat_legacy")["version"]==2,"reading legacy data leaves original archive untouched")
	SaveManager.delete_save("compat_legacy")
	SaveManager.delete_save("compat_fresh")
	print("SAVE COMPATIBILITY RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)


## Gleise des Tunnelanschlusses: gehören seit dem Tunnel-Umbau zur leeren Welt.
func _tunnel_tracks(world: Node) -> int:
	var count := 0
	for portal in (world.get("region") as RegionRailway).portals:
		count += portal.track_ids.size()
	return count
