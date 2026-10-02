## Parchment travel journal: milestones, station operations and a persistent fleet.
class_name RegionPanel
extends CanvasLayer

const INK := Color("483e32")
const GOLD := Color("ba8847")
const PAPER := Color("eee4ce")
var region: RegionRailway
var _root: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _title: Label
var _hint: Label
var _epoch_button: Button
var _page := "epochs"
var _station_id := 0
var _selected_train := "diesel_heritage"
var _previous_pause := false
var _was_captured := false
var _preview: Node3D
var _viewport: SubViewport
var _preview_camera: Camera3D
var _preview_length := 16.0
var _debug := false
var _refresh_pending := false

func _ready() -> void:
	layer = 65
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.theme = _theme()
	var launch := HBoxContainer.new()
	launch.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	launch.position = Vector2(-356,22)
	_root.add_child(launch)
	_epoch_button = _button(launch,"Reise · Epoche 1",func() -> void: open_page("epochs"))
	_button(launch,"Fuhrpark",func() -> void: open_page("fleet"))
	var tutorial := PanelContainer.new()
	tutorial.position = Vector2(24,106)
	tutorial.custom_minimum_size = Vector2(360,0)
	tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tutorial)
	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(320,0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size",17)
	tutorial.add_child(_hint)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 70
	_panel.offset_right = -70
	_panel.offset_top = 70
	_panel.offset_bottom = -110
	_root.add_child(_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",14)
	_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	_title = _label(header,"Deine Eisenbahnreise",30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header,"Schließen  ×",close)
	var tabs := HBoxContainer.new()
	layout.add_child(tabs)
	for id in ["epochs","stations","fleet","lines"]:
		var caption: String = {"epochs":"Unsere Reise","stations":"Orte & Bahnhöfe","fleet":"Fuhrpark","lines":"Linien"}[id]
		_button(tabs,caption,open_page.bind(id))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation",12)
	scroll.add_child(_content)
	_panel.hide()
	region.changed.connect(_schedule_refresh)
	region.progression.changed.connect(_schedule_refresh)
	region.progression.epoch_unlocked.connect(_on_unlock)
	Events.region_station_requested.connect(func(id: int) -> void:
		_station_id = id
		open_page("station"))
	_update_hint()

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",Color("735128"))
	theme.set_color("font_disabled_color","Button",Color("817765"))
	var paper := _style(PAPER,Color("c4ab7e"),16)
	paper.shadow_color = Color(0.12,0.1,0.07,0.28)
	paper.shadow_size = 12
	theme.set_stylebox("panel","PanelContainer",paper)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var color := Color("e4d2af")
		if state == "hover":
			color = Color("f8ebcf")
		elif state == "pressed":
			color = Color("ccb084")
		elif state == "disabled":
			color = Color("d5cebf")
		theme.set_stylebox(state,"Button",_style(color,GOLD,8))
		theme.set_stylebox(state,"OptionButton",_style(color,GOLD,8))
	theme.set_color("font_color","OptionButton",INK)
	theme.set_color("font_hover_color","OptionButton",INK)
	theme.set_color("font_color","LineEdit",INK)
	theme.set_stylebox("normal","LineEdit",_style(Color("f8f1e2"),GOLD,8))
	theme.set_stylebox("focus","LineEdit",_style(Color("fff8e9"),GOLD,8))
	theme.set_stylebox("background","ProgressBar",_style(Color("d4c5aa"),Color("d4c5aa"),6))
	theme.set_stylebox("fill","ProgressBar",_style(Color("769a76"),Color("769a76"),6))
	return theme

func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(parent: Node, text: String, font_size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _paragraph(parent: Node, text: String) -> Label:
	var label := _label(parent,text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color("f5eddd"),Color("d1bb94"),10))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	return box

func open_page(page: String) -> void:
	if not _panel.visible:
		_previous_pause = WorldClock.paused
		WorldClock.paused = true
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.show()
	_page = page
	_refresh()
	_panel.modulate.a = 0
	_panel.create_tween().tween_property(_panel,"modulate:a",1.0,0.18)

func close() -> void:
	if not _panel.visible:
		return
	_panel.hide()
	WorldClock.paused = _previous_pause
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_preview = null
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	if _panel and _panel.visible:
		WorldClock.paused = _previous_pause

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"region_overview"):
		if _panel.visible:
			close()
		else:
			open_page("epochs")
	elif _panel.visible and event.is_action_pressed(&"build_cancel"):
		close()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_debug = not _debug
		open_page("debug" if _debug else "epochs")
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _panel.visible and is_instance_valid(_preview):
		_preview.rotation.y += delta*0.12
		_frame_preview()

func _frame_preview() -> void:
	if not is_instance_valid(_preview_camera) or not is_instance_valid(_viewport):
		return
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	for x: float in [-1.6,1.6]:
		for y: float in [0,4.4]:
			for z: float in [-_preview_length/2,_preview_length/2]:
				var point := _preview_camera.to_local(_preview.to_global(Vector3(x,y,z)))
				minimum = minimum.min(Vector2(point.x,point.y))
				maximum = maximum.max(Vector2(point.x,point.y))
	var aspect := float(_viewport.size.x)/maxf(1,_viewport.size.y)
	var size := maximum-minimum
	_preview_camera.size = maxf(size.x,size.y*aspect)*1.12

func _schedule_refresh() -> void:
	_update_hint()
	if _panel.visible and not _refresh_pending:
		_refresh_pending = true
		_refresh.call_deferred()

func _update_hint() -> void:
	_epoch_button.text = "Reise · Epoche %d" % region.progression.epoch
	var metrics := region.progression.metrics()
	if region.network.get_segment_count()==0:
		_hint.text = "Ein Anfang im Grünen\nB drücken · Schiene wählen · Start und Ende anklicken. Zwei verbundene Stücke mit je 45 m bieten Platz für die ersten Haltepunkte."
	elif region.stations.size()<2:
		_hint.text = "Die ersten Orte\nB → H: Zwei Holz-Haltepunkte am Gleis errichten. Je etwa 12 m Gleis an den Enden freilassen, damit der ganze Zug hineinpasst."
	elif region.lines.is_empty():
		_hint.text = "Dein erster Zug\nFuhrpark öffnen · Alter Dieseltriebwagen · Zwei Haltepunkte auswählen · Zug einsetzen."
	else:
		_hint.text = "%s\n%d Fahrgäste · %d Einwohner · %d Verbindungen\nP öffnet Ziele und kommende Freischaltungen." % [EpochCatalog.epoch(region.progression.epoch)["name"],region.progression.passengers,int(metrics["population"]),int(metrics["lines"])]

func _refresh() -> void:
	_refresh_pending = false
	_preview = null
	_viewport = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_title.text = {"epochs":"Unsere Eisenbahnreise","stations":"Orte, die durch deine Bahn wachsen","fleet":"Dein Fuhrpark","lines":"Verbindungen durch die Region","station":"Bahnhof & Nachbarschaft","debug":"Entwicklungswerkzeuge"}.get(_page,"Wintervale")
	match _page:
		"epochs": _epochs()
		"stations": _stations()
		"station": _station()
		"fleet": _fleet()
		"lines": _lines()
		"debug": _debug_tools()

func _epochs() -> void:
	_paragraph(_content,"Jeder neue Abschnitt entsteht aus deiner Bahn: Orte verbinden, Menschen befördern und Nachbarschaften wachsen lassen. Frühere Fahrzeuge und kleine Haltepunkte bleiben erhalten.")
	for data in EpochCatalog.all():
		var level := int(data["id"])
		var card := _card(_content)
		var state := "✓ Erreicht" if level<region.progression.epoch else ("● Deine Epoche" if level==region.progression.epoch else "○ Vor dir")
		_label(card,"%s · %d  %s" % [state,level,data["name"]],23)
		var train := EpochCatalog.train(data["trains"][0])
		_paragraph(card,"%s  ·  %s\n%s" % [data["station"],train.display_name," · ".join(data["features"])])
		if level>1:
			for requirement in region.progression.requirements(level):
				var row := HBoxContainer.new()
				card.add_child(row)
				var text := _label(row,"%s  %d / %d" % [requirement["label"],int(requirement["value"]),int(requirement["target"])],16)
				text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var bar := ProgressBar.new()
				bar.custom_minimum_size = Vector2(220,16)
				bar.max_value = float(requirement["target"])
				bar.value = minf(float(requirement["value"]),bar.max_value)
				bar.show_percentage = false
				row.add_child(bar)

func _stations() -> void:
	if region.stations.is_empty():
		_paragraph(_content,"Die Landschaft wartet auf deinen ersten Haltepunkt. Baue Gleise mit B und wähle anschließend H.")
	for station in region.stations:
		var card := _card(_content)
		_label(card,station.station_name,24)
		_paragraph(card,"%s · %d Einwohner · %d Fahrgäste · %d Ankünfte" % [EpochCatalog.epoch(station.level)["station"],station.population,station.passenger_total,station.services])
		_button(card,"Bahnhof ansehen",func() -> void:
			_station_id = station.station_id
			open_page("station"))

func _station() -> void:
	var station := region.station_by_id(_station_id)
	if station == null:
		_stations()
		return
	_label(_content,station.station_name,32)
	_paragraph(_content,"%s · Stufe %d · Region in Epoche %d" % [EpochCatalog.epoch(station.level)["station"],station.level,region.progression.epoch])
	var counts := _card(_content)
	_paragraph(counts,"%d Einwohner  ·  %d beförderte Gäste  ·  %d Ankünfte  ·  %d gelieferte Güter\n%d gebaute Häuser  ·  %d / %d Bahnsteige" % [station.population,station.passenger_total,station.services,station.delivered_goods,station.house_ids.size(),station.platform_tracks.size()+1,int(EpochCatalog.epoch(station.level)["platforms"])])
	var reason := station.upgrade_reason()
	var upgrade := _button(counts,"Bahnhof ausbauen · %d Taler" % int(EpochCatalog.epoch(mini(6,station.level+1))["cost"]),func() -> void:
		station.upgrade()
		_refresh())
	upgrade.disabled = reason != ""
	upgrade.tooltip_text = reason
	_paragraph(counts,reason if reason != "" else "Bereit für den nächsten architektonischen Schritt")
	if station.level<6:
		_paragraph(counts,"Als Nächstes: %s · Platz für %d Bahnsteige" % [EpochCatalog.epoch(station.level+1)["station"],int(EpochCatalog.epoch(station.level+1)["platforms"])])
	if station.get_stops().size()<int(EpochCatalog.epoch(station.level)["platforms"]):
		_button(counts,"Weiteren Bahnsteig am Gleis platzieren · 120 Taler",func() -> void:
			close()
			var build := region.get_parent().get_node("BuildMode") as BuildMode
			build.set_active(true)
			build.select_tool(&"station")
			(build.get_tool(&"station") as StationBuildTool).expand_station_id = station.station_id)
	var name_row := HBoxContainer.new()
	_content.add_child(name_row)
	var edit := LineEdit.new()
	edit.text = station.station_name
	edit.max_length = 32
	edit.custom_minimum_size.x = 320
	name_row.add_child(edit)
	_button(name_row,"Ort benennen",func() -> void:
		station.rename_station(edit.text))
	for line in region.lines:
		if int(line["a"])==station.station_id or int(line["b"])==station.station_id:
			_line_card(line)
	_button(_content,"Weitere Verbindung planen",open_page.bind("lines"))

func _fleet() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",18)
	_content.add_child(columns)
	var shelf := ScrollContainer.new()
	shelf.custom_minimum_size = Vector2(300,550)
	shelf.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(shelf)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_child(list)
	for id in EpochCatalog.TRAIN_IDS:
		var type := EpochCatalog.train(id)
		var unlocked := region.progression.is_train_unlocked(id)
		var text := "%s\n%s" % [type.display_name,"Sonderzug" if type.special else ("Verfügbar" if unlocked else "Epoche %d" % type.required_epoch)]
		_button(list,text,func() -> void:
			_selected_train = id
			_refresh())
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail)
	var type := EpochCatalog.train(_selected_train)
	_label(detail,type.display_name,27)
	var assigned := 0
	for line in region.lines:
		assigned += 1 if line["train"]==_selected_train else 0
	_paragraph(detail,"%d zugewiesene Linien · %s" % [assigned,"Sonderfahrzeug" if type.special else ("Freigeschaltet" if region.progression.is_train_unlocked(_selected_train) else "Vorschau")])
	_paragraph(detail,"%s · %d km/h · %.2f m/s²\n%d Plätze · %d Gütereinheiten · %d Fahrzeuge\nBenötigt Bahnhofsstufe %d · Epoche %d" % [type.service_role,int(type.max_speed_kmh),type.acceleration,type.passenger_capacity,type.cargo_capacity,type.consist.size(),type.required_station_level,type.required_epoch])
	_train_preview(detail,type)
	if region.progression.is_train_unlocked(_selected_train):
		_line_form(detail,_selected_train)
	else:
		_paragraph(detail,"Diese Reise liegt noch vor dir. Deine bisherigen Züge bleiben auch nach der Freischaltung im Einsatz.")

