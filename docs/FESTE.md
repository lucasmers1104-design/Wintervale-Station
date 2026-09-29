# Etappe 10 – Feste und Dorfleben

## Zum Ausprobieren

| Was | Wie |
|---|---|
| Weihnachtsmarkt ansehen | Das Spiel beginnt im Winter – der Markt steht schon. Er öffnet um 15:00; mit **T** (Zeitraffer) bis dahin vorspulen. |
| Lichterfest | Um 17:00 (Winter): kurz vorher versammelt sich das Dorf am großen Baum. |
| Herbstfest | Taste **J** dreimal (Frühling → Sommer → Herbst), dann bis 10:30 vorspulen. Laternenumzug um 18:30, stündlich Reigen am Brunnen. |
| Mit Bewohnern sprechen | In der Figuransicht (**Tab**) zu jemandem gehen, **E** drücken. Nochmal **E** = weiter zuhören. |
| Vergessener Koffer | Manchmal nach einer Abfahrt am Bahnsteig: **E** hebt ihn auf, bring ihn dem suchenden Besitzer (**E**) zurück. |
| Schneeräumzug | Bei starkem Schneefall (Taste **K** bis „Starker Schneefall“) kommt er von selbst. |
| Notizbuch | **N**, Reiter **Feste** (Taste 6): Festkalender, heutiges Programm, Sonderzüge, Dorfchronik. |

## Überblick

```
FestivalDirector (Festivals, main.tscn)
   │  Kalender (FESTIVALS) ← Seasons: Weihnachtsmarkt im Winter, Herbstfest im Herbst
   │  baut am Dorfplatz auf: Budengasse, Baum/Lagerfeuer, Karussell/Bühne, Bogen, Tische
   │  öffnet/schließt täglich, lädt Bewohner ein, holt Gäste, fährt Sonderzüge,
   │  inszeniert Lichterfest, Laternenumzug und Reigen, führt die Dorfchronik
   ├── MarketStall        Bude: Laden klappt auf, Verkäufer, Lampe, Dampf, Kundenplatz
   ├── FestivalTree       Weihnachtsbaum: Lichterwelle, Stern, Funken
   ├── FestivalCarousel   Karussell: dreht, Pferdchen wippen, Lauflicht, Spieluhr
   └── FestivalFire       Lagerfeuer / Feuerkorb: Flammen, Funken, Flackerlicht, Knistern
TrainEvents (main.tscn)   Verspätungen, Schneeräumzug, vergessener Koffer (LostLuggage)
Npc                       neuer Zustand FESTIVAL, Gespräche (E), Sprechblasen
PlayerInteraction         Taste E: nächstes "interactable" vor der Figur
SpeechBubble              Text- und Bildblasen über den Köpfen
EventOverlay (HUD)        großes Fest-Banner und Interaktionshinweis
FestivalSounds            eigene Musik und Festklänge (synthetisiert)
```

## Die Feste

### Weihnachtsmarkt (Winter, täglich 15–22 Uhr)

- **Budengasse** nördlich des Dorfplatzes. Fünf Holzbuden mit verschneiten Satteldächern, Tannengrün am Giebel und Lichterketten:
  - **Glühwein**: Kupfertopf, Becher, Fässer, Dampf.
  - **Lebkuchen**: hängende Herzen mit Zuckerrand.
  - **Kerzen & Sterne**: brennende Kerzen, Strohsterne.
  - **Holzspielzeug**: Holzeisenbahn, Nussknacker, Schaukelpferd.
  - **Heiße Maronen**: Röstofen mit Glut, Papiertüten.
