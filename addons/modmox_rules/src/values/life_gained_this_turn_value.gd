class_name LifeGainedThisTurnValue
extends MmValue
## "The amount of life [players] have gained this turn", as Voracious Wurm's "This creature
## enters with X +1/+1 counters on it, where X is the amount of life you've gained this
## turn." (engine ADR 0082's fourth addendum): added up over every player selected, from the
## count each keeps (MmPlayer.life_gained_this_turn), which holds every life gain of the
## turn, from an effect or from lifelink damage (CR 119.3, 120.3f), and which a new turn
## clears.

@export var players: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var total: int = 0
	for found: MmReference in players.select(state, context):
		if found.is_player():
			total += state.player(found.id).life_gained_this_turn
	return total
