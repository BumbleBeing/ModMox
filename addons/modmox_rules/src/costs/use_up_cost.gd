class_name UseUpCost
extends MmCost
## "Use up this Potion": the ability's source is removed from the game (ADR 0036). Payable
## only by a Potion in the command zone.


## Only a Potion still in the command zone can be used up.
func can_pay(state: MmGameState, source: MmGameObject) -> bool:
	return source.is_potion() and source.zone() == state.command


## Removes the Potion from the game.
func pay(state: MmGameState, source: MmGameObject) -> void:
	state.perform(PotionUsedEvent.new(source.id))
