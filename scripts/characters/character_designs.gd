## Die freigegebenen Figuren aus den Charakterblättern des Creative Directors
## (docs/character_references/). Jede Figur im Spiel stammt von hier: Spielerinnen und
## Spieler, die Dorfbewohner, Reisende, Festgäste, Händler und Arbeiter.
class_name CharacterDesigns
extends RefCounted

const PLAYER_MALE := preload("res://assets/characters/designs/player_male.tres")
const PLAYER_FEMALE := preload("res://assets/characters/designs/player_female.tres")

## Alle NPC-Figuren (ohne die beiden Spielfiguren).
const NPC: Array[CharacterAppearance] = [
	preload("res://assets/characters/designs/gardener.tres"),
	preload("res://assets/characters/designs/grandpa_cardigan.tres"),
	preload("res://assets/characters/designs/newsboy.tres"),
	preload("res://assets/characters/designs/bow_girl.tres"),
	preload("res://assets/characters/designs/smith.tres"),
	preload("res://assets/characters/designs/baker.tres"),
	preload("res://assets/characters/designs/sailor.tres"),
	preload("res://assets/characters/designs/granny_gingham.tres"),
	preload("res://assets/characters/designs/satchel_boy.tres"),
	preload("res://assets/characters/designs/scout.tres"),
	preload("res://assets/characters/designs/winter_girl.tres"),
	preload("res://assets/characters/designs/grandpa_fairisle.tres"),
	preload("res://assets/characters/designs/earmuff_boy.tres"),
	preload("res://assets/characters/designs/duffle_girl.tres"),
	preload("res://assets/characters/designs/lumberjack.tres"),
	preload("res://assets/characters/designs/beret_girl.tres"),
	preload("res://assets/characters/designs/elf_girl.tres"),
	preload("res://assets/characters/designs/granny_diamond.tres"),
	preload("res://assets/characters/designs/sailor_satchel.tres"),
	preload("res://assets/characters/designs/trapper.tres"),
]

## Figuren, die als Kinder auftreten können (Festbesuch mit den Eltern).
const CHILDREN: Array[CharacterAppearance] = [
	preload("res://assets/characters/designs/newsboy.tres"),
	preload("res://assets/characters/designs/bow_girl.tres"),
	preload("res://assets/characters/designs/satchel_boy.tres"),
	preload("res://assets/characters/designs/scout.tres"),
	preload("res://assets/characters/designs/winter_girl.tres"),
	preload("res://assets/characters/designs/earmuff_boy.tres"),
	preload("res://assets/characters/designs/duffle_girl.tres"),
	preload("res://assets/characters/designs/elf_girl.tres"),
]


## Zufällige NPC-Figur als eigene Kopie (Aufrufer dürfen sie verändern).
static func random(rng: RandomNumberGenerator) -> CharacterAppearance:
	return NPC[rng.randi() % NPC.size()].duplicate() as CharacterAppearance


## Zufällige Kinderfigur, etwas kleiner als die Erwachsenen.
static func random_child(rng: RandomNumberGenerator) -> CharacterAppearance:
	var look := CHILDREN[rng.randi() % CHILDREN.size()].duplicate() as CharacterAppearance
	look.height_scale = rng.randf_range(0.78, 0.84)
	return look


## Figur nach Dateiname (z. B. "baker"), null wenn es sie nicht gibt.
static func by_name(design: String) -> CharacterAppearance:
	var path := "res://assets/characters/designs/%s.tres" % design
	return load(path) as CharacterAppearance if ResourceLoader.exists(path) else null
