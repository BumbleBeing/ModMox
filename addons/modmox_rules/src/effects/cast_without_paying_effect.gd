class_name CastWithoutPayingEffect
extends MmEffect
## "Cast [selection] without paying its mana cost" (CR 118.9), as Goblin Dark-Dwellers'
## "you may cast target instant or sorcery card with mana value 3 or less from your graveyard
## without paying its mana cost", which a MayEffect wraps (engine ADR 0104). It names the
## card to cast as it happens (card_to_cast()), and ResolutionProcedure hands that cast to
## the turn: it is cast at once (CR 601.2a-i), its choices asked as any cast's, paying no
## mana and no flashback cost, and then the resolution carries on with no one receiving
## priority. A card that cannot be cast now is not. With
## [member is_exiled_instead_of_graveyard] it adds "If that spell would be put into your
## graveyard, exile it instead."
# Later: a card in another zone than a graveyard, a copy, or several cards to choose among,
# each once a card says so.

## The card to cast: the first card it finds.
@export var selection: MmSelection
## "If that spell would be put into your graveyard, exile it instead."
@export var is_exiled_instead_of_graveyard: bool = false


## The card [param context]'s controller casts now, or null when [member selection] finds
## none, or none that can be cast now (CastProcedure.can_cast_without_paying()).
func card_to_cast(state: MmGameState, context: MmEffectContext, _worked_out: Array[int]) -> MmGameObject:
	for found: MmReference in selection.select(state, context):
		if found == null or not found.is_object():
			continue
		var card: MmGameObject = state.object(found.id)
		if card != null and card.zone().kind == MmZone.Kind.GRAVEYARD \
				and CastProcedure.can_cast_without_paying(state, context.controller_id, card):
			return card
		return null
	return null


func exiles_cast_instead_of_graveyard() -> bool:
	return is_exiled_instead_of_graveyard


## Nothing of its own: the cast is begun by ResolutionProcedure.
func next_batch(_state: MmGameState, _context: MmEffectContext, _step: int, _numbers: Array[int]) -> Array[MmEvent]:
	return []


func selections() -> Array[MmSelection]:
	return [selection]