func _train_preview(parent: Node, type: TrainType) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(460,300)
	container.stretch = true
	parent.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(580,260)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)
	_preview = Node3D.new()
	_viewport.add_child(_preview)
	var factory := region.dispatcher
	var length := EpochCatalog.consist_length(type)
	_preview_length = length
	var offset := -length/2
	for i in type.consist.size():
		var car := TrainCar.new()
		_preview.add_child(car)
		car.build(type.consist[i],type,i==0,i==type.consist.size()-1,factory._materials,i)
		car.position.z = offset+car.length/2
		offset += car.length+TrainMeshes.COUPLING_GAP
		car.set_cabin_light(0.7)
		car.set_snow_spray(0)
		if car._exhaust:
			car._exhaust.emitting = false
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 1.1
	_viewport.add_child(light)
	var camera := Camera3D.new()
	_preview_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = length*0.85+10
	_viewport.add_child(camera)
	camera.position = Vector3(length*0.65,length*0.10+3,-length*0.20)
	camera.look_at(Vector3(0,2.2,0))
	_frame_preview()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("343f3a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e0dac9")
	environment.environment.ambient_light_energy = 0.6
	_viewport.add_child(environment)
	container.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_preview.rotation.y += event.relative.x*0.012)
	_label(parent,"Modell mit gedrückter Maustaste drehen",14)

