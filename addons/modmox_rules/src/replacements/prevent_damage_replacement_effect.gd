class_name PreventDamageReplacementEffect
extends MmReplacementEffect
## Prevents damage (CR 615): all of it, or as much as a shield has left (CR 615.7). Prevented
## damage is never dealt (CR 615.1), so nothing that reacts to damage sees it, and the
## prevention is recorded as a DamagePreventedEvent instead.

## Only damage from sources this matches is prevented; null means any source, as for Fog.
@export var sources: MmFilter = null
## For an effect not locked to particular players or objects: only damage to recipients this
## matches, checked when the damage would be dealt. Null means any recipient.
@export var recipients: MmFilter = null
## Only combat damage, as for Fog (CR 510.2).
@export var combat_only: bool = false


func applies_to(state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> bool:
	var damage: DamageEvent = event as DamageEvent
	if damage == null or damage.amount <= 0 or active.remaining == 0:
		return false
	if combat_only and not damage.is_combat:
		return false
	var context: MmEffectContext = MmEffectContext.new(active.controller_id, active.source_object_id)
	if active.affected.is_empty():
		if recipients != null and not recipients.matches(state, damage.recipient, context):
			return false
	elif not active.is_locked_to(damage.recipient):
		return false
	return sources == null or sources.matches(state, MmReference.to_object(damage.source_object_id), context)


func replace(_state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> Array[MmEvent]:
	var damage: DamageEvent = event as DamageEvent
	var prevented: int = damage.amount
	var shield_timestamp: int = 0
	if active.remaining != ActiveReplacementEffect.UNLIMITED:
		prevented = mini(damage.amount, active.remaining)
		shield_timestamp = active.timestamp
	var events: Array[MmEvent] = [DamagePreventedEvent.new(damage.source_object_id, damage.recipient, prevented,
		damage.is_combat, active.source_card_id, shield_timestamp)]
	if prevented < damage.amount:
		# CR 615.7: a shield prevents only as much as it has left; the rest is still dealt.
		events.append(DamageEvent.new(damage.source_object_id, damage.recipient, damage.amount - prevented, damage.is_combat))
	return events


func prevents_everything(active: ActiveReplacementEffect) -> bool:
	return active.remaining == ActiveReplacementEffect.UNLIMITED


func describe() -> String:
	return "prevent %sdamage" % ("combat " if combat_only else "")
