## Regie der Dorffeste (Etappe 10): Weihnachtsmarkt im Winter, Herbstfest im Herbst.
##
## - **Kalender:** Jedes Fest gehört zu einer Jahreszeit ([constant FESTIVALS]) und
##   steht einige Tage (Anteil der Jahreszeit "from"–"to"). Täglich öffnet es
##   von "open" bis "close".
## - **Aufbau:** rund um den Dorfplatz – Buden, Weihnachtsbaum bzw. Lagerfeuer,
##   Karussell bzw. Bühne, Stehtische, Heuballen, Eingangsbogen. Die Plätze werden
##   im Gelände gesucht: nie auf Häusern, Wegen, Gleisen oder Fußwegen.
## - **Leben:** Bewohner ohne andere Pläne gehen hin (abends lieber), kaufen an den
##   Buden (Glühwein und Most im Becher), stehen an Stehtischen, schauen dem
##   Karussell zu, wärmen sich am Feuer. Mit dem **Sonderzug** kommen Besucher
##   aus dem Tal und fahren abends wieder heim.
## - **Höhepunkte:** Lichterfest (Winter, 17 Uhr: alle versammeln sich, zählen
##   herunter, die Lichter laufen den Baum hinauf) und Laternenumzug (Herbst,
##   Dämmerung: die Kinder ziehen mit Laternen durchs Dorf). Beim Herbstfest wird
##   stündlich im Kreis getanzt.
##
## Schnittstelle für die Bewohner: [method claim_activity], [method on_customer],
## [method random_point], [method get_return_trip]. Tests: [member forced_festival].
class_name FestivalDirector
extends Node3D

signal festival_changed(festival_id: String)
signal opened_changed(open: bool)
signal highlight_started(festival_id: String)

const GROUP := &"festival_director"
const SAVE_ID := "festivals"
## Stationsname der Festplätze (StationSpot) – so bleiben sie von den Bahnsteigplätzen getrennt.
const SPOT_STATION := "Festplatz"
const CHRISTMAS := "christmas_market"
const HARVEST := "harvest_festival"
const TICK := 0.5
const PLAZA_RADIUS := 6.0
const DANCE_RADIUS := 2.75

const FESTIVALS := {
	CHRISTMAS: {
		"name": "Weihnachtsmarkt", "season": 3, "from": 0.08, "to": 0.94, "open": 15.0, "close": 22.0,
		"highlight": 17.0, "highlight_name": "Lichterfest", "icon": "tree",
		"stalls": ["gluehwein", "lebkuchen", "kerzen", "spielzeug", "maronen"],
		"train_type": "res://assets/trains/special_winter.tres",
		"trains": [
			{"number": "SZ 24", "name": "Weihnachtszug", "origin": "Nordtal", "destination": "Südtal",
				"arrival": "15:44", "departure": "15:52", "visitors": true},
			{"number": "SZ 25", "name": "Weihnachtszug", "origin": "Südtal", "destination": "Nordtal",
				"arrival": "21:30", "departure": "21:38", "return": true},
		],
	},
	HARVEST: {
		"name": "Herbstfest", "season": 2, "from": 0.18, "to": 0.88, "open": 10.5, "close": 20.5,
		"highlight": 18.5, "highlight_name": "Laternenumzug", "icon": "lantern",
		"stalls": ["apfelmost", "kuerbis", "zwiebelkuchen", "honig"],
		"train_type": "res://assets/trains/special_autumn.tres",
		"trains": [
			{"number": "EZ 31", "name": "Erntezug", "origin": "Nordtal", "destination": "Südtal",
				"arrival": "10:40", "departure": "10:48", "visitors": true},
			{"number": "EZ 32", "name": "Erntezug", "origin": "Südtal", "destination": "Nordtal",
				"arrival": "19:30", "departure": "19:38", "return": true},
		],
	},
}

@export var village: VillageManager
@export var terrain: LowPolyTerrain
@export var npc_director: NpcDirector
@export var dispatcher: TrainDispatcher
@export var walk_graph: WalkGraph
@export var network: RailNetwork
## Wilde Bäume unter Buden, Baum und Karussell werden gerodet (und wachsen danach wieder).
@export var nature: PropScatter
@export var body_material: Material = preload("res://assets/materials/nature_vertex_color.tres")
@export var enabled := true
## Für Tests und zum Ausprobieren: dieses Fest erzwingen ("" = nach Kalender, "none" = keins).
@export var forced_festival := ""

var _active := ""
var _open := false
var _dark := false
var _site: Node3D
var _center := Vector3(-27.0, 0.0, 4.0)
var _entrance := Vector3.FORWARD
var _stalls: Array[MarketStall] = []
var _tree: FestivalTree
var _carousel: FestivalCarousel
var _fires: Array[FestivalFire] = []
var _musician: CharacterModel
var _accordion: Node3D
var _stage_music: AudioStreamPlayer3D
var _murmur: AudioStreamPlayer3D
var _glow_stalls: ShaderMaterial
var _glow_decor: ShaderMaterial
var _spots := {"chat": [], "watch": [], "warm": [], "sit": []}
var _placed: Array[Array] = []
var _timer := 0.0
var _invite_timer := 0.0
var _guest_timer := 0.0
var _quiet := false
var _rng := RandomNumberGenerator.new()
var _visited: Dictionary = {}
var _special_entries: Array[TimetableEntry] = []
var _visitor_trains: Dictionary = {}
var _highlight_phase := ""
var _highlight_day := -1
var _procession_music: AudioStreamPlayer3D
var _dance: Array[Npc] = []
var _dance_angle := 0.0
var _dance_until := -1.0
var _dance_hour := -1
var _dance_wait := 0.0
var _stats := {"visitors": 0, "sold": 0, "lights": 0, "processions": 0}
var chronicle: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PropScatter.GROUP_CLEARING)
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_rng.randomize()
	_glow_stalls = ShaderMaterial.new()
	_glow_stalls.shader = preload("res://assets/materials/festival_lights.gdshader")
	_glow_decor = _glow_stalls.duplicate() as ShaderMaterial
	WorldClock.darkness_changed.connect(_on_darkness_changed)
	_dark = WorldClock.is_dark()
	Events.chronicle_entry.connect(add_chronicle)
	if not Engine.is_editor_hint():
		FestivalSounds.warm_up()


static func find(tree: SceneTree) -> FestivalDirector:
	return tree.get_first_node_in_group(GROUP) as FestivalDirector if tree else null


# --- Abfragen -------------------------------------------------------------------------------

## Welches Fest gerade steht ("" = keins).
func get_active_id() -> String:
	return _active


func is_active() -> bool:
	return _active != ""


func is_open() -> bool:
	return _open


func get_display_name(festival_id := "") -> String:
	var id := festival_id if festival_id != "" else _active
	return String(FESTIVALS[id]["name"]) if FESTIVALS.has(id) else ""


func get_open_hour() -> float:
	return float(FESTIVALS[_active]["open"]) if _active != "" else 0.0


func get_close_hour() -> float:
	return float(FESTIVALS[_active]["close"]) if _active != "" else 0.0


func get_highlight_hour() -> float:
	return float(FESTIVALS[_active]["highlight"]) if _active != "" else 0.0


func get_highlight_phase() -> String:
	return _highlight_phase


func get_center() -> Vector3:
	return _center


func get_stalls() -> Array[MarketStall]:
	return _stalls


func get_tree_feature() -> FestivalTree:
	return _tree


func get_carousel() -> FestivalCarousel:
	return _carousel


func get_fires() -> Array[FestivalFire]:
	return _fires


func get_special_entries() -> Array[TimetableEntry]:
	return _special_entries


func get_stats() -> Dictionary:
	return _stats


func get_spot_count(kind: String) -> int:
	return (_spots.get(kind, []) as Array).size()


func get_visitors_now() -> int:
	var count := 0
	if npc_director:
		for npc in npc_director.get_npcs() + npc_director.get_travellers():
			if is_instance_valid(npc) and npc.state == Npc.State.FESTIVAL:
				count += 1
	return count


