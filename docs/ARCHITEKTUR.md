# Architektur

## Grundprinzipien

- **Systeme** (`systems/`) sind globale Autoloads ohne Grafik-Wissen: Zeit, Eingabe, Speichern, Events.
- **Szenen-Skripte** (`scripts/`) gehören zu Nodes in Szenen und kennen nur, was ihnen per `@export` zugewiesen wird.
- Kommunikation über **Signale**: entweder direkt (`WorldClock.darkness_changed`) oder über den Event-Bus `Events`.
- **Daten und Darstellung getrennt**: `RailNetwork` enthält nur Daten, `RailNetworkView` zeichnet sie.
- **Alle Assets prozedural oder selbst gebaut**: Terrain, Bäume, Steine, Gleise, Prellböcke und Bahnsteig per Code; Figuren aus Primitiven mit eigenem Karo-Shader; Himmel als eigener Sky-Shader.
- Welt-Generatoren sind `@tool`-Skripte: Terrain, Natur, Bahnsteig und Figuren sind auch im Editor sichtbar.

## Szenenbaum (`scenes/main/main.tscn`)

```
Main (main.gd)                   – Spawn, Zeitraffer, Schnellspeichern
├─ WorldEnvironment              – Sky-Shader, Nebel, Glow, SSAO, ACES
├─ DayNightCycle                 – bewegt Sonne/Mond, färbt Himmel & Licht
├─ World
│  ├─ Terrain (LowPolyTerrain)    – Gelände, Kollision, zugefrorener See
│  ├─ Nature (PropScatter)        – Tannen & Steine als MultiMesh
│  ├─ Railway
│  │  ├─ RailNetwork              – Gleisnetz als Graph (Daten)
│  │  └─ RailNetworkView          – Gleismodelle + Prellböcke (Darstellung)
│  └─ TestArea (GroundSnapper)    – Bahnsteig, 4 Laternen, 4 Kisten
├─ Player (PlayerController)     – Figur (CharacterModel) + Kamera
├─ BirdEyeCamera                 – Kamera für Bauen & Management
├─ TransitionCamera              – fliegt beim Ansichtswechsel weich hinüber
├─ ViewModeController            – Ansicht, Eingabe, Mausfang; Start in Vogelperspektive
├─ BuildMode                     – Bauwerkzeuge + Undo/Redo
│  ├─ RailPlaceTool   (&"rail")
│  └─ RailRemoveTool  (&"remove")
└─ HUD                           – Uhr, Hinweise, Tastenhilfe, Build-Panel
```

## Autoloads (`systems/`)

| Name | Aufgabe |
|---|---|
| `Events` | Event-Bus: Ansicht, Hinweise, Speichern/Laden, Build-Mode (`build_mode_changed`, `build_tool_changed`, `build_tool_requested`, `build_status_changed`) |
| `GameInput` | Legt alle Eingabe-Aktionen an (physische Tasten; Strg-Kürzel nach Beschriftung), Mausfang, Vollbild |
| `WorldClock` | Tageszeit, Tage, Zeitraffer; Signale `minute_changed`, `hour_changed`, `darkness_changed` … |
| `SaveManager` | Speichert alle Nodes der Gruppe `saveable` als JSON nach `user://saves/` |

Dazu die Klassen `GameDefs` (Enums, Physik-Ebenen, Konstanten) und `SaveUtils` (JSON-Helfer).

## Gleisnetz (Rail Network)

Das Netz ist ein **Graph aus Knoten und Gleisstücken** (`scripts/rail/`).

```
   RailNode 1 ──── RailSegment 1 ──── RailNode 2 ──── RailSegment 2 ──── RailNode 3
   (END: Prellbock)  (STRAIGHT, 20 m)   (JOINT)        (CURVE, 10 m)      (END: Prellbock)
```

**RailSegment** (ein Gleisstück) besitzt:

| Feld | Bedeutung |
|---|---|
| `id` | eindeutige ID (bleibt auch nach Undo/Laden gleich) |
| `start_node_id` / `end_node_id` | Knoten an Anfang und Ende; Fahrtrichtung läuft immer von Start nach Ende |
| `get_start_position()` / `get_end_position()` | Start- und Endpunkt |
| `get_start_direction()` / `get_end_direction()` | Richtung (Tangente) an beiden Enden |
| `length` | Länge entlang der Kurve in Metern |
| `start_neighbors` / `end_neighbors` / `get_neighbors()` | Nachbar-Gleise |
| `start_connection` / `end_connection` | Verbindungstyp: `END` (offen), `JOINT` (Stoß), `SWITCH` (Weiche, später) |
| `kind` | `STRAIGHT` oder `CURVE` |
| `curve` | Godot-`Curve3D` (kubische Bézierkurve) – Züge können später per Bogenlänge daran entlangfahren |

