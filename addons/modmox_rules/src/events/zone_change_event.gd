class_name ZoneChangeEvent
extends MmEvent
## A card or token moves from one zone to another and becomes a new Game Object (CR 400.7,
## ADR 0008).
## Zones are named by kind and owner rather than referenced, so the event stays plain data
## that a copied game state can share.

## Only ever add values at the end, so saved event histories keep their meaning.
## DESTROY is CR 701.8 (indestructible and regeneration care); ZERO_TOUGHNESS is CR 704.5f,
## which is not destruction. COUNTER is CR 701.6: a spell countered on the stack.
## RETURN_TO_HAND is an effect putting a card into its owner's hand. EXILE is CR 701.13a,
## and RETURN_TO_BATTLEFIELD an effect putting a card in exile or a graveyard onto the
## battlefield. SEARCH is a card found by a search (CR 701.23). UNATTACHED_AURA is CR 704.5m:
## an Aura attached illegally, or to nothing, put into its owner's graveyard. SACRIFICE is
## CR 701.21a: its controller moving a permanent to its owner's graveyard, which is not
## destruction.
enum Reason { DRAW, MULLIGAN, PUT_ON_BOTTOM, DISCARD, PLAY_LAND, CAST, RESOLVED, DID_NOT_RESOLVE, DESTROY, ZERO_TOUGHNESS, COUNTER, RETURN_TO_HAND,
	EXILE, RETURN_TO_BATTLEFIELD, LEGEND_RULE, SEARCH, UNATTACHED_AURA, SURVEIL, SACRIFICE, MILL, LOOK }

## The object leaving. It stops existing once this event is applied.
var object_id: int
var card_id: int
var from_zone_kind: MmZone.Kind
var from_owner_id: int
var to_zone_kind: MmZone.Kind
var to_owner_id: int
## Position in the destination: 0 for the top, MmZone.BOTTOM for after the last object.
var position: int
var reason: Reason
## For a destruction: false when it "can't be regenerated", as with Terror (CR 701.19c).
var can_be_regenerated: bool = true
## For an exile: the object whose ability exiled the card, which its linked ability later
## looks for (CR 607.2a), or 0.
var exiled_with_object_id: int = 0
## For an exile "until [that object] leaves the battlefield" (CR 610.3, ADR 0065): the card
## comes back once the object in exiled_with_object_id has left.
var exiled_until_source_leaves: bool = false
## For a card cast from a graveyard for its flashback cost (CR 702.34a): marks the spell.
var cast_with_flashback: bool = false
## For an Adventurer card cast as its Adventure (CR 715.3): marks the spell.
var cast_as_adventure: bool = false
## For a spell cast as an Adventure that resolved (CR 715.3d): marks the card in exile.
var exiled_on_adventure: bool = false
## For a card entering the battlefield: the counters it enters with (CR 122.6), on it as it
## arrives so that its "enters" abilities see them.
var counters_on_arrival: Dictionary[MmCounter.Kind, int] = {}
## For a card entering the battlefield: true when it enters tapped (CR 110.5b), tapped as it
## arrives so that its "enters" abilities see it tapped.
var tapped_on_arrival: bool = false
## For a card entering the battlefield: the creature type chosen as it enters (CR 614.12,
## ADR 0052), or "". Recorded as it arrives, so its static abilities apply at once.
var chosen_creature_type_on_arrival: String = ""
## For a card entering the battlefield: true when its controller paid what its
## AsEntersPayOrEntersTappedAbility asks as it enters, so it enters untapped (ADR 0052).
var entry_cost_paid: bool = false
## For an Aura spell entering the battlefield: the ID of the object it enters attached to
## (CR 303.4a, ADR 0064), or 0. Attached as it arrives, so its static abilities apply at
## once and its "enters" abilities see what it enchants.
var attached_to_on_arrival: int = 0
## For a card found by a search and revealed (CR 701.20, ADR 0057): every player sees it,
## so one put into a hand is a Known Card there.
var revealed: bool = false
## The new object's ID, set when the event is applied.
var new_object_id: int = 0
## For an object leaving the battlefield or a graveyard: its characteristics as it last
## existed there, set when the event is applied (CR 608.2h).
var last_known: MmCharacteristics = null


func _init(leaving: MmGameObject, destination: MmZone, at_position: int, why: Reason, regenerable: bool = true) -> void:
	object_id = leaving.id
	card_id = leaving.card_id
	from_zone_kind = leaving.zone().kind
	from_owner_id = leaving.zone().owner_id
	to_zone_kind = destination.kind
	to_owner_id = destination.owner_id
	position = at_position
	reason = why
	can_be_regenerated = regenerable


## The same move, not yet performed, for a replacement effect to change (ADR 0019): the
## original may be shared with a copy of the state, so it is never changed itself.
func copy(state: MmGameState) -> ZoneChangeEvent:
	var same: ZoneChangeEvent = new(state.object(object_id), state.zone(to_zone_kind, to_owner_id), position,
		reason, can_be_regenerated)
	same.exiled_with_object_id = exiled_with_object_id
	same.exiled_until_source_leaves = exiled_until_source_leaves
	same.cast_with_flashback = cast_with_flashback
	same.cast_as_adventure = cast_as_adventure
	same.exiled_on_adventure = exiled_on_adventure
	same.counters_on_arrival = counters_on_arrival.duplicate()
	same.tapped_on_arrival = tapped_on_arrival
	same.chosen_creature_type_on_arrival = chosen_creature_type_on_arrival
	same.attached_to_on_arrival = attached_to_on_arrival
	same.entry_cost_paid = entry_cost_paid
	same.revealed = revealed
	return same


