# Etappe 9.5 – Premium-Zug und Welt-Feinschliff

## Neuer Regionaltriebzug (`scripts/procgen/railcar_meshes.gd`)

RE und RB fahren jetzt als moderner, dreiteiliger Triebzug: `railcar_front`, `railcar_middle`, `railcar_rear`. Die alte Lok mit Wagen (`loco_regional`, `coach`) gibt es weiterhin. Man kann sie in jeder Zuggattung wieder eintragen.

**Form: weiche Kurven statt Kisten**
- **Wagenkasten:** gerundeter Querschnitt mit 18 Stützpunkten je Seite. Die Flanken sind leicht eingezogen, das Dach gewölbt, die Unterkante abgerundet. Die Normalen werden gemittelt, sodass der Kasten weich schattiert ist.
- **Bugnase:** ein Loft durch 21 Stationen. Das Dach senkt sich zur großen, umlaufenden Panorama-Frontscheibe. Darunter sitzen ein Bug in der Hauptfarbe mit durchlaufender Zierlinie und eine runde Bugschürze mit Räumerkante.
- **Frontscheibe:** eine dunkle Scheibe, die wenig spiegelt, mit schwarzem Rahmen. Ihre Oberkante läuft als glatte Linie quer übers Dach. Der Führerstand dahinter bleibt dunkel.
- **Fenster:** ein schwarzes Fensterband, darauf Scheiben mit abgeschrägten Ecken. Die Flächen folgen der Wölbung des Kastens.
- **Türen:**
  - Zwei Doppeltüren je Seite und Wagen. Jeder Flügel hat ein großes Fenster mit Rahmen, Gummidichtung, Griffleiste und einen grün leuchtenden Türtaster.
  - Unter der Tür sitzt eine Einstiegskante in der Akzentfarbe.
  - Hinter geöffneten Türen ist ein warm beleuchteter Einstiegsraum zu sehen, statt eines schwarzen Lochs.
- **Weitere Details:**
  - Führerstandstür mit Griffstange.
  - Seitenschürzen zwischen den Drehgestellen, Unterflurtechnik.
  - Gerundete Dachaufbauten (Klimageräte, Kühler mit Lüfter).
  - Faltenbalg-Übergänge, Scharfenbergkupplung an der Bugspitze.
- **Lichter:**
  - Bugspitze: zwei Scheinwerfer im schwarzen Lampenband.
  - Oben über der Frontscheibe: ein dritter Scheinwerfer.
  - Hinterer Endwagen: rote Schlusslichter.
  - Nicht leuchtende Lampen (Schlusslicht vorne, Scheinwerfer hinten) sind als glänzendes Glas zu sehen.
- **Zielanzeige:** orange Leuchtschrift mit Zugnummer und Ziel, z.B. „RE 3  Nordhafen“, an beiden Enden.
- **Hinterer Endwagen:** der gespiegelte vordere Wagen, sodass der Zug an beiden Enden gleich aussieht.
- **Neue Drehgestelle (alle Züge):**
  - Geformte Seitenrahmen, Achslager mit Deckeln und Schraubenfedern.
  - Luftfeder, Dämpfer und Bremseinheiten.
  - Räder mit blanker Lauffläche, Radscheibe, Nabe und drei Löchern, an denen man das Drehen sieht.
  - Bremsscheiben auf der Achse.
- **Lack:** Klarlack auf der Farbe, dunkle Teile (Fahrwerk, Gummi, Rahmen) sind matt. So spiegeln sie nicht mehr beige den Himmel.

## Zug-Animationen (`train_car.gd`, `train.gd`)

| Animation | Umsetzung |
|---|---|
| Anfahren / Bremsen | Der Wagenkasten nickt: beim Bremsen senkt sich die Front leicht (max. 0,7°), beim Anfahren geht sie zurück. Die Werte werden aus der tatsächlichen Beschleunigung weich gefiltert. |
| Kurvenfahrt | Der Kasten neigt sich nach außen (max. 2°). Die Neigung berechnet sich aus dem Winkel zwischen den beiden Drehgestellen und der Geschwindigkeit. |
| Fahrt | leichtes Wiegen und Federn, stärker mit der Geschwindigkeit |
| Türen und Trittstufen | wie bisher (entriegeln → Stufe fährt aus → Türen öffnen …). Die Türflügel schwingen mit dem Kasten mit. |
| Innenlicht | Beim Halt am Bahnsteig wird es warm hell, nachts bleibt es warm an, bei Tagfahrt ist es gedämpft. Das Licht blendet weich über (Instanz-Parameter `cabin` im Fenster-Shader). Hinter den Scheiben zeichnen sich Sitzlehnen ab. |
| Front-/Rücklicht | Vorne weiß, hinten rot. Die jeweils anderen Lampen bleiben dunkel. Im Stand werden die Scheinwerfer abgeblendet. |

