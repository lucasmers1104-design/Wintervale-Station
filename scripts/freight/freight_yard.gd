## Der Güterbahnhof: Lager, Portalkran und Ladearbeiten an Gleis 3.
##
## Ablauf, wenn ein Güterzug hält:
## 1. Der Zug wird festgehalten ([method Train.hold_departure]), die Trassengebühr gutgeschrieben.
## 2. Für jedes geladene Stück wird geprüft: Ist das Material bestellt, ist Platz
##    im Lager, reicht das Geld? Dann plant der Kran einen Entladeauftrag.
## 3. Der Kran fährt hin, senkt die Traverse (bzw. den Greifer beim Schüttgut),
##    hebt das Stück vom Wagen, fährt es zum Lagerplatz und setzt es ab. Erst dort
##    kommt es ins Lager ([code]Economy.add_stock[/code]) – bezahlt wird beim Anheben.
## 4. Danach wird Leergut (leere Paletten, leere Container) zurückgeladen – es
##    bringt ein kleines Pfand.
## 5. Der Kran fährt in die Parkstellung, der Zug darf abfahren.
##
## Lagerbestände sind sichtbar: Jeder Lagerplatz zeigt dieselben Stücke wie auf
## den Wagen (Stammbündel, Ziegelpaletten, Container, Stahlbündel), die
## Steinboxen füllen sich mit Haufen. Wird Material verbaut, verschwinden die
## Stücke wieder (sanft) – und leere Paletten bzw. Container sammeln sich an.
##
## Dazu: Güterschuppen mit Laderampe, Lagerhalle, Lampenmasten, Fahnen,
## Gabelstapler, Drehkran, Rauch, Vögel auf den Waggons und zwei Arbeiter.
class_name FreightYard
extends Node3D

## Ein Güterzug wurde fertig be- und entladen (für Notizbuch und Tests).
signal train_serviced(train_number: String, delivered: Dictionary)
## Der Kran hat ein Stück abgesetzt.
signal piece_stored(goods_id: String, amount: int)

const GROUP := &"freight_yard"
const SAVE_ID := "freight_yard"
const STATION := "Güterbahnhof"
const HOLD_KEY := "freight_yard"
const CORRIDOR_BASE := 7900000
## Höhe der Traverse bei der Fahrt (über dem Hof) – alles passt darunter durch.
const TRAVEL_HOOK_Y := 9.9
const PARK_Z := -2.0
const PARK_X := 12.5
## Größter Simulationsschritt für die Kranbewegung.
const MAX_STEP := 0.1
## Höhe der Ladungsstücke (für Anheben und Stapeln).
const PIECE_HEIGHT := {"wood_bundle": 1.57, "brick_pallet": 0.86, "pallet_stack": 0.77,
	"glass_container": 2.52, "container_empty": 2.52, "steel_bundle": 1.04}
## So viele Paletten je leerem Palettenstapel, so viel Glas je Container.
const BRICKS_PER_PALLET_STACK := 30
const GLASS_PER_CONTAINER := 8

@export var terrain: LowPolyTerrain
@export var network: RailNetwork
@export var dispatcher: TrainDispatcher
@export var material: Material = preload("res://assets/materials/cargo.tres")
@export var glow_material: Material = preload("res://assets/materials/village_glow.tres")
@export var flag_material: Material
## Hofbelag (am besten das Schneematerial des Geländes, damit er sich einfügt).
@export var ground_material: Material
@export var enabled := true
@export_group("Anlage")
@export var track_x := 11.4
@export var crane_west_x := 8.4
@export var crane_span := 15.2
@export var crane_height := 10.5
@export var runway_start_z := -37.0
@export var runway_end_z := 13.0
@export_group("Tempo (Meter je Spielsekunde bei ×1)")
@export var gantry_speed := 6.0
@export var trolley_speed := 3.5
@export var hoist_speed := 3.2
@export_group("Geld")
## Trassengebühr, die jeder Güterzug zahlt.
@export var freight_fee := 40
@export var pallet_deposit := 8
@export var container_deposit := 20

var yard_y := 0.0

## Lagerplätze je Material: {"piece", "unit", "slots": Array[Transform3D], "nodes": Array[Node3D]}
var _storage := {}
var _empty_areas := {}
var _heaps: Array[MeshInstance3D] = []
var _bays: Array[Vector3] = []
var _empty_pallet_stacks := 0
var _empty_containers := 0
var _consumed := {"brick": 0, "glass": 0}
var _last_stock := {}
var _deliveries: Array[Dictionary] = []

# Kran
var _gantry: Node3D
var _trolley: Node3D
var _pivot: Node3D
var _rope: MeshInstance3D
var _hook: Node3D
var _traverse: MeshInstance3D
var _grab: Node3D
var _jaws: Array[Node3D] = []
var _carried: Node3D
var _carried_scoop: MeshInstance3D
var _crane_z := PARK_Z
var _crane_x := PARK_X
var _hook_y := TRAVEL_HOOK_Y
var _vel := Vector3.ZERO
var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _grab_open := 0.0
var _motor: AudioStreamPlayer3D
var _clank: AudioStreamPlayer3D

# Aufträge
var _train: Train
var _served: Dictionary[int, bool] = {}
var _jobs: Array[Dictionary] = []
var _job: Dictionary = {}
var _phase := ""
var _phase_time := 0.0
var _loading_planned := false
var _delivered := {}
var _check_timer := 0.0

# Atmosphäre
var _lights: Array[Light3D] = []
var _glow: StandardMaterial3D
var _forklift: Node3D
var _forks: Node3D
var _forklift_tween: Tween
var _jib_arm: Node3D
var _birds: Array[Dictionary] = []
var _worker: CharacterModel
var _driver: CharacterModel
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _dark := false
var _built := false
var progressive_dormant := false
var _static_body: SurfaceTool
var _static_glow: SurfaceTool


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GameDefs.GROUP_SAVEABLE)
	add_to_group(PropScatter.GROUP_CLEARING)
	_rng.seed = 2024
	# Erst wenn die Startstrecke liegt (Main baut sie in seinem _ready)
	_setup.call_deferred()


func _setup() -> void:
	if progressive_dormant or not is_inside_tree() or is_queued_for_deletion():
		return
	yard_y = _find_track_height()
	_level_ground()
	_glow = (glow_material as StandardMaterial3D).duplicate() if glow_material is StandardMaterial3D else StandardMaterial3D.new()
	_build_static()
	_build_storage()
	_build_crane()
	_build_life()
	_hook_y = _travel_y()
	for goods in Economy.get_goods():
		_last_stock[goods.id] = Economy.get_stock(goods.id)
		_refresh_storage(goods.id, false)
	_refresh_empties(false)
	Economy.stock_changed.connect(_on_stock_changed)
	if not Engine.is_editor_hint():
		WorldClock.darkness_changed.connect(_on_darkness_changed)
	_dark = WorldClock.is_dark()
	_apply_light(_dark, true)
	_place_crane()
	_built = true


func is_ready() -> bool:
	return _built


## Hakenhöhe (Welt) bei der Fahrt über den Hof.
func _travel_y() -> float:
	return yard_y + TRAVEL_HOOK_Y


## Hakenhöhe für den aktuellen Auftrag: Container brauchen die volle Höhe (Stapel),
## alles andere fährt niedriger und damit schneller (hängt trotzdem über Wagen und Containerstapeln).
func _job_travel_y() -> float:
	var piece := String(_job.get("piece", ""))
	if _job.is_empty() or piece.begins_with("container") or piece == "glass_container":
		return _travel_y()
	return yard_y + 8.4