func apply(state: MmGameState) -> void:
	var from_zone: MmZone = state.zone(from_zone_kind, from_owner_id)
	var to_zone: MmZone = state.zone(to_zone_kind, to_owner_id)
	var leaving: MmGameObject = state.object(object_id)
	assert(leaving != null and leaving.zone() == from_zone, "Object %d is no longer in the %s." % [object_id, from_zone.describe()])
	if from_zone_kind == MmZone.Kind.BATTLEFIELD or from_zone_kind == MmZone.Kind.GRAVEYARD:
		# CR 608.2h: keep what it last looked like, for look-back triggers and "its power",
		# and for "if it was a permanent card" once a card has left a graveyard.
		last_known = state.characteristics_of(leaving)
		leaving.freeze_last_known(last_known)
		state.record_departure(leaving)
	var hand_size_before: int = from_zone.size()
	from_zone.remove(leaving)
	state.retire_object(leaving)
	if from_zone_kind == MmZone.Kind.HAND and to_zone_kind == MmZone.Kind.LIBRARY and not revealed and hand_size_before >= 2:
		# ADR 0057: the other player cannot tell which card went, so nothing left in that
		# hand is known any more.
		for kept: MmGameObject in from_zone.objects():
			kept.forget_who_knows()
	var arriving: MmGameObject = state.create_object(leaving.card_id, leaving.owner_id, leaving.definition)
	to_zone.insert(arriving, position)
	new_object_id = arriving.id
	if leaving.is_token:
		# CR 111.7: a token that leaves the battlefield moves like a card, and is still a
		# token where it lands until state-based actions see it there (CR 704.5d).
		arriving.become_token()
	if leaving.is_copy and to_zone_kind == MmZone.Kind.BATTLEFIELD:
		# CR 608.3f, 111.13: a copy of a permanent spell becomes a token as it resolves, and
		# is no longer a copy of a spell.
		arriving.become_token()
	elif leaving.is_copy:
		# CR 707.10a: still a copy where it lands, until state-based actions see it there
		# (CR 704.5e).
		arriving.become_copy()
	if to_zone_kind == MmZone.Kind.EXILE and exiled_with_object_id != 0:
		arriving.record_exiled_with(exiled_with_object_id, exiled_until_source_leaves)
	if to_zone_kind == MmZone.Kind.LIBRARY and from_zone_kind == MmZone.Kind.HAND:
		# Whoever held the card knows where it went, until the library is shuffled.
		# Later: a card put there from a zone everyone sees, when a card does that.
		arriving.make_known_to(from_owner_id)
	if revealed and to_zone_kind == MmZone.Kind.HAND:
		for player: MmPlayer in state.players:
			if player.id != to_owner_id:
				arriving.make_known_to(player.id)
	if cast_with_flashback:
		arriving.record_cast_with_flashback()
	if cast_as_adventure and to_zone_kind == MmZone.Kind.STACK:
		arriving.record_cast_as_adventure()
	if exiled_on_adventure and to_zone_kind == MmZone.Kind.EXILE:
		arriving.record_on_adventure()
	if reason == Reason.CAST and from_zone_kind == MmZone.Kind.LIBRARY:
		arriving.record_cast_from_library()  # ADR 0054
	for kind: MmCounter.Kind in counters_on_arrival:
		arriving.put_counters(kind, counters_on_arrival[kind])
	if tapped_on_arrival and to_zone_kind == MmZone.Kind.BATTLEFIELD:
		arriving.set_tapped(true)
	if chosen_creature_type_on_arrival != "" and to_zone_kind == MmZone.Kind.BATTLEFIELD:
		arriving.record_chosen_creature_type(chosen_creature_type_on_arrival)
	if attached_to_on_arrival != 0 and to_zone_kind == MmZone.Kind.BATTLEFIELD:
		arriving.attach_to(attached_to_on_arrival)
	if to_zone_kind == MmZone.Kind.BATTLEFIELD:
		# CR 302.6: summoning sickness counts from when its controller began controlling it.
		arriving.record_control_since(state.game_turn)
	if reason == Reason.PLAY_LAND:
		state.player(arriving.controller_id).record_land_play()


func describe() -> String:
	var exiled_with: String = "" if exiled_with_object_id == 0 else " with object %d%s" % [exiled_with_object_id,
		" until it leaves" if exiled_until_source_leaves else ""]
	var chosen: String = "" if chosen_creature_type_on_arrival == "" else " choosing %s" % chosen_creature_type_on_arrival
	var attached: String = "" if attached_to_on_arrival == 0 else " attached to object %d" % attached_to_on_arrival
	return "%s%s: object %d (card %d) from %s to %s%s%s%s%s as object %d" % [
		Reason.find_key(reason), "" if can_be_regenerated else " (can't be regenerated)", object_id, card_id,
		MmZone.describe_zone(from_zone_kind, from_owner_id), MmZone.describe_zone(to_zone_kind, to_owner_id),
		" tapped" if tapped_on_arrival else "", chosen, attached, exiled_with, new_object_id]
