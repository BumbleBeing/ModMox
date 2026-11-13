class_name ReplacementText
extends RefCounted
## The words of the replacement choice (A340): the event about to happen, and for each
## effect that could apply to it first, what it does and where it came from.


## What the choice's window is titled: the event, and the question.
static func title(decision: ChooseReplacementEffectDecision, view: MmPlayerView, names: PlayerNames = null) -> String:
	return "%s: which applies first?" % event_text(decision.event, view, names)


## [param event] in a few words, such as "3 damage to Grizzly Bears".
static func event_text(event: MmEvent, view: MmPlayerView, names: PlayerNames = null) -> String:
	var damage: DamageEvent = event as DamageEvent
	if damage != null:
		return "%d %sdamage to %s" % [damage.amount, "combat " if damage.is_combat else "", _name(damage.recipient, view, names)]
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	if moved != null and moved.reason == ZoneChangeEvent.Reason.DESTROY:
		return "%s would be destroyed" % _name(MmReference.to_object(moved.object_id), view)
	return "This event"


## What [param active] does, with what a shield has left.
static func effect_text(active: ActiveReplacementEffect, view: MmPlayerView, names: PlayerNames = null) -> String:
	var affected_names: PackedStringArray = []
	for affected: MmReference in active.affected:
		affected_names.append(_name(affected, view, names))
	var whom: String = " or ".join(affected_names)
	var prevent: PreventDamageReplacementEffect = active.effect as PreventDamageReplacementEffect
	if prevent != null:
		var to_whom: String = "" if whom == "" else " to " + whom
		if active.remaining != ActiveReplacementEffect.UNLIMITED:
			return "Prevent the next %d damage that would be dealt%s this turn." % [active.remaining, to_whom]
		var by_whom: String = "" if prevent.sources == null else " by " + AbilityText.things(prevent.sources)
		return "Prevent all %sdamage that would be dealt%s%s this turn." % ["combat " if prevent.combat_only else "", to_whom, by_whom]
	if active.effect is RegenerationReplacementEffect:
		return "The next time %s would be destroyed this turn, it regenerates instead." % (whom if whom != "" else "it")
	return "A replacement effect."


## The card [param active] came from, wherever [param view] shows it: the object itself,
## or the same card after it moved, as a resolved spell is in a graveyard. Null if unseen.
static func source_of(active: ActiveReplacementEffect, view: MmPlayerView) -> MmObjectView:
	var everything: Array[MmObjectView] = _visible(view)
	for seen: MmObjectView in everything:
		if seen.id == active.source_object_id:
			return seen
	for seen: MmObjectView in everything:
		if active.source_card_id != MmGameObject.NO_CARD and seen.card_id == active.source_card_id:
			return seen
	return null


static func source_name(active: ActiveReplacementEffect, view: MmPlayerView) -> String:
	var source: MmObjectView = source_of(active, view)
	return source.name if source != null else "An effect"


static func _name(reference: MmReference, view: MmPlayerView, names: PlayerNames = null) -> String:
	if reference.is_player():
		return (names if names != null else PlayerNames.new()).of(reference.id)
	for seen: MmObjectView in view.battlefield:
		if seen.id == reference.id:
			return seen.name
	return "a permanent"


static func _visible(view: MmPlayerView) -> Array[MmObjectView]:
	var all: Array[MmObjectView] = []
	all.append_array(view.battlefield)
	all.append_array(view.command)
	all.append_array(view.stack)
	all.append_array(view.hand)
	for player_id: int in view.graveyards:
		all.append_array(view.graveyards[player_id])
	for player_id: int in view.exiles:
		all.append_array(view.exiles[player_id])
	return all
