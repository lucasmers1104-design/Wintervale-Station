# Etappe 8 – Güterbahnhof, Wirtschaft und lebendiges Dorf

Die Eisenbahn ist jetzt das wirtschaftliche Herz der Welt: Güterzüge bringen Holz,
Ziegel, Glas, Stahl und Stein zum neuen Güterbahnhof. Ein Portalkran lädt alles
sichtbar ins Lager. Neue Häuser kosten Geld **und** Material, entstehen als
Baustelle, und wenn sie fertig sind, kommt die neue Familie mit dem Zug an.

## Wirtschaftsarchitektur

```
                         ┌──────────────────────────── Economy (Autoload, systems/economy.gd) ───────────────────────────┐
                         │ Geld · Lagerbestand je Material · Reservierungen je Baustelle · Daueraufträge · Kassenbuch    │
                         │ Materialien = GoodsType-Dateien in assets/goods/ (Name, Icon, Herkunft, Max., Preis)            │
                         └───────▲──────────────────▲─────────────────────▲──────────────────────▲───────────────────────┘
                   add_stock /   │   charge_build / │ consume             │ earn                 │ lesen
                   pay (Einkauf) │   refund_build   │                     │                      │
┌────────────────────────────────┴──┐  ┌────────────┴─────────────┐  ┌────┴──────────────┐  ┌────┴──────────────┐
│ FreightYard (World/FreightYard)   │  │ VillageManager (Dorf)     │  │ TownFinances      │  │ Notebook (N)      │
│ Güterschuppen, Lagerhalle, Kran,  │  │ build / demolish,         │  │ Fahrkarten,       │  │ Lager, Einwohner, │
│ Lagerflächen, Leergut, Vögel …    │  │ Baufortschritt, Zuzug     │  │ Gemeindeabgaben   │  │ Fahrplan, Bau,    │
└──────────▲────────────────────────┘  └──────────▲───────────────┘  └───────────────────┘  │ Finanzen          │
           │ hält Zug fest, entlädt                │                                        └───────────────────┘
┌──────────┴────────────────────────┐  ┌──────────┴───────────────┐
│ TrainDispatcher → Train → TrainCar│  │ VillageHouse +           │
│ Ladeplätze je Wagen (TrainMeshes. │  │ ConstructionSite         │
│ CARGO), hold_departure()          │  │ (Zaun, Gerüst, Kran …)   │
└───────────────────────────────────┘  └──────────────────────────┘
```

**Grundsätze**
- `Economy` kennt keine Grafik und keine anderen Systeme – alle anderen rufen nur seine Schnittstelle auf und hören auf seine Signale (`money_changed`, `stock_changed`, `reservations_changed`, `ledger_changed`, `orders_changed`).
- Materialien sind **modular**: eine neue `.tres`-Datei in `assets/goods/` plus Icon genügt, damit Lager, Notizbuch, Kostenanzeige und Kassenbuch sie kennen (siehe unten).
- Kosten werden überall gleich geschrieben: `{"money": 350, "wood": 30, "brick": 12, "glass": 8}`.
- Nichts Hektisches: Es gibt keine Strafen und keine Schulden. Fehlt Geld oder Platz, bleibt die Ware einfach auf dem Zug und fährt zurück.

## Materialfluss vom Güterzug bis zum fertigen Haus

