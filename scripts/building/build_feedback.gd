## Short, bounded placement feedback. Effects never move the committed geometry.
class_name BuildFeedback
extends Node3D

signal placed(kind: String, point: Vector3)
const GOLD := Color(0.95,0.76,0.37)
const GREEN := Color(0.47,0.78,0.59)
var _last_snap := Vector3.INF
var _snap_cooldown := 0.0
var _effects: Array[Node3D] = []
var _audio: AudioStreamPlayer
var _sounds := {}

func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -15
	add_child(_audio)
	SoundLibrary.stop_on_exit(_audio)
	set_process(false)

func snapped(point: Vector3, connected: bool) -> void:
	if not connected:
		_last_snap = Vector3.INF
		return
	if point.distance_to(_last_snap)<0.15:
		return
	_last_snap = point
	if Time.get_ticks_msec()/1000.0 < _snap_cooldown:
		return
	_snap_cooldown = Time.get_ticks_msec()/1000.0+0.12
	_ring(point+Vector3.UP*0.15,0.65,GOLD,0.30)
	_play("snap")

func reject(point: Vector3, reason: String) -> void:
	if not point.is_finite():
		return
	_ring(point+Vector3.UP*0.16,0.65,Color(0.87,0.43,0.32),0.35)
	_play("deny")
	if reason!="":
		Events.notification_requested.emit(reason)

func confirm(kind: String, point: Vector3, points := PackedVector3Array(), caption := "") -> void:
	placed.emit(kind,point)
	_play("rail" if kind=="rail" else "place")
	_last_snap = Vector3.INF
	_ring(point+Vector3.UP*0.14,1.0 if kind in ["rail","path"] else 2.4,GREEN,0.65)
	if points.size()>1 and not GameSettings.get_pref("reduced_motion"):
		_trace(points)
	if caption!="":
		var label := Label3D.new()
		label.text = "✓ "+caption
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.font_size = 48
		label.pixel_size = 0.0014
		label.modulate = Color(1,0.94,0.73)
		label.outline_size = 4
		label.position = point+Vector3.UP*2.5
		add_child(label)
		_track(label)
		var tween := label.create_tween().set_parallel()
		if not GameSettings.get_pref("reduced_motion"):
			tween.tween_property(label,"position:y",label.position.y+0.9,0.85).set_trans(Tween.TRANS_SINE)
		tween.tween_property(label,"modulate:a",0.0,0.40).set_delay(0.55)
		tween.chain().tween_callback(label.queue_free)

func _track(effect: Node3D) -> void:
	for i in range(_effects.size()-1,-1,-1):
		if not is_instance_valid(_effects[i]):
			_effects.remove_at(i)
	while _effects.size()>=12:
		var oldest: Node3D = _effects.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_effects.append(effect)

func _ring(at: Vector3, radius: float, tint: Color, duration: float) -> void:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius*0.82
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 4
	node.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = tint
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	add_child(node)
	_track(node)
	var tween := node.create_tween().set_parallel()
	if not GameSettings.get_pref("reduced_motion"):
		tween.tween_property(node,"scale",Vector3(1.9,0.55,1.9),duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,duration)
	tween.chain().tween_callback(node.queue_free)

func _trace(points: PackedVector3Array) -> void:
	var node := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	var bead := SphereMesh.new()
	bead.radius = 0.11
	bead.height = 0.22
	bead.radial_segments = 6
	bead.rings = 3
	batch.mesh = bead
	batch.instance_count = mini(48,points.size())
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.multimesh = batch
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_track(node)
	var animate := func(t: float) -> void:
		for i in batch.instance_count:
			var fraction := float(i)/maxi(1,batch.instance_count-1)
			var p := points[roundi(fraction*(points.size()-1))]
			var age := clampf((t-fraction*0.3)/0.7,0,1)
			batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.7+sin(age*PI)*0.8)),p+Vector3.UP*(0.18+sin(age*PI)*0.5)))
			batch.set_instance_color(i,Color(GOLD,sin(age*PI)*0.9))
	animate.call(0.0)
	var tween := node.create_tween()
	tween.tween_method(animate,0.0,1.0,0.8)
	tween.tween_callback(node.queue_free)

func _play(id: String) -> void:
	if not SoundLibrary.audible:
		return
	if not _sounds.has(id):
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var bytes := PackedByteArray()
		var samples := int(22050*0.16)
		bytes.resize(samples*2)
		var frequency: float = {"snap":740.0,"place":330.0,"rail":230.0,"deny":160.0}[id]
		for i in samples:
			var t := float(i)/22050
			var envelope := (1.0-exp(-t*900))*exp(-t*35)
			var value := (sin(TAU*frequency*t)+sin(TAU*frequency*1.51*t)*0.28)*envelope*0.34
			bytes.encode_s16(i*2,roundi(value*32767))
		wav.data = bytes
		_sounds[id] = wav
	_audio.stream = _sounds[id]
	SoundLibrary.play(_audio)
