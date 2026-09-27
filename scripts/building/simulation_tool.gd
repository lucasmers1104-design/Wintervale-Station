## Werkzeug "Test": Testsimulation für Signale und Blöcke (es gibt noch keine Züge).
##
## - Klick auf ein Gleis: Abschnitt belegen / freigeben (wie ein stehender Zug)
## - Klick auf ein Signal: zwischen Automatik und Halt umschalten
## - Klick auf eine Weiche: umstellen (das Stellwerk prüft, ob es sicher ist)
##
## Solange das Werkzeug aktiv ist, sind belegte Gleise rot und reservierte
## Fahrwege grün eingefärbt.
class_name SimulationTool
extends BuildTool

@export var pick_radius := 2.5


func activate() -> void:
	super()
	context.rail_view.set_overlays_visible(true)


func deactivate() -> void:
	context.rail_view.set_overlays_visible(false)
	super()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"interact_primary"):
		var point := context.get_mouse_ground_point()
		if point != Vector3.INF:
			click_at(point)
		return true
	return false


func update_tool(_delta: float) -> void:
	var point := context.get_mouse_ground_point()
	set_status(describe(point) if point != Vector3.INF else "")


## Führt die Testaktion an [param point] aus. Gibt eine kurze Rückmeldung zurück.
func click_at(point: Vector3) -> String:
	var network := context.rail_network
	var interlocking := context.interlocking
	var rail_signal := network.find_signal_near(point, 1.6)
	if rail_signal:
		var halt := rail_signal.mode != RailSignal.Mode.HALT
		network.set_signal_mode(rail_signal.id, RailSignal.Mode.HALT if halt else rail_signal.resume_mode)
		return "Signal %d: %s" % [rail_signal.id, "Halt" if halt else "wieder in Betrieb"]
	var switch := network.find_switch_near(point, pick_radius)
	if switch:
		var refused := interlocking.request_switch_toggle(switch.node_id)
		set_status(refused)
		return refused if refused != "" else "Weiche umgestellt"
	var segment := network.find_segment_near(point, pick_radius)
	if segment:
		var occupied := not interlocking.is_segment_test_occupied(segment.id)
		interlocking.set_segment_occupied(segment.id, occupied)
		return "Gleis %d %s" % [segment.id, "belegt" if occupied else "frei"]
	return ""


## Zustand des Objekts unter dem Mauszeiger als kurzer Text.
func describe(point: Vector3) -> String:
	var network := context.rail_network
	var interlocking := context.interlocking
	var rail_signal := network.find_signal_near(point, 1.6)
	if rail_signal:
		var aspect := "Grün" if rail_signal.aspect == RailSignal.Aspect.CLEAR else "Rot"
		return "Signal %d: %s – %s" % [rail_signal.id, aspect, rail_signal.reason]
	var switch := network.find_switch_near(point, pick_radius)
	if switch:
		var reason := interlocking.can_toggle_switch(switch.node_id)
		var setting := "gerade" if switch.state == 0 else "abzweigend"
		return "Weiche: %s%s" % [setting, "" if reason == "" else " – " + reason]
	var segment := network.find_segment_near(point, pick_radius)
	if segment:
		var state := "frei"
		if interlocking.is_segment_occupied(segment.id):
			state = "belegt"
		elif interlocking.is_block_reserved(segment.block_id):
			state = "reserviert für Signal %d" % interlocking.get_block_owner(segment.block_id)
		return "Abschnitt %d: %s" % [segment.block_id, state]
	return ""
