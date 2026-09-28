# Architektur

## Grundprinzipien

- **Systeme** (`systems/`) sind globale Autoloads ohne Grafik-Wissen: Zeit, Eingabe, Einstellungen, Speichern, Events.
- **Szenen-Skripte** (`scripts/`) gehören zu Nodes in Szenen und kennen nur, was ihnen per `@export` zugewiesen wird.
- Kommunikation über **Signale**: direkt (`RailNetwork.topology_changed`) oder über den Event-Bus `Events`.
- **Daten, Logik und Darstellung getrennt**: `RailNetwork` (Daten) → `RailInterlocking` (Sicherungslogik) → `RailNetworkView` (Optik).
- **Alle Assets prozedural oder selbst gebaut**: Terrain, Natur, Gleise, Weichen, Signale, Prellböcke, Bahnsteig per Code; Figuren aus Primitiven mit Karo-Shader; Himmel als Sky-Shader.

## Szenenbaum (`scenes/main/main.tscn`)

```
Main (main.gd)                    – Spawn, Zeitraffer, Schnellspeichern
├─ WorldEnvironment               – Sky-Shader, Nebel, Glow, SSAO, ACES
├─ DayNightCycle                  – Sonne/Mond, Himmel & Licht
├─ World
│  ├─ Terrain (LowPolyTerrain)     – Gelände in 8×8 Kacheln, formbar durch Gleise
│  ├─ Nature (PropScatter)         – Tannen & Steine, folgen Geländeänderungen
│  ├─ Railway
│  │  ├─ RailNetwork               – Gleisnetz als Graph (Daten)
│  │  ├─ RailInterlocking          – Stellwerk: Blöcke, Fahrwege, Signalbilder
│  │  ├─ RailTerrainAdapter        – Gleise formen das Gelände
│  │  └─ RailNetworkView           – Gleise, Prellböcke, Weichen, Signale (Optik)
│  └─ TestArea (GroundSnapper)     – Bahnsteig, Laternen, Kisten
├─ Player / BirdEyeCamera / TransitionCamera / ViewModeController
├─ BuildMode                      – Werkzeuge + Undo/Redo
│  ├─ RailPlaceTool  (&"rail")     1  Schiene
│  ├─ SwitchTool     (&"switch")   2  Weiche
│  ├─ SignalTool     (&"signal")   3  Signal
│  ├─ RailRemoveTool (&"remove")   4  Entfernen
│  └─ SimulationTool (&"test")     5  Testsimulation
└─ HUD                            – Uhr, Hinweise, Werkzeugleiste, Tastenlegende
```

## Autoloads (`systems/`)

| Name | Aufgabe |
|---|---|
| `Events` | Event-Bus: Ansicht, Hinweise, Speichern/Laden, Build-Mode |
| `GameSettings` | Dauerhafte Einstellungen (Legende ein/aus, Vollbild) in `user://settings.cfg` |
| `GameInput` | Trägt die Tasten aus `InputConfig` in die Input Map ein; Mausfang, Vollbild |
| `WorldClock` | Tageszeit, Tage, Zeitraffer |
| `SaveManager` | Speichert alle Nodes der Gruppe `saveable` als JSON nach `user://saves/` (Format-Version 2) |

Dazu: `InputConfig` (alle Tasten, Werkzeuge und Legenden an einer Stelle), `GameDefs` (Enums, Physik-Ebenen), `SaveUtils`.

## Gleisnetz

Graph aus **Knoten** und **Gleisstücken**, dazu Weichen, Signale und Blöcke.

```
 Prellbock    Signal 1                Weiche                          Signal 2
   (END) ────── ● ────────────────────── ◆ ─────── gerader Ast ────────── ● ────── (END)
       Block A  │  Block B (Signal bis Signal, inkl. Weiche und Abzweig)  │ Block C
                                         ╲
                                          ╲ abzweigender Ast ── (END)
```

**RailSegment** (ein Gleisstück):