func _lines() -> void:
	_paragraph(_content,"Züge pendeln zwischen zwei Orten. Bahnsteiglänge, freie Gleise und die Bahnhofsstufe bestimmen, welche Fahrzeuge eingesetzt werden können.")
	_line_form(_content,_selected_train)
	for line in region.lines:
		_line_card(line)

func _line_form(parent: Node, train_id: String) -> void:
	if region.stations.size()<2:
		_paragraph(parent,"Für eine Verbindung werden zwei gebaute Haltepunkte benötigt.")
		return
	var form := _card(parent)
	var row := HBoxContainer.new()
	form.add_child(row)
	var a := OptionButton.new()
	var b := OptionButton.new()
	var types := OptionButton.new()
	for station in region.stations:
		a.add_item(station.station_name,station.station_id)
		b.add_item(station.station_name,station.station_id)
	b.select(1)
	for id in EpochCatalog.TRAIN_IDS:
		if region.progression.is_train_unlocked(id):
			types.add_item(EpochCatalog.train(id).display_name)
			types.set_item_metadata(types.item_count-1,id)
			if id==train_id:
				types.select(types.item_count-1)
	row.add_child(a)
	_label(row,"↔",22)
	row.add_child(b)
	form.add_child(types)
	var hint := _paragraph(form,"")
	var action := _button(form,"Zug einsetzen",func() -> void:
		region.add_line(a.get_selected_id(),b.get_selected_id(),String(types.get_selected_metadata()))
		_refresh())
	var update := func(_index := 0) -> void:
		var selected := String(types.get_selected_metadata())
		var reason := region.line_reason(a.get_selected_id(),b.get_selected_id(),selected)
		hint.text = reason if reason!="" else "Bereit · %d Taler · Regelmäßiger Pendelverkehr" % EpochCatalog.train(selected).purchase_price
		action.disabled = reason!=""
	a.item_selected.connect(update)
	b.item_selected.connect(update)
	types.item_selected.connect(update)
	update.call()

