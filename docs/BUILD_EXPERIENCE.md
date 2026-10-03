# Bauen, Bahnhofszugänge und Ilse – Oktober 2026

Die vorhandene Welt mit Tunnelanschlüssen, manuell gebautem Dorf und regionalem Zugbetrieb bleibt die Grundlage dieser Überarbeitung.

## Bedienung und Gestaltung

- Gleise, Wege, Häuser, Dekoration, Signale, Weichen und Haltepunkte erhalten kurze Bestätigungen mit einem weichen Bauton und einem Farbring. Bei Wegen und Gleisen zeichnet eine kurze goldene Spur den gebauten Verlauf nach. Einrastpunkte bekommen eigenes Feedback; ungültige Klicks erklären den Grund.
- Die Effekte verändern die gebaute Geometrie nicht. Höchstens zwölf Effektobjekte und 48 Punkte je Spur bleiben gleichzeitig aktiv. Die Einstellung „Reduzierte Bewegung“ unterdrückt bewegte Spuren und das Aufsteigen der Beschriftung. Lautstärke folgt der vorhandenen UI-Audiosteuerung.
- B öffnet die Bauwerkzeuge, R dreht, C wechselt Varianten, F das Objekt. Strg+Z und Strg+Y funktionieren weiterhin für Rückgängig/Wiederholen. Wege beginnen nach einem Abschnitt am tatsächlichen Endpunkt einschließlich seiner Geländehöhe.
- Alle sechs Bahnhofsstufen haben einen gemeinsamen, sichtbaren Treppenzugang. Größere Gebäude bekommen Steinsockel, zusätzliche Fassadendetails, Vorplätze, Pflanzkübel und Informationsbereiche. Die großen Hallen haben eigenes transparentes Glas statt einer flächig leuchtenden Dachfläche.
- Ein gedrehtes Geländeplanum passt sich beim Bau, Ausbau und Laden an den Bahnhof und seine zusätzlichen Bahnsteige an. Außerhalb der Fläche geht es weich ins Gelände über; Gleiskerne behalten ihre eigene Höhe. Entfernen und Wiederherstellen erzeugen das Planum aus den Gebäudedaten neu.
- Der nostalgische Regionalzug aus Epoche 2 fährt mit **Lok – Wagen – Wagen – Lok**. Die Endlok ist gespiegelt; ihre äußeren Lampen passen zur Rückfahrt. Die 64 Sitzplätze bleiben erhalten. Die neue Gesamtlänge beträgt **48,52 m**; die Fahrwegprüfung berücksichtigt die zusätzlichen Meter hinter dem Halt.

## Tutorial und UI

Über **Hilfe** oben rechts lässt sich Ilses Rundgang jederzeit öffnen. Er führt durch Reise/Epochen, Orte, Bahnhofsausbau, Fuhrpark und Linien, alle sechs Notizbuchseiten, Statusleiste und Bauwerkzeuge. Der bisherige Einstieg führt am Ende ebenfalls in diesen Rundgang.

Eine erreichte Epoche bekommt eine kurze Einführung. **Neuheiten zeigen** öffnet die echte Epochenseite, den Bahnhofsausbau, das neue Fahrzeugmodell und die verfügbaren Bauwerkzeuge. Während Reisebuch, Notizbuch oder Pausenmenü geöffnet sind, wartet die Einführung. Abgehakte Einführungen und laufende Rundgänge werden gespeichert; alte Spielstände spielen bereits erreichte Epochen nicht erneut ab.

Tutorialkarten passen ihre Höhe an den Text an und reservieren Platz unter den Seiten. Das Notizbuch skaliert mit der Bildschirmgröße und seine Spalten lassen sich scrollen. Regionale Personen- und Güterlinien sowie die Haushalte werden aus der tatsächlichen Region angezeigt. Das Lager erklärt den Baustoffhandel und den aktuellen Güterbetrieb.

## Gefundene und behobene Fehler

