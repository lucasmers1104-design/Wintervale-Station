# Etappe 7 – Visual Polish, Bug Hunt & Winter Atmosphere

Vorgehen: Zuerst eine Bestandsaufnahme mit neun Screenshots (Bahnsteig mit Zug, Zug aus der
Nähe, Gleise, Bahnhof von oben, Dorfstraße, Figuren an der Bank, goldene Stunde, Nacht am
Bahnsteig, Nacht von oben) und eine Leistungsmessung. Danach gezielte Verbesserungen, jede
mit Vorher/Nachher-Bildern geprüft. Nichts wurde grundlos neu geschrieben.

## In Etappe 7 gefundene und behobene Fehler

| # | Fehler | Ursache | Behebung |
|---|---|---|---|
| 1 | Kamera der Spielfigur fährt durch Häuser, Anzeigetafel, Laternen | SpringArm prüfte nur Ebene „Welt“ | Kollisionsmaske Welt + Objekte (`player.tscn`) |
| 2 | Bewohner laufen durch stehende Bewohner hindurch (z.B. Wartende am Bahnsteig) | Ausweichen gab es nur für die Spielfigur | `NpcDirector.is_path_blocked` beachtet stehende Bewohner; sie werden seitlich umgangen (zwei Gehende blockieren sich nie) |
| 3 | Schnee auf Tannen praktisch unsichtbar | Schneekegel lagen *unter* der nächsten Nadelstufe | Schnee als Band auf dem sichtbaren Außenring jeder Stufe (`VillageMeshes._snow_band`) – gilt für Dorf- und Waldbäume |
| 4 | Laternen überstrahlen nachts (Glas-Emission 4, Licht 3 → Bloom-Fleck, weiß ausgebrannte Zugseiten) | zu hohe Werte | Licht 1,7, Glas 1,9, weicherer Abfall (Dämpfung 1,3), Bahnsteiglampen 2,0 |
| 5 | Bauvorschau rechnete die komplette Platzierungsprüfung jedes Frame (Physik-, Gleis- und Wegetests) | keine Zwischenspeicherung | nur neu prüfen, wenn sich Objekt, Lage, Drehung, Farbe oder das Dorf ändern |
| 6 | Alle Bewohner „dachten“ im selben Frame nach (Lastspitzen alle 0,4 s) | gleicher Startwert | zufällig versetzter Start |
| 7 | Zugfenster tagsüber flach grau | Standardglas spiegelt im Kompatibilitätsmodus nichts | eigener Fenster-Shader (Himmelsreflexion, Glanzstreifen, Innenlicht) |
| 8 | Toter Code: alte Tannenfunktion und ungenutzte Farbkonstanten | Überbleibsel | entfernt |

### Bereits während Etappe 6 gefunden (in deren Commit behoben)

| Fehler | Behebung |
|---|---|
| Absturzgefahr „invalid previously freed instance“ nach Abriss/Laden eines Hauses (`NpcDirector.get_home`) | Gültigkeit prüfen, bevor typisiert wird |
| Hausgrundflächen falsch (Dachüberstand mitgezählt, Bauernhaus nicht zentriert) → Wege zur Haustür galten als „durch das Haus“ | exakte Grundfläche je Haus |
| Ungenutzte Kollisionsform bei Lichterketten (Speicherleck) | Form erst anlegen, wenn sie gebraucht wird |
| Laufende Klänge hielten beim Beenden Objekte fest | `SoundLibrary.stop_on_exit` / `SoundLibrary.play` |
| Licht-Tweens ohne Inhalt bzw. ohne Startwert (Fehlermeldungen) | nur tweenen, wenn es Lichter gibt; Startwert setzen |
| Pendler verpassten manchmal ihren Zug | Zeitfenster 2,6 h, mindestens ein Pendler pro Familie |

Weiter untersucht, **ohne** Fehler zu finden: Z-Fighting (Wege, Dorfplatz, Bahnsteigpflaster,
Schnee auf Schwellen – alle Flächen haben eigene Höhenstufen), Zughalte und Trittstufen
(Sicherheitstests laufen jeden Frame), Speichern/Laden (Dorf, Bewohner, Züge), Kamera in der
Vogelperspektive, Fußwegenetz (Rückfall aufs feste Netz, wenn etwas nicht verbunden ist).

## Verbesserungen im Überblick

### Modelle
- **Gleise:** neues Schotterprofil mit weichen Schneewehen an den Flanken und fast freier
  Krone (Züge wirbeln den Schnee weg); wärmerer, hellerer Schotter. **Holzschwellen** mit
  hellerer, leicht zurückgesetzter Oberseite (weiche Kante), hellem Hirnholz an den Enden,
  minimal verdreht (handgemacht) und Schnee an den Enden außerhalb der Schienen.
- **Bäume:** alle Nadelbäume (Wald, Tunnelberg, Dorf) nutzen dieselben hochwertigen Modelle
  mit sichtbaren Schneebändern; sie wiegen sich leicht im Wind.
