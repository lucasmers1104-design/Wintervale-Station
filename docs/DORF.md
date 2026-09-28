# Das Dorf: Bauen, Häuser, Wege und Bewohner

## Überblick

```
Build-Mode (B) → Dorf-Werkzeuge 6–0          RailRemoveTool (4) entfernt auch Dorf-Objekte
   VillagePlaceTool je Kategorie                 │
   (Vorschau, Drehen, Farbe, Linien)             │
          │ place() / remove() mit Undo           │
          ▼                                       ▼
VillageManager (World/Village) ── speichert alles (Speicher-ID "village")
   │  prüft Platzierung, ebnet Gelände, baut Fußwegenetz, verteilt Bewohner, schaltet Licht
   ├── VillageHouse   (8 Hausformen, erbt von NpcHome → Bewohner finden es)
   ├── VillagePath    (Kiesweg, Steinweg, kleine Straße – folgt dem Gelände)
   └── VillageObject  (Bäume, Büsche, Zäune, Laternen, Brunnen, Dorfplatz …)
          │ Aussehen über VillageVisual ← VillageCatalog ← HouseMeshes / VillageMeshes / PathMeshes
          ▼
WalkGraph (Fußwegenetz)   ← gebaute Wege sind "billiger" → Bewohner bevorzugen sie
NpcDirector               ← add_resident() / remove_resident() für die Familien neuer Häuser
TerrainDeformer           ← ebnet Grundflächen von Häusern und Dorfplatz ein (wie bei Gleisen)
```

## Bauen (Build-Mode, Taste B)

| Taste | Kategorie | Inhalt |
|---|---|---|
| 6 | Wohnhäuser | Häuschen, Chalet, Stadthaus, Bauernhaus, Turmhaus, A-Frame-Hütte, Scheunenhaus, Gaubenhaus |
| 7 | Wege | Kiesweg, Steinweg, kleine Straße |
| 8 | Natur | 6 Bäume (hohe Fichte, Tanne, Schneefichte, Birke, Laubbaum, Bäumchen), 4 Büsche (Busch, Stechpalme, Wacholder, Schneebusch), Blumenbeet, Hecke, Zaun, Felsen, Baumstämme, Grasbüschel |
| 9 | Beleuchtung | Laterne, Gartenlampe, Straßenlaterne, Lichterkette |
| 0 | Dekoration | Dorfplatz, Bank, Brunnen, Wegweiser, Fahrradständer, Briefkasten, Pflanzkübel, Schneemann, Schlitten |

- **Objekt wählen:** Button in der Leiste unten links oder **F** (nächstes Objekt).
- **Drehen:** **R** (45°). Häuser drehen sich von selbst mit der Tür zum nächsten Weg, bis man selbst dreht.
- **Farbe:** **C** schaltet die Farbvariante durch (Häuser: 6 Paletten).
- **Setzen:** Linksklick. Die Vorschau ist grün (passt) oder rot, die Statuszeile nennt den Grund.
- **Linien** (Wege, Zäune, Hecken, Lichterketten): Klick = Start, Klick = Ende; danach geht es direkt am Ende weiter. Esc/Rechtsklick beendet die Linie.
- **Entfernen:** Werkzeug **4** – Dorf-Objekte werden rot markiert und per Klick abgerissen.
- **Rückgängig / Wiederholen:** Strg+Z / Strg+Y – auch für Häuser samt Bewohnern.

### Platzierungsregeln

Nicht erlaubt: auf oder zu nah an Gleisen, auf dem Bahnsteig und anderen Bahnhofsobjekten,
im zugefrorenen See, außerhalb des Gebiets, zu steil (Häuser dürfen bis 3 m Höhenunterschied
einebnen), auf/über anderen Häusern oder festen Objekten, Häuser nicht auf Wegen, Wege nicht
durch Häuser, und nichts, das die festen Fußwege der Bewohner (Bahnsteig, Übergang,
Dorfstraße) versperrt. Wilde Bäume unter neuen Objekten werden automatisch gerodet.