## Kalender: {"id", "name", "days_until" (0 = jetzt), "open", "close", "highlight", "highlight_name"} je Fest.
func get_calendar() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var year := Seasons.year_length()
	var today := Seasons.year_day()
	for id: String in FESTIVALS:
		var info: Dictionary = FESTIVALS[id]
		var start := _season_start(int(info["season"])) + Seasons.LENGTHS[int(info["season"])] * float(info["from"])
		var end := _season_start(int(info["season"])) + Seasons.LENGTHS[int(info["season"])] * float(info["to"])
		var until := fposmod(start - today, year)
		var running := today >= start and today < end
		rows.append({"id": id, "name": info["name"], "days_until": 0.0 if running else until, "running": running,
			"open": info["open"], "close": info["close"], "highlight": info["highlight"],
			"highlight_name": info["highlight_name"], "icon": info["icon"], "days_left": end - today if running else 0.0})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["days_until"]) < float(b["days_until"]))
	return rows


# --- Takt ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not enabled:
		return
	_update_dance(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	tick()


## Ein Regie-Schritt (auch direkt aus Tests aufrufbar).
func tick() -> void:
	var wanted := _wanted_festival()
	if wanted != _active:
		_switch(wanted)
	if _active == "":
		return
	var now := WorldClock.time_of_day
	var info: Dictionary = FESTIVALS[_active]
	var open := now >= float(info["open"]) and now < float(info["close"])
	if open != _open:
		_set_open(open, true)
	_update_lights(now)
	_watch_trains()
	if WorldClock.paused:
		return
	_update_invitations(now)
	_ensure_crowd(now)
	_update_highlight(now)
	_start_dance_if_due(now)
	if _open and _rng.randf() < 0.25 and not _stalls.is_empty():
		_stalls[_rng.randi() % _stalls.size()].idle_gesture(_rng)


func _wanted_festival() -> String:
	if forced_festival == "none":
		return ""
	if forced_festival != "":
		return forced_festival
	var season := Seasons.get_season()
	var progress := Seasons.get_season_progress()
	for id: String in FESTIVALS:
		var info: Dictionary = FESTIVALS[id]
		if int(info["season"]) == season and progress >= float(info["from"]) and progress < float(info["to"]):
			return id
	return ""


func _switch(festival_id: String) -> void:
	_end_everything()
	_clear_site()
	_remove_special_trains()
	_active = festival_id
	_open = false
	# Jedes Fest hat seinen eigenen Höhepunkt (auch wenn am selben Tag gewechselt wird)
	_highlight_day = -1
	if festival_id == "":
		festival_changed.emit("")
		return
	_build_site(festival_id)
	_add_special_trains(festival_id)
	var info: Dictionary = FESTIVALS[festival_id]
	var now := WorldClock.time_of_day
	_set_open(now >= float(info["open"]) and now < float(info["close"]), false)
	festival_changed.emit(festival_id)
	if is_inside_tree() and not WorldClock.paused and not _quiet:
		Events.event_banner_requested.emit("%s im Dorf" % info["name"], "Täglich %s–%s Uhr am Dorfplatz · %s um %s" % [
			TimetableEntry.format_time(float(info["open"])), TimetableEntry.format_time(float(info["close"])),
			info["highlight_name"], TimetableEntry.format_time(float(info["highlight"]))], info["icon"])
		add_chronicle("%s aufgebaut – die Buden stehen am Dorfplatz." % info["name"], info["icon"])


func _set_open(open: bool, announce: bool) -> void:
	_open = open
	for stall in _stalls:
		stall.set_open(open, not announce)
	if _carousel:
		_carousel.set_running(open, not announce)
	for fire in _fires:
		fire.set_burning(open)
	if _musician:
		_musician.visible = open
		_musician.set_fade(1.0 if open else 0.0)
	if _stage_music:
		if open:
			SoundLibrary.play(_stage_music)
		else:
			_stage_music.stop()
	if _murmur:
		if open:
			SoundLibrary.play(_murmur)
		else:
			_murmur.stop()
	_glow_stalls.set_shader_parameter(&"lit", 1.0 if open else 0.0)
	opened_changed.emit(open)
	if not open:
		_end_everything()
	if announce and open and is_inside_tree():
		Events.notification_requested.emit("%s hat geöffnet" % get_display_name())


func _update_lights(now: float) -> void:
	var decor_lit := _open or _dark
	_glow_decor.set_shader_parameter(&"lit", 1.0 if decor_lit else 0.0)
	if _tree and _highlight_phase == "":
		# Der Baum leuchtet nach dem Lichterfest bis spät in die Nacht
		var should := now >= get_highlight_hour() or now < 1.0
		if should != _tree.is_lit():
			_tree.set_lit(should)


func _on_darkness_changed(dark: bool) -> void:
	_dark = dark
	for stall in _stalls:
		stall.set_dark(dark)
	if _carousel:
		_carousel.set_dark(dark)


# --- Aufbau -------------------------------------------------------------------------------------

func _build_site(festival_id: String) -> void:
	_site = Node3D.new()
	_site.name = "Site"
	add_child(_site)
	_rng.seed = hash(festival_id) + WorldClock.day
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = hash(festival_id) * 31
	var winter := festival_id == CHRISTMAS
	_center = _plaza_center()
	_center.y = _ground(_center)
	_entrance = _entrance_direction()
	_placed.clear()
	# Der Dorfplatz selbst ist belegt; der Eingang bleibt frei
	_placed.append([_center, PLAZA_RADIUS])
	_placed.append([_center + _entrance * 8.5, 1.6])
	var decor := TrainMeshes._new_st()
	var decor_glow := TrainMeshes._new_st()
	# Eingangsbogen zur Dorfstraße hin
	var arch_point := _center + _entrance * (PLAZA_RADIUS + 0.55)
	arch_point.y = _ground(arch_point)
	var arch_basis := Basis.looking_at(_entrance, Vector3.UP)
	var arch_st := TrainMeshes._new_st()
	var arch_glow := TrainMeshes._new_st()
	var sign_xform := FestivalMeshes.arch(arch_st, arch_glow, layout_rng, 3.4, winter)
	var arch_xform := Transform3D(arch_basis, arch_point)
	decor.append_from(arch_st.commit(), 0, arch_xform)
	decor_glow.append_from(arch_glow.commit(), 0, arch_xform)
	for face: float in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = get_display_name(festival_id)
		label.font_size = 64
		label.pixel_size = 0.0034
		label.modulate = Color(1.0, 0.9, 0.62) if winter else Color(1.0, 0.93, 0.78)
		label.outline_size = 0
		label.double_sided = false
		var local := sign_xform.translated(Vector3(0, 0, 0.04 * face))
		if face < 0.0:
			local.basis = local.basis.rotated(Vector3.UP, PI)
		label.transform = arch_xform * local
		_site.add_child(label)
	for side: float in [-1.0, 1.0]:
		_add_box_collision(arch_xform * Vector3(side * 1.7, 1.6, 0), Vector3(0.3, 3.2, 0.3), arch_basis)
	# Budengasse: links und rechts der Achse vom Platz zum Baum, die Fronten zur Gasse
	var stall_kinds: Array = FESTIVALS[festival_id]["stalls"]
	var lane := -_entrance
	var turns := [-0.42, 0.42, -0.26, 0.26, -0.62, 0.62, -0.85, 0.85]
	var placed_stalls := 0
	for turn: float in turns:
		if placed_stalls >= stall_kinds.size():
			break
		var p := _find_place(1.65, lane.rotated(Vector3.UP, turn), [8.8, 10.2, 11.6, 13.0, 14.4])
		if p == Vector3.INF:
			continue
		var kind: String = stall_kinds[placed_stalls]
		placed_stalls += 1
		var stall := MarketStall.new()
		stall.name = "Stall_%s" % kind
		_site.add_child(stall)
		# Front zur Gasse: zum nächsten Punkt auf der Achse, ein Stück Richtung Platz
		var on_axis := _center + lane * maxf(lane.dot(p - _center) - 2.0, 0.0)
		var look := Vector3(on_axis.x - p.x, 0.0, on_axis.z - p.z)
		if look.length() < 0.5:
			look = _center - p
		stall.global_transform = Transform3D(Basis.looking_at(look.normalized(), Vector3.UP), p)
		stall.build(kind, body_material, _glow_stalls, layout_rng, NpcDirector.random_appearance(layout_rng))
		stall.set_dark(_dark)
		_stalls.append(stall)
	# Großes Stück hinter dem Platz: Weihnachtsbaum bzw. Lagerfeuer
	# Am Ende der Budengasse (gegenüber dem Eingang) als Blickfang
	var big := _find_place(2.8, -_entrance, [14.0, 15.0, 13.0, 16.0, 12.0, 17.0, 11.0, 10.0, 9.0])
	if big == Vector3.INF:
		pass
	elif winter:
		_tree = FestivalTree.new()
		_tree.name = "ChristmasTree"
		_site.add_child(_tree)
		_tree.global_position = big
		_tree.build(body_material, _glow_decor, layout_rng)
		_ring_spots(big, 3.4, 6, "watch", {"look_up": true, "icons": ["tree", "star", "heart"]})
	else:
		var bonfire_st := TrainMeshes._new_st()
		var bonfire_glow := TrainMeshes._new_st()
		FestivalMeshes.bonfire(bonfire_st, bonfire_glow, layout_rng)
		decor.append_from(bonfire_st.commit(), 0, Transform3D(Basis.IDENTITY, big))
		decor_glow.append_from(bonfire_glow.commit(), 0, Transform3D(Basis.IDENTITY, big))
		_add_fire(big + Vector3(0, 0.1, 0), 1.0, 0.25)
		_add_cylinder_collision(big, 1.2, 0.6)
		_ring_spots(big, 1.75, 6, "warm", {"icons": ["heart", "leaf", "sun"]})
		# Sitzbalken rund ums Feuer
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			var c := big + Vector3(cos(a) * 2.4, 0.0, sin(a) * 2.4)
			var along := Vector3(-sin(a), 0, cos(a))
			for offset: float in [-0.4, 0.4]:
				_add_seat(c + along * offset + Vector3(0, 0.38, 0), big - c)
	# Zweites großes Stück: Karussell bzw. Bühne
	var second := _find_place(3.4, (-_entrance).rotated(Vector3.UP, 0.9), [12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 11.0, 10.0])
	if second == Vector3.INF:
		pass
	elif winter:
		_carousel = FestivalCarousel.new()
		_carousel.name = "Carousel"
		_site.add_child(_carousel)
		_carousel.global_position = second
		_carousel.build(body_material, _glow_decor, layout_rng)
		_ring_spots(second, _carousel.radius + 1.0, 8, "watch", {"icons": ["star", "heart", "note"]})
	else:
		# Vorderseite (-Z, Publikum) zum Platz, Rückwand nach außen
		var flat_to_center := Vector3(_center.x - second.x, 0.0, _center.z - second.z).normalized()
		var stage_basis := Basis.looking_at(flat_to_center, Vector3.UP)
		var stage_st := TrainMeshes._new_st()
		var stage_glow := TrainMeshes._new_st()
		var musician_at := FestivalMeshes.stage(stage_st, stage_glow, layout_rng)
		var stage_xform := Transform3D(stage_basis, second)
		decor.append_from(stage_st.commit(), 0, stage_xform)
		decor_glow.append_from(stage_glow.commit(), 0, stage_xform)
		_add_box_collision(second + Vector3(0, 0.25, 0), Vector3(3.6, 0.5, 2.4), stage_basis)
		_add_musician(stage_xform * musician_at, stage_basis)
		for k in 6:
			var local := Vector3(-1.8 + k * 0.72, 0.0, -2.6 - (k % 2) * 0.6)
			var p := stage_xform * local
			var spot := _make_spot(StationSpot.Kind.STAND, p, second - p)
			(_spots["watch"] as Array).append({"spot": spot, "icons": ["note", "heart", "star"]})
	# Stehtische und Feuerkorb auf dem Platz (zwischen Bänken und Rand)
	var slots: Array[Vector3] = []
	for k in 8:
		var angle := PI * 0.125 + k * PI * 0.25
		var dir := Vector3(cos(angle), 0, sin(angle))
		if dir.dot(_entrance) > 0.75:
			continue  # Eingang frei lassen
		slots.append(dir)
	slots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(_entrance) < b.dot(_entrance))
	var table_count := 4 if winter else 3
	for k in mini(slots.size(), table_count + 1):
		var p := _center + slots[k] * 4.85
		p.y = _ground(p)
		if k == 0 and winter:
			_add_fire_basket(p, layout_rng, decor, decor_glow)
			continue
		var table_st := TrainMeshes._new_st()
		var table_glow := TrainMeshes._new_st()
		FestivalMeshes.standing_table(table_st, table_glow, layout_rng, winter)
		decor.append_from(table_st.commit(), 0, Transform3D(Basis.IDENTITY, p))
		decor_glow.append_from(table_glow.commit(), 0, Transform3D(Basis.IDENTITY, p))
		_add_cylinder_collision(p, 0.5, 1.05)
		_table_spots(p, slots[k])
	if not winter:
		_harvest_decor(decor, decor_glow, layout_rng)
	var decor_mesh := MeshInstance3D.new()
	decor_mesh.name = "Decor"
	decor_mesh.mesh = decor.commit()
	decor_mesh.material_override = body_material
	_site.add_child(decor_mesh)
	var glow_mesh := MeshInstance3D.new()
	glow_mesh.name = "DecorLights"
	glow_mesh.mesh = decor_glow.commit()
	glow_mesh.material_override = _glow_decor
	glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_site.add_child(glow_mesh)
	# Gemurmel der Leute über dem Platz
	_murmur = AudioStreamPlayer3D.new()
	_murmur.stream = SoundLibrary.get_sound("station_murmur")
	_murmur.volume_db = -16.0
	_murmur.unit_size = 10.0
	_murmur.max_distance = 60.0
	_site.add_child(_murmur)
	_murmur.global_position = _center + Vector3(0, 1.5, 0)
	SoundLibrary.stop_on_exit(_murmur)
	# Sanft aufbauen: alles wächst kurz aus dem Boden
	_refresh_nature()
	if is_inside_tree() and not WorldClock.paused:
		_site.scale = Vector3(1, 0.01, 1)
		create_tween().tween_property(_site, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _harvest_decor(decor: SurfaceTool, decor_glow: SurfaceTool, rng: RandomNumberGenerator) -> void:
	# Heuballen als Sitzplätze nahe der Buden, Kürbisse daneben
	for k in 3:
		var p := _find_place(0.9, (-_entrance).rotated(Vector3.UP, 2.4 + k * 0.5), [7.4, 8.0, 8.8])
		if p == Vector3.INF:
			continue
		var basis := Basis.looking_at(_center - p, Vector3.UP)
		var bale := TrainMeshes._new_st()
		FestivalMeshes.hay_bale(bale, rng)
		decor.append_from(bale.commit(), 0, Transform3D(basis, p))
		for offset: float in [-0.28, 0.28]:
			_add_seat(p + basis.x * offset + Vector3(0, 0.46, 0), _center - p)
		var pumpkins := TrainMeshes._new_st()
		FestivalMeshes.pumpkin(pumpkins, rng, Vector3(0.85, 0, 0.1), rng.randf_range(0.16, 0.24))
		FestivalMeshes.pumpkin(pumpkins, rng, Vector3(-0.8, 0, 0.2), rng.randf_range(0.12, 0.18))
		decor.append_from(pumpkins.commit(), 0, Transform3D(basis, p))
	# Wimpelketten und Papierlaternen zwischen benachbarten Buden
	for i in _stalls.size() - 1:
		var a := _stalls[i].global_transform * Vector3(FestivalMeshes.STALL_WIDTH * 0.5, FestivalMeshes.EAVE_HEIGHT + 0.4, 0)
		var b := _stalls[i + 1].global_transform * Vector3(-FestivalMeshes.STALL_WIDTH * 0.5, FestivalMeshes.EAVE_HEIGHT + 0.4, 0)
		if a.distance_to(b) > 7.0:
			continue
		FestivalMeshes.bunting(decor, a, b, 0.35, rng)
		FestivalMeshes.paper_lanterns(decor_glow, decor, a - Vector3(0, 0.1, 0), b - Vector3(0, 0.1, 0), rng)


func _clear_site() -> void:
	_stalls.clear()
	_tree = null
	_carousel = null
	_fires.clear()
	_musician = null
	_accordion = null
	_stage_music = null
	_murmur = null
	_spots = {"chat": [], "watch": [], "warm": [], "sit": []}
	var had_site := _site != null
	_placed.clear()
	if _site:
		_site.queue_free()
		remove_child(_site)
		_site = null
	if had_site:
		_refresh_nature()


## Kein wilder Baum unter den Festbauten (PropScatter fragt alle "Rodungen").
func clears(x: float, z: float) -> bool:
	if _site == null:
		return false
	# Die Budengasse vom Platz bis zum Ende bleibt frei
	var lane_end := _center - _entrance * 15.0
	var on_lane := Geometry2D.get_closest_point_to_segment(Vector2(x, z), Vector2(_center.x, _center.z), Vector2(lane_end.x, lane_end.z))
	if on_lane.distance_to(Vector2(x, z)) < 4.5:
		return true
	for placed: Array in _placed:
		var p: Vector3 = placed[0]
		if Vector2(x - p.x, z - p.z).length() < float(placed[1]) * 0.9 + 0.4:
			return true
	return false


func _refresh_nature() -> void:
	if nature and is_inside_tree():
		nature.refresh_area(Rect2(_center.x - 22.0, _center.z - 22.0, 44.0, 44.0))


func _plaza_center() -> Vector3:
	if village:
		for obj in village.get_objects():
			if obj is VillageObject and (obj as VillageObject).item_id == "plaza":
				return obj.global_position
	return Vector3(-27.0, 0.0, 4.0)


## Richtung vom Platz zur nächsten Straße (dort steht der Eingangsbogen).
func _entrance_direction() -> Vector3:
	if village:
		var road := village.nearest_path_point(_center, 30.0)
		if road != Vector3.INF:
			var dir := Vector3(road.x - _center.x, 0.0, road.z - _center.z)
			if dir.length() > 0.5:
				return dir.normalized()
	return Vector3.BACK


## Freier Platz mit [param clearance] Abstand, möglichst in Richtung [param preferred].
func _find_place(clearance: float, preferred: Vector3, radii: Array) -> Vector3:
	var best := Vector3.INF
	var best_score := INF
	for radius: float in radii:
		for k in 48:
			var angle := TAU * k / 48.0
			var dir := Vector3(cos(angle), 0, sin(angle))
			var p := _center + dir * radius
			if not _is_free(p, clearance):
				continue
			var score := (1.0 - dir.dot(preferred.normalized())) * 4.0 + (radius - float(radii[0])) * 0.6
			if score < best_score:
				best_score = score
				best = p
		if best != Vector3.INF and best_score < 1.5:
			break
	if best == Vector3.INF:
		# Kein freier Platz: dieses Stück fällt dann eben weg (nie in Häuser oder auf Wege stellen)
		return Vector3.INF
	best.y = _ground(best)
	_placed.append([best, clearance])
	return best


func _is_free(p: Vector3, clearance: float) -> bool:
	for placed: Array in _placed:
		var other: Vector3 = placed[0]
		if Vector2(p.x - other.x, p.z - other.z).length() < clearance + float(placed[1]):
			return false
	if terrain:
		if terrain.is_in_lake(p.x, p.z) or maxf(absf(p.x), absf(p.z)) > terrain.get_half_extent() - 8.0:
			return false
		var low := INF
		var high := -INF
		for o: Vector3 in [Vector3.ZERO, Vector3(clearance, 0, 0), Vector3(-clearance, 0, 0), Vector3(0, 0, clearance),
				Vector3(0, 0, -clearance)]:
			var h := terrain.get_height(p.x + o.x, p.z + o.z)
			low = minf(low, h)
			high = maxf(high, h)
		if high - low > 0.8:
			return false
	if network and network.find_segment_near(p, clearance + 3.2):
		return false
	if walk_graph and walk_graph.distance_to_links(p) < clearance * 0.6:
		return false
	if village:
		var flat := Vector2(p.x, p.z)
		for obj in village.get_objects():
			if obj is VillagePath:
				if (obj as VillagePath).distance_to(p) < (obj as VillagePath).get_width() * 0.5 + clearance:
					return false
			elif obj is VillageObject and (obj as VillageObject).item_id == "plaza":
				continue
			else:
				# Linien (Zaun, Hecke, Lichterkette) sind schmal – dort reicht ein kleiner Abstand
				var margin := minf(clearance, 0.9) if VillageCatalog.is_line((obj as VillageObject).item_id if obj is VillageObject else "") \
					and (obj as VillageObject).item_id != "string_lights" \
					else clearance
				if VillageFootprint.contains(obj.get_footprint(), flat, margin):
					return false
	for node in get_tree().get_nodes_in_group(StationSpot.GROUP):
		var spot := node as StationSpot
		if spot.station_name != SPOT_STATION and spot.global_position.distance_to(p) < clearance + 0.5:
			return false
	return true


func _ground(p: Vector3) -> float:
	return terrain.get_surface_height(p.x, p.z) if terrain else p.y


# --- Plätze für die Besucher --------------------------------------------------------------

func _make_spot(kind: StationSpot.Kind, p: Vector3, facing: Vector3) -> StationSpot:
	var spot := StationSpot.new()
	spot.kind = kind
	spot.station_name = SPOT_STATION
	_site.add_child(spot)
	spot.global_position = Vector3(p.x, _ground(p) if kind != StationSpot.Kind.SEAT else p.y, p.z)
	var flat := Vector3(facing.x, 0, facing.z)
	if flat.length() > 0.01:
		spot.global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	return spot


func _ring_spots(center: Vector3, radius: float, count: int, kind: String, extra: Dictionary) -> void:
	for k in count:
		var angle := TAU * (k + 0.5) / count
		var p := center + Vector3(cos(angle), 0, sin(angle)) * radius
		if not _is_walkable_spot(p):
			continue
		var spot := _make_spot(StationSpot.Kind.STAND, p, center - p)
		var entry := extra.duplicate()
		entry["spot"] = spot
		(_spots[kind] as Array).append(entry)


## Plätze an einem Stehtisch: zwei Gesprächspaare einander gegenüber.
func _table_spots(p: Vector3, outward: Vector3) -> void:
	var side := outward.cross(Vector3.UP).normalized()
	for axis: Vector3 in [outward, side]:
		var a := _make_spot(StationSpot.Kind.CHAT, p + axis * 0.72, -axis)
		var b := _make_spot(StationSpot.Kind.CHAT, p - axis * 0.72, axis)
		a.partner = b
		b.partner = a
		(_spots["chat"] as Array).append({"spot": a})
		(_spots["chat"] as Array).append({"spot": b})


func _add_seat(p: Vector3, facing: Vector3) -> void:
	var spot := _make_spot(StationSpot.Kind.SEAT, p, facing)
	(_spots["sit"] as Array).append({"spot": spot, "icons": ["heart", "leaf", "note"]})


func _is_walkable_spot(p: Vector3) -> bool:
	if not _clear_of_features(p, 0.35):
		return false
	for placed: Array in _placed:
		var other: Vector3 = placed[0]
		var radius := float(placed[1])
		# Der Platz selbst ist begehbar (nur die großen Stücke nicht)
		if radius >= PLAZA_RADIUS - 0.1:
			continue
		if Vector2(p.x - other.x, p.z - other.z).length() < radius * 0.7:
			return false
	return true


## Was ein Besucher als Nächstes tut: {"kind", "spot", "facing", "duration", "icons", …} oder {}.
func claim_activity(npc: Npc, rng: RandomNumberGenerator) -> Dictionary:
	if _active == "":
		return {}
	var child := NpcDialogue.is_child(npc)
	var has_mug := npc.model and npc.model.carry == CharacterModel.Carry.MUG
	var weights := {
		"buy": (0.25 if has_mug else 1.1) * (0.6 if child else 1.0) * (1.0 if _open else 0.0),
		"table": 0.0 if child else 0.9,
		"watch": 2.2 if child else 0.7,
		"warm": 0.7,
		"sit": 0.5,
	}
	for attempt in 4:
		var kind := _weighted(weights, rng)
		if kind == "":
			return {}
		var result := _claim_kind(kind, npc, rng)
		if not result.is_empty():
			return result
		weights[kind] = 0.0
	return {}


func _claim_kind(kind: String, npc: Npc, rng: RandomNumberGenerator) -> Dictionary:
	if kind == "buy":
		var free: Array[MarketStall] = []
		for stall in _stalls:
			if stall.customer_spot.is_free():
				free.append(stall)
		if free.is_empty():
			return {}
		var stall := free[rng.randi() % free.size()]
		stall.customer_spot.reserve(npc)
		var icon := {"gluehwein": "cup", "apfelmost": "cup", "lebkuchen": "heart", "kerzen": "star", "spielzeug": "gift",
			"maronen": "heart", "kuerbis": "leaf", "zwiebelkuchen": "heart", "honig": "sun"}.get(stall.kind, "heart") as String
		return {"kind": "buy", "spot": stall.customer_spot, "stall": stall, "mug": stall.sells_drinks, "icon": icon,
			"duration": 3.0}
	var pool: Array = _spots.get(kind, [])
	var free_entries: Array = []
	for entry: Dictionary in pool:
		var spot: StationSpot = entry["spot"]
		if spot.is_free():
			free_entries.append(entry)
	if free_entries.is_empty():
		return {}
	# Gespräch: lieber gegenüber von jemandem, der schon dasteht
	if kind == "chat" or kind == "table":
		free_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _partner_waiting(a) and not _partner_waiting(b))
	var picked: Dictionary = free_entries[0] if kind == "table" and _partner_waiting(free_entries[0]) \
		else free_entries[rng.randi() % free_entries.size()]
	var result := picked.duplicate()
	(result["spot"] as StationSpot).reserve(npc)
	result["kind"] = kind
	result["duration"] = rng.randf_range(22.0, 48.0)
	if not result.has("icons"):
		result["icons"] = ["cup", "heart", "snowflake", "note"] if _active == CHRISTMAS else ["leaf", "heart", "note", "sun"]
	return result


