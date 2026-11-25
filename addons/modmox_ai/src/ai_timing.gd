class_name AiTiming
extends RefCounted
## Timing Tags (glossary "Timing Tag"): when a spell or ability is worth considering,
## derived from what its effects do and never authored (ADR 0002, A164). A tag decides
## when to look at a play, not whether it is good; simulation decides that.

enum Tag {
	## Considered whenever it may legally be played.
	NONE,
	## Only "until end of turn" changes, prevention or regeneration: worth something only
	## in a fight, so considered once blockers are declared or in response to a spell.
	COMBAT_TRICK,
	## Only grants abilities until end of turn, such as flying: it can change who may block
	## whom, so it is considered from the declare attackers step, and in response to a spell.
	EVASION,
	## Deals damage, fights, destroys, exiles or puts -1/-1 counters: considered in its controller's
	## main phases, once blockers are declared, in response to a spell, and in the other
	## player's end step.
	REMOVAL,
	## Counters a spell or an ability: considered only with the other player's spell or ability on top
	## of the stack, never to counter its own.
	COUNTER,
	## Only draws cards or searches for them into its owner's hand, from an activated ability
	## not restricted to sorcery timing, such as cycling, basic landcycling (ADR 0059) or
	## Jodah's Codex's "{5}, {T}: Draw a card": worth the mana left over, so considered only
	## in the other player's end step, when that mana would go unused, and in response to the
	## other player's spell or ability. An ability whose cost exerts its creature (CR 701.43),
	## such as Pride Sovereign's, and which is otherwise NONE, is considered then too: its
	## creature was free to block first, and it skips the same untap step either way.
	SPARE_MANA,
}

const COMBAT_STEPS: Array[MmTurn.Step] = [
	MmTurn.Step.BEGINNING_OF_COMBAT, MmTurn.Step.DECLARE_ATTACKERS,
	MmTurn.Step.DECLARE_BLOCKERS, MmTurn.Step.COMBAT_DAMAGE,
]


## [param effects] with each "you may" (MayEffect), "you may pay {X}" (MayPayXEffect,
## ADR 0061), "you may [cost]" (MayPayEffect, ADR 0076) and "if [condition]" (IfEffect)
## replaced by the effect it offers, so a spell or ability is read as doing what it may do
## (CR 603.5).
static func unwrapped(effects: Array[MmEffect]) -> Array[MmEffect]:
	var found: Array[MmEffect] = []
	for effect: MmEffect in effects:
		var offered: MmEffect = effect
		while offered is MayEffect or offered is MayPayXEffect or offered is MayPayEffect or offered is IfEffect:
			if offered is IfEffect:
				offered = (offered as IfEffect).effect
			elif offered is MayPayEffect:
				offered = (offered as MayPayEffect).effect
			else:
				offered = (offered as MayEffect).effect if offered is MayEffect else (offered as MayPayXEffect).effect
		found.append(offered)
	return found


## The tag of a spell or ability whose effects are [param effects].
static func tag_of_effects(wrapped: Array[MmEffect]) -> Tag:
	var effects: Array[MmEffect] = unwrapped(wrapped)
	if effects.is_empty():
		return Tag.NONE
	var is_trick: bool = true
	var is_evasion: bool = true
	for effect: MmEffect in effects:
		if effect is CounterEffect:
			return Tag.COUNTER
	for effect: MmEffect in effects:
		if effect is DealDamageEffect or effect is FightEffect or effect is DestroyEffect or effect is ExileEffect \
				or _shrinks_for_good(effect):
			return Tag.REMOVAL
		var lasts_the_turn: bool = effect is CreateContinuousEffect \
			and (effect as CreateContinuousEffect).duration == CreateContinuousEffect.Duration.UNTIL_END_OF_TURN
		if not (lasts_the_turn or effect is PreventDamageEffect or effect is RegenerateEffect):
			is_trick = false
		if not (lasts_the_turn and (effect as CreateContinuousEffect).continuous is GainAbilitiesContinuousEffect):
			is_evasion = false
	if not is_trick:
		return Tag.NONE
	return Tag.EVASION if is_evasion else Tag.COMBAT_TRICK


## Whether [param effects] harm what they reach, so they are aimed at the other player's
## permanents: removal, a counter, or a tap, which keeps a creature from blocking or
## attacking. A tap keeps its tag: it is not removal.
static func is_harmful(effects: Array[MmEffect]) -> bool:
	var tag: Tag = tag_of_effects(effects)
	return tag == Tag.REMOVAL or tag == Tag.COUNTER or taps(effects)


## Whether any of [param effects] taps: worth something only in a fight this turn or the
## next, so its targets are scored once the turn is over.
static func taps(effects: Array[MmEffect]) -> bool:
	for effect: MmEffect in unwrapped(effects):
		if effect is TapEffect:
			return true
	return false


