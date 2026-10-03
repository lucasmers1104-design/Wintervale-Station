# Master Debugging V2 – Abschlussbericht (Zwischenstand)

Branch `qa/master-debug-v2` · Rückfallpunkt: Tag `qa-v2-baseline` (Commit `9f5f351`, Stand vor allen QA-Änderungen).
Details: [BUG_REGISTER.md](BUG_REGISTER.md) · [VISUAL_COMPARISON.md](VISUAL_COMPARISON.md) · [TEST_RESULTS.md](TEST_RESULTS.md)

## 1. Zusammenfassung

Das Spiel importiert und startet fehlerfrei; alle bestehenden 10 Test-Suiten waren schon vorher grün. Gefunden und behoben wurden 11 Fehler, 2 große Optikfehler und 5 Abweichungen der Menüs von ihren Referenzbildern. Dazu kommen 4 neue Test-Suiten (79 Prüfungen) und reproduzierbare Screenshot-Werkzeuge.

Wichtigste Punkte:
- **Spielstände geschützt:** Tests schrieben bisher in deinen echten Spielstand-Ordner. Jetzt landet alles in einer Sandbox.
- **HUD-Uhr:** Die Zeiger waren aufgemalt und standen immer auf 4:00. Jetzt laufen genau zwei echte Zeiger mit der Spielzeit.
- **Pausenmenü (Esc):** Vorher gab es aus dem Spiel keinen Weg ins Hauptmenü, zu den Einstellungen oder zum Beenden.
- **Menüs wie die Referenzbilder:** Settings (alle 4 Tabs), Load Save, Achievements und Credits sind an die freigegebenen Bilder angeglichen; Rahmen und Symbole stammen aus diesen Bildern.
- **Wintermittag:** Vorher war fast die Hälfte des Bildes überstrahlt, jetzt zeigt der Schnee wieder Form und kühle Schatten.
- **Birken** tragen im Frühling und Sommer Laub.

## 2. Status nach Bereich

| Bereich | Status |
| --- | --- |
| Start, Import, Skripte | PASSED |
| Hauptmenü, Menüseiten, Übergänge | PASSED (automatisch) · Screenshots 1672×941 geprüft |
| HUD Geld/Tag/Uhr | PASSED |
| Pausenmenü | PASSED |
| Einstellungen mit echter Wirkung | PASSED (Anzeige/Monitor-Wechsel: manuell prüfen) |
| Spielstände, Sandbox, defekte Dateien | PASSED |
| Achievements (per Reise, keine Doppel-Freischaltung) | PASSED (bestehende + neue Tests) |
| Gleise, Weichen, Signale, Züge | PASSED (bestehende Suiten, 232 Prüfungen) – kein neuer Befund |
| Türen und Trittstufen | PARTIALLY VERIFIED – Stufen ausgefahren im Bild geprüft, Ablauf per train_test |
| NPCs, Dorf, Wirtschaft, Feste | PASSED (bestehende Suiten) |
| Jahreszeiten, Licht, Schnee | PARTIALLY VERIFIED – im Compatibility-Renderer geprüft |
| Audio | NOT VERIFIED (nicht hörbar hier) |
| Leistung auf dem Spiel-PC | NOT VERIFIED |

## 3. Offene Punkte / nächste Schritte

1. **Sprache (UX-001, Entscheidung CD):** Menüs englisch (wie Referenzbilder), Spiel und Pausenmenü deutsch.
2. **New Game** hat kein eigenes Referenzbild – bitte liefern, dann gleiche ich die Seite genauso an.
3. Alte Testdatei `phase_12_journey_probe_6906` im echten Spielstand-Ordner: im Spiel unter *Load Save → Delete* löschen (ich lösche keine Spielerdaten).
4. Phasen D–H im Detail (Modell-für-Modell-Review Zug/Güterwagen/Häuser, NPC-Animationen, Wege im Winter) sind noch nicht vollständig durchgegangen – nächster Durchgang.

## 4. Manuelle Testanleitung

1. Spiel starten → Hauptmenü. **Settings** öffnen: alle vier Tabs mit den Referenzbildern vergleichen. Unter *Graphics* Bloom aus → *Apply* → im Spiel wirkt das Licht flacher.
2. **Achievements** und **Load Save** öffnen und mit den Referenzbildern vergleichen. **Credits** ebenso.
3. **Continue** → im Spiel oben die Leiste ansehen. **T** drücken (Zeitraffer): Die kleinen Uhrzeiger laufen mit, die Stellung passt zur Digitalzeit.
4. **Esc** drücken → Pausenmenü: Züge stehen still. *Einstellungen* → *Back*. *Hauptmenü* → Rückfrage erscheint.
5. **J** (Jahreszeit) bis Sommer: Birken im Dorf haben Laub.
6. Mittags im Winter die Vogelperspektive: Schnee sollte Struktur zeigen, nicht reinweiß sein.
