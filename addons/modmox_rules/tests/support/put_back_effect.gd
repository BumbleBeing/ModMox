extends MmEffect
## A test-only effect: its controller puts the first card of their hand on the bottom of
## their library without revealing it, as Brainstorm puts cards back. Lets a test move a card
## from a hand to the library unseen before any card in Content does (ADR 0057).


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var hand: MmZone = state.player(context.controller_id).hand
	if step > 0 or hand.is_empty():
		return []
	var library: MmZone = state.player(context.controller_id).library
	var card: MmGameObject = hand.objects().front()
	return [ZoneChangeEvent.new(card, library, MmZone.BOTTOM, ZoneChangeEvent.Reason.PUT_ON_BOTTOM)]
