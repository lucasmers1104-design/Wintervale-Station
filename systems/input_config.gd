## Zentrale Konfiguration aller Eingaben und der Tastenlegende.
##
## - Tastenbelegung: KEY_BINDINGS, CTRL_SHORTCUTS, MOUSE_BINDINGS
##   (werden von [code]GameInput[/code] beim Start in die Input Map eingetragen)
## - Werkzeuge des Build-Mode: BUILD_TOOLS (Reihenfolge = Zifferntasten & Buttons)
## - Legende je Spielmodus: LEGENDS
##
## Die Legende zeigt nie fest eingetippte Tasten, sondern liest die Namen aus
## der Input Map. Ändert man hier eine Taste, ändert sich die Legende mit.
class_name InputConfig
extends RefCounted

## Tasten nach ihrer Position (WASD liegt auf jeder Tastatur gleich).
const KEY_BINDINGS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"sprint": [KEY_SHIFT],
	&"jump": [KEY_SPACE],
	&"toggle_view": [KEY_TAB],
	&"toggle_perspective": [KEY_V],
	&"camera_rotate_left": [KEY_Q],
	&"camera_rotate_right": [KEY_E],
	&"time_speed": [KEY_T],
	&"quick_save": [KEY_F5],
	&"quick_load": [KEY_F9],
	&"toggle_help": [KEY_F1],
	&"toggle_fullscreen": [KEY_F11],
	&"release_mouse": [KEY_ESCAPE],
	&"build_mode": [KEY_B],
	&"build_tool_rail": [KEY_1],
	&"build_tool_switch": [KEY_2],
	&"build_tool_signal": [KEY_3],
	&"build_tool_remove": [KEY_4],
	&"build_tool_test": [KEY_5],
	&"build_free_angle": [KEY_ALT],
	&"build_cancel": [KEY_ESCAPE],
}

## Tastenkürzel mit Strg. Diese nutzen die Tastenbeschriftung statt der
## Position, damit Strg+Z auch auf QWERTZ-Tastaturen auf dem "Z" liegt.
const CTRL_SHORTCUTS := {
	&"undo": [KEY_Z],
	&"redo": [KEY_Y],
}

const MOUSE_BINDINGS := {
	&"zoom_in": [MOUSE_BUTTON_WHEEL_UP],
	&"zoom_out": [MOUSE_BUTTON_WHEEL_DOWN],
	&"camera_drag_rotate": [MOUSE_BUTTON_MIDDLE],
	&"camera_drag_pan": [MOUSE_BUTTON_RIGHT],
	&"interact_primary": [MOUSE_BUTTON_LEFT],
}

## Werkzeuge im Build-Mode. Die Reihenfolge bestimmt Buttons und Zifferntasten.
const BUILD_TOOLS: Array[Dictionary] = [
	{"id": &"rail", "action": &"build_tool_rail", "label": "Schiene"},
	{"id": &"switch", "action": &"build_tool_switch", "label": "Weiche"},
	{"id": &"signal", "action": &"build_tool_signal", "label": "Signal"},
	{"id": &"remove", "action": &"build_tool_remove", "label": "Entfernen"},
	{"id": &"test", "action": &"build_tool_test", "label": "Test"},
]

