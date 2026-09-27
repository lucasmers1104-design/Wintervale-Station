@tool
## Ein Bahnhofsdetail, komplett per Code erzeugt (auch im Editor sichtbar).
##
## Art über [member kind] wählen. Bänke legen ihre Sitzplätze
## ([StationSpot], Art SEAT) selbst an – die Bewohner finden sie automatisch.
## -Z ist die Vorderseite (bei Bänken: Blickrichtung der Sitzenden).
class_name StationProp
extends StaticBody3D

enum Kind { BENCH, BIN, FLOWER_BOX, SIGNPOST, TIMETABLE, CROSSING, LUGGAGE, BICYCLE, SNOW_BANK, SEATING_GROUP }

## Diese Details richten sich nach dem Gleisbau auf die Gleishöhe aus (siehe main.gd).
const RAIL_ALIGNED_GROUP := &"rail_aligned"

@export var kind := Kind.BENCH:
	set(value):
		kind = value
		if is_node_ready():
			rebuild()
@export var material: Material
@export var variation_seed := 1
## Blumenkasten und Schneebank: Länge in Metern.
@export var box_length := 1.2
## Wegweiser: je Schild "Text|Winkel in Grad" (0° = Pfeil nach +X, 90° = nach -Z).
@export var arrows: PackedStringArray = ["Wintervale|0"]
## Aushangfahrplan: dieser Fahrplan wird für [member station_name] angeschlagen.
@export var timetable: Timetable
@export var station_name := "Wintervale"

@export_tool_button("Neu erzeugen", "Reload")
var rebuild_action: Callable = rebuild


func _ready() -> void:
	collision_mask = 0
	if kind == Kind.CROSSING:
		add_to_group(RAIL_ALIGNED_GROUP)
	add_to_group(PropScatter.GROUP_CLEARING)
	rebuild()


## Bohlenübergang: exakt auf die Höhe des Gleises darunter setzen.
func align_to_track(network: RailNetwork) -> void:
	if kind != Kind.CROSSING:
		return
	var segment := network.find_segment_near(global_position, 3.0)
	if segment:
		global_position.y = segment.closest_point(global_position).y


## Sitzplätze dieser Bank (leer bei anderen Arten).
func get_seats() -> Array[StationSpot]:
	var seats: Array[StationSpot] = []
	for child in get_children():
		if child is StationSpot:
			seats.append(child)
	return seats


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Der Bohlenübergang gehört zum Boden (begehbar, blockiert aber keinen Gleisbau darüber hinaus).
	collision_layer = GameDefs.LAYER_WORLD if kind == Kind.CROSSING else GameDefs.LAYER_OBJECTS
	match kind:
		Kind.BENCH:
			StationPropMeshes.add_bench(st, rng)
			_add_box_collision(Vector3(1.7, 0.9, 0.5), Vector3(0.0, 0.45, 0.03))
			for x in StationPropMeshes.BENCH_SEATS:
				var seat := StationSpot.new()
				seat.name = "Seat%d" % (0 if x < 0.0 else 1)
				seat.kind = StationSpot.Kind.SEAT
				seat.station_name = station_name
				seat.position = Vector3(x, StationPropMeshes.BENCH_SEAT_HEIGHT, -0.02)
				_add_generated(seat)
		Kind.BIN:
			StationPropMeshes.add_bin(st)
			_add_box_collision(Vector3(0.5, 0.9, 0.5), Vector3(0.0, 0.45, 0.0))
		Kind.FLOWER_BOX:
			StationPropMeshes.add_flower_box(st, rng, box_length)
			_add_box_collision(Vector3(box_length, 0.45, 0.45), Vector3(0.0, 0.22, 0.0))
		Kind.SIGNPOST:
			_build_signpost(st)
			_add_box_collision(Vector3(0.2, 2.2, 0.2), Vector3(0.0, 1.1, 0.0))
		Kind.TIMETABLE:
			var poster := StationPropMeshes.add_timetable_case(st)
			_add_poster_text(poster)
			_add_box_collision(Vector3(1.1, 1.9, 0.2), Vector3(0.0, 0.95, 0.0))
		Kind.LUGGAGE:
			StationPropMeshes.add_luggage(st, rng)
			_add_box_collision(Vector3(1.1, 0.45, 0.7), Vector3(0.0, 0.22, 0.1))
		Kind.BICYCLE:
			StationPropMeshes.add_bicycle(st, rng)
			_add_box_collision(Vector3(1.6, 1.0, 0.4), Vector3(0.0, 0.5, 0.0))
		Kind.SNOW_BANK:
			StationPropMeshes.add_snow_bank(st, rng, box_length)
		Kind.SEATING_GROUP:
			var seats := StationPropMeshes.add_seating_group(st, rng)
			for side: float in [-1.0, 1.0]:
				_add_box_collision(Vector3(1.7, 0.9, 0.5), Vector3(0.0, 0.45, side * 0.98))
			_add_box_collision(Vector3(0.6, 0.65, 0.6), Vector3(0.0, 0.33, 0.0))
			for i in seats.size():
				var seat := StationSpot.new()
				seat.name = "Seat%d" % i
				seat.kind = StationSpot.Kind.SEAT
				seat.station_name = station_name
				seat.transform = seats[i]
				_add_generated(seat)
		Kind.CROSSING:
			StationPropMeshes.add_crossing(st, rng)
			var top := RailConfig.RAIL_BASE + RailConfig.RAIL_HEIGHT
			_add_box_collision(Vector3(3.8, 0.1, 1.8), Vector3(0.0, top - 0.06, 0.0))
			for side: float in [-1.0, 1.0]:
				var ramp := StationPropMeshes.crossing_ramp(side)
				_add_box_collision(Vector3(StationPropMeshes.CROSSING_RAMP_LENGTH, 0.08, 1.8), ramp.origin, ramp.basis)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = material
	# Kleine Details aus großer Entfernung nicht mehr zeichnen (Leistung)
	if kind in [Kind.LUGGAGE, Kind.BICYCLE, Kind.FLOWER_BOX, Kind.BIN, Kind.SNOW_BANK]:
		mesh_instance.visibility_range_end = 110.0
		mesh_instance.visibility_range_end_margin = 10.0
	_add_generated(mesh_instance)


