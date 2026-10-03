# Visueller Abgleich – Master Debugging V2

Alle Aufnahmen sind echte Godot-Renderings dieses Rechners (Intel HD 520, **GL-Compatibility-Renderer**). Auf dem Spiel-PC (Forward+) wirken Licht und Schatten etwas reicher (u. a. SSAO).
Werkzeuge: `tests/qa/menu_capture.gd` (alle Menüseiten in 1672 × 941 = Referenzgröße), `tests/qa/visual_capture.gd` (feste Kamera, Uhrzeit, Jahreszeit, Wetter).

## Grundsatz nach CD-Vorgabe (30.09.)

> „Verändere nichts am GUI-Style. Nur wenn das GUI nicht genau so aussieht wie die Referenzbilder, darf es verbessert werden, damit es genau so aussieht.“

Deshalb gilt: Jede GUI-Änderung in diesem Durchgang gleicht eine Seite **an ihr freigegebenes Referenzbild** an. Rahmen, Knöpfe, Symbole und Häkchen werden **aus den Referenzbildern selbst** geschnitten (reproduzierbare Werkzeuge unter `tools/`), nicht neu gezeichnet. Seiten ohne Referenzbild (New Game, Lösch-Dialog) wurden nicht umgestaltet.
Den zwischenzeitlich umgestalteten Notizbuch-Knopf im HUD habe ich auf das ursprüngliche Aussehen zurückgesetzt (nur eine Mindestgröße bleibt, damit er nicht auf wenige Pixel schrumpft).

## Menüseiten gegen Referenz

| Seite | Referenz | Vorher (Abweichung) | Nachher |
| --- | --- | --- | --- |
| Hauptmenü | `main_menu/*`, `loading_screen_reference.png` | Bahnhofsschild, Wegweiser, Zugziel und Tafel waren per Code gezeichnete flache Rechtecke mit dünner Schrift (vom CD gemeldet: „sieht scheiße aus“, im Ladescreen richtig) | die gemalten Schilder aus der Ladescreen-Grafik ausgeschnitten (`tools/extract_menu_signs.gd`) und an denselben Stellen eingesetzt; Versionsnummer zeigt die echte Projektversion |
| New Game | `new_game.png` (vom CD geliefert, 30.09.) | eigene Pergamentseite ohne Referenz | Referenzbild als Seite; live: Reisename, Figur (Male/Female, echte Spielfigur, im Spielstand gespeichert), Startjahreszeit, Jahreszeit in der Infozeile; Auswahlzustände aus der Vorlage erzeugt (`tools/extract_new_game_states.gd`) |
| HUD-Leiste | `hud_status_bar.png` | CD: „viel zu groß“ (52 % der Bildbreite) | auf ≈ 35 % verkleinert, näher am oberen Rand; Notizbuch-Symbol bleibt klickbar groß |
| Settings · Graphics | `settings_graphics.png` | schlichte Liste ohne Symbole, Knopf-Schalter „● On“, Hinweis „Renderer effects are unavailable“ | Zeilen mit Symbolen und Trennlinien, Pill-Schalter, Pergament-Auswahlfelder mit Winkel; **Shadow Quality, Bloom, Particle Density** wie in der Referenz – mit echter Wirkung (Test `settings_effects_test`). Nicht übernommen: Texture Quality und View Distance (keine echte Entsprechung im Spiel, daher keine Attrappe) |
| Settings · Audio | `settings_audio.png` | Liste ohne Symbole | Symbole, Trennlinien, goldene Regler wie Referenz. Voice/Announcements nicht übernommen (gibt es im Spiel nicht) |
| Settings · Controls | `settings_controls.png` | vier Tasten-Knöpfe in einer Zeile | zwei Spalten „Camera Settings“ / „Key Bindings“ mit Symbolen und hellen Tastenfeldern wie Referenz |
| Settings · Gameplay | `settings_gameplay.png` | Liste ohne Beschreibungen; **Back/Reset/Apply-Klickflächen lagen 41 px zu hoch** (Knöpfe sitzen auf dieser Vorlage tiefer) | Zeilen mit Symbol, Titel und Beschreibungszeile wie Referenz; Klickflächen auf die gemessenen Knopfkanten gesetzt |
| Load Save | `load_save.png` | einfache Karten, 150-px-Knöpfe, „New Journey“-Leiste | Karten mit Rahmen aus der Referenz, neueste Reise gold hervorgehoben, Kalender-/Jahreszeiten-/Zug-/Einwohner-/Uhrsymbole, Load/Delete-Knöpfe mit Symbol, Karte „Empty Slot · New Save“ mit Skizze, Stempel „Good Journeys Ahead“ bleibt sichtbar |
| Achievements | `achievements.png` | Listenzeilen, dunkle gesperrte Siegel | „Total Progress“-Zeile (live), Kategorien mit Symbol, Motto und Zähler, 3er-Kartenraster mit Rahmen aus der Referenz, gesperrte Siegel silbergrau, Häkchen bzw. Balken + Zahl, Detailkarte im Bilderrahmen |
| Credits | `credits.png` | große Pergamentfläche verdeckte Symbole, Linien und Skizzen | Referenz 1:1; nur die erfundenen Beispielnamen sind entfernt (`tools/clean_credits_names.gd`) und durch belegte Angaben ersetzt |
| Ladescreen | `loading_screen_reference.png` | entsprach der Referenz | unverändert |
| HUD-Leiste | `hud_status_bar.png` | aufgemalte Uhr zeigte immer 4:00 | Leiste unverändert, nur die gemalten Zeiger entfernt; zwei echte Zeiger laufen mit der Spielzeit |