## Legende je Modus. "actions": Tasten aus der Input Map, "literal": fester Text
## (nur für Dinge ohne eigene Aktion, z.B. Mausbewegung).
const LEGENDS := {
	&"explore": [
		{"actions": [&"move_forward", &"move_left", &"move_back", &"move_right"], "text": "Gehen"},
		{"actions": [&"sprint"], "text": "Laufen"},
		{"actions": [&"jump"], "text": "Springen"},
		{"literal": ["Maus"], "text": "Umsehen"},
		{"actions": [&"zoom_in"], "text": "Abstand"},
		{"actions": [&"toggle_perspective"], "text": "Ich-Perspektive"},
		{"actions": [&"toggle_view"], "text": "Vogelperspektive"},
	],
	&"bird_eye": [
		{"actions": [&"move_forward", &"move_left", &"move_back", &"move_right"], "text": "Kamera bewegen"},
		{"actions": [&"camera_rotate_left", &"camera_rotate_right"], "text": "Drehen"},
		{"actions": [&"zoom_in"], "text": "Zoomen"},
		{"actions": [&"camera_drag_rotate"], "text": "Ziehen: Drehen & Neigen"},
		{"actions": [&"camera_drag_pan"], "text": "Ziehen: Verschieben"},
		{"actions": [&"interact_primary"], "text": "Zug anklicken: mitfahren"},
		{"actions": [&"interact_primary"], "text": "Weiche anklicken: umstellen"},
		{"actions": [&"build_mode"], "text": "Bauen"},
		{"actions": [&"toggle_view"], "text": "Zur Spielfigur"},
	],
	&"build_rail": [
		{"actions": [&"interact_primary"], "text": "Start setzen / Gleis bauen"},
		{"actions": [&"build_free_angle"], "text": "Halten: freier Winkel"},
	],
	&"build_switch": [
		{"actions": [&"interact_primary"], "text": "Auf Gleis: Weiche setzen"},
		{"actions": [&"interact_primary"], "text": "Auf Weiche: umstellen"},
	],
	&"build_signal": [
		{"actions": [&"interact_primary"], "text": "Signal setzen"},
		{"literal": ["Mausseite"], "text": "Fahrtrichtung"},
	],
	&"build_remove": [
		{"actions": [&"interact_primary"], "text": "Gleis / Signal entfernen"},
	],
	&"build_test": [
		{"actions": [&"interact_primary"], "text": "Gleis belegen / freigeben"},
		{"actions": [&"interact_primary"], "text": "Signal: Halt ein / aus"},
	],
	&"build_common": [
		{"actions": [&"build_tool_rail", &"build_tool_switch", &"build_tool_signal", &"build_tool_remove",
			&"build_tool_test"], "text": "Werkzeug"},
		{"actions": [&"move_forward", &"move_left", &"move_back", &"move_right", &"camera_rotate_left",
			&"camera_rotate_right"], "text": "Kamera"},
		{"actions": [&"zoom_in"], "text": "Zoomen"},
		{"actions": [&"undo"], "text": "Rückgängig"},
		{"actions": [&"redo"], "text": "Wiederholen"},
		{"actions": [&"build_cancel"], "text": "Abbrechen"},
		{"actions": [&"build_mode"], "text": "Bauen beenden"},
	],
	&"global": [
		{"actions": [&"time_speed"], "text": "Zeitraffer"},
		{"actions": [&"quick_save"], "text": "Speichern"},
		{"actions": [&"quick_load"], "text": "Laden"},
		{"actions": [&"toggle_help"], "text": "Legende"},
	],
}

const KEY_NAMES := {
	KEY_SPACE: "Leertaste",
	KEY_SHIFT: "Shift",
	KEY_ESCAPE: "Esc",
	KEY_TAB: "Tab",
	KEY_ALT: "Alt",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
}

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Linksklick",
	MOUSE_BUTTON_RIGHT: "Rechte Maustaste",
	MOUSE_BUTTON_MIDDLE: "Mittlere Maustaste",
	MOUSE_BUTTON_WHEEL_UP: "Mausrad",
	MOUSE_BUTTON_WHEEL_DOWN: "Mausrad",
}


## Legende für einen Spielmodus: Liste von {"keys": Array[String], "text": String}.
## Mögliche Modi: &"explore", &"bird_eye", &"build_<werkzeug>".
static func get_legend(mode: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var sources: Array = [mode]
	if String(mode).begins_with("build_"):
		sources.append(&"build_common")
	else:
		sources.append(&"global")
	for source: StringName in sources:
		for entry: Dictionary in LEGENDS.get(source, []):
			var keys: Array[String] = []
			for action: StringName in entry.get("actions", []):
				var label := get_action_label(action)
				if not keys.has(label):
					keys.append(label)
			for literal: String in entry.get("literal", []):
				keys.append(literal)
			rows.append({"keys": keys, "text": entry["text"]})
	return rows


## Name der ersten Taste einer Aktion, wie sie auf der Tastatur steht.
static func get_action_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events := InputMap.action_get_events(action)
	return event_label(events[0]) if not events.is_empty() else "?"


static func event_label(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key:
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			# Beschriftung der Taste im aktuellen Tastaturlayout (z.B. QWERTZ)
			code = key.physical_keycode
			if DisplayServer.get_name() != "headless":
				var mapped := DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
				if mapped != KEY_NONE:
					code = mapped
		var label: String = KEY_NAMES.get(code, OS.get_keycode_string(code))
		if key.ctrl_pressed or key.command_or_control_autoremap:
			label = "Strg+" + label
		return label
	var button := event as InputEventMouseButton
	if button:
		return MOUSE_NAMES.get(button.button_index, "Maus")
	return "?"
