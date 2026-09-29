## Abfahrtstafel am Bahnsteig: dunkelblaue Tafel mit warm leuchtender Schrift,
## beidseitig lesbar (±X). Zeigt die nächsten Abfahrten mit Zeit, Zug, Ziel,
## Gleis und Verspätung. Kündigt einfahrende Züge mit einem Gong an.
class_name DepartureBoard
extends Node3D

const ROWS := 4
const WIDTH := 3.4
const TEXT_COLOR := Color(1.0, 0.92, 0.72)
const DELAY_COLOR := Color(1.0, 0.66, 0.28)

@export var dispatcher: TrainDispatcher
@export var station_name := "Wintervale"
@export var board_height := 2.4

## Pro Seite: Zeilen mit Labels [Zeit, Zug, Ziel, Gleis, Verspätung]
var _rows: Array = []
var _chime: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(TrainDispatcher.BOARD_GROUP)
	_build()
	_chime = AudioStreamPlayer3D.new()
	_chime.stream = SoundLibrary.get_sound("chime")
	_chime.volume_db = -6.0
	_chime.max_distance = 70.0
	_chime.unit_size = 10.0
	_chime.position = Vector3(0.0, board_height, 0.0)
	add_child(_chime)
	SoundLibrary.stop_on_exit(_chime)
	WorldClock.minute_changed.connect(func(_h: int, _m: int) -> void: refresh())
	if dispatcher:
		dispatcher.trains_changed.connect(refresh)
	refresh()


## Aktualisiert die Anzeige.
func refresh() -> void:
	var data: Array[Dictionary] = []
	if dispatcher:
		data = dispatcher.get_departure_rows(station_name, ROWS)
	for face: Array in _rows:
		for i in ROWS:
			var labels: Array = face[i]
			if i < data.size():
				var row := data[i]
				(labels[0] as Label3D).text = row["time"]
				(labels[1] as Label3D).text = row["number"]
				(labels[2] as Label3D).text = row["destination"]
				(labels[3] as Label3D).text = "Gl. %d" % row["platform"]
				(labels[4] as Label3D).text = "+%d" % row["delay"] if int(row["delay"]) > 0 else ""
			else:
				for label: Label3D in labels:
					label.text = ""


## Die aktuell angezeigten Zeilen als Text (für Tests).
func get_row_texts() -> Array[String]:
	var texts: Array[String] = []
	for labels: Array in _rows[0]:
		var parts: Array[String] = []
		for label: Label3D in labels:
			parts.append(label.text)
		texts.append(" ".join(parts).strip_edges())
	return texts


## Gong – ein Zug fährt gleich ein.
func announce(_train: Node) -> void:
	if WorldClock.time_scale <= 2.0:
		SoundLibrary.play(_chime)


func _build() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.14, 0.15, 0.17)
	iron.roughness = 0.5
	var panel := StandardMaterial3D.new()
	panel.albedo_color = Color(0.06, 0.09, 0.18)
	panel.roughness = 0.35
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.55, 0.42, 0.25)
	frame.roughness = 0.6

	for z in [-WIDTH * 0.45, WIDTH * 0.45]:
		_box(Vector3(0.0, board_height * 0.5, z), Vector3(0.1, board_height + 0.6, 0.1), iron)
	_box(Vector3(0.0, board_height, 0.0), Vector3(0.16, 1.4, WIDTH + 0.14), frame)
	_box(Vector3(0.0, board_height, 0.0), Vector3(0.18, 1.3, WIDTH), panel)
	_box(Vector3(0.0, board_height + 0.74, 0.0), Vector3(0.24, 0.06, WIDTH + 0.2), iron)
	_box(Vector3(0.0, board_height + 0.79, 0.0), Vector3(0.2, 0.04, WIDTH + 0.1), _snow_material())

	for side: float in [1.0, -1.0]:
		var face_x: float = side * 0.1
		var left: float = side * (WIDTH * 0.5 - 0.15)
		var along: float = -side
		_label(Vector3(face_x, board_height + 0.47, left), side, "Abfahrt  ·  %s" % station_name, 30, TEXT_COLOR.darkened(0.15))
		var face_rows: Array = []
		for i in ROWS:
			var y := board_height + 0.2 - i * 0.26
			var labels: Array = []
			for column: Array in [[0.0, 36], [0.62, 36], [1.34, 36], [2.46, 32], [2.92, 32]]:
				var color := DELAY_COLOR if column[0] == 2.92 else TEXT_COLOR
				labels.append(_label(Vector3(face_x, y, left + along * float(column[0])), side, "", column[1], color))
			face_rows.append(labels)
		_rows.append(face_rows)


func _label(position_: Vector3, side: float, text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = position_
	label.rotation.y = PI * 0.5 * side
	add_child(label)
	return label


func _box(center: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
	instance.position = center
	add_child(instance)


## Schneekappe auf dem Dach der Anzeige (Schneeauflage: taut mit den Jahreszeiten).
func _snow_material() -> Material:
	return preload("res://assets/materials/snow.tres")