- **Öffnen**: Beim Öffnen klappt der Laden hoch und wird zum Vordach. Der Verkäufer erscheint und streckt sich, drinnen geht die Lampe an.
- **Großer Weihnachtsbaum** am Ende der Gasse (7,4 m): Kugeln, spiralige Lichterkette, leuchtender Stern und Geschenke am Fuß.
- **Kinderkarussell**: gestreiftes Zeltdach, sechs Pferdchen, die auf und ab wippen, Lauflicht am Dachrand, Spieluhr-Walzer.
- **Feuerkorb und vier Stehtische** auf dem Platz. Am Feuerkorb wärmt man sich die Hände; die Tische tragen Windlichter und Tannengrün.
- **Eingangsbogen** zur Dorfstraße: Tannengirlande, Lichterbögen, rotes Schild „Weihnachtsmarkt“.
- **Lichterfest um 17:00**:
  1. Ab 16:33 kommt fast das ganze Dorf zum Baum.
  2. Ein Bewohner hält eine kleine Ansprache (Sprechblasen), die Menge zählt „Drei … Zwei … Eins!“.
  3. Die Lichter laufen in 4,5 s als Welle den Baum hinauf. Der Stern strahlt auf und sprüht goldene Funken; dazu Glockenspiel und ein staunendes „Ahh“.
  4. Alle jubeln und winken, Herzen und Sterne steigen auf, Applaus. Ein Banner zeigt „Der Baum leuchtet!“.
  5. Der Baum leuchtet danach bis in die Nacht.

### Herbstfest (Herbst, täglich 10:30–20:30 Uhr)

- **Vier Buden**: Apfelmost (Äpfel, Flaschen, Fässer), Kürbisse (auch große Stapel vor der Bude), Zwiebelkuchen (dampfende Bleche, Brotkorb), Honig & Wachs (Gläser, Bienenwachskerzen, Strohkorb).
- **Lagerfeuer** im Steinkreis mit Sitzbalken.
- **Bühne** mit Akkordeonspieler. Der Balg zieht sich im Takt auf und zu, dazu eine Polka.
- **Dekoration**: Heuballen zum Sitzen, Kürbisse, Wimpelketten und Papierlaternen zwischen den Buden, Bogen mit Herbstlaub.
- **Reigen**: jede Stunde (zwischen :15 und :40) tanzen bis zu acht Besucher im Kreis um den Brunnen, mit Wiegeschritt im Takt.
- **Laternenumzug um 18:30** (Dämmerung):
  - Die Kinder gehen vorneweg, jeder trägt eine leuchtende Papierlaterne am Stab, die beim Gehen pendelt und ihr Umfeld beleuchtet.
  - Der Zug läuft vom Platz auf die Dorfstraße, ein Stück in beide Richtungen und zurück zum Feuer.
  - Mit dem Umzug zieht ein Flötenlied mit.

### Wer kommt aufs Fest?

- **Bewohner** ohne andere Pläne gehen hin, abends lieber.
- **Gäste aus der Umgebung** kommen zu Fuß ins Dorf, oft Eltern mit Kind: tagsüber einige, abends mehr, zum Höhepunkt ein richtiges Gedränge (bis 16).
- **Sonderzüge**:

  | Zug | Strecke | Ankunft | Abfahrt |
  |---|---|---|---|
  | SZ 24 Weihnachtszug | Nordtal → Südtal | 15:44 | 15:52 |
  | SZ 25 Weihnachtszug | Südtal → Nordtal | 21:30 | 21:38 |
  | EZ 31 Erntezug | Nordtal → Südtal | 10:40 | 10:48 |
  | EZ 32 Erntezug | Südtal → Nordtal | 19:30 | 19:38 |

  - Der Weihnachtszug trägt dunkelgrünen Lack mit Gold und Lichterketten in Girlandenbögen entlang der Dachkanten; der Erntezug ist rostrot mit bernsteinfarbenen Lichtern.
  - Bei der Ankunft klingen Schellen, und 6–9 Gäste steigen aus und gehen aufs Fest. Abends fahren sie mit dem Gegenzug wieder heim.
- **Auf dem Fest**:
  - An den Buden kaufen: Der Verkäufer erzählt und reicht die Ware; Glühwein und Most gibt es im dampfenden Becher.
  - Am Stehtisch plaudern (Bildblasen), dem Karussell oder der Bühne zuschauen, sich am Feuer wärmen, auf Heuballen sitzen.

## Zug-Ereignisse (`TrainEvents`)

