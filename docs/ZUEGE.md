# Züge, Fahrplan und Bahnhofsbetrieb

## Überblick

```
Fahrplan (assets/timetables/wintervale.tres)
   │  24 Zeilen: Zugnummer, Strecke, Zuggattung, Gleis, Ankunft, Abfahrt, Halt ja/nein
   ▼
TrainDispatcher (Fahrdienstleiter)
   │  - setzt Züge rechtzeitig im Herkunftsportal ein
   │  - plant den Weg Portal → Bahnsteig → Zielportal (RailPathfinder)
   │  - wählt ein freies Gleis, wenn das geplante belegt ist
   │  - lässt nie mehr Züge Richtung Bahnhof, als es Bahnsteige gibt
   ▼
Train (ein fahrender Zug)                         RailInterlocking (Stellwerk)
   │  - Bremskurven, Kurvengeschwindigkeit      ◄──►  request_route(): Weichen stellen,
   │  - fordert an jedem Signal einen Fahrweg an        Fahrweg exklusiv reservieren
   │  - hält am Bahnsteig, Türen auf/zu              set_train_occupancy(): Belegung
   │  - meldet seine Belegung
   ▼
TrainCar (je Fahrzeug)
      Modell aus TrainMeshes, Drehgestelle folgen dem Gleis, Räder drehen,
      Türen gleiten, Lichter, Schneestaub, Klänge aus SoundLibrary
```

## Ablauf einer Fahrt (z. B. RE 209 Nordtal → Südtal, an 17:42, ab 17:48, Gleis 1)

1. **Einsetzen:** Etwa 15 Spielminuten vor der Ankunft erscheint der Zug tief im Nordtal-Tunnel – nur wenn die Strecke dort frei und nicht für einen ausfahrenden Zug reserviert ist.
2. **Fahrt:** Der Zug beschleunigt sanft (0,45 m/s²), fährt Kurven langsamer (v = √(0,9 · Radius)) und schaut 240 m voraus.
3. **Einfahrsignal:** Rechtzeitig fordert er beim Stellwerk den Fahrweg bis zum Bahnsteig an. Das Stellwerk stellt die Weiche und reserviert Einfahrt und Bahnsteiggleis. Der Bahnhofsgong ertönt.
   Ist Gleis 1 belegt, fährt der Zug automatisch auf Gleis 2 (die Anzeigetafel zeigt das neue Gleis).
4. **Halt:** Der Zug bremst weich, rollt auf den letzten 10 m nur noch mit 30 % der Bremskraft aus (ganz zum Schluss ein leises Quietschen) und steht mittig am Bahnsteig. Dann: Türen entriegeln (leises Zischen) → die Trittstufe fährt unter jeder Tür heraus und klappt ihre untere Stufe herunter (Surren, Klacken) → die Türen öffnen sich (gedämpft) → erst aussteigen, dann einsteigen.
5. **Aufenthalt:** Mindestens 10 Sekunden, und nie vor der planmäßigen Abfahrt.
6. **Abfahrt:** Türen schließen (Warnton), die Trittstufe klappt ein und fährt zurück, das Ausfahrsignal wird angefordert, ein sanftes Horn, dann Anfahrt – die Zugkraft setzt über ~4 s weich ein.
7. **Ende:** Sobald der Zug vollständig im Südtal-Tunnel ist, verschwindet er.

## Sicherheit (automatisch getestet)

- Ein Zug fährt nie an einem Signal vorbei, dessen Fahrweg nicht ihm gehört.
- Ein befahrener Fahrweg wird nie an einen anderen Zug weitergereicht.
- Ein Block kann nie zwei Fahrwegen gehören.
- Zusätzlich fährt jeder Zug „auf Sicht“: Er hält vor jedem fremd belegten Gleis.
- Befahrene Blöcke werden nach dem Räumen einzeln freigegeben (Teilauflösung).

## Zeit