```
 1  Fahrplan: GZ 802 „Baustoffzug“ aus Südtal, an 10:30, ab 13:00, Gleis 3 (Güterbahnhof)
      │  Wagen: Flachwagen (6 Ziegelpaletten à 6), Rungenwagen (3 Stahlbündel à 4), Trichterwagen (3 Greiferladungen Stein à 8)
      ▼
 2  Einfahrt über die Güterweiche auf Gleis 3, Halt mittig am Ladegleis
      │  FreightYard hält den Zug fest (hold_departure), Trassengebühr +40 Taler
      ▼
 3  Planung: Für jedes Stück wird geprüft – bestellt? Platz im Lager? Geld da?
      │  (Nicht bestellte Ware bleibt auf dem Zug und fährt weiter.)
      ▼
 4  Portalkran: fährt hin → senkt Traverse bzw. Greifer → hebt an (jetzt wird bezahlt: „Einkauf 6 Ziegel“)
      │  → fährt zum Lagerplatz → senkt ab → setzt ab: erst jetzt Economy.add_stock(+6 Ziegel)
      │  Auf dem Wagen fehlt das Stück sichtbar, im Lager steht es am nächsten freien Platz.
      ▼
 5  Leergut: leere Palettenstapel / leere Container auf die freien Plätze → Pfand +8 / +20 Taler
      ▼
 6  Kran in Parkstellung, Zug fährt ab (release_departure) nach Nordtal
      ▼
 7  Bauen: Häuschen platzieren → Kosten 350 Taler + 30 Holz + 12 Ziegel + 8 Glas
      │  Geld wird sofort bezahlt, das Material für die Baustelle reserviert (liegt noch im Lager,
      │  ist aber verplant – das Notizbuch zeigt es schraffiert an).
      ▼
 8  Baustelle (06–20 Uhr, 5 Arbeitsstunden): Fortschritt → Material wird anteilig verbaut
      │  (Economy.consume): Stapel an der Baustelle schrumpfen, im Lager verschwinden Stücke,
      │  verbrauchte Ziegel und Glas hinterlassen Leergut am Güterbahnhof.
      ▼
 9  Fertig: Glöckchen, Zaun/Gerüst/Kran verschwinden, Fenster, Licht und Rauch an
      ▼
10  Zuzug: Die Familie (Herkunft Nordtal/Südtal) steigt aus dem nächsten Zug von dort,
      geht mit Koffern ins neue Haus. Weitere Angehörige ziehen an den folgenden Tagen nach.
      Ab dann zahlen sie jeden Abend Gemeindeabgaben und kaufen Fahrkarten.
```

## Materialien

| Material | Herkunft | Zug | Max. Lager | Start | Preis/Stück | Stück auf dem Wagen |
|---|---|---|---|---|---|---|
| Holz | Sägewerk Nordtal | GZ 801, GZ 803 | 150 | 70 | 2 | Stammbündel (10) auf Rungenwagen |
| Ziegel | Ziegelei Südtal | GZ 802, GZ 804 | 96 | 36 | 3 | Palette (6) auf Flachwagen |
| Glas | Glashütte Nordtal | GZ 803 | 64 | 24 | 5 | Container (8) auf Containertragwagen |
| Stahl | Stahlwerk Südtal | GZ 802 | 48 | 16 | 6 | Trägerbündel (4) auf Rungenwagen mit rot-weißen Rungen |
| Stein | Steinbruch Südtal | GZ 802, GZ 804 | 120 | 60 | 1 | Schüttgut (3 × 8) im Trichterwagen, Kran mit Greifer |

Startgeld: 3.000 Taler.

## Güterzüge (Fahrplan)

| Zug | Gattung | Wagen | an – ab | Ladung |
|---|---|---|---|---|
| GZ 801 | Holzzug (grün) | Lok + 2 Rungenwagen | 07:05 – 08:20 | 60 Holz |
| GZ 802 | Baustoffzug (blau) | Lok + Flach- + Rungen- + Trichterwagen | 10:30 – 13:00 | 36 Ziegel, 12 Stahl, 24 Stein |
| GZ 803 | Güterzug (orange) | Lok + 2 Containerwagen + Rungenwagen | 14:25 – 16:00 | 32 Glas, 30 Holz |
| GZ 804 | Schüttgutzug (ocker) | Lok + 2 Trichterwagen + Flachwagen | 18:20 – 20:45 | 48 Stein, 36 Ziegel |

Die Abfahrtszeit ist ein Richtwert: Der Zug wartet, bis der Kran fertig ist (höchstens drei Spielstunden).

## Einnahmen und Ausgaben

| Buchung | Wann | Betrag |
|---|---|---|
| Fahrkarten | jede Person, die in Wintervale einsteigt | +4 |
| Gemeindeabgaben | jeden Abend um 18 Uhr, je Einwohner | +14 |
| Trassengebühr | jeder Güterzug am Güterbahnhof | +40 |
| Leergut-Pfand | leerer Palettenstapel / leerer Container zurück | +8 / +20 |
| Materialeinkauf | beim Anheben durch den Kran | Preis × Menge |
| Baukosten | beim Setzen eines Objekts | siehe Notizbuch „Bauprojekte“ |
| Rückerstattung | Abriss oder Rückgängig (nur Selbstgebautes; das Startdorf war geschenkt) | alles zurück |

