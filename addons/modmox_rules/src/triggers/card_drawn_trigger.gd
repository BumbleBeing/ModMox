class_name CardDrawnTrigger
extends MmTrigger
## "Whenever [whose] draws a card" (CR 121.1, 603.2). With [member nth_each_turn] it is
## "Whenever you draw your second card each turn", as Faerie Vandal says: it triggers only
## for the drawer's Nth card this turn, counting every card they drew this turn
## (MmPlayer.cards_drawn_this_turn), those drawn before this ability's source was on the
## battlefield too, the draw step's card among them. Each card is drawn on its own
## (CR 121.2), so "draw two cards" can trigger it on its second. A draw from an empty library
## draws nothing (CR 121.4), so it is not counted and triggers nothing. "That player" is the
## drawer and "that card" the card drawn, in their hand.

@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU
## "Your second card each turn": with N above 0, only the drawer's Nth card this turn.
@export var nth_each_turn: int = 0


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var drawn: ZoneChangeEvent = _draw_of(event)
	if drawn == null or not is_whose(whose, drawn.to_owner_id, context):
		return false
	# The count already holds this card: it is counted as it is drawn.
	return nth_each_turn == 0 or state.player(drawn.to_owner_id).cards_drawn_this_turn == nth_each_turn


func triggering_player_id(_state: MmGameState, event: MmEvent) -> int:
	return (event as ZoneChangeEvent).to_owner_id


func triggering_object_id(event: MmEvent) -> int:
	var drawn: ZoneChangeEvent = _draw_of(event)
	return 0 if drawn == null else drawn.new_object_id


## [param event] as a card being drawn, or null.
func _draw_of(event: MmEvent) -> ZoneChangeEvent:
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	if moved == null or moved.reason != ZoneChangeEvent.Reason.DRAW:
		return null
	return moved
