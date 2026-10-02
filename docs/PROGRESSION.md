# Wintervale: vom ersten Gleis zur Eisenbahnregion

Neue Reisen beginnen in einem leeren, verschneiten Tal. Nur aus dem Berg im Norden ragt ein kurzes Gleis aus einem Tunnel: **Nordtal**. Von dort kommen alle Züge, Gäste und neuen Familien – kein Zug erscheint aus dem Nichts. Bereits gespeicherte Reisen ohne Epochen behalten ihre bestehende Welt. Das System erweitert RailNetwork, TrainDispatcher, Train, NpcDirector, VillageManager und Economy; es benutzt dieselbe Gleis-, Sicherungs-, Tür-, Stufen- und Baulogik.

## Die ersten Schritte

1. **B** öffnet den Baumodus. Mit „Schiene“ am Gleisende vor dem Tunnel ansetzen und ins Tal bauen (Stücke bis 60 m).
2. **H** wählen und einen Holz-Haltepunkt neben das neue Gleis setzen (mindestens 30 m vom Tunnel entfernt). Dahinter etwas Gleis frei lassen, damit der ganze Zug Platz hat.
3. **P** oder **Fuhrpark** öffnen: „Nordtal (Tunnel) ⇄ dein Ort“ ist vorausgewählt, der alte Dieseltriebwagen ist kostenlos.
4. Der Zug rollt aus dem Tunnel, Gäste steigen aus, Reisende steigen ein, und er fährt zurück in den Berg. Jede Ankunft zählt als Fahrt; jeder Gast, der wirklich aussteigt, und jede Reisegruppe, die im Tunnel ankommt, zählt als Fahrgast.
5. Das Dorf baust du selbst (Häuser, Wege, Natur, Licht ab Epoche 1). Ist ein Haus fertig, wartet die Familie in Nordtal und steigt aus dem nächsten Zug von dort. Erst dann zählt sie als Einwohner.

## Tunnel, Linien und Familien (Umbau vom 2. Oktober 2026)

Entscheidungen des Creative Directors: Züge kommen aus dem Berg; zum Start genügt ein Haltepunkt (Tunnel ⇄ eigener Ort); ein Tunnel zum Start, ein zweiter (**Südtal**, im Süden) öffnet sich mit Epoche 3; keine automatischen Häuser, Wege, Plätze oder Brunnen mehr; Familien kommen per Zug.

- **Tunnelanschluss** (`scripts/progression/region_portal.gd`): ein Ort ohne Bahnsteig. Er besteht aus 125 m Tunnelgleis im Berg (lang genug für jeden Zug) und 14 m Anschlussgleis davor. Sichtbar sind nur Portal und die ersten Tunnelmeter; Wagen tiefer als 14 m im Berg werden ausgeblendet. Der Anschluss lässt sich nicht abreißen.
- **Tunnel-Linien:** Der Zug fährt vom tiefen Tunnelende zum Bahnsteig, bringt Gäste (mehr, je mehr Einwohner der Ort hat) und wartende Familien, nimmt Reisende auf, fährt zurück in den Berg und verschwindet. Der nächste Zug derselben Linie folgt nach etwa 24 Spielsekunden. Güterzüge liefern ihre Ladung ab und fahren leer zurück.
- **Linien zwischen eigenen Orten** gibt es weiterhin. Der Zug reist zuerst durch den Tunnel zum ersten Ort an und pendelt dann. Dafür muss dieser Ort mit dem Tunnel verbunden sein.
- **Stadtbau:** Häuser gehören zum nächsten Haltepunkt. Ein Haus kann erst gebaut werden, wenn es einen Haltepunkt gibt. Fehlende Baustoffe kauft der **Baustoffhandel in Nordtal** automatisch mit 50 % Aufpreis dazu; die Kostenzeile zeigt das an.
- **Freischaltungen:** Häuschen, A-Frame, Chalet, Kieswege, Natur, Laternen und Gartenlampen ab Epoche 1; Bauernhaus, Lichterketten und Dorfdeko ab Epoche 2; Stadthaus, Scheunenhaus, Steinwege, Dorfplatz, Brunnen ab Epoche 3; Turmhaus, Gaubenhaus, Straßen, Straßenlaternen ab Epoche 4.
- **Bedingungen:** „Streckenlänge“ zählt nur selbst gebaute Gleise, „Verbundene Orte“ nur eigene Haltepunkte mit Zugverkehr.

