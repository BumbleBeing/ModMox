class_name AttackersDeclaredTrigger
extends MmTrigger
## "Whenever one or more [filter] [whose] control attack" (CR 508.1, 603.2c): triggers once
## as attackers are declared, however many of them match, and never when none do. With
## IsSourceFilter it is "Whenever this creature attacks" (CR 508.3a): it triggers as this
## creature is declared as an attacker, not as it becomes tapped, so with vigilance too, and
## never for a creature put onto the battlefield attacking (CR 508.4), which is attacking but
## never attacked. "That player" is the attacking player. With [member alone] it is
## "Whenever a [filter] [whose] control attacks alone", as exalted says (CR 702.83a).

## Which attackers count. Null matches any creature.
@export var filter: MmFilter = null
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU
## "Attacks alone": it triggers only when exactly one creature is declared as an attacker
## (CR 506.5), and that creature, matching, is "that creature". One put onto the battlefield
## attacking afterwards was never declared, so it changes nothing (CR 508.4).
@export var alone: bool = false


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var declared: AttackersDeclaredEvent = event as AttackersDeclaredEvent
	if declared == null or not is_whose(whose, declared.attacking_player_id, context):
		return false
	if alone and declared.attacker_ids.size() != 1:
		return false
	for attacker_id: int in declared.attacker_ids:
		if filter == null or filter.matches(state, MmReference.to_object(attacker_id), context):
			return true
	return false


func triggering_player_id(_state: MmGameState, event: MmEvent) -> int:
	return (event as AttackersDeclaredEvent).attacking_player_id


## "That creature" for one attacking alone; none otherwise, since several may attack.
func triggering_object_id(event: MmEvent) -> int:
	var declared: AttackersDeclaredEvent = event as AttackersDeclaredEvent
	if alone and declared != null and declared.attacker_ids.size() == 1:
		return declared.attacker_ids[0]
	return 0
