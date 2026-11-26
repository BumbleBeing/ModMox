class_name CardsInZoneValue
extends MmValue
## "The number of cards in [whose] [zone]", such as threshold's "seven or more cards in your
## graveyard" (engine ADR 0080): the cards in that zone of each player [member whose] names,
## relative to the controller, as they are now. With a [member filter] it is "the number of
## [filter] cards in [whose] [zone]", as Chitin Gravestalker's "for each artifact and/or
## creature card in your graveyard" (engine ADR 0080's second addendum): only the cards that
## match count, each once, so an artifact creature card is one card.

@export var zone: MmZone.Kind = MmZone.Kind.GRAVEYARD
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU
@export var filter: MmFilter = null


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var count: int = 0
	for player: MmPlayer in state.players:
		if not MmTrigger.is_whose(whose, player.id, context):
			continue
		if filter == null:
			count += state.zone(zone, player.id).size()
			continue
		for card: MmGameObject in state.zone(zone, player.id).objects():
			if filter.matches(state, MmReference.to_object(card.id), context):
				count += 1
	return count