Der Wagenkasten hängt dafür an einem neuen Node „Body“ (Federung). Drehgestelle und Räder folgen weiter exakt dem Gleis.

## Güterzüge

- **Güterlok:**
  - Wartungstüren mit Griffen am Vorbau, runde Lampengehäuse und Nummernschild.
  - Sonnenblenden über den Führerhausfenstern, Doppel-Signalhorn.
  - Sandkästen, gelbe Aufstiegstritte mit Griffstangen, Kraftstofftank.
- **Alle Flachwagen** (Holz, Container, Ziegel, Stahl):
  - Lackierte Außenlangträger mit Rippen, in Oxidrot, Graublau oder Tannengrün.
  - Rangiertritte und Griffe an allen Ecken, Handbremsrad.
  - Bremszylinder, Luftbehälter und Bremsschläuche.
- **Trichterwagen:** Leitern an den Stirnwänden, kräftiger Obergurt und dieselbe Ausrüstung.

## Bahnhof

- **Bahnsteigdach:**
  - Klassisches Zierbrett aus spitzen Brettern unter der Traufe, mit grüner Deckleiste.
  - Dachrinne und Schneewulst an der Traufkante.
  - Eiszapfen, die im Frühling tauen.
- **Gleisnummern:** blaue Schilder mit „2 | 1“ hängen an beiden Enden des Dachs.
- **Bahnsteig:**
  - Blindenleitstreifen mit Rillen.
  - Dunkle Schattenfuge unter der überstehenden Bahnsteigkante.
  - Geländer an beiden Rampen (Pfosten, Handlauf, Knieleiste, Schnee).
  - Vier Pflanzkübel aus Holzdauben mit kleinen verschneiten Tannen.
- Unverändert und weiterhin passend: Abfahrtstafel, Uhr, Bänke, Laternen und Schilder.

## Dorf und Wege

- **Wege liegen auf dem echten Gelände:**
  - Das Gelände besteht aus flachen Dreiecken im 2-m-Raster und liegt in Mulden etwas über der glatten Höhenfunktion.
  - Neu ist `LowPolyTerrain.get_surface_height()`: sie liefert die Höhe der gezeichneten Dreiecke. Daran richten sich die Wege aus.
  - Zusätzlich wird ein 3×3-Raster abgetastet. So kann keine Geländespitze mehr durch einen Weg stoßen.
- **Einmündungen:**
  - Ein schmaler Weg, der auf einer Straße oder dem Dorfplatz endet, hört kurz hinter deren Rand ohne eigene Knotenscheibe auf.
  - An Kreuzungen und Einmündungen entstehen keine Schneewälle und Randsteine mehr.
  - Anliegende Wege werden beim Bauen und Abreißen automatisch angepasst.

## Gefundene und behobene Fehler

