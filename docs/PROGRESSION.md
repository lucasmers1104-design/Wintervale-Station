# Wintervale: vom ersten Gleis zur Eisenbahnregion

Neue Reisen beginnen ohne Gleise, Bahnhof, Gebäude oder Verkehr. Bereits gespeicherte Reisen behalten ihre bestehende Welt. Das neue System erweitert RailNetwork, TrainDispatcher, Train, NpcDirector, VillageManager und Economy; es benutzt dieselbe Gleis-, Sicherungs-, Tür-, Stufen- und Baulogik.

## Die ersten Schritte

1. **B** öffnet den Baumodus. Zwei zusammenhängende gerade Gleisstücke von ungefähr 45 m bauen. Gleisstücke dürfen höchstens 60 m lang sein.
2. Im Baumodus **H** wählen und zwei Holz-Haltepunkte neben das Gleis setzen. Rund 12 m Gleis an beiden Enden freilassen. Haltepunkte liegen mindestens 32 m auseinander.
3. **P** oder **Fuhrpark** öffnen, den alten Dieseltriebwagen auswählen und beide Orte verbinden. Der erste Diesel kostet keinen zusätzlichen Kaufpreis.
4. Das Menü schließen. Reisende gehen zum Bahnsteig, steigen durch die animierten Doppeltüren ein und am Ziel wieder aus. Erst ein abgeschlossener Ausstieg zählt als Beförderung.
5. Nach erfolgreichem Verkehr entstehen Baustellen und anschließend bewohnte Häuser. Die Reiseübersicht zeigt die konkreten Bedingungen für den nächsten Abschnitt.

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

Die komplette bisherige Fahrzeugbibliothek bleibt zusätzlich erhalten: Regionalbahn, Regional-Express, Holz-, Baustoff-, Schüttgut- und gemischter Güterzug sowie Weihnachts-, Ernte- und Schneeräumzug. Sonderfahrzeuge benötigen keine saisonalen Ereignisse zum Fortschritt. Ihre Bahnhofsvoraussetzungen gelten auch im neuen regionalen Betrieb. Neue Fahrzeuge erweitern den Fuhrpark; ältere werden nicht automatisch ersetzt.

Geschwindigkeit, Beschleunigung, Kapazität, Preis, notwendige Epoche/Bahnhofsstufe, Komfort und Klangparameter liegen in den TrainType-Resources. Höhere Kapazitäten ermöglichen größere Reisegruppen bei ausreichender örtlicher Nachfrage. Die Zahl sichtbarer Figuren bleibt begrenzt; jede Gruppe wird erst nach ihrer tatsächlichen Ein-/Ausstiegsanimation gezählt. Die Modelle benutzen den bestehenden gemeinsamen Spurweiten-, Rad-, Kupplungs- und Einstiegshöhenmaßstab.

## Betrieb, Güter und Wachstum

Linien pendeln zwischen zwei Orten. Parallelgleise und zusätzliche Bahnsteige ermöglichen gleichzeitigen Verkehr. Gemeinsam genutzte eingleisige Fahrwege werden nacheinander bedient: Nach einem abgeschlossenen Halt kann eine wartende Linie übernehmen. Es wird kein zweiter Zug in einen belegten vollständigen Fahrweg gesetzt. Eine pausierte Linie bleibt gespeichert und kann fortgesetzt werden.

Der Passagierwechsel verwendet die bestehenden Phasen: Stillstand → Entriegeln → Stufen ausfahren → Türen öffnen → Aus-/Einsteigen → Türen schließen → Stufen einfahren → Abfahrt. Beim Wenden bleiben die Fahrzeuge körperlich an derselben Position; Reihenfolge, Türseite, Lichtenden, Anzeige und Fahrweg wechseln gemeinsam.

Güterzüge liefern bestellte Waren in das bestehende gemeinsame Lager. Holz, Ziegel, Glas und Stein versorgen damit auch manuelle Bauprojekte. Lagerplatz, Bestellungen und vorhandenes Geld begrenzen die Lieferung. Ladung wird sichtbar angehoben, zum Güterschuppen bewegt und abgesetzt; währenddessen bleibt die Abfahrt gesperrt. Erst danach werden Lagerbestand, Frachtentgelt, örtliche Versorgung und Epochenfortschritt erhöht. Für den Tankwagen benutzt die vereinfachte vorhandene Wirtschaft ihre Glas-Lieferkategorie; es wurde keine zusätzliche Flüssigkeitswirtschaft eingeführt.

Erfolgreicher Verkehr und örtliche Lieferungen erhöhen das Wachstumspotenzial. Vorhandene Hausformen werden nach Epoche ausgewählt, mit echten Baustellen aufgebaut und in die Nachbarschaft integriert. Organische Baustellen benötigen eine Spielstunde tagsüber; selbst beauftragte Gebäude verwenden weiterhin ihre regulären Bauzeiten und Materialreservierungen. Wege entwickeln sich von Kies zu Stein und Straße; Plätze, Brunnen und Laternen ergänzen entwickelte Orte, sofern ihre Fläche frei ist. Auch selbst gebaute Häuser nahe eines Bahnhofs gehören zur örtlichen Einwohnerzahl. Der Einwohnerstand enthält alle fertigen Haushalte; maximal sechs Bewohner je Ort werden zusätzlich als dauerhafte NPCs dargestellt.

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
