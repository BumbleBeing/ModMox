class_name GainedLifeThisTurnCondition
extends MmCondition
## "If you gained life this turn", as Poisoner's Apprentice's infusion says (engine ADR
## 0082's addendum): true while the controller of the spell or ability that asks has gained
## life this turn, from an effect or from lifelink damage (CR 119.3, 120.3f). Gaining no
## life is no life gain (CR 119.9). Read from MmPlayer.life_gained_this_turn, which a new
## turn clears.


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	return state.player(context.controller_id).life_gained_this_turn > 0
