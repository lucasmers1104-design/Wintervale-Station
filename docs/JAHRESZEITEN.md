# Etappe 9 – Jahreszeiten, Wetter und gemütlicher Welt-Feinschliff

## Zum Ausprobieren

| Taste | Wirkung |
|---|---|
| J | Nächste Jahreszeit – blendet in ca. 6 Sekunden über (Schnee taut fleckig, Laub färbt sich …) |
| K | Nächstes Wetter – gleitet über ca. 1,2 Spielstunden hinüber |
| T | Zeitraffer – Wetter und Jahreszeiten laufen mit |

Das Spiel beginnt wie bisher im Winter.

## Jahreszeiten (`systems/seasons.gd`, Autoload `Seasons`)

Das Jahr folgt den Spieltagen der `WorldClock`: **Frühling 5, Sommer 5, Herbst 5, Winter 8 Tage.** Der Winter ist absichtlich am längsten, weil er die stärkste Stimmung des Spiels ist.

**Übergänge:** Um jede Grenze liegt ein weicher Übergang. Er nimmt 28 % der Jahreszeit ein und liegt je zur Hälfte am Ende der alten und am Anfang der neuen. `get_weights()` liefert die Anteile der vier Jahreszeiten (Summe 1). Alle Werte werden daraus gemischt.

| Wert | Frühling | Sommer | Herbst | Winter |
|---|---|---|---|---|
| Schneedecke | 0 | 0 | 0 | 1 |
| Sonnenaufgang / -untergang | 6:00 / 19:30 | 5:00 / 21:24 | 6:36 / 18:24 | 7:00 / 17:00 |
| Sonnenhöhe mittags | 44° | 58° | 36° | 30° |
| Nebel (Faktor) | 0,8 | 0,5 | 1,1 | 1,0 |
| Wiese | frisches Grün | sattes Grün | Oliv-Ocker | – |
| Laub | Blüten-Hauch | – | Herbstfarben | Schnee |
| Klänge | viele Vögel | Vögel, Grillen nachts | Blätterrauschen | Wintervögel, Kamin |

**Wer die Werte liest:**
- `DayNightCycle`:
  - Die Tageslänge folgt der Jahreszeit. Die Farbverläufe des Wintertags werden auf Sonnenauf- und -untergang umgerechnet.
  - Außerdem Sonnenhöhe, Tönung von Licht und Himmel und Nebel.
- `WorldClock`: Dämmerung, also wann Laternen und Fenster angehen.
- `WeatherSystem`: welches Wetter wie wahrscheinlich ist.
- `AmbientSoundscape`: Vögel, Grillen und Blätter.
- Alle Welt-Shader, über die Shader-Globals.

Die Shader-Globals (Projekt → Shader-Globals) setzt `Seasons` alle 0,1 s:
- `snow_cover` (0..1)
- `season_grass`
- `season_bare`
- `foliage_autumn`
- `foliage_spring`

### Der Schnee-Merker

Alle prozeduralen Modelle speichern im **Alpha-Kanal der Vertexfarbe**, was eine Fläche ist. Gezeichnet wird ohnehin nichts transparent.

| Alpha | Bedeutung | Mit tauender Schneedecke … |
|---|---|---|
| < 0,6 | Schneeauflage (Dächer, Kappen auf Laternen/Bänken/Zäunen, Äste, Schneebänke) | verschwindet fleckig. Darunter liegt das echte Material: Dachziegel, Holz, Nadeln |
| < 0,9 | Bodenschnee (Schotterbett, Pflasterreste, Felsflächen) | wird blanker Boden in `season_bare` |
| sonst | normale Farbe | bleibt |

- Die Logik steckt in `assets/materials/world_snow.gdshaderinc` und wird von allen Welt-Shadern eingebunden:
  - `world_vertex`
  - `foliage_sway`
  - `snow_terrain`
  - `flat_shaded` (mit `snow_layer`)
  - `train_paint`
  - `path`
  - `ice_lake`
- Das Tauen folgt einem Rauschmuster in Weltkoordinaten. Deshalb schmilzt der Schnee in natürlichen Flecken und nicht überall gleichzeitig.
- Felsen haben unter der Schneekappe eine echte Steinfläche, damit nach dem Tauen keine Löcher entstehen.
- Das **Gelände** markiert seine Flächen auf dieselbe Weise:
  - 0,5 = Schnee, wird zu Wiese
  - 0,75 = Boden neben den Gleisen und Seegrund, wird zu Erde
  - 1 = Fels oder Erde

### Was sich sonst mit der Jahreszeit ändert

- **Bäume:**
  - Laubbäume färben sich im Herbst gold, orange und rot. Jeder Baum hat einen eigenen Ton.
  - Im Frühling bekommen sie einen frischen Grünschimmer.
  - Nadelbäume bleiben grün.
  - Der Schnee auf den Ästen taut.