func _partner_waiting(entry: Dictionary) -> bool:
	var spot: StationSpot = entry["spot"]
	return spot.partner != null and not spot.partner.is_free()


func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	if total <= 0.0:
		return ""
	var pick := rng.randf() * total
	for key: String in weights:
		pick -= float(weights[key])
		if pick <= 0.0:
			return key
	return ""


## Ein Kauf an der Bude: Verkäufer bedient, Becher klirren.
func on_customer(npc: Npc, activity: Dictionary) -> void:
	var stall: MarketStall = activity.get("stall")
	if stall == null:
		return
	stall.serve(npc)
	_stats["sold"] = int(_stats["sold"]) + 1
	if bool(activity.get("mug", false)):
		_play_at("clink", stall.global_position + Vector3(0, 1.2, 0), -10.0)


## Zufälliger Punkt auf dem Platz (zum Schlendern).
func random_point(rng: RandomNumberGenerator) -> Vector3:
	var angle := rng.randf() * TAU
	return _center + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(4.2, 5.6)


## Rückfahrt für Besucher: {"destination", "entry"} des Sonderzugs zurück (oder {}).
func get_return_trip() -> Dictionary:
	if dispatcher == null or dispatcher.timetable == null:
		return {}
	for entry in _special_entries:
		if not entry.has_meta(&"return"):
			continue
		var index := dispatcher.timetable.entries.find(entry)
		if index < 0:
			continue
		var until := fposmod(entry.get_departure_hours() - WorldClock.time_of_day, 24.0)
		if until < 12.0:
			return {"destination": entry.destination, "entry": index}
	return {}


