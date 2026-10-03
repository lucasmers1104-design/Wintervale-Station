## Rendert Figuren wie die freigegebenen Charakterblätter (vorne, links, hinten,
## rechts) und legt das Ergebnis unter die Vorlage aus docs/character_references/.
##
## Start (nicht headless – es wird gerendert):
##   godot --path . --resolution 1448x1086 -s res://tests/qa/character_sheet.gd -- <ordner> <name> [name …]
## <name> = Dateiname ohne Endung in assets/characters/designs/ und docs/character_references/.
## Ausgabe: <name>_render.png (1448×1086) und <name>_compare.png (Vorlage oben, Spiel unten).
extends SceneTree

const SIZE := Vector2i(1448, 1086)
## Pixel je Meter in den Vorlagen (700 px ≙ 1,45 m) und Fußlinie.
const PX_PER_M := 483.0
const FEET_Y := 866.0
const COLUMNS := [210.0, 565.0, 915.0, 1265.0]
## Blickrichtung je Spalte: vorne, nach links, hinten, nach rechts.
const YAWS := [0.0, -PI * 0.5, PI, PI * 0.5]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(SIZE)
	var stage := _build_stage()
	root.add_child(stage)
	for i in range(1, args.size()):
		await _capture(stage, args[i], out)
	quit()


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("ece1d8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.95, 0.9)
	environment.ambient_light_energy = 0.38
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = 0.7
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	stage.add_child(key)
	key.look_at_from_position(Vector3(2.0, 3.0, -4.0), Vector3.ZERO, Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.95, 0.9, 1.0)
	fill.light_energy = 0.2
	stage.add_child(fill)
	fill.look_at_from_position(Vector3(-3.0, 1.0, 2.0), Vector3.ZERO, Vector3.UP)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SIZE.y / PX_PER_M
	stage.add_child(camera)
	# Bildmitte in Metern über dem Boden; leichter Blick von oben wie in den Vorlagen
	var center_y := (FEET_Y - SIZE.y * 0.5) / PX_PER_M
	camera.position = Vector3(0, center_y + 0.35, -10.0)
	camera.rotation = Vector3(-0.035, PI, 0)
	camera.make_current()
	return stage


func _capture(stage: Node3D, design: String, out: String) -> void:
	var look: CharacterAppearance = load("res://assets/characters/designs/%s.tres" % design)
	var models: Array[CharacterModel] = []
	for i in 4:
		var model := CharacterModel.new()
		model.appearance = look
		stage.add_child(model)
		# Spalte: Bild-x → Welt-x (Kamera schaut nach +Z, Bild rechts = Welt −X)
		model.position = Vector3(-(COLUMNS[i] - SIZE.x * 0.5) / PX_PER_M, 0.0, 0.0)
		model.rotation.y = YAWS[i]
		model.set("_glance_timer", 9999.0)
		model.set("_blink_timer", 9999.0)
		models.append(model)
	for i in 30:
		await process_frame
	var render := root.get_viewport().get_texture().get_image()
	render.save_png(out + design + "_render.png")
	var reference_path := ProjectSettings.globalize_path("res://docs/character_references/%s.png" % design)
	var compare := Image.create(SIZE.x, SIZE.y * 2, false, Image.FORMAT_RGBA8)
	if FileAccess.file_exists(reference_path):
		var reference := Image.load_from_file(reference_path)
		reference.convert(Image.FORMAT_RGBA8)
		reference.resize(SIZE.x, SIZE.y)
		compare.blit_rect(reference, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	render.convert(Image.FORMAT_RGBA8)
	compare.blit_rect(render, Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y))
	compare.resize(SIZE.x / 2, SIZE.y, Image.INTERPOLATE_BILINEAR)
	compare.save_png(out + design + "_compare.png")
	print(design, ": rendered")
	for model in models:
		model.queue_free()
	await process_frame