## Baukosten (Auszug)

| Objekt | Kosten | Bauzeit |
|---|---|---|
| Häuschen | 350 Taler, 30 Holz, 12 Ziegel, 8 Glas | 5 h |
| Chalet | 450, 45 Holz, 6 Ziegel, 10 Glas, 2 Stahl | 6 h |
| Stadthaus | 600, 20 Holz, 36 Ziegel, 12 Glas, 4 Stahl, 6 Stein | 7 h |
| Bauernhaus | 650, 50 Holz, 18 Ziegel, 10 Glas, 12 Stein | 7 h |
| Turmhaus | 700, 24 Holz, 24 Ziegel, 14 Glas, 6 Stahl, 16 Stein | 8 h |
| A-Frame-Hütte | 380, 40 Holz, 12 Glas | 4 h |
| Scheunenhaus | 520, 55 Holz, 12 Ziegel, 6 Glas, 4 Stahl | 6 h |
| Gaubenhaus | 800, 36 Holz, 30 Ziegel, 16 Glas, 4 Stahl, 10 Stein | 8 h |
| Laterne | 30 Taler, 2 Stahl | sofort |
| Straßenlaterne | 60, 3 Stahl, 1 Glas | sofort |
| Wege | je Meter: Kies 3 + 0,5 Stein, Steinweg 5 + 1 Stein, Straße 8 + 1,5 Stein | sofort |
| Dorfplatz | 500, 40 Stein, 10 Holz, 4 Stahl | sofort |

Alle Werte stehen in `VillageCatalog.COSTS` (eine Tabelle). Brücken gibt es im Spiel noch
nicht – das Beispiel „Brücke = Holz + Stein“ lässt sich später einfach als neuer Eintrag
ergänzen.

## Bauprojekte

1. **Platzieren** (Build-Mode, Taste 6): Die Vorschau zeigt die Kosten mit Icons unter der Objektleiste; fehlt etwas, ist die Vorschau rot („Fehlt: 6 Glas“).
2. **Material reservieren**: Geld wird bezahlt, Material zurückgelegt (`Economy.charge_build`).
3. **Baustelle erscheint** (`ConstructionSite`): Bauzaun mit rot-weißer Warnlatte und Einfahrt vor der Tür, Schild „Hier entsteht ein neues Zuhause“, warme Baustellenlaterne, Materialstapel (Bretter, Ziegelpalette, Glaskiste, Stahlträger, Steinhaufen), kleiner Baukran, zwei Bauarbeiter.
4. **Baufortschritt** (nur 06–20 Uhr): Abschnitte „Baustelle wird eingerichtet → Fundament und Mauern → Rohbau → Dachstuhl → Innenausbau“. Das Haus wächst von unten nach oben (Shader `construction_reveal`, frische Baukante leicht heller), das Gerüst wächst Etage für Etage mit, der Kran schwenkt und hebt, Arbeiter tragen zwischen Stapel und Haus, Hammer und Säge sind zu hören.
5. **Fertig**: Glöckchen, Baustelle baut sich sanft ab, Fenster/Lampen/Rauch an, die Familie ist unterwegs.

## Bewohner

- **Haushaltsgröße**: aus Hausgröße und Startwert, 1–4 Personen.
- **Zuzug**: die ersten beiden sofort nach Fertigstellung (mit dem Zug), weitere Angehörige an den folgenden Tagen – die Einwohnerzahl wächst organisch. Keine zufälligen Spawnpunkte: Neue Bewohner steigen immer aus einem echten Zug.
- **Pendelverhalten**: wie bisher (Pendler fahren morgens nach Nordtal/Südtal und kommen nachmittags zurück), Daheimbleibende besuchen den Bahnhof.
- **Tagesrhythmus**: neu ist der **Spaziergang** (Routine `STROLL`): mittags bzw. abends zu einer Bank am Dorfplatz (oder einer anderen Dorfbank), eine Weile sitzen, dann heim. Die Beschreibung („früh auf den Beinen“, „lässt den Morgen ruhig angehen“) steht im Notizbuch.
- **Lieblingsweg**: ein schöner Ort in der Nähe (Dorfplatz, Brunnen, Bank, Laternen, ein Weg). Auf dem Weg zum Bahnhof und zurück gehen sie gern dort vorbei, solange der Umweg höchstens 50 % länger ist.

