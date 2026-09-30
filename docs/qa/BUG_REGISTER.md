# Bug-Register – Master Debugging V2

Stand: 2026-09-29 · Branch `qa/master-debug-v2` · Rückfallpunkt: Tag `qa-v2-baseline` (Commit `9f5f351`).

Schweregrade: `BLOCKER` · `HIGH` · `MEDIUM` · `LOW` · `COSMETIC`.
Status: `FIXED` (behoben und geprüft) · `OPEN` (offen, begründet) · `CD` (Entscheidung des Creative Directors nötig).

| ID | Schwere | Bereich | Kurzbeschreibung | Status |
| --- | --- | --- | --- | --- |
| BUG-001 | HIGH | Speichern / Tests | Automatische Tests schrieben in den echten Spielstand-Ordner des Spielers | FIXED |
| BUG-002 | HIGH | HUD | Kleine Analoguhr war aufgemalt und zeigte immer 4:00 | FIXED |
| BUG-003 | HIGH | Menüs | Kein Pausenmenü: aus dem Spiel kein Weg ins Hauptmenü, zu Einstellungen oder zum Beenden | FIXED |
| BUG-004 | MEDIUM | HUD | Notizbuch-Knopf lag außerhalb der Leiste und war nur ~4 px groß | FIXED |
| BUG-005 | MEDIUM | Achievements / Speichern | Jeder Fortschritt löste 12 s später ein komplettes Speichern aus – auch bei ausgeschaltetem Autosave | FIXED |
| BUG-006 | MEDIUM | Neues Spiel | Geld, Lager und Zeitraffer der vorigen Reise wären in eine neue Reise übernommen worden (Autoloads nie zurückgesetzt) | FIXED |
| BUG-007 | MEDIUM | Pause | Spiel-Timer (Fest, NPC-Gesten, Koffer-Quest, Hinweise) liefen während der Pause weiter | FIXED |
| BUG-008 | LOW | Uhr | `set_time(23:27)` wurde als „23:26“ angezeigt (Gleitkomma-Abrundung) | FIXED |
| BUG-009 | LOW | Tests | `economy_test` „walked home with their suitcases“ war zufallsabhängig (Familienname/Tagesablauf) | FIXED |
| BUG-010 | COSMETIC | Hauptmenü | Versionsanzeige fest „v1.0.0“, Projekt ist 0.1.0 | FIXED |
| VIS-001 | HIGH (visuell) | Licht | Wintermittag: 41–45 % aller Pixel ausgebrannt, Schnee ohne Modellierung | FIXED |
| VIS-002 | MEDIUM (visuell) | Natur | Birken blieben im Frühling/Sommer kahl („tote Bäume“) | FIXED |
| BUG-011 | MEDIUM | Settings | Gameplay-Seite: Klickflächen von Back/Reset/Apply lagen 41 px über den gemalten Knöpfen | FIXED |
| GUI-001 | MEDIUM (visuell) | Settings | Alle vier Settings-Seiten wichen deutlich von ihren Referenzbildern ab (keine Symbole, Linien, Pill-Schalter, Controls einspaltig) | FIXED |
| GUI-002 | MEDIUM (visuell) | Load Save | Spielstandkarten wichen von der Referenz ab (Rahmen, Symbole, Knöpfe, Empty Slot) | FIXED |
| GUI-003 | MEDIUM (visuell) | Achievements | Listenansicht statt Kartenraster der Referenz; gesperrte Siegel dunkel statt silbergrau | FIXED |
| GUI-004 | LOW (visuell) | Credits | Pergamentfläche verdeckte Symbole, Linien und Skizzen der Referenz | FIXED |
| GUI-005 | LOW (visuell) | Settings | Aufklappliste der Auswahlfelder im grauen Engine-Standard statt Pergament | FIXED |
| UX-001 | COSMETIC | Sprache | Hauptmenü, Einstellungen und Achievements englisch, Spiel-HUD/Notizbuch deutsch | CD |

---

## Details

