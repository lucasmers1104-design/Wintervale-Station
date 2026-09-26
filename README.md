# Wintervale Station

Ein gemütliches Low-Poly Eisenbahn- und Dorfbau-Spiel im Winter.
Engine: **Godot 4.7** (GDScript, Renderer Forward+).

Aktueller Stand: **Etappe 2 – Railway Build System** (Gleisbau mit Vorschau, Kurven, Einrasten, Entfernen, Undo).
Das Spiel startet in der Vogelperspektive.

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
| Mausrad | Zoom |
| Mittlere Maustaste ziehen | Drehen & Neigen |
| Rechte Maustaste ziehen | Ansicht ziehen |
| B | Build-Mode ein/aus |
| Tab | Zurück zur Figur |

| Build-Mode | |
|---|---|
| 1 / 2 | Werkzeug Schiene / Entfernen (oder Klick auf die Buttons unten links) |
| Linksklick | Startpunkt setzen, nächster Klick baut das Gleis – danach geht es direkt weiter |
| Rechtsklick / Esc | Aktuelles Gleis abbrechen (zweites Esc beendet den Build-Mode) |
| Alt (halten) | Freier Winkel statt 15°-Raster |
| Strg+Z / Strg+Y | Rückgängig / Wiederholen |

| Allgemein | |
|---|---|
| T | Zeitraffer (×1 → ×10 → ×60) |
| F5 / F9 | Schnellspeichern / Schnellladen |
| F1 | Tastenhilfe ein/aus |
| F11 | Vollbild |
| Esc | Maus freigeben (Klick fängt sie wieder) |

## Automatischer Test

```
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
```

Exit-Code 0 = alle Prüfungen bestanden.

## Weitere Doku

- [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md) – Aufbau, Systeme, Dateien
- [CLAUDE.md](CLAUDE.md) – Projektregeln & Vision
