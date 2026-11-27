class_name SatchelEntry
extends RefCounted
## One entry of a page of the Satchel (milestone 24): a kind of Item held, how many, its type
## line and its words, a sentence to a line. It is an Armor's, a Mod's or a Potion's, and
## only an Armor's takes a click.

var name: String = ""
var count: int = 1
var type_line: String = ""
var lines: Array[String] = []
## The Item it is, one of the three.
var armor: Armor = null
var mod: Mod = null
var potion: MmCardDefinition = null
## Whether its Armor is Worn, as it was when the entry was made.
var is_worn: bool = false


## Its name, and its count after it when more than one is held: "Big Gulp ×2".
func title() -> String:
	return name if count == 1 else "%s ×%d" % [name, count]


## Whether a click on it puts its Armor on or takes it off. A Mod is applied only in the
## deckbuilder (ADR 0029) and a Potion used only in an encounter.
func takes_clicks() -> bool:
	return armor != null