Bewusst verbleibende Unterschiede zur Referenz (keine Attrappen): erfundene Beispielwerte der Bilder (z. B. „28 / 60 Achievements“, „Busy Platform“) sind durch echte Spieldaten ersetzt; Optionen ohne Spielfunktion fehlen. Bei mehreren Reisen erscheint unter den Achievements eine Reise-Auswahl (in der Referenz nicht vorhanden, für per-Reise-Fortschritt nötig).

## Modelle und Animationen (Durchgang 2)

Werkzeug: `tests/qa/model_review.gd` – freie Kamera nimmt Züge (Front, ¾, Seite, Drehgestell, Trittstufe, Kupplung, Dach, Nacht), Güterzug, Figuren, alle Hausformen, Bahnhof, alle Pflanzen in Winter und Sommer sowie Bildstreifen (Gehzyklus, Türsequenz, Fahrgastwechsel) auf.

| Motiv | Befund | Änderung | Geprüft |
| --- | --- | --- | --- |
| Triebzug-Front | Frontscheibe wirkte wie eine flache schwarze Platte, keine Wischer | getöntes Glas mit Himmelsspiegelung und weichem Glanz, nachts Pultschimmer; zwei geparkte Scheibenwischer | Front ¾ Tag und Nacht |
| Zugschürzen, Figuren | Sägezahn-Schattenakne bei tiefer Wintersonne | Schatten-Bias von Sonne und Mond angepasst | Türsequenz-Streifen vorher/nachher |
| Laternen | harte, gezackte Schattenkanten | weichere Schatten; Schatten ab 35 m ausgeblendet (Leistung) | Nachtaufnahmen |
| Birke im Winter | „letzte goldene Blätter“ schwebten als gelbe Plättchen | als Saisonlaub: im Winter unsichtbar, im Herbst golden | Bahnhof, Stadthaus |
| Hecke im Winter | flache Schneeplatte über den Büschen → weiße Leiste mit Zacken | Kern abgesenkt, Buschkugeln tragen Schneehauben | Winter und Sommer |
| Hausfenster am Tag | graue Kacheln | Himmel spiegelt oben, unten warmer Raumschimmer (dezent), nachts unverändert | Bauernhaus vorher/nachher |
| Türen und Trittstufen | – | Ablauf korrekt: Stufe aus → Türen auf → erst aussteigen, dann einsteigen → Türen zu → Stufe ein → Abfahrt | Bildstreifen + `npc_test`/`train_test` |
| Gehzyklus Spielfigur | – | Beine wechseln sauber, kein sichtbares Gleiten | Bildstreifen |
| Güterlok, Wagen, Ladung, Häuser, Bahnhof | keine Mängel gefunden | – | Nahaufnahmen |

## Spielwelt vorher/nachher

| Motiv | Messung vorher | Nachher | Bewertung |
| --- | --- | --- | --- |
| Bahnhof Wintermittag | 41,3 % ausgebrannte Pixel | Weißpunkt 2,0: Varianten 1,6 → 8,1 %, 2,4 → 0,5 % | Schnee zeigt wieder Facetten und lavendelfarbene Schatten |
| Wege Nahaufnahme | 23,1 % | 1,6 → 1,9 %, 2,4 → 0,4 % | Wegkanten und Pflaster lesbar |
| Abend / Nacht | 0,1–0,2 % | ≈ 5–8 % dunkler | warme Lichtinseln unverändert |
| Birke im Sommer/Frühling | kahl („toter Baum“) | Laub | Winter unverändert kahl, Herbst golden |
| HUD 09:41 / 16:00 / 23:27 / 00:00 | Uhr zeigt immer 4:00 | Zeiger = Digitalzeit | geprüft im Test und im Bild |

