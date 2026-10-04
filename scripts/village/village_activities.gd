## Optional, saved character activities. They never award money or building goods.
class_name VillageActivities
extends Node3D
const GROUP := &"village_activities"
const SAVE_ID := "village_activities"
const JOBS := {
	"cleanup":{"title":"Ein sauberer Bahnhof","text":"Sammle drei liegengebliebene Papierstücke am Bahnhof ein."},
	"mail":{"title":"Post aus Nordtal","text":"Hol die Post am Aushang ab und bring sie zu einer bewohnten Haustür."},
	"walk":{"title":"Wintervale entdecken","text":"Besuche drei kleine Aussichtspunkte rund um deinen Bahnhof."},
}
var region: RegionRailway
var active := {}
var completed := {"cleanup":0,"mail":0,"walk":0}
var last_done := {}
var history: Array[Dictionary] = []
var selected_station := 0
var _boards := {}
var _targets: Array[ActivityPoint] = []
var _tick := 0.0
var _status: Label
var _loaded_state := false

static func find(tree: SceneTree) -> VillageActivities:
	return tree.get_first_node_in_group(GROUP) as VillageActivities

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GameDefs.GROUP_SAVEABLE)
	region.village.changed.connect(_recheck_targets)
	Events.game_loaded.connect(func(_slot: String) -> void:
		if not _loaded_state:
			cancel_job()
			completed = {"cleanup":0,"mail":0,"walk":0}
			last_done.clear()
			history.clear()
		_restore_carry()
		_loaded_state = false)
	var canvas := CanvasLayer.new()
	canvas.layer = 6
	add_child(canvas)
	_status = Label.new()
	_status.position = Vector2(18,108)
	_status.add_theme_font_size_override("font_size",17)
	_status.add_theme_color_override("font_color",Color(1,0.93,0.75))
	_status.add_theme_color_override("font_outline_color",Color(0.13,0.17,0.18))
	_status.add_theme_constant_override("outline_size",5)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_status)

func _process(delta: float) -> void:
	_tick -= delta
	if _tick>0:
		return
	_tick = 0.5
	_sync_boards()
	if not active.is_empty():
		var station := region.station_by_id(int(active["station"]))
		var home: Node3D = region.village.get_object(int(active.get("home",0)))
		if station==null or (active["kind"]=="mail" and not home is VillageHouse):
			cancel_job()
			Events.notification_requested.emit("Bahnhofsrunde beendet · der Zielort wurde abgebaut.")
	_status.visible = not active.is_empty()
	if _status.visible:
		var player := _player()
		var distance := INF
		for target in _targets:
			if is_instance_valid(target) and not target.done and player:
				distance = minf(distance,RailGeometry.flat(target.global_position-player.global_position).length())
		_status.text = "%s · %s\nE: mitmachen · N: Dorfleben%s" % [JOBS[active["kind"]]["title"],progress_text()," · %.0f m zum nächsten Ziel" % distance if distance<INF else ""]

func _sync_boards() -> void:
	var live := {}
	for station in region.stations:
		live[station.station_id] = true
		var board: ActivityPoint = _boards.get(station.station_id)
		if not is_instance_valid(board):
			board = ActivityPoint.new()
			board.manager = self
			board.role = "board"
			board.station_id = station.station_id
			board.caption = "Dorfleben"
			add_child(board)
			_boards[station.station_id] = board
		var entrance: Vector3 = station.path_entrances()[0]
		var at := station.to_local(entrance)
		at.x = 19.1
		at.z += 3.5
		var point := station.to_global(at)
		point.y = region.terrain.get_height(point.x,point.z)
		if board.global_position.distance_to(point)>0.1:
			board.global_position = point
			region.village.nature.refresh_area(Rect2(Vector2(point.x,point.z)-Vector2.ONE,Vector2.ONE*2))
	for id in _boards.keys():
		if not live.has(id):
			var old: ActivityPoint = _boards[id]
			var at := old.global_position
			remove_child(old)
			old.queue_free()
			_boards.erase(id)
			region.village.nature.refresh_area(Rect2(Vector2(at.x,at.z)-Vector2.ONE,Vector2.ONE*2))