- **See:**
  - Im Winter Eis mit Rissen und Schneeflecken.
  - Im Frühling tauen erst die Mitte und dann die Schollen am Ufer.
  - Im Sommer offenes Wasser mit leichten Wellen.
  - Kleine gefrorene Pfützen am Ufer tauen mit.
- **Schneemann und Schlitten** sinken im Tauwetter sanft zusammen und verschwinden samt Kollision. Im nächsten Winter stehen sie wieder da (`"winter_only"` im Katalog).
- **Schneebänke** am Bahnsteig verlieren ihre Kollision, sobald sie getaut sind.
- **Fußspuren** gibt es nur, solange Schnee liegt. Auf Gras klingen die Schritte weich (`step_grass`).
- Der **Schneestaub** an der fahrenden Lok erscheint nur, wenn Schnee liegt.

## Wetter (`scripts/world/weather_system.gd`, Node `Weather`)

Sieben Wetterlagen. Jede hat eigene Werte für Niederschlag, Wolken, Wind, Nebel, Sonnenlicht und Sterne:

| Wetter | Partikel | Licht & Himmel | Wind | Sicht | Klang |
|---|---|---|---|---|---|
| Sonnig | – | volle Sonne, harte Schatten, fast wolkenlos | leicht | weit | Vögel |
| Bewölkt | – | Sonne gedämpft, weiche Schatten, graue Wolkendecke | mittel | etwas dunstig | Wind in Bäumen |
| Leichter Schneefall | ruhig rieselnde Flocken | bedeckt | schwach | dunstig | leises Schneerieseln |
| Starker Schneefall | dichtes, schräges Schneetreiben | sehr bedeckt, kaum Schatten | stark | stark eingeschränkt | Sturm, Rieseln |
| Klarer Winterabend | – | wolkenlos, goldene Sonne, viele Sterne | fast still | sehr weit | fast still, Kaminfeuer |
| Regen | schräge Tropfenstriche | bedeckt, nasser dunkler Boden mit Glanz | mittel | dunstig | Regen auf Dächern |
| Nebel | – | gedämpft, kühles Grau | still | sehr kurz | Nebelhorn am Bahnhof, gedämpftes Gemurmel |

- **Weicher Wechsel:**
  - Alle Werte gleiten über `transition_hours` (1,2 Spielstunden) zum neuen Wetter.
  - Ein Wetter hält 2,5 bis 6,5 Spielstunden.
- **Auswahl passend zur Jahreszeit** (`CHANCES`):
  - Schneefall nur, wenn Schnee liegt.
  - Kein Regen im tiefen Winter.
  - Der klare Winterabend kommt nur nachmittags.
  - Dasselbe Wetter zweimal hintereinander ist seltener.
- **Nässe** (`wetness`):
  - Regen macht den Boden in etwa 1,5 h nass: dunkler und glänzend auf Wegen, Gelände und Modellen.
  - Danach trocknet er in etwa 5 h.
- **Wind** (`WeatherSystem.wind` und das Global `wind_strength`) bewegt:
  - Baumkronen
  - Fahnen
  - schwingende Laternenköpfe
  - Schneetreiben und Regenwinkel
  - das Windgeräusch
- **Partikel:**
  - `Snowfall` und `Rainfall` fallen in einem hohen Kasten kurz vor der Kamera. So ist das Bild in jeder Ansicht sofort gefüllt.
  - Aus der Vogelperspektive sind die Flocken größer, sonst wären sie unsichtbar.
- Das Wetter wird gespeichert (`save_state`/`load_state`).

## Wege – neue Materialien (`scripts/procgen/path_meshes.gd`, `assets/materials/path.gdshader`)

Alle drei Wegarten wurden neu gebaut, die Schnittstelle ist gleich geblieben. Das Aussehen kommt aus einem Shader mit Mustern **in Weltkoordinaten**. Dadurch laufen Wegstücke, Kurven und Kreuzungen ohne Naht ineinander.

| Weg | Material | Winter |
|---|---|---|
| **Kiesweg** (`path_gravel.tres`, 1,6 m) | Kiesel in zwei Größen (Voronoi), helle und dunkle Steinchen auf sandigem Grund | dünne, fleckige Schneedecke, durch die die Kiesel schauen |
| **Steinweg** (`path_stone.tres`, 2 m) | unregelmäßiges Natursteinpflaster mit Fugen, Randsteine | Schnee in den Fugen, Hauch auf den Steinen |
| **Kleine Straße** (`path_road.tres`, 3,2 m) | festgefahrener Kies, zwei dunklere Fahrspuren | festgefahrener Schnee zwischen den Spuren |

