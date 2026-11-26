class_name LostLifeThisTurnCondition
extends MmCondition
## "If an opponent lost life this turn", as Bat Whisperer's intervening "if" says (engine ADR
## 0082's second addendum): true while a player [member whose] names, relative to the
## controller of the spell or ability that asks, has lost life this turn, from damage
## (CR 120.3a), an effect or paying life (CR 119.3, 119.4). Losing no life is no life loss.
## Read from MmPlayer.life_lost_this_turn, which a new turn clears.

## Who must have lost life: "you", "an opponent", or with ANY "a player".
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	for player: MmPlayer in state.players:
		var is_yours: bool = player.id == context.controller_id
		if (whose == MmTrigger.Whose.YOU and not is_yours) or (whose == MmTrigger.Whose.OPPONENT and is_yours):
			continue
		if player.life_lost_this_turn > 0:
			return true
	return false