Ein Spieltag dauert 48 Echtzeit-Minuten, eine Spielminute also 2 Sekunden. Der Zeitraffer (T) beschleunigt auch die Züge; die Simulation rechnet dann in kleinen Teilschritten, damit nichts verloren geht.

## Einen neuen Zug erstellen

### Neue Fahrplanzeile (ohne Programmieren)

1. In Godot `assets/timetables/wintervale.tres` öffnen.
2. Im Inspector bei **Entries** auf „+“ klicken und **New TimetableEntry** wählen.
3. Ausfüllen: Zugnummer (z. B. „RE 213“), Strecke („Nordtal → Südtal“), Zuggattung (eine Datei aus `assets/trains/`), Herkunft, Ziel, Gleis, Ankunft, Abfahrt, Halt.
4. Speichern – der Zug fährt ab dem nächsten Spieltag (bzw. sofort, wenn die Zeit noch bevorsteht).

### Neue Zuggattung (anderes Aussehen, andere Wagen)

1. `assets/trains/regional_express.tres` im Dateisystem kopieren (z. B. zu `sonderzug.tres`).
2. Im Inspector ändern:
   - **Consist**: Wagenreihung von vorne nach hinten, z. B. `loco_regional, coach, coach, coach`
     oder `loco_freight, wagon_container, wagon_container, wagon_timber`.
   - **Lackierung**: Grundfarbe, Fensterband, Akzent (Türen, Streifen, Front), Dach.
   - **Fahrverhalten**: Höchstgeschwindigkeit, Beschleunigung, Bremsen, Mindestaufenthalt.
   - **Klang**: Tonhöhe des Horns.
3. In einer Fahrplanzeile als Zuggattung auswählen.

Verfügbare Fahrzeuge: `loco_regional`, `coach`, `loco_freight`, `wagon_timber` (Holz), `wagon_container` (Glas), `wagon_hopper` (Stein), `wagon_flat` (Ziegel), `wagon_stake` (Stahl). Güterwagen kommen beladen an; ihre Ladung steht in `TrainMeshes.CARGO`.

### Neues Fahrzeugmodell (Programmierung)

In `scripts/procgen/train_meshes.gd`:
1. In `SPECS` Länge, Drehgestellabstand und Achsstand eintragen.
2. Eine Funktion `_build_<name>()` schreiben (Bausteine: `_extrude` für gerundete Kästen, `_add_buffers`, `_window_row`, `_door_leaf`, `LowPolyBuilder.add_box` …).
3. In `build_car()` im `match` ergänzen.

### Neuer Herkunfts-/Zielort oder Bahnhof

- **Portal:** Node mit `train_portal.gd` am Tunnelmund des Gleisendes platzieren, `portal_name` setzen; -Z zeigt in den Tunnel. Das Gleisende muss `tunnel_length` Meter dahinter liegen. Mauer, Berg (mit Tannen und Felseinschnitt) und Kollision entstehen automatisch; `variation_seed` ändert die Bergform.
- **Bahnsteiggleis:** Node mit `platform_stop.gd` auf die Gleisachse in Bahnsteigmitte setzen: `station_name`, `platform_number`, `platform_direction` (Richtung zum Bahnsteig).

## Dateien