### Einführung mit Ilse

Neue Reisen beginnen mit einer geführten Einführung (`scripts/ui/journey_tutorial.gd`). Ilse, die Bahnhofsvorsteherin, begleitet neun Schritte: Willkommen am Tunnel → Baumodus (B) → 60 m Gleis ab dem Tunnelanschluss → ein Haltepunkt (H) → Zug aus Nordtal (P) → erste Fahrgäste → ein Haus bauen → die Familie kommt mit dem Zug → Ausblick auf die Epochen. Jeder Schritt zeigt Tastenkappen und einen Fortschritt als kleines Gleis und wird mit Stempel und Glockenklang abgehakt. Ein goldener Pfeil zeigt auf den passenden Knopf (Werkzeug, Fuhrpark-Schild, „Zug einsetzen“, „Häuser“). Leuchtende Ringe in der Welt markieren „Hier anschließen“, einen guten Haltepunkt-Platz und einen freien „Bauplatz“. Der Knopf **Zeigen** fährt die Kamera dorthin. Ist das Reisebuch offen, spricht Ilse in dessen Kopfzeile. Wer schneller ist, überspringt erledigte Schritte automatisch; „Einführung überspringen“ beendet sie sofort. Der Schritt steht im Spielstand (`progression.tutorial`, -1 = fertig). Danach bleibt oben links eine einklappbare Zielkarte mit den Bedingungen der nächsten Epoche.

### Reisebuch

Das Reisebuch (`scripts/ui/region_panel.gd`, Taste P oder die Holzschilder oben rechts) nutzt die Bildsprache der Menüseiten: Pergament im verschneiten Holzrahmen (`parchment_panel.png` als Neun-Feld-Grafik), Messingknöpfe der Spielstand-Seite, Serifenschrift und eigene Symbole in `assets/ui/journey/`. Gemeinsame Bausteine stehen in `scripts/ui/journey_style.gd`. Das Buch liegt unter der Statusleiste, damit Geld, Tag und Uhr sichtbar bleiben.

- **Reise:** sechs Epochen als Haltestellen an einem Gleis, die aktuelle leuchtet; Klick zeigt Bahnhof, neuen Zug (mit Lackierungs-Silhouette), Neuerungen und Bedingungen mit Fortschritt und einem Tipp zum ersten offenen Ziel.
- **Orte / Bahnhof:** Kennzahlen mit Symbolen, Stufenpunkte, Umbenennen, Ausbau mit Preis und Grund, Bahnsteige, Linien des Ortes.
- **Fuhrpark:** Regal mit allen Zügen (gesperrte mit Schloss), drehbare 3D-Vorschau auf einem kleinen Schaugleis, Kennzahlen und „Zug auf die Strecke schicken“.
- **Linien:** Karten mit Zustand („hält in …“, „unterwegs nach …“, „Gleis unterbrochen?“), Pausieren und Aufheben.

### Haltepunkte abreißen

Im Baumodus reißt „Entfernen“ (4) auch Haltepunkte ab: Bahnsteig oder Gebäude anklicken (rot markiert). Der Preis des Holz-Haltepunkts (180 Taler) kommt zurück, die Linien des Ortes enden. Strg+Z stellt Bahnhof und Linien wieder her und bucht den Betrag erneut. Ein Klick direkt auf ein Gleis entfernt weiterhin das Gleis.

