class_name ReplacementRules
extends RefCounted
## Which replacement and prevention effects apply to an event about to be performed, who
## chooses among them, and when no choice needs asking (CR 616, ADR 0019).
##
## Later: self-replacement effects, which apply first (CR 614.15), and the other ordering
## categories of CR 616.1a-d, once a card has one.


## Every effect that applies to [param event] and has not already applied to it
## ([param applied_keys], CR 616.2): created effects in the order they were created, then
## those static abilities generate, in object ID order.
static func applicable(state: MmGameState, event: MmEvent, applied_keys: PackedStringArray) -> Array[ActiveReplacementEffect]:
	var found: Array[ActiveReplacementEffect] = []
	for active: ActiveReplacementEffect in state.replacement_effects + _from_static_abilities(state, event):
		if not applied_keys.has(active.key()) and active.effect.applies_to(state, event, active):
			found.append(active)
	return found


## The effect to apply without asking, or null when the affected player must choose
## (CR 616.1). A choice is needed only when the order could change the game: not for a
## single effect, nor when all of them prevent everything and are never used up, nor when
## they are all interchangeable (A146). Then the earliest one applies.
static func automatic_choice(choices: Array[ActiveReplacementEffect]) -> ActiveReplacementEffect:
	var all_prevent_everything: bool = true
	var all_interchangeable: bool = true
	var earliest: ActiveReplacementEffect = choices[0]
	for active: ActiveReplacementEffect in choices:
		all_prevent_everything = all_prevent_everything and active.effect.prevents_everything(active)
		all_interchangeable = all_interchangeable and active.content_key() == choices[0].content_key()
		if active.timestamp < earliest.timestamp:
			earliest = active
	return earliest if choices.size() == 1 or all_prevent_everything or all_interchangeable else null


## CR 616.1: the player affected by [param event] chooses: a player being dealt damage, or
## the controller of the object being dealt damage or destroyed.
static func affected_player_id(state: MmGameState, event: MmEvent) -> int:
	var damage: DamageEvent = event as DamageEvent
	if damage != null:
		if damage.recipient.is_player():
			return damage.recipient.id
		return state.object_or_last_known(damage.recipient.id).controller_id
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	assert(moved != null, "No player is affected by %s." % event.describe())
	return state.object(moved.object_id).controller_id


## The effects static abilities generate right now: protection's prevention (CR 702.16e).
static func _from_static_abilities(state: MmGameState, event: MmEvent) -> Array[ActiveReplacementEffect]:
	var found: Array[ActiveReplacementEffect] = []
	if not event is DamageEvent:
		return found  # Only protection generates one so far, and it only prevents damage.
	var permanents: Array[MmGameObject] = state.battlefield.objects()
	permanents.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	for permanent: MmGameObject in permanents:
		var abilities: Array[MmAbility] = state.characteristics_of(permanent).abilities
		for index: int in abilities.size():
			var protection: ProtectionAbility = abilities[index] as ProtectionAbility
			if protection != null:
				found.append(ActiveReplacementEffect.of_static(protection.prevention(), permanent, index))
	return found
