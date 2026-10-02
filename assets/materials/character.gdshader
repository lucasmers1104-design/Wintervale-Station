// Gemeinsamer Shader aller Figuren (Spieler und Bewohner).
//
// Jede Figur besteht aus wenigen zusammengeführten Meshes (je Gelenk eines);
// Farbe und Muster jedes Teils stecken in den Vertexdaten:
//   COLOR        Grundfarbe
//   CUSTOM0      zweite Farbe (Streifen, Karo, Brauen …)
//   CUSTOM1      dritte Farbe (Karo-Linien, Muster …)
//   UV2.x        Muster (siehe PATTERN_*), UV2.y Mustermaßstab
//   UV           Musterkoordinaten des Teils (u rundherum, v in der Höhe);
//                beim Kopf: Gesichtskoordinaten (x, y der Einheitskugel)
// So kommt eine Figur mit 7–8 Zeichenaufrufen aus, egal wie viele Teile sie hat.
shader_type spatial;
render_mode diffuse_lambert_wrap;

#include "res://assets/materials/character.gdshaderinc"