| # | Fehler | Ursache | Behebung |
|---|---|---|---|
| 1 | Heller Keil auf der Dorfstraße, sobald die Laterne leuchtet | Eine Spitze des Geländes (Dreieck im 2-m-Raster) stieß durch die Straße. Der Weg kannte nur die glatte Höhenfunktion. | `get_surface_height()` und 3×3-Abtastung. Der Test prüft jetzt auch das Innere der Dreiecke gegen die gezeichnete Oberfläche. |
| 2 | Knotenscheibe eines Hauszugangs schaute mit Schnee-Bankett durch die Straße | Der Kiesweg endete mitten auf der Straße | Wege enden am Rand breiterer Wege ohne Scheibe |
| 3 | Schneewall und Randsteine quer über Einmündungen | Die Wälle kannten die anderen Wege nicht | Kein Wall und kein Randstein, wo ein anderer Weg oder der Dorfplatz anschließt |
| 4 | Ungültige Werte (NaN) in den Normalen des neuen Zugdachs | Der Scheitelpunkt lag durch 32-Bit-Rundung minimal über der Dachhöhe, dadurch Division durch 0 | Vergleich mit Toleranz |
| 5 | Schräge Frontscheibe wirkte wie helles Blech | Sie spiegelte den Himmel wie ein Seitenfenster | eigene Scheibenmarkierung: dunkel, wenig Spiegelung, kein Innenlicht |
| 6 | Treppenkante an der Scheibenoberkante | Glas wurde je Fläche nach Höhe zugeordnet | Scheibenkanten folgen Querschnittslinien und Ringen, also eine glatte Linie |
| 7 | Fenster sanken in den gewölbten Kasten ein | große flache Rechtecke auf gewölbter Fläche | Fenster- und Türflächen werden an den Knicken des Querschnitts geteilt |
| 8 | Fahrwerk und Schürzen wirkten beige statt dunkel | Klarlack spiegelte auch auf dunklen Teilen | Klarlack und Glanz nur auf farbigen Flächen |
| 9 | Schwarzes Loch hinter offenen Türen | kein Innenraum | beleuchteter Einstiegsraum |
| 10 | Hunderte Skriptfehler im Güterbahnhof („previously freed instance“) | Ein weggeflogener Vogel wurde einer typisierten Variable zugewiesen, bevor geprüft wurde, ob es ihn noch gibt | erst prüfen, dann zuweisen |

## Leistung

- **Züge:** Kleine Teile unter dem Wagenkasten werfen keinen eigenen Schatten mehr; der Schatten des Kastens genügt. Das betrifft Drehgestelle, Radsätze, Türflügel, Trittstufen und Fensterglas.
- **Trittstufen:** Eingefahrene Stufen werden gar nicht gezeichnet. Das spart 16 Draw Calls je Wagen während der Fahrt.
- **Messung:** Testrechner mit Intel HD 520 und Kompatibilitäts-Renderer, 15 Uhr, zwei Züge im Bild, Güterbahnhof:
  - Draw Calls: 1802 → 1646
  - Bildrate: unverändert rund 7–8 fps
- **Wo die Zeit hängt:** Die Skriptzeit habe ich pro System ausgemessen, indem ich jedes einzeln abgeschaltet habe. Kein System spart mehr als rund 8 ms, und das liegt im Rauschen. Die Bildzeit auf diesem Rechner kommt also von der schwachen Onboard-Grafik, nicht von der NPC- oder Zuglogik.
- **Dreiecke:** Endwagen etwa 2 700, Mittelwagen etwa 1 100 Dreiecke. Die Meshes werden je Lackierung zwischengespeichert.

## Neue und geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/procgen/railcar_meshes.gd` | **neu:** moderner Triebzug (Endwagen, Mittelwagen, Spiegelung) |
| `scripts/procgen/train_meshes.gd` | Triebzug eingebunden; neue Drehgestelle und Radsätze; Güterwagen- und Güterlok-Details |
| `scripts/trains/train_car.gd` | Federung („Body“), Kurvenneigung, Nicken, Innenlicht, unbeleuchtete Lampen, Zielanzeige, Leistung |
| `scripts/trains/train.gd` | Beschleunigung und Innenlicht an die Wagen, Zielanzeige setzen |
| `scripts/trains/train_dispatcher.gd` | Materialien für unbeleuchtete Lampen |
| `assets/materials/train_window.gdshader` | Innenlicht je Wagen, Sitzlehnen, Frontscheibe, Einstiegsraum |
| `assets/materials/train_paint.gdshader` / `.tres` | matte dunkle Teile, feinerer Klarlack |
| `assets/trains/regional_*.tres` | RE und RB fahren als Triebzug |
| `scripts/procgen/station_meshes.gd`, `scripts/rail/railway_platform.gd` | Zierbrett, Rinne, Eiszapfen, Leitstreifen, Rampengeländer, Pflanzkübel, Gleisnummern |
| `scripts/world/low_poly_terrain.gd` | `get_surface_height()` |
| `scripts/procgen/path_meshes.gd`, `scripts/village/village_path.gd`, `village_manager.gd`, `village_place_tool.gd` | Wege auf echter Oberfläche, Einmündungen |
| `scripts/freight/freight_yard.gd` | Fehler 10 |
| `tests/train_test.gd`, `tests/world_test.gd` | neue Prüfungen (Triebzug, Federung, Innenlicht, Zielanzeige, Wege) |
