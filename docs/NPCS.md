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
| Sitzen (25–60 s) | SEAT (jede Bank 2, jede Sitzgruppe 4) | umdrehen, vorbeugen, hinsetzen; Beinchen baumeln |
| Stehen / auf den Zug warten (14–35 s) | STAND, Blick zum Gleis | locker oder Hände hinter dem Rücken |
| Uhr ansehen (4–7 s) | CLOCK | Kopf hebt sich zur Uhr |
| Tafel/Aushang lesen (6–10 s) | BOARD | Kopf leicht angehoben |
| Zusammenstehen (25–45 s) | CHAT, paarweise gegenüber | begrüßen, nicken, mit der Hand erzählen |
| Spazieren | – | langsames Gehen zu einem Bahnsteigpunkt |

**Kleine Leerlauf-Gesten** (alle 4–9 s zufällig, nie gleichzeitig): auf die Armbanduhr
schauen, Hände wärmen (abends häufiger), sich strecken, Hände hinter den Rücken nehmen
oder wieder lösen, sich ein wenig umdrehen und umsehen. Sitzend ab und zu ein Blick auf die Uhr.

**Begrüßen:** Begegnen sich zwei Bewohner (unter 3 m), nicken oder winken sie einander
kurz zu – höchstens einmal pro Spielstunde je Paar. Fährt ein Zug ein, winken
freistehende Bewohner manchmal.

**Gepäck:** Reisende tragen meist einen Koffer, Rucksack oder eine Einkaufstasche
(Bewohner laut Steckbrief, `carry`). Beim Sitzen steht der Koffer neben ihnen auf der
Bank, bei Gesten mit der Kofferhand wird er kurz abgestellt.

## Passagier-System (Ein- und Aussteigen)

Der `NpcDirector` führt für jede Tür eines haltenden Zuges eine Warteschlange:

1. **Vorher:** Kündigt sich der eigene Zug an (letzte ~300 m), stellt man sich an die
   Bahnsteigkante des richtigen Gleises, nahe der Zugmitte.
2. **Türen offen:** Wer einsteigen will, wählt die nächste Tür mit der kürzesten
   Schlange und stellt sich **links und rechts neben die Tür** – die Mitte bleibt für
   Aussteigende frei.
3. **Erst aussteigen:** Solange an einer Tür noch jemand aussteigen will, wartet die
   Schlange. Aussteigende kommen **einzeln** aus der Tür und gehen die Trittstufe hinunter.
4. **Verteilen:** Nach dem Aussteigen geht jeder ein paar Schritte in eine zufällige
   Richtung auf dem Bahnsteig, schaut sich kurz um (strecken, Uhr, umsehen) und geht
   dann ins Dorf bzw. nach Hause.
5. **Dann einsteigen:** Der Erste der Schlange geht die Trittstufe hinauf in den Zug,
   die anderen rücken nach. Immer nur eine Person pro Tür auf den Stufen – niemand
   läuft durch den Zug oder durch andere hindurch.
6. **Türen aufhalten:** Solange sich an einer Tür etwas tut, hält der Director die Türen
   offen – höchstens 8 Simulationssekunden (≈ 4 Spielminuten) über die Abfahrtszeit
   hinaus. Wer dann noch wartet, nimmt den nächsten Zug.

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
- **Fortbewegung:** `move(tempo, delta, sprint, beschleunigung, drehrate)` – die Figur
  animiert sich aus der echten Bewegung (siehe „Animationen“ unten).
- **Haltungen:** `set_pose(...)` blendet weich in eine Grundhaltung (Sitzen in ~0,6 s, sonst ~0,35 s),
  `play_gesture(pose, dauer)` spielt eine kurze Geste und kehrt dann zurück.
- **Gepäck:** `carry = SUITCASE | BACKPACK | SHOPPING_BAG`.
- **Schritte:** das Signal `footstep` löst über `FootstepPlayer` ein Knirschen (Schnee)
  oder Klopfen (Bahnsteig, Holz) aus.