| Feld | Bedeutung |
|---|---|
| `id` | eindeutige ID (bleibt nach Undo/Laden gleich) |
| `control_points` + `heights` | geometrischer Verlauf: Grundriss als Bézierkurve + Höhenprofil alle ~2 m |
| `curve` | fertige `Curve3D` – Züge fahren später per Bogenlänge daran entlang |
| `get_start_position()` / `get_end_position()` | Start- und Endpunkt |
| `length` | Länge in Metern |
| `start_node_id` / `end_node_id`, `start_connection` / `end_connection` | Anschlüsse: offenes Ende, Stoß oder Weiche |
| `start_neighbors` / `end_neighbors` | benachbarte Gleise |
| `block_id` | zugehöriger Gleisabschnitt |

**RailNode**: Position + angeschlossene Gleise. 1 Gleis = `END`, 2 = `JOINT`, 3 = `SWITCH`.

**RailSwitch**: Stammgleis, zwei Äste (0 = gerade, 1 = abzweigend), Stellung `state`.

**RailSignal**: steht an einem Knoten und sichert die Einfahrt in ein Gleis (`segment_id`). Modus `AUTO` oder `HALT`, Signalbild `STOP`/`CLEAR` (wird nicht gespeichert, sondern immer berechnet).

**Wichtige Abfragen**: `get_next_segments(von_gleis, knoten, weichen_beachten)` liefert die Weiterfahrt – mit Weichenstellung (für Fahrwege und Züge) oder alle Möglichkeiten (für spätere Wegsuche). `get_block_segments()`, `find_*_near()`, `get_signal_transform()`.

**Änderungen** laufen nur über Methoden mit Dictionaries → rückgängig machbar und speicherbar:
`restore_segment`, `remove_segment`, `plan_split`/`apply_split`/`revert_split`, `build_switch`/`unbuild_switch`, `add_signal`/`remove_signal`, `build_signal`/`unbuild_signal`. Zusammengesetzte Aktionen (Gleis teilen + Abzweig bauen) sind eine einzige Undo-Aktion.

## Stellwerk (`RailInterlocking`)

- **Belegung**: `set_segment_occupied()` – heute von der Testsimulation, später von Zügen. Ein Block ist belegt, wenn eines seiner Gleise belegt ist.
- **Fahrweg**: Ein Automatik-Signal bildet einen Fahrweg bis zum nächsten Signal in Fahrtrichtung (oder bis zum Prellbock), folgt der Weichenstellung und reserviert alle berührten **Blöcke exklusiv**.
- **Signalbild**: Grün nur, wenn der Fahrweg reserviert und alle seine Blöcke frei sind. Ein Block kann nie zwei Fahrwegen gehören → ein grünes Signal kann nie einen Konflikt mit einem anderen Fahrweg erlauben (automatisch mit 400 Zufallsschritten getestet).
- **Befahren**: Wird der Fahrweg belegt, fällt das Signal auf Rot; ist er danach frei, wird er aufgelöst.
- **Weichenverschluss**: Umstellen ist verboten, wenn der Block der Weiche belegt ist oder ein befahrener Fahrweg darüber führt. Unbefahrene Automatik-Fahrwege werden beim Umstellen aufgelöst und neu gebildet.

## Geländeanpassung

- `RailProfile` legt die Gleishöhe fest: Gelände abtasten → glätten → Steigung auf 5 % begrenzen. Angeschlossene Enden übernehmen Höhe und Steigung des Nachbargleises (keine Knicke).
- `RailTerrainAdapter` meldet jedes Gleis als **Korridor** an das Terrain (`TerrainDeformer`): im Kern (±2,8 m) eingeebnet, daneben Böschung 1:2 bis ins natürliche Gelände. Wo sich Korridore überlagern, bestimmt das nähere Gleis.
- Das Terrain baut nur die betroffenen Kacheln neu; Bäume und Steine werden auf die neue Höhe gesetzt.
- **Speichern**: Die Anpassung wird aus den gespeicherten Gleisen (inkl. Höhenprofil) exakt rekonstruiert – nach Laden, Entfernen und Undo stimmt das Gelände dadurch automatisch.
- **Bauregeln** (`RailConfig`, `RailPlacementValidator`): Länge 3–60 m, Radius ≥ 12 m, ≤ 90° pro Stück, Steigung ≤ 5 %, Damm/Einschnitt ≤ 3 m, Abstand zum See, Gleisabstand ≥ 3,9 m, Höhenunterschied zu Nachbargleisen, Hindernisse (Physik-Ebene „Objekte“).