Ein Bahnhof lässt sich außerhalb des Baumodus anklicken. Sein Menü bietet Namen, Auslastungszahlen, angeschlossene Linien, Ausbau und zusätzliche Bahnsteige. Kleine Bahnhöfe bleiben beim Epochenwechsel erhalten; jeder Ort wird separat ausgebaut. **F8** öffnet ausschließlich im Entwicklungsbuild die Testwerkzeuge.

Für längere Züge die Gleise hinter den vorhandenen Haltepunkten verlängern. Der Fahrweg berücksichtigt auch diese zusätzlichen Endstücke. Auf der Verbindung müssen der ganze Zug und die Bremswege Platz finden. Die Fehlermeldung im Fuhrpark erklärt fehlende Bahnhofsstufen oder Gleislängen. Bahnhofsflächen werden für spätere Ausbauten freigehalten; benachbarte Bahnsteige dürfen beim Ausbau nicht überlappen.

## Sechs Entwicklungsschritte

Die verbindlichen Daten liegen in [`assets/progression/epochs.tres`](../assets/progression/epochs.tres), einer im Godot-Inspector editierbaren und im Export enthaltenen Resource. Anforderungen vergleichen tatsächliche Zähler und den aktuellen Netz-/Siedlungszustand. Es gibt keine XP-Leiste und keinen Freischaltungstimer.

| Epoche | Bahnhof und neue Referenzfahrzeuge | Bedingungen |
|---|---|---|
| 1 · Der erste Funke | Holz-Haltepunkt; alter Dieseltriebwagen | Start |
| 2 · Land und Leute | Landbahnhof; grüne Mittelführerstandslok mit zwei Wagen | 12 Fahrgäste, 3 Fahrten, 2 verbundene Orte, 70 m Gleis |
| 3 · Ein Dorf entsteht | Dorfbahnhof mit Uhrturm und Güterschuppen; roter Güterzug | 40 Fahrgäste, 8 Fahrten, 3 Orte, 12 Einwohner |
| 4 · Neue Nachbarschaften | Kleinstadtbahnhof; dreiteiliger moderner Nahverkehr | 100 Fahrgäste, 24 Güter, 3 Orte, 2 Linien, 24 Einwohner |
| 5 · Die Region verbindet sich | Stadtbahnhof mit Glashalle; vierteiliger Intercity | 220 Fahrgäste, 60 Güter, 4 Orte, 3 Linien, 240 m Gleis, 40 Einwohner |
| 6 · Wintervale blüht auf | Hauptbahnhof mit großer Halle und zwei Türmen; fünfteiliger Hochgeschwindigkeitszug | 450 Fahrgäste, 120 Güter, 5 Orte, 4 Linien, 64 Einwohner, 50 Fahrten |

Gleise und Holz-Haltepunkte kosten Geld. Ausbauten benötigen zusätzlich erfolgreiche Ankünfte am betreffenden Ort. Die Kosten der sechs Bahnhofsstufen sind 180 / 350 / 650 / 1000 / 1500 / 2200 Taler; ein zusätzlicher Bahnsteig kostet 120 Taler. Die möglichen Bahnsteigzahlen sind 1 / 1 / 2 / 2 / 3 / 4. Ein Epochenwechsel schaltet Möglichkeiten frei, bezahlt oder ersetzt aber keinen Bahnhof.

## Fahrzeuge und Referenztreue

Alle sechs Bilder aus `C:\Users\Luca Warmers\Pictures\TrainModels` wurden einzeln ausgewertet. Für reproduzierbare Vergleiche liegen Kopien in [`train_references`](train_references/). Die Bilder werden nicht als Fahrzeugtexturen verwendet. Körper, Fensteröffnungen, Fronten, Sitze, Dachdetails, Kupplungen und Güterwagen sind pro Zugfamilie modellierte Geometrie. Bewegliche Türen, Stufen, Drehgestelle und Räder bleiben eigenständige Komponenten.