```
scripts/trains/train_type.gd        Zuggattung (Resource): Wagenreihung, Lackierung, Fahrverhalten
scripts/trains/timetable_entry.gd   Fahrplanzeile (Resource)
scripts/trains/timetable.gd         Fahrplan (Resource)
scripts/trains/train_path.gd        Weg eines Zuges über mehrere Gleise
scripts/trains/rail_pathfinder.gd   Wegsuche (Dijkstra über Gleis + Richtung)
scripts/trains/train.gd             Zugphysik, Signale, Halt, Türen, Klang
scripts/trains/train_car.gd         Fahrzeug: Modell, Drehgestelle, Türen, Lichter
scripts/trains/train_dispatcher.gd  Fahrdienstleiter: Fahrplan, Einsetzen, Gleiswahl, Anzeigedaten
scripts/trains/train_portal.gd      Tunnelportal (Herkunft/Ziel)
scripts/trains/platform_stop.gd     Haltepunkt eines Bahnsteiggleises
scripts/procgen/train_meshes.gd     alle Zugmodelle
scripts/procgen/tunnel_meshes.gd    Steinportal, Tunnelröhre, Berg mit Felseinschnitt
scripts/audio/sound_library.gd      synthetisierte Klänge
scripts/rail/starter_railway.gd     Startstrecke beim ersten Spielstart
scripts/props/departure_board.gd    Anzeigetafel mit Gong
scripts/props/station_clock.gd      Bahnhofsuhr
scripts/world/snowfall.gd           Schneefall mit langsam wechselndem Wetter
assets/trains/*.tres                Zuggattungen RE, RB, GZ
assets/timetables/wintervale.tres   Fahrplan
assets/materials/train_*.tres       Lack (glänzend) und Glas (spiegelnd, nachts warm beleuchtet)
tests/train_test.*                  105 Prüfungen inkl. Sicherheitsüberwachung jedes Frames
```

## Fahrgäste und Trittstufen (ab Etappe 4/5)

Bewohner und Reisende steigen über die Trittstufen ein und aus (siehe [NPCS.md](NPCS.md), Passagier-System). Dafür bietet `Train`:

- `dwell_phase`: `UNLOCKING → STEP_OUT → OPENING → WAITING → CLOSING → STEP_IN` (Dauern: `UNLOCK_TIME` 0,6 s, `STEP_TIME` 1,2 s, `DOOR_TIME` 1,8 s)
- `doors_open()`, `get_door_paths()` (Weg je Tür: innen → Tür → obere Stufe → untere Stufe → Bahnsteig), `get_step_amount()`
- `hold_doors()`/`release_doors()`: Solange sich an einer Tür etwas tut, bleiben die Türen offen – höchstens `MAX_DOOR_HOLD` = 8 Simulationssekunden (≈ 4 Spielminuten) über die Abfahrtszeit hinaus.

Die Trittstufe (`TrainMeshes.create_step_upper/lower`, animiert in `TrainCar.set_steps`) besteht aus einer oberen Stufe mit Führungsschiene und einer über ein Scharnier klappbaren unteren Stufe, beide mit Riffelblech und gelber Sicherheitskante. Beim Ausfahren gleitet die Einheit erst heraus (55 %), dann klappt die untere Stufe herunter.

## Güterverkehr (ab Etappe 8)

Güterzüge fahren nicht mehr durch, sondern halten am **Güterbahnhof** (Gleis 3, Bahnhof
„Güterbahnhof“, Haltepunkt `World/Railway/FreightStop`). Es gibt vier Gattungen mit
unterschiedlicher Länge und Ladung (Holzzug, Baustoffzug, Güterzug, Schüttgutzug).

- Der `FreightYard` hält den Zug mit `Train.hold_departure()` fest, bis der Kran fertig ist
  (Sicherheitsgrenze `Train.MAX_CARGO_HOLD` ≈ 3 Spielstunden), und gibt ihn mit
  `release_departure()` frei. Die Infozeile zeigt dann „wird be- und entladen“.
- Die Ladung sind eigene Stücke am Wagen (`TrainCar.get_cargo()`, `detach_cargo()`,
  `attach_cargo()`, `take_bulk_portion()`), damit der Kran sie sichtbar abheben kann.
- Die Güterlok stößt kleine Abgaswolken aus (beim Anfahren mehr).
- Stellwerk: Steht ein Zug vollständig im Zielabschnitt seines Fahrwegs, wird der Fahrweg
  aufgelöst (Zielgleis-Auflösung) – das Einfahrsignal ist dann für andere Züge frei.

Details, Materialfluss und Fahrplan der Güterzüge: [WIRTSCHAFT.md](WIRTSCHAFT.md).