func _build_signpost(st: SurfaceTool) -> void:
	var specs: Array = []
	for i in arrows.size():
		var parts := arrows[i].split("|")
		var angle := parts[1].to_float() if parts.size() > 1 else 0.0
		var width := clampf(parts[0].length() * 0.075 + 0.22, 0.6, 1.4)
		specs.append([angle, 1.95 - i * 0.32, width])
	var boards := StationPropMeshes.add_signpost(st, specs)
	for i in boards.size():
		var text := arrows[i].split("|")[0]
		for face: float in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = text
			label.font_size = 44
			label.pixel_size = 0.0032
			label.modulate = Color(0.25, 0.16, 0.1)
			label.outline_size = 0
			label.double_sided = false
			var xform := boards[i].translated_local(Vector3(-0.02, -0.005, face * 0.021))
			if face < 0.0:
				xform.basis = xform.basis.rotated(xform.basis.y.normalized(), PI)
			label.transform = xform
			_add_generated(label)


## Schlägt die Abfahrten des Fahrplans auf dem gelben Plakat an.
func _add_poster_text(center: Vector3) -> void:
	var title := Label3D.new()
	title.text = "Abfahrt · %s" % station_name
	title.font_size = 32
	title.pixel_size = 0.0028
	title.modulate = Color(0.12, 0.1, 0.1)
	title.outline_size = 0
	title.double_sided = false
	title.rotation.y = PI
	title.position = center + Vector3(0.0, 0.42, 0.0)
	_add_generated(title)
	var lines := PackedStringArray()
	if timetable:
		var rows: Array[TimetableEntry] = []
		for entry in timetable.entries:
			if entry and entry.stops and entry.station == station_name:
				rows.append(entry)
		rows.sort_custom(func(a: TimetableEntry, b: TimetableEntry) -> bool:
			return a.get_departure_hours() < b.get_departure_hours())
		for entry in rows:
			lines.append("%s  %-7s %-8s Gl. %d" % [entry.departure, entry.train_number, entry.destination, entry.platform])
	var body := Label3D.new()
	body.text = "\n".join(lines)
	body.font_size = 22
	body.pixel_size = 0.0021
	body.line_spacing = -4.0
	body.modulate = Color(0.16, 0.12, 0.1)
	body.outline_size = 0
	body.double_sided = false
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.rotation.y = PI
	body.position = center + Vector3(0.38, 0.34, 0.0)
	_add_generated(body)


func _add_box_collision(size: Vector3, center: Vector3, basis := Basis.IDENTITY) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(basis, center)
	_add_generated(shape)


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)


## Keine Bäume in und direkt um das Detail (Bahnsteig-Details sind ohnehin gerodet).
func clears(x: float, z: float) -> bool:
	var radius := {Kind.SEATING_GROUP: 2.4, Kind.BICYCLE: 1.4, Kind.SNOW_BANK: box_length * 0.5 + 0.4,
		Kind.LUGGAGE: 0.9, Kind.SIGNPOST: 1.0, Kind.FLOWER_BOX: 1.0}.get(kind, 0.8) as float
	return Vector2(x, z).distance_to(Vector2(global_position.x, global_position.z)) < radius
