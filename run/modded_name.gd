class_name ModdedName
extends RefCounted
## What a card with Mods or Hexes is called (ADR 0029): the names of the Mods and Hexes on it
## in alphabetical order, in front of the card's own, whose capitalization never changes. A
## Mod on the card twice is named once with "Very" in front, three times with "Extremely",
## and those words play no part in the order: Ancient Very Violent Plains.

## The word in front of a Mod's name for how many times the card holds it, from twice up.
const REPEATS: Array[String] = ["", "", "Very", "Extremely"]


## [param own_name] with the names of [param mods] in front of it. A Mod with no name, as a
## test's may be, adds no word.
static func of(own_name: String, mods: Array[Mod]) -> String:
	var counts: Dictionary[String, int] = {}
	for mod: Mod in mods:
		if mod.name != "":
			counts[mod.name] = counts.get(mod.name, 0) + 1
	var mod_names: Array[String] = []
	mod_names.assign(counts.keys())
	mod_names.sort_custom(func(first: String, second: String) -> bool:
		return first.naturalnocasecmp_to(second) < 0)
	var words: PackedStringArray = []
	for mod_name: String in mod_names:
		var times: int = mini(counts[mod_name], REPEATS.size() - 1)
		if REPEATS[times] != "":
			words.append(REPEATS[times])
		words.append(mod_name)
	words.append(own_name)
	return " ".join(words)
