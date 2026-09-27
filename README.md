# Wintervale Station

Ein gemütliches Low-Poly Eisenbahn- und Dorfbau-Spiel im Winter.
Engine: **Godot 4.7** (GDScript, Renderer Forward+).

Aktueller Stand: **Etappe 5 – Living Passengers & Animation Polish**: Züge rollen sanft aus, fahren eine Trittstufe aus, Fahrgäste stellen sich an den Türen an und steigen nacheinander aus und ein; weiche, lebendige Animationen und eine dezente Klangkulisse aus Wind, Vögeln und Bahnsteig-Gemurmel.
Das Spiel startet in der Vogelperspektive über dem Bahnhof. Unten rechts zeigt eine Legende immer die passenden Tasten.

## Starten

1. Godot 4.7 (Standard-Version, nicht .NET) von https://godotengine.org herunterladen.
2. Godot starten → **Importieren** → `project.godot` in diesem Ordner wählen.
3. Beim ersten Öffnen importiert Godot kurz die Dateien.
4. **F5** (oder ▶ oben rechts) startet das Spiel.

Voraussetzung: Eine Grafikkarte mit aktuellem Vulkan-Treiber (Forward+).

## Steuerung

| Erkunden | |
|---|---|
| WASD / Pfeiltasten | Gehen |
| Shift | Laufen |
| Leertaste | Springen |
| Maus | Umsehen |
| Mausrad | Kameraabstand |
| V | Ich-Perspektive ↔ Verfolgerperspektive |
| Tab | Zur Vogelperspektive |

| Vogelperspektive | |
|---|---|
| WASD | Verschieben |
| Q / E | Drehen |
| Mausrad | Zoom (zur Mausposition hin) |
| Mittlere Maustaste ziehen | Drehen & Neigen |
| Rechte Maustaste ziehen | Ansicht ziehen |
| Linksklick auf Zug | Kamera fährt ruhig mit (WASD oder Esc beendet) |
| Linksklick auf Weiche | Weiche umstellen |
| B | Build-Mode ein/aus |
| Tab | Zurück zur Figur |

| Build-Mode | |
|---|---|
| 1 Schiene | Klick: Start, Klick: Gleis bauen – danach geht es direkt weiter. Rastet an Gleisenden ein. |
| 2 Weiche | Klick auf ein Gleis setzt eine Weiche, dann den Abzweig zur Seite ziehen. Klick auf eine Weiche stellt sie um. |
| 3 Signal | Klick neben ein Gleis. Die Seite bestimmt die Fahrtrichtung (Signal steht rechts vom Zug). |
| 4 Entfernen | Klick auf Gleis oder Signal |
| 5 Test | Klick auf Gleis: belegen/freigeben · auf Signal: Halt ein/aus · auf Weiche: umstellen |
| Alt (halten) | Freier Winkel und freie Länge statt 15°-/Meter-Raster |
| Strg+Z / Strg+Y | Rückgängig / Wiederholen |
| Rechtsklick / Esc | Abbrechen (zweites Esc beendet den Build-Mode) |

| Allgemein | |
|---|---|
| T | Zeitraffer (×1 → ×10 → ×60) |
| F5 / F9 | Schnellspeichern / Schnellladen |
| F1 | Tastenlegende ein-/ausklappen |
| F11 | Vollbild |

## Automatische Tests

```
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/railway_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/train_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/npc_test.tscn
```

Exit-Code 0 = alle Prüfungen bestanden.

## Weitere Doku

- [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md) – Aufbau, Gleisnetz, Stellwerk, Geländeanpassung, Dateien
- [docs/ZUEGE.md](docs/ZUEGE.md) – Züge, Fahrplan, Bahnhofsbetrieb, neue Züge erstellen
- [docs/NPCS.md](docs/NPCS.md) – Figuren, Bewohner, Tagesablauf, neue Bewohner erstellen
- [CLAUDE.md](CLAUDE.md) – Projektregeln & Vision
