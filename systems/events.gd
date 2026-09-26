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
