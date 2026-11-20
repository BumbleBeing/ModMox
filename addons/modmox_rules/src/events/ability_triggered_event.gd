class_name AbilityTriggeredEvent
extends MmEvent
## A triggered ability triggers and waits to be put on the stack (CR 603.2). One that
## triggers only once each turn is Spent on its source as it does (ADR 0054's addendum).

var pending: PendingTrigger
## The Game Turn it triggered in, set when the event is applied.
var game_turn: int = 0


func _init(triggered: PendingTrigger) -> void:
	pending = triggered


func apply(state: MmGameState) -> void:
	game_turn = state.game_turn
	state.add_pending_trigger(pending)
	if not pending.ability.is_once_each_turn:
		return
	# A leaves-the-battlefield trigger's source may have left in the batch that triggered it
	# (CR 603.10a). It is gone for good and never triggers again (ADR 0008), so it needs no
	# mark, and a departed object is frozen.
	var source: MmGameObject = state.object(pending.source_object_id)
	if source != null:
		source.record_triggered(pending.ability_index, game_turn)


func describe() -> String:
	return "TRIGGERED: " + pending.describe()
