class_name StepBeganTrigger
extends MmTrigger
## "At the beginning of [whose] [step]" (CR 603.2, 503.1). "That player" is the active
## player.

@export var step: MmTurn.Step = MmTurn.Step.UPKEEP
@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var started: StepStartedEvent = event as StepStartedEvent
	return started != null and started.step == step and is_whose(whose, state.active_player_id, context)


func triggering_player_id(state: MmGameState, _event: MmEvent) -> int:
	return state.active_player_id