## Eingabe & Tastenlegende

`InputConfig` enthält Tastenbelegung, Werkzeugliste und Legenden je Modus. Die Legende (`KeyLegend`, unten rechts) liest die Tastennamen aus der Input Map – sie zeigt also immer die echte Belegung, auch nach Änderungen. Sie wechselt automatisch zwischen Erkunden, Vogelperspektive und jedem Bauwerkzeug; F1 klappt sie ein (Einstellung bleibt gespeichert).

## Physik-Ebenen

| Ebene | Name | Wer |
|---|---|---|
| 1 | Welt | Terrain-Kacheln, Eis |
| 2 | Spieler | Spielfigur (kollidiert mit 1, 3, 4) |
| 3 | Objekte | Bäume, Steine, Laternen, Kisten, Bahnsteig, Signalmasten – blockieren den Gleisbau |
| 4 | Gleise | Schotterbett, Prellböcke |

## Neue und geänderte Dateien in Etappe 2 + 3

```
systems/input_config.gd              NEU  Tasten, Werkzeuge, Legenden – zentral
systems/game_settings.gd             NEU  dauerhafte Einstellungen
systems/game_input.gd                     nutzt InputConfig
systems/save_manager.gd                   Format-Version 2
scripts/world/terrain_deformer.gd    NEU  Gleiskorridore im Gelände
scripts/world/low_poly_terrain.gd         Kacheln, natürliche/angepasste Höhe, Live-Vorschau
scripts/world/prop_scatter.gd             Bäume/Steine folgen dem Gelände
scripts/rail/rail_profile.gd         NEU  Höhenprofil über Hügel
scripts/rail/rail_switch.gd          NEU  Weiche (Daten)
scripts/rail/rail_signal.gd          NEU  Signal (Daten)
scripts/rail/rail_route.gd           NEU  Fahrweg
scripts/rail/rail_interlocking.gd    NEU  Stellwerk
scripts/rail/rail_terrain_adapter.gd NEU  Gleisnetz → Gelände
scripts/rail/rail_switch_view.gd     NEU  Weiche mit Stellanimation
scripts/rail/rail_signal_view.gd     NEU  Hauptsignal mit Lichtwechsel
scripts/rail/rail_network.gd              Weichen, Signale, Blöcke, Teilen, Weiterfahrt
scripts/rail/rail_segment.gd              Höhenprofil, Block, Richtungs-Helfer
scripts/rail/rail_geometry.gd             Höhenprofil-Kurven, Bézier teilen
scripts/rail/rail_candidate.gd            Profil, Abzweig-Infos
scripts/rail/rail_placement_validator.gd  neue Bauregeln
scripts/rail/rail_config.gd               neue Maße
scripts/rail/rail_network_view.gd         Weichen, Signale, Einblendungen
scripts/rail/rail_segment_view.gd         Einblendung für Belegung/Fahrweg
scripts/procgen/rail_meshes.gd            Weichenzunge, Antrieb, Laterne, Signalmast
scripts/building/switch_tool.gd      NEU  Werkzeug Weiche
scripts/building/signal_tool.gd      NEU  Werkzeug Signal
scripts/building/simulation_tool.gd  NEU  Werkzeug Test (Simulation)
scripts/building/rail_place_tool.gd       Profil, Geländevorschau, Maße am Cursor, Meter-Raster
scripts/building/rail_remove_tool.gd      entfernt auch Signale
scripts/building/build_mode.gd            5 Werkzeuge, Weichen per Klick
scripts/building/build_context.gd         Stellwerk + Geländeanbindung
scripts/camera/bird_eye_camera.gd         Zoom zur Mausposition
scripts/ui/key_legend.gd             NEU  Tastenlegende
scripts/ui/hud.gd, scenes/ui/hud.tscn     Legende, Werkzeugleiste
assets/ui/hud_theme.tres                  Stile für Tastenkappen und Legende
scenes/main/main.tscn                     neue Nodes
project.godot                             Autoload GameSettings
tests/railway_test.*                 NEU  93 Prüfungen für Etappe 2 + 3
```