- **Bahnsteig:** warmes Sandsteinpflaster im Läuferverband statt grauer 1-m-Kacheln, nur
  vereinzelte Schneereste; wärmere Wand- und Kantensteine, Holz wärmer.
- **Zugfenster:** eigener Shader – Himmelsreflexion oben, stilisierter Glanzstreifen, warmes
  Innenlicht unter den Deckenlampen. **Hausfenster** mit demselben Glanzstreifen.
- **Figuren:** Kindchenschema (Augen etwas tiefer und weiter auseinander), Glanzpunkte in
  den Knopfaugen (blinzeln mit), glänzendere Vinyl-Haut, gestrickte Bündchen an den
  Fäustlingen, dunkle Schuhsohlen, rosigere Wangen.

### Winter & Licht
- **Schneeglitzern:** das Gelände hat einen eigenen Shader – winzige Kristalle funkeln im
  Sonnenlicht und nachts warm im Laternenlicht, in der Ferne ausgeblendet (kein Flimmern).
- **Talnebel:** leichter Höhennebel für mehr Tiefe.
- **Abendstimmung:** etwas weniger Magenta, wärmer.
- **Nacht:** Laternen und Bahnsteiglampen als weiche, warme Lichtinseln statt greller Flecken.

### Klang
- **Holzknarren:** Bänke knarren leise, wenn sich jemand setzt.
- **Holzschritte:** auf dem Bohlenübergang klingen Schritte hohl nach Holz.
- **Laternen-Ambiente:** ganz leises, warmes Summen mit gelegentlichem Knistern, nur direkt daneben hörbar.
- **Bahnhof-Hall:** unter dem Bahnsteigdach ein dezenter Nachhall (eigener Audio-Bus, `StationAcoustics`).
- **Zugrollen:** zusätzlich weiches Wummern der Drehgestelle und leises Schienensingen.
- Bereits vorhanden und beibehalten: Wind (dynamisch mit Wetter und Nacht), Schneeschritte, ferne Vögel.

## Überarbeitete Modelle und Dateien

```
scripts/procgen/rail_meshes.gd          Schotterprofil, Schwellen, Farben
scripts/procgen/village_meshes.gd       Schneebänder der Tannen (_snow_band)
scripts/procgen/nature_meshes.gd        Waldtannen = Dorftannen, toter Code entfernt
scripts/procgen/station_meshes.gd       Pflaster, Farben
scripts/procgen/house_meshes.gd         exakte Grundflächen
scripts/characters/character_model.gd   Gesicht, Glanzpunkte, Bündchen, Sohlen, Sichtweite
scripts/world/prop_scatter.gd           Waldbäume mit Wind-Material (tree_material)
assets/materials/snow_terrain.*         Schneeglitzern (neu)
assets/materials/train_window.gdshader  Zugfenster (neu), train_glass.tres
assets/materials/house_window.gdshader  Glanzstreifen
scripts/audio/station_acoustics.gd      Bahnhofshall (neu)
scripts/audio/sound_library.gd          Holzschritte, Knarren, Laternen-Summen, volleres Rollen
scripts/props/lantern.gd, lantern.tscn  weicheres Licht, Summen, Ausblenden in der Ferne
scenes/player/player.tscn               Kamera-Kollision
```

## Performance

| Maßnahme | Wirkung |
|---|---|
| Lichter blenden in der Ferne aus (Dorf 60 m, Laternen/Bahnsteig 70 m, Signale 60 m) | ferne Lichter kosten nichts |
| Figuren ab 120 m nicht mehr gezeichnet, Details (Augen, Knöpfe, Sohlen, Bündchen) ab 45 m und ohne Schatten | weniger Draw-Calls bei vielen Bewohnern |
| Kleine Deko (Gras, Lampen, Briefkasten …) ohne Schatten | weniger Schatten-Draw-Calls |
| Sonnenschatten bis 95 m statt 120 m | weniger Objekte im Schattenpass |
| 3 statt 4 Waldbaum-Varianten (je Variante ein MultiMesh) | weniger Draw-Calls |
| Bauvorschau prüft nur bei Änderungen | Build-Mode flüssiger |
| Bewohner-Denken zeitlich verteilt | keine Lastspitzen |

Messung auf dem Entwicklungs-Laptop (Intel HD 520, Kompatibilitätsmodus, 1280×720):

| Ansicht | Vorher | Nachher |
|---|---|---|
| Vogelperspektive nah – Draw-Calls | 701 | 503 |
| Vogelperspektive Übersicht – Draw-Calls | 960 | 1009 (Dorf mit mehr Details sichtbar) |
| Bildrate | ~10 fps | ~9,5 fps |
| **ohne Grafikausgabe** (reine Spiellogik) | – | **144 fps** (≈3 ms Logik + 1,5 ms Physik pro Frame) |

Die Bildrate auf diesem Laptop ist durch den sehr schwachen Grafikchip begrenzt, nicht durch
die Spiellogik (144 fps ohne Grafik). Ob auf einem Mittelklasse-PC stabil 60 fps erreicht
werden, kann erst auf dem Test-PC geprüft werden. Das Schneeglitzern kostet hier gemessen ~3 %.