## Notizbuch (Taste N oder Knopf neben der Uhr)

Ein kleines Spiralnotizbuch mit Ledereinband, Naht, Gummiband, Lesebändchen, liniertem
Papier mit rotem Rand, Washi-Tape und Papierreitern. Überschriften in Handschrift
(Systemschrift „Segoe Print“, sonst eine ähnliche). Reiter per Klick, Tasten 1–5 oder Q/E;
Esc/N schließt. Beim Umblättern raschelt Papier.

| Seite | Inhalt |
|---|---|
| Lager | alle Materialien mit Icon, Bestand/Max. (schraffierter Balken, reservierter Teil kreuzschraffiert), Herkunft, Preis, **Dauerauftrag an/aus**; Kranstatus, nächste Güterzüge mit Ladung, letzte Lieferungen, Leergut |
| Einwohner | Einwohnerzahl, Haushalte (auch Baustellen und „2 von 3 eingezogen“); je Familie: Mitglieder, was sie gerade tun, Rolle, Tagesrhythmus, Lieblingsweg, Tagesplan |
| Fahrplan | Personenzüge (nächster markiert, vergangene blass), Güterzüge mit Zeiten, Gattung, Herkunft, Ladung als Icons und Status |
| Bauprojekte | Baustellen mit Fortschritt, Abschnitt, Reststunden und verbautem Material; zuletzt fertige Häuser; Kostentabelle aller Häuser |
| Finanzen | Gemeindekasse, Einnahmen/Ausgaben von heute nach Art, Bilanz von gestern, Kassenbuch |

## Neues Material hinzufügen (ohne Programmieren, bis auf den Wagen)

