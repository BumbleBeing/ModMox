class_name ActiveReplacementEffect
extends RefCounted
## A replacement or prevention effect that is applying (ADR 0019): one created by a
## resolved spell or ability, kept in the game state until its duration ends or it is used
## up, or one a static ability generates, such as protection's. Never changes once made: a
## shield that is partly used is replaced by a copy with less left, so copies of the state
## can share these.

## For [member remaining]: never used up.
const UNLIMITED: int = -1

var effect: MmReplacementEffect
## CR 613.7: when it was created. A static ability's effect has its source's timestamp.
var timestamp: int
var controller_id: int
var source_object_id: int
## The source's Card Identity, so the GUI can show where a shield came from.
var source_card_id: int
## The players and objects it was locked to when it was created, such as the target of
## "prevent the next 1 damage that would be dealt to any target". Empty when the effect's
## own filters decide, as for "prevent all combat damage" (CR 611.2c).
var affected: Array[MmReference] = []
## How much it can still prevent, or how many more times it can apply, or UNLIMITED.
var remaining: int = UNLIMITED
## CreateContinuousEffect.Duration, or -1 for a static ability's effect.
var duration: int = -1
## For a static ability's effect: which ability on which object, so "applies once per
## event" (CR 616.2) can tell it apart. Empty for a created effect.
var _static_key: String = ""


func _init(replacement: MmReplacementEffect, effect_timestamp: int, controlling_player_id: int, source_id: int,
		source_card: int) -> void:
	effect = replacement
	timestamp = effect_timestamp
	controller_id = controlling_player_id
	source_object_id = source_id
	source_card_id = source_card


## An effect created by a resolving spell or ability.
static func created(replacement: MmReplacementEffect, effect_timestamp: int, controlling_player_id: int, source_id: int,
		source_card: int, locked: Array[MmReference], amount_left: int, lasting: int) -> ActiveReplacementEffect:
	var active: ActiveReplacementEffect = ActiveReplacementEffect.new(replacement, effect_timestamp, controlling_player_id,
		source_id, source_card)
	active.affected = locked.duplicate()
	active.remaining = amount_left
	active.duration = lasting
	return active


## The effect of ability number [param ability_index] of [param source], applying to
## [param source] itself, with the source's timestamp (CR 613.7a).
static func of_static(replacement: MmReplacementEffect, source: MmGameObject, ability_index: int) -> ActiveReplacementEffect:
	var active: ActiveReplacementEffect = ActiveReplacementEffect.new(replacement, source.id, source.controller_id,
		source.id, source.card_id)
	active.affected = [MmReference.to_object(source.id)]
	active._static_key = "static %d:%d" % [source.id, ability_index]
	return active


## What tells this effect apart from every other one applying right now.
func key() -> String:
	return _static_key if _static_key != "" else "created %d" % timestamp


## Whether a static ability generates it, rather than a resolved spell or ability.
func is_static() -> bool:
	return _static_key != ""


## Whether it was locked to [param reference] when it was created.
func is_locked_to(reference: MmReference) -> bool:
	for locked: MmReference in affected:
		if locked.equals(reference):
			return true
	return false


## A copy with [param amount_left] remaining.
func with_remaining(amount_left: int) -> ActiveReplacementEffect:
	var copy: ActiveReplacementEffect = ActiveReplacementEffect.created(effect, timestamp, controller_id, source_object_id,
		source_card_id, affected, amount_left, duration)
	copy._static_key = _static_key
	return copy


## The same for two effects exactly when using either one would change the game in the same
## way (A146).
func content_key() -> String:
	var locked: PackedStringArray = PackedStringArray()
	for reference: MmReference in affected:
		locked.append(reference.describe())
	return "%s remaining %d on [%s]" % [effect.content_key(), remaining, ", ".join(locked)]


func describe() -> String:
	var locked: PackedStringArray = PackedStringArray()
	for reference: MmReference in affected:
		locked.append(reference.describe())
	return "%s %s at %d from object %d (card %d) on [%s] remaining %d duration %d" % [
		effect.describe(), key(), timestamp, source_object_id, source_card_id, ", ".join(locked), remaining, duration]
