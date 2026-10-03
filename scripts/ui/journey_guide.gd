## Reusable UI tour and a short, persistent introduction for each unlocked epoch.
class_name JourneyGuide
extends CanvasLayer

const S = preload("res://scripts/ui/journey_style.gd")
const TOUR := [
	{"page":"epochs","target":"epochs_tab","title":"Deine nächste Epoche","text":"Hier siehst du echte Beförderungen, Einwohner und Verbindungen. Die offenen Ziele führen zur nächsten Epoche; wähle ein Kapitel, um seine Freischaltungen anzusehen."},
	{"page":"stations","target":"stations_tab","title":"Deine Orte","text":"Jeder Ort hat eigene Einwohner, Ankünfte und wartende Familien. Öffne einen Bahnhof, um seinen Namen, Ausbau und seine Linien zu verwalten."},
	{"page":"station","target":"station_upgrade","title":"Ein Bahnhof wird größer","text":"Ein Ausbau braucht die passende Epoche, Geld und erfolgreiche Ankünfte an diesem Ort. Gelände, Treppe und Zugänge wachsen mit. Zusätzliche Bahnsteige brauchen ein eigenes Gleis."},
	{"page":"fleet","target":"fleet_tab","title":"Züge kennenlernen","text":"Ziehe am 3D-Modell, um es zu drehen. Kapazität, Tempo und benötigte Bahnhofsstufe helfen bei der Wahl. Darunter wählst du zwei Orte und setzt den Zug ein."},
	{"page":"lines","target":"lines_tab","title":"Dein Fahrplan","text":"Hier findest du alle Verbindungen, beförderte Gäste und Güter. Linien lassen sich pausieren. Wartende Züge nutzen gemeinsam belegte Gleise erst, wenn diese frei sind."},
	{"page":"_notebook_storage","title":"Vorräte und Baustoffhandel","text":"Im Lager siehst du Bestände und Daueraufträge. Güterzüge liefern bestellte Waren; beim Bauen zeigt die Kostenleiste auch den Zukauf fehlender Materialien."},
	{"page":"_notebook_residents","title":"Wer hier wohnt","text":"Diese Seite zeigt Haushalte und den Status ihrer Familie. Im Detail findest du Tagesrhythmus und Lieblingswege der sichtbaren Bewohner."},
	{"page":"_notebook_timetable","title":"Züge auf einen Blick","text":"Das Notizbuch führt deine Personen- und Güterlinien mit aktuellem Betriebszustand auf. Neue Verbindungen legst du im Fuhrpark oder unter Linien an."},
	{"page":"_notebook_projects","title":"Deine Baustellen","text":"Hier siehst du Baufortschritt und Materialbedarf. Gebaut wird tagsüber. Fertige Häuser warten auf ihre Familie aus dem nächsten passenden Zug."},
	{"page":"_notebook_finances","title":"Die Gemeindekasse","text":"Fahrkarten und Gemeindeabgaben finanzieren den Ausbau. Das Kassenbuch zeigt Einnahmen und Ausgaben; behalte auch Baustoffkäufe im Blick."},
	{"page":"_notebook_festivals","title":"Feste und Chronik","text":"Im Festkalender und in der Chronik kannst du Ereignisse deiner Reise nachlesen. Sonderzüge findest du zusätzlich im Fuhrpark."},
	{"page":"_status","target":"status","title":"Geld, Zeit und Reisebuch","text":"Oben stehen Geld, Tag und Uhrzeit. T wechselt das Zeittempo. N öffnet das Notizbuch mit Vorräten, Handel und Chronik; Esc öffnet das Pausenmenü mit Speichern und Einstellungen."},
	{"page":"_build","target":"build","title":"Mit Ruhe bauen","text":"B öffnet die Werkzeuge. Vorschau und Kosten zeigen, was passt. Einrasten und Bestätigung helfen beim Platzieren. R dreht, C wechselt Varianten; Strg+Z nimmt den letzten Bauschritt zurück."},
]
const EPOCH_TIPS := {
	2:"Weichen und Signale erweitern dein Netz. Der nostalgische Regionalzug hat eine Lok an jedem Ende. Baue deinen Haltepunkt zum Landbahnhof aus; Bauernhäuser, Lichterketten und Dorfdeko kommen hinzu. Ein bedienter Bahnhof genügt bis zur dritten Epoche – entwickle erst dein Dorf in Ruhe.",
	3:"Güterverkehr, Dorfbahnhof und der Tunnel nach Südtal sind neu. Steinwege, Dorfplatz und weitere Hausformen erweitern dein Dorf. Bestellte Waren zählen erst nach dem sichtbaren Umschlag.",
	4:"Der moderne Nahverkehr verbindet größere Nachbarschaften. Kleinstadtbahnhöfe, Straßen und neue Häuser geben deinen Orten einen städtischen Charakter.",
	5:"Der Intercity, Stadtbahnhöfe und zusätzliche Bahnsteige verbinden die Region. Verlängere auch die Gleise hinter den Haltepunkten, damit längere Züge Platz haben.",
	6:"Hauptbahnhof und Hochgeschwindigkeitszug sind jetzt verfügbar. Große Hallen und bis zu vier Bahnsteige bilden einen regionalen Knotenpunkt. Die langen Züge brauchen passende Gleise und ausgebaute Ziele.",
}
var region: RegionRailway
var panel: RegionPanel
var tutorial: JourneyTutorial
var build_mode: BuildMode
var hud: Node
var _canvas: Control
var _card: PanelContainer
var _body: VBoxContainer
var _pointer: Control
var _mode := ""
var _steps: Array[Dictionary] = []
var _index := 0
var _epoch := 0
var _previous_page := ""
var _previous_build := false
var _previous_view := 0
var _book_step := false
var _note_step := false
var _note_pause := false