**RailNode** (Verbindungspunkt) hat `id`, `position` und die `segment_ids` aller angeschlossenen Gleise.
Der Verbindungstyp ergibt sich aus der Anzahl: 1 = offenes Ende, 2 = Stoß, 3+ = Weiche.

**RailNetwork** verwaltet beides:

- Abfragen: `get_segment()`, `get_rail_node()`, `get_neighbors()`, `find_open_node_near()`, `find_segment_near()`, `get_outward_direction()`
- Änderungen nur über `restore_segment(data)` und `remove_segment(id)`. Beide arbeiten mit Dictionaries, dadurch sind sie
  **rückgängig machbar** (Godot `UndoRedo`) und direkt **speicherbar**.
- Signale: `segment_added`, `segment_removed`, `topology_changed` → die Darstellung und die Bau-Marker aktualisieren sich selbst.

**Geometrie:**

- `RailPlanner` berechnet die Form: Gerade (15°-Raster), tangentialer **Kreisbogen** beim Weiterbauen, Hermite-Kurve beim Verbinden zweier Enden.
- `RailPlacementValidator` prüft der Reihe nach: Länge (3–60 m), Radius (≥ 12 m), Richtungsänderung (≤ 90°), Steigung (≤ 5 %), Gelände, See, Kartenrand, Abstand zu anderen Gleisen (≥ 3,9 m) und Hindernisse (Physik-Abfrage auf Ebene „Objekte“).
- Alle Maße und Regeln stehen zentral in `RailConfig`.

**Erweiterung in späteren Etappen:** Weichen hängen einen dritten Gleisstrang an einen Knoten (`SWITCH`), Signale hängen an Knoten oder Positionen auf Segmenten, und die Zug-KI sucht Wege über `get_neighbors()` und fährt an `curve` entlang.

## Bausystem (`scripts/building/`)

- `BuildMode` schaltet mit **B** ein und aus (wechselt dabei in die Vogelperspektive), registriert alle Kind-Nodes vom Typ `BuildTool` und verwaltet `UndoRedo`.
- `BuildTool` ist die Basisklasse: `activate()`, `deactivate()`, `cancel()`, `handle_input()`, `update_tool()`, `set_status()`.
- `BuildContext` bündelt, was Werkzeuge brauchen: Kamera, Terrain, Netz, Darstellung, Undo, Maus → Bodenpunkt.
- Neues Werkzeug (z.B. Weiche): Skript von `BuildTool` ableiten, `tool_id` setzen, als Kind unter `BuildMode` hängen, fertig.

## Figuren (`scripts/characters/`)

- `CharacterAppearance` (Resource) beschreibt das Aussehen: Haut, Karohemd (3 Farben), Hose, Schuhe, Mütze, Frisur, Brille.
- `CharacterModel` baut daraus die Figur im Stil der Referenz: großer runder Kopf, Knopfaugen, Wangen, Mütze mit Umschlag, Karohemd (`plaid.gdshader`), kurze Beinchen. Die Laufanimation ist prozedural.
- Vorlagen: `assets/characters/player_appearance.tres`, `assets/characters/villager_glasses.tres` (für spätere Bewohner).

## Speichersystem

Ein Node wird speicherbar, indem er

1. sich in `_ready()` zur Gruppe `GameDefs.GROUP_SAVEABLE` hinzufügt und
2. `get_save_id()`, `save_state() -> Dictionary` und `load_state(data)` implementiert.

