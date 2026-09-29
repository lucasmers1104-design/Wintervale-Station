## Fußabdrücke im Schnee: Spielfigur und Bewohner hinterlassen abwechselnd
## linke und rechte Abdrücke, die langsam wieder verwehen (sie werden flacher
## und verschwinden). Nur wo Schnee liegt – auf Wegen, Bahnsteig und in den
## warmen Jahreszeiten nicht.
##
## Ein MultiMesh als Ringpuffer: beliebig viele Schritte, ein Zeichenaufruf.
class_name Footprints
extends MultiMeshInstance3D

const GROUP := &"footprints"

@export var capacity := 360
## So lange (Sekunden bei ×1) bleibt ein Abdruck sichtbar.
@export var lifetime := 80.0
@export var print_material: Material = preload("res://assets/materials/nature_vertex_color.tres")

var _born := PackedFloat32Array()
var _transforms: Array[Transform3D] = []
var _next := 0
var _time := 0.0
var _update_timer := 0.0
var _last := {}


func _ready() -> void:
	add_to_group(GROUP)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _print_mesh()
	mm.instance_count = capacity
	mm.visible_instance_count = capacity
	multimesh = mm
	material_override = print_material
	_born.resize(capacity)
	_transforms.resize(capacity)
	for i in capacity:
		_born[i] = -1000.0
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -100, 0)))


## Ein Schritt von [param walker] (Node, z.B. der FootstepPlayer) an [param position].
func add_step(walker: Node, position: Vector3) -> void:
	if Seasons.get_snow_cover() < 0.4:
		return
	var id := walker.get_instance_id()
	var entry: Dictionary = _last.get(id, {"pos": position, "left": false})
	var direction := position - (entry["pos"] as Vector3)
	direction.y = 0.0
	if direction.length() < 0.15:
		direction = Vector3.FORWARD if not entry.has("dir") else entry["dir"]
	direction = direction.normalized()
	var left := not bool(entry["left"])
	_last[id] = {"pos": position, "left": left, "dir": direction}
	var side := direction.cross(Vector3.UP).normalized() * (0.1 if left else -0.1)
	var basis := Basis.looking_at(direction, Vector3.UP)
	var xform := Transform3D(basis, position + side + Vector3(0, 0.02, 0))
	_transforms[_next] = xform
	_born[_next] = _time
	multimesh.set_instance_transform(_next, xform)
	_next = (_next + 1) % capacity


func get_active_count() -> int:
	var count := 0
	for born in _born:
		if _time - born < lifetime:
			count += 1
	return count


func _process(delta: float) -> void:
	_time += delta * minf(WorldClock.time_scale, 10.0) * (1.0 if not WorldClock.paused else 0.0)
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = 0.5
	# Abdrücke werden mit der Zeit flacher und kleiner (Schnee weht darüber)
	var snow_factor := smoothstep(0.35, 0.6, Seasons.get_snow_cover())
	for i in capacity:
		var age := (_time - _born[i]) / lifetime
		if age > 1.2:
			continue
		var fade := clampf(1.0 - smoothstep(0.55, 1.0, age), 0.0, 1.0) * snow_factor
		var xform := _transforms[i]
		multimesh.set_instance_transform(i, Transform3D(xform.basis.scaled_local(Vector3(fade, 1.0, fade)), xform.origin))


## Abdruck: flacher, etwas dunklerer Schnee (Ballen und Ferse).
static func _print_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(0.7, 0.75, 0.84)
	for part: Array in [[Vector3(0, 0, -0.06), 0.055, 0.075], [Vector3(0, 0, 0.08), 0.045, 0.05]]:
		var center: Vector3 = part[0]
		var rx: float = part[1]
		var rz: float = part[2]
		var segments := 8
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			LowPolyBuilder.add_triangle_facing(st, center, center + Vector3(cos(a0) * rx, 0, sin(a0) * rz),
				center + Vector3(cos(a1) * rx, 0, sin(a1) * rz), color, Vector3.UP)
	return st.commit()
