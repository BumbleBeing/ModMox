class_name CardsDrawnThisTurnValue
extends MmValue
## "The number of cards [players] have drawn this turn", as Spinehorn Minotaur's "As long as
## you've drawn two or more cards this turn" counts under a ValueAtLeastCondition (CR 121.1):
## added up over every player selected, from the count each keeps
## (MmPlayer.cards_drawn_this_turn), the draw step's card among them. A draw from an empty
## library draws nothing (CR 121.4), so it is not counted.

@export var players: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var total: int = 0
	for found: MmReference in players.select(state, context):
		if found.is_player():
			total += state.player(found.id).cards_drawn_this_turn
	return total
