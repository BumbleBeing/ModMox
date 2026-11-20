class_name AttackersDeclaredTrigger
extends MmTrigger
## "Whenever one or more [filter] [whose] control attack" (CR 508.1, 603.2c): triggers once
## as attackers are declared, however many of them match, and never when none do. With
## IsSourceFilter it is "Whenever this creature attacks" (CR 508.3a): it triggers as this
## creature is declared as an attacker, not as it becomes tapped, so with vigilance too, and
## never for a creature put onto the battlefield attacking (CR 508.4), which is attacking but
## never attacked. "That player" is the attacking player.

## Which attackers count. Null matches any creature.
@export var filter: MmFilter = null
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var declared: AttackersDeclaredEvent = event as AttackersDeclaredEvent
	if declared == null or not is_whose(whose, declared.attacking_player_id, context):
		return false
	for attacker_id: int in declared.attacker_ids:
		if filter == null or filter.matches(state, MmReference.to_object(attacker_id), context):
			return true
	return false


func triggering_player_id(_state: MmGameState, event: MmEvent) -> int:
	return (event as AttackersDeclaredEvent).attacking_player_id