| Bild | Resource | Erkennungsmerkmale | Fahrzeuge / Länge | Plätze / Güter |
|---|---|---|---|---|
| 1 | `diesel_heritage` | Rot/Creme, gerade Front, zwei Frontscheiben, runde Lampen, Kühler, außermittige Doppeltür | 1 / 16 m | 24 / 0 |
| 2 | `nostalgic_regional` | Grüne Mittelführerstandslok, schmale Vorbauten, offene Umläufe und Handläufe, zwei grüne/cremefarbene Reisezugwagen | 3 / 37,68 m | 64 / 0 |
| 3 | `reference_freight` | Rote Endführerstandslok, gedeckter Wagen, Holz, heller Tankwagen, blauer offener Kohlewagen | 5 / 53,36 m | 0 / 94 |
| 4 | `modern_local` | Kurze schräge Front, Türkis/Creme, orange Doppeltüren, drei Wagen | 3 / 51,68 m | 100 / 0 |
| 5 | `intercity` | Creme mit burgunderfarbenen Bändern, rote Sitze und Türen, vier Wagen | 4 / 72,52 m | 160 / 0 |
| 6 | `high_speed` | Lange verjüngte Nase, weiße/blaue Flächen, dunkles Fensterband, fünf Wagen | 5 / 97,36 m | 220 / 0 |

**Überarbeitung 2. Oktober 2026** (Vergleich mit denselben sechs Bildern im Studio und in der Spielwelt):

- Der Lack-Shader (`railcar_paint.gdshader`) dunkelte helle Farben auf 62 % ab – Creme wurde zu Khaki, Weiß zu Beige. Jetzt höchstens auf 79 %.
- Lackierungen nach den Bildern: kräftigeres Rot/Creme (Triebwagen), Tannengrün (Epoche 2), Signalrot (Güterlok), Türkis/Orange (Nahverkehr), Burgunder (Intercity), Weiß/Kobalt (Hochgeschwindigkeit); alle Dächer anthrazit.
- Puffer, Kupplungen und Dachgeräte dunkel statt hellgrau; moderne Züge tragen flache Klimakästen.
- Epoche 2: geschlossenes Führerhaus (unten grün, oben creme mit echten Fensteröffnungen), gleich hohe Vorbauten, runde Puffer; Wagen mit Tonnendach und Pilzlüftern.
- Güterlok: rote Stirn mit cremefarbenem Fensterrahmen, dunkles Dach auf dem Maschinenraum.
- Alter Triebwagen: lange Dachkiste, orange Begrenzungsleuchten, Trittlampe über der Tür.
- Hochgeschwindigkeitszug: breites blaues Band unter den Fenstern.

### Bahnsteige

Der Holz-Haltepunkt (`EpochStationMeshes._timber_halt`) hat ein Bretterdeck auf Stelzen mit Streben und Stirnblenden, einen Zaun mit Schneekappen und eine kleine Treppe dort, wo die Reisenden zum Ort gehen. Dazu kommen ein Unterstand mit Satteldach, Schneedecke, Zierbrettern, Fenster, Bank, Fahrplanaushang und Hängelaterne sowie Gepäckkarren, Milchkannen, Kisten, Pflanzkübel und Endtreppen mit Handlauf. Alle Stufen haben gusseiserne Laternenmasten (die Lichtquellen sitzen in den Laternen) und Schnee auf allen Dächern. Ab Stufe 2 liegen zusätzlich Schneereste, Gepäckkarren und Kannen auf dem Bahnsteig. Der Ortsname steht jetzt lesbar auf beiden Seiten des Schildes; vorher lag die Schrift in der Tafel.

