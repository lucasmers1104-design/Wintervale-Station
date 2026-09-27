# Figuren, Bewohner und Bahnhofsleben

## Überblick

```
assets/npcs/*.tres  (Steckbriefe: Name, Aussehen, Zuhause, Tagesablauf, Vorlieben)
   │  werden beim Start automatisch geladen
   ▼
NpcDirector (Regie, einmal in main.tscn)
   │  - erzeugt je Steckbrief einen Npc, stellt ihn passend zur Uhrzeit auf
   │  - setzt Reisende ein: vor Abfahrten aus dem Dorf, bei Ankünften aus dem Zug
   │  - vermittelt: Züge & Türen, freie Plätze, Wohnhäuser, Boden unter den Füßen
   ▼
Npc (ein Bewohner oder Reisender)
   │  Verhalten („Gedanken“ alle 0,4 s): Tagesablauf → zum Bahnhof, sitzen,
   │  stehen, Uhr ansehen, Tafel lesen, spazieren, einsteigen, heimgehen
   │  Bewegung: Weg aus dem WalkGraph, folgt dem Boden, weicht der Spielfigur aus
   ▼
CharacterModel (dasselbe Modell wie die Spielfigur)
      Laufen, Atmen, Umschauen, Sitzen, Uhr ansehen, Winken – alles prozedural
```

Beteiligte Szenen-Nodes in `main.tscn`:

| Node | Aufgabe |
|---|---|
| `NpcDirector` | Regie (Skript `npc_director.gd`) |
| `World/WalkGraph` | Fußwege: Wegpunkte (Marker3D) + Verbindungen „A-B“ |
| `World/Village/Home…` | fünf Wohnhaus-Platzhalter (Gartentor, Briefkasten, Lampe) |
| `World/TestArea/Bench…`, `Stand…`, `Clock…`, `Board…` | Bänke und Plätze am Bahnsteig |
| `World/TestArea/Crossing` | Bohlenübergang über Gleis 2 (Zugang zum Mittelbahnsteig) |

## Der Tagesablauf

Jeder Bewohner hat eine Liste von **Routinen** (`NpcRoutine`):

- **STATION_VISIT** `start`–`until`: zum Bahnhof gehen und dort verweilen, danach heim.
- **TRAVEL** ab `start`: zum Bahnhof, mit dem nächsten Zug nach `destination` fahren.
  Kommt bis `until` keiner, geht der Bewohner heim. Zurück kommt er mit dem ersten
  Zug aus `destination`, der nach `return_after` in Wintervale hält – er steigt aus
  und geht nach Hause.

Außerhalb der Routinen ist der Bewohner zu Hause (unsichtbar hinter seinem Gartentor).

Die sechs Bewohner (Stand Etappe 4):

| Name | Zuhause | Tagesablauf |
|---|---|---|
| Greta Berger | Berger | 09:00–11:30 am Bahnhof (sitzt gern), 14:30 nach Nordtal, zurück ab 19:30 |
| Jonas Kellner | Kellner | 07:20 nach Südtal (Pendler), zurück ab 16:00; 19:30–21:00 Züge schauen |
| Lotte Winter | Winter | 12:30–14:15 am Bahnhof (spaziert), 16:00 nach Südtal, zurück ab 19:30 |
| Emil Hofer | Hofer | 10:00–13:00 und 15:00–17:30 am Bahnhof (Bank, Tafel lesen) |
| Mats Hofer (Kind) | Hofer | 14:30–16:30 am Bahnhof (Uhr, spazieren) |
| Ida Sommer | Sommer | 08:30 nach Nordtal, zurück ab 12:30; 17:30–19:00 am Bahnhof |

Dazu kommen **Reisende** ohne Steckbrief (zufälliges, aber stimmiges Aussehen): vor
jeder Abfahrt 0–2 aus dem Dorf, bei jeder Ankunft 0–2 Aussteiger. Höchstens 8 gleichzeitig.

## Verhalten am Bahnsteig

Zwischen den Aufgaben wählt ein Bewohner – gewichtet nach seinen Vorlieben – eine ruhige Beschäftigung:

| Beschäftigung | Platz (`StationSpot.Kind`) | Haltung |
|---|---|---|
| Sitzen (25–60 s) | SEAT (von jeder Bank automatisch 2) | Sitzen, Beinchen baumeln |
| Stehen / auf den Zug warten (14–35 s) | STAND, Blick zum Gleis | Stehen, ab und zu Blick auf die Armbanduhr |
| Uhr ansehen (4–7 s) | CLOCK | Kopf hebt sich zur Uhr |
| Tafel/Aushang lesen (6–10 s) | BOARD | Kopf leicht angehoben |
| Spazieren | – | langsames Gehen zu einem Bahnsteigpunkt |

Fährt ein Zug ein, winken freistehende Bewohner manchmal. Jeder Platz kann nur von einem belegt werden.

**Ein- und Aussteigen:** Hält ein passender Zug mit offenen Türen, geht der Bewohner zur
nächsten Tür (Türen werden gleichmäßig verteilt), hüpft hinein und blendet aus.
Aussteiger erscheinen in der Tür und hüpfen auf den Bahnsteig. Solange jemand ein- oder
aussteigt, hält er die Tür auf – höchstens 5 Simulationssekunden (≈ 2,5 Spielminuten) über
die Abfahrtszeit hinaus, damit der Fahrplan stabil bleibt.

**Rücksicht:** Steht die Spielfigur im Weg, wartet ein Bewohner kurz und geht dann
seitlich vorbei – nur auf eine Seite mit gleich hohem Boden, also nie über die Bahnsteigkante.