func _ready() -> void:
	layer = 67
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = S.make_theme()
	add_child(_canvas)
	_card = PanelContainer.new()
	_card.theme = _canvas.theme
	_card.add_theme_stylebox_override("panel",S.flat(S.PAPER,S.GOLD,2,12,14))
	_canvas.add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation",9)
	_card.add_child(_body)
	_pointer = JourneyTutorial.TutorialPointer.new()
	add_child(_pointer)
	_card.hide()
	Events.journey_guide_requested.connect(start_tour)
	Events.game_loaded.connect(func(_slot: String) -> void: _resume.call_deferred())
	region.progression.epoch_unlocked.connect(_unlocked)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_resume.call_deferred()

func _state() -> Dictionary:
	return region.progression.guide_state

func _resume() -> void:
	stop(true,false)
	var index := int(_state().get("active_index",-1))
	if index>=0:
		start_tour(int(_state().get("active_epoch",0)),index)

func _process(_delta: float) -> void:
	if _mode!="":
		_fit_card()
	if _mode=="":
		var pending: Array = _state().get("pending",[])
		if not pending.is_empty() and not panel.is_open() and not _notebook().is_open and not _pause_open():
			show_epoch(int(pending[0]))
		return
	if _book_step and not panel.is_open():
		stop(true)
		return
	if _note_step and not _notebook().is_open:
		stop(true)
		return
	if _pause_open():
		_pointer.set("target",null)
		return
	var target: Control
	if _mode=="tour":
		var key := String(_steps[_index].get("target",""))
		if _note_step:
			target = _notebook()._tab_buttons.get(String(_steps[_index]["page"]).trim_prefix("_notebook_"))
		else:
			target = hud.get_tutorial_target(key) if key in ["status","build"] else panel.get_tutorial_target(key)
	_pointer.set("target",target)

func _pause_open() -> bool:
	var pause := region.get_parent().get_node_or_null("PauseMenu")
	return pause!=null and bool(pause.get("is_open"))

