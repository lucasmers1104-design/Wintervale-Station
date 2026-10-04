# Bildquellen und leere GUI-Rahmen

Die sechs vom Nutzer bereitgestellten PNG-Vorlagen liegen unverändert in `references/`. Godot verwendet AtlasTexture-Ausschnitte für die Illustrationen; Zahlen, Texte, Tabs, Auswahlfelder und Aktionen sind native dynamische Controls. Die Ausschnitte stehen in `scripts/ui/journey_art.gd`.

Drei leere Rahmen wurden mit dem eingebauten Tool `image_gen.imagegen` erstellt, jeweils mit transparentem Hintergrund. Keine externen Bilddienste. Die Originalausgaben wurden in dieses Verzeichnis kopiert:

- `board.png`: großer Holz-/Pergamentrahmen, basierend auf epochs.png und tutorial.png.
- `card.png`: innere Pergamentkarte, basierend auf epochs.png. Godot lädt sie für die Neun-Feld-Darstellung mit einer kleineren Pixeldichte; die Quelldatei bleibt unverändert.
- `sign.png`: kleines Holzschild, basierend auf launcher.png.

## Verwendete Prompts

### board.png

Use case: precise-object-edit. Asset type: a reusable background texture for the real Godot game UI, not a screenshot. Edit the provided first reference (wide Eisenbahnreise menu): remove ALL text, icons, tabs, close button, timeline, progress bars, cards, inner panels and trains from inside the OUTER wood frame, leaving one uninterrupted warm ivory honey parchment sheet. Preserve the original outer dark carved wood frame, brass corner bolts, tiny gold diamond ornaments, snow caps, torn-paper edges and richly textured painterly cozy winter game look. The parchment interior must be clean and uniform, very subtle paper grain; faint sepia alpine landscape ONLY along the bottom 12%, restrained corner filigree. Same wide 16:9 rectangular proportions, front-facing perfectly planar, frame fills image edges with small transparent outside margin. Outside the entire wooden panel is genuinely transparent, no world backdrop. No text or numbers anywhere. Reference image 2 is supporting texture/style only. Output one isolated blank menu panel texture with transparency, suitable for overlaying real dynamic controls. Keep frame narrow: outer frame thickness about 30px at 1600px image width, corner snow never takes up more than 55px.

### card.png

Use case: precise-object-edit. Create ONE isolated blank reusable inner parchment card for a Godot game UI, using the supplied menu reference as exact style reference. Reproduce the INNER left card which contains Ein Dorf entsteht: pale honey parchment, delicate carved gold/beige double outline, 4 rounded polished brass rivets at the corners, sepia baroque botanical flourish near upper corners. Remove ALL text, trains, scenes, icons, buttons, ribbons and numbers; interior is clean lightly textured parchment. No outer dark wooden frame, no snow, no background. Front-facing flat rectangle, thin rim about 18px at a width of 1200px. Card aspect ratio 16:9. Genuine transparent outside margin, panel fills canvas, no drop shadow far outside. One blank panel only.

### sign.png

Use case: precise-object-edit. Create ONE isolated blank reusable small GUI launcher sign for a Godot game UI using the supplied first image as exact style reference: ONLY the big left Reise Epoche wood sign. Keep carved dark wood, gold brass ornamental outline, gold central diamond at top, two brass side rivets, snow caps at upper left and upper right, warm pale parchment inside. Remove ALL icons, ALL text, ALL progress dots. No second sign, no help button, no background. Flat front-facing rectangle, wide horizontal sign approximately 4:1 aspect ratio, very thin wood frame about 14px at 800px width with intact chamfered corners. Genuine transparent outside. One isolated blank sign.
