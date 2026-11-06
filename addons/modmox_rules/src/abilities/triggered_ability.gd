class_name TriggeredAbility
extends MmAbility
## "When/Whenever/At [trigger], [if condition,] [effect]" (CR 603). Whether it targets is
## worked out from its targets and effects, never set by hand (ADR 0002, 0014).
##
## Later: optional ("you may") triggers, and "you may pay" costs during resolution (CR 603.5).

@export var trigger: MmTrigger
## An intervening "if" clause (CR 603.4), or null. Checked when it triggers and again on
## resolution.
@export var condition: MmCondition = null
@export var targets: Array[TargetSpec] = []
@export var effects: Array[MmEffect] = []


## Whether the intervening "if" clause, if any, holds right now.
func condition_holds(state: MmGameState, context: MmEffectContext) -> bool:
	return condition == null or condition.is_true(state, context)


func describe() -> String:
	return "triggered ability (%d targets, %d effects)" % [targets.size(), effects.size()]
