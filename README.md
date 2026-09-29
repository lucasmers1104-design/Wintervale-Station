# Wintervale Station

Ein gemütliches Low-Poly Eisenbahn- und Dorfbau-Spiel im Winter.
Engine: **Godot 4.7** (GDScript, Renderer Forward+).

Aktueller Stand: **Etappe 8 – Güterbahnhof, Wirtschaft und lebendiges Dorf**: Güterzüge bringen Holz, Ziegel, Glas, Stahl und Stein zum neuen Güterbahnhof, ein Portalkran lädt alles sichtbar ins Lager. Häuser kosten Geld und Material, entstehen als Baustelle und bekommen Bewohner, die mit dem Zug zuziehen. Das Notizbuch (N) zeigt Lager, Einwohner, Fahrplan, Bauprojekte und Finanzen. Davor, **Etappe 7**: überarbeitete Gleise, Bäume, Bahnsteig, Fenster und Figuren, Schneeglitzern, weichere Nachtbeleuchtung, Bahnhofshall und 8 behobene Fehler. Dazu aus Etappe 6: Hinter dem Bahnhof liegt ein kleines Dorf mit Dorfplatz; im Build-Mode baut man Häuser (8 Formen), Wege, Natur, Beleuchtung und Dekoration. Jedes neue Haus bekommt eine Familie, die morgens über die Wege zum Bahnhof geht und mit dem Zug fährt.
Das Spiel startet in der Vogelperspektive über dem Bahnhof. Unten rechts zeigt eine Legende immer die passenden Tasten.

## Starten

1. Godot 4.7 (Standard-Version, nicht .NET) von https://godotengine.org herunterladen.
2. Godot starten → **Importieren** → `project.godot` in diesem Ordner wählen.
3. Beim ersten Öffnen importiert Godot kurz die Dateien.
4. **F5** (oder ▶ oben rechts) startet das Spiel.

Voraussetzung: Eine Grafikkarte mit aktuellem Vulkan-Treiber (Forward+).

## Steuerung

| Erkunden | |
|---|---|
| WASD / Pfeiltasten | Gehen |
| Shift | Laufen |
| Leertaste | Springen |
| Maus | Umsehen |
| Mausrad | Kameraabstand |
| V | Ich-Perspektive ↔ Verfolgerperspektive |
| E | Sprechen / Aufheben / Übergeben (Bewohner, vergessener Koffer) |
| Tab | Zur Vogelperspektive |

| Vogelperspektive | |
|---|---|
| WASD | Verschieben |
| Q / E | Drehen |
| Mausrad | Zoom (zur Mausposition hin) |
| Mittlere Maustaste ziehen | Drehen & Neigen |
| Rechte Maustaste ziehen | Ansicht ziehen |
| Linksklick auf Zug | Kamera fährt ruhig mit (WASD oder Esc beendet) |
| Linksklick auf Weiche | Weiche umstellen |
| B | Build-Mode ein/aus |
| Tab | Zurück zur Figur |
| N | Notizbuch (Lager, Einwohner, Fahrplan, Bauprojekte, Finanzen, Feste) – Reiter per Klick, 1–6 oder Q/E, Esc schließt |

| Build-Mode | |
|---|---|
| 1 Schiene | Klick: Start, Klick: Gleis bauen – danach geht es direkt weiter. Rastet an Gleisenden ein. |
| 2 Weiche | Klick auf ein Gleis setzt eine Weiche, dann den Abzweig zur Seite ziehen. Klick auf eine Weiche stellt sie um. |
| 3 Signal | Klick neben ein Gleis. Die Seite bestimmt die Fahrtrichtung (Signal steht rechts vom Zug). |
| 4 Entfernen | Klick auf Gleis, Signal oder Dorf-Objekt |
| 5 Test | Klick auf Gleis: belegen/freigeben · auf Signal: Halt ein/aus · auf Weiche: umstellen |
| 6–0 Dorf | Häuser · Wege · Natur · Licht · Deko – Objekt per Button oder F, R drehen, C Farbe, Klick setzen (Linien: Start und Ende). Kosten stehen mit Icons unter der Leiste; Häuser entstehen als Baustelle |
| Alt (halten) | Freier Winkel und freie Länge statt 15°-/Meter-Raster |
| Strg+Z / Strg+Y | Rückgängig / Wiederholen |
| Rechtsklick / Esc | Abbrechen (zweites Esc beendet den Build-Mode) |

| Allgemein | |
|---|---|
| N | Notizbuch – auch über den Knopf neben der Uhr |
| T | Zeitraffer (×1 → ×10 → ×60) |
| J | Nächste Jahreszeit (blendet in ein paar Sekunden über) |
| K | Wetter wechseln (sonnig, bewölkt, leichter/starker Schnee, klarer Winterabend, Regen, Nebel) |
| F5 / F9 | Schnellspeichern / Schnellladen |
| F1 | Tastenlegende ein-/ausklappen |
| F11 | Vollbild |

## Automatische Tests

```
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/railway_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/train_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/npc_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/village_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/economy_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/world_test.tscn
godot --headless --path . --fixed-fps 60 res://tests/festival_test.tscn
```

Exit-Code 0 = alle Prüfungen bestanden.

## Weitere Doku

- [docs/ARCHITEKTUR.md](docs/ARCHITEKTUR.md) – Aufbau, Gleisnetz, Stellwerk, Geländeanpassung, Dateien
- [docs/ZUEGE.md](docs/ZUEGE.md) – Züge, Fahrplan, Bahnhofsbetrieb, neue Züge erstellen
- [docs/NPCS.md](docs/NPCS.md) – Figuren, Bewohner, Tagesablauf, neue Bewohner erstellen
- [docs/DORF.md](docs/DORF.md) – Dorf, Häuser, Wege, Bauen, Bewohner neuer Häuser
- [docs/POLISH.md](docs/POLISH.md) – Etappe 7: behobene Fehler, Verbesserungen, Performance
- [docs/WIRTSCHAFT.md](docs/WIRTSCHAFT.md) – Etappe 8: Güterbahnhof, Materialien, Güterzüge, Bauprojekte, Bewohner, Notizbuch, Fehlerliste
- [docs/JAHRESZEITEN.md](docs/JAHRESZEITEN.md) – Etappe 9: Jahreszeiten, Wetter, Wege-Materialien, Schnee, Fehlerliste
- [docs/ZUG_UND_WELT.md](docs/ZUG_UND_WELT.md) – Etappe 9.5: neuer Triebzug, Zug-Animationen, Güterzug- und Bahnhofsdetails, Fehlerliste, Leistung
- [docs/FESTE.md](docs/FESTE.md) – Etappe 10: Weihnachtsmarkt, Herbstfest, Sonderzüge, Zug-Ereignisse, Gespräche, Festmusik
- [CLAUDE.md](CLAUDE.md) – Projektregeln & Vision