1. Icon als SVG nach `assets/ui/icons/goods_<id>.svg` (64 × 64, warmer Umriss #3b2a20).
2. `assets/goods/wood.tres` kopieren, `id`, Name, Icon, Herkunft, Portal, Max., Start, Preis, Farbe, Reihenfolge anpassen.
3. Damit Züge es bringen: in `TrainMeshes.CARGO` einem Wagen das Material zuordnen (oder einen neuen Wagen anlegen) und den Wagen in eine Zuggattung (`assets/trains/*.tres`) aufnehmen.
4. Im Güterbahnhof eine Lagerfläche anlegen (`FreightYard._build_storage`).
5. Kosten in `VillageCatalog.COSTS` können das neue Material sofort verwenden.

## Neue und geänderte Dateien

```
systems/economy.gd                        NEU  Autoload: Geld, Lager, Reservierungen, Kassenbuch, Speichern
scripts/economy/goods_type.gd             NEU  Material (Resource)
scripts/economy/town_finances.gd          NEU  Fahrkarten und Gemeindeabgaben
assets/goods/*.tres                       NEU  Holz, Ziegel, Glas, Stahl, Stein
assets/ui/icons/*.svg                     NEU  5 Material-Icons, 5 Notizbuch-Reiter, Münze, Notizbuch
scripts/freight/freight_yard.gd           NEU  Güterbahnhof: Lager, Kran, Entladen, Leergut, Licht, Vögel, Arbeiter
scripts/procgen/freight_meshes.gd         NEU  Güterschuppen, Lagerhalle, Portalkran, Lagerflächen, Masten, Fahnen,
                                               Gabelstapler, Drehkran, Brennholz, Paletten, Vögel
scripts/procgen/construction_meshes.gd    NEU  Bauzaun, Gerüst, Materialstapel, Baukran, Schild, Laterne
scripts/village/construction_site.gd      NEU  Baustelle mit Kran, Arbeitern und Geräuschen
scripts/ui/notebook.gd, scenes/ui/notebook.tscn  NEU  Notizbuch
assets/materials/construction_reveal.gdshader    NEU  Haus wächst beim Bauen
assets/materials/flag_wave.gdshader, flag.tres   NEU  Fahnen im Wind
assets/materials/cargo.tres               NEU  mattes Material für Ladung und Lager
assets/trains/freight_timber|building|bulk.tres  NEU  Holz-, Baustoff-, Schüttgutzug
tests/economy_test.*                      NEU  115 Prüfungen für Etappe 8

scripts/rail/starter_railway.gd           Gleis 3 (Güterbahnhof) mit zwei Güterweichen und Ausfahrsignalen
scripts/rail/rail_interlocking.gd         release_routes_of(), Zielgleis-Auflösung (siehe Fehlerliste)
scripts/trains/train.gd                   hold_departure()/release_departure(), Abgaswolken, Info „wird be- und entladen“
scripts/trains/train_car.gd               Ladeplätze: detach/attach, Schüttgut-Portionen, Leergut; Abgas der Güterlok
scripts/trains/train_dispatcher.gd        Ladungsmaterial, Fahrwege entfernter Züge freigeben
scripts/procgen/train_meshes.gd           Ladung vom Wagen getrennt (CARGO), neue Wagen wagon_flat und wagon_stake,
                                          Innenwände des Trichterwagens, Ladungsstücke create_cargo()
assets/timetables/wintervale.tres         Güterzüge halten am Güterbahnhof (Gleis 3), neue Gattungen
scripts/village/village_manager.gd        build()/demolish() mit Kosten, Baufortschritt, Haushalte, Zuzug, Lieblingswege
scripts/village/village_house.gd          Bauzustand, Bau-Shader, Baustelle, Fertigstellung
scripts/village/village_catalog.gd        COSTS, get_cost(), get_build_hours()
scripts/village/village_residents.gd      Rolle, Tagesrhythmus, Spaziergang, Herkunft
scripts/npc/npc.gd                        Spaziergang, Ankunft mit dem Zug (Koffer), Lieblingsweg, Statustext
scripts/npc/npc_director.gd               add_resident(…, arriving_from), claim_stroll_spot()
scripts/npc/npc_profile.gd                rhythm, role, favourite_via/-way, came_from
scripts/npc/npc_routine.gd                Activity.STROLL
scripts/building/village_place_tool.gd    Kosten in der Vorschau, bezahlen beim Bauen
scripts/building/rail_remove_tool.gd      Abriss mit Rückerstattung
scripts/ui/hud.gd                         Gemeindekasse neben der Uhr, Notizbuch-Knopf, Kostenzeile mit Icons
scripts/audio/sound_library.gd            Kranmotor, Klacken, Schotter, Hammer, Säge, Umblättern, Glöckchen
systems/input_config.gd, events.gd        Taste N, Signale build_cost_changed, notebook_requested
scenes/main/main.tscn                     FreightYard, FreightStop, TownFinances, Notebook
```

## Gefundene Fehler und ihre Lösungen

### Alte Fehler, die der Güterbahnhof aufgedeckt hat

| # | Fehler | Ursache | Lösung |
|---|---|---|---|
| 1 | Nach dem Laden eines Spielstands (oder wenn ein Zug entfernt wurde) warteten Züge manchmal ewig: „Weiche liegt im Fahrweg eines Zuges“ | Fahrwege eines verschwundenen Zuges blieben reserviert, ihre Weichen damit für immer gesperrt | `RailInterlocking.release_routes_of()`, aufgerufen von `TrainDispatcher.retire()` |
| 2 | Steht ein Zug lange an seinem Ziel (z.B. Güterzug beim Entladen), blieb das Einfahrsignal dahinter gesperrt – RB 315 und RB 316 blockierten sich dadurch fast anderthalb Stunden | Ein Fahrweg wurde erst aufgelöst, wenn der Zug auch seinen Zielabschnitt wieder verlassen hatte | **Zielgleis-Auflösung**: Steht der anfordernde Zug vollständig im letzten Abschnitt seines Fahrwegs, ist der Fahrweg erfüllt und wird frei. Den Abschnitt schützt weiter die Belegung (kein anderer Fahrweg kann hinein). Alle Sicherheitsprüfungen der Zugtests laufen weiter jedes Frame. |
| 3 | Leerer Trichterwagen wäre durchsichtig gewesen | Der Wagenkasten hatte nur eine Außenhaut (bisher lag immer Schotter darauf) | Innenwände und Stirnseiten innen |

### Während Etappe 8 gefunden (vor dem Commit behoben)

| # | Fehler | Lösung |
|---|---|---|
| 4 | Güterschuppen und Lagerhalle: eine Dachseite ohne Schnee, Sparrenköpfe ragten oben aus dem Dach | Dachflächen zeigen jetzt immer mit der Normalen nach oben |
| 5 | Hofbelag sah aus wie ein Schachbrett | Farben je Eckpunkt mit weichen Übergängen, Schneematerial mit Glitzern wie das Gelände |
| 6 | Kran zu langsam (≈ 45 s je Stück, Güterzüge 2,5 h zu spät) | schnellere, weich beschleunigende Achsen; ohne Container fährt die Last niedriger (trotzdem über allen Wagen und Stapeln) → ≈ 20 s je Stück; Fahrplan an die Ladezeiten angepasst |
| 7 | Abriss des (geschenkten) Startdorfs hätte Geld und Material „erstattet“ | Nur bezahlte Objekte werden erstattet (Merkmal „paid“, wird gespeichert) |
| 8 | Verschwand ein Zug während der Kranarbeit (Laden), griff der Kran auf gelöschte Wagen zu | Auftrag wird sauber abgebrochen; Leergut am Haken kommt zurück ins Lager |
| 9 | Laufzeitfehler bei Vögeln auf Waggons, wenn der Zug verschwand | Gültigkeit prüfen, bevor der Wagen benutzt wird |
| 10 | Auf den Lagerflächen konnte man Häuser und Gleise bauen, die Spielfigur lief durch die Stapel | Lagerflächen haben Kollision (Ebene „Objekte“), das Dorf baut nicht auf dem Hof („Gehört zum Güterbahnhof“) |
| 11 | Lieblingswege konnten nach dem Laden anders sein | werden nach dem Laden bestimmt, wenn alle Wege wieder stehen |
| 12 | Wurde der Güterbahnhof vor seinem Aufbau entfernt, baute er sich trotzdem auf (Fehlermeldungen) | Aufbau nur, solange er im Szenenbaum ist |
| 13 | Die Liste bedienter Güterzüge wuchs unbegrenzt | wird geleert, sobald der Zug abgefahren ist |
| 14 | Stahlbündel sahen vor lauter Schnee fast weiß aus | nur noch schmale Schneestreifen auf der oberen Lage |
| 15 | Notizbuch: Lesebändchen verdeckte Text, Reiter-Icons lagen hinter dem Einband | Bändchen schaut nur unten heraus, Reiter weiter außen |

### Tests angepasst (keine Spielfehler)

- `smoke_test` und `railway_test` bauen ihre Testgleise bei x ≈ 10 – genau dort steht jetzt das Kranbein. Ihr „leeres Gelände“ entfernt deshalb auch den Güterbahnhof.
- `train_test`: Die Anlage hat jetzt 17 Gleise, 4 Weichen, 8 Signale, 7 Blöcke. Der Güterzug-Test prüft Halt, Entladen und Abfahrt statt Durchfahrt. Weil der Güterzug länger unterwegs ist, räumen die folgenden Fälle vorher die Züge.
- `village_test`: Ein neues Haus ist erst Baustelle; die Familie zieht nach der Fertigstellung ein; Rückgängig erstattet exakt.

## Leistung

Gemessen auf dem Entwicklungs-Laptop (Intel HD 520, Kompatibilitätsmodus, 1280 × 720), gleiche Ansichten wie in Etappe 7:

| Ansicht | Etappe 7 | Etappe 8 |
|---|---|---|
| Vogelperspektive Übersicht – Zeichenaufrufe | 1009 | 1195 (Güterbahnhof im Bild) |
| Vogelperspektive nah (Bahnhof) | 503 | 543 |
| Blick auf den Güterbahnhof | – | 1766 |
| Bildrate | ~9,5 fps | 8,4–9,9 fps |
| ohne Grafikausgabe (reine Spiellogik) | 144 fps | 142 fps |

Maßnahmen: alle unbeweglichen Teile des Güterbahnhofs in einem Mesh (Leuchtgläser in einem zweiten), Lagerstapel als MultiMesh (ein Zeichenaufruf je Lagerfläche), Lichter blenden ab 70 m aus, kleine Teile ohne Schatten, Arbeiterfiguren ab 90 m ausgeblendet. Den größten Teil der Zeichenaufrufe machen die Sonnenschatten aus (sie verdoppeln jedes Objekt). Ob der Test-PC stabil 60 fps schafft, kann erst dort geprüft werden.
