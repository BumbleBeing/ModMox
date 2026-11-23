class_name CardsInZoneValue
extends MmValue
## "The number of cards in [whose] [zone]", such as threshold's "seven or more cards in your
## graveyard" (engine ADR 0080): the cards in that zone of each player [member whose] names,
## relative to the controller, as they are now.

@export var zone: MmZone.Kind = MmZone.Kind.GRAVEYARD
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var count: int = 0
	for player: MmPlayer in state.players:
		if MmTrigger.is_whose(whose, player.id, context):
			count += state.zone(zone, player.id).size()
	return count
