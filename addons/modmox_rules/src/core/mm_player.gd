class_name MmPlayer
extends RefCounted
## A player in an encounter, with a life total and their own library, hand and graveyard.
## Rules code identifies players only by ID and relationship, never as Hero or Villain.

var id: int
var life: int
var opening_hand_size: int
var free_mulligans: int
var mulligans_taken: int = 0
var library: MmZone
var hand: MmZone
var graveyard: MmZone


func _init(player_id: int, setup: MmPlayerSetup) -> void:
	id = player_id
	life = setup.starting_life
	opening_hand_size = setup.opening_hand_size
	free_mulligans = setup.free_mulligans
	library = MmZone.new(MmZone.Kind.LIBRARY, player_id)
	hand = MmZone.new(MmZone.Kind.HAND, player_id)
	graveyard = MmZone.new(MmZone.Kind.GRAVEYARD, player_id)


## Event-only: counts one more mulligan taken.
func record_mulligan() -> void:
	mulligans_taken += 1