**Zeitraffer:** Bewohner gehen höchstens 3× so schnell (sonst wirkt es hektisch).
Reisende, die ihren Zug nicht mehr erreichen können, brechen gar nicht erst auf.

**Speichern/Laden, Zeitsprünge:** Die Bewohner werden nicht gespeichert, sondern aus der
Uhrzeit abgeleitet (`NpcDirector.resume_all()`): Wer laut Tagesablauf am Bahnhof ist,
steht dort; wer verreist ist, ist unterwegs; alle anderen sind zu Hause.

## Einen neuen Bewohner erstellen (ohne Programmieren)

1. **Aussehen:** In Godot `assets/characters/lotte.tres` duplizieren (z.B. `paul.tres`)
   und im Inspector anpassen: Hautfarbe, Oberteil (Karohemd / Pulli / Mantel) und Farben,
   Mütze (keine / Mütze / Bommelmütze / Schiebermütze), Frisur (kurz, Seiten, Bob,
   Dutt, Zopf, Locken), Bart, Brille, Schal, Fäustlinge, Größe (0,74 = Kind), Breite, Kopfgröße.
2. **Steckbrief:** `assets/npcs/lotte.tres` duplizieren (z.B. `paul.tres`) und anpassen:
   - `display_name`: „Paul Brenner“
   - `appearance`: die neue Aussehen-Datei
   - `home_name`: Name eines Hauses (siehe 3.) – mehrere Bewohner dürfen sich ein Haus teilen
   - `walk_speed`: 0,9 (gemächlich) bis 1,4 (zügig)
   - `routines`: Einträge hinzufügen (**New NpcRoutine**), Uhrzeiten als "HH:MM"
   - Vorlieben: Schieberegler für Sitzen, Stehen, Spazieren, Uhr, Tafel
3. **Neues Haus (optional):** In `main.tscn` unter `World/Village` einen `HomeBerger`
   duplizieren, verschieben und `home_name` setzen. -Z des Tors zeigt zur Straße.
   Das Haus braucht keinen eigenen Weg: Bewohner laufen vom Tor zum nächsten Wegpunkt.

Fertig – beim nächsten Start lädt der `NpcDirector` den Steckbrief automatisch.

## Neue Wege und Plätze

- **Wegpunkt:** unter `World/WalkGraph` ein `Marker3D` hinzufügen und in `links` eine
  Verbindung eintragen, z.B. `"Dorfplatz-Brunnen"`. Namen, die mit „Bahnsteig“ beginnen,
  zählen als Spazierziele auf dem Bahnsteig. Auf Wegen wachsen keine Bäume.
- **Platz:** ein `Marker3D` mit dem Skript `station_spot.gd` (unter `World/TestArea`,
  Höhe 0,55 = Bahnsteig), Art wählen und so drehen, dass -Z in die Blickrichtung zeigt.
- **Bank:** ein `StaticBody3D` mit `station_prop.gd`, Art `BENCH` – die Sitzplätze entstehen von selbst.

## Figuren (CharacterModel)

- Großer runder Kopf (~40 % der Höhe), kleiner rundlicher Körper, kurze Beinchen,
  runde Hände (im Winter Fäustlinge), kleine Schuhe, nur Knopfaugen, Näschen und rosige Wangen.
- Weiche, glatt schattierte Formen mit leichtem Randlicht (Spielzeug-/Vinyl-Look).
- **Outfit:** `outfit = WINTER` (Mütze, Schal, Fäustlinge) oder `SUMMER` (ohne, Pulli und
  Mantel werden zum T-Shirt). Grundlage für das spätere Jahreszeiten-System.
- **Haltungen:** `set_pose(Pose.SIT | LOOK_UP | CHECK_WATCH | WAVE | STAND)` blendet in ~0,3 s über.
- **Schritte:** das Signal `footstep` löst über `FootstepPlayer` ein Knirschen (Schnee)
  oder Klopfen (Bahnsteig, Holz) aus.
- Materialien werden zwischen allen Figuren geteilt (Cache).

## Dateien

```
scripts/characters/character_model.gd     Figur: Aufbau, Laufen, Atmen, Haltungen, Schritte, Ausblenden
scripts/characters/character_appearance.gd Aussehen (Resource): Oberteil, Frisur, Mütze, Winter, Statur
scripts/characters/footstep_player.gd     Schrittgeräusche je nach Untergrund
scripts/npc/npc_profile.gd                Steckbrief (Resource)
scripts/npc/npc_routine.gd                Routine im Tagesablauf (Resource)
scripts/npc/npc.gd                        Bewohner/Reisender: Verhalten und Bewegung
scripts/npc/npc_director.gd               Regie: Laden, Reisende, Züge, Plätze, Boden
scripts/npc/walk_graph.gd                 Fußwegenetz (A*), rodet Bäume auf Wegen
scripts/npc/station_spot.gd               Platz am Bahnsteig (reservierbar)
scripts/npc/npc_home.gd                   Wohnhaus-Platzhalter
scripts/props/station_prop.gd             Bank, Mülleimer, Blumenkasten, Wegweiser, Aushang, Übergang
scripts/procgen/station_prop_meshes.gd    Meshes dieser Details
assets/characters/*.tres                  Aussehen: Spieler + 6 Bewohner
assets/npcs/*.tres                        Steckbriefe der 6 Bewohner
tests/npc_test.*                          72 Prüfungen (Figuren, Wege, Tagesablauf, Ein-/Aussteigen, Kameras)
```
