class_name IsPlayerFilter
extends MmFilter
## Matches a player: any player, or with [member whose] "you" or "an opponent", relative to
## the controller of the spell or ability, as Mardu Skullhunter's "target opponent" says.

## Whose: ANY for "player", OPPONENT for "opponent".
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(_state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	return candidate.is_player() and MmTrigger.is_whose(whose, candidate.id, context)