Die komplette bisherige Fahrzeugbibliothek bleibt zusätzlich erhalten: Regionalbahn, Regional-Express, Holz-, Baustoff-, Schüttgut- und gemischter Güterzug sowie Weihnachts-, Ernte- und Schneeräumzug. Sonderfahrzeuge benötigen keine saisonalen Ereignisse zum Fortschritt. Ihre Bahnhofsvoraussetzungen gelten auch im neuen regionalen Betrieb. Neue Fahrzeuge erweitern den Fuhrpark; ältere werden nicht automatisch ersetzt.

Geschwindigkeit, Beschleunigung, Kapazität, Preis, notwendige Epoche/Bahnhofsstufe, Komfort und Klangparameter liegen in den TrainType-Resources. Höhere Kapazitäten ermöglichen größere Reisegruppen bei ausreichender örtlicher Nachfrage. Die Zahl sichtbarer Figuren bleibt begrenzt; jede Gruppe wird erst nach ihrer tatsächlichen Ein-/Ausstiegsanimation gezählt. Die Modelle benutzen den bestehenden gemeinsamen Spurweiten-, Rad-, Kupplungs- und Einstiegshöhenmaßstab.

## Betrieb, Güter und Wachstum

Linien pendeln zwischen zwei Orten. Parallelgleise und zusätzliche Bahnsteige ermöglichen gleichzeitigen Verkehr. Gemeinsam genutzte eingleisige Fahrwege werden nacheinander bedient: Nach einem abgeschlossenen Halt kann eine wartende Linie übernehmen. Es wird kein zweiter Zug in einen belegten vollständigen Fahrweg gesetzt. Eine pausierte Linie bleibt gespeichert und kann fortgesetzt werden.

Der Passagierwechsel verwendet die bestehenden Phasen: Stillstand → Entriegeln → Stufen ausfahren → Türen öffnen → Aus-/Einsteigen → Türen schließen → Stufen einfahren → Abfahrt. Beim Wenden bleiben die Fahrzeuge körperlich an derselben Position; Reihenfolge, Türseite, Lichtenden, Anzeige und Fahrweg wechseln gemeinsam.

Güterzüge liefern bestellte Waren in das bestehende gemeinsame Lager. Holz, Ziegel, Glas und Stein versorgen damit auch manuelle Bauprojekte. Lagerplatz, Bestellungen und vorhandenes Geld begrenzen die Lieferung. Ladung wird sichtbar angehoben, zum Güterschuppen bewegt und abgesetzt; währenddessen bleibt die Abfahrt gesperrt. Erst danach werden Lagerbestand, Frachtentgelt, örtliche Versorgung und Epochenfortschritt erhöht. Für den Tankwagen benutzt die vereinfachte vorhandene Wirtschaft ihre Glas-Lieferkategorie; es wurde keine zusätzliche Flüssigkeitswirtschaft eingeführt.

Die Stadt wächst nicht mehr von selbst (seit 2. Oktober 2026): Häuser, Wege, Plätze und Laternen baut der Spieler. Jedes Haus gehört zum nächsten Haltepunkt; fertige Häuser zählen zur Einwohnerzahl, sobald ihre Familie mit dem Zug aus dem Tunnel angekommen ist. Maximal sechs Bewohner je Ort werden zusätzlich als dauerhafte NPCs dargestellt. Der frühere organische Wachstumscode (`grow_station`, `_grow_public_space`) bleibt nur für das F8-Entwicklungsmenü erhalten.

## Speichern und bestehende Reisen

Save-Version 3 speichert Epoche, Zähler, freigeschaltete Fahrzeuge, Debug-Nutzung, Bahnhofsnamen/-stufen, zusätzliche Bahnsteige, Haus-/Nachbarschaftszuordnung sowie Linien, Zugzuweisungen und deren Transportzahlen. Das vorhandene Village-/Economy-/RailNetwork-Save-System speichert weiterhin Gebäude, Baufortschritt, Wege, Geld, Lager und Gleise.