| Ereignis | Wann | Was passiert |
|---|---|---|
| Verspätung | stündlich geprüft: bei starkem Schneefall 60 %, Nebel 45 %, leichtem Schnee 22 % | Ein bald fälliger Personenzug kommt 4–16 Minuten später. Es gibt eine Ansage, die Tafel zeigt die Verspätung, Wartende schauen auf die Uhr (Bildblase), Reisende warten entsprechend länger. |
| Schneeräumzug | einmal am Tag bei starkem Schneefall, wenn Schnee liegt | Die gelbe Lok mit großem Keilpflug und Warnstreifen fährt ohne Halt durch, mit Schneefontäne vor dem Pflug und zwei blinkenden orangen Rundumleuchten. Ein Banner und ein Eintrag in der Chronik halten es fest. |
| Vergessener Koffer | nach Abfahrten zwischen 8 und 20 Uhr (20 %) | Ein Koffer steht am Bahnsteig; ein Kofferbild zeigt ihn an. Der Besitzer kommt mit dem nächsten Zug aus seiner Richtung zurück und sucht (Fragezeichen, „Hat jemand meinen Koffer gesehen?“). Bringt man ihn zurück, gibt es überglücklichen Dank, ein Herz und 30 Taler Finderlohn. Sonst findet er ihn selbst, oder der Koffer kommt nach 6 Stunden ins Fundbüro. |

## Gespräche und Dorfleben

- **Taste E** (nur beim Erkunden): Das Nächste vor der Figur (bis 2,4 m) wird gewählt. Der Hinweis unten zeigt z.B. „[E] Mit Greta sprechen“, „Koffer aufheben“ oder „Koffer zurückgeben“.
- **Ein Gespräch** (`NpcDialogue`) besteht aus vier Sätzen, die Buchstabe für Buchstabe in der Sprechblase erscheinen:
  1. **Begrüßung** passend zur Tageszeit, beim ersten Mal mit Vorstellung („ich wohne bei den Bergers“).
  2. **Zwei Themen aus dem Moment**: das Fest (Karussell, Glühwein, Lichterfest, Laternenumzug), der eigene Plan („Ich warte auf meinen Zug nach Südtal“), das Wetter, die Jahreszeit oder das Dorf.
  3. **Abschied**.
- **Wer anders redet**: Kinder reden wie Kinder („Ich will nochmal Karussell fahren!“), Reisende wie Fremde.
- **Beim Gespräch** bleibt der Bewohner stehen, dreht sich zur Spielfigur und winkt bzw. erzählt mit den Händen.
- **Bildblasen**: Wer sich begegnet, plaudert manchmal in Bildern: Schneeflocke, Zug, Herz, Becher, Laub, Sonne … je nach Jahreszeit und Fest. Am Stehtisch, am Karussell und am Feuer tauchen sie immer wieder auf.

## Musik und Klänge (`FestivalSounds`)

Alles ist selbst komponiert und synthetisiert (Wellentabellen), und es wird beim Start im Hintergrund berechnet, damit nichts ruckelt.

| Klang | Beschreibung |
|---|---|
| `carol` | Spieluhr-Walzer (3/4, C-Dur, 16 Takte, ca. 30 s): Melodie mit Arpeggio-Begleitung – am Karussell |
| `polka` | Akkordeon-Polka (2/4, F-Dur): zwei leicht verstimmte Zungen, Umpa-Bass – auf der Bühne |
| `laterne` | Flötenlied mit weichen Akkordflächen und Atemgeräusch – zieht mit dem Laternenumzug |
| `crowd_aah`, `applause` | Staunen und Applaus beim Lichterfest |
| `sparkle` | aufsteigendes Glockenspiel, wenn die Lichter angehen |
| `clink` | Becher stoßen an (Glühwein-, Mostbude) |
| `sleigh_bells` | Schellen, wenn ein Sonderzug einfährt |

Dazu kommen das Gemurmel über dem Platz und das Knistern am Feuer.

## Aufbau im Gelände

- **Suche nach freien Plätzen:** Die Festbauten stehen nie auf Häusern, Wegen, Gleisen, Fußwegen der Bewohner oder im See. Jede Stelle wird geprüft: Grundflächen aller Dorfobjekte, Wegbreiten, Abstand zu Gleisen, Verbindungen des Fußwegenetzes und Hangneigung. Für schmale Linien wie Zaun und Hecke reicht ein kleiner Abstand.
- **Reihenfolge:**
  1. Der Eingangsbogen zeigt zur nächsten Straße.
  2. Die Buden bilden eine Gasse auf der Gegenseite, mit der Front zur Gasse.
  3. Baum bzw. Lagerfeuer stehen dahinter als Blickfang, Karussell bzw. Bühne seitlich.
  4. Stehtische und Feuerkorb kommen auf den Platz; der Eingang bleibt frei.
