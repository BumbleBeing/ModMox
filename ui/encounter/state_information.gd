class_name StateInformation
extends RefCounted
## The State Information of a permanent (13h and milestone 16, ADR 0033): summoning sickness, counters, damage marked, and
## what it is attached to and what is attached to it, what exiled it or what it exiled, a cast from the top of a library it allowed this turn, and each effect on it with the card it came from. The Encounter Presenter makes one for each
## permanent and puts it on the snapshot. A new kind of state adds its entries here and changes nothing in the Inspector.


## The entries for the permanent [param seen] as [param view] shows it, in a fixed order.
static func of(seen: MmObjectView, view: MmPlayerView, names: PlayerNames = null) -> Array[StateEntry]:
	var entries: Array[StateEntry] = []
	if seen.is_token:
		entries.append(StateEntry.new("Token", "Ceases to exist if it leaves the battlefield."))
	if seen.is_creature and seen.is_summoning_sick:
		entries.append(StateEntry.new("Summoning Sick",
			"Can't attack or tap until its controller's next turn."))
	for kind: MmCounter.Kind in MmCounter.KINDS:
		if seen.counters_of(kind) > 0:
			entries.append(StateEntry.new("%s Counters" % MmCounter.label(kind), _counters_text(kind, seen.counters_of(kind))))
	if seen.chosen_creature_type != "":
		entries.append(StateEntry.new("Chosen type: %s" % seen.chosen_creature_type, _chosen_type_text(seen)))
	for index: int in seen.permissions_used_this_turn:
		entries.append(StateEntry.new("Cast from the top this turn",
			_cast_from_top_text(seen, view, seen.permissions_used_this_turn[index], names)))
	entries.append_array(_attachment_entries(seen, view))
	entries.append_array(_exile_entries(seen, view))
	if seen.damage_marked > 0:
		entries.append(StateEntry.new("Damaged", "Has %d damage marked on it." % seen.damage_marked))
	for active: ActiveContinuousEffect in seen.continuous_effects:
		var until: String = " until end of turn" if active.duration == CreateContinuousEffect.Duration.UNTIL_END_OF_TURN else ""
		entries.append(StateEntry.new(_effect_title(_source_name(active, view)), "%s%s." % [_effect_text(active), until]))
	for active: ActiveReplacementEffect in seen.replacement_effects:
		var source: MmObjectView = ReplacementText.source_of(active, view)
		entries.append(StateEntry.new(_effect_title(source.name if source != null else ""), ReplacementText.effect_text(active, view, names)))
	return entries


## What [param seen] is attached to, and then each permanent attached to it, in object ID
## order as they are drawn.
static func _attachment_entries(seen: MmObjectView, view: MmPlayerView) -> Array[StateEntry]:
	var entries: Array[StateEntry] = []
	var attached: Array[MmObjectView] = []
	for other: MmObjectView in view.battlefield:
		if seen.attached_to_object_id != 0 and other.id == seen.attached_to_object_id:
			entries.append(StateEntry.new("Attached", "Attached to %s." % other.name))
		if seen.id != 0 and other.attached_to_object_id == seen.id:
			attached.append(other)
	attached.sort_custom(func(a: MmObjectView, b: MmObjectView) -> bool: return a.id < b.id)
	for other: MmObjectView in attached:
		entries.append(StateEntry.new("Attachment", "%s." % other.name))
	return entries


## What exiled [param seen], for a Tucked Card (game ADR 0043), and then each card
## [param seen] exiled that is still in exile, in object ID order as they are drawn. A card
## whose permanent has gone says nothing: it is exiled for good.
static func _exile_entries(seen: MmObjectView, view: MmPlayerView) -> Array[StateEntry]:
	var entries: Array[StateEntry] = []
	if seen.exiled_with_object_id != 0:
		for other: MmObjectView in view.battlefield:
			if other.id == seen.exiled_with_object_id:
				entries.append(StateEntry.new("Exiled", "Exiled by %s." % other.name))
		return entries
	if seen.id == 0:
		return entries
	var exiled: Array = Tucks.by_host(view, [seen.id] as Array[int]).get(seen.id, [])
	for card: MmObjectView in exiled:
		entries.append(StateEntry.new("Exiled Card", "%s." % card.name))
	return entries