func can_start(kind: String, station: RegionStation) -> String:
	if not JOBS.has(kind) or station==null:
		return "Baue zuerst einen Bahnhof."
	if not active.is_empty():
		return "Schließe deine aktuelle Runde ab oder lege sie zurück."
	if int(last_done.get("%d_%s" % [station.station_id,kind],0))==WorldClock.day:
		return "Für heute erledigt · morgen gibt es eine neue Runde."
	if kind=="mail" and _homes(station.station_id).is_empty():
		return "Die erste Familie muss angekommen sein."
	return ""

func start_job(kind: String, station_id: int) -> bool:
	_sync_boards()
	var station := region.station_by_id(station_id)
	if can_start(kind,station)!="":
		return false
	var points: Array = []
	var home_id := 0
	var entrance: Vector3 = station.path_entrances()[0]
	if kind=="mail":
		var homes := _homes(station_id)
		var home: VillageHouse = homes[(int(completed["mail"])+WorldClock.day-1)%homes.size()]
		home_id = home.object_id
		points = [SaveUtils.vec3_to_array((_boards[station_id] as ActivityPoint).global_position+station.global_basis.x*1.2),SaveUtils.vec3_to_array(home.get_front_point())]
	else:
		var offsets: Array = [Vector3(2,0,-4),Vector3(5,0,3),Vector3(8,0,-1)] if kind=="cleanup" else [Vector3(12,0,-14),Vector3(24,0,0),Vector3(12,0,15)]
		for offset: Vector3 in offsets:
			var point := _free_point(entrance+station.global_basis*offset,entrance)
			if point==Vector3.INF:
				Events.notification_requested.emit("Hier fehlt noch Platz für diese Runde.")
				return false
			points.append(SaveUtils.vec3_to_array(point))
	active = {"kind":kind,"station":station_id,"home":home_id,"points":points,"done":[]}
	for i in points.size():
		active["done"].append(false)
	_spawn_targets()
	Events.notification_requested.emit("%s · Tab zur Spielfigur, E an den markierten Orten." % JOBS[kind]["title"])
	return true

func _homes(station_id: int) -> Array:
	return region.village.get_houses().filter(func(home: VillageHouse) -> bool: return home.region_station_id==station_id and home.is_finished() and home.finished_day>0 and not region.station_by_id(station_id).waiting_houses.has(home.object_id))

## Building during a round must not bury its remaining items inside a house.
func _recheck_targets() -> void:
	if active.is_empty() or active["kind"]=="mail":
		return
	var station := region.station_by_id(int(active["station"]))
	if station==null:
		return
	var entrance: Vector3 = station.path_entrances()[0]
	var moved := false
	for i in active["points"].size():
		if bool(active["done"][i]):
			continue
		var old := SaveUtils.array_to_vec3(active["points"][i])
		var free := _free_point(old,entrance)
		if free==Vector3.INF:
			cancel_job()
			Events.notification_requested.emit("Hier fehlt jetzt Platz für die Runde · sie kann später neu angenommen werden.")
			return
		if free.distance_to(old)>0.1:
			active["points"][i] = SaveUtils.vec3_to_array(free)
			moved = true
	if moved:
		_spawn_targets()

func _free_point(wanted: Vector3, entrance: Vector3) -> Vector3:
	for i in 20:
		var p := wanted+Vector3(cos(i*2.4),0,sin(i*2.4))*float(i)*0.45
		var object: Node3D = region.village.pick(p)
		if object!=null and not object is VillagePath:
			continue
		if not region.village.is_walkable(entrance,p):
			continue
		p.y = region.terrain.get_height(p.x,p.z)
		return p
	return Vector3.INF