Der Spielstand hat eine `version`. Formatänderungen werden in `SaveManager._migrate()` behandelt.
Aktuell gespeichert: Uhrzeit, Spielfigur, Vogelperspektive-Kamera, aktive Ansicht, Gleisnetz.
Speicherort unter Windows: `%APPDATA%\Godot\app_userdata\Wintervale Station\saves\`.

## Tag-/Nacht-Zyklus

- Ein Spieltag dauert 24 Echtzeit-Minuten (`WorldClock.day_length_minutes`). Start: Tag 1, 15:00 Uhr.
- Kurze Wintertage: Sonnenaufgang 7:00, Untergang 17:00 (`GameDefs`). Die Sonne steht maximal 30° hoch.
- Die Farbstimmungen stehen als Stützpunkte (Stunde → Farbe) in `DayNightCycle._build_gradients()`.
- Laternen schalten sich über `WorldClock.darkness_changed` ab 16:15 Uhr ein und nach 7:45 Uhr aus. Nur Pfosten und Sockel werfen Schatten.

## Terrain

- 256 m × 256 m, flache Mitte (Radius ca. 38 m), Berge am Rand, zugefrorener See im Nordosten.
- `get_height(x, z)` liefert die Höhe überall; `intersect_ray()` findet den Bodenpunkt unter der Maus.

## Physik-Ebenen

| Ebene | Name | Wer | Konstante |
|---|---|---|---|
| 1 | Welt | Terrain, Eis | `GameDefs.LAYER_WORLD` |
| 2 | Spieler | Spielfigur (kollidiert mit 1, 3, 4) | `GameDefs.LAYER_PLAYER` |
| 3 | Objekte | Bäume, Steine, Laternen, Kisten, Bahnsteig – blockieren den Gleisbau | `GameDefs.LAYER_OBJECTS` |
| 4 | Gleise | Schotterbett, Prellböcke (begehbar) | `GameDefs.LAYER_RAILS` |

## Dateien

```
project.godot                          Projekteinstellungen, Autoloads, Jolt Physics, MSAA
systems/
  events.gd                            Event-Bus
  game_input.gd                        Eingabe-Aktionen, Mausfang, Vollbild
  world_clock.gd                       Weltzeit & Zeitraffer
  save_manager.gd                      Speichern/Laden (JSON)
  game_defs.gd                         Enums, Physik-Ebenen, Konstanten
  save_utils.gd                        Vector3 <-> JSON
scripts/
  main/main.gd                         Einstieg der Spielwelt
  main/view_mode_controller.gd         Wechsel Erkunden <-> Vogelperspektive
  player/player_controller.gd          Bewegung, Kamera
  camera/bird_eye_camera.gd            Orbit-/Pan-Kamera für Bauen
  characters/character_appearance.gd   Aussehen einer Figur (Resource)
  characters/character_model.gd        Figur-Generator + Laufanimation (@tool)
  rail/rail_config.gd                  Maße & Bauregeln
  rail/rail_geometry.gd                Kurven-Hilfen (Bézier, Tangenten, Radius)
  rail/rail_node.gd                    Knoten im Gleisnetz
  rail/rail_segment.gd                 Gleisstück im Gleisnetz
  rail/rail_network.gd                 Gleisnetz (Graph, undo-fähig, speicherbar)
  rail/rail_candidate.gd               geplantes, noch nicht gebautes Gleis
  rail/rail_planner.gd                 berechnet Gerade / Bogen / Übergang
  rail/rail_placement_validator.gd     Bauregeln
  rail/rail_segment_view.gd            Modell + Kollision eines Gleisstücks
  rail/rail_network_view.gd            Darstellung des Netzes + Prellböcke
  rail/railway_platform.gd             Bahnsteig (@tool)
  building/build_mode.gd               Build-Mode, Werkzeugwahl, Undo/Redo
  building/build_context.gd            gemeinsamer Zugriff für Werkzeuge
  building/build_tool.gd               Basisklasse für Werkzeuge
  building/rail_place_tool.gd          Werkzeug "Schiene" (Ghost, Einrasten, Kette)
  building/rail_remove_tool.gd         Werkzeug "Entfernen"
  world/…                              Terrain, Natur, Tag/Nacht, GroundSnapper
  procgen/low_poly_builder.gd          Mesh-Bausteine (Dreieck, Quader, Balken, Zylinder …)
  procgen/nature_meshes.gd             Tanne & Stein
  procgen/rail_meshes.gd               Schotter, Schwellen, Schienen, Laschen, Prellbock, Ghost
  procgen/station_meshes.gd            Bahnsteig, Bank, Stationsschild
  props/lantern.gd                     Laterne mit Dämmerungsschaltung
  ui/hud.gd                            HUD inkl. Build-Panel
scenes/
  main/main.tscn                       Hauptszene
  player/player.tscn                   Spielfigur
  camera/bird_eye_camera.tscn          Vogelperspektive
  rail/railway_platform.tscn           Bahnsteig
  props/lantern.tscn, props/crate.tscn Testobjekte
  ui/hud.tscn                          HUD-Layout
assets/
  characters/*.tres                    Figuren-Vorlagen
  materials/sky.gdshader               Himmel
  materials/flat_shaded.gdshader       Facetten-Look für beliebige Meshes
  materials/plaid.gdshader             Karostoff für Hemden
  materials/rail_steel.tres            Schienenstahl
  materials/ghost_*.tres, build_marker.tres  Vorschau grün/rot, Einrast-Marker
  materials/*.tres                     Natur, Eis, Laternenglas, Eisen, Schnee, Holz
  ui/hud_theme.tres                    Schrift, Panels, Buttons
tests/smoke_test.*                     Headless-Funktionstest (66 Prüfungen)
```
