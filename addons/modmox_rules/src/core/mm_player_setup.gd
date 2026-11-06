class_name MmPlayerSetup
extends Resource
## One player's part of an Encounter Setup. Every number here is final: the game has
## already applied Statuses before handing it over (ADR 0011).

## Maximum hand size meaning "no maximum hand size".
const NO_MAXIMUM_HAND_SIZE: int = -1

@export var deck: Array[MmRunCard] = []
@export var starting_life: int = 20
@export var opening_hand_size: int = 7
## Cards beyond this are discarded in cleanup (CR 514.1), or NO_MAXIMUM_HAND_SIZE.
@export var maximum_hand_size: int = 7
@export var free_mulligans: int = 0
## Emblems this player starts with, from Statuses or a Villain's rules (ADR 0011). Each is a
## Card Definition with abilities and nothing else.
@export var emblems: Array[MmCardDefinition] = []


## Returns why this setup is unusable, or "" if it is valid.
func validate() -> String:
	if opening_hand_size < 0:
		return "Opening hand size cannot be negative."
	if maximum_hand_size < 0 and maximum_hand_size != NO_MAXIMUM_HAND_SIZE:
		return "Maximum hand size must be zero or more, or NO_MAXIMUM_HAND_SIZE."
	if free_mulligans < 0:
		return "Free mulligans cannot be negative."
	for index: int in emblems.size():
		if emblems[index] == null:
			return "Emblem %d has no Card Definition." % index
	for index: int in deck.size():
		if deck[index] == null or deck[index].base == null:
			return "Deck entry %d has no Card Definition." % index
	return ""