### BUG-001 – Tests schrieben in echte Spielstände (HIGH, FIXED)
- **Reproduktion:** `godot --headless --path . -s res://tests/phase12_journey_test.gd` ausführen, danach `%APPDATA%/Godot/app_userdata/Wintervale Station/saves/` ansehen.
- **Erwartet:** Tests berühren keine Spielerdaten. **Tatsächlich:** Testreisen wurden dort angelegt; die Datei `phase_12_journey_probe_6906.json` im echten Ordner stammt aus einem früheren Testlauf.
- **Ursache:** `SaveManager.SAVE_DIR` war eine Konstante; Einstellungen und Tastenbelegung ebenso fest auf `user://`.
- **Fix:** `systems/qa_sandbox.gd` – wird eine Szene aus `res://tests/` oder `res://_probe/` gestartet (oder `-- --qa-sandbox`), leiten `SaveManager.save_dir`, `GameSettings.storage_path` und `GameInput.storage_path` nach `user://qa_sandbox/` um.
- **Prüfung:** Alle Suiten laufen; Byte-Vergleich der echten Spielstände vor/nach allen Testläufen: identisch. `pause_menu_test` prüft `save_dir` enthält `qa_sandbox`.
- **Hinweis:** Die alte Testdatei `phase_12_journey_probe_6906.json` wurde **nicht** gelöscht (Spielerdaten werden nie automatisch gelöscht). Sie kann im Spiel über *Load Save → Delete* entfernt werden.

### BUG-002 – Aufgemalte HUD-Uhr (HIGH, FIXED)
- **Reproduktion:** Spiel starten, Zeit ≠ 16:00 (z. B. 09:41): Digitalanzeige 09:41, Analoguhr zeigt 4:00.
- **Ursache:** Die freigegebene Leiste `hud_status_bar.png` enthält eine gemalte Uhr mit festen Zeigern.
- **Fix:** `tools/generate_hud_clock_face.gd` erzeugt `hud_status_bar_clean.png`: Zeigerpixel werden entlang ihres Kreises interpoliert, der verdeckte 12-Uhr-Strich entsteht aus dem gespiegelten 6-Uhr-Strich. Alles außerhalb des Zifferblatts bleibt pixelgleich. `GameHUD.HudClockHands` zeichnet genau zwei Zeiger (Stunde, Minute) aus `WorldClock.time_of_day`. Original bleibt als `hud_status_bar.png` erhalten (Revert: Konstante `STATUS_BAR_ART` in `scripts/ui/hud.gd` zurückstellen).
- **Prüfung:** `tests/qa/hud_test.gd` (28 Prüfungen: 00:00, 03:00, 06:30, 09:41, 12:00, 16:00, 23:27 – Winkel und Digitaltext). Gerenderte Nahaufnahmen 00:00, 09:41, 16:00, 23:27 visuell geprüft.

### BUG-003 – Kein Pausenmenü (HIGH, FIXED)
- **Reproduktion:** Spiel starten, Esc drücken: nichts passiert (außer Maus freigeben). Kein Weg zurück ins Hauptmenü, zu den Einstellungen oder zum Beenden (nur Alt+F4).
- **Fix:** `scripts/ui/pause_menu.gd` im Stil des Hauptmenüs (Holzlogo, Pergament, echte Buttons): Weiterspielen, Spiel speichern, Einstellungen (vorhandene Settings-Seiten, wirken sofort), Hauptmenü und Spiel beenden – beide mit Rückfrage *Speichern & …* / *Ohne Speichern* / *Abbrechen*. Die Welt steht still (`SceneTree.paused` + `WorldClock.paused`). Esc-Kette: Notizbuch/Bauwerkzeug → Maus freigeben/Mitfahren beenden → Pausenmenü. Das Vorschaubild beim Speichern zeigt die Welt, nicht das Menü.
- **Prüfung:** `tests/qa/pause_menu_test.gd` (21 Prüfungen inkl. Uhr und Züge stehen still, schnelles Öffnen/Schließen, Speichern, Einstellungen + Esc, Rückfrage + Esc, Hauptmenü, Welt freigegeben, neue Reise danach). Screenshots `pause_menu`, `pause_confirm`.

