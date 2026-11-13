class_name PlayerNames
extends RefCounted
## What each player of an encounter is called, wherever the screen names one: on their
## panel, on a Zone Window's title, on a stack entry. A player who was given no name goes
## by their part, "Hero" or "Villain", and only then takes "the" in a sentence.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const PARTS: Dictionary[int, String] = {HERO: "Hero", VILLAIN: "Villain"}

var _names: Dictionary[int, String] = {}


## A name that is empty, or only spaces, is no name.
func _init(hero_name: String = "", villain_name: String = "") -> void:
	for pair: Array in [[HERO, hero_name], [VILLAIN, villain_name]]:
		var given: String = (pair[1] as String).strip_edges()
		if given != "":
			_names[pair[0] as int] = given


## Whether [param player_id] was given a name of their own.
func is_named(player_id: int) -> bool:
	return _names.has(player_id)


## The player's name, as a label: "Mishra", or "Villain".
func of(player_id: int) -> String:
	return _names.get(player_id, PARTS.get(player_id, "Player"))


## The player in a sentence: "Mishra", or "the Villain".
func the(player_id: int) -> String:
	return of(player_id) if is_named(player_id) else "the " + of(player_id)


## The player at the start of a sentence: "Mishra", or "The Villain".
func starting(player_id: int) -> String:
	var words: String = the(player_id)
	return words.left(1).to_upper() + words.substr(1)


## Whose something is, as a label: "Mishra's", "Urzas'", or "Villain's".
func possessive(player_id: int) -> String:
	return _owned_by(of(player_id))


## Whose something is, in a sentence: "Mishra's", or "the Villain's".
func the_possessive(player_id: int) -> String:
	return _owned_by(the(player_id))


static func _owned_by(owner: String) -> String:
	return owner + ("'" if owner.ends_with("s") else "'s")
