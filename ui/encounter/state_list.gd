class_name StateList
extends RefCounted
## The State List of a permanent (13h, ADR 0033): summoning sickness, damage marked, and
## each effect on it with the card it came from. The Encounter Presenter makes one for each
## permanent and puts it on the snapshot. A new kind of state, such as counters when the
## game has them, adds its entries here and changes nothing in the Inspector.


## The entries for the permanent [param seen] as [param view] shows it, in a fixed order.
static func of(seen: MmObjectView, view: MmPlayerView, names: PlayerNames = null) -> Array[StateEntry]:
	var entries: Array[StateEntry] = []
	if seen.is_creature and seen.is_summoning_sick:
		entries.append(StateEntry.new("Summoning sick",
			"It came under its controller's control this turn, so it can't attack or tap for a cost."))
	if seen.damage_marked > 0:
		entries.append(StateEntry.new("Damage", "%d damage is marked on it until end of turn." % seen.damage_marked))
	for active: ActiveContinuousEffect in seen.continuous_effects:
		var until: String = " until end of turn" if active.duration == CreateContinuousEffect.Duration.UNTIL_END_OF_TURN else ""
		entries.append(StateEntry.new(_source_name(active, view), "%s%s." % [_effect_text(active), until]))
	for active: ActiveReplacementEffect in seen.replacement_effects:
		entries.append(StateEntry.new(ReplacementText.source_name(active, view), ReplacementText.effect_text(active, view, names)))
	return entries


## What [param active] does to the permanent, without its full stop.
static func _effect_text(active: ActiveContinuousEffect) -> String:
	var amounts: Array[int] = active.amounts
	if active.effect is ModifyPowerToughnessContinuousEffect and amounts.size() == 2:
		return "It gets %+d/%+d" % amounts
	if active.effect is SetPowerToughnessContinuousEffect and amounts.size() == 2:
		return "Its base power and toughness are %d/%d" % amounts
	var gained: GainAbilitiesContinuousEffect = active.effect as GainAbilitiesContinuousEffect
	if gained != null:
		var words: PackedStringArray = []
		for ability: MmAbility in gained.abilities:
			var text: String = AbilityText.of_ability(ability, "it").trim_suffix(".")
			words.append(text.to_lower() if AbilityText.is_keyword(ability) else "\"%s.\"" % text)
		return "It has " + " and ".join(words)
	if active.effect is LoseAllAbilitiesContinuousEffect:
		return "It loses all abilities"
	return "An effect applies to it"


## The name of the card [param active] came from, wherever [param view] shows it: the
## object itself, or the same card after it moved, as a resolved spell is in a graveyard.
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
	return "An effect"
