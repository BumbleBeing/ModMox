class_name MmEffect
extends Resource
## One thing a spell or ability does, such as dealing damage. Subclasses describe one kind
## each, and refer to who or what they affect only through Selections (ADR 0014).


## The numbers this effect works out once, as it begins (CR 608.2h), such as how many cards
## to draw. Each later step gets them again, so they cannot change part-way through.
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	var none: Array[int] = []
	return none


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