**Geometrie:**
- Ein feines Band (alle 0,4 m, 10 Spalten) folgt dem Gelände. Jeder Punkt liegt über der höchsten Geländestelle ringsum, sodass der Weg nie vom Boden durchstoßen wird.
- **Bankett:**
  - Links und rechts taucht ein 0,6 m breiter Rand sanft unter das Gelände.
  - Er nimmt die Geländefarbe an: Schnee, oder im Sommer die Wiese.
  - Der Wegrand ist unregelmäßig (kleine Buchten statt einer Linie). Es gibt keine harte Kante.
- **Knotenscheiben** an den Enden haben dasselbe Muster, damit Kurven und Kreuzungen nahtlos wirken.
  - Die Fahrspuren der Straße laufen zu den Scheiben hin aus (Vertexfarbe R), damit dort keine Ringe entstehen.
  - Breitere Wegarten liegen minimal höher und decken schmalere ab.
- **Details:**
  - Randsteine am Steinweg.
  - Ein flacher Wall aus geräumtem Schnee, dessen Kammhöhe aus Weltkoordinaten kommt. So treffen sich benachbarte Stücke ohne Stufe. Der Wall taut im Frühling weg.
- **Nässe:** Bei Regen werden die Wege dunkler und glänzen.

## Schnee-Feinschliff

- Schnee ist leicht warm-grau statt reinweiß (`ws_soft_snow`) und glitzert fein im Licht (nur, wo er noch liegt).
- Schnee auf Dächern, Laternen, Bänken, Zäunen (mit kleinen Verwehungen auf beiden Seiten), Schildern, Bahnhofsuhr, Abfahrtstafel, Kisten und dem Schotterbett.
- Fußspuren von Spielfigur und Bewohnern: abwechselnd links und rechts, verwehen in etwa 80 s. Alle Spuren sind ein einziger Zeichenaufruf (MultiMesh).
- Schneewälle an den Wegrändern und Schneebänke am Bahnsteig.

## Gemütliche Details

- Lichterketten zwischen Häusern, zwei neue im Startdorf.
- Warme Fenster (wie bisher) und Kaminrauch mit **Funken**: 5 kleine, glühende Partikel je Kamin, abgeschaltet während des Hausbaus.
- **Schwingende Laternen:** Die Köpfe der Straßenlaternen hängen an einem Drehpunkt (`LampSway`) und pendeln leicht im Wind, jede in ihrem eigenen Takt. Das Licht schwingt mit.
- Baumkronen im Wind, Schneeverwehungen an Zäunen, Eisflächen am See.

## Klang (`scripts/audio/ambient_soundscape.gd`, `sound_library.gd`)

Neue, selbst erzeugte Klänge:
- `tree_wind` – Wind in den Bäumen
- `snow_hiss` – fallender Schnee
- `rain_roof` – Regen auf Dächern
- `fireplace` – Kaminfeuer
- `church_bell` – ferne Kirchenglocke
- `fog_horn` – Nebelhorn am Bahnhof
- `crickets` – Grillen
- `winter_bird_0` und `winter_bird_1` – Wintervögel
- `step_grass` – Schritte auf Gras

**Dynamisch:**
- Die Schleifen folgen Wetter, Wind und Jahreszeit.
- Das Kaminfeuer ist am nächsten Haus zu hören, stärker bei Kälte und am Abend.
- Die Glocke schlägt um 8, 12 und 18 Uhr.
- Das Nebelhorn ist nur bei dichtem Nebel zu hören.
- Bahnhofsgemurmel klingt im Nebel gedämpft.
- Vögel singen tagsüber je nach Jahreszeit; bei Schnee sind es Wintervögel.
- Grillen gibt es in Sommernächten.

## Visuelle Fehlersuche – gefundene und behobene Fehler

