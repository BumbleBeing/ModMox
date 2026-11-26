class_name AttackedThisTurnCondition
extends MmCondition
## "If you attacked this turn", as Mardu Skullhunter's raid says (engine ADR 0095's
## addendum): true while the controller of the ability that asks declared one or more
## attackers this turn (CR 508.1). A creature put onto the battlefield attacking was never
## declared, so it never attacked (CR 508.4). Read from MmPlayer.has_attacked_this_turn,
## which a new turn clears.


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	return state.player(context.controller_id).has_attacked_this_turn
