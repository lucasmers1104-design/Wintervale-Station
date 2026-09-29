# Menü und HUD: visuelle Nacharbeit

Die drei am 29. September gelieferten Bildhinweise wurden mit Godot-Aufnahmen verglichen.

| Wunsch | Umsetzung | Prüfung |
| --- | --- | --- |
| Text bleibt im kleinen Zugschild | Schrift verkleinert und Text auf die Schildfläche begrenzt. | `menu_polish_main.png` |
| Ladescreen beim Öffnen einer Reise | Geliefertes Bild als bildschirmfüllende Ebene; der Balken zeigt nun die Schritte Laden, Weltaufbau und Wiederherstellen statt eines fest eingebrannten Werts. Die Ebene bleibt bis zum fertigen Weltwechsel sichtbar. | `menu_polish_loading.png`, Journey-Integrationstest |
| Neue Leiste für Geld, Tag, Uhrzeit | Transparenter Holzrahmen aus der gelieferten Referenz; die drei Werte kommen live aus Economy und WorldClock. Die Leiste ist auf etwa 52 % der Fensterbreite verkleinert, mittig ausgerichtet und hat einen proportionalen Abstand zum oberen Rand. | `menu_polish_hud.png`, `menu_polish_hud_1280.png` |
| Keine Animation beim Tabwechsel | Grafik, Audio, Steuerung und Gameplay erscheinen sofort. Die Ausblendung beim Verlassen der Galerie bleibt erhalten. | `menu_polish_tab.png`, Menütest |
| Keine Überlagerung neuer HUD-Elemente | Fest-Banner, Achievement-Hinweis und kurze Speichermeldungen liegen unterhalb der neuen Leiste. | HUD-Aufnahmen bei 1672 × 941 und 1280 × 720 |

Die Ladescreen-Illustration ist die unveränderte, vom Nutzer gelieferte Vorlage. Der frei gestellte HUD-Rahmen wurde aus dem zweiten Bild abgeleitet; die festen Beispielzahlen wurden entfernt und durch echte Godot-Texte ersetzt. Die Aufnahmen sind reale Godot-Screenshots; sie zeigen den aktuellen Stand, keinen behaupteten Pixelvergleich mit einem weiteren Gameplay-Referenzbild.
