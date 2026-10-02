## Ein gebautes Wohnhaus. Ersetzt den Platzhalter [NpcHome] (gleiche
## Schnittstelle): Bewohner finden es über [member home_name], treten an der
## Haustür heraus und verschwinden hinter ihr. Dazu: Kollision, Grundfläche,
## warm leuchtende Fenster und Türlampe bei Nacht, Rauch aus dem Schornstein.
##
## Neue Häuser entstehen als Baustelle ([member build_progress] < 1): Das Haus
## wächst von unten nach oben (Shader [code]construction_reveal[/code]), dazu
## Bauzaun, Gerüst, Materialstapel, Baukran und Bauarbeiter ([ConstructionSite]).
## Fenster, Lampen und Rauch gibt es erst, wenn es fertig ist.
class_name VillageHouse
extends NpcHome

signal finished(house: VillageHouse)

const REVEAL_SHADER := preload("res://assets/materials/construction_reveal.gdshader")

var object_id := 0
var item_id := "house_cottage"
var variant := 0
var angle := 0.0
## Startwert für die Bewohner dieses Hauses (gleicher Wert = gleiche Bewohner).
var resident_seed := 0
## Baufortschritt 0..1 (1 = fertig, bewohnbar).
var build_progress := 1.0
## Tag, an dem das Haus fertig wurde (für den schrittweisen Zuzug).
var finished_day := 0
var region_station_id := 0
var organic_growth := false

var _parts := {}
var _footprint := {}
var _door := Vector3(0, 0, -3)
var _glow_tween: Tween
var _site: ConstructionSite
var _reveal: ShaderMaterial
var _body_meshes: Array[MeshInstance3D] = []
var _hidden_meshes: Array[MeshInstance3D] = []
var _dark := false


## Vor dem Einfügen in den Baum aufrufen.
func configure(data: Dictionary, body_material: Material) -> void:
	object_id = int(data["id"])
	item_id = String(data["item"])
	variant = int(data.get("variant", 0))
	angle = float(data.get("rot", 0.0))
	resident_seed = int(data.get("seed", object_id * 7919))
	build_progress = clampf(float(data.get("build", 1.0)), 0.0, 1.0)
	finished_day = int(data.get("since", 0))
	region_station_id = int(data.get("region_station",0))
	organic_growth = bool(data.get("organic",region_station_id>0 and not bool(data.get("paid",false))))
	home_name = String(data.get("home", "Haus %d" % object_id))
	material = body_material
	position = SaveUtils.array_to_vec3(data.get("pos"), Vector3.ZERO)
	rotation.y = angle
	_footprint = VillageFootprint.for_item(item_id, position, angle, variant)
	name = "%s_%d" % [item_id, object_id]


func get_data() -> Dictionary:
	var data := {"id": object_id, "item": item_id, "pos": SaveUtils.vec3_to_array(position), "rot": angle,
		"variant": variant, "seed": resident_seed, "home": home_name, "since": finished_day}
	if build_progress < 1.0:
		data["build"] = build_progress
	if region_station_id>0:
		data["region_station"] = region_station_id
		data["organic"] = organic_growth
	return data


func is_finished() -> bool:
	return build_progress >= 1.0


## Bauabschnitt für Notizbuch und Tests.
func get_stage_text() -> String:
	if build_progress >= 1.0:
		return "Fertig"
	if build_progress < 0.08:
		return "Baustelle wird eingerichtet"
	if build_progress < 0.35:
		return "Fundament und Mauern"
	if build_progress < 0.7:
		return "Rohbau"
	if build_progress < 0.85:
		return "Dachstuhl"
	return "Innenausbau"


## Baufortschritt setzen. [param remaining]: noch nicht verbautes Material
## (für die Stapel), [param working]: gerade Arbeitszeit.
func set_build_progress(progress: float, remaining: Dictionary, working: bool) -> void:
	var was_finished := is_finished()
	build_progress = clampf(progress, 0.0, 1.0)
	if _reveal:
		var height := float(_parts["data"]["height"])
		_reveal.set_shader_parameter(&"reveal_height", lerpf(0.15, height + 0.6, clampf((build_progress - 0.04) / 0.8, 0.0, 1.0)))
	if _site:
		_site.set_progress(build_progress, remaining, working)
	if not was_finished and is_finished():
		_complete()