## What [param seen]'s chosen type does, each ability that reads it worded with the type
## in its place, and when it was chosen (game ADR 0053): "Each Cat creature you control gets
## +1/+1. Chosen as Rally the Ranks entered."
static func _chosen_type_text(seen: MmObjectView) -> String:
	var lines: PackedStringArray = []
	for ability: MmAbility in seen.abilities:
		var worded: String = AbilityText.with_chosen_type(ability, seen.chosen_creature_type, AbilityText.self_noun(seen.card_types, seen.name))
		if worded != "":
			lines.append(worded)
	lines.append("Chosen as %s entered." % seen.name)
	return " ".join(lines)


## Who cast what with [param seen]'s permission this turn (game ADR 0055): "You cast
## Savannah Lions from the top of your library.", or "The Villain cast Pearled Unicorn from
## the top of their library." for the other player's.
static func _cast_from_top_text(seen: MmObjectView, view: MmPlayerView, spell_name: String, names: PlayerNames) -> String:
	if seen.controller_id == view.viewer_id:
		return "You cast %s from the top of your library." % spell_name
	var called: PlayerNames = names if names != null else PlayerNames.new()
	return "%s cast %s from the top of their library." % [called.starting(seen.controller_id), spell_name]


## "Currently has 2 +1/+1 counters.": the number in digits.
static func _counters_text(kind: MmCounter.Kind, count: int) -> String:
	return "Currently has %d %s %s." % [count, MmCounter.label(kind), "counter" if count == 1 else "counters"]


## An effect's entry is titled for the card it came from, "Samite Healer's Effect", or
## "Llanowar Elves' Effect" as the stack says it (StackItem), and plain "Effect" when that card is
## nowhere to be seen.
static func _effect_title(source_name: String) -> String:
	if source_name == "":
		return "Effect"
	return source_name + ("' Effect" if source_name.ends_with("s") else "'s Effect")


## "flying", "flying and trample", or "flying, first strike, and trample".
static func _series(words: PackedStringArray) -> String:
	if words.size() <= 2:
		return " and ".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + ", and " + words[words.size() - 1]


## What [param active] does to the permanent, without its full stop.
static func _effect_text(active: ActiveContinuousEffect) -> String:
	var amounts: Array[int] = active.amounts
	if active.effect is ModifyPowerToughnessContinuousEffect and amounts.size() == 2:
		return "%+d/%+d" % amounts
	if active.effect is SetPowerToughnessContinuousEffect and amounts.size() == 2:
		return "Has base power and toughness %d/%d" % amounts
	var gained: GainAbilitiesContinuousEffect = active.effect as GainAbilitiesContinuousEffect
	if gained != null:
		var words: PackedStringArray = []
		for ability: MmAbility in gained.abilities:
			var text: String = AbilityText.of_ability(ability, "it").trim_suffix(".")
			words.append(text.to_lower() if AbilityText.is_keyword(ability) else "\"%s.\"" % text)
		return "Has " + _series(words)
	if active.effect is LoseAllAbilitiesContinuousEffect:
		return "Loses all abilities"
	return "An effect"


## The name of the card [param active] came from, wherever [param view] shows it: the
## object itself, or the same card after it moved, as a resolved spell is in a graveyard.
## Empty if it is nowhere to be seen.
static func _source_name(active: ActiveContinuousEffect, view: MmPlayerView) -> String:
	var everything: Array[MmObjectView] = []
	everything.append_array(view.battlefield)
	everything.append_array(view.command)
	everything.append_array(view.stack)
	for player_id: int in view.graveyards:
		everything.append_array(view.graveyards[player_id])
	for player_id: int in view.exiles:
		everything.append_array(view.exiles[player_id])
	for seen: MmObjectView in everything:
		if seen.id == active.source_object_id:
			return seen.name
	for seen: MmObjectView in everything:
		if active.source_card_id != MmGameObject.NO_CARD and seen.card_id == active.source_card_id:
			return seen.name
	return ""
