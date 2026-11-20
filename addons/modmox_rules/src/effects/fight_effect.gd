class_name FightEffect
extends MmEffect
## "[creature] fights [other]" (CR 701.14a): each deals damage equal to its power to the
## other, at once, as one batch. The creatures are the sources, so deathtouch and lifelink
## apply (CR 702.2b, 702.15b), and it is not combat damage. If either is no longer a
## creature on the battlefield, or is an illegal target, no damage is dealt at all
## (CR 701.14b).
# Later: a creature fighting itself (CR 701.14c), once a card can make it.

## The first creature, such as "target creature you control".
@export var creature: MmSelection
## The creature it fights, such as "target creature you don't control".
@export var other: MmSelection


## The two creatures' IDs and their powers as the effect begins (CR 608.2h), or nothing when
## either is missing.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = []
	var first: MmGameObject = _creature_of(state, creature.select(state, context))
	var second: MmGameObject = _creature_of(state, other.select(state, context))
	if first == null or second == null:
		return worked_out  # CR 701.14b
	worked_out.assign([first.id, state.characteristics_of(first).power, second.id, state.characteristics_of(second).power])
	return worked_out


func next_batch(state: MmGameState, _context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out.is_empty():
		return events
	if _creature_of(state, [MmReference.to_object(worked_out[0])]) == null \
			or _creature_of(state, [MmReference.to_object(worked_out[2])]) == null:
		return events
	# CR 120.8: 0 damage is not dealt; CR 107.1b: nor is a negative amount.
	if worked_out[1] > 0:
		events.append(DamageEvent.new(worked_out[0], MmReference.to_object(worked_out[2]), worked_out[1]))
	if worked_out[3] > 0:
		events.append(DamageEvent.new(worked_out[2], MmReference.to_object(worked_out[0]), worked_out[3]))
	return events


func selections() -> Array[MmSelection]:
	return [creature, other]


## The one creature on the battlefield [param found] holds, or null.
func _creature_of(state: MmGameState, found: Array[MmReference]) -> MmGameObject:
	if found.size() != 1 or not found[0].is_object():
		return null
	var game_object: MmGameObject = state.object(found[0].id)
	if game_object == null or game_object.zone() != state.battlefield \
			or not state.characteristics_of(game_object).has_card_type(MmCardTypes.CardType.CREATURE):
		return null
	return game_object
