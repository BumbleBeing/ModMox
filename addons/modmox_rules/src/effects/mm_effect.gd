class_name MmEffect
extends Resource
## One thing a spell or ability does, such as dealing damage. Subclasses describe one kind
## each, and refer to who or what they affect only through Selections (ADR 0014).


## The numbers this effect works out once, as it begins (CR 608.2h), such as how many cards
## to draw. Each later step gets them again, so they cannot change part-way through.
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	var none: Array[int] = []
	return none


## The decision this effect asks of its own as it begins, once its Selections' choices are
## made, or null for none, such as a search's (ADR 0057). [param stack_object_id] is the
## resolving spell or ability. Its answer comes back to numbers_with_answer().
func decision_as_it_begins(_state: MmGameState, _context: MmEffectContext, _stack_object_id: int) -> MmPendingDecision:
	return null


## The numbers this effect works out as it begins, once decision_as_it_begins() has been
## answered with [param answer].
func numbers_with_answer(state: MmGameState, context: MmEffectContext, _answer: Variant) -> Array[int]:
	return numbers(state, context)


## The events this effect proposes at [param step], counting from 0, as one simultaneous
## batch worked out from the game as it is now. An empty batch means the effect is done.
## Effects never perform events themselves: resolution performs each batch, and can stop
## inside one for a replacement choice (A143).
func next_batch(_state: MmGameState, _context: MmEffectContext, _step: int, _numbers: Array[int]) -> Array[MmEvent]:
	assert(false, "%s must override next_batch()." % get_script().resource_path)
	return []


## Performs every step of this effect at once, for the few places that cannot stop for a
## decision, such as a mana ability (CR 605.3a). MmGameState asserts that none of its
## batches needs a replacement choice.
func perform_now(state: MmGameState, context: MmEffectContext) -> void:
	var worked_out: Array[int] = numbers(state, context)
	var step: int = 0
	while true:
		var batch: Array[MmEvent] = next_batch(state, context, step, worked_out)
		if batch.is_empty():
			return
		state.perform_together(batch)
		step += 1


## Whether the spell or ability remembers the cards this effect moves, for a later effect's
## "from among them" (MovedCardsSelection, engine ADR 0080), as a MillEffect does.
func remembers_moved_cards() -> bool:
	return false


## The Selections this effect uses. Subclasses with Selections override this.
func selections() -> Array[MmSelection]:
	return []


## Whether this effect uses a target (CR 115). Worked out from its Selections.
func has_targets() -> bool:
	for selection: MmSelection in selections():
		if selection != null and selection.is_targeted():
			return true
	return false


## Whether this effect could add mana (CR 605.1a). Used to classify mana abilities.
func adds_mana() -> bool:
	return false