func _unlocked(level: int) -> void:
	var pending: Array = _state().get("pending",[])
	for number in range(maxi(2,int(_state().get("epoch_seen",1))+1),level+1):
		if not pending.has(number):
			pending.append(number)
	_state()["pending"] = pending

func show_epoch(level: int) -> void:
	_previous_page = panel.get_page()
	_previous_build = build_mode.active
	_previous_view = build_mode.view_mode_controller.mode
	_epoch = level
	_mode = "epoch"
	_book_step = false
	tutorial.set_guide_active(true)
	_clear()
	var data := EpochCatalog.epoch(level)
	_body.add_child(S.label("ILSES KLEINER AUSBLICK",15,S.GOLD.darkened(0.3)))
	_body.add_child(S.paragraph("Epoche %d · %s" % [level,data["name"]],27,S.INK))
	_body.add_child(S.paragraph(String(EPOCH_TIPS.get(level,"Neue Möglichkeiten für deine Eisenbahnregion.")),19))
	var actions := HBoxContainer.new()
	_body.add_child(actions)
	S.button(actions,"Neuheiten zeigen",start_tour.bind(level),true,"journey",19)
	S.button(actions,"Später ansehen",stop.bind(true),false,"",18)
	_place_card(false)

func start_tour(level := 0, resume_index := 0) -> void:
	if _mode!="tour":
		if _notebook().is_open:
			_notebook().close()
		_previous_page = panel.get_page()
		_previous_build = build_mode.active
		_previous_view = build_mode.view_mode_controller.mode
	_epoch = clampi(level,0,6)
	_mode = "tour"
	_steps.clear()
	if _epoch>0:
		_steps.assign([
			{"page":"epochs","target":"epochs_tab","title":"Epoche %d ist erreicht" % _epoch,"text":EPOCH_TIPS.get(_epoch,"")},
			{"page":"station","target":"station_upgrade","title":"Deinen Bahnhof ausbauen","text":"Die neue Bahnhofsstufe ist jetzt möglich. Prüfe hier die örtlichen Ankünfte und Kosten. Kleine Bahnhöfe wachsen erst, wenn du ihren Ausbau beauftragst."},
			{"page":"fleet","target":"fleet_tab","title":"Das neue Fahrzeug","text":"Hier steht dein frisch freigeschalteter Zug. Dreh das Modell und prüfe Bahnhofsstufe, Länge und Kapazität. Wähle unten seine Verbindung."},
			{"page":"_build","target":"build","title":"Die neuen Bauwerkzeuge","text":"Die Werkzeugleiste zeigt alle verfügbaren Kategorien. Unter der gewählten Kategorie findest du die inzwischen freigeschalteten Objekte."},
		])
	else:
		_steps.assign(TOUR)
	_index = clampi(resume_index,0,_steps.size()-1)
	tutorial.set_guide_active(true)
	_present()