| # | Fehler | Ursache | Behebung |
|---|---|---|---|
| 1 | Blasse, fast weiße Dreiecke auf der Sommerwiese | Das Gelände erkannte Schnee an Helligkeit und Blauton. Schattige Schneeflächen lagen knapp darunter und tauten nur zu 20 % | Flächenart als fester Merker im Alpha-Kanal |
| 2 | Gezackter, heller Rand um den See | Grund-Dreiecke, deren Mitte unter Wasser lag, ragten über die Uferlinie. Das Wasser war ein 20-Eck | Seegrund ist nur, was ganz unter Wasser liegt. Wasserfläche mit 40 Ecken reicht unter das Ufer, die Uferlinie entsteht am Gelände |
| 3 | Ringe auf der Straße an Knotenpunkten und Wegenden | Die Fahrspuren hingen vom Abstand zur Mitte ab und wurden auf runden Scheiben zu Kreisen | Spurstärke als Vertexfarbe, läuft zu den Scheiben hin aus |
| 4 | Schneewall am Wegrand als Sägezahn aus blauen Kacheln | Jedes 0,4-m-Stück hatte eine eigene Zufallshöhe | Kammhöhe aus Weltkoordinaten, stufenlos |
| 5 | Kiesweg im Winter wie schmutziger Sand | Zu wenig Schnee auf Kies | dünne, fleckige Schneedecke mit durchschauenden Kieseln |
| 6 | Grüner Busch schaut durch die Schneehaube | Kern und Haube hatten verschiedene Zufallsformen | gleiche Form, Kern etwas kleiner |
| 7 | Schnee auf Abfahrtstafel und Bahnhofsuhr taute nie | eigenes Standardmaterial ohne Jahreszeit | gemeinsames Schneematerial (Schneeauflage) |
| 8 | Lok wirbelte im Sommer Schnee auf | keine Abfrage der Schneedecke | nur bei Schneedecke > 0,3 |
| 9 | Schneefall aus der Vogelperspektive unsichtbar | Flocken entstanden nur über der Kamera, waren winzig und verschwanden im Nebel | hoher Kasten vor der Kamera, Größe nach Kamerahöhe (dafür weniger Flocken), kein Nebel auf Flocken |
| 10 | Nebel sepiabraun statt grau | Nebelfarbe kam vom warmen Horizont | dichter Nebel mischt zu kühlem Grau |
| 11 | Flimmernde Schattenkanten („Schattenkriechen“) | Die Sonne drehte sich jedes Bild minimal, die Schattenkarte zitterte | Sonne und Mond werden in 0,15°-Schritten nachgeführt |
| 12 | Sichtbare Nahtlinie zwischen Schattenstufen | harte Kaskadengrenzen | `directional_shadow_blend_splits` |
| 13 | Z-Fighting der Schneekappen auf Felsen aus der Ferne | Kappe nur 1,2 cm über dem Fels | 2 cm Abstand |
| 14 | Unsichtbare Kollision getauter Schneebänke und des Schneemanns | Kollision blieb im Sommer | Kollision geht mit dem Schnee |
| 15 | Wiese zu grell (Sommer) und wüstengelb (Herbst), Wasser milchig | Farbwerte | sattere Wiesen, Oliv-Ocker im Herbst, dunkleres Wasser mit weniger Spiegelung |

## Leistung

- Die Schnee- und Jahreszeitenlogik läuft komplett im Shader. Kein Mesh wird bei einem Jahreszeitenwechsel neu gebaut.
- `Seasons` rechnet nur alle 0,1 s. `get_value()` mischt nicht mehr bei jedem Aufruf.
- Fußspuren: ein MultiMesh, 360 Plätze, aktualisiert alle 0,5 s.
- Funken: 5 Partikel je Kamin, ab 90 m ausgeblendet.
- Winterobjekte und Schneebänke prüfen nur einmal pro Sekunde.
- Regen und Schnee sind je ein Partikelsystem um die Kamera. Aus der Vogelperspektive werden die Flocken größer, dafür nur halb so viele. Große, halbtransparente Flocken kosteten auf schwacher Grafik sonst zwei Drittel der Bildrate.
- **Messung** (Testrechner Intel HD 520, Kompatibilitäts-Renderer, 15 Uhr, leichter Schneefall):
  - Übersicht: 7,5 fps (Etappe 8: 8,4)
  - Nah: 8,6 fps (Etappe 8: 9,9)
  - Güterbahnhof: 7,5 fps (Etappe 8: 8,5)
  - Draw Calls im Güterbahnhof: 1802 (Etappe 8: 1766)
  - Die Werte schwanken auf diesem Rechner stark, je nachdem, wo die Züge gerade stehen. Die Messung ist nur ein grober Vergleich.

## Neue Dateien

| Datei | Zweck |
|---|---|
| `systems/seasons.gd` | Autoload: Jahreslauf, Übergänge, Shader-Globals, Taste J, Speichern |
| `scripts/world/weather_system.gd` | Wetterlagen, Übergänge, Auswahl, Nässe, Wind, Taste K, Speichern |
| `scripts/world/rainfall.gd` | Regenpartikel |
| `scripts/world/footprints.gd` | Fußspuren im Schnee (MultiMesh-Ringpuffer) |
| `scripts/village/lamp_sway.gd` | schwingende Laternenköpfe |
| `assets/materials/world_snow.gdshaderinc` | gemeinsame Schnee-/Jahreszeitenfunktionen |
| `assets/materials/world_vertex.gdshader` | Welt-Shader für Vertexfarben-Modelle (Schnee-Merker, Eis, Nässe) |
| `assets/materials/path.gdshader` + `path_gravel/stone/road.tres` | Wege-Materialien |
| `assets/materials/ice_lake.gdshader` | See: Eis ↔ Wasser |
| `assets/materials/train_paint.gdshader` | Zuglack mit Klarlack und Schneeflecken |
| `tests/world_test.*` | automatischer Test Etappe 9 |