Laufende Warenübergaben werden vor dem Speichern abgeschlossen, damit bezahlte Ware nicht zwischen Zuständen verloren geht. Beim Laden werden alte Übergaben verworfen, bevor die gespeicherten Zähler und Bestände wiederhergestellt werden. Aktive Züge werden nach dem Laden aus ihren gespeicherten Linien neu eingesetzt; ihre exakten Positionen und einzelne Reisende werden wie im bestehenden Dispatcher nicht konserviert.

Spielstände ohne Progressionsdaten laden ihre alte entwickelte Welt einschließlich Bahnhof, Stadt und Portalen. Die Entscheidung erfolgt sowohl im Hauptmenü als auch beim Wechsel zwischen unterschiedlichen Reisen im Spiel. Das Lesen verändert keine alten Save-Dateien. Neue Reisen erben keine Stadt aus einem zuvor geladenen Spielstand.

## Qualitätssicherung und technische Grenzen

Die Tests laufen in der vorhandenen QA-Sandbox und verändern keine normalen Spielstände:

```text
godot --headless --path . --fixed-fps 60 res://tests/progression_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/regional_operations_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/save_compatibility_test.tscn
```

Zusätzlich wurden die bestehenden `railway_test`, `train_test` und `economy_test` ohne Fehler ausgeführt. Die neuen Tests prüfen leeren Start, echte Bauwerkzeuge und Undo/Redo, endliche Modellgeometrie, bewegliche Türpaare, Kapazitäten, Stufen-/Türsicherheit, tatsächlichen Passagierwechsel, Wendepositionen, alle Epochen-Grenzwerte, vier gleichzeitige Linien, freie Parallelbahnsteige, wartenden Sonderverkehr, Warenübergaben, Erfolge, kollisionsfreie Bahnhofsflächen, Neustart und Save-Kompatibilität.

| Test | Prüfungen | Fehler |
|---|---:|---:|
| `progression_test` | 188 | 0 |
| `regional_operations_test` | 43 | 0 |
| `save_compatibility_test` | 15 | 0 |
| Gesamt neue Integrationstests | 246 | 0 |

Die echten Godot-Bildprüfungen liegen in [`qa/progression`](qa/progression/): Front/Seite/offene Türen aller sechs Referenzzüge, alle Bahnhofsstufen, frühe/entwickelte Welt bei Tag/Nacht sowie Reise-, Stations-, Linien- und Fuhrparkmenüs einschließlich 1280 × 720. Die entwickelten Weltbilder sind ausdrücklich Debug-Aufbauten, keine behaupteten mehrstündigen Spielverläufe. Die rotierbare Fuhrparkvorschau wird dynamisch eingepasst und nur bei sichtbarem Menü gerendert.

Die Körper-/Innenraumgeometrie der sechs neuen vollständigen Züge liegt ungefähr zwischen 5.000 und 34.000 Dreiecken; zusätzliche bewegliche Teile kommen hinzu. Stationsgeometrie wird in zwei gemeinsame Material-Meshes zusammengefasst, Netzvalidität zwischengespeichert und entfernte Stationen ausgeblendet. Die zuletzt geprüfte entwickelte Bildprüfungswelt mit rund 30 Häusern, Bewohnern, Bahnhofshalle und geöffneter Vorschau lag auf Intel HD 520/ANGLE bei 753 Draw Calls und 935.065 gerenderten Primitiven. Das ist eine konkrete Szenenmessung, keine Framerate-Zusage oder Garantie für beliebig große Netze. Weitere LODs und Instancing können bei größeren Zielwelten anhand eines Profilings ergänzt werden.

Die komplette erste Stunde und mehrere reale Spielstunden wurden nicht als menschlicher Spieltest durchgeführt. Die Schwellen sind ein konsistenter Ausgangspunkt für weiteres Spielgefühl-/Ökonomietuning; sie lassen sich zentral im Epochen-Resource und in den TrainType-Resources ändern.