## Etappe 3: Züge und Bahnhofsbetrieb

Ausführlich in [ZUEGE.md](ZUEGE.md). Kurz:

- Neue Nodes unter `World/Railway`: `StarterRailway` (baut beim ersten Start die Strecke Nordtal – Wintervale – Südtal), `TrainDispatcher` (Fahrplan und Züge), `NordtalPortal`/`SuedtalPortal` (Tunnelportale), `Platform1Stop`/`Platform2Stop` (Haltepunkte).
- Bahnhof in `World/TestArea`: 44 m langer Mittelbahnsteig mit Dach und warmen Hängelampen, zwei Bahnhofsuhren, Abfahrtstafel, Laternen. Unter `Main` sorgt `Snowfall` für wechselndes Winterwetter.
- Erweiterungen bestehender Systeme (nichts neu geschrieben):
  - `RailInterlocking`: Fahrwege auf Anforderung eines Zuges (`request_route`, mit Besitzer), Teilauflösung, Zugbelegung getrennt von der Testbelegung.
  - `RailSignal`: neuer Modus `ROUTE` (Zuglenkung – rot, bis ein Zug anfordert).
  - `RailSegment`: Merkmal `tunnel` (formt kein Gelände).
  - `RailProfile`: freie Enden folgen dem Gelände nur im Rahmen der Steigungsgrenze.
  - `PropScatter`: rodet Bäume auf Gleistrassen und an Portalen (Ebene „Natur“ blockiert den Gleisbau nicht mehr).
  - `BirdEyeCamera`: folgt einem angeklickten Zug ruhig.
  - `WorldClock`: ein Spieltag dauert jetzt 48 Minuten (1 Spielminute = 2 Sekunden).
- Physik-Ebenen neu: 5 „Natur“ (Bäume, Steine), 6 „Züge“ (Klickflächen).

## Feinschliff nach Etappe 3: Tunnelberg und gemütliches Licht

- **Tunnelportale sitzen im Berg** (`TunnelMeshes.create_mound`): Der Berg liegt direkt hinter dem Gesims auf der Portalmauer, steigt über der Röhre an und läuft seitlich (±30 m) und nach vorne weit unter dem Gelände aus. Vor der Mauer schneidet ein felsiger Einschnitt die Trasse frei; seine Flanken laufen von den Mauerecken schräg zum Gleis. Obendrauf wachsen ein paar Tannen.
- `TrainPortal`: Berg und Mauer sind jetzt begehbarer Boden (Ebene „Welt“), eine unsichtbare Wand 3 m im Tunnel hält die Spielfigur draußen. `get_mound_height()` liefert die Berghöhe (für Tests/Deko). Die Rodung reicht so weit wie der Berg.
- **Licht** (`DayNightCycle._build_gradients`, `Environment` in `main.tscn`): goldenes Sonnenlicht, cremiger Horizont und Nebel, kühle Lavendel-Schatten („gelbes Licht, kalter Schnee“). Nachts ruhiges, entsättigtes Blau – Mond neutraler, damit Laternen, Bahnsteiglampen und Zugfenster warm herausleuchten. Weniger Bloom-Schleier, leicht angehobene Sättigung.
- **Farben**: Fels und Erde wärmer (Gelände, Tunnelberg, Steine), Tannen in frischerem Grün, Portalmauer aus warmem Sandstein. Zugfenster matter, tagsüber mit einem Hauch Innenlicht (`TrainDispatcher.day_window_glow`). Laternen etwas heller und weiter.
- `tests/train_test.*`: 8 neue Prüfungen (Berg auf der Mauer, Röhre überdeckt, Gleis frei, Kollision) – jetzt 105.

