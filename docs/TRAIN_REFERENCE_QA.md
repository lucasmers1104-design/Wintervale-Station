# Zugmodelle nach den Bildvorlagen

Stand: 1. Oktober 2026. Umsetzung und Aufnahmen mit Godot 4.7.2, Compatibility/ANGLE auf Intel HD Graphics 520.

## Umsetzung

Die beiden im Chat gelieferten Front-/Seitenansichten bilden die gestalterische Grundlage. Es sind echte, prozedural erzeugte 3D-Modelle mit getrennten beweglichen Teilen.

- **Normaler Zug (RE/RB):** cremefarbener Wagenkasten, türkiser Sockel und Dachkante, orange Zierlinie und Türen, schräge kantige Front, schwarze Scheibenrahmen, Scheibenwischer, zwei geformte Scheinwerfer, Kupplung, Dachgeräte mit Lüftungsschlitzen und blaue Sitze.
- **WinterSpecial:** rotes Fensterband und Dachkante, dunkelgrünes Band und Türfelder, goldene Türrahmen, rote Sitze, Kränze mit Kugeln und Schleifen, Girlanden, warme Lichter und unregelmäßige Schneekappen. Die Seitendekoration sitzt fest am Wagenkasten und außerhalb der vollständigen Türbewegung.
- Fenster und Türen sind tatsächliche Öffnungen. Dahinter stehen Sitze, Armlehnen, Haltestangen, Boden, Deckenleuchten und Führerstand. Glas, Innenraum und Beleuchtung haben eigene Materialien.
- Der hintere Führerstand ist gespiegelt. Zielanzeigen passen ihre Schriftgröße an das Gehäuse an. Winter und Normalzug haben getrennte Einträge im Geometriecache.

## Einbindung der Funktionen

Die bestehenden Fahrzeugressourcen werden direkt vom Fahrplan und vom Festkalender verwendet. Die Wintergestaltung wird durch `TrainType.winter_special` aktiviert.

Türen und Klappstufen werden weiterhin durch die vorhandene Zugsequenz bewegt: entriegeln, Stufen ausfahren, Türen öffnen, Fahrgastwechsel, Türen schließen und Stufen einfahren. Die Trittstufen und die Einstiegswege verwenden jetzt denselben gefederten Wagenkasten wie die Türen. Drehgestelle, rollende Achsen, Geräusche, Bremsverhalten, Signale, Bahnsteigwahl, Fahrplan und Speichern/Laden bleiben in den vorhandenen Systemen eingebunden. Auch die zusätzliche Lichterkette anderer festlicher Triebzüge berücksichtigt die neue Dachhöhe.

## Tatsächliche Godot-Aufnahmen

| Ansicht | Normal | WinterSpecial |
|---|---|---|
| Front im neutralen Prüfraum | [Front](regional_express_front.png) | [Front](special_winter_front.png) |
| Gesamter Zug | [Seite](regional_express_side.png) | [Seite](special_winter_side.png) |
| Geöffnete Türen und Stufen | [Einstiege](regional_express_doors.png) | [Einstiege](special_winter_doors.png) |
| Zug in der Spielwelt | [Bahnhof](regional_express_in_game.png) | [Bahnhof](special_winter_in_game.png) |
| Einstiegsseite am Bahnsteig | [Bahnsteig](regional_express_platform.png) | [Bahnsteig](special_winter_platform.png) |

Die Bahnhofsbilder zeigen durch den tatsächlichen Dispatcher erzeugte Züge in `main.tscn`, mit geöffneten Türen auf der ermittelten Bahnsteigseite. Für die Aufnahme sind HUD und Erfolgsmeldung ausgeblendet; die Bahnhofskulisse bleibt sichtbar. Die Prüfraum-Aufnahmen verwenden dieselben `TrainCar`-Modelle und Materialien. Es handelt sich nicht um generierte Vorschaubilder.

