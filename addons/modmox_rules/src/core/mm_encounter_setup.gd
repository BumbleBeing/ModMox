class_name MmEncounterSetup
extends Resource
## The starting conditions of an encounter: both players' setups, who starts, and the
## Encounter Seed. Hero and Villain appear here, at the boundary, and never in rules code.

## How the starting player is determined (CR 103.1). The *_CHOOSES rules ask that player
## to play or draw; RANDOM_CHOOSER flips a coin with the Game RNG to pick who chooses;
## the *_STARTS rules force the start, for Statuses or Villain abilities (ADR 0011).
enum StartingPlayerRule { RANDOM_CHOOSER, HERO_CHOOSES, VILLAIN_CHOOSES, HERO_STARTS, VILLAIN_STARTS }

const HERO_PLAYER_ID: int = 0
const VILLAIN_PLAYER_ID: int = 1

@export var hero: MmPlayerSetup
@export var villain: MmPlayerSetup
@export var starting_player_rule: StartingPlayerRule = StartingPlayerRule.RANDOM_CHOOSER
@export var encounter_seed: int = 0


## Returns why this setup is unusable, or "" if it is valid.
func validate() -> String:
	if hero == null or villain == null:
		return "Both the Hero and the Villain need a player setup."
	var hero_error: String = hero.validate()
	if hero_error != "":
		return "Hero: " + hero_error
	var villain_error: String = villain.validate()
	if villain_error != "":
		return "Villain: " + villain_error
	return ""