# --- Bewohner einladen --------------------------------------------------------------------------

func _update_invitations(now: float) -> void:
	if npc_director == null or not _open:
		return
	_invite_timer -= TICK * WorldClock.time_scale
	if _invite_timer > 0.0:
		return
	_invite_timer = 30.0  # ≈ alle Viertelstunde Spielzeit
	var close := get_close_hour()
	var evening := smoothstep(15.0, 18.5, now)
	for npc in npc_director.get_npcs():
		if not is_instance_valid(npc) or npc.profile == null or npc.state != Npc.State.AT_HOME or npc.is_moving_in():
			continue
		if npc.has_plans(now, 1.2) or int(_visited.get(npc.name, -1)) == WorldClock.day:
			continue
		if _rng.randf() > 0.1 + evening * 0.3:
			continue
		_visited[npc.name] = WorldClock.day
		_stats["visitors"] = int(_stats["visitors"]) + 1
		npc.visit_festival(self, minf(close - 0.1, now + _rng.randf_range(0.8, 2.2)))


## Gäste aus der Umgebung kommen zu Fuß (manchmal Eltern mit Kind): tagsüber ein
## paar, abends mehr, zum Höhepunkt ein richtiges Gedränge.
func _ensure_crowd(now: float) -> void:
	if npc_director == null or not _open:
		return
	_guest_timer -= TICK
	if _guest_timer > 0.0:
		return
	var evening := smoothstep(15.0, 18.0, now)
	var target := 5 + int(round(evening * 5.0))
	if _highlight_phase in ["gathering", "running"]:
		target = 16
	if _festival_npcs().size() >= target or npc_director.get_travellers().size() >= 22:
		return
	# Im Zeitraffer kommen die Gäste entsprechend schneller
	_guest_timer = 1.4 / clampf(WorldClock.time_scale, 1.0, 20.0)
	var entries: Array[Vector3] = [npc_director.get_exit_point()]
	if walk_graph and walk_graph.has_point("Wegkreuz"):
		entries.append(walk_graph.get_point("Wegkreuz"))
	var start: Vector3 = entries[_rng.randi() % entries.size()] + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
	var until := minf(get_close_hour() - 0.1, now + _rng.randf_range(1.0, 2.6))
	if _highlight_phase != "":
		until = maxf(until, get_highlight_hour() + 0.8)
	var guest := npc_director.spawn_traveller(_rng)
	guest.set_meta(&"festival_guest", true)
	guest.model.carry = CharacterModel.Carry.NONE if _rng.randf() < 0.6 else CharacterModel.Carry.SHOPPING_BAG
	guest.appear_at(start)
	guest.visit_festival(self, until)
	_stats["visitors"] = int(_stats["visitors"]) + 1
	if _rng.randf() < 0.35 and npc_director.get_travellers().size() < 22:
		var child := npc_director.spawn_traveller(_rng)
		child.set_meta(&"festival_guest", true)
		var look := child.model.appearance.duplicate() as CharacterAppearance
		look.height_scale = _rng.randf_range(0.7, 0.78)
		look.width_scale = 0.95
		look.hat_style = CharacterAppearance.HatStyle.POMPOM_BEANIE
		child.model.appearance = look
		child.model.carry = CharacterModel.Carry.NONE
		child.appear_at(start + Vector3(0.6, 0, 0.3))
		child.visit_festival(self, until)


