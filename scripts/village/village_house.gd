## Ein gebautes Wohnhaus. Ersetzt den Platzhalter [NpcHome] (gleiche
## Schnittstelle): Bewohner finden es über [member home_name], treten an der
## Haustür heraus und verschwinden hinter ihr. Dazu: Kollision, Grundfläche,
## warm leuchtende Fenster und Türlampe bei Nacht, Rauch aus dem Schornstein.
class_name VillageHouse
extends NpcHome

var object_id := 0
var item_id := "house_cottage"
var variant := 0
var angle := 0.0
## Startwert für die Bewohner dieses Hauses (gleicher Wert = gleiche Bewohner).
var resident_seed := 0

var _parts := {}
var _footprint := {}
var _door := Vector3(0, 0, -3)
var _glow_tween: Tween


## Vor dem Einfügen in den Baum aufrufen.
func configure(data: Dictionary, body_material: Material) -> void:
	object_id = int(data["id"])
	item_id = String(data["item"])
	variant = int(data.get("variant", 0))
	angle = float(data.get("rot", 0.0))
	resident_seed = int(data.get("seed", object_id * 7919))
	home_name = String(data.get("home", "Haus %d" % object_id))
	material = body_material
	position = SaveUtils.array_to_vec3(data.get("pos"), Vector3.ZERO)
	rotation.y = angle
	_footprint = VillageFootprint.for_item(item_id, position, angle, variant)
	name = "%s_%d" % [item_id, object_id]


func get_data() -> Dictionary:
	return {"id": object_id, "item": item_id, "pos": SaveUtils.vec3_to_array(position), "rot": angle,
		"variant": variant, "seed": resident_seed, "home": home_name}


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


func _on_darkness_changed(dark: bool) -> void:
	if _parts.is_empty():
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
