# Testergebnisse – Master Debugging V2

Rechner: Windows 10, Intel HD Graphics 520, Godot 4.7.2 stable (Konsole), Renderer lokal GL Compatibility.
Alle Tests laufen in der **QA-Sandbox** (`user://qa_sandbox/`); echte Spielstände und Einstellungen wurden vor und nach allen Läufen byteweise verglichen: **unverändert**.

## Befehle

```
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 res://tests/<name>_test.tscn        # Szenen-Tests
godot --headless --path . --fixed-fps 60 -s res://tests/<name>_test.gd       # SceneTree-Tests
godot --path . -s res://tests/qa/menu_capture.gd -- <ordner>                   # Menü-Screenshots 1672×941
godot --path . --resolution 1672x941 -s res://tests/qa/visual_capture.gd -- <ordner> [motiv …]
```

## Baseline (vor allen Änderungen, Commit 9f5f351)

| Suite | Ergebnis |
| --- | --- |
| smoke 66 · railway 94 · train 138 · npc 98 · village 94 · economy 116 · world 63 · festival 73 · phase12_menu 29 · phase12_journey 23 | alle bestanden, 0 Engine-Fehler, 0 Warnungen |
| Import | fehlerfrei |

## Endstand

| Suite | Prüfungen | Ergebnis |
| --- | --- | --- |
| smoke | 66 | bestanden |
| railway | 94 | bestanden |
| train | 138 | bestanden |
| npc | 98 | bestanden |
| village | 94 | bestanden |
| economy | 115–116 | bestanden (Anzahl hängt von der zufälligen Haushaltsgröße ab) |
| world | 63 | bestanden |
| festival | 73 | bestanden |
| phase12_menu | 29 | bestanden |
| phase12_journey | 23 | bestanden |
| **qa/hud** (neu) | 28 | bestanden – Zeigerwinkel = Digitalzeit bei 00:00, 03:00, 06:30, 09:41, 12:00, 16:00, 23:27 |
| **qa/pause_menu** (neu) | 21 | bestanden – Pause stoppt Uhr und Züge, Speichern, Einstellungen, Rückfrage, Hauptmenü, neue Reise ohne Altlasten |
| **qa/settings_effects** (neu) | 19 | bestanden – Bloom, Schatten, Partikel, Lautstärke, Tagesdauer, Kameraempfindlichkeit wirken wirklich |
| **qa/stress** (neu) | 11 | bestanden – 5 Lade-Zyklen, 3× Welt ↔ Hauptmenü |

## Messwerte (nur dieser Rechner, headless = ohne GPU)

| Messung | Wert |
| --- | --- |
| Welt geladen | 3014 Nodes, 7621 Objekte, 311 Ressourcen, 230 MB statischer Speicher |
| Zeitraffer ×60, CPU pro Frame | Ø 92 ms, max. 149 ms (Simulation in 40 Teilschritten; schwacher Laptop-Prozessor) |
| Audio-Bus-Zuordnung (alle 3 s) | 7,7 ms über 3014 Nodes |
| 5× Laden | keine Node-Anhäufung (3254 → 2689), 0 verwaiste Nodes |
| 3× Welt ↔ Hauptmenü | Hauptmenü danach identisch: 79 Nodes, 0 verwaiste Nodes, 193 MB |

**Nicht gemessen:** echte FPS auf dem Spiel-PC (Forward+), GPU-Zeiten, Draw Calls. Eine FPS-Zusage ist daher nicht möglich.

## Manuelle Prüfung nötig

- Klang (Lautstärken, Loops, Übergänge) – hier nicht hörbar.
- Forward+-Optik (SSAO, Schatten) auf dem Spiel-PC.
- Vollbild-/Auflösungswechsel mit echtem Monitor (10-Sekunden-Rückfrage).
