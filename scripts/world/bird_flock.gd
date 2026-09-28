## Vögel im Hintergrund: kleine Schwärme, die tagsüber gemächlich über den
## Bergen kreisen. Rein zur Atmosphäre – sehr sparsam (ein paar Dreiecke).
## Nachts, bei dichtem Schneefall und im schnellen Zeitraffer sind sie weg.
class_name BirdFlock
extends Node3D

@export var flocks := 2
@export var birds_per_flock := 6
## Abstand der Kreisbahnen vom Kartenmittelpunkt.
@export var orbit_distance := 95.0

var _birds: Array[Dictionary] = []
var _time := 0.0
var _visibility := 1.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.19, 0.22)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wing := _wing_mesh()
	for f in flocks:
		var center_angle := rng.randf() * TAU
		var center := Vector3(cos(center_angle), 0.0, sin(center_angle)) * orbit_distance + Vector3(0, rng.randf_range(34.0, 46.0), 0)
		var radius := rng.randf_range(16.0, 26.0)
		var speed := rng.randf_range(0.07, 0.11) * (1.0 if f % 2 == 0 else -1.0)
		for i in birds_per_flock:
			var bird := Node3D.new()
			add_child(bird)
			var wings: Array[MeshInstance3D] = []
			for side: float in [-1.0, 1.0]:
				var mesh := MeshInstance3D.new()
				mesh.mesh = wing
				mesh.material_override = material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mesh.scale = Vector3(side, 1.0, 1.0)
				bird.add_child(mesh)
				wings.append(mesh)
			_birds.append({"node": bird, "wings": wings, "center": center, "radius": radius + rng.randf_range(-4.0, 4.0),
				"speed": speed, "phase": rng.randf() * TAU * 0.25 + i * 0.12, "height": rng.randf_range(-2.0, 2.0),
				"flap": rng.randf_range(5.0, 7.0), "offset": rng.randf() * TAU})


func _process(delta: float) -> void:
	_time += delta * minf(WorldClock.time_scale, 3.0)
	var hour := WorldClock.time_of_day
	var target := 1.0 if hour > 7.3 and hour < 16.8 and WorldClock.time_scale <= 10.0 else 0.0
	_visibility = move_toward(_visibility, target, delta * 0.3)
	visible = _visibility > 0.01
	if not visible:
		return
	for bird: Dictionary in _birds:
		var angle := float(bird["phase"]) + _time * float(bird["speed"])
		var center: Vector3 = bird["center"]
		var radius := float(bird["radius"])
		var pos := center + Vector3(cos(angle) * radius, float(bird["height"]) + sin(_time * 0.3 + angle) * 1.5,
			sin(angle) * radius)
		var tangent := Vector3(-sin(angle), 0.0, cos(angle)) * signf(float(bird["speed"]))
		var node: Node3D = bird["node"]
		node.global_transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), pos)
		node.scale = Vector3.ONE * (0.6 + 0.4 * _visibility)
		# Flügelschlag mit Gleitphasen
		var glide := 0.5 + 0.5 * sin(_time * 0.4 + float(bird["offset"]))
		var flap := sin(_time * float(bird["flap"]) + float(bird["offset"])) * (0.6 * (1.0 - glide) + 0.1)
		for mesh: MeshInstance3D in bird["wings"]:
			mesh.rotation.z = flap * signf(mesh.scale.x)


static func _wing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(0.2, 0.19, 0.22)
	LowPolyBuilder.add_triangle_facing(st, Vector3(0, 0, -0.25), Vector3(0.9, 0.05, 0.1), Vector3(0, 0, 0.25), color, Vector3.UP)
	LowPolyBuilder.add_triangle_facing(st, Vector3(0, 0, -0.25), Vector3(0.9, 0.05, 0.1), Vector3(0, 0, 0.25), color, Vector3.DOWN)
	return st.commit()
