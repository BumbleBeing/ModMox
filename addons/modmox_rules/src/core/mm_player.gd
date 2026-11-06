class_name MmPlayer
extends RefCounted
## A player in an encounter, with a life total and their own library, hand and graveyard.
## Rules code identifies players only by ID and relationship, never as Hero or Villain.

var id: int
var life: int
var opening_hand_size: int
## MmPlayerSetup.NO_MAXIMUM_HAND_SIZE when there is no maximum.
var maximum_hand_size: int
var free_mulligans: int
var mulligans_taken: int = 0
## How many turns this player has begun. 0 until their first turn.
var turn_number: int = 0
var library: MmZone
var hand: MmZone
var graveyard: MmZone


func _init(player_id: int, setup: MmPlayerSetup) -> void:
	id = player_id
	life = setup.starting_life
	opening_hand_size = setup.opening_hand_size
	maximum_hand_size = setup.maximum_hand_size
	free_mulligans = setup.free_mulligans
	library = MmZone.new(MmZone.Kind.LIBRARY, player_id)
	hand = MmZone.new(MmZone.Kind.HAND, player_id)
	graveyard = MmZone.new(MmZone.Kind.GRAVEYARD, player_id)


## How many cards this player must discard to reach their maximum hand size (CR 514.1).
func cards_over_maximum_hand_size() -> int:
	if maximum_hand_size == MmPlayerSetup.NO_MAXIMUM_HAND_SIZE:
		return 0
	return maxi(0, hand.size() - maximum_hand_size)


## Event-only: counts one more mulligan taken.
func record_mulligan() -> void:
	mulligans_taken += 1


## Event-only: counts the start of one of this player's turns.
func begin_turn() -> void:
	turn_number += 1
