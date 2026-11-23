class_name FightEffect
extends MmEffect
## "[creature] fights [other]" (CR 701.14a): each deals damage equal to its power to the
## other, at once, as one batch. The creatures are the sources, so deathtouch and lifelink
## apply (CR 702.2b, 702.15b), and it is not combat damage. If either is no longer a
## creature on the battlefield, or is an illegal target, no damage is dealt at all
## (CR 701.14b).
##
## Overloaded, "each creature you control fights each creature you don't control"
## (CR 702.96b), every creature [member creature] finds fights every one [member other]
## finds: each deals damage equal to its power to each creature on the other side, all in
## the same batch. When either side finds none, no damage is dealt.
# Later: a creature fighting itself (CR 701.14c), once a card can make it. Until then a
# creature found on both sides does not fight itself.

## The first creature, such as "target creature you control".
@export var creature: MmSelection
## The creature it fights, such as "target creature you don't control".
@export var other: MmSelection


## Four numbers for each pair that fights, as the effect begins (CR 608.2h): the first
## creature's ID and power, then the other's. Nothing when either side is missing.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = []
	var others: Array[MmGameObject] = _creatures_of(state, other.select(state, context))
	for first: MmGameObject in _creatures_of(state, creature.select(state, context)):
		for second: MmGameObject in others:
			if first.id != second.id:
				worked_out.append_array([first.id, state.characteristics_of(first).power,
					second.id, state.characteristics_of(second).power])
	return worked_out


func next_batch(state: MmGameState, _context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for pair: int in range(0, worked_out.size(), 4):
		var found: Array[MmReference] = [MmReference.to_object(worked_out[pair]), MmReference.to_object(worked_out[pair + 2])]
		if _creatures_of(state, found).size() != 2:
			continue  # CR 701.14b
		# CR 120.8: 0 damage is not dealt; CR 107.1b: nor is a negative amount.
		if worked_out[pair + 1] > 0:
			events.append(DamageEvent.new(worked_out[pair], found[1], worked_out[pair + 1]))
		if worked_out[pair + 3] > 0:
			events.append(DamageEvent.new(worked_out[pair + 2], found[0], worked_out[pair + 3]))
	return events


func selections() -> Array[MmSelection]:
	return [creature, other]


## The creatures on the battlefield among [param found], in its order.
func _creatures_of(state: MmGameState, found: Array[MmReference]) -> Array[MmGameObject]:
	var creatures: Array[MmGameObject] = []
	for reference: MmReference in found:
		var game_object: MmGameObject = state.object(reference.id) if reference.is_object() else null
		if game_object != null and game_object.zone() == state.battlefield \
				and state.characteristics_of(game_object).has_card_type(MmCardTypes.CardType.CREATURE):
			creatures.append(game_object)
	return creatures