## Etappe 4: Figuren und Bahnhofsleben

Ausführlich in [NPCS.md](NPCS.md). Kurz:

- **Figuren überarbeitet** (`CharacterModel`, `CharacterAppearance`): weichere Proportionen, runde Hände/Fäustlinge, gerollte Mützen, drei Oberteile (Karohemd, Pulli, Mantel), sechs Frisuren, vier Mützen, Bart, Schal, Statur (auch Kinder), Winter-/Sommer-Outfit, ruhige Haltungen (Sitzen, Uhr ansehen, Armbanduhr, Winken), Atmen und Umschauen im Stehen. Schnittstelle unverändert – Spieler und Bewohner nutzen dasselbe Modell.
- **Spielfigur:** Schrittgeräusche (Schnee/Stein), gemütlicheres Tempo (Gehen 2,8 m/s, Laufen 5,4 m/s), sanftere Drehung. Die Kamera hängt nicht mehr starr an der Figur, sondern folgt weich; Mausbewegungen minimal geglättet.
- **Vogelperspektive:** Tastatur-Verschieben und -Drehen fahren sanft an und rollen aus, Zoom gleitet ruhiger, nah herangezoomt neigt sich die Kamera etwas flacher (min. 8 m).
- **Bewohner:** `NpcDirector` + `Npc` + Steckbriefe in `assets/npcs/`; Fußwegenetz `WalkGraph`; Plätze `StationSpot`; Wohnhaus-Platzhalter `NpcHome`.
- **Bahnhofsdetails** (`StationProp`): 6 Bänke, 2 Mülleimer, 3 Blumenkästen, 2 Wegweiser, Fahrplanaushang, Bohlenübergang über Gleis 2, drei Dorflaternen. Die alte, fest eingebaute Bahnsteigbank ist abgeschaltet (`with_bench = false`).
- **Erweiterungen bestehender Systeme (nichts neu geschrieben):**
  - `Train`: `doors_open()`, `get_door_points()`, `hold_doors()`/`release_doors()` (Fahrgäste halten kurz die Tür auf).
  - `TrainCar`: `get_door_centers()`; `TrainMeshes.FLOOR_HEIGHT`.
  - `SoundLibrary`: Schritte `step_snow_0..2`, `step_stone_0..2`.
  - `main.gd`: richtet auch Bohlenübergänge auf die Gleishöhe aus.
  - Physik-Ebene 7 „Bewohner“ (`GameDefs.LAYER_CHARACTERS`); die Spielfigur stößt an Bewohner.
- `tests/npc_test.*`: 72 Prüfungen.

## Etappe 5: Lebendige Fahrgäste und Animations-Feinschliff

Ausführlich in [NPCS.md](NPCS.md) (Animationen, Passagier-System) und [ZUEGE.md](ZUEGE.md) (Halt mit Trittstufe). Kurz:

- **Animationen** (`CharacterModel`, Animationsteil überarbeitet, Aufbau und Schnittstelle erhalten): neue Fortbewegung `move(tempo, delta, sprint, beschleunigung, drehrate)` mit tempoabhängiger Schrittfrequenz, Sprint-Haltung, Vor-/Zurücklehnen beim Anfahren/Bremsen, Kurvenlage, Trippeln beim Drehen, stabilisiertem Kopf, Blinzeln, Gewichtsverlagerung; neue Haltungen und Gesten (`HANDS_BEHIND`, `STRETCH`, `WARM_HANDS`, `NOD`, `TALK`) über `play_gesture()`; weicheres Hinsetzen/Aufstehen; Gepäck (`carry`).
- **Spielfigur:** wird aus der echten Bewegung animiert (Tempo, Beschleunigung, Drehung); kleine Leerlauf-Gesten nach längerem Stillstehen.
- **Zughalt** (`Train`, erweitert): sanftes Ausrollen auf den letzten 10 m, weiches Anfahren, neue Haltephasen `UNLOCKING → STEP_OUT → OPENING → WAITING → CLOSING → STEP_IN`; ausfahrbare, klappbare Trittstufe je Tür (`TrainMeshes`, `TrainCar.set_steps`); `get_door_paths()` für den Weg über die Stufen; Türen höchstens 8 Simulationssekunden aufhalten.
- **Passagier-System** (`NpcDirector`, `Npc`): Warteschlange je Tür, erst aussteigen, dann einsteigen, einer nach dem anderen über die Stufen; Wartende stehen neben der Tür; Aussteiger verteilen sich; Reisende gehen zur Bahnsteigkante, wenn ihr Zug einfährt.
- **Bahnsteig-Leben:** Gesprächsplätze (`StationSpot.Kind.CHAT`, paarweise), Begrüßen im Vorbeigehen, zufällige Leerlauf-Gesten; neue Details (`StationProp`: Gepäckstapel, Fahrrad im Ständer, Schneebänke, Sitzgruppen mit Tisch).
- **Klang:** neue Klänge (Entriegeln, Trittstufe aus/ein, leises Bremsquietschen, Wind, Bahnsteig-Gemurmel, Vögel), gedämpftere Türen; neue Klangkulisse `AmbientSoundscape`. `SoundLibrary.play()` spielt ohne Audioausgabe (headless) nichts ab.
- **Leistung:** Bodenabtastung der Bewohner nur alle zwei Physik-Schritte und nur in Bewegung; Namensschilder nur bei Bedarf; kleine Figurdetails (Augen, Knöpfe, Brille …) ohne Schatten und ab 45 m ausgeblendet; kleine Bahnhofsdetails ab 110 m ausgeblendet; Materialien geteilt. Gemessen auf dem schwachen Entwicklungs-Laptop (Intel HD 520, Kompatibilitätsmodus): gleiche Bildrate wie Etappe 4, in der Nahansicht ~30 % weniger Draw-Calls (767 → 531).
- `tests/npc_test.*`: jetzt 98 Prüfungen.

## Etappe 6: Dorf und Bausystem

Ausführlich in [DORF.md](DORF.md). Kurz:

- **Neu:** `World/Village` (`VillageManager`) mit Häusern (`VillageHouse`), Wegen (`VillagePath`) und Objekten (`VillageObject`); Katalog `VillageCatalog`; Modelle `HouseMeshes` (8 Häuser), `VillageMeshes`, `PathMeshes`; Startdorf `StarterVillage`; Bewohner `VillageResidents`; Bauwerkzeug `VillagePlaceTool` (5 Kategorien, Tasten 6–0); Atmosphäre `BirdFlock`, `AmbientMotes`.
- **Erweiterungen bestehender Systeme (nichts neu geschrieben):**
  - `WalkGraph`: gewichtetes A* mit dynamischem Teil (`set_dynamic`) – gebaute Wege sind günstiger, Bewohner bevorzugen sie; Rückfall aufs feste Netz, wenn etwas nicht verbunden ist.
  - `NpcDirector`: `add_resident`/`remove_resident`, `has_family`, `get_homeless_families`; `get_home` findet auch neu gebaute Häuser (und ignoriert abgerissene).
  - `RailRemoveTool` entfernt auch Dorf-Objekte; `BuildMode`/`BuildContext` kennen das Dorf; `InputConfig`: Tasten 6–0, R (drehen), F (nächstes Objekt), C (Farbe); HUD: zweite Werkzeugzeile und Objektleiste; `Events`: `village_items_changed`, `village_item_requested`.
  - `PropScatter.refresh_area()`; `FootstepPlayer`: Stein auf Wegen; `main.gd` baut das Startdorf.
  - Die Platzhalter-Häuser (`NpcHome`) der fünf Familien sind durch echte Häuser ersetzt; `NpcHome` bleibt als Basisklasse.
- **Spielsymbol** neu (`assets/ui/icon.png`, aus der Vorlage des Creative Directors zugeschnitten, runde Ecken).
- `tests/village_test.*`: 87 Prüfungen; `railway_test` prüft zusätzlich die Dorf-Tasten in der Legende (94).
