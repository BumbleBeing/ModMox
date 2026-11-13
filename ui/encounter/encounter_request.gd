class_name EncounterRequest
extends RefCounted
## What encounter to play: both decks, the Encounter Seed and how hard the Villain plays.
## Filled in on the start form or from the command line (A246) until runs exist, when the
## game around the encounter will hand it over instead.

const DECKS: String = "res://content/decks/"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

var hero_deck: String = "red_green"
var villain_deck: String = "white_black"
var encounter_seed: int = 1
var difficulty: String = "easy"
## What each player is called; "" for a player who goes by their part.
var hero_name: String = ""
var villain_name: String = ""
## Gives each player one sample Emblem, so the Emblems windows have something to show.
var has_sample_emblems: bool = false


## The request in [param arguments], as passed after "--" on the command line, such as
## --hero=red_green --villain=white_black --seed=7 --difficulty=normal --emblems
## --hero-name=Jackson --villain-name=Mishra. Null when
## they name no deck and no seed, which means "show the start form".
static func from_arguments(arguments: PackedStringArray) -> EncounterRequest:
	var request: EncounterRequest = EncounterRequest.new()
	var is_asked_for: bool = false
	for argument: String in arguments:
		if argument.begins_with("--hero="):
			request.hero_deck = argument.trim_prefix("--hero=")
			is_asked_for = true
		elif argument.begins_with("--villain="):
			request.villain_deck = argument.trim_prefix("--villain=")
			is_asked_for = true
		elif argument.begins_with("--seed="):
			request.encounter_seed = int(argument.trim_prefix("--seed="))
			is_asked_for = true
		elif argument.begins_with("--difficulty="):
			request.difficulty = argument.trim_prefix("--difficulty=")
		elif argument.begins_with("--hero-name="):
			request.hero_name = argument.trim_prefix("--hero-name=")
		elif argument.begins_with("--villain-name="):
			request.villain_name = argument.trim_prefix("--villain-name=")
		elif argument == "--emblems":
			request.has_sample_emblems = true
	return request if is_asked_for else null


## The names of the decks in content/decks/, in order.
static func deck_names() -> Array[String]:
	var names: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(DECKS)
	files.sort()
	for file: String in files:
		# An exported game lists a resource as "name.tres.remap".
		var deck: String = file.trim_suffix(".remap")
		if deck.ends_with(".tres"):
			names.append(deck.trim_suffix(".tres"))
	return names


## Why this request cannot be played, or "" if it can.
func validate() -> String:
	for deck: String in [hero_deck, villain_deck]:
		if not ResourceLoader.exists(DECKS + deck + ".tres"):
			return "There is no deck named \"%s\"." % deck
	if not DIFFICULTIES.has(difficulty):
		return "There is no difficulty named \"%s\"." % difficulty
	return ""


## The Encounter Setup this request describes. Loaded decks are never changed: sample
## Emblems go on copies.
func setup() -> MmEncounterSetup:
	var encounter: MmEncounterSetup = MmEncounterSetup.new()
	encounter.hero = load(DECKS + hero_deck + ".tres") as MmPlayerSetup
	encounter.villain = load(DECKS + villain_deck + ".tres") as MmPlayerSetup
	encounter.encounter_seed = encounter_seed
	if has_sample_emblems:
		encounter.hero = encounter.hero.duplicate() as MmPlayerSetup
		encounter.hero.emblems = [_sample_emblem("Sample Boon: Howling Winds", "howling_mine")] as Array[MmCardDefinition]
		encounter.villain = encounter.villain.duplicate() as MmPlayerSetup
		encounter.villain.emblems = [_sample_emblem("Sample Hex: Ankh's Curse", "ankh_of_mishra")] as Array[MmCardDefinition]
	return encounter


## What each player is called on the screen.
func names() -> PlayerNames:
	return PlayerNames.new(hero_name, villain_name)


## The Agent that plays the Villain, at this request's difficulty.
func villain_agent() -> MmAgent:
	var level: AiDifficulty = load("res://content/ai/difficulty_%s.tres" % difficulty) as AiDifficulty
	return AiAgent.new(null, AiAgent.Mode.FULL, level)


## An Emblem with the abilities of a card in Content, and nothing else (ADR 0011).
static func _sample_emblem(emblem_name: String, card: String) -> MmCardDefinition:
	var source: MmCardDefinition = load("res://content/cards/alpha/%s.tres" % card) as MmCardDefinition
	var emblem: MmCardDefinition = MmCardDefinition.new()
	emblem.name = emblem_name
	emblem.abilities = source.abilities.duplicate()
	return emblem