## Whether any of [param effects] untaps: worth something, as a tap is, only in a fight
## this turn or the next, so its targets are scored once the turn is over too. It helps what
## it reaches, so it is aimed at the Agent's own permanents.
static func untaps(effects: Array[MmEffect]) -> bool:
	for effect: MmEffect in unwrapped(effects):
		if effect is UntapEffect:
			return true
	return false


## Whether [param effect] puts -1/-1 counters: harm that lasts, aimed like removal.
static func _shrinks_for_good(effect: MmEffect) -> bool:
	var put: PutCountersEffect = effect as PutCountersEffect
	return put != null and put.kind == MmCounter.Kind.MINUS_ONE_MINUS_ONE


## Whether [param tag] marks a play that lasts only until end of turn.
static func is_trick(tag: Tag) -> bool:
	return tag == Tag.COMBAT_TRICK or tag == Tag.EVASION


## The tag of a priority [param action], read from [param state].
static func tag_of_action(state: MmGameState, action: MmAction) -> Tag:
	var spell: SpellAbility = modal_spell_of_action(state, action)
	if spell != null:
		return tag_of_spell(spell)
	var flashed: Tag = _tag_of_flash_permanent(state, action)
	if flashed != Tag.NONE:
		return flashed
	var effects: Array[MmEffect] = effects_of_action(state, action)
	var activated: ActivatedAbility = activated_ability_of(state, action)
	if activated != null and not activated.is_sorcery_speed and _only_draws_or_searches_into_the_hand(effects):
		return Tag.SPARE_MANA
	if activated is EquipAbility and not _at_sorcery_timing(state, state.object((action as ActivateAbilityAction).object_id).controller_id):
		# Equip offered at instant speed (InstantSpeedEquipAbility) is worth it in a fight:
		# moved after blockers are declared, or onto a creature a spell would kill.
		return Tag.COMBAT_TRICK
	var tag: Tag = tag_of_effects(effects)
	if tag == Tag.NONE and activated != null and not activated.is_sorcery_speed and _exerts(activated):
		return Tag.SPARE_MANA
	return tag


## For casting a permanent spell with flash: the tag of its own "enters" triggered
## abilities when that is removal or a trick, as Leyline Binding's exile is, so it is held
## for the moments those are; otherwise NONE, and it is cast as any permanent is (ADR 0065).
static func _tag_of_flash_permanent(state: MmGameState, action: MmAction) -> Tag:
	var cast: CastSpellAction = action as CastSpellAction
	if cast == null:
		return Tag.NONE
	var characteristics: MmCharacteristics = characteristics_of_cast(state, cast)
	if not characteristics.is_permanent() or not characteristics.has_ability(FlashAbility):
		return Tag.NONE
	var effects: Array[MmEffect] = []
	for ability: MmAbility in characteristics.abilities:
		var triggered: TriggeredAbility = ability as TriggeredAbility
		if triggered != null and _is_own_enters(triggered.trigger):
			effects.append_array(triggered.effects)
	var tag: Tag = tag_of_effects(effects)
	return tag if tag == Tag.REMOVAL or is_trick(tag) else Tag.NONE


## Whether [param trigger] is "when this enters": the source itself arriving on the
## battlefield.
static func _is_own_enters(trigger: MmTrigger) -> bool:
	var zone_change: ZoneChangeTrigger = trigger as ZoneChangeTrigger
	return zone_change != null and not zone_change.any_to_zone and zone_change.to_zone == MmZone.Kind.BATTLEFIELD \
		and zone_change.filter is IsSourceFilter


## Whether paying for [param ability] exerts its source (CR 701.43).
static func _exerts(ability: ActivatedAbility) -> bool:
	for cost: MmCost in ability.costs:
		if cost is ExertCost:
			return true
	return false


## Whether [param player_id] has sorcery timing (CR 307.1): their own main phase, with an
## empty stack.
static func _at_sorcery_timing(state: MmGameState, player_id: int) -> bool:
	var main_phase: bool = state.step == MmTurn.Step.PRECOMBAT_MAIN or state.step == MmTurn.Step.POSTCOMBAT_MAIN
	return state.active_player_id == player_id and main_phase and state.stack.is_empty()


## Whether [param effects] do nothing but draw cards or search for cards into the hand.
static func _only_draws_or_searches_into_the_hand(effects: Array[MmEffect]) -> bool:
	for effect: MmEffect in effects:
		var search: SearchLibraryEffect = effect as SearchLibraryEffect
		var searches_into_the_hand: bool = search != null and search.destination == MmZone.Kind.HAND
		if not (effect is DrawCardsEffect or searches_into_the_hand):
			return false
	return not effects.is_empty()


