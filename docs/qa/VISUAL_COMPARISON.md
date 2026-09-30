# Visueller Abgleich – Master Debugging V2

Alle Aufnahmen sind echte Godot-Renderings dieses Rechners (Intel HD 520, **GL-Compatibility-Renderer**). Auf dem Spiel-PC (Forward+) wirken Licht und Schatten etwas reicher (u. a. SSAO).
Werkzeuge: `tests/qa/menu_capture.gd` (alle Menüseiten in 1672 × 941 = Referenzgröße), `tests/qa/visual_capture.gd` (feste Kamera, Uhrzeit, Jahreszeit, Wetter).

## Grundsatz nach CD-Vorgabe (30.09.)

> „Verändere nichts am GUI-Style. Nur wenn das GUI nicht genau so aussieht wie die Referenzbilder, darf es verbessert werden, damit es genau so aussieht.“

Deshalb gilt: Jede GUI-Änderung in diesem Durchgang gleicht eine Seite **an ihr freigegebenes Referenzbild** an. Rahmen, Knöpfe, Symbole und Häkchen werden **aus den Referenzbildern selbst** geschnitten (reproduzierbare Werkzeuge unter `tools/`), nicht neu gezeichnet. Seiten ohne Referenzbild (New Game, Lösch-Dialog) wurden nicht umgestaltet.
Den zwischenzeitlich umgestalteten Notizbuch-Knopf im HUD habe ich auf das ursprüngliche Aussehen zurückgesetzt (nur eine Mindestgröße bleibt, damit er nicht auf wenige Pixel schrumpft).

## Menüseiten gegen Referenz

| Seite | Referenz | Vorher (Abweichung) | Nachher |
| --- | --- | --- | --- |
| Hauptmenü | `main_menu/*` | entsprach der Referenz | unverändert (nur Versionsnummer zeigt echte Projektversion v0.1.0 statt „v1.0.0“) |
| Settings · Graphics | `settings_graphics.png` | schlichte Liste ohne Symbole, Knopf-Schalter „● On“, Hinweis „Renderer effects are unavailable“ | Zeilen mit Symbolen und Trennlinien, Pill-Schalter, Pergament-Auswahlfelder mit Winkel; **Shadow Quality, Bloom, Particle Density** wie in der Referenz – mit echter Wirkung (Test `settings_effects_test`). Nicht übernommen: Texture Quality und View Distance (keine echte Entsprechung im Spiel, daher keine Attrappe) |
| Settings · Audio | `settings_audio.png` | Liste ohne Symbole | Symbole, Trennlinien, goldene Regler wie Referenz. Voice/Announcements nicht übernommen (gibt es im Spiel nicht) |
| Settings · Controls | `settings_controls.png` | vier Tasten-Knöpfe in einer Zeile | zwei Spalten „Camera Settings“ / „Key Bindings“ mit Symbolen und hellen Tastenfeldern wie Referenz |
| Settings · Gameplay | `settings_gameplay.png` | Liste ohne Beschreibungen; **Back/Reset/Apply-Klickflächen lagen 41 px zu hoch** (Knöpfe sitzen auf dieser Vorlage tiefer) | Zeilen mit Symbol, Titel und Beschreibungszeile wie Referenz; Klickflächen auf die gemessenen Knopfkanten gesetzt |
| Load Save | `load_save.png` | einfache Karten, 150-px-Knöpfe, „New Journey“-Leiste | Karten mit Rahmen aus der Referenz, neueste Reise gold hervorgehoben, Kalender-/Jahreszeiten-/Zug-/Einwohner-/Uhrsymbole, Load/Delete-Knöpfe mit Symbol, Karte „Empty Slot · New Save“ mit Skizze, Stempel „Good Journeys Ahead“ bleibt sichtbar |
| Achievements | `achievements.png` | Listenzeilen, dunkle gesperrte Siegel | „Total Progress“-Zeile (live), Kategorien mit Symbol, Motto und Zähler, 3er-Kartenraster mit Rahmen aus der Referenz, gesperrte Siegel silbergrau, Häkchen bzw. Balken + Zahl, Detailkarte im Bilderrahmen |
| Credits | `credits.png` | große Pergamentfläche verdeckte Symbole, Linien und Skizzen | Referenz 1:1; nur die erfundenen Beispielnamen sind entfernt (`tools/clean_credits_names.gd`) und durch belegte Angaben ersetzt |
| Ladescreen | `loading_screen_reference.png` | entsprach der Referenz | unverändert |
| HUD-Leiste | `hud_status_bar.png` | aufgemalte Uhr zeigte immer 4:00 | Leiste unverändert, nur die gemalten Zeiger entfernt; zwei echte Zeiger laufen mit der Spielzeit |

Bewusst verbleibende Unterschiede zur Referenz (keine Attrappen): erfundene Beispielwerte der Bilder (z. B. „28 / 60 Achievements“, „Busy Platform“) sind durch echte Spieldaten ersetzt; Optionen ohne Spielfunktion fehlen. Bei mehreren Reisen erscheint unter den Achievements eine Reise-Auswahl (in der Referenz nicht vorhanden, für per-Reise-Fortschritt nötig).

## Spielwelt vorher/nachher

| Motiv | Messung vorher | Nachher | Bewertung |
| --- | --- | --- | --- |
| Bahnhof Wintermittag | 41,3 % ausgebrannte Pixel | Weißpunkt 2,0: Varianten 1,6 → 8,1 %, 2,4 → 0,5 % | Schnee zeigt wieder Facetten und lavendelfarbene Schatten |
| Wege Nahaufnahme | 23,1 % | 1,6 → 1,9 %, 2,4 → 0,4 % | Wegkanten und Pflaster lesbar |
| Abend / Nacht | 0,1–0,2 % | ≈ 5–8 % dunkler | warme Lichtinseln unverändert |
| Birke im Sommer/Frühling | kahl („toter Baum“) | Laub | Winter unverändert kahl, Herbst golden |
| HUD 09:41 / 16:00 / 23:27 / 00:00 | Uhr zeigt immer 4:00 | Zeiger = Digitalzeit | geprüft im Test und im Bild |