- Materialien werden zwischen allen Figuren geteilt (Cache).

## Dateien

```
scripts/characters/character_model.gd     Figur: Aufbau, Gang, Gesten, Blinzeln, Gepäck, Schritte, Ausblenden
scripts/characters/character_appearance.gd Aussehen (Resource): Oberteil, Frisur, Mütze, Winter, Statur
scripts/characters/footstep_player.gd     Schrittgeräusche je nach Untergrund
scripts/npc/npc_profile.gd                Steckbrief (Resource)
scripts/npc/npc_routine.gd                Routine im Tagesablauf (Resource)
scripts/npc/npc.gd                        Bewohner/Reisender: Verhalten und Bewegung
scripts/npc/npc_director.gd               Regie: Reisende, Türwarteschlangen, Begrüßen, Plätze, Boden
scripts/npc/walk_graph.gd                 Fußwegenetz (A*), rodet Bäume auf Wegen
scripts/npc/station_spot.gd               Platz am Bahnsteig (reservierbar), auch Gesprächspaare
scripts/npc/npc_home.gd                   Wohnhaus-Platzhalter
scripts/props/station_prop.gd             Bank, Mülleimer, Blumenkasten, Wegweiser, Aushang, Übergang,
                                          Gepäck, Fahrrad, Schneebank, Sitzgruppe
scripts/audio/ambient_soundscape.gd       Wind, Bahnsteig-Gemurmel, ferne Vögel
scripts/procgen/station_prop_meshes.gd    Meshes dieser Details
assets/characters/*.tres                  Aussehen: Spieler + 6 Bewohner
assets/npcs/*.tres                        Steckbriefe der 6 Bewohner
tests/npc_test.*                          98 Prüfungen (Figuren, Animationen, Wege, Tagesablauf, Halt mit
                                          Trittstufe, Warteschlangen, Klänge, Kameras)
```

## Animationen (Etappe 5)

Alle Animationen sind prozedural und werden weich überblendet – nichts springt.

| Bewegung | Was passiert |
|---|---|
| Idle | Atmen, langsame Gewichtsverlagerung, Umschauen, Blinzeln (alle 2–5 s) |
| Laufen | Schrittfrequenz wächst mit dem Tempo (kurze Beinchen trippeln), Knie heben sich leicht, Hüfte dreht mit, Kopf bleibt ruhig |
| Sprinten | Vorlage des Oberkörpers, angewinkelte, kräftig pumpende Arme, mehr Wippen |
| Beschleunigen | leichtes Vorlehnen in den ersten Schritten |
| Abbremsen / Stoppen | kurzes Zurücklehnen, Schritte federn aus |
| Drehen | in Kurven legt sich die Figur hinein; auf der Stelle kleine Trippelschritte |
| Hinsetzen | zur Bank umdrehen, vorbeugen, Hände auf die Knie, rückwärts sinken |
| Aufstehen | vorbeugen, abstützen, nach vorne hochkommen |
| Umsehen | Kopf wandert, manchmal dreht sich die ganze Figur ein Stück |
| Uhr anschauen | Arm hoch, Blick aufs Handgelenk |
| Hände hinter dem Rücken | ruhige Wartehaltung (gemächliche Bewohner bevorzugen sie) |
| Dehnen | Arme über den Kopf, leicht ins Hohlkreuz, auf die Zehen |
| Hände wärmen | Hände vor der Brust aneinander reiben |
| Begrüßen | Nicken (nah) oder Winken (weiter weg) |
| Erzählen | eine Hand bewegt sich locker vor dem Körper, Kopf nickt mit |
| Trittstufen | Schritt für Schritt hinauf/hinunter, Höhe wird früh im Schritt gewonnen |

Jeder Bewohner geht etwas anders: `gait_energy` (aus Gehtempo und Zufall) macht den Gang
gemütlicher oder munterer. Die Spielfigur macht nach einer Weile Stillstehen gelegentlich
selbst eine kleine Geste (Hände wärmen, Uhr, strecken).
