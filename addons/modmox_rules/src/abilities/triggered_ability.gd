class_name TriggeredAbility
extends MmAbility
## "When/Whenever/At [trigger], [if condition,] [effect]" (CR 603). Whether it targets is
## worked out from its targets and effects, never set by hand (ADR 0002, 0014). A modal one
## ("[trigger], choose one —", CR 700.2) has [member modes] instead, and its own targets and
## effects are empty: what it does is the mode chosen as it is put on the stack (CR 603.3c,
## ADR 0046).
##
## An optional ("you may") one has a MayEffect among its effects (CR 603.5).
##
## Later: "you may pay" costs during resolution (CR 603.5).

@export var trigger: MmTrigger
## An intervening "if" clause (CR 603.4), or null. Checked when it triggers and again on
## resolution.
@export var condition: MmCondition = null
@export var targets: Array[TargetRequirement] = []
@export var effects: Array[MmEffect] = []
## "Choose one —": one entry for each "•" line. Empty for a triggered ability that is not
## modal.
@export var modes: Array[AbilityMode] = []
## "This ability triggers only once each turn" (ADR 0054's addendum): once it has triggered
## in a turn, its source marks it Spent, and its trigger event does nothing more that turn,
## even several events at once. Counted on its source object, so one that leaves and
## returns is a new object that may trigger again (ADR 0008).
@export var is_once_each_turn: bool = false


## Whether the intervening "if" clause, if any, holds right now.
func condition_holds(state: MmGameState, context: MmEffectContext) -> bool:
	return condition == null or condition.is_true(state, context)


## Its modes: empty when it is not modal.
func modes_or_none() -> Array[AbilityMode]:
	return modes


## Whether this is a modal triggered ability (CR 700.2).
func is_modal() -> bool:
	return not modes.is_empty()


## The target requirements of mode [param mode_index], or this ability's own for
## SpellAbility.NO_MODE.
func targets_for(mode_index: int) -> Array[TargetRequirement]:
	return modes[mode_index].targets if mode_index != SpellAbility.NO_MODE else targets


## The effects of mode [param mode_index], or this ability's own for SpellAbility.NO_MODE.
func effects_for(mode_index: int) -> Array[MmEffect]:
	return modes[mode_index].effects if mode_index != SpellAbility.NO_MODE else effects


func describe() -> String:
	if is_modal():
		return "modal triggered ability (%d modes)" % modes.size()
	return "triggered ability (%d targets, %d effects)" % [targets.size(), effects.size()]