- **Kein freier Platz:** Findet sich keiner, fällt das Stück weg, statt irgendwo hineinzuragen.
- **Wilde Bäume:** Unter den Festbauten und in der Gasse wird gerodet. Nach dem Fest wachsen die Bäume wieder.
- **Auf- und Abbau:** Der Aufbau wächst sanft aus dem Boden. Mit dem Ende des Festzeitraums verschwindet alles, und die Sonderzüge verlassen den Fahrplan.

## Leistung

- Die feste Deko eines Fests ist **ein** Mesh plus **ein** Lichter-Mesh. Jede Bude besteht aus Körper, Lichterkette und Laden.
- Alle Birnen teilen sich einen Shader (Funkeln über den Alpha-Zufallswert, Lichterwelle über `reveal_height`).
- **Echte Lichter:** eines je Bude (nur bei Dunkelheit und geöffnet), Baum und Stern, Karussell, Feuer sowie die Laternen im Umzug; alle ohne Schatten und in der Ferne ausgeblendet.
- Die Musik entsteht einmal im Hintergrund-Thread und wird zwischengespeichert.
- Die Verkäufer werfen keine eigenen Schatten (sie stehen im Schatten der Bude). Figuren werden ab 80 m nicht mehr gezeichnet (vorher 120 m); sie sind dort nur noch Punkte.
- **Messung** auf dem Testrechner (Intel HD 520, Kompatibilitäts-Renderer), Winter 15 Uhr, Markt geöffnet, Gäste unterwegs:

  | Ansicht | Etappe 9.5 | Etappe 10 (Markt offen) |
  |---|---|---|
  | Übersicht | 7,8 fps | 8,0 fps |
  | Nah am Bahnhof | 8,4 fps | 8,3 fps |
  | Güterbahnhof | 7,3 fps | 7,8 fps |
  | Marktansicht | – | 7,5 fps, 1440 Draw Calls |

  Die ersten Messungen lagen bei 6,3–6,4 fps. Grund waren die Schatten und die Sichtweite der vielen Figuren; beides ist behoben (siehe oben). Die Werte schwanken auf diesem Rechner stark.

## Gefundene und behobene Fehler

| # | Fehler | Ursache | Behebung |
|---|---|---|---|
| 1 | Karussell stand im Haus der Kellners, eine Bude im Garten der Bergers | Fand die Platzsuche nichts, stellte sie das Stück „irgendwo in Wunschrichtung“ ab | Kein freier Platz → das Stück entfällt. Budengasse nördlich des Platzes, Buden vor Baum und Karussell geplant |
| 2 | Wilder Baum mitten in der Budengasse | Rodung nur unter den einzelnen Bauten | Die ganze Gasse wird gerodet (`FestivalDirector.clears()`), nach dem Fest wächst alles nach |
| 3 | Beim Lichterfest standen die Leute hinter den Buden | Versammlungsring rund um den Baum | Stehplätze in Halbkreisen vor dem Baum, nie in Buden, Karussell oder Häusern |
| 4 | Zum Lichterfest kam fast niemand | Die Bewohner waren zu der Zeit unterwegs oder am Bahnhof | Gäste aus der Umgebung kommen zu Fuß, Spaziergänger und Bahnhofsbesucher schließen sich an |
| 5 | Alle Tests stürzten beim Beenden ab (Exit 139) | Die Festmusik wurde noch im Hintergrund-Thread berechnet | Beim Beenden wird auf den Thread gewartet, statische Zwischenspeicher werden geleert |
| 6 | Aus normalen Zügen stieg niemand mehr aus | Festgäste zählten zur Obergrenze für Reisende | Gäste werden getrennt gezählt (`regular_traveller_count()`) |
| 7 | Sonderzüge blieben nach einem Szenenwechsel im Fahrplan | Der Fahrplan ist eine geteilte Ressource | Beim Verlassen werden sie ausgetragen |
| 8 | Sprechblasen verdeckt von Pfosten und Ästen | Tiefentest | Blase und Text liegen immer obenauf |
| 9 | Bühne stand verkehrt herum | Drehung um 180° zu viel | Vorderseite zum Platz |
| 10 | Kein Reigen, wenn beim ersten Versuch zu wenige da waren; ein Nachzügler hielt den Tanz auf | Die Stunde galt als erledigt; die Wartezeit lief über die echte Uhr | Neuer Versuch in derselben Stunde; nach 12 s Spielzeit beginnt der Tanz ohne Nachzügler |
| 11 | Kein Laternenumzug nach dem Lichterfest am selben Tag (Jahreszeit mit J gewechselt) | Ein gemeinsamer „heute schon gefeiert“-Tag für beide Feste | Jedes Fest hat seinen eigenen Höhepunkt |
| 12 | Die Dorfchronik ging beim Speichern verloren | Gespeichert wurde eine Referenz auf die Liste, keine Kopie | Beim Speichern wird kopiert |
| 13 | Selten (2 von 12 Testläufen) kam eine neue Familie nicht zu Hause an | Steht jemand im Weg und ist der Boden seitlich zu uneben zum Ausweichen, wartete ein Bewohner endlos. Das Festgedränge machte das wahrscheinlicher | Nach 5 s Warten schlüpft man vorsichtig vorbei |
| 14 | Bildrate fiel von ~7,8 auf 6,4 fps | Viele Figuren mit jeweils ~25 Teilen, alle mit Schatten, sichtbar bis 120 m | Verkäufer ohne Schatten, Figuren nur bis 80 m |
| 15 | Schneepflug breiter als das Lichtraumprofil | Pflugflügel zu weit | Flügel und Räumschilde schmaler |

