class_name LifeGainedTrigger
extends MmTrigger
## "Whenever [whose] gain(s) life" (CR 119.9, 603.2, ADR 0082), as Unflinching Hortimancer's
## "Whenever you gain life, put a +1/+1 counter on this creature." It reads "whenever a source
## causes [whose] to gain life" (CR 119.9): a LifeGainedEvent is one life gain, and so is the
## damage of each source with lifelink, which gains its controller life as part of the damage
## (CR 120.3f), so two lifelink creatures dealing combat damage at once trigger it twice. One
## lifelink source damaging several recipients at once is one life gain, so its damage in one
## batch is one occasion (occasion_of()). Gaining no life is no life gain (CR 119.9). "That
## player" is the player who gains the life.

## Compared with the player who gains the life.
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var gainer_id: int = triggering_player_id(state, event)
	return gainer_id != MmGameState.NO_PLAYER and is_whose(whose, gainer_id, context)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var gained: LifeGainedEvent = event as LifeGainedEvent
	if gained != null:
		return gained.player_id if gained.amount > 0 else MmGameState.NO_PLAYER
	var damage: DamageEvent = event as DamageEvent
	if damage == null or not damage.is_lifelink or damage.amount <= 0:
		return MmGameState.NO_PLAYER
	# CR 120.3f: the source's controller gains it, as DamageEvent applied it.
	var source: MmGameObject = state.object_or_last_known(damage.source_object_id)
	return MmGameState.NO_PLAYER if source == null else source.controller_id


## CR 119.9: a lifelink source's damage to several recipients at once is one life gain.
func occasion_of(_state: MmGameState, event: MmEvent) -> String:
	var damage: DamageEvent = event as DamageEvent
	return "" if damage == null else "lifelink of object %d" % damage.source_object_id
