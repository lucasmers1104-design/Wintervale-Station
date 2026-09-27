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

## Die Kamera folgt jetzt diesem Zug (null = keinem).
signal followed_train_changed(train: Node)