## Neue Dateien

| Datei | Zweck |
|---|---|
| `scripts/festival/festival_director.gd` | Regie der Feste (Kalender, Aufbau, Besucher, Höhepunkte, Sonderzüge, Chronik) |
| `scripts/festival/market_stall.gd` | Marktbude |
| `scripts/festival/festival_tree.gd` | Weihnachtsbaum mit Lichterwelle |
| `scripts/festival/festival_carousel.gd` | Kinderkarussell |
| `scripts/festival/festival_fire.gd` | Lagerfeuer / Feuerkorb |
| `scripts/festival/train_events.gd` | Verspätungen, Schneeräumzug, vergessener Koffer |
| `scripts/festival/lost_luggage.gd` | der vergessene Koffer |
| `scripts/procgen/festival_meshes.gd` | alle Festmodelle |
| `scripts/audio/festival_sounds.gd` | Festmusik und -klänge |
| `scripts/npc/npc_dialogue.gd` | Gesprächssätze |
| `scripts/player/player_interaction.gd` | Taste E |
| `scripts/ui/speech_bubble.gd`, `assets/materials/speech_bubble.gdshader` | Sprechblasen |
| `scripts/ui/event_overlay.gd` | Fest-Banner und Interaktionshinweis |
| `assets/materials/festival_lights.gdshader` | Festbeleuchtung |
| `assets/ui/bubbles/*.svg` | 15 selbst gezeichnete Bildblasen-Symbole |
| `assets/ui/icons/tab_festivals.svg` | Notizbuch-Reiter |
| `assets/trains/special_winter.tres`, `special_autumn.tres`, `snowplough.tres` | Sonderzüge und Schneeräumzug |
| `tests/festival_test.*` | automatischer Test Etappe 10 |

**Erweitert (nichts neu geschrieben):**

- **Figuren und Spielfigur:**
  - `Npc`: Fest, Gespräche, Sprechblasen, Tanz, Umzug, Versammlung.
  - `NpcDirector`: Bildblasen beim Plaudern, Verspätungen beim Warten.
  - `CharacterModel`: Becher und Laterne; beim Wechsel wird nur das Getragene neu gebaut.
  - `PlayerController`: Interaktion, `get_model()`, `get_facing()`.
- **Züge:**
  - `TrainDispatcher`: Sonderzeilen, Verspätungen.
  - `TrainCar`: Lichterketten, Rundumleuchten, Schneefontäne.
  - `TrainMeshes`: Schneeräumlok.
  - `TrainType`: `festive_lights`.
- **Oberfläche und System:** `Notebook` (Seite Feste), `HUD`, `Events` (drei Signale), `InputConfig` (Taste E), `Economy` (Buchungsart Finderlohn), `WalkGraph.distance_to_links()`.
