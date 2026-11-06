class_name ContinuousEffectsEndedEvent
extends MmEvent
## Every continuous effect with [member duration] ends, such as "until end of turn"
## effects in the cleanup step (CR 514.2). Replacement and prevention effects are continuous
## effects too (CR 611.1), so "this turn" shields end with them (A138).

var duration: CreateContinuousEffect.Duration
## How many ended, set when the event is applied.
var count: int = 0


func _init(ending: CreateContinuousEffect.Duration) -> void:
	duration = ending


func apply(state: MmGameState) -> void:
	count = state.end_continuous_effects(duration) + state.end_replacement_effects(duration)


func describe() -> String:
	return "CONTINUOUS EFFECTS ENDED: %d %s" % [count, CreateContinuousEffect.Duration.find_key(duration)]
