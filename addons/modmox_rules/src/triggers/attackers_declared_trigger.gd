class_name AttackersDeclaredTrigger
extends MmTrigger
## "Whenever one or more creatures [whose] control attack" (CR 508.1, 603.2c): triggers once
## as attackers are declared, however many attack, and never when none do. "That player"
## is the attacking player.

@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func matches(_state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var declared: AttackersDeclaredEvent = event as AttackersDeclaredEvent
	return declared != null and not declared.attacker_ids.is_empty() \
		and is_whose(whose, declared.attacking_player_id, context)


func triggering_player_id(_state: MmGameState, event: MmEvent) -> int:
	return (event as AttackersDeclaredEvent).attacking_player_id
