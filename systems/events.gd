## Globaler Event-Bus (Autoload "Events").
##
## Systeme kommunizieren über diese Signale statt über direkte Referenzen.
## So bleiben sie unabhängig voneinander austauschbar – z.B. weiß das HUD
## nichts über die Kamera, es hört nur auf view_mode_changed.
extends Node

@warning_ignore_start("unused_signal")

## Zwischen Erkunden und Vogelperspektive wurde gewechselt.
signal view_mode_changed(mode: GameDefs.ViewMode)
## Eine kurze Hinweisnachricht soll angezeigt werden (z.B. "Zeit ×10").
signal notification_requested(text: String)
## Ein Spielstand wurde geschrieben.
signal game_saved(slot: String)
## Ein Spielstand wurde geladen und auf die Welt angewendet.
signal game_loaded(slot: String)

## Der Build-Mode wurde ein- oder ausgeschaltet.
signal build_mode_changed(active: bool)
## Im Build-Mode wurde ein anderes Werkzeug gewählt (z.B. &"rail", &"remove").
signal build_tool_changed(tool_id: StringName)
## Die UI möchte ein Werkzeug wählen (z.B. per Klick auf einen Button).
signal build_tool_requested(tool_id: StringName)
## Hinweis des aktiven Werkzeugs, z.B. warum eine Platzierung ungültig ist ("" = alles gut).
signal build_status_changed(text: String)
## Ein Dorf-Werkzeug zeigt seine Objekte (für die Auswahlleiste im HUD).
signal village_items_changed(category: StringName, items: Array[String], selected: String)
## Die UI möchte ein Dorf-Objekt wählen (Klick auf einen Button).
signal village_item_requested(item_id: String)
## Kosten des Objekts unter dem Mauszeiger ({"money", "<material>": Menge}; leer = ausblenden).
signal build_cost_changed(cost: Dictionary)
## Esc wurde gedrückt, ohne dass etwas anderes es brauchte: Pausenmenü öffnen.
signal pause_menu_requested
## Das Notizbuch soll auf- oder zugehen (z.B. per Button im HUD); page "" = zuletzt offene Seite.
signal notebook_requested(page: String)
signal region_station_requested(station_id: int)

## Die Kamera folgt jetzt diesem Zug (null = keinem).
signal followed_train_changed(train: Node)

## Hinweis, womit die Spielfigur gerade interagieren kann (z.B. "Mit Greta sprechen"; "" = nichts).
signal interaction_prompt_changed(text: String)
## Großes Fest-Banner in der Bildmitte (Titel, Untertitel, Bildname aus assets/ui/bubbles).
signal event_banner_requested(title: String, subtitle: String, icon: String)
## Etwas Schönes ist passiert – fürs Notizbuch (Seite "Feste": Dorfchronik).
signal chronicle_entry(text: String, icon: String)
