class_name ReplacementEffectCreatedEvent
extends MmEvent
## A resolving spell or ability creates a replacement or prevention effect, such as a
## damage shield or a regeneration shield (ADR 0019). It takes the next timestamp
## (CR 613.7b).

var replacement: MmReplacementEffect
var controller_id: int
var source_object_id: int
var source_card_id: int
var affected: Array[MmReference]
var remaining: int
var duration: CreateContinuousEffect.Duration
## The effect as created, set when the event is applied.
var active: ActiveReplacementEffect = null


func _init(effect: MmReplacementEffect, controlling_player_id: int, source_id: int, source_card: int,
		locked: Array[MmReference], amount_left: int, lasting: CreateContinuousEffect.Duration) -> void:
	replacement = effect
	controller_id = controlling_player_id
	source_object_id = source_id
	source_card_id = source_card
	affected = locked.duplicate()
	remaining = amount_left
	duration = lasting


func apply(state: MmGameState) -> void:
	active = ActiveReplacementEffect.created(replacement, state.next_timestamp(), controller_id, source_object_id,
		source_card_id, affected, remaining, duration)
	state.add_replacement_effect(active)


func describe() -> String:
	return "REPLACEMENT EFFECT: " + ("?" if active == null else active.describe())