## The tag of [param spell]. A modal spell's modes share their tag when they agree;
## otherwise it is considered whenever it may be cast (NONE), since some mode may be worth
## it at any time.
static func tag_of_spell(spell: SpellAbility) -> Tag:
	if not spell.is_modal():
		return tag_of_effects(spell.effects)
	var shared: Tag = tag_of_effects(spell.modes[0].effects)
	for mode: AbilityMode in spell.modes:
		if tag_of_effects(mode.effects) != shared:
			return Tag.NONE
	return shared


## The characteristics of what [param cast] casts: its card's, its Adventure's when it
## casts the card as one (CR 715.3b, engine ADR 0078), or an Aura's when it casts the card
## bestowed (CR 702.103b, engine ADR 0089).
static func characteristics_of_cast(state: MmGameState, cast: CastSpellAction) -> MmCharacteristics:
	if cast.is_bestowed:
		return BestowRules.as_bestowed(state, state.object(cast.object_id))
	var characteristics: MmCharacteristics = state.characteristics_of(state.object(cast.object_id))
	return characteristics.adventure if cast.as_adventure and characteristics.adventure != null else characteristics


## The modal spell [param action] casts, or null if it casts none.
static func modal_spell_of_action(state: MmGameState, action: MmAction) -> SpellAbility:
	var cast: CastSpellAction = action as CastSpellAction
	if cast == null:
		return null
	for ability: MmAbility in characteristics_of_cast(state, cast).abilities:
		var spell: SpellAbility = ability as SpellAbility
		if spell != null and spell.is_modal():
			return spell
	return null


## What [param action] would do: a spell's effects (every mode's, for a modal spell), or an
## activated ability's, each "you may" read as what it offers. A permanent spell does
## nothing when it resolves but enter, so it has none.
static func effects_of_action(state: MmGameState, action: MmAction) -> Array[MmEffect]:
	var effects: Array[MmEffect] = []
	var cast: CastSpellAction = action as CastSpellAction
	if cast != null:
		var characteristics: MmCharacteristics = characteristics_of_cast(state, cast)
		if characteristics.is_permanent():
			return effects
		for ability: MmAbility in characteristics.abilities:
			var spell: SpellAbility = ability as SpellAbility
			if spell == null:
				continue
			effects.append_array(spell.effects)
			for mode: AbilityMode in spell.modes:
				effects.append_array(mode.effects)
		return unwrapped(effects)
	var activated: ActivatedAbility = activated_ability_of(state, action)
	if activated != null:
		effects.append_array(activated.effects)
	return unwrapped(effects)


## The ability [param action] activates, or null if it activates none.
static func activated_ability_of(state: MmGameState, action: MmAction) -> ActivatedAbility:
	var activate: ActivateAbilityAction = action as ActivateAbilityAction
	if activate == null:
		return null
	var abilities: Array[MmAbility] = state.characteristics_of(state.object(activate.object_id)).abilities
	return abilities[activate.ability_index] as ActivatedAbility


## Whether [param tag] is worth considering for [param player_id] now.
static func is_in_window(state: MmGameState, player_id: int, tag: Tag) -> bool:
	if tag == Tag.NONE:
		return true
	if _opposing_object_on_top(state, player_id):
		return true
	if tag == Tag.COUNTER:
		return false
	if tag == Tag.SPARE_MANA:
		return state.active_player_id != player_id and state.step == MmTurn.Step.END
	if state.step == MmTurn.Step.DECLARE_BLOCKERS:
		return true
	if tag == Tag.EVASION:
		return state.step == MmTurn.Step.DECLARE_ATTACKERS
	if tag == Tag.REMOVAL:
		var my_turn: bool = state.active_player_id == player_id
		var main_phase: bool = state.step == MmTurn.Step.PRECOMBAT_MAIN or state.step == MmTurn.Step.POSTCOMBAT_MAIN
		return (my_turn and main_phase and state.stack.is_empty()) or (not my_turn and state.step == MmTurn.Step.END)
	return false


## Whether [param action] would put an ability on top of its own earlier activation: the
## same ability of the same permanent is the top object of the stack. Letting the first one
## resolve loses nothing, and one answer to the permanent then wastes only one activation.
## (Later: an ability whose first resolution would kill its own source wants to be stacked.)
static func is_on_top_of_itself(state: MmGameState, action: MmAction) -> bool:
	var activate: ActivateAbilityAction = action as ActivateAbilityAction
	if activate == null or state.stack.is_empty():
		return false
	var top: MmGameObject = state.stack.objects().back()
	return top.ability != null and top.source_object_id == activate.object_id \
		and top.ability == activated_ability_of(state, action)


static func _opposing_object_on_top(state: MmGameState, player_id: int) -> bool:
	# The top of the stack is the last object in the zone.
	return not state.stack.is_empty() and (state.stack.objects().back() as MmGameObject).controller_id != player_id
