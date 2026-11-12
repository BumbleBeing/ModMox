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
	## Deals damage or destroys: considered in its controller's main phases, once blockers
	## are declared, in response to a spell, and in the other player's end step.
	REMOVAL,
	## Counters a spell: considered only with the other player's spell or ability on top
	## of the stack, never to counter its own.
	COUNTER,
}

const COMBAT_STEPS: Array[MmTurn.Step] = [
	MmTurn.Step.BEGINNING_OF_COMBAT, MmTurn.Step.DECLARE_ATTACKERS,
	MmTurn.Step.DECLARE_BLOCKERS, MmTurn.Step.COMBAT_DAMAGE,
]


## The tag of a spell or ability whose effects are [param effects].
static func tag_of_effects(effects: Array[MmEffect]) -> Tag:
	if effects.is_empty():
		return Tag.NONE
	var is_trick: bool = true
	var is_evasion: bool = true
	for effect: MmEffect in effects:
		if effect is CounterEffect:
			return Tag.COUNTER
	for effect: MmEffect in effects:
		if effect is DealDamageEffect or effect is DestroyEffect:
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


## Whether [param tag] marks a play that lasts only until end of turn.
static func is_trick(tag: Tag) -> bool:
	return tag == Tag.COMBAT_TRICK or tag == Tag.EVASION


## The tag of a priority [param action], read from [param state].
static func tag_of_action(state: MmGameState, action: MmAction) -> Tag:
	var effects: Array[MmEffect] = effects_of_action(state, action)
	return tag_of_effects(effects)


## What [param action] would do: a spell's effects, or an activated ability's. A permanent
## spell does nothing when it resolves but enter, so it has none.
static func effects_of_action(state: MmGameState, action: MmAction) -> Array[MmEffect]:
	var effects: Array[MmEffect] = []
	var cast: CastSpellAction = action as CastSpellAction
	if cast != null:
		var characteristics: MmCharacteristics = state.characteristics_of(state.object(cast.object_id))
		if characteristics.is_permanent():
			return effects
		for ability: MmAbility in characteristics.abilities:
			if ability is SpellAbility:
				effects.append_array((ability as SpellAbility).effects)
		return effects
	var activated: ActivatedAbility = activated_ability_of(state, action)
	if activated != null:
		effects.append_array(activated.effects)
	return effects


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