| Fehler | Korrektur |
| --- | --- |
| NPCs liefen diagonal direkt auf den Bahnsteig und ignorierten die offizielle Treppe. | Zugangspunkte, Umgehung der Gebäudeflügel und gemeinsame Treppenmaße für Geometrie und Laufwege. |
| Bereits laufende NPCs behielten beim Ausbau die Wegpunkte der alten Treppe. | Laufwege mit Bahnhofszugang werden für die neue Stufe erneut berechnet; Ziel, Laufgeschwindigkeit und Ankunftsaktion bleiben erhalten. |
| NPC-Bodenmessung konnte Dächer, Bänke oder Gepäck statt des Bahnsteigs treffen. | Exakte Bodenhöhen innerhalb von Bahnsteig und Treppenlauf; außerhalb weiterhin Gelände/Kollision. |
| Die achtsekündige Einstiegsfrist konnte für den nun richtigen Fußweg zu kurz sein. | Eine begrenzte, vom tatsächlichen Zugangsweg abhängige Einstiegsfrist; normale übrige Halte behalten ihr Verhalten. |
| Größere Bahnhöfe standen über unpassendem Gelände bzw. hatten freiliegende Gebäudesockel. | Vollständige Fundamentflächen und Steinsockel, die beim Ausbau mitwachsen. |
| Die Wegvorschau begrenzte die Länge, während der Klick bis zur weiter entfernten Mausposition baute. | Platzierung, Kostenprüfung und nächster Start verwenden denselben begrenzten Endpunkt. |
| Ungültige Gleiskandidaten oder fehlende Maus-Bodentreffer ließen die Gelände-Vorschau stehen. | Vorschau wird in diesen Fällen entfernt. |
| Ein zusätzlicher Bahnsteig konnte das Hauptgebäude oder einen vorhandenen Bahnsteig überlappen. | Prüfung der tatsächlichen reservierten Flächen vor dem Platzieren. |
| Die Vorschau zusätzlicher Bahnsteige zeigte einen kleinen Haltepunkt. | Sie zeigt einen Bahnsteig mit den Maßen der gewählten Bahnhofsstufe. |
| Das Notizbuch las den alten Fahrplan und den abgeschalteten zentralen NPC-Verwalter. | Regionale Linien und die Bewohnerverwaltung des zugehörigen Bahnhofs werden verwendet. |
| Das Lager versprach im neuen Spiel einen automatisch kommenden Güterzug um 07:05. | Tatsächliche Güterlinien, gelieferte Mengen und Baustoffhandel ersetzen diese alte Anzeige. |
| Die Kostenleiste erzeugte bei identischen Vorschauen ständig neue UI-Elemente. | Wiederaufbau nur bei geänderten Kosten, Wirtschaftsdaten oder Baumodus. |
| Tutorial-Scrollen auf Menü-Reiter oder inzwischen ersetzte Controls erzeugte Engine-Fehler. | Ziele werden erst im aktuellen Seitenaufbau aufgelöst; gescrollt werden nur enthaltene Controls. |
| Ein einseitig bespannter Regionalzug sah auf der Rückfahrt rückwärts gezogen aus. | Lokomotive an beiden Enden mit passender äußerer Beleuchtung. |

## Prüfung

Automatische Prüfungen verwenden den vorhandenen QA-Speicherbereich und verändern keine echten Spielstände.

| Test | Ergebnis |
| --- | --- |
| Fortschritt und reguläre neue Reise (`progression_test`) | 205 Prüfungen, keine Fehler |
| Gleichzeitiger regionaler Betrieb, Güterumschlag, Wenden, Speichern/Laden (`regional_operations_test`) | 43 Prüfungen, keine Fehler |
| Alte und neue Spielstandgenerationen (`save_compatibility_test`) | 15 Prüfungen, keine Fehler |
| Bauen, sechs Treppengeometrien, tatsächlich laufende NPCs, Gelände, Platzierungsgrenzen und Tutorial (`build_experience_test`) | 81 Prüfungen, keine Fehler |
| Bestehende Gleis- und Zugregressionen (`railway_test`, `train_test`) | 94 und 138 Prüfungen, keine Fehler |

Insgesamt: **576 bestandene Prüfungen**. Die 81 neuen Prüfungen umfassen auch laufende NPCs beim Bahnhofsausbau, gespeicherte Rundgänge und die sichtbaren Grenzen der Tutorialkarten.

Neue Engine-Aufnahmen liegen in [docs/qa/build_experience](qa/build_experience). Die Aufnahmen enthalten die sechs Bahnhofsstufen, den Zug mit beiden Lokomotiven, die Rundgangseiten und die Epochen-Einführung. Sie stammen direkt aus dem Spielrenderer.

Zum Wiederholen: Godot mit `--headless --path . --fixed-fps 60 res://tests/build_experience_test.tscn` starten. Für neue Bilder die Szene `res://tests/qa/build_experience_capture.tscn` mit dem grafischen Renderer öffnen.