## Figuren nach den Charakterblättern

Vorlagen: 22 Charakterblätter des Creative Directors (`docs/character_references/`, je vorne,
nach links, hinten, nach rechts). Werkzeug: `tests/qa/character_sheet.gd` rendert die Figur mit
gleicher Kamera und gleichem Maßstab (483 px/m, Fußlinie 866 px) und legt Vorlage und Spiel
übereinander; Detailausschnitte mit Messlinien alle 50 px. Jede Figur wurde erst nach der
Sichtprüfung aller vier Ansichten abgeschlossen.

| Figur | Wichtigste Merkmale, die nachgebaut und geprüft wurden |
| --- | --- |
| player_male | Tannenzapfen-Haar mit Spitze, Rollkragen, Latzhose mit Messingknöpfen, Gesäßtaschen |
| player_female | Kopftuch mit Knoten, Dutt, Seitenscheitel-Pony, lange Strähnen vor den Ohren |
| gardener | Strohhut mit grünem Band, tiefer Zopf mit Haargummi, Halstuch, Latzhose |
| grandpa_cardigan | Haarkranz-Wolken, runde Brille, Strickjacke mit V, Holzknöpfe, Hose mit Aufschlag |
| newsboy | Schiebermütze mit schräger Kante und Schirm, Sommersprossen, kariertes Hemd, Hosenträger-Shorts |
| bow_girl | Bob, Dutt mit großer Schleife, Bubikragen mit Bögen, Faltenrock-Trägerkleid, Strumpfhose |
| smith | Locken, Vollbart, buschige Brauen, Lederschürze mit Werkzeugtasche, Stulpenhandschuhe |
| baker | Kochmütze mit Streifen, Kleid mit Rundkragen und Puffärmeln, Schürze mit Blattmotiv und Schleife |
| sailor | Bommelmütze mit Strickgitter, Ringel-Rollkragen, Cargo-Shorts, Lederhosenträger, Bart |
| granny_gingham | Vichy-Kopftuch, Mittelscheitel, offene Vichy-Strickjacke, Faltenrock, Brille |
| satchel_boy | Weste mit Spitzen und Blende, Umhängetasche mit Schnalle, breite Hosenaufschläge |
| scout | Wanderhut mit Feder und Knopf, Halstuch hinten geknotet, geschnürte Tunika mit Gürtel |
| winter_girl | Daunenweste, Strickpulli mit langem Bund, Karo-Schal mit Fransen, Jeans, Fäustlinge |
| grandpa_fairisle | Norwegerband auf Rumpf und Ärmeln, Schalkragen, graue Mütze, Schnurrbart |
| earmuff_boy | Ohrenschützer, Daunenjacke mit Zipper und Klappentaschen, Schnürstiefel mit Strickrand |
| duffle_girl | Dufflecoat mit Knebeln, zweifarbige Bommelmütze, Blockstreifen-Schal, tiefe Zwillingsdutts |
| lumberjack | Büffelkaro-Hemd, grüne Daunenweste, rote Mütze, Vollbart |
| beret_girl | Barett, langer Pony, Strickkleid, schlichte Latzschürze mit Rückenschleife |
| elf_girl | Wichtelmütze mit Pelzband und umgeknickter Spitze, Mantel mit Pelzmanschetten und Gürtel |
| granny_diamond | Kopftuch mit Nackenknoten, Rauten-Strickjacke über Rollkragen, Karorock, Kniestrümpfe |
| sailor_satchel | Navy-Bommelmütze, Ringelpulli, Cargo-Latzshorts, roter Schal, Tasche |
| trapper | Fliegermütze mit Pelzklappen, Parka mit Pelzkragen, Karo-Schal, Schnurrbart |

Bekannte Restabweichungen (bewusst klein gehalten): Muster werden im Shader gezeichnet und
sind gröber als in den Vorlagen (Karo, Norweger, Rauten); Stoffe sind facettiert statt
weich modelliert; die Rauten der granny_diamond-Strickjacke sitzen etwas weiter außen.

Im Spiel geprüft: beide Spielfiguren am Bahnhof (`tests/qa/character_capture.gd`) und alle
20 NPC-Figuren nebeneinander in der Welt (Aufstellung im Schnee, Tageslicht).

**Gefundener Fehler dabei:** Bei vielen Figuren gleichzeitig meldete der Renderer „Too many
instances using shader instance variables“ (Kompatibilitäts-Renderer: höchstens 4096).
Ursache: Jedes der sechs Figurenteile trug den Blinzel-Parameter. Behoben: nur der Kopf nutzt
ihn (eigener Kopf-Shader über eine gemeinsame Include-Datei); danach keine Meldung mehr.
