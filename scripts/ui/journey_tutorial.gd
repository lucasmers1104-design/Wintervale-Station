## Einstieg in eine neue Reise: Ilse, die Bahnhofsvorsteherin, führt in sieben
## Schritten zur ersten fahrenden Linie. Danach bleibt eine kleine Zielkarte
## mit den Bedingungen der nächsten Epoche.
##
## - Karte oben links im Stil des Reisebuchs (JourneyStyle): Schritt, Text,
##   Tastenkappen, Fortschritt als kleines Gleis, Stempel bei Erfolg.
## - Ein goldener Pfeil zeigt auf den passenden Knopf (Werkzeug, Fuhrpark,
##   „Zug einsetzen“), leuchtende Ringe in der Welt auf gute Haltepunkt-Plätze.
## - Der Schritt wird in RegionProgression.tutorial_step gespeichert (-1 = fertig).
##   Die Bedingungen lesen nur den Spielzustand; wer schneller ist, überspringt
##   erledigte Schritte automatisch.
class_name JourneyTutorial
extends CanvasLayer

const S = preload("res://scripts/ui/journey_style.gd")
const CARD_WIDTH := 450.0
const CARD_POS := Vector2(22.0, 26.0)
const RAIL_TARGET := 90.0
const NO_POINTS: Array[Vector3] = []
const STEPS := [
	{"id": "welcome", "title": "Willkommen in Wintervale!", "text": "Ich bin Ilse, die Bahnhofsvorsteherin. Noch fährt hier kein einziger Zug – lass uns gemeinsam die erste Bahnlinie bauen. Es dauert nur ein paar Minuten.", "button": "Los geht's"},
	{"id": "build", "title": "Der Baumodus", "text": "Drück B, um den Baumodus zu öffnen. Unten links erscheinen dann deine Werkzeuge.", "keys": [&"build_mode"]},
	{"id": "rails", "title": "Die erste Strecke", "text": "Wähle „Schiene“. Klick einen Startpunkt, dann das Ende – das Gleis folgt dem Gelände. Zwei gerade Stücke mit je etwa 45 m sind ideal.", "keys": [&"build_tool_rail", &"interact_primary"]},
	{"id": "halts", "title": "Zwei Haltepunkte", "text": "Wähle „Haltepunkt“ und setz zwei Holz-Haltepunkte neben das Gleis – am besten auf die leuchtenden Ringe nahe der Enden.", "keys": [&"build_tool_station", &"interact_primary"], "note": "Falsch gesetzt? „Entfernen“ reißt ihn wieder ab – das Geld kommt zurück."},
	{"id": "train", "title": "Dein erster Zug", "text": "Öffne den Fuhrpark – der alte Dieseltriebwagen wartet schon. Wähl beide Orte und drück „Zug einsetzen“.", "keys": [&"region_overview"]},
	{"id": "ride", "title": "Abfahrt!", "text": "Sieh zu, wie Reisende zum Bahnsteig gehen, einsteigen und losfahren. Klick auf den Zug, um mitzufahren – T lässt die Zeit schneller laufen.", "keys": [&"time_speed", &"interact_primary"]},
	{"id": "grow", "title": "Wintervale wächst", "text": "Jede Fahrt bringt Fahrgäste – und mit ihnen neue Nachbarn. Im Reisebuch siehst du, was die nächste Epoche freischaltet: neue Züge, größere Bahnhöfe, Weichen und Signale.", "button": "Reisebuch öffnen"},
]

var region: RegionRailway
var panel: RegionPanel
var build_mode: BuildMode
var hud: Node

var _canvas: Control
var _card: PanelContainer
var _body: VBoxContainer
var _stamp: TextureRect
var _pointer: TutorialPointer
var _markers: Node3D
var _marker_key := ""
var _shown_step := -99
var _advancing := false
var _timer := 0.0
var _collapsed := false
var _ribbon := false
var _snow: Control
var _progress_bar: JourneyStyle.TrackBar
var _progress_label: Label
var _goal_signature := ""