func _present() -> void:
	_close_notebook()
	_state()["active_index"] = _index
	_state()["active_epoch"] = _epoch
	var step := _steps[_index]
	var page := String(step["page"])
	_book_step = not page.begins_with("_")
	if _book_step:
		build_mode.set_active(false)
		match page:
			"epochs": panel.show_epoch(_epoch if _epoch>0 else region.progression.epoch)
			"fleet": panel.show_train(String(EpochCatalog.epoch(_epoch if _epoch>0 else region.progression.epoch)["trains"][0]))
			"station":
				if region.stations.is_empty():
					panel.open_page("stations")
				else:
					panel.show_station(region.stations[0].station_id)
			_: panel.open_page(page)
		panel.reserve_guide_space(true)
		panel.set_tutorial_hint("Ilse zeigt dir die Bedienung · %d von %d" % [_index+1,_steps.size()])
		panel.reveal_tutorial_target(String(step["target"]))
	else:
		panel.reserve_guide_space(false)
		panel.close()
		build_mode.set_active(page=="_build")
		if page.begins_with("_notebook_"):
			_note_pause = WorldClock.paused
			_note_step = true
			WorldClock.paused = true
			_notebook().open(page.trim_prefix("_notebook_"))
			_notebook().reserve_guide_space(true)
	_clear()
	_body.add_child(S.label("ILSES RUNDGANG · %d / %d" % [_index+1,_steps.size()],15,S.GOLD.darkened(0.3)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	_body.add_child(row)
	var explanation := VBoxContainer.new()
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(explanation)
	explanation.add_child(S.paragraph(String(step["title"]),25,S.INK))
	explanation.add_child(S.paragraph(String(step["text"]),18))
	var controls: BoxContainer = HBoxContainer.new() if _book_step or _note_step else VBoxContainer.new()
	row.add_child(controls)
	var back := S.button(controls,"Zurück",previous,false,"",18)
	back.disabled = _index==0
	S.button(controls,"Fertig" if _index==_steps.size()-1 else "Weiter",next,true,"check",18)
	S.button(controls,"Beenden",stop.bind(true),false,"",17)
	_place_card(_book_step)

func _notebook() -> Notebook:
	return region.get_parent().get_node("Notebook") as Notebook

func _close_notebook() -> void:
	if _note_step:
		_note_step = false
		_notebook().reserve_guide_space(false)
		_notebook().close()
		WorldClock.paused = _note_pause

func next() -> void:
	if _index+1>=_steps.size():
		if _epoch==0:
			_state()["tour_done"] = true
		stop()
		return
	_index += 1
	_present()

func previous() -> void:
	_index = maxi(0,_index-1)
	_present()

func stop(keep_closed := false, mark := true) -> void:
	if _mode=="":
		return
	_close_notebook()
	if mark:
		_state()["active_index"] = -1
		if _epoch>0:
			_state()["epoch_seen"] = maxi(_epoch,int(_state().get("epoch_seen",1)))
			var pending: Array = _state().get("pending",[])
			pending.erase(_epoch)
	_mode = ""
	_book_step = false
	_card.hide()
	_pointer.set("target",null)
	panel.reserve_guide_space(false)
	panel.set_tutorial_hint("")
	if keep_closed or _previous_page=="":
		panel.close()
	else:
		panel.open_page(_previous_page)
	build_mode.set_active(_previous_build)
	if not _previous_build and build_mode.view_mode_controller.mode!=_previous_view:
		build_mode.view_mode_controller.set_mode(_previous_view)
	tutorial.set_guide_active(false)

func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _place_card(book: bool) -> void:
	if _note_step:
		_card.reparent(_notebook().guide_host(),false)
		_card.position = Vector2(68,Notebook.BOOK_SIZE.y-174)
		_card.custom_minimum_size = Vector2(Notebook.BOOK_SIZE.x-136,0)
	elif book:
		_card.reparent(panel.guide_host(),false)
		_card.position = Vector2(98,RegionPanel.BOARD_SIZE.y-178)
		_card.custom_minimum_size = Vector2(RegionPanel.BOARD_SIZE.x-196,0)
	else:
		_card.reparent(_canvas,false)
		_card.position = Vector2(22,132)
		_card.custom_minimum_size = Vector2(520,0)
	_card.size = Vector2(_card.custom_minimum_size.x,0)
	_card.reset_size()
	_card.show()
	_fit_card.call_deferred()

func _fit_card() -> void:
	var height := _card.get_combined_minimum_size().y
	_card.size.y = height
	if _book_step:
		_card.position.y = RegionPanel.BOARD_SIZE.y-36-height
		panel.reserve_guide_space(true,height+50)
	elif _note_step:
		_card.position.y = Notebook.BOOK_SIZE.y-32-height
		_notebook().reserve_guide_space(true,height+104)

func _layout() -> void:
	_canvas.scale = Vector2.ONE*S.screen_factor(get_viewport().get_visible_rect().size)