func _line_card(line: Dictionary) -> void:
	var a := region.station_by_id(int(line["a"]))
	var b := region.station_by_id(int(line["b"]))
	if a==null or b==null:
		return
	var card := _card(_content)
	_label(card,"Linie %d · %s ↔ %s" % [int(line["id"]),a.station_name,b.station_name],23)
	var train := region.train_for_line(int(line["id"]))
	var state := train.get_info_text() if train else ("Wartet auf freie Gleise" if region.line_is_valid(line) else "Verbindung prüfen")
	_paragraph(card,"%s\n%s\n%d Fahrten · %d Fahrgäste · %d Gütereinheiten" % [EpochCatalog.train(String(line["train"])).display_name,state,int(line.get("trips",0)),int(line.get("passengers",0)),int(line.get("goods",0))])
	var row := HBoxContainer.new()
	card.add_child(row)
	_button(row,"Linie pausieren" if bool(line.get("enabled",true)) else "Linie fortsetzen",func() -> void:
		line["enabled"] = not bool(line.get("enabled",true))
		if train:
			region.dispatcher.retire(train,"")
		region.refresh())
	_button(row,"Verbindung aufheben",func() -> void: region.remove_line(int(line["id"])))

func _debug_tools() -> void:
	if not OS.is_debug_build() or not _debug:
		return
	_paragraph(_content,"F8 · Nur im Entwicklungsbuild. Änderungen werden im Spielstand als Debug-Nutzung markiert.")
	var row := HBoxContainer.new()
	_content.add_child(row)
	for level in range(1,7):
		_button(row,"Epoche %d" % level,region.progression.set_epoch.bind(level,true))
	_button(_content,"Epoche +1",func() -> void: region.progression.set_epoch(region.progression.epoch+1,true))
	_button(_content,"20 Fahrgäste & 24 Güter simulieren",region.progression.debug_simulate.bind(20,24))
	for station in region.stations:
		var card := _card(_content)
		_label(card,station.station_name,22)
		var stages := HBoxContainer.new()
		card.add_child(stages)
		for level in range(1,7):
			_button(stages,"Stufe %d" % level,func() -> void:
				station.level = level
				station.rebuild()
				region.progression.debug_used = true
				region.refresh())
		_button(card,"Stadtwachstum simulieren",region.grow_station.bind(station,true))
	for id in EpochCatalog.TRAIN_IDS:
		_button(_content,"Freischalten: "+EpochCatalog.train(id).display_name,func() -> void:
			if not region.progression.unlocked.has(id):
				region.progression.unlocked.append(id)
			region.progression.debug_used = true
			region.refresh())

func _on_unlock(_level: int) -> void:
	_epoch_button.create_tween().tween_property(_epoch_button,"modulate",Color("f7ca7c"),0.5)
	var sound := AudioStreamPlayer.new()
	sound.stream = SoundLibrary.get_sound("done_chime")
	sound.volume_db = -12
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	SoundLibrary.play(sound)