func _ready() -> void:
	layer = 66
	_canvas = Control.new()
	_canvas.size = S.DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = S.make_theme()
	add_child(_canvas)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var style := S.flat(Color("f6ead0"), S.WOOD, 5, 18, 20.0)
	style.content_margin_top = 22
	style.shadow_color = Color(0.12, 0.06, 0.02, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	_card.add_theme_stylebox_override("panel", style)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_card.add_child(_body)
	# Nicht im PanelContainer: Container würden die Kappe auf Kartengröße ziehen.
	_snow = S.SnowCap.new(31)
	_canvas.add_child(_snow)
	_stamp = S.icon_rect(S.icon("check"), 84)
	_stamp.size = Vector2(84, 84)
	_stamp.pivot_offset = Vector2(42, 42)
	_stamp.visible = false
	_canvas.add_child(_stamp)
	_pointer = TutorialPointer.new()
	add_child(_pointer)
	_markers = Node3D.new()
	_markers.name = "TutorialMarkers"
	region.get_parent().add_child.call_deferred(_markers)
	get_viewport().size_changed.connect(_layout)
	region.progression.changed.connect(_on_progress_changed)
	Events.build_mode_changed.connect(func(_active: bool) -> void: _timer = 0.0)
	Events.build_tool_changed.connect(func(_tool: StringName) -> void: _timer = 0.0)
	Events.game_loaded.connect(func(_slot: String) -> void: _shown_step = -99)
	_show_current()


func _exit_tree() -> void:
	if is_instance_valid(_markers):
		_markers.queue_free()


func _step() -> int:
	return region.progression.tutorial_step


func is_finished() -> bool:
	return _step() < 0 or _step() >= STEPS.size()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_evaluate()
	_update_pointer()
	_update_ribbon()


## Prüft den aktuellen Schritt gegen den Spielzustand.
func _evaluate() -> void:
	if _shown_step != _step():
		_show_current()
	if is_finished() or _advancing:
		_update_markers(NO_POINTS)
		return
	var id := String(STEPS[_step()]["id"])
	if _condition_met(id):
		_complete_step()
		return
	_update_progress(id)
	_update_markers(_halt_suggestions() if id == "halts" else NO_POINTS)


func _condition_met(id: String) -> bool:
	var metrics := region.progression.metrics()
	match id:
		"welcome":
			return region.network.get_segment_count() > 0
		"build":
			return build_mode.active or region.network.get_segment_count() > 0
		"rails":
			return float(metrics["rail_length"]) >= RAIL_TARGET or region.stations.size() >= 2
		"halts":
			return region.stations.size() >= 2
		"train":
			return not region.lines.is_empty()
		"ride":
			return region.progression.passengers > 0 or region.progression.services >= 2
	return false


func _progress_of(id: String) -> Vector2:
	match id:
		"rails":
			return Vector2(float(region.progression.metrics()["rail_length"]), RAIL_TARGET)
		"halts":
			return Vector2(region.stations.size(), 2)
		"ride":
			return Vector2(mini(region.progression.passengers, 1), 1)
	return Vector2(-1, -1)


func _complete_step() -> void:
	if _advancing:
		return
	_advancing = true
	S.play_chime()
	_stamp.visible = true
	_stamp.position = _card.position + Vector2(_card.size.x - 70, -26)
	_stamp.scale = Vector2(2.4, 2.4)
	_stamp.modulate.a = 0.0
	_stamp.rotation = -0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(_stamp, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_stamp, "modulate:a", 1.0, 0.18)
	tween.tween_property(_stamp, "rotation", -0.12, 0.32)
	if _progress_bar:
		_progress_bar.value = _progress_bar.max_value
	tween.chain().tween_interval(1.0)
	tween.chain().tween_callback(_advance)


func _advance() -> void:
	_stamp.visible = false
	_advancing = false
	var next := _step() + 1
	# Bereits erfüllte Folgeschritte direkt überspringen (z.B. nach dem Laden).
	while next < STEPS.size() and _condition_met(String(STEPS[next]["id"])) and next != 0:
		next += 1
	region.progression.tutorial_step = next if next < STEPS.size() else -1
	_show_current()


func finish() -> void:
	region.progression.tutorial_step = -1
	_show_current()


func _on_progress_changed() -> void:
	if is_finished():
		var signature := _goal_text_signature()
		if signature != _goal_signature:
			_show_current()


# --- Karte -----------------------------------------------------------------

func _show_current() -> void:
	_shown_step = _step()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_progress_bar = null
	_progress_label = null
	if is_finished():
		_build_goal_card()
	else:
		_build_step_card(STEPS[_step()])
	_card.reset_size()
	_layout()
	_card.modulate.a = 0.0
	var start := _card.position
	_card.position = start + Vector2(-24, 0)
	var tween := _card.create_tween().set_parallel()
	tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	tween.tween_property(_card, "position", start, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_step_card(step: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(head)
	head.add_child(_portrait(80))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	titles.add_child(S.label("SCHRITT %d VON %d" % [_step() + 1, STEPS.size()], 15, S.GOLD.darkened(0.3)))
	var title := S.label(String(step["title"]), 28, S.INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(title)
	head.add_child(_step_dots())
	_body.add_child(S.paragraph(String(step["text"]), 19, S.INK))
	if step.has("keys"):
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 8)
		keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(keys)
		for action: StringName in step["keys"]:
			keys.add_child(S.keycap(InputConfig.get_action_label(action), 19))
			keys.add_child(S.label(_key_caption(action), 17, S.INK_SOFT))
	var progress := _progress_of(String(step["id"]))
	if progress.y > 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(row)
		var icon_name: String = {"rails": "rail", "halts": "station", "ride": "passengers"}.get(String(step["id"]), "journey")
		row.add_child(S.icon_rect(S.icon(icon_name), 34))
		_progress_bar = S.TrackBar.new(progress.x, progress.y)
		_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_progress_bar)
		_progress_label = S.label("", 18, S.INK)
		_progress_label.custom_minimum_size = Vector2(110, 0)
		_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(_progress_label)
		_update_progress(String(step["id"]))
	if step.has("note"):
		_body.add_child(S.paragraph(String(step["note"]), 16, S.INK_FADED))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_body.add_child(footer)
	var skip := Button.new()
	skip.text = "Einführung überspringen"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.add_theme_font_override("font", S.serif())
	skip.add_theme_font_size_override("font_size", 16)
	skip.add_theme_color_override("font_color", S.INK_FADED)
	skip.add_theme_color_override("font_hover_color", S.INK_SOFT)
	skip.pressed.connect(finish)
	footer.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	if step.has("button"):
		var id := String(step["id"])
		S.button(footer, String(step["button"]), func() -> void:
			if id == "grow":
				panel.open_page("epochs")
			_complete_step(), true, "", 20)


## Nach der Einführung: nächste Epoche mit ihren offenen Bedingungen.
func _build_goal_card() -> void:
	var progress := region.progression
	_goal_signature = _goal_text_signature()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_body.add_child(head)
	head.add_child(S.icon_rect(S.icon("journey"), 44))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	if progress.epoch >= EpochCatalog.all().size():
		titles.add_child(S.label("EPOCHE %d" % progress.epoch, 14, S.GOLD.darkened(0.3)))
		titles.add_child(S.label(String(EpochCatalog.epoch(progress.epoch)["name"]), 24))
	else:
		var next := EpochCatalog.epoch(progress.epoch + 1)
		titles.add_child(S.label("NÄCHSTES ZIEL · EPOCHE %d" % (progress.epoch + 1), 14, S.GOLD.darkened(0.3)))
		titles.add_child(S.label(String(next["name"]), 24))
	var fold := Button.new()
	fold.text = "+" if _collapsed else "–"
	fold.flat = true
	fold.focus_mode = Control.FOCUS_NONE
	fold.tooltip_text = "Ziele ein- oder ausklappen"
	fold.add_theme_font_override("font", S.serif())
	fold.add_theme_font_size_override("font_size", 28)
	fold.add_theme_color_override("font_color", S.INK_SOFT)
	fold.pressed.connect(func() -> void:
		_collapsed = not _collapsed
		_show_current())
	head.add_child(fold)
	if _collapsed or progress.epoch >= EpochCatalog.all().size():
		return
	for requirement in progress.requirements(progress.epoch + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(row)
		row.add_child(S.icon_rect(S.icon(RegionPanel.METRIC_ICONS.get(String(requirement["key"]), "journey")), 28))
		var caption := S.label(String(requirement["label"]).replace(" (m)", ""), 16, S.INK)
		caption.custom_minimum_size = Vector2(170, 0)
		row.add_child(caption)
		var bar := S.TrackBar.new(float(requirement["value"]), float(requirement["target"]))
		bar.custom_minimum_size = Vector2(110, 13)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var unit := " m" if String(requirement["key"]) == "rail_length" else ""
		var value := S.label("%d/%d%s" % [mini(int(requirement["value"]), int(requirement["target"])), int(requirement["target"]), unit], 15, S.GREEN if requirement["met"] else S.INK_SOFT)
		value.custom_minimum_size = Vector2(76, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	var open := S.button(_body, "Reisebuch öffnen", func() -> void: panel.open_page("epochs"), false, "journey", 17)
	open.size_flags_horizontal = Control.SIZE_SHRINK_END


func _goal_text_signature() -> String:
	var parts := [str(region.progression.epoch)]
	if region.progression.epoch < EpochCatalog.all().size():
		for requirement in region.progression.requirements(region.progression.epoch + 1):
			parts.append(str(int(requirement["value"])))
	return ",".join(parts)


func _portrait(edge: float) -> Control:
	var frame := PanelContainer.new()
	var ring := S.flat(Color("dfe7ef"), S.GOLD, 4, int(edge), 2.0)
	frame.add_theme_stylebox_override("panel", ring)
	frame.custom_minimum_size = Vector2(edge, edge)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var face := S.icon_rect(S.icon("conductor"), edge - 8)
	frame.add_child(face)
	return frame


func _step_dots() -> Control:
	var dots := VBoxContainer.new()
	dots.add_theme_constant_override("separation", 4)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in STEPS.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = S.GOLD if i < _step() else (S.WOOD if i == _step() else Color(0.6, 0.5, 0.4, 0.3))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	return dots


func _key_caption(action: StringName) -> String:
	match action:
		&"build_mode": return "Baumodus"
		&"build_tool_rail": return "Schiene"
		&"build_tool_station": return "Haltepunkt"
		&"interact_primary": return "setzen" if _step() != 5 else "mitfahren"
		&"region_overview": return "Reisebuch & Fuhrpark"
		&"time_speed": return "Zeitraffer"
	return ""


func _update_progress(id: String) -> void:
	if _progress_bar == null or not is_instance_valid(_progress_bar):
		return
	var progress := _progress_of(id)
	if progress.y <= 0:
		return
	if not is_equal_approx(_progress_bar.value, progress.x):
		_progress_bar.value = progress.x
		var tween := _progress_bar.create_tween()
		tween.tween_property(_progress_bar, "_shown", clampf(progress.x / progress.y, 0.0, 1.0), 0.45).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_method(func(_v: float) -> void: _progress_bar.queue_redraw(), 0.0, 1.0, 0.45)
	match id:
		"rails": _progress_label.text = "%d / %d m" % [mini(int(progress.x), int(progress.y)), int(progress.y)]
		"halts": _progress_label.text = "%d / 2 Orte" % mini(int(progress.x), 2)
		"ride": _progress_label.text = "unterwegs" if progress.x < 1 else "angekommen"


# --- Position --------------------------------------------------------------

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := S.screen_factor(viewport)
	_canvas.scale = Vector2.ONE * factor
	# Linke obere Ecke des Bildschirms (nicht der zentrierten Leinwand).
	_canvas.position = Vector2.ZERO
	_card.custom_minimum_size.x = CARD_WIDTH if not is_finished() else 420.0
	_card.position = CARD_POS
	_fit_card.call_deferred()


## Umbrechende Texte kennen ihre Höhe erst nach dem Layout – danach einpassen.
func _fit_card() -> void:
	_card.size = Vector2(_card.custom_minimum_size.x, 0)
	_card.reset_size()
	_snow.position = CARD_POS + Vector2(10, -17)
	_snow.size = Vector2(_card.size.x - 20, 26)


## Ist das Reisebuch offen, spricht Ilse in dessen Kopfzeile; die Karte ruht.
func _update_ribbon() -> void:
	var open := panel.is_open()
	_card.visible = not open
	_snow.visible = not open
	if open != _ribbon:
		_ribbon = open
		if not open:
			panel.set_tutorial_hint("")
	if open:
		panel.set_tutorial_hint(_panel_hint())
		if not is_finished() and String(STEPS[_step()]["id"]) == "train":
			panel.reveal_tutorial_target("assign")


func _panel_hint() -> String:
	if is_finished():
		return ""
	match String(STEPS[_step()]["id"]):
		"train":
			if panel.get_page() in ["fleet", "lines"]:
				return "Ilse: Wähl beide Orte und drück „Zug einsetzen“ – der Dieseltriebwagen ist kostenlos."
			return "Ilse: Öffne den Fuhrpark, um deinen ersten Zug einzusetzen."
		"welcome", "build", "rails", "halts":
			return "Ilse: Schließ das Reisebuch (Esc) – draußen wartet deine erste Strecke."
		"ride":
			return "Ilse: Schließ das Buch und sieh deinem Zug bei der ersten Fahrt zu."
	return ""


# --- Zeigepfeil ------------------------------------------------------------

func _update_pointer() -> void:
	_pointer.target = _pointer_target()


func _pointer_target() -> Control:
	if is_finished() or _advancing:
		return null
	var id := String(STEPS[_step()]["id"])
	var current_tool := build_mode.get_current_tool()
	match id:
		"rails":
			if build_mode.active and (current_tool == null or current_tool.tool_id != &"rail"):
				return _tool_button(&"rail")
		"halts":
			if build_mode.active and (current_tool == null or current_tool.tool_id != &"station"):
				return _tool_button(&"station")
		"train":
			if panel.is_open():
				var assign := panel.get_tutorial_target("assign")
				return assign if assign else panel.get_tutorial_target("fleet_tab")
			return panel.get_tutorial_target("fleet_sign")
	return null


func _tool_button(id: StringName) -> Control:
	if hud and hud.has_method("get_tool_button"):
		var button: Control = hud.call("get_tool_button", id)
		if button and button.is_visible_in_tree():
			return button
	return null


# --- Markierungen in der Welt ----------------------------------------------

## Gute Plätze für Haltepunkte: nahe an Gleisenden, mit Platz für den Zug.
func _halt_suggestions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var wanted := 2 - region.stations.size()
	if wanted <= 0:
		return result
	var network := region.network
	var ends: Array[Dictionary] = []
	for segment in network.get_segments():
		if segment.tunnel:
			continue
		for at_start: bool in [true, false]:
			var node := network.get_rail_node(segment.start_node_id if at_start else segment.end_node_id)
			if node and node.segment_ids.size() == 1:
				ends.append({"segment": segment, "start": at_start})
	for end in ends:
		if result.size() >= wanted:
			break
		var segment: RailSegment = end["segment"]
		for inset: float in [20.0, 24.0, 17.0, 28.0]:
			if inset > segment.length - 4.0:
				continue
			var offset := inset if bool(end["start"]) else segment.length - inset
			var axis := segment.curve.sample_baked(offset, true)
			var tangent := RailGeometry.flat(RailGeometry.tangent_at(segment.curve, offset)).normalized()
			var right := Vector3(tangent.z, 0, -tangent.x)
			var found := false
			for side: float in [1.0, -1.0]:
				var candidate := axis + right * side * 3.5
				var too_close := false
				for other in result:
					too_close = too_close or RailGeometry.flat(other - candidate).length() < 34.0
				if too_close:
					continue
				var placement := region.placement(candidate)
				if String(placement.get("reason", "")) == "" and placement.has("pos"):
					var pos := SaveUtils.array_to_vec3(placement["pos"])
					result.append(pos + Basis(Vector3.UP, float(placement["angle"])).x * 3.4)
					found = true
					break
			if found:
				break
	return result


func _update_markers(points: Array[Vector3]) -> void:
	if not is_instance_valid(_markers) or not _markers.is_inside_tree():
		return
	var key := ""
	for point in points:
		key += "%d,%d;" % [roundi(point.x), roundi(point.z)]
	if key == _marker_key:
		return
	_marker_key = key
	for child in _markers.get_children():
		child.queue_free()
	for point in points:
		var marker := TutorialMarker.new()
		_markers.add_child(marker)
		marker.global_position = Vector3(point.x, region.terrain.get_height(point.x, point.z), point.z)


## Goldener Pfeil mit pulsierendem Rahmen um ein Bedienelement.
class TutorialPointer extends Control:
	var target: Control
	var _time := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
			return
		var rect := target.get_global_rect()
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		var frame := rect.grow(4.0 + pulse * 4.0)
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(1.0, 0.8, 0.35, 0.10 + pulse * 0.08)
		glow.border_color = Color(1.0, 0.78, 0.3, 0.75 + pulse * 0.25)
		glow.set_border_width_all(3)
		glow.set_corner_radius_all(10)
		draw_style_box(glow, frame)
		# Pfeil über (oder unter, wenn oben kein Platz ist) dem Element.
		var above := rect.position.y > 90.0
		var bob := sin(_time * 5.0) * 7.0
		var tip := Vector2(rect.get_center().x, (rect.position.y - 8.0 + bob) if above else (rect.end.y + 8.0 - bob))
		var direction := 1.0 if above else -1.0
		var head := PackedVector2Array([tip, tip + Vector2(-18, -24 * direction), tip + Vector2(18, -24 * direction)])
		var shaft := Rect2(tip.x - 7, tip.y - 54 * direction if above else tip.y + 22, 14, 32)
		draw_rect(shaft.grow(2.5), JourneyStyle.WOOD_DARK)
		draw_colored_polygon(PackedVector2Array([head[0] + Vector2(0, 4 * direction), head[1] + Vector2(-4, -2 * direction), head[2] + Vector2(4, -2 * direction)]), JourneyStyle.WOOD_DARK)
		draw_rect(shaft, JourneyStyle.GOLD_LIGHT)
		draw_colored_polygon(head, JourneyStyle.GOLD_LIGHT)


## Leuchtender Ring mit schwebendem Pfeil: „Hier passt ein Haltepunkt hin.“
class TutorialMarker extends Node3D:
	var _arrow: Node3D
	var _ring: MeshInstance3D
	var _time := 0.0

	func _ready() -> void:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.58, 0.16, 0.95)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.no_depth_test = false
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 2.6
		torus.outer_radius = 3.4
		torus.rings = 32
		torus.ring_segments = 6
		_ring.mesh = torus
		_ring.material_override = glow
		_ring.position.y = 0.35
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)
		_arrow = Node3D.new()
		add_child(_arrow)
		var cone := MeshInstance3D.new()
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = 0.75
		cone_mesh.height = 1.1
		cone_mesh.radial_segments = 8
		cone.mesh = cone_mesh
		cone.rotation.x = PI
		cone.material_override = glow
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arrow.add_child(cone)
		var shaft := MeshInstance3D.new()
		var shaft_mesh := CylinderMesh.new()
		shaft_mesh.top_radius = 0.28
		shaft_mesh.bottom_radius = 0.28
		shaft_mesh.height = 1.2
		shaft_mesh.radial_segments = 8
		shaft.mesh = shaft_mesh
		shaft.position.y = 1.1
		shaft.material_override = glow
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arrow.add_child(shaft)
		var label := Label3D.new()
		label.text = "Haltepunkt"
		label.font = JourneyStyle.serif()
		label.font_size = 64
		label.pixel_size = 0.02
		label.outline_size = 14
		label.modulate = Color("fff3d6")
		label.outline_modulate = Color("3f2a1e")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position.y = 2.5
		_arrow.add_child(label)

	func _process(delta: float) -> void:
		_time += delta
		_arrow.position.y = 2.6 + sin(_time * 3.0) * 0.35
		_arrow.rotation.y += delta * 1.2
		var pulse := 1.0 + sin(_time * 3.0) * 0.08
		_ring.scale = Vector3(pulse, 1.0, pulse)
