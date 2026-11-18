class_name LifeAtLeastStartingCondition
extends MmCondition
## "Your life total is greater than or equal to your starting life total": true while the
## controller has at least the life they began the encounter with (CR 103.4).


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	var you: MmPlayer = state.player(context.controller_id)
	return you != null and you.life >= you.starting_life
