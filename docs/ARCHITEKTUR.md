# Architektur

## Grundprinzipien

- **Systeme** (`systems/`) sind globale Autoloads ohne Grafik-Wissen: Zeit, Eingabe, Speichern, Events.
- **Szenen-Skripte** (`scripts/`) gehören zu Nodes in Szenen und kennen nur, was ihnen per `@export` zugewiesen wird.
- Kommunikation über **Signale**: entweder direkt (`WorldClock.darkness_changed`) oder über den Event-Bus `Events`.
- **Alle Assets prozedural oder selbst gebaut**: Terrain, Bäume, Steine per Code; Figur, Laterne, Kiste aus Primitiven mit einem Flat-Shading-Shader; Himmel als eigener Sky-Shader.
- Welt-Generatoren sind `@tool`-Skripte: Terrain und Natur sind auch im Editor sichtbar.

## Szenenbaum (`scenes/main/main.tscn`)

```
Main (main.gd)                 – Spawn, Zeitraffer, Schnellspeichern
├─ WorldEnvironment            – Sky-Shader, Nebel, Glow, SSAO, ACES
├─ DayNightCycle               – bewegt Sonne/Mond, färbt Himmel & Licht
│  ├─ Sun
│  └─ Moon
├─ World
│  ├─ Terrain (LowPolyTerrain)  – Gelände, Kollision, zugefrorener See
│  ├─ Nature (PropScatter)      – Tannen & Steine als MultiMesh
│  └─ TestArea (GroundSnapper)  – Testobjekte: 4 Laternen, 4 Kisten
├─ Player (PlayerController)   – Figur + eigene Kamera (Third/First Person)
├─ BirdEyeCamera               – Kamera für Bauen & Management
├─ TransitionCamera            – fliegt beim Ansichtswechsel weich hinüber
├─ ViewModeController          – schaltet Ansicht, Eingabe und Mausfang um
└─ HUD                         – Uhr, Hinweise, Tastenhilfe
```

## Autoloads (`systems/`)

| Name | Aufgabe |
|---|---|
| `Events` | Event-Bus: `view_mode_changed`, `notification_requested`, `game_saved`, `game_loaded` |
| `GameInput` | Legt alle Eingabe-Aktionen an (physische Tasten), Mausfang, Vollbild |
| `WorldClock` | Tageszeit, Tage, Zeitraffer; Signale `minute_changed`, `hour_changed`, `darkness_changed` … |
| `SaveManager` | Speichert alle Nodes der Gruppe `saveable` als JSON nach `user://saves/` |

Dazu die Klassen `GameDefs` (Enums & Konstanten) und `SaveUtils` (JSON-Helfer).

## Speichersystem

Ein Node wird speicherbar, indem er

1. sich in `_ready()` zur Gruppe `GameDefs.GROUP_SAVEABLE` hinzufügt und
2. `get_save_id()`, `save_state() -> Dictionary` und `load_state(data)` implementiert.

Der Spielstand hat eine `version`. Formatänderungen werden in `SaveManager._migrate()` behandelt.
Aktuell gespeichert: Uhrzeit, Spielfigur, Vogelperspektive-Kamera, aktive Ansicht.
Speicherort unter Windows: `%APPDATA%\Godot\app_userdata\Wintervale Station\saves\`.
`res://saves/` ist für spätere Vorlagen reserviert (z.B. Startszenarien).

## Tag-/Nacht-Zyklus

- Ein Spieltag dauert 24 Echtzeit-Minuten (`WorldClock.day_length_minutes`). Start: Tag 1, 15:00 Uhr.
- Kurze Wintertage: Sonnenaufgang 7:00, Untergang 17:00 (`GameDefs`). Die Sonne steht maximal 30° hoch, dadurch gibt es lange, warme Schatten.
- Die Farbstimmungen stehen als Stützpunkte (Stunde → Farbe) in `DayNightCycle._build_gradients()`.
- Im Editor zeigt `DayNightCycle.editor_preview_hour` jede Tageszeit als Vorschau.
- Laternen schalten sich über `WorldClock.darkness_changed` ab 16:15 Uhr ein und nach 7:45 Uhr aus.

## Terrain

- Gitter mit 128 × 128 Zellen à 2 m (256 m × 256 m), zufällig versetzte Punkte, eine Farbe pro Dreieck.
- Flache Mitte (Radius ca. 38 m) für den späteren Bahnhof und das Dorf, Berge am Rand, ein zugefrorener See im Nordosten.
- `terrain.get_height(x, z)` liefert die Höhe überall, auch für Platzierungen.
- Gleicher `terrain_seed` ergibt dieselbe Welt.

## Physik-Ebenen

| Ebene | Name | Wer |
|---|---|---|
| 1 | Welt | Terrain, Eis, Bäume, Steine, Testobjekte |
| 2 | Spieler | Spielfigur (kollidiert mit Ebene 1) |

## Dateien

```
project.godot                        Projekteinstellungen, Autoloads, Jolt Physics, MSAA
icon.svg                             Projekt-Icon (selbst gezeichnet)
systems/
  events.gd                          Event-Bus
  game_input.gd                      Eingabe-Aktionen, Mausfang, Vollbild
  world_clock.gd                     Weltzeit & Zeitraffer
  save_manager.gd                    Speichern/Laden (JSON)
  game_defs.gd                       Enums & Konstanten
  save_utils.gd                      Vector3 <-> JSON
scripts/
  main/main.gd                       Einstieg der Spielwelt
  main/view_mode_controller.gd       Wechsel Erkunden <-> Vogelperspektive
  player/player_controller.gd        Bewegung, Kamera, Laufanimation
  camera/bird_eye_camera.gd          Orbit-/Pan-Kamera für Bauen
  world/low_poly_terrain.gd          Terrain-Generator (@tool)
  world/prop_scatter.gd              Verteilt Bäume & Steine (@tool)
  world/ground_snapper.gd            Setzt Objekte auf den Boden
  world/day_night_cycle.gd           Licht, Himmel, Nebel (@tool)
  procgen/low_poly_builder.gd        Mesh-Bausteine (Dreieck, Kegel, Zylinder, Box, Stein)
  procgen/nature_meshes.gd           Tanne & Stein als Mesh
  props/lantern.gd                   Laterne mit Dämmerungsschaltung
  ui/hud.gd                          HUD-Logik
scenes/
  main/main.tscn                     Hauptszene
  player/player.tscn                 Spielfigur (Low-Poly aus Primitiven)
  camera/bird_eye_camera.tscn        Vogelperspektive
  props/lantern.tscn                 Laterne
  props/crate.tscn                   Holzkiste mit Schnee
  ui/hud.tscn                        HUD-Layout
assets/
  materials/sky.gdshader             Himmel: Verlauf, Sonne, Mond, Sterne
  materials/flat_shaded.gdshader     Facetten-Look für beliebige Meshes
  materials/*.tres                   Natur (Vertexfarben), Eis, Laternenglas, Eisen, Schnee, Holz
  ui/hud_theme.tres                  Schrift & Panel-Stil des HUD
  models/, audio/                    noch leer (folgen in späteren Etappen)
saves/                               reserviert für Vorlagen
tests/smoke_test.*                   Headless-Funktionstest
```