## Vor dem Höhepunkt kommt fast das ganze Dorf.
func _invite_for_highlight(until: float) -> void:
	if npc_director == null:
		return
	var now := WorldClock.time_of_day
	for npc in npc_director.get_npcs():
		if not is_instance_valid(npc) or npc.profile == null or npc.is_moving_in():
			continue
		if npc.state == Npc.State.FESTIVAL:
			npc.extend_festival(until)
			continue
		# Wer spazieren geht oder nur am Bahnhof steht, kommt auch dazu
		var idle := npc.state == Npc.State.STROLLING or (npc.state == Npc.State.AT_STATION and npc.get_routine() != null \
			and npc.get_routine().activity == NpcRoutine.Activity.STATION_VISIT)
		if idle and _rng.randf() < 0.85:
			npc.visit_festival(self, until)
			continue
		if npc.state != Npc.State.AT_HOME or npc.has_plans(now, 0.8) or _rng.randf() > 0.8:
			continue
		_visited[npc.name] = WorldClock.day
		npc.visit_festival(self, until)


# --- Sonderzüge ---------------------------------------------------------------------------------

func _add_special_trains(festival_id: String) -> void:
	if dispatcher == null or dispatcher.timetable == null:
		return
	var info: Dictionary = FESTIVALS[festival_id]
	var train_type: TrainType = load(String(info["train_type"]))
	for data: Dictionary in info["trains"]:
		var entry := TimetableEntry.new()
		entry.train_number = data["number"]
		entry.train_name = "%s · %s → %s" % [data["name"], data["origin"], data["destination"]]
		entry.train_type = train_type
		entry.origin = data["origin"]
		entry.destination = data["destination"]
		entry.station = npc_director.station_name if npc_director else "Wintervale"
		entry.platform = 1 if data["destination"] == "Südtal" else 2
		entry.arrival = data["arrival"]
		entry.departure = data["departure"]
		entry.set_meta(&"festival", festival_id)
		if data.get("visitors", false):
			entry.set_meta(&"visitors", true)
		if data.get("return", false):
			entry.set_meta(&"return", true)
		_special_entries.append(entry)
	dispatcher.add_entries(_special_entries)


