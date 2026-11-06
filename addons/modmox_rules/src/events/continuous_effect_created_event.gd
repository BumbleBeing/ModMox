class_name ContinuousEffectCreatedEvent
extends MmEvent
## A resolving spell or ability creates a continuous effect, locked to the objects and
## numbers it found (CR 611.2c). It takes the next timestamp (CR 613.7b).

var continuous: MmContinuousEffect
var controller_id: int
var source_object_id: int
var source_card_id: int
var affected_ids: Array[int]
var amounts: Array[int]
var duration: CreateContinuousEffect.Duration
## The effect as created, set when the event is applied.
var active: ActiveContinuousEffect = null


func _init(effect: MmContinuousEffect, controlling_player_id: int, source_id: int, source_card: int,
		ids: Array[int], locked_amounts: Array[int], lasting: CreateContinuousEffect.Duration) -> void:
	continuous = effect
	controller_id = controlling_player_id
	source_object_id = source_id
	source_card_id = source_card
	affected_ids = ids.duplicate()
	amounts = locked_amounts.duplicate()
	duration = lasting


func apply(state: MmGameState) -> void:
	active = ActiveContinuousEffect.locked(continuous, state.next_timestamp(), controller_id, source_object_id,
		source_card_id, affected_ids, amounts, duration)
	state.add_continuous_effect(active)


func describe() -> String:
	return "CONTINUOUS EFFECT: " + ("?" if active == null else active.describe())