## Rodet Bäume und Steine auf dem Hof ([PropScatter]).
func clears(x: float, z: float) -> bool:
	if progressive_dormant:
		return false
	return x > crane_west_x - 2.0 and x < 40.0 and z > runway_start_z - 4.0 and z < 27.0


## Gehört der Punkt zum Hof (dort baut das Dorf nicht)?
func covers(x: float, z: float) -> bool:
	if progressive_dormant:
		return false
	return x > 12.6 and x < 39.2 and z > runway_start_z - 2.2 and z < 25.2


# --- Aufbau --------------------------------------------------------------------------------

func _find_track_height() -> float:
	if network:
		var segment := network.find_segment_near(Vector3(track_x, 0.0, (runway_start_z + runway_end_z) * 0.5), 3.0)
		if segment:
			return segment.get_start_position().y
	return terrain.get_height(track_x + 6.0, -12.0) if terrain else 0.0


## Hof einebnen (wie bei Gleisen über Korridore – nie gespeichert, immer abgeleitet).
func _level_ground() -> void:
	if terrain == null:
		return
	var y := yard_y + TerrainDeformer.GROUND_OFFSET
	var lines := [
		[Vector2(14.6, runway_start_z - 1.0), Vector2(14.6, 22.0)],
		[Vector2(18.2, runway_start_z - 1.0), Vector2(18.2, 22.0)],
		[Vector2(21.8, runway_start_z - 1.0), Vector2(21.8, 22.0)],
		[Vector2(25.4, -30.0), Vector2(25.4, 24.0)],
		[Vector2(29.0, -20.0), Vector2(29.0, 24.0)],
		[Vector2(32.6, -18.0), Vector2(32.6, 24.0)],
		[Vector2(36.2, -16.0), Vector2(36.2, 22.0)],
		[Vector2(crane_west_x, runway_start_z - 1.0), Vector2(crane_west_x, runway_end_z + 2.0)],
	]
	for k in lines.size():
		var a: Vector2 = lines[k][0]
		var b: Vector2 = lines[k][1]
		terrain.set_track_corridor(CORRIDOR_BASE + k, PackedVector3Array([Vector3(a.x, y, a.y), Vector3(b.x, y, b.y)]))
	terrain.flush_changes()


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := 0.0, parent: Node3D = self, shadows := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.rotation.y = rot
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_collision(center: Vector3, size: Vector3, rot := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.rotation.y = rot
	add_child(body)


func _add_light(pos: Vector3, energy: float, light_range: float, spot_dir := Vector3.ZERO, parent: Node3D = self) -> Light3D:
	var light: Light3D
	if spot_dir != Vector3.ZERO:
		var spot := SpotLight3D.new()
		spot.spot_range = light_range
		spot.spot_angle = 52.0
		spot.spot_attenuation = 0.9
		light = spot
		spot.position = pos
		parent.add_child(spot)
		spot.look_at(spot.global_position + spot_dir, Vector3.UP if absf(spot_dir.normalized().y) < 0.95 else Vector3.FORWARD)
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = light_range
		omni.omni_attenuation = 1.3
		light = omni
		omni.position = pos
		parent.add_child(omni)
	light.light_color = VillageVisual.LIGHT_COLOR
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 20.0
	light.set_meta(&"energy", energy)
	light.light_energy = 0.0
	light.visible = false
	_lights.append(light)
	return light


## Unbewegliche Teile (Gebäude, Masten, Gestelle, Deko) werden zu einem Mesh
## zusammengefasst, leuchtende Gläser zu einem zweiten – wenige Zeichenaufrufe.
func _merge(mesh: ArrayMesh, xform: Transform3D, glow := false) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	(_static_glow if glow else _static_body).append_from(mesh, 0, xform)


func _build_static() -> void:
	var y := yard_y
	_static_body = SurfaceTool.new()
	_static_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_static_glow = SurfaceTool.new()
	_static_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Hofbelag
	_add_mesh(FreightMeshes.yard_ground(Vector2(26.0, 64.0), [4.0, 13.0, 20.0]), ground_material if ground_material else material,
		Vector3(12.8, y + 0.035, runway_start_z - 2.0), 0.0, self, false)
	# Kranbahn
	_merge(FreightMeshes.crane_rails(crane_span, runway_end_z - runway_start_z),
		Transform3D(Basis.IDENTITY, Vector3(crane_west_x, y, runway_start_z)))
	# Güterschuppen mit Rampe (Rampe zur Kranseite)
	var shed := FreightMeshes.goods_shed()
	var shed_pos := Vector3(24.4, y, -6.0)
	var shed_node := Node3D.new()
	shed_node.name = "GoodsShed"
	shed_node.position = shed_pos
	add_child(shed_node)
	_merge(shed["body"], Transform3D(Basis.IDENTITY, shed_pos))
	_merge(shed["glow"], Transform3D(Basis.IDENTITY, shed_pos), true)
	for p: Vector3 in shed["lights"]:
		_add_light(p, 1.3, 7.0, Vector3.ZERO, shed_node)
	var smoke := VillageVisual.create_smoke()
	smoke.position = shed["chimney"]
	shed_node.add_child(smoke)
	_add_sign(shed_node, shed["sign"], "GÜTERBAHNHOF WINTERVALE", -PI * 0.5, 64)
	_add_collision(shed_pos + Vector3(1.1, FreightMeshes.DOCK_HEIGHT * 0.5, 0.0), Vector3(2.2, FreightMeshes.DOCK_HEIGHT, 18.0))
	_add_collision(shed_pos + Vector3(6.2, 3.0, 0.0), Vector3(8.0, 6.0, 16.0))
	# Lagerhalle
	var hall := FreightMeshes.warehouse()
	var hall_pos := Vector3(31.6, y, 14.4)
	var hall_node := Node3D.new()
	hall_node.name = "Warehouse"
	hall_node.position = hall_pos
	add_child(hall_node)
	_merge(hall["body"], Transform3D(Basis.IDENTITY, hall_pos))
	_merge(hall["glow"], Transform3D(Basis.IDENTITY, hall_pos), true)
	for p: Vector3 in hall["lights"]:
		_add_light(p, 1.4, 8.0, Vector3.ZERO, hall_node)
	var stove := VillageVisual.create_smoke()
	stove.position = Vector3(3.2, 8.6, 5.0)
	stove.amount = 8
	hall_node.add_child(stove)
	_add_sign(hall_node, hall["sign"], "LAGERHALLE", PI, 72)
	_add_collision(hall_pos + Vector3(0, 3.5, 0), Vector3(12.2, 7.0, 18.2))
	# Lagerflächen
	_merge(FreightMeshes.wood_rack(_wood_columns(), _wood_rows()), Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	_merge(FreightMeshes.stone_bays(3, 3.1, 4.6), Transform3D(Basis.IDENTITY, Vector3(17.8, y, -19.6)))
	_merge(FreightMeshes.sleepers(_grid([15.1, 17.8, 20.5], [-12.4, -9.2], 0.0), Vector2(2.0, 2.8)), Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	_merge(FreightMeshes.sleepers(_grid([14.6, 15.95, 17.3, 18.65, 20.3, 21.65], [-4.9, -3.4], 0.0), Vector2(1.1, 1.25)),
		Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	_merge(FreightMeshes.sleepers(_grid([14.9, 17.8, 20.7], [4.0, 8.8], 0.0), Vector2(2.5, 4.2), true), Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	# Lampenmasten mit Flutlichtern (auf den Hof gerichtet)
	for mast: Vector3 in [Vector3(26.4, 0, -34.0), Vector3(26.4, 0, -18.5), Vector3(22.8, 0, 20.5), Vector3(6.6, 0, 18.0)]:
		var data := FreightMeshes.lamp_mast(9.5)
		var node := Node3D.new()
		node.position = Vector3(mast.x, y, mast.z)
		node.rotation.y = atan2(mast.x - 17.0, mast.z - (-12.0))
		add_child(node)
		_merge(data["body"], node.transform)
		_merge(data["glow"], node.transform, true)
		var aim := (Vector3(17.0, y, -12.0) - node.position)
		aim.y = 0.0
		for p: Vector3 in data["lights"]:
			_add_light(p, 2.2, 24.0, aim.normalized() + Vector3.DOWN * 0.9, node)
		_add_collision(Vector3(mast.x, y + 2.0, mast.z), Vector3(0.8, 4.0, 0.8))
	# Fahnen am Hofeingang
	var flag_colors := [[Color(0.72, 0.16, 0.14), Color(0.95, 0.93, 0.88)], [Color(0.2, 0.36, 0.55), Color(0.95, 0.93, 0.88)],
		[Color(0.26, 0.45, 0.3), Color(0.95, 0.8, 0.3)]]
	for i in 3:
		var pole := Vector3(37.4, y, -12.6 + i * 2.2)
		_merge(FreightMeshes.flag_pole(7.0), Transform3D(Basis.IDENTITY, pole))
		var cloth := _add_mesh(FreightMeshes.flag_cloth(flag_colors[i]), flag_material if flag_material else material,
			pole + Vector3(0.05, 7.2, 0), -0.4 + i * 0.1, self, false)
		cloth.name = "Flag%d" % i
	# Deko: Brennholz, Paletten, Fässer
	_merge(FreightMeshes.firewood_stack(), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(35.4, y, 1.2)))
	_merge(FreightMeshes.pallet_pile(), Transform3D(Basis(Vector3.UP, 0.3), Vector3(36.4, y, -16.5)))
	_merge(FreightMeshes.pallet_pile(), Transform3D(Basis(Vector3.UP, -0.6), Vector3(23.6, y, 24.2)))
	_add_collision(Vector3(35.4, y + 1.1, 1.2), Vector3(1.4, 2.2, 4.2))
	# Lagerflächen sind fest: Man läuft nicht durch Stapel, baut dort keine Gleise und Häuser
	for area: Array in [[13.5, 22.0, -35.4, -25.6, 3.4], [13.1, 22.5, -22.3, -16.5, 1.7], [13.9, 21.7, -14.1, -7.6, 2.2],
			[13.9, 22.3, -5.6, -2.7, 1.8], [13.5, 22.0, 1.8, 11.0, 5.2]]:
		var size := Vector3(area[1] - area[0], area[4], area[3] - area[2])
		_add_collision(Vector3((area[0] + area[1]) * 0.5, y + size.y * 0.5, (area[2] + area[3]) * 0.5), size)
	var body := _add_mesh(_static_body.commit(), material, Vector3.ZERO)
	body.name = "YardStatic"
	var glow := _add_mesh(_static_glow.commit(), _glow, Vector3.ZERO, 0.0, self, false)
	glow.name = "YardGlow"
	_static_body = null
	_static_glow = null


func _add_sign(parent: Node3D, pos: Vector3, text: String, rot: float, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.modulate = Color(0.32, 0.14, 0.1)
	label.outline_size = 0
	label.position = pos
	label.rotation.y = rot
	label.double_sided = false
	parent.add_child(label)


func _wood_columns() -> Array:
	return [15.0, 17.8, 20.6]


func _wood_rows() -> Array:
	return [-33.8, -30.5, -27.2]


func _grid(columns: Array, rows: Array, y: float) -> Array:
	var slots: Array = []
	for z: float in rows:
		for x: float in columns:
			slots.append(Vector3(x, y, z))
	return slots


## Lagerplätze je Material in Füllreihenfolge (erst die untere Lage, dann gestapelt).
func _build_storage() -> void:
	var y := yard_y
	_storage["wood"] = _area("wood_bundle", 10, _layers(_grid(_wood_columns(), _wood_rows(), y + 0.16), 2, 1.57))
	_storage["steel"] = _area("steel_bundle", 4, _layers(_grid([15.1, 17.8, 20.5], [-12.4, -9.2], y + 0.12), 2, 1.04))
	_storage["brick"] = _area("brick_pallet", 6, _layers(_grid([14.6, 15.95, 17.3, 18.65], [-4.9, -3.4], y + 0.12), 2, 0.86))
	var container_slots := _layers(_grid([14.9, 17.8, 20.7], [4.0, 8.8], y + 0.12), 2, 2.52)
	_storage["glass"] = _area("glass_container", 8, container_slots.slice(0, 8))
	_empty_areas["container_empty"] = _area("container_empty", 1, container_slots.slice(8))
	_empty_areas["pallet_stack"] = _area("pallet_stack", 1, _layers(_grid([20.3, 21.65], [-4.9, -3.4], y + 0.12), 2, 0.77))
	# Steinboxen: drei Haufen, die mit dem Bestand wachsen
	var heap_mesh := TrainMeshes.create_cargo("stone_heap")
	for i in 3:
		var center := Vector3(17.8 + (i - 1) * 3.1, y + 0.04, -19.6)
		_bays.append(center)
		var heap := _add_mesh(heap_mesh, material, center, i * 1.3)
		heap.visible = false
		_heaps.append(heap)


## Eine Lagerfläche. Gleichartige Stücke (Holz, Ziegel, Stahl, Leerpaletten)
## werden als MultiMesh gezeichnet – ein Zeichenaufruf für die ganze Fläche.
## Container behalten eigene Nodes (jeder hat eine andere Farbe).
func _area(piece: String, unit: int, slots: Array) -> Dictionary:
	var transforms: Array[Transform3D] = []
	for slot: Vector3 in slots:
		transforms.append(Transform3D(Basis.IDENTITY, slot))
	var area := {"piece": piece, "unit": unit, "slots": transforms, "nodes": [], "count": 0}
	if not piece.begins_with("container") and piece != "glass_container":
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = TrainMeshes.create_cargo(piece, 0)
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
		multimesh.visible_instance_count = 0
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.name = "Storage_" + piece
		add_child(instance)
		area["multimesh"] = multimesh
	return area


## Wie viele Stücke eine Lagerfläche gerade zeigt.
func _area_count(area: Dictionary) -> int:
	return int(area["count"]) if area.has("multimesh") else (area["nodes"] as Array).size()


func _layers(slots: Array, layers: int, height: float) -> Array:
	var result: Array = []
	for layer in layers:
		for slot: Vector3 in slots:
			result.append(slot + Vector3(0, layer * (height + 0.02), 0))
	return result


func _build_crane() -> void:
	var gantry_data := FreightMeshes.crane_gantry(crane_span, crane_height)
	_gantry = Node3D.new()
	_gantry.name = "Crane"
	add_child(_gantry)
	_add_mesh(gantry_data["body"], material, Vector3.ZERO, 0.0, _gantry)
	_add_mesh(gantry_data["glow"], _glow, Vector3.ZERO, 0.0, _gantry, false)
	for p: Vector3 in gantry_data["lights"]:
		_add_light(p, 1.6, 12.0, Vector3.DOWN, _gantry)
	# Beine als bewegliche Hindernisse (die Spielfigur läuft nicht hindurch)
	var legs := AnimatableBody3D.new()
	legs.collision_layer = GameDefs.LAYER_OBJECTS
	legs.collision_mask = 0
	legs.sync_to_physics = false
	for x: float in [0.0, crane_span]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, crane_height, 1.6)
		shape.shape = box
		shape.position = Vector3(x, crane_height * 0.5, 0.0)
		legs.add_child(shape)
	_gantry.add_child(legs)
	var trolley_data := FreightMeshes.crane_trolley()
	_trolley = Node3D.new()
	_trolley.name = "Trolley"
	_trolley.position = Vector3(0, crane_height + 1.42, 0)
	_gantry.add_child(_trolley)
	_add_mesh(trolley_data["body"], material, Vector3.ZERO, 0.0, _trolley)
	_add_mesh(trolley_data["glow"], _glow, Vector3.ZERO, 0.0, _trolley, false)
	_pivot = Node3D.new()
	_pivot.name = "Pendulum"
	_pivot.position = Vector3(-0.65, 0.4, 0.0)
	_trolley.add_child(_pivot)
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.035
	rope_mesh.bottom_radius = 0.035
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 5
	rope_mesh.rings = 0
	_rope = _add_mesh(rope_mesh, material, Vector3.ZERO, 0.0, _pivot, false)
	_rope.material_override = _dark_rope_material()
	_hook = Node3D.new()
	_hook.name = "Hook"
	_pivot.add_child(_hook)
	_traverse = _add_mesh(FreightMeshes.crane_hook(), material, Vector3.ZERO, 0.0, _hook)
	_grab = Node3D.new()
	_grab.name = "Grab"
	_grab.visible = false
	_hook.add_child(_grab)
	_add_mesh(FreightMeshes.grab_head(), material, Vector3.ZERO, 0.0, _grab)
	for s: float in [-1.0, 1.0]:
		var jaw := Node3D.new()
		jaw.position = Vector3(s * 0.12, -0.85, 0.0)
		jaw.scale = Vector3(s, 1.0, 1.0)
		_grab.add_child(jaw)
		_add_mesh(FreightMeshes.grab_jaw(), material, Vector3.ZERO, 0.0, jaw)
		_jaws.append(jaw)
	_carried_scoop = _add_mesh(TrainMeshes.create_cargo("stone_scoop"), material, Vector3(0, -1.55, 0), 0.0, _grab, false)
	_carried_scoop.visible = false
	_motor = _make_player("crane_motor", -20.0, 40.0, _trolley)
	_clank = _make_player("clank", -10.0, 35.0, _hook)
	# Wimpel oben auf dem Kran
	var pennant := _add_mesh(FreightMeshes.flag_cloth([Color(0.72, 0.16, 0.14), Color(0.95, 0.93, 0.88)]),
		flag_material if flag_material else material, gantry_data["flag"], -0.3, _gantry, false)
	pennant.scale = Vector3(0.45, 0.45, 0.45)


func _dark_rope_material() -> StandardMaterial3D:
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.14, 0.14, 0.15)
	rope.roughness = 0.6
	return rope


func _make_player(sound: String, volume: float, distance: float, parent: Node3D) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = SoundLibrary.get_sound(sound)
	player.volume_db = volume
	player.max_distance = distance
	player.unit_size = 6.0
	parent.add_child(player)
	SoundLibrary.stop_on_exit(player)
	return player


## Gabelstapler mit Fahrer, Drehkran, Arbeiter, Vögel auf dem Schuppendach.
func _build_life() -> void:
	var y := yard_y
	var fork_data := FreightMeshes.forklift()
	_forklift = Node3D.new()
	_forklift.name = "Forklift"
	_forklift.position = Vector3(25.5, y + FreightMeshes.DOCK_HEIGHT, -9.0)
	add_child(_forklift)
	_add_mesh(fork_data["body"], material, Vector3.ZERO, 0.0, _forklift)
	_add_mesh(FreightMeshes.forklift_mast(), material, Vector3.ZERO, 0.0, _forklift)
	_forks = Node3D.new()
	_forklift.add_child(_forks)
	_add_mesh(FreightMeshes.forklift_forks(), material, Vector3.ZERO, 0.0, _forks)
	var fork_pallet := _add_mesh(TrainMeshes.create_cargo("brick_pallet", 1), material, Vector3(0, 0.1, -1.6), 0.0, _forks, false)
	fork_pallet.name = "Pallet"
	var appearance_rng := RandomNumberGenerator.new()
	appearance_rng.seed = 919
	_driver = CharacterModel.new()
	_driver.appearance = NpcDirector.random_appearance(appearance_rng)
	_driver.view_distance = 90.0
	_forklift.add_child(_driver)
	_driver.position = fork_data["seat"] + Vector3(0, -0.45, 0.12)
	_driver.set_pose(CharacterModel.Pose.SIT)
	_jib_arm = Node3D.new()
	_jib_arm.position = Vector3(25.3, y + FreightMeshes.DOCK_HEIGHT, -14.2)
	add_child(_jib_arm)
	_add_mesh(FreightMeshes.jib_pillar(), material, Vector3.ZERO, 0.0, _jib_arm)
	var arm := Node3D.new()
	arm.name = "Arm"
	_jib_arm.add_child(arm)
	_add_mesh(FreightMeshes.jib_arm(), material, Vector3.ZERO, 0.0, arm)
	_worker = CharacterModel.new()
	_worker.appearance = NpcDirector.random_appearance(appearance_rng)
	_worker.view_distance = 90.0
	add_child(_worker)
	_worker.position = Vector3(24.95, y + FreightMeshes.DOCK_HEIGHT, -12.9)
	_worker.rotation.y = PI * 0.5
	_worker.set_pose(CharacterModel.Pose.HANDS_BEHIND)
	# Ein paar Vögel auf dem First des Schuppens
	for i in 3:
		_spawn_bird(Vector3(30.6, y + 7.2, -9.0 + i * 1.3 + _rng.randf_range(-0.3, 0.3)), null)


# --- Lagerbestände sichtbar machen ------------------------------------------------------------

## Wie viele Stücke ein Material gerade im Lager zeigt.
func get_visible_pieces(goods_id: String) -> int:
	if goods_id == "stone":
		var count := 0
		for heap in _heaps:
			if heap.visible:
				count += 1
		return count
	var area: Dictionary = _storage.get(goods_id, {})
	return _area_count(area) if not area.is_empty() else 0


func get_storage_capacity(goods_id: String) -> int:
	var area: Dictionary = _storage.get(goods_id, {})
	return (area.get("slots", []) as Array).size()


func get_empties() -> Dictionary:
	return {"pallet_stack": _empty_pallet_stacks, "container_empty": _empty_containers}


func _target_count(goods_id: String) -> int:
	var area: Dictionary = _storage[goods_id]
	return mini(ceili(float(Economy.get_stock(goods_id)) / int(area["unit"])), (area["slots"] as Array).size())


func _refresh_storage(goods_id: String, animated := true) -> void:
	if goods_id == "stone":
		_refresh_heaps(animated)
		return
	if not _storage.has(goods_id):
		return
	_sync_area(_storage[goods_id], _target_count(goods_id), animated)


func _refresh_empties(animated := true) -> void:
	_sync_area(_empty_areas["pallet_stack"], mini(_empty_pallet_stacks, (_empty_areas["pallet_stack"]["slots"] as Array).size()), animated)
	_sync_area(_empty_areas["container_empty"], mini(_empty_containers, (_empty_areas["container_empty"]["slots"] as Array).size()), animated)


func _sync_area(area: Dictionary, count: int, animated: bool) -> void:
	if area.has("multimesh"):
		_sync_multimesh(area, count, animated)
		return
	var nodes: Array = area["nodes"]
	var slots: Array = area["slots"]
	while nodes.size() < count:
		var index := nodes.size()
		var piece := MeshInstance3D.new()
		piece.mesh = TrainMeshes.create_cargo(area["piece"], index)
		piece.material_override = material
		piece.transform = slots[index]
		add_child(piece)
		nodes.append(piece)
	while nodes.size() > count:
		var piece: Node3D = nodes.pop_back()
		if animated and is_inside_tree():
			# Verbautes Material verschwindet sanft
			var tween := piece.create_tween()
			tween.tween_property(piece, "scale", Vector3(0.9, 0.05, 0.9), 0.7).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(piece.queue_free)
		else:
			piece.queue_free()


## MultiMesh-Fläche: sichtbare Anzahl anpassen; ein verbautes Stück sinkt vorher sanft zusammen.
func _sync_multimesh(area: Dictionary, count: int, animated: bool) -> void:
	var multimesh: MultiMesh = area["multimesh"]
	var slots: Array = area["slots"]
	var before := int(area["count"])
	area["count"] = count
	# Neue Stücke erscheinen in voller Größe (z.B. gerade vom Kran abgesetzt)
	for i in range(before, count):
		multimesh.set_instance_transform(i, slots[i])
	if count >= before or not animated or not is_inside_tree():
		multimesh.visible_instance_count = count
		return
	# Weniger Stücke: die obersten schrumpfen weg, dann werden sie ausgeblendet
	var tween := create_tween().set_parallel(true)
	for i in range(count, before):
		var slot: Transform3D = slots[i]
		tween.tween_method(func(t: float) -> void:
			multimesh.set_instance_transform(i, slot.scaled_local(Vector3(1.0 - t * 0.1, 1.0 - t * 0.95, 1.0 - t * 0.1))),
			0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void:
		if int(area["count"]) <= count:
			multimesh.visible_instance_count = int(area["count"])
			for i in range(int(area["count"]), before):
				multimesh.set_instance_transform(i, slots[i]))


func _refresh_heaps(animated: bool) -> void:
	var stock := Economy.get_stock("stone")
	var per_bay := ceilf(Economy.get_max("stone") / 3.0)
	for i in _heaps.size():
		var fill := clampf((stock - i * per_bay) / per_bay, 0.0, 1.0)
		var heap := _heaps[i]
		var target := Vector3(0.6 + 0.8 * fill, 0.25 + 1.35 * fill, 0.6 + 0.8 * fill) if fill > 0.0 else Vector3(0.3, 0.02, 0.3)
		heap.visible = fill > 0.0 or (animated and heap.visible)
		if animated and is_inside_tree():
			var tween := heap.create_tween()
			tween.tween_property(heap, "scale", target, 0.9).set_trans(Tween.TRANS_SINE)
			if fill <= 0.0:
				tween.tween_callback(heap.hide)
		else:
			heap.scale = target


## Bestand hat sich geändert: Lager neu zeigen; verbrauchte Ziegel und Glas
## hinterlassen leere Paletten bzw. Container (Leergut).
func _on_stock_changed(goods_id: String) -> void:
	var now := Economy.get_stock(goods_id)
	var before := int(_last_stock.get(goods_id, now))
	_last_stock[goods_id] = now
	if now < before and _consumed.has(goods_id):
		_consumed[goods_id] = int(_consumed[goods_id]) + before - now
		_update_empties()
	if _built:
		_refresh_storage(goods_id)


func _update_empties() -> void:
	var changed := false
	while int(_consumed["brick"]) >= BRICKS_PER_PALLET_STACK:
		_consumed["brick"] = int(_consumed["brick"]) - BRICKS_PER_PALLET_STACK
		_empty_pallet_stacks = mini(_empty_pallet_stacks + 1, 8)
		changed = true
	while int(_consumed["glass"]) >= GLASS_PER_CONTAINER:
		_consumed["glass"] = int(_consumed["glass"]) - GLASS_PER_CONTAINER
		_empty_containers = mini(_empty_containers + 1, 4)
		changed = true
	if changed and _built:
		_refresh_empties()


# --- Züge und Aufträge -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	_update_birds(delta)
	_animate_jib(delta)
	if not enabled or WorldClock.paused:
		return
	var sim := delta * WorldClock.time_scale
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.25
		_watch_trains()
	while sim > 0.0:
		var step := minf(sim, MAX_STEP)
		sim -= step
		_update_crane(step)
	_place_crane()
	_update_sound()


## Der Zug, der gerade am Güterbahnhof steht (oder null).
func get_current_train() -> Train:
	return _train if is_instance_valid(_train) else null


func is_working() -> bool:
	return not _job.is_empty() or not _jobs.is_empty()


## Kurzer Text für Notizbuch und Tests, z.B. "Kran entlädt GZ 801 (3 von 7)".
func get_status_text() -> String:
	var train := get_current_train()
	if train == null:
		return "Der Kran ruht – nächster Güterzug laut Fahrplan."
	if is_working():
		var done := int(_delivered.get("_count", 0))
		var verb := "belädt" if _loading_planned else "entlädt"
		return "Der Kran %s %s (%d erledigt, %d offen)." % [verb, train.entry.train_number, done, _jobs.size() + (0 if _job.is_empty() else 1)]
	return "%s ist fertig und fährt gleich ab." % train.entry.train_number


## Letzte Lieferungen: [{"train", "day", "hours", "goods": {id: Menge}}], neueste zuerst.
func get_deliveries() -> Array[Dictionary]:
	return _deliveries


func _watch_trains() -> void:
	if get_current_train() != null:
		if _train.state == Train.State.DONE or _train.state == Train.State.RUNNING:
			_train = null
			_served.clear()  # abgefahrene Züge halten hier nie wieder
		return
	if dispatcher == null:
		return
	for train in dispatcher.get_trains():
		if train.state != Train.State.DWELLING or _served.has(train.train_id):
			continue
		if train.platform_stop == null or train.platform_stop.station_name != STATION:
			continue
		_begin_service(train)
		return


func _begin_service(train: Train) -> void:
	_train = train
	_served[train.train_id] = true
	_loading_planned = false
	_delivered = {"_count": 0}
	train.hold_departure(HOLD_KEY)
	Economy.earn(freight_fee, "Trassengebühr %s" % train.entry.train_number, "freight")
	_plan_unloading(train)
	_worker.play_gesture(CharacterModel.Pose.WAVE, 2.2)
	_spawn_wagon_birds(train)
	if _jobs.is_empty():
		_plan_loading(train)
	_drive_forklift(true)


## Entladeaufträge: nur was bestellt ist, ins Lager passt und bezahlt werden kann.
func _plan_unloading(train: Train) -> void:
	_jobs.clear()
	var planned := {}
	var money_left := Economy.money
	for car in train.cars:
		if not car.has_cargo_slots():
			continue
		var cargo := car.get_cargo()
		for i in cargo.size():
			var entry: Dictionary = cargo[i]
			if entry["state"] != "full":
				continue
			var goods := String(entry["goods"])
			var amount := int(entry["amount"])
			var goods_type := Economy.get_goods_type(goods)
			if goods_type == null or not Economy.is_ordered(goods):
				continue
			var portions := int(entry["portions"]) if car.is_bulk() else 1
			for p in portions:
				var price := amount * goods_type.unit_price
				if Economy.get_space(goods) - int(planned.get(goods, 0)) < amount or (price > money_left and not Economy.free_build):
					break
				planned[goods] = int(planned.get(goods, 0)) + amount
				money_left -= price
				_jobs.append({"kind": "unload", "car": car, "index": i, "goods": goods, "amount": amount,
					"piece": entry["piece"], "bulk": car.is_bulk(), "price": price})
	_sort_jobs()


## Leergut zurückladen: leere Palettenstapel auf Flachwagen, leere Container auf Containerwagen.
func _plan_loading(train: Train) -> void:
	_loading_planned = true
	var pallets := _empty_pallet_stacks
	var containers := _empty_containers
	for car in train.cars:
		var empty := car.get_empty_piece()
		if empty == "":
			continue
		var cargo := car.get_cargo()
		for i in cargo.size():
			if cargo[i]["state"] != "none":
				continue
			if empty == "pallet_stack" and pallets > 0:
				pallets -= 1
			elif empty == "container_empty" and containers > 0:
				containers -= 1
			else:
				continue
			_jobs.append({"kind": "load", "car": car, "index": i, "piece": empty})
	_sort_jobs()


## Aufträge so ordnen, dass der Kran wenig hin- und herfährt (entlang des Zuges).
func _sort_jobs() -> void:
	_jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var za := (a["car"] as TrainCar).get_slot_transform(a["index"]).origin.z
		var zb := (b["car"] as TrainCar).get_slot_transform(b["index"]).origin.z
		return za < zb)


func _finish_service() -> void:
	var train := get_current_train()
	if train:
		train.release_departure(HOLD_KEY)
		var delivered := _delivered.duplicate()
		delivered.erase("_count")
		if not delivered.is_empty():
			_deliveries.push_front({"train": train.entry.train_number, "day": WorldClock.day,
				"hours": WorldClock.time_of_day, "goods": delivered})
			if _deliveries.size() > 12:
				_deliveries.resize(12)
		train_serviced.emit(train.entry.train_number, delivered)
		_worker.play_gesture(CharacterModel.Pose.NOD, 1.5)
	_drive_forklift(false)


# --- Kran ---------------------------------------------------------------------------------

func _update_crane(dt: float) -> void:
	_phase_time += dt
	if _job.is_empty():
		if not _jobs.is_empty():
			_job = _jobs.pop_front()
			if not _job_valid():
				_job = {}
				return
			_set_phase("to_pick")
		elif get_current_train() and not _loading_planned:
			_plan_loading(_train)
			if _jobs.is_empty():
				_finish_service()
		elif get_current_train() and _train.is_departure_held():
			_finish_service()
		else:
			# Parkstellung
			_move_to(PARK_Z, PARK_X, _travel_y(), dt)
		return
	if _train_gone():
		return
	match _phase:
		"to_pick":
			var pick := _pick_point()
			if _hook_y < _job_travel_y() - 0.05:
				_move_axis_hoist(_job_travel_y(), dt)
			elif _move_to(pick.z, pick.x, _job_travel_y(), dt):
				_set_phase("lower_pick")
		"lower_pick":
			var pick := _pick_point()
			_prepare_tool()
			if _move_to(pick.z, pick.x, pick.y, dt, 0.75):
				_set_phase("grab")
		"grab":
			if _job.get("bulk", false):
				_grab_open = move_toward(_grab_open, 0.0, dt * 1.6)
			if _phase_time >= 0.55:
				if not _take_piece():
					_job = {}
					return
				SoundLibrary.play(_clank)
				_set_phase("raise")
		"raise":
			if _move_axis_hoist(_job_travel_y(), dt, 0.8):
				_set_phase("to_drop")
		"to_drop":
			var drop := _drop_point()
			if _move_to(drop.z, drop.x, _job_travel_y(), dt):
				_set_phase("lower_drop")
		"lower_drop":
			var drop := _drop_point()
			if _move_to(drop.z, drop.x, drop.y, dt, 0.75):
				_set_phase("release")
		"release":
			if _job.get("bulk", false):
				_grab_open = move_toward(_grab_open, 1.0, dt * 1.4)
			if _phase_time >= (0.9 if _job.get("bulk", false) else 0.45):
				_release_piece()
				SoundLibrary.play(_clank)
				_set_phase("clear")
		"clear":
			if _move_axis_hoist(_job_travel_y(), dt):
				_job = {}


## Der Zug des Auftrags ist verschwunden (z.B. Spielstand geladen): Auftrag abbrechen.
## Ein angehobenes Leergut-Stück kommt zurück aufs Lager, entladene Ware wird noch abgelegt.
func _train_gone() -> bool:
	if is_instance_valid(_job.get("car")):
		return false
	var carrying := _carried != null or _carried_scoop.visible
	if carrying and _job["kind"] == "unload":
		return false  # Ware hängt schon am Haken: normal ins Lager bringen
	if carrying and _job["kind"] == "load":
		if _job["piece"] == "pallet_stack":
			_empty_pallet_stacks += 1
		else:
			_empty_containers += 1
		if _carried:
			_carried.queue_free()
		_carried = null
		_refresh_empties(false)
	_job = {}
	return true


func _set_phase(phase: String) -> void:
	_phase = phase
	_phase_time = 0.0


## Ist der Auftrag noch ausführbar (Zug steht noch, Platz ist noch belegt/frei)?
func _job_valid() -> bool:
	# Erst prüfen, dann typisiert zuweisen: ein abgefahrener Zug ist schon freigegeben.
	if not is_instance_valid(_job.get("car")) or get_current_train() == null:
		return false
	var car: TrainCar = _job["car"]
	var entry: Dictionary = car.get_cargo()[_job["index"]]
	if _job["kind"] == "unload":
		return entry["state"] == "full"
	return entry["state"] == "none" and ((_job["piece"] == "pallet_stack" and _empty_pallet_stacks > 0)
		or (_job["piece"] == "container_empty" and _empty_containers > 0))


## Wohin der Haken zum Aufnehmen muss (Welt, y = Höhe der Hakenaufhängung).
func _pick_point() -> Vector3:
	if _job["kind"] == "load":
		var area: Dictionary = _empty_areas[_job["piece"]]
		var slot: Transform3D = (area["slots"] as Array)[maxi(_area_count(area) - 1, 0)]
		return slot.origin + Vector3(0, float(PIECE_HEIGHT[_job["piece"]]) - FreightMeshes.HOOK_LOAD_Y, 0)
	var car: TrainCar = _job["car"]
	if _job.get("bulk", false):
		return car.get_bulk_top(_job["index"]) + Vector3(0, 1.2, 0)
	var slot := car.get_slot_transform(_job["index"])
	return slot.origin + Vector3(0, float(PIECE_HEIGHT.get(_job["piece"], 1.0)) - FreightMeshes.HOOK_LOAD_Y, 0)


func _drop_point() -> Vector3:
	if _job["kind"] == "load":
		var car: TrainCar = _job["car"]
		var slot := car.get_slot_transform(_job["index"])
		return slot.origin + Vector3(0, float(PIECE_HEIGHT[_job["piece"]]) - FreightMeshes.HOOK_LOAD_Y, 0)
	var goods := String(_job["goods"])
	if goods == "stone":
		var bay := _bays[clampi(int(Economy.get_stock("stone") / ceilf(Economy.get_max("stone") / 3.0)), 0, 2)]
		return bay + Vector3(0, 3.6, 0)
	var area: Dictionary = _storage[goods]
	var index := mini(_target_count(goods), (area["slots"] as Array).size() - 1)
	var slot: Transform3D = (area["slots"] as Array)[index]
	return slot.origin + Vector3(0, float(PIECE_HEIGHT.get(_job["piece"], 1.0)) - FreightMeshes.HOOK_LOAD_Y, 0)


## Traverse oder Greifer, je nach Ladung.
func _prepare_tool() -> void:
	var bulk: bool = _job.get("bulk", false)
	_grab.visible = bulk
	_traverse.visible = not bulk
	if bulk and _phase == "lower_pick":
		_grab_open = move_toward(_grab_open, 1.0, 0.05)


## Stück anheben. Rückgabe false, wenn es nicht (mehr) geht.
func _take_piece() -> bool:
	var car: TrainCar = _job["car"]
	if not is_instance_valid(car):
		return false
	if _job["kind"] == "load":
		var area: Dictionary = _empty_areas[_job["piece"]]
		var index := _area_count(area) - 1
		if index < 0:
			return false
		var node: Node3D
		if area.has("multimesh"):
			# Das oberste Stück des MultiMesh wird zu einem eigenen Stück am Haken
			var mesh := MeshInstance3D.new()
			mesh.mesh = (area["multimesh"] as MultiMesh).mesh
			mesh.material_override = material
			add_child(mesh)
			mesh.transform = (area["slots"] as Array)[index]
			node = mesh
			_sync_area(area, index, false)
		else:
			node = (area["nodes"] as Array).pop_back()
		if _job["piece"] == "pallet_stack":
			_empty_pallet_stacks -= 1
		else:
			_empty_containers -= 1
		_attach_to_hook(node)
		return true
	var price := int(_job["price"])
	if not Economy.free_build and not Economy.pay(price, "Einkauf %d %s (%s)" % [int(_job["amount"]),
			Economy.get_label(_job["goods"]), _train.entry.train_number], "purchase"):
		return false
	if _job.get("bulk", false):
		car.take_bulk_portion(_job["index"])
		_carried_scoop.visible = true
		return true
	var piece := car.detach_cargo(_job["index"])
	if piece == null:
		return false
	_attach_to_hook(piece)
	return true


func _attach_to_hook(node: Node3D) -> void:
	if node.get_parent():
		node.get_parent().remove_child(node)
	_hook.add_child(node)
	var height := float(PIECE_HEIGHT.get(_job["piece"], 1.0))
	node.transform = Transform3D(Basis.IDENTITY, Vector3(0, FreightMeshes.HOOK_LOAD_Y - height, 0))
	_carried = node


func _release_piece() -> void:
	if _job["kind"] == "load":
		var car: TrainCar = _job["car"]
		if _carried and is_instance_valid(car):
			car.attach_cargo(_job["index"], _carried, _job["piece"], "", 0, "empty")
			Economy.earn(pallet_deposit if _job["piece"] == "pallet_stack" else container_deposit,
				"Leergut-Pfand (%s)" % _train.entry.train_number if get_current_train() else "Leergut-Pfand", "deposit")
		elif _carried:
			_carried.queue_free()
		_carried = null
		return
	var goods := String(_job["goods"])
	var amount := int(_job["amount"])
	if _job.get("bulk", false):
		_carried_scoop.visible = false
		_pour_stones(_drop_point() - Vector3(0, 2.2, 0))
	elif _carried:
		_carried.queue_free()
		_carried = null
	# Im Lager angekommen: jetzt zählt es (das Lager zeigt das Stück am selben Platz)
	var accepted := Economy.add_stock(goods, amount)
	_delivered[goods] = int(_delivered.get(goods, 0)) + accepted
	_delivered["_count"] = int(_delivered.get("_count", 0)) + 1
	piece_stored.emit(goods, accepted)


## Bewegt Kran und Katze zu (z, x) und den Haken auf [param hook_y].
## Rückgabe true, wenn alles angekommen ist.
func _move_to(z: float, x: float, hook_y: float, dt: float, hoist_factor := 1.0) -> bool:
	# Ziele außerhalb der Kranbahn werden so nah wie möglich angefahren
	z = clampf(z, runway_start_z + 2.6, runway_end_z - 2.6)
	x = clampf(x, crane_west_x + 1.2, crane_west_x + crane_span - 1.6)
	var at_z := _move_axis(0, z, gantry_speed, 2.2, dt)
	var at_x := _move_axis(1, x, trolley_speed, 2.2, dt)
	var at_y := true
	if at_z and at_x:
		at_y = _move_axis_hoist(hook_y, dt, hoist_factor)
	return at_z and at_x and at_y


func _move_axis_hoist(target: float, dt: float, factor := 1.0) -> bool:
	return _move_axis(2, target, hoist_speed * factor, 3.0, dt)


## Weiche Achsbewegung mit Anfahren und Abbremsen. Achse 0 = Kran (z), 1 = Katze (x), 2 = Haken (y).
func _move_axis(axis: int, target: float, max_speed: float, accel: float, dt: float) -> bool:
	var current: float = [_crane_z, _crane_x, _hook_y][axis]
	var distance := target - current
	var velocity := _vel[axis]
	if absf(distance) < 0.01 and absf(velocity) < 0.05:
		_set_axis(axis, target)
		_vel[axis] = 0.0
		return true
	var desired := signf(distance) * minf(max_speed, sqrt(2.0 * accel * absf(distance)))
	var old_velocity := velocity
	velocity = move_toward(velocity, desired, accel * dt)
	var step := velocity * dt
	if absf(step) > absf(distance):
		step = distance
		velocity = 0.0
	_set_axis(axis, current + step)
	_vel[axis] = velocity
	# Die Last pendelt beim Anfahren und Bremsen leicht nach
	if axis < 2 and dt > 0.0:
		var accel_now := (velocity - old_velocity) / dt
		if axis == 0:
			_sway_vel.y -= accel_now * 0.012
		else:
			_sway_vel.x -= accel_now * 0.012
	return false


func _set_axis(axis: int, value: float) -> void:
	match axis:
		0:
			_crane_z = clampf(value, runway_start_z + 2.6, runway_end_z - 2.6)
		1:
			_crane_x = clampf(value, crane_west_x + 1.2, crane_west_x + crane_span - 1.6)
		2:
			_hook_y = clampf(value, yard_y + 0.5, _travel_y() + 0.2)


func _place_crane() -> void:
	if _gantry == null:
		return
	_gantry.position = Vector3(crane_west_x, yard_y, _crane_z)
	_trolley.position.x = _crane_x - crane_west_x
	# Haken hängt am Seil; die Pendelbewegung klingt langsam ab
	var dt := get_process_delta_time()
	_sway_vel += -_sway * 5.0 * dt
	_sway_vel *= exp(-1.6 * dt)
	_sway += _sway_vel * dt
	_sway = _sway.limit_length(0.12)
	_pivot.rotation = Vector3(_sway.y, 0.0, -_sway.x)
	var top := _trolley.global_position.y + _pivot.position.y
	var length := maxf(top - _hook_y, 0.3)
	_hook.position = Vector3(0, -length, 0)
	_rope.scale = Vector3(1.0, length, 1.0)
	_rope.position = Vector3(0, -length * 0.5, 0)
	for jaw in _jaws:
		jaw.rotation.z = -lerpf(0.05, 0.75, _grab_open) * signf(jaw.scale.x)


func _update_sound() -> void:
	var moving := _vel.length() > 0.05
	if moving and not _motor.playing:
		SoundLibrary.play(_motor)
	elif not moving and _motor.playing:
		_motor.stop()
	if _motor.playing:
		_motor.pitch_scale = 0.8 + clampf(_vel.length() / 2.5, 0.0, 1.0) * 0.4


## Staubige Steinchen fallen aus dem Greifer in die Box.
func _pour_stones(at: Vector3) -> void:
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.DOWN
	process.spread = 18.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.5
	process.gravity = Vector3(0, -9.0, 0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.4, 0.1, 0.4)
	particles.process_material = process
	var rock := BoxMesh.new()
	rock.size = Vector3(0.12, 0.1, 0.12)
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = TrainMeshes.GRAVEL
	rock.material = rock_material
	particles.draw_pass_1 = rock
	particles.amount = 40
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.3
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	var pour := _make_player("gravel", -8.0, 40.0, particles)
	SoundLibrary.play(pour)
	get_tree().create_timer(2.5, false).timeout.connect(particles.queue_free)


# --- Leben auf dem Hof ------------------------------------------------------------------------

## Gabelstapler pendelt auf der Rampe, solange gearbeitet wird.
## Die Gabel zeigt bei Drehung 0 nach -Z, bei PI nach +Z (Richtung Schuppenkisten).
func _drive_forklift(working: bool) -> void:
	if _forklift_tween and _forklift_tween.is_valid():
		_forklift_tween.kill()
	if not is_inside_tree():
		return
	var y := _forklift.position.y
	var home := Vector3(25.5, y, -9.0)
	var dock := Vector3(25.5, y, -2.6)
	_forklift_tween = create_tween()
	if not working:
		# Zurück an den Stammplatz, Gabel runter
		_forklift_tween.tween_property(_forks, "position:y", 0.0, 0.8)
		_forklift_tween.tween_property(_forklift, "position", home, 4.0).set_trans(Tween.TRANS_SINE)
		_forklift_tween.tween_property(_forklift, "rotation:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
		return
	_forklift_tween.set_loops()
	_forklift_tween.tween_property(_forklift, "rotation:y", PI, 1.6).set_trans(Tween.TRANS_SINE)
	_forklift_tween.tween_property(_forks, "position:y", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	_forklift_tween.tween_property(_forklift, "position", dock, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_forklift_tween.tween_property(_forks, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	_forklift_tween.tween_interval(1.5)
	_forklift_tween.tween_property(_forks, "position:y", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	_forklift_tween.tween_property(_forklift, "position", home, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_forklift_tween.tween_property(_forklift, "rotation:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	_forklift_tween.tween_property(_forks, "position:y", 0.0, 0.8)
	_forklift_tween.tween_interval(2.5)


func _animate_jib(_delta: float) -> void:
	if _jib_arm:
		var arm := _jib_arm.get_child(_jib_arm.get_child_count() - 1) as Node3D
		arm.rotation.y = sin(_time * 0.13) * 0.6 + 0.4


## Ein Vogel, der auf [param at] sitzt (auf einem Wagen: [param car] ist sein Halt).
func _spawn_bird(at: Vector3, car: TrainCar) -> void:
	var bird := MeshInstance3D.new()
	bird.mesh = FreightMeshes.bird(_rng.randi() % 3)
	bird.material_override = material
	bird.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bird.rotation.y = _rng.randf() * TAU
	bird.scale = Vector3.ONE * 1.6
	if car:
		car.add_child(bird)
		bird.global_position = at
	else:
		add_child(bird)
		bird.position = at
	_birds.append({"node": bird, "hop": _rng.randf_range(1.0, 4.0), "fly": -1.0, "dir": Vector3.ZERO, "car": car})


## Auf jedem zweiten Wagen landen ein paar Vögel (auf Rungen, Containern, Bordwänden).
func _spawn_wagon_birds(train: Train) -> void:
	for car in train.cars:
		if not car.has_cargo_slots() or _rng.randf() < 0.45:
			continue
		var count := _rng.randi_range(1, 2)
		for i in count:
			var local := Vector3(_rng.randf_range(-1.1, 1.1), 0.0, _rng.randf_range(-car.length * 0.4, car.length * 0.4))
			var top := _perch_height(car, local)
			_spawn_bird(car.global_transform * Vector3(local.x, top, local.z), car)


func _perch_height(car: TrainCar, local: Vector3) -> float:
	match car.kind:
		"wagon_container":
			return 3.86
		"wagon_timber":
			return 2.95
		"wagon_stake":
			return 2.5
		"wagon_flat":
			local.x = signf(local.x) * 1.25
			return 1.72
		"wagon_hopper":
			return 3.37
	return 2.0


func _update_birds(delta: float) -> void:
	var hook := _hook.global_position if _hook else Vector3.INF
	for i in range(_birds.size() - 1, -1, -1):
		var bird: Dictionary = _birds[i]
		# Erst prüfen, dann typisiert zuweisen (ein gelöschter Vogel darf keine Variable füllen)
		if not is_instance_valid(bird["node"]):
			_birds.remove_at(i)
			continue
		var node: Node3D = bird["node"]
		if float(bird["fly"]) >= 0.0:
			bird["fly"] = float(bird["fly"]) + delta
			var t: float = bird["fly"]
			node.global_position += (bird["dir"] as Vector3) * delta * (2.5 + t * 3.0) + Vector3.UP * delta * (2.0 + t)
			node.scale = Vector3.ONE * 1.6 * clampf(1.0 - (t - 2.0) / 1.5, 0.0, 1.0)
			if t > 3.5:
				node.queue_free()
				_birds.remove_at(i)
			continue
		# Scheu: fliegt auf, wenn der Kran näher als 4 m kommt oder der Zug fährt
		var car = bird["car"]
		var startled := hook != Vector3.INF and node.global_position.distance_to(hook) < 4.5
		if car != null and (not is_instance_valid(car) or get_current_train() == null):
			startled = true
		if startled:
			_take_off(bird)
			continue
		bird["hop"] = float(bird["hop"]) - delta
		if float(bird["hop"]) <= 0.0:
			bird["hop"] = _rng.randf_range(1.5, 5.0)
			var tween := node.create_tween()
			var yaw := node.rotation.y + _rng.randf_range(-1.2, 1.2)
			tween.tween_property(node, "rotation:y", yaw, 0.15)
			tween.tween_property(node, "position:y", node.position.y + 0.08, 0.08)
			tween.tween_property(node, "position:y", node.position.y, 0.08)


func _take_off(bird: Dictionary) -> void:
	var node: Node3D = bird["node"]
	var world := node.global_transform
	if node.get_parent() != self:
		node.get_parent().remove_child(node)
		add_child(node)
		node.global_transform = world
	var angle := _rng.randf() * TAU
	bird["dir"] = Vector3(cos(angle), 0.0, sin(angle))
	bird["fly"] = 0.0
	bird["car"] = null
	node.rotation.y = -angle - PI * 0.5


# --- Licht -----------------------------------------------------------------------------------

func _on_darkness_changed(dark: bool) -> void:
	_dark = dark
	_apply_light(dark, false)


func _apply_light(dark: bool, instant: bool) -> void:
	var energy := 1.7 if dark else 0.12
	if instant or not is_inside_tree():
		_glow.emission_energy_multiplier = energy
		for light in _lights:
			light.visible = dark
			light.light_energy = float(light.get_meta(&"energy")) if dark else 0.0
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_glow, "emission_energy_multiplier", energy, 3.0)
	for light in _lights:
		if dark:
			light.visible = true
		tween.tween_property(light, "light_energy", float(light.get_meta(&"energy")) if dark else 0.0, 2.5 + randf())
	if not dark:
		tween.chain().tween_callback(func() -> void:
			for light in _lights:
				if is_instance_valid(light):
					light.visible = false)


func get_light_count() -> int:
	return _lights.size()


# --- Speichern ---------------------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"empty_pallets": _empty_pallet_stacks, "empty_containers": _empty_containers,
		"consumed": _consumed.duplicate(), "deliveries": _deliveries.duplicate(true)}


func load_state(data: Dictionary) -> void:
	_empty_pallet_stacks = int(data.get("empty_pallets", 0))
	_empty_containers = int(data.get("empty_containers", 0))
	var consumed: Dictionary = data.get("consumed", {})
	_consumed = {"brick": int(consumed.get("brick", 0)), "glass": int(consumed.get("glass", 0))}
	_deliveries.clear()
	for entry: Variant in data.get("deliveries", []):
		if entry is Dictionary:
			_deliveries.append(entry)
	# Laufende Arbeiten gehören zu Zügen, die nicht gespeichert werden
	if _carried:
		_carried.queue_free()
		_carried = null
	if _carried_scoop:
		_carried_scoop.visible = false
	_job = {}
	_jobs.clear()
	_train = null
	for goods in Economy.get_goods():
		_last_stock[goods.id] = Economy.get_stock(goods.id)
		if _built:
			_refresh_storage(goods.id, false)
	if _built:
		_refresh_empties(false)


func _exit_tree() -> void:
	FreightMeshes.clear_cache()
