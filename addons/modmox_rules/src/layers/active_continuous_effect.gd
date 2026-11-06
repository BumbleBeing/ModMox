class_name ActiveContinuousEffect
extends RefCounted
## A continuous effect that is applying: one created by a resolved spell or ability, kept
## in the game state until its duration ends, or one a static ability generates while the
## layers are worked out. Never changes once made, so copies of the state share it.

var effect: MmContinuousEffect
## CR 613.7: earlier effects apply first within a layer. Object IDs and these timestamps
## come from the same counter (A117, A127).
var timestamp: int
var controller_id: int
var source_object_id: int
## The source's Card Identity, so the GUI can explain where a change came from.
var source_card_id: int
## For a resolved spell's effect: the objects it found when it resolved (CR 611.2c) and
## its numbers then (CR 608.2h). Empty and unused for a static ability's effect.
var is_locked: bool
var affected_ids: Array[int]
var amounts: Array[int]
## CreateContinuousEffect.Duration, or -1 for a static ability's effect.
var duration: int
## For a static ability's effect: the ability, so CR 613.6 can follow it across layers.
var static_ability: ContinuousStaticAbility


func _init(continuous: MmContinuousEffect, effect_timestamp: int, controlling_player_id: int,
		source_id: int, source_card: int) -> void:
	effect = continuous
	timestamp = effect_timestamp
	controller_id = controlling_player_id
	source_object_id = source_id
	source_card_id = source_card
	is_locked = false
	affected_ids = []
	amounts = []
	duration = -1
	static_ability = null


## The effect of [param ability] on [param source], with the source's timestamp (its object
## ID, CR 613.7a).
static func of_static(continuous: MmContinuousEffect, ability: ContinuousStaticAbility, source: MmGameObject) -> ActiveContinuousEffect:
	var active: ActiveContinuousEffect = ActiveContinuousEffect.new(continuous, source.id, source.controller_id, source.id, source.card_id)
	active.static_ability = ability
	return active


## An effect created by a resolving spell or ability, locked to [param ids] and
## [param locked_amounts].
static func locked(continuous: MmContinuousEffect, effect_timestamp: int, controlling_player_id: int, source_id: int,
		source_card: int, ids: Array[int], locked_amounts: Array[int], effect_duration: int) -> ActiveContinuousEffect:
	var active: ActiveContinuousEffect = ActiveContinuousEffect.new(continuous, effect_timestamp, controlling_player_id, source_id, source_card)
	active.is_locked = true
	active.affected_ids = ids.duplicate()
	active.amounts = locked_amounts.duplicate()
	active.duration = effect_duration
	return active


func describe() -> String:
	return "%s at %d from object %d on %s %s" % [effect.get_script().get_global_name(), timestamp, source_object_id, affected_ids, amounts]