func _exit_tree() -> void:
	# Der Fahrplan ist eine geteilte Ressource – Sonderzüge nicht darin zurücklassen
	_remove_special_trains()
	FestivalSounds.wait_for_warm_up()
	# Statische Zwischenspeicher leeren (Ressourcen sauber freigeben)
	FestivalSounds.clear_cache()
	SpeechBubble.clear_cache()
	MarketStall._puff_texture = null


func _remove_special_trains() -> void:
	if dispatcher and not _special_entries.is_empty():
		dispatcher.remove_entries(_special_entries)
	_special_entries.clear()
	_visitor_trains.clear()


## Hält der Sonderzug mit Besuchern: sie steigen aus und gehen aufs Fest.
func _watch_trains() -> void:
	if dispatcher == null or npc_director == null:
		return
	for train in dispatcher.get_trains():
		if train.state != Train.State.DWELLING or not train.doors_open() or _visitor_trains.has(train.train_id):
			continue
		if not train.entry.has_meta(&"festival"):
			continue
		_visitor_trains[train.train_id] = true
		var info: Dictionary = FESTIVALS.get(String(train.entry.get_meta(&"festival")), {})
		_play_at("sleigh_bells", train.get_focus_point() + Vector3(0, 2, 0), -6.0)
		if not train.entry.has_meta(&"visitors"):
			continue
		Events.event_banner_requested.emit("Der %s ist da!" % String(train.entry.train_name).split(" · ")[0],
			"Gäste aus dem Tal kommen zum %s" % info.get("name", "Fest"), "train")
		var rng := RandomNumberGenerator.new()
		rng.seed = train.train_id * 71 + WorldClock.day
		var count := rng.randi_range(6, 9)
		for i in count:
			var visitor := npc_director.spawn_traveller(rng)
			visitor.set_meta(&"festival_guest", true)
			visitor.festival_invite = self
			visitor.festival_invite_until = minf(get_close_hour() - 0.6, WorldClock.time_of_day + rng.randf_range(2.5, 5.0))
			visitor.alight_from(train, true)
		_stats["visitors"] = int(_stats["visitors"]) + count
		add_chronicle("%s brachte %d Gäste zum %s." % [train.entry.train_number, count, info.get("name", "Fest")], "train")


# --- Höhepunkte: Lichterfest und Laternenumzug ---------------------------------------------------------

func _update_highlight(now: float) -> void:
	var hour := get_highlight_hour()
	var until := _hours_between(now, hour)
	match _highlight_phase:
		"":
			if _highlight_day == WorldClock.day:
				return
			if until > 0.0 and until <= 0.45:
				_begin_gathering()
			elif until <= 0.0 and until > -0.1:
				_begin_gathering()
		"gathering":
			if until <= 0.0:
				_run_highlight()
		"done":
			if until < -0.5:
				_highlight_phase = ""
				for npc in _festival_npcs():
					npc.release_gathering()


## Alle versammeln sich (Baum bzw. Feuer), das Banner kündigt es an.
func _begin_gathering() -> void:
	_highlight_phase = "gathering"
	var hour := get_highlight_hour()
	_invite_for_highlight(hour + 1.0)
	if _active == CHRISTMAS:
		if _tree:
			_tree.set_lit(false)
		Events.event_banner_requested.emit("Gleich ist Lichterfest", "Alle treffen sich um %s am großen Weihnachtsbaum" % \
			TimetableEntry.format_time(hour), "tree")
	else:
		Events.event_banner_requested.emit("Gleich ist Laternenumzug", "Die Kinder holen ihre Laternen – Treffpunkt am Feuer", "lantern")
	_gather_all()


func _gather_all() -> void:
	var focus := _tree.global_position if _tree else (_fires[0].global_position if not _fires.is_empty() else _center)
	var npcs := _festival_npcs()
	var points := gathering_points(focus, npcs.size())
	for i in npcs.size():
		var npc := npcs[i]
		if npc.is_dancing():
			npc.stop_dance()
		var p: Vector3 = points[i % points.size()] if not points.is_empty() else focus + Vector3(3, 0, 3)
		npc.gather_at(p, focus - p)