### BUG-004 – Notizbuch-Knopf unsichtbar (MEDIUM, FIXED)
- **Ursache:** Der Button hatte keine Mindestgröße und schrumpfte auf die Breite seines (leeren) Textes.
- **Fix:** Aussehen und Position unverändert wie vom CD angelegt (flaches Notizbuch-Symbol rechts an der Leiste), nur Mindestgröße 43 × 43 Leisteneinheiten. Eine zwischenzeitliche Umgestaltung als Medaillon wurde auf CD-Wunsch zurückgenommen.
- **Prüfung:** `hud_test`: sichtbar, groß genug, öffnet das Notizbuch.

### BUG-005 – Achievements überschrieben den Spielstand (MEDIUM, FIXED)
- **Reproduktion:** Autosave aus, Zug ankommen lassen → 12 s später wird der Spielstand gespeichert.
- **Ursache:** `Achievements._set_progress` setzte bei jedem Fortschritt `_save_delay = 12.0`.
- **Fix:** Nur eine **Freischaltung** speichert sofort – und nur mit eingeschaltetem Autosave. Fortschritt wird mit dem nächsten normalen Speichern gesichert (per-Reise-Design unverändert).

### BUG-006 – Autoload-Zustände zwischen Reisen (MEDIUM, FIXED)
- **Ursache:** `Economy` wurde nur beim Programmstart zurückgesetzt; Zeitraffer blieb erhalten. Wurde erst durch den neuen Weg „Pausenmenü → Hauptmenü → Neues Spiel“ erreichbar.
- **Fix:** `main_menu.gd`: neue Reise setzt Economy, Uhr (Tag 1, 15:00, ×1) zurück; Laden setzt Economy vor dem Anwenden zurück (ältere Spielstände ohne Wirtschaftsdaten).
- **Prüfung:** `pause_menu_test`: Geld 123456 + Zeitraffer gesetzt → Hauptmenü → neue Reise: Geld 3000, ×1.

### BUG-007 – Timer liefen in der Pause weiter (MEDIUM, FIXED)
- **Ursache:** `get_tree().create_timer(t)` ist standardmäßig `process_always`.
- **Fix:** Spiel-Timer in Fest, Marktständen, Zugereignissen, Güterbahnhof, NPCs und Achievement-Hinweis mit `process_always = false`.

### BUG-008 – Minutenrundung (LOW, FIXED)
- `WorldClock.get_hour/get_minute` leiten sich aus einer gemeinsamen Minutenzahl mit Epsilon ab (`_total_minutes`).

### BUG-009 – Zufallsabhängiger Test (LOW, FIXED)
- Wer zuerst ins neue Haus kommt, lebt danach normal weiter (z. B. Abendspaziergang). Der Test merkt sich jetzt pro Person, ob sie ihr Zuhause erreicht hat.

### VIS-001 – Ausgebrannter Wintermittag (HIGH visuell, FIXED)
- **Messung** (Anteil Pixel ≥ 97 % Helligkeit, GL-Compatibility, 1280×720): `station_noon` 41,3 %, `hud_1200` 45,2 %, `paths_close` 23,1 %.
- **Fix:** ACES-Weißpunkt `tonemap_white = 2.0` im Welt-Environment. Varianten 1,6 und 2,4 wurden gemessen und verglichen (siehe `VISUAL_COMPARISON.md`).
- **Grenze:** Gemessen im Compatibility-Renderer dieses Rechners; auf dem Spiel-PC (Forward+) bitte visuell gegenprüfen.

### VIS-002 – Kahle Birken im Sommer (MEDIUM visuell, FIXED)
- **Fix:** Birken bekommen Laubbüschel mit neuem Vertex-Merker (Alpha 0,7). `foliage_sway.gdshader` zeigt sie nur, wo die Schneeauflage geschmolzen ist – Winterform unverändert, Frühling frisch, Herbst golden über die vorhandene Herbstlogik.

### UX-001 – Sprachmischung (COSMETIC, CD)
- Hauptmenü, Settings-Seiten, Achievement-Karten und -Hinweise sind englisch (so in den freigegebenen Referenzbildern), Spiel-HUD, Legende, Notizbuch und Pausenmenü deutsch. Entscheidung nötig: eine Sprache oder Umschalter. Nicht eigenmächtig geändert.