func _spawn_targets() -> void:
	_clear_targets()
	if active.is_empty():
		return
	for i in active["points"].size():
		if bool(active["done"][i]):
			continue
		var point := ActivityPoint.new()
		point.manager = self
		point.role = String(active["kind"])
		point.index = i
		point.caption = "Post abholen" if point.role=="mail" and i==0 else ("Post zustellen" if point.role=="mail" else ("Papier einsammeln" if point.role=="cleanup" else "Aussicht entdecken"))
		point.position = SaveUtils.array_to_vec3(active["points"][i])
		add_child(point)
		_targets.append(point)
		region.village.nature.refresh_area(Rect2(Vector2(point.position.x,point.position.z)-Vector2.ONE,Vector2.ONE*2))

func act(index: int, player: PlayerController) -> bool:
	if active.is_empty() or index<0 or index>=active["done"].size() or bool(active["done"][index]):
		return false
	var target := SaveUtils.array_to_vec3(active["points"][index])
	if player==null or RailGeometry.flat(player.global_position-target).length()>PlayerInteraction.REACH or absf(player.global_position.y-target.y)>1.6:
		return false
	var kind: String = active["kind"]
	if kind=="mail":
		if index==0:
			if player.get_model().carry!=CharacterModel.Carry.NONE:
				return false
			player.get_model().carry = CharacterModel.Carry.SHOPPING_BAG
		elif not bool(active["done"][0]):
			return false
		else:
			player.get_model().carry = CharacterModel.Carry.NONE
	player.get_model().play_gesture(CharacterModel.Pose.LOOK_UP if kind=="walk" else CharacterModel.Pose.NOD,1.0)
	active["done"][index] = true
	for point in _targets:
		if point.index==index:
			point.done = true
			point.remove_from_group(PlayerInteraction.GROUP)
			point.hide()
	if not active["done"].has(false):
		_finish_job()
	else:
		Events.notification_requested.emit("%s · %s" % [JOBS[kind]["title"],progress_text()])
	return true

func _finish_job() -> void:
	var kind: String = active["kind"]
	completed[kind] = int(completed[kind])+1
	last_done["%d_%s" % [int(active["station"]),kind]] = WorldClock.day
	var station := region.station_by_id(int(active["station"]))
	var entry := {"day":WorldClock.day,"title":JOBS[kind]["title"],"station":station.station_name if station else "Wintervale"}
	history.push_front(entry)
	history.resize(mini(history.size(),20))
	Events.chronicle_entry.emit("%s · %s" % [entry["title"],entry["station"]],"heart")
	Events.notification_requested.emit("Runde geschafft! · %s · Fortschritt im Notizbuch." % rank_title())
	active = {}
	_clear_targets()

func cancel_job() -> void:
	if not active.is_empty() and active["kind"]=="mail" and bool(active["done"][0]):
		var player := _player()
		if player:
			player.get_model().carry = CharacterModel.Carry.NONE
	active = {}
	_clear_targets()

func _clear_targets() -> void:
	for point in _targets:
		if is_instance_valid(point):
			var at := point.global_position
			remove_child(point)
			point.queue_free()
			region.village.nature.refresh_area(Rect2(Vector2(at.x,at.z)-Vector2.ONE,Vector2.ONE*2))
	_targets.clear()

func progress_text() -> String:
	if active.is_empty():
		return "Keine Runde angenommen"
	if active["kind"]=="mail":
		return "Post zur Haustür bringen" if bool(active["done"][0]) else "Post am Aushang abholen"
	return "%d / %d Orte" % [active["done"].count(true),active["done"].size()]

func rank_title() -> String:
	var count := 0
	for value in completed.values():
		count += int(value)
	return "Wintervales gute Seele" if count>=12 else ("Vertrautes Gesicht" if count>=5 else ("Helfende Hand" if count>0 else "Neu im Dorf"))

func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController

func _restore_carry() -> void:
	var player := _player()
	if player and not active.is_empty() and active["kind"]=="mail" and bool(active["done"][0]):
		player.get_model().carry = CharacterModel.Carry.SHOPPING_BAG

func get_save_id() -> String:
	return SAVE_ID

