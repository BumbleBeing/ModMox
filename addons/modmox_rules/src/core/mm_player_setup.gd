class_name MmPlayerSetup
extends Resource
## One player's part of an Encounter Setup. Every number here is final: the game has
## already applied Statuses before handing it over (ADR 0011).

@export var deck: Array[MmRunCard] = []
@export var starting_life: int = 20
@export var opening_hand_size: int = 7
@export var free_mulligans: int = 0


## Returns why this setup is unusable, or "" if it is valid.
func validate() -> String:
	if opening_hand_size < 0:
		return "Opening hand size cannot be negative."
	if free_mulligans < 0:
		return "Free mulligans cannot be negative."
	for index: int in deck.size():
		if deck[index] == null or deck[index].base == null:
			return "Deck entry %d has no Card Definition." % index
	return ""