## Das Haus ist fertig: echtes Material, Fenster, Licht, Rauch – Baustelle abbauen.
func _complete() -> void:
	finished_day = WorldClock.day
	for mesh in _body_meshes:
		mesh.material_override = _reveal.get_meta(&"original") if _reveal and _reveal.has_meta(&"original") else material
	_reveal = null
	for mesh in _hidden_meshes:
		mesh.visible = true
	_hidden_meshes.clear()
	for smoke: GPUParticles3D in _parts.get("smoke", []):
		_set_smoke(smoke, true)
	if _site:
		_site.finish()
		_site = null
	if is_inside_tree():
		var chime := AudioStreamPlayer3D.new()
		chime.stream = SoundLibrary.get_sound("done_chime")
		chime.volume_db = -8.0
		chime.max_distance = 70.0
		chime.position = Vector3(0, 3, 0)
		add_child(chime)
		SoundLibrary.stop_on_exit(chime)
		SoundLibrary.play(chime)
		chime.finished.connect(chime.queue_free)
		if not SoundLibrary.audible:
			chime.queue_free()
	_on_darkness_changed(_dark)
	finished.emit(self)


func get_footprint() -> Dictionary:
	return _footprint


func get_capacity() -> int:
	return int(HouseMeshes.CAPACITY.get(VillageCatalog.get_item(item_id).get("house", ""), 2))


func is_solid() -> bool:
	return true


## Vor der Haustür (hier kommen die Bewohner heraus).
func get_front_point() -> Vector3:
	return to_global(Vector3(_door.x, 0.0, _door.z))


## Hinter der Haustür – hier ist der Bewohner "im Haus".
func get_inside_point() -> Vector3:
	var inward := 1.0 if _door.z < 0.0 else -1.0
	return to_global(Vector3(_door.x, 0.0, _door.z + inward * 2.6))


func clears(x: float, z: float) -> bool:
	return VillageFootprint.contains(_footprint, Vector2(x, z), 1.5)


func set_dark(dark: bool) -> void:
	_on_darkness_changed(dark)


func set_highlight(highlight: Material) -> void:
	VillageVisual.set_overlay(_parts, highlight)


func get_light_count() -> int:
	return (_parts.get("lights", []) as Array).size()


func get_window_glow() -> float:
	var windows: ShaderMaterial = _parts.get("windows")
	return float(windows.get_shader_parameter(&"glow")) if windows else 0.0


# --- NpcHome überschreiben --------------------------------------------------------

func _build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var holder := Node3D.new()
	holder.name = "Visual"
	_add_generated(holder)
	_parts = VillageVisual.attach(holder, item_id, variant, 0.0, material)
	_door = _parts["data"]["door"]
	var house_data := HouseMeshes.build(VillageCatalog.get_item(item_id)["house"], variant)
	var size: Vector2 = house_data["size"]
	var offset: Vector2 = house_data["center"]
	var body := StaticBody3D.new()
	body.collision_layer = GameDefs.LAYER_OBJECTS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var height := float(_parts["data"]["height"])
	box.size = Vector3(size.x - 0.8, height * 0.8, size.y - 0.8)
	shape.shape = box
	shape.position = Vector3(offset.x, height * 0.4, offset.y)
	body.add_child(shape)
	_add_generated(body)
	_body_meshes.clear()
	_hidden_meshes.clear()
	if not is_finished():
		_start_construction(house_data)


## Baustelle aufbauen: Hauskörper mit Bau-Shader, Fenster und Lichter aus.
func _start_construction(house_data: Dictionary) -> void:
	var body_material := VillageCatalog.body_material(item_id, material)
	_reveal = ShaderMaterial.new()
	_reveal.shader = REVEAL_SHADER
	_reveal.set_meta(&"original", body_material)
	for mesh: MeshInstance3D in _parts["meshes"]:
		if mesh.material_override == body_material:
			mesh.material_override = _reveal
			_body_meshes.append(mesh)
		else:
			mesh.visible = false
			_hidden_meshes.append(mesh)
	for smoke: GPUParticles3D in _parts.get("smoke", []):
		_set_smoke(smoke, false)
	_site = ConstructionSite.new()
	_site.set_meta(&"generated", true)
	add_child(_site)
	var size: Vector2 = house_data["size"]
	_site.setup(size, house_data["center"], float(house_data["height"]), _door, VillageCatalog.get_cost(item_id),
		material, resident_seed)
	set_build_progress(build_progress, VillageCatalog.get_cost(item_id), false)


func get_site() -> ConstructionSite:
	return _site


func _on_darkness_changed(dark: bool) -> void:
	_dark = dark
	if _parts.is_empty():
		return
	if not is_finished():
		if _site:
			_site.set_dark(dark)
		return
	VillageVisual.set_lit(_parts, dark, self)
	var windows: ShaderMaterial = _parts["windows"]
	if windows:
		if _glow_tween and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween()
		# Nicht alle Häuser gehen gleichzeitig an
		_glow_tween.tween_interval(randf() * 2.0)
		_glow_tween.tween_property(windows, "shader_parameter/glow", 1.0 if dark else 0.0, 3.0)


## Rauch samt Funken an- oder ausschalten.
static func _set_smoke(smoke: GPUParticles3D, on: bool) -> void:
	smoke.emitting = on
	for child in smoke.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = on