Beim visuellen Vergleich mit den Chatvorlagen wurden die Wagenkastenhöhe reduziert, die Scheiben stärker getönt, Sitzlehnen und Kupplung abgeschrägt, Schneekappen unregelmäßiger gestaltet und die Schleifen ausgeformt. Eine Überschneidung des vorderen Winterkranzes mit dem geöffneten Türflügel wurde durch eine neue Anordnung des ersten Einstiegs behoben. Kontinuierliche Normalen beseitigen Schattierungsrillen an der Nase; Lampenflächen sind entlang der Knickkante der Front aufgeteilt, damit sie den Lack nicht durchschneiden.

## Grenzen des Bildabgleichs

**Kein bestätigter perfekter 1:1-Nachbau.** Silhouette, Farbaufteilung und Ausstattung sind nach den Bildern umgesetzt; folgende Unterschiede bleiben sichtbar:

- Die Vorlagen haben weichere Studiobeleuchtung, stärkere Glanzlichter und Lichtschein. Der aktive Compatibility-Renderer und die vorhandene Spielbeleuchtung liefern eine deutlich einfachere Schattierung. Die Fenster zeigen einen modellierten, vereinfachten Innenraum.
- Das Spiel verwendet weiterhin drei Wagen mit den bisherigen Längen von 12/11/12 m und zwei Doppeltüren je Seite und Wagen. Der normale Referenzzug zeigt eine längere, fünfteilige Wagenreihung mit anderer Türverteilung. Damit unterscheiden sich die Gesamtproportionen und Fensterabstände.
- Fahrwerk, Einstiegshöhe und Klappmechanik folgen den spielrelevanten Maßen. Die mehrteiligen Klappstufen sind deshalb nicht identisch mit den kurzen Trittbrettern der normalen Vorlage.
- Dachgeräte, Sitze, Girlanden, Schneekappen und Details sind räumlich nach den sichtbaren Ansichten rekonstruiert. Nicht sichtbare Dach-/Rückseiten und Innenraumteile mussten konstruiert werden. Die vorhandene dynamische Zielanzeige bleibt auch beim WinterSpecial erhalten.

## Prüfungen

| Prüfung | Ergebnis |
|---|---|
| `tests/qa/train_reference_test.tscn` | **82 Checks, 0 Fehler:** beide Varianten, alle drei Wagen, endliche Geometrie und gültige Normalen, getrennte Varianten, Innenlicht, Zielanzeige, korrekte Türseite, vollständige Schiebewege frei von Kränzen, Stufen/Boarding auf beiden Seiten, Ausrichtung bei Federungsneigung, Schließen und Einfahren |
| `tests/train_test.tscn` | **0 Fehler:** Fahrzeugmaße, Fahrt und Kreuzung, Signale, Halt/Bahnsteigwahl, Türen, Federung, Innenlicht, Zielanzeige, Güterverkehr und Speichern/Laden |
| `tests/festival_test.tscn` | **0 Fehler:** Festkalender, Sonderzüge und Ereignisse |
| `tests/npc_test.tscn` | **10 Fehler in Charaktermodell-Prüfungen:** alte Erwartungen an mindestens 18 Meshteile bzw. Winter-/Sommerkleidung passen nicht zu den bereits vorhandenen Charakteränderungen. Die Zug-, Fahrgast- und Stufenprüfungen bestehen. Der Gesamt-NPC-Test ist nicht fehlerfrei. |
| Godot-Editorimport | Erfolgreich, keine Skriptfehler |

Die Geometrieprüfung zählt pro Wagen die festen Lack-, Glas-, Innenraum-, Licht- und Dekorationsflächen: normal ungefähr 4.500 Dreiecke, WinterSpecial ungefähr 17.600–19.100. Fahrwerk und bewegliche Türblätter kommen hinzu. Das ist keine FPS-Messung und keine Garantie für Fehlerfreiheit in allen Spielsituationen.

## Erneut prüfen

```powershell
godot --headless --path . res://tests/qa/train_reference_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/train_test.tscn
godot --path . res://tests/qa/train_reference_capture.tscn
godot --path . res://tests/qa/train_game_capture.tscn
```

Der Modellaufbau steht in `scripts/procgen/reference_railcar_meshes.gd`. `RailcarMeshes` stellt weiterhin die bisherigen Maße und den Einstiegspunkt bereit. Die spezialisierten Materialien heißen `assets/materials/railcar_*.gdshader` / `.tres`.
