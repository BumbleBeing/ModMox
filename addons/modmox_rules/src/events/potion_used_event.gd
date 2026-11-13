class_name PotionUsedEvent
extends MmEvent
## A Potion is used up as a cost and stops existing (ADR 0036). The game reads these to
## learn which Potions to delete after the encounter.

var object_id: int
## Who used it, and its place in that player's list of Potions in the Encounter Setup. Set
## when the event is applied.
var player_id: int = MmGameState.NO_PLAYER
var potion_index: int = MmGameObject.NOT_A_POTION


func _init(potion_object_id: int) -> void:
	object_id = potion_object_id


## Records whose Potion it was and which, then removes it from the game.
func apply(state: MmGameState) -> void:
	var potion: MmGameObject = state.object(object_id)
	player_id = potion.owner_id
	potion_index = potion.potion_index
	state.command.remove(potion)
	state.retire_object(potion)


## For logs and debugging.
func describe() -> String:
	return "POTION USED: object %d (potion %d of player %d)" % [object_id, potion_index, player_id]