## Häuser

Jedes Haus hat eine eigene Form (siehe `scripts/procgen/house_meshes.gd`):

| Haus | Form | Bewohner |
|---|---|---|
| Häuschen | eingeschossig, steiles Satteldach, Vordach, Giebelfenster | 1 |
| Chalet | Giebel zur Straße, weiter Dachüberstand, Holz-Obergeschoss, Balkon, verzierte Ortbretter | 2 |
| Stadthaus | schmal, drei Geschosse, Gesimse, Gaube | 2 |
| Bauernhaus | L-Form, Fachwerk, zwei Dächer, Bank an der Wand, zwei Schornsteine | 2 |
| Turmhaus | runder Eckturm mit Spitzdach und Messingspitze | 2 |
| A-Frame-Hütte | Dach bis zum Boden, große dreieckige Giebelverglasung, Holzterrasse | 1 |
| Scheunenhaus | Mansarddach, Brettschalung, großes Scheunentor-Fenster | 2 |
| Gaubenhaus | Walmdach mit zwei Gauben, Erker, zwei Schornsteine | 2 |

Gemeinsame Details: Natursteinsockel, Sprossenfenster mit Läden und Blumenkästen (Tannengrün,
Beeren), Tür mit Kranz, Messingknauf, Türlampe und Stufe, Schnee auf allen Dachflächen,
Eiszapfen an den Traufen, Rauch aus den Schornsteinen. Die Fenster (eigener Shader) spiegeln
tagsüber den Himmel leicht und leuchten nachts warm – einige bleiben dunkel.

## Wege

- Wegstücke liegen auf dem Gelände (Band mit Schneewall an den Rändern, Steinweg mit Randsteinen,
  Straße mit festgefahrenem Schnee am Rand).
- **Automatisch verbunden:** Start- und Endpunkte rasten an Wegenden (1,6 m) und mitten auf
  bestehenden Wegen ein. An jedem Knoten liegt eine runde Scheibe – so sehen Kreuzungen in
  jedem Winkel sauber aus; breitere Wegarten liegen minimal höher (kein Flackern).
- Auf Wegen klingen Schritte nach Stein statt nach Schnee.

## Bewohner – wie Häuser bewohnt werden

1. **Bekannte Familien zuerst:** Gibt es Bewohner mit Steckbrief (assets/npcs), deren Haus
   fehlt (z.B. weil es abgerissen wurde), ziehen sie in das nächste neue Haus.
2. **Sonst eine neue Familie:** Das Haus bekommt einen Familiennamen und einen Startwert
   (`seed`). `VillageResidents.generate()` erfindet daraus 1–2 Bewohner mit Aussehen, Tempo,
   Vorlieben und Tagesablauf. Gleicher Startwert = gleiche Familie → Bewohner werden **nicht**
   gespeichert, sondern beim Laden wieder abgeleitet.
3. **Tagesablauf:** In jeder Familie pendelt mindestens eine erwachsene Person: morgens
   (06:36–08:36) aus dem Haus, über die Wege zum Bahnhof, mit dem nächsten Zug nach Nordtal
   oder Südtal, nachmittags/abends zurück und nach Hause. Andere besuchen vormittags und/oder
   abends den Bahnhof. Kinder bleiben in der Nähe.
4. **Abriss:** Die Familie zieht aus (verschwindet). Undo bringt Haus und Familie zurück.
5. Höchstens 18 erfundene Bewohner gleichzeitig (gemütliches Dorf statt Stadt).

### Fußwegenetz

`VillageManager.rebuild_walk_network()` erweitert den `WalkGraph` nach jeder Änderung:
Wege (alle 6 m ein Knoten, Kosten ×0,65), der Ring um den Dorfplatz, Anschlüsse an die festen
Wegpunkte (×1,3) und jede Haustür (zum nächsten Weg, sonst zum nächsten festen Wegpunkt).
Anschlüsse führen nie durch Häuser, über Gleise oder durch den See.

## Startdorf