## Freie Stehplätze vor [param focus] (Baum, Feuer) in Halbkreisen – nie in Buden,
## Karussell oder Bühne, am liebsten auf der Seite zum Platz hin.
func gathering_points(focus: Vector3, count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var toward := _center - focus
	toward.y = 0.0
	toward = toward.normalized()
	for ring in 6:
		var radius := 3.4 + ring * 0.85
		var steps := 7 + ring * 2
		for k in steps:
			var angle := (float(k) / (steps - 1) - 0.5) * PI * 1.1
			var dir := toward.rotated(Vector3.UP, angle)
			var p := focus + dir * radius
			if not _clear_of_features(p, 0.55):
				continue
			p.y = _ground(p)
			points.append(p)
			if points.size() >= count:
				return points
	return points


func _clear_of_features(p: Vector3, margin: float) -> bool:
	for stall in _stalls:
		var local := stall.global_transform.affine_inverse() * p
		if absf(local.x) < FestivalMeshes.STALL_WIDTH * 0.5 + margin and absf(local.z) < FestivalMeshes.STALL_DEPTH * 0.5 + margin:
			return false
	if _carousel and Vector2(p.x - _carousel.global_position.x, p.z - _carousel.global_position.z).length() < _carousel.radius + 0.6 + margin:
		return false
	if village:
		for obj in village.get_objects():
			if obj is VillageHouse and VillageFootprint.contains(obj.get_footprint(), Vector2(p.x, p.z), margin):
				return false
	return true


func _run_highlight() -> void:
	_highlight_phase = "running"
	_highlight_day = WorldClock.day
	highlight_started.emit(_active)
	# Wer noch unterwegs ist, stellt sich jetzt dazu
	_gather_all()
	if _active == CHRISTMAS:
		_lichterfest()
	else:
		_laternenumzug()


## Lichterfest: Ansprache, Countdown aus der Menge, Lichterwelle, Staunen, Applaus.
func _lichterfest() -> void:
	var crowd := _festival_npcs()
	var speaker := _pick_speaker(crowd)
	var steps: Array[Array] = []
	if speaker:
		steps.append([0.0, func() -> void: speaker.say("Liebe Wintervalerinnen und Wintervaler!", 3.4)])
		steps.append([3.4, func() -> void: speaker.say("Schön, dass ihr alle da seid. Zählt mit mir!", 3.0)])
	var t := 6.6 if speaker else 0.5
	for word: String in ["Drei …", "Zwei …", "Eins …!"]:
		var line := word
		steps.append([t, func() -> void:
			for npc in _festival_npcs():
				if npc.get_festival_behaviour() == "gather" and _rng.randf() < 0.55:
					npc.say(line, 1.1)])
		t += 1.25
	steps.append([t, func() -> void:
		if _tree:
			_tree.light_up(4.5)
		_play_at("sparkle", _tree.global_position + Vector3(0, 4, 0) if _tree else _center, -4.0)
		_play_at("crowd_aah", _center + Vector3(0, 1.6, 0), -5.0)])
	steps.append([t + 4.8, func() -> void:
		for npc in _festival_npcs():
			npc.ceremony_cheer(["heart", "star", "tree"][_rng.randi() % 3])
		_play_at("applause", _center + Vector3(0, 1.6, 0), -6.0)
		Events.event_banner_requested.emit("Der Baum leuchtet!", "Das Lichterfest hat begonnen – frohe Weihnachtszeit", "star")
		_stats["lights"] = int(_stats["lights"]) + 1
		add_chronicle("Lichterfest: %d Leute sahen den großen Baum aufleuchten." % _festival_npcs().size(), "tree")
		_highlight_phase = "done"])
	_run_steps(steps)


## Laternenumzug: die Kinder vorneweg, mit Laternen einmal die Dorfstraße entlang und zurück.
func _laternenumzug() -> void:
	var route := procession_route()
	var walkers := _festival_npcs()
	walkers.sort_custom(func(a: Npc, b: Npc) -> bool: return NpcDialogue.is_child(a) and not NpcDialogue.is_child(b))
	for i in walkers.size():
		walkers[i].join_procession(route, 0.6 + i * 1.5)
	if not walkers.is_empty():
		_procession_music = AudioStreamPlayer3D.new()
		_procession_music.stream = FestivalSounds.get_sound("laterne")
		_procession_music.volume_db = -9.0
		_procession_music.unit_size = 8.0
		_procession_music.max_distance = 55.0
		_procession_music.position = Vector3(0, 1.4, 0)
		walkers[0].add_child(_procession_music)
		SoundLibrary.stop_on_exit(_procession_music)
		SoundLibrary.play(_procession_music)
		var music := _procession_music
		get_tree().create_timer(120.0).timeout.connect(func() -> void:
			if is_instance_valid(music):
				music.queue_free())
	Events.event_banner_requested.emit("Laternenumzug", "Laterne, Laterne … die Kinder ziehen durchs Dorf", "lantern")
	_stats["processions"] = int(_stats["processions"]) + 1
	add_chronicle("Laternenumzug mit %d Laternen durchs Dorf." % walkers.size(), "lantern")
	_highlight_phase = "done"


## Strecke des Umzugs: vom Platz zur Dorfstraße, ein Stück in beide Richtungen, zurück zum Feuer.
func procession_route() -> PackedVector3Array:
	var route := PackedVector3Array()
	var start := _center + _entrance * (PLAZA_RADIUS + 1.5)
	var along := _entrance.cross(Vector3.UP).normalized()
	if village:
		for obj in village.get_objects():
			if obj is VillagePath and (obj as VillagePath).item_id == "path_road" and (obj as VillagePath).distance_to(start) < 4.0:
				var path := obj as VillagePath
				along = (path.end_point - path.start_point).normalized()
				along.y = 0.0
				along = along.normalized()
				break
	var road := village.nearest_path_point(start, 12.0) if village else start
	if road == Vector3.INF:
		road = start
	var stops: Array[Vector3] = [_center + _entrance * 3.0, road, road + along * 11.0, road - along * 13.0, road,
		_center + _entrance * 3.5]
	for i in stops.size():
		var point := stops[i]
		if village and i in [2, 3]:
			var snapped := village.nearest_path_point(point, 6.0)
			if snapped != Vector3.INF:
				point = snapped
		if route.is_empty():
			route.append(Vector3(point.x, 0.0, point.z))
			continue
		var leg := walk_graph.find_path(route[route.size() - 1], point) if walk_graph else PackedVector3Array([route[route.size() - 1], point])
		for j in range(1, leg.size()):
			route.append(Vector3(leg[j].x, 0.0, leg[j].z))
	return route


func _pick_speaker(crowd: Array[Npc]) -> Npc:
	var best: Npc = null
	for npc in crowd:
		if NpcDialogue.is_child(npc) or npc.profile == null:
			continue
		if npc.display_name == "Emil Hofer":
			return npc
		if best == null:
			best = npc
	return best


func _run_steps(steps: Array[Array]) -> void:
	for step: Array in steps:
		var callback: Callable = step[1]
		if float(step[0]) <= 0.0:
			callback.call()
		else:
			get_tree().create_timer(float(step[0])).timeout.connect(func() -> void:
				if is_instance_valid(self) and _active != "":
					callback.call())


# --- Reigen (Herbstfest) ------------------------------------------------------------------------

func _start_dance_if_due(now: float) -> void:
	if _active != HARVEST or not _open or _highlight_phase != "" or not _dance.is_empty():
		return
	var hour := int(now)
	var minute := (now - hour) * 60.0
	if minute < 15.0 or minute > 40.0 or hour == _dance_hour or absf(now - get_highlight_hour()) < 1.0:
		return
	if start_dance():
		_dance_hour = hour


## Den Reigen jetzt beginnen (bis zu 8 Besucher tanzen im Kreis um den Brunnen).
func start_dance() -> bool:
	var dancers: Array[Npc] = []
	for npc in _festival_npcs():
		if npc.get_festival_behaviour() in ["gather", "procession"]:
			continue
		dancers.append(npc)
		if dancers.size() >= 8:
			break
	if dancers.size() < 3:
		return false
	_dance = dancers
	_dance_angle = 0.0
	_dance_wait = 0.0
	_dance_until = WorldClock.time_of_day + 0.35
	for i in dancers.size():
		dancers[i].join_dance(_dance_point(i, dancers.size()))
	if is_inside_tree():
		Events.notification_requested.emit("Am Brunnen wird getanzt!")
	return true


func _dance_point(index: int, count: int) -> Vector3:
	var angle := _dance_angle + TAU * index / count
	var p := _center + Vector3(cos(angle), 0, sin(angle)) * DANCE_RADIUS
	p.y = npc_director.ground_height(p, _center.y + 0.3) if npc_director else _center.y + 0.06
	return p


func _update_dance(delta: float) -> void:
	if _dance.is_empty():
		return
	var all_ready := true
	for npc in _dance:
		if is_instance_valid(npc) and npc.get_festival_behaviour() == "dance_join":
			all_ready = false
	# Wer nach 12 Sekunden noch nicht im Kreis ist, bleibt draußen – der Tanz beginnt
	_dance_wait += delta
	if not all_ready and _dance_wait > 12.0:
		for npc in _dance.duplicate():
			if not is_instance_valid(npc) or npc.get_festival_behaviour() == "dance_join":
				if is_instance_valid(npc):
					npc.stop_dance()
				_dance.erase(npc)
		all_ready = true
	if all_ready:
		# Im Takt: schneller Schritt, kurzes Innehalten (Wiegeschritt)
		var beat := fposmod(Time.get_ticks_msec() * 0.001 * 1.9, 1.0)
		_dance_angle += delta * (0.55 + 0.35 * sin(beat * TAU)) * minf(WorldClock.time_scale, 3.0)
		for i in _dance.size():
			var npc := _dance[i]
			if not is_instance_valid(npc) or not npc.is_dancing():
				continue
			var p := _dance_point(i, _dance.size())
			var tangent := Vector3(-sin(_dance_angle + TAU * i / _dance.size()), 0, cos(_dance_angle + TAU * i / _dance.size()))
			npc.dance_to(p, tangent.rotated(Vector3.UP, 0.5 * sin(beat * TAU * 0.5)))
	if WorldClock.time_of_day >= _dance_until or not _open:
		stop_dance()


func stop_dance() -> void:
	for npc in _dance:
		if is_instance_valid(npc):
			npc.stop_dance()
	_dance.clear()


func get_dancers() -> Array[Npc]:
	return _dance


# --- Hilfen -------------------------------------------------------------------------------------

func _festival_npcs() -> Array[Npc]:
	var result: Array[Npc] = []
	if npc_director == null:
		return result
	for npc in npc_director.get_npcs() + npc_director.get_travellers():
		if is_instance_valid(npc) and npc.state == Npc.State.FESTIVAL:
			result.append(npc)
	return result


func _end_everything() -> void:
	stop_dance()
	if _highlight_phase != "":
		_highlight_phase = ""
		for npc in _festival_npcs():
			npc.release_gathering()


func _add_fire(p: Vector3, size: float, flame_height: float) -> void:
	var fire := FestivalFire.new()
	_site.add_child(fire)
	fire.global_position = p
	fire.build(size, flame_height)
	fire.set_burning(_open)
	_fires.append(fire)


## Feuerkorb (Weihnachtsmarkt): eiserner Korb mit Glut, Leute wärmen sich die Hände.
func _add_fire_basket(p: Vector3, rng: RandomNumberGenerator, decor: SurfaceTool, glow: SurfaceTool) -> void:
	var st := TrainMeshes._new_st()
	for k in 3:
		var a := TAU * k / 3.0
		LowPolyBuilder.add_beam(st, Vector3(cos(a) * 0.35, 0.0, sin(a) * 0.35), Vector3(cos(a) * 0.22, 0.75, sin(a) * 0.22), 0.05,
			FestivalMeshes.IRON)
	for k in 10:
		var a := TAU * k / 10.0
		LowPolyBuilder.add_beam(st, Vector3(cos(a) * 0.26, 0.72, sin(a) * 0.26), Vector3(cos(a) * 0.36, 1.12, sin(a) * 0.36), 0.03,
			FestivalMeshes.IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 0.7, 0), 0.26, 0.3, 0.05, 10, FestivalMeshes.IRON)
	LowPolyBuilder.add_cylinder(st, Vector3(0, 1.1, 0), 0.37, 0.37, 0.04, 12, FestivalMeshes.IRON)
	var glow_st := TrainMeshes._new_st()
	for k in 6:
		var a := rng.randf() * TAU
		FestivalMeshes._bulb(glow_st, Vector3(cos(a) * 0.12, 0.82, sin(a) * 0.12), 0.08, Color(1.0, 0.4, 0.1), rng.randf())
	decor.append_from(st.commit(), 0, Transform3D(Basis.IDENTITY, p))
	glow.append_from(glow_st.commit(), 0, Transform3D(Basis.IDENTITY, p))
	_add_fire(p + Vector3(0, 0.78, 0), 0.45, 0.05)
	_add_cylinder_collision(p, 0.4, 1.1)
	_ring_spots(p, 1.1, 4, "warm", {"icons": ["heart", "snowflake", "star"]})