func save_state() -> Dictionary:
	return {"active":active.duplicate(true),"completed":completed.duplicate(),"last_done":last_done.duplicate(),"history":history.duplicate(true)}

func load_state(data: Dictionary) -> void:
	_loaded_state = true
	cancel_job()
	for kind: String in JOBS:
		completed[kind] = maxi(0,int(data.get("completed",{}).get(kind,0)))
	last_done = data.get("last_done",{}).duplicate()
	history.assign(data.get("history",[]))
	history.resize(mini(history.size(),20))
	var saved: Dictionary = data.get("active",{})
	if JOBS.has(saved.get("kind","")) and region.station_by_id(int(saved.get("station",0))) and saved.get("points",[]).size()==saved.get("done",[]).size() and saved.get("points",[]).size() in [2,3]:
		active = saved.duplicate(true)
	_sync_boards()
	_spawn_targets()

class ActivityPoint extends Node3D:
	var manager: VillageActivities
	var role := "board"
	var caption := ""
	var station_id := 0
	var index := -1
	var done := false
	func _ready() -> void:
		add_to_group(PlayerInteraction.GROUP)
		add_to_group(PropScatter.GROUP_CLEARING)
		var mesh := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if role=="board":
			LowPolyBuilder.add_box(st,Vector3(0,0.65,0),Vector3(0.1,1.3,0.1),Color(0.4,0.25,0.14))
			LowPolyBuilder.add_box(st,Vector3(0,1.25,0),Vector3(0.95,0.7,0.12),Color(0.48,0.3,0.16))
			LowPolyBuilder.add_box(st,Vector3(0,1.25,0.07),Vector3(0.8,0.55,0.015),Color(0.94,0.85,0.62))
		elif role=="cleanup":
			for k in 3:
				LowPolyBuilder.add_oriented_box(st,Transform3D(Basis(Vector3.UP,k*0.9),Vector3(k*0.13-0.13,0.07+k*0.006,0)),Vector3(0.2,0.012,0.27),Color(0.84,0.77,0.59))
		elif role=="mail":
			LowPolyBuilder.add_box(st,Vector3(0,0.18,0),Vector3(0.36,0.32,0.25),Color(0.6,0.4,0.22))
			LowPolyBuilder.add_box(st,Vector3(0,0.35,0),Vector3(0.32,0.015,0.22),Color(0.95,0.89,0.68))
		else:
			LowPolyBuilder.add_box(st,Vector3(0,0.45,0),Vector3(0.07,0.9,0.07),Color(0.4,0.27,0.16))
			LowPolyBuilder.add_box(st,Vector3(0,0.88,0),Vector3(0.52,0.27,0.07),Color(0.45,0.58,0.4))
		mesh.mesh = st.commit()
		mesh.material_override = preload("res://assets/materials/nature_vertex_color.tres")
		add_child(mesh)
		var label := Label3D.new()
		label.text = caption
		label.font_size = 30
		label.pixel_size = 0.001
		label.fixed_size = true
		label.position.y = 1.9 if role=="board" else 1.3
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1,0.89,0.56)
		label.visibility_range_end = 38
		add_child(label)
	func clears(x: float,z: float) -> bool:
		return Vector2(x-global_position.x,z-global_position.z).length()<0.7
	func get_interaction_point() -> Vector3:
		return global_position
	func get_interaction_text(player: Node) -> String:
		if done or manager.active.is_empty() and role!="board":
			return ""
		if role=="board":
			return "Aushang lesen · Dorfleben"
		if role=="mail" and index==1 and not bool(manager.active["done"][0]):
			return "Erst die Post am Aushang abholen"
		if role=="mail" and index==0 and (player as PlayerController).get_model().carry!=CharacterModel.Carry.NONE:
			return "Hände zuerst freimachen"
		return caption
	func interact(player: Node) -> void:
		if role=="board":
			manager.selected_station = station_id
			Events.notebook_requested.emit("activities")
		else:
			manager.act(index,player as PlayerController)