Beim neuen Spiel baut `StarterVillage` hinter dem Bahnhof: Dorfstraße, Dorfplatz (Brunnen,
vier Bänke, Laternen, Pflanzkübel, Bäumchen, Wegweiser, Briefkasten, Fahrradständer),
die Häuser der fünf bekannten Familien (Berger, Kellner, Sommer, Winter, Hofer) mit Kieswegen,
Straßenlaternen, einer Lichterkette, Gärten, Bäumen, Schneemann und Schlitten. Alles davon
lässt sich abreißen oder ergänzen.

## Atmosphäre

- Bäume, Büsche und Hecken wiegen sich leicht im Wind (`foliage_sway.gdshader`, der Stamm bleibt ruhig).
- Lichterketten flattern sanft und flackern warm (`string_lights.gdshader`).
- Rauch aus allen Schornsteinen, weich und mit dem Wind ziehend.
- Nachts gelbliche, weiche Lichtkegel (Farbe 1,0/0,72/0,42), keine Schatten, begrenzte Reichweite.
- Vögel kreisen tagsüber in der Ferne (`BirdFlock`), zur goldenen Stunde schweben warme
  Glitzerpartikel (`AmbientMotes`).

## Ein neues Objekt hinzufügen

1. In `scripts/procgen/village_meshes.gd` eine Funktion schreiben, die das Modell in einen
   `SurfaceTool` baut (Ursprung = Boden, -Z = vorne; Leuchtglas in den `glow`-SurfaceTool).
2. In `VillageCatalog.ITEMS` einen Eintrag ergänzen (Kategorie, Name, Art, Radius, `sway`,
   `solid`, `light`) und in `build_meshes()` die Funktion aufrufen.
3. Fertig – es erscheint automatisch in der Objektleiste der Kategorie.

Neues Haus: in `house_meshes.gd` eine Funktion `_<name>(b)` mit den Bausteinen (`walls`,
`gable_roof_x/z`, `hip_roof`, `gambrel_roof`, `window`, `door`, `chimney`, `dormer`, `turret` …),
`b.footprint(...)` setzen, in `TYPES`, `NAMES`, `CAPACITY` und `build()` eintragen, dazu ein
Katalogeintrag mit `"kind": "house"`.

## Dateien

```
scripts/village/village_manager.gd     Dorf: Objekte, Regeln, Gelände, Wegenetz, Bewohner, Licht, Speichern
scripts/village/village_catalog.gd     alle Dorf-Objekte (Kategorie, Art, Maße) + Mesh-Fabrik
scripts/village/village_house.gd       gebautes Wohnhaus (erbt von NpcHome)
scripts/village/village_path.gd        Wegstück
scripts/village/village_object.gd      Einzel- und Linienobjekte, Dorfplatz
scripts/village/village_visual.gd      Meshes, Lichter, Rauch – auch für die Vorschau
scripts/village/village_footprint.gd   Grundflächen und Überschneidungstests
scripts/village/village_residents.gd   erfundene Familien und ihr Tagesablauf
scripts/village/starter_village.gd     Startdorf beim neuen Spiel
scripts/building/village_place_tool.gd Bauwerkzeug je Kategorie
scripts/procgen/house_meshes.gd        8 Hausformen
scripts/procgen/village_meshes.gd      Natur, Beleuchtung, Deko, Dorfplatz, Zaun, Hecke, Lichterkette
scripts/procgen/path_meshes.gd         Wege auf dem Gelände
scripts/world/bird_flock.gd            Vögel im Hintergrund
scripts/world/ambient_motes.gd         Lichtpartikel im Abendlicht
assets/materials/foliage*.{gdshader,tres}        wiegendes Blattwerk
assets/materials/house_window.{gdshader,tres}    Fenster (Reflexion, warmes Licht)
assets/materials/string_lights.gdshader          Lichterkette
assets/materials/village_glow.tres               leuchtende Lampengläser
assets/ui/icon.png                               Spielsymbol
tests/village_test.*                   87 Prüfungen
```