## Musikant auf der Bühne mit Akkordeon (Balg zieht sich im Takt auf und zu).
func _add_musician(at: Vector3, basis: Basis) -> void:
	var look := CharacterAppearance.new()
	look.top_style = CharacterAppearance.TopStyle.PLAID_SHIRT
	look.shirt_color = Color(0.62, 0.22, 0.16)
	look.shirt_stripe_color = Color(0.2, 0.1, 0.08)
	look.hat_style = CharacterAppearance.HatStyle.FLAT_CAP
	look.beard = true
	look.hair_color = Color(0.72, 0.7, 0.73)
	_musician = CharacterModel.new()
	_musician.name = "Musician"
	_musician.appearance = look
	_musician.outfit = CharacterAppearance.Outfit.SUMMER
	_site.add_child(_musician)
	_musician.global_transform = Transform3D(basis, at)
	_musician.set_pose(CharacterModel.Pose.WARM_HANDS)
	# Akkordeon vor der Brust
	_accordion = Node3D.new()
	_accordion.position = Vector3(0, 0.62, -0.2)
	_musician.add_child(_accordion)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.14, 0.12)
	red.roughness = 0.35
	var bellows := StandardMaterial3D.new()
	bellows.albedo_color = Color(0.2, 0.18, 0.18)
	for side: float in [-1.0, 1.0]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.26, 0.16)
		box.mesh = mesh
		box.material_override = red
		box.position = Vector3(side * 0.13, 0, 0)
		box.set_meta(&"side", side)
		_accordion.add_child(box)
	var middle := MeshInstance3D.new()
	var middle_mesh := BoxMesh.new()
	middle_mesh.size = Vector3(0.18, 0.24, 0.14)
	middle.mesh = middle_mesh
	middle.material_override = bellows
	middle.name = "Bellows"
	_accordion.add_child(middle)
	_stage_music = AudioStreamPlayer3D.new()
	_stage_music.stream = FestivalSounds.get_sound("polka")
	_stage_music.volume_db = -10.0
	_stage_music.unit_size = 8.0
	_stage_music.max_distance = 60.0
	_site.add_child(_stage_music)
	_stage_music.global_position = at + Vector3(0, 1.2, 0)
	SoundLibrary.stop_on_exit(_stage_music)


func _physics_process(_delta: float) -> void:
	if _accordion and _open:
		var t := Time.get_ticks_msec() * 0.001
		var pull := 1.0 + 0.45 * sin(t * 3.9)
		var bellows := _accordion.get_node_or_null("Bellows") as Node3D
		if bellows:
			bellows.scale.x = pull
		for child in _accordion.get_children():
			if child.has_meta(&"side"):
				(child as Node3D).position.x = float(child.get_meta(&"side")) * (0.09 + 0.045 * pull)
		_musician.rotation.z = sin(t * 1.95) * 0.04
		if _rng.randf() < 0.004:
			_musician.play_gesture(CharacterModel.Pose.NOD, 1.2)


func _add_box_collision(center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_site.add_child(body)
	body.global_transform = Transform3D(basis, center)


func _add_cylinder_collision(base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	_site.add_child(body)
	body.global_position = base + Vector3(0, height * 0.5, 0)


## Einmaliger Klang an einer Stelle der Welt.
func _play_at(sound: String, where: Vector3, volume: float) -> void:
	if not is_inside_tree() or not SoundLibrary.audible:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = FestivalSounds.get_sound(sound)
	player.volume_db = volume
	player.unit_size = 10.0
	player.max_distance = 90.0
	add_child(player)
	player.global_position = where
	SoundLibrary.stop_on_exit(player)
	SoundLibrary.play(player)
	player.finished.connect(player.queue_free)


func _angle_to(direction: Vector3) -> float:
	return atan2(direction.z, direction.x)


func _season_start(season: int) -> float:
	var start := 0.0
	for i in season:
		start += Seasons.LENGTHS[i]
	return start


static func _hours_between(from: float, to: float) -> float:
	return fposmod(to - from + 12.0, 24.0) - 12.0


# --- Dorfchronik und Speichern ------------------------------------------------------------------

## Ein schöner Moment fürs Notizbuch (Seite "Feste").
func add_chronicle(text: String, icon: String) -> void:
	chronicle.push_front({"day": WorldClock.day, "time": TimetableEntry.format_time(WorldClock.time_of_day), "text": text,
		"icon": icon})
	if chronicle.size() > 30:
		chronicle.resize(30)


func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"chronicle": chronicle.duplicate(true), "stats": _stats.duplicate(), "highlight_day": _highlight_day,
		"visited": _visited.duplicate()}


func load_state(data: Dictionary) -> void:
	chronicle.clear()
	for entry in data.get("chronicle", []):
		if entry is Dictionary:
			chronicle.append(entry)
	var stats: Dictionary = data.get("stats", {})
	for key: String in _stats:
		_stats[key] = int(stats.get(key, _stats[key]))
	_visited = data.get("visited", {})
	_highlight_phase = ""
	if _active != "":
		_quiet = true
		_switch(_active)
		_quiet = false
	_highlight_day = int(data.get("highlight_day", -1))
