class_name YouDidCondition
extends MmCondition
## "If you do", after a "you may" (CR 603.5, 608.2c), as Riddlesmith's "you may draw a card.
## If you do, discard a card.": true once the latest MayEffect or MayPayEffect of the same
## spell or ability was answered yes, its cost paid (MmEffectContext.answered_yes). An
## IfEffect after the "you may" holds it, so the effect it wraps, and any decision of its
## own, happens only on yes. Before any "you may" has been asked it is false.
# Later: "If you don't", once a card says it.


func is_true(_state: MmGameState, context: MmEffectContext) -> bool:
	return context.answered_yes
