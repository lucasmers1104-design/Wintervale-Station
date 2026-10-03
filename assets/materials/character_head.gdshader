// Figuren-Shader für den Kopf: wie character.gdshader, zusätzlich mit dem
// Instanzparameter eye_open fürs Blinzeln (je Figur).
shader_type spatial;
render_mode diffuse_lambert_wrap;

#define CHARACTER_BLINK
#include "res://assets/materials/character.gdshaderinc"
