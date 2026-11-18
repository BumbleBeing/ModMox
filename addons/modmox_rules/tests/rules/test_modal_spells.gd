extends GutTest
## CR 700.2: a modal spell says "Choose one —" and its controller chooses the mode as it is
## cast (CR 601.2b), before its targets. A mode that could not have its targets chosen
## can't be chosen (CR 700.2a), and when only one mode can be, it is chosen without asking.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason


func test_casting_a_modal_spell_asks_for_its_mode_before_any_target() -> void:
	var engine: MmEngine = _engine(true)
	var charm: int = Scenario.card_in_hand(engine, engine.hero(), "Charm")

	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, charm)), "")

	var decision: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision
	assert_not_null(decision, "CR 601.2b: the mode is chosen first.")
	assert_eq(decision.modes, [0, 1])
	assert_eq(decision.stack_object_id, Scenario.stack_ids(engine)[0])
	assert_eq(Scenario.choose_mode(engine, 1), "")
	var targeting: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(targeting, "Then the chosen mode's target.")
	assert_eq(targeting.candidates.size(), 1, "Only the enchantment, as the second mode asks.")
	assert_eq(targeting.candidates[0].id, _glory(engine))


func test_the_mode_decision_lists_what_each_mode_could_target() -> void:
	var engine: MmEngine = _engine(true)
	var charm: int = Scenario.card_in_hand(engine, engine.hero(), "Charm")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, charm))

	var decision: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision
	var creatures: Array[int] = []
	for candidate: MmReference in decision.mode_targets[0]:
		creatures.append(candidate.id)
	assert_eq(creatures, [_bears(engine), _ogre(engine)])
	assert_eq(decision.mode_targets[1].size(), 1)
	assert_eq((decision.mode_targets[1][0] as MmReference).id, _glory(engine))


func test_a_mode_with_no_legal_target_is_left_out_and_the_only_other_is_chosen_without_asking() -> void:
	var engine: MmEngine = _engine(false)
	var charm: int = Scenario.card_in_hand(engine, engine.hero(), "Charm")

	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, charm)), "")

	assert_true(engine.pending_decision() is ChooseTargetDecision, "CR 700.2a: no enchantment, so only the first mode.")
	var on_stack: MmObjectView = _stack_view(engine, engine.hero())
	assert_eq(on_stack.chosen_mode, 0)


func test_a_modal_spell_with_no_mode_that_can_be_chosen_cannot_be_cast() -> void:
	var nothing: MmCardDefinition = Scenario.free_modal("Nothing", [
		Scenario.ability_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))], [Scenario.destroy(Scenario.targeted(0))]),
		Scenario.ability_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.ARTIFACT))], [Scenario.destroy(Scenario.targeted(0))]),
	])
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bears", 2, 2)], [], [nothing])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)

	var index: int = Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Nothing"))

	assert_eq(index, -1, "CR 700.2a: neither mode could have its target chosen.")


func test_only_the_chosen_modes_effects_happen() -> void:
	var engine: MmEngine = _engine(true)
	var glory: int = _glory(engine)

	assert_eq(Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Charm"), 1,
		[MmReference.to_object(glory)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Glory"])
	assert_eq(Scenario.damage_on(engine, _ogre(engine)), 0, "The damage mode was not chosen.")
	assert_eq(Scenario.damage_on(engine, _bears(engine)), 0)


func test_the_chosen_damage_mode_deals_its_damage() -> void:
	var engine: MmEngine = _engine(true)
	var ogre: int = _ogre(engine)

	Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Charm"), 0, [MmReference.to_object(ogre)])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.damage_on(engine, ogre), 2)
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Glory"), _glory(engine), "Glory is untouched.")


func test_a_modal_spell_whose_chosen_target_left_does_not_resolve() -> void:
	var engine: MmEngine = _engine(true)
	var hero: MmPlayer = engine.hero()
	var glory: MmReference = MmReference.to_object(_glory(engine))
	Scenario.cast_mode(engine, Scenario.card_in_hand(engine, hero, "Charm"), 1, [glory])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Disenchant"), [glory]), "")
	Scenario.resolve_stack(engine)

	assert_eq(_moves_with(engine, Reason.DID_NOT_RESOLVE).size(), 1, "CR 608.2b: its chosen mode's only target is gone.")


func test_canceling_after_choosing_a_mode_puts_the_card_back_in_hand() -> void:
	var engine: MmEngine = _engine(true)
	var charm: int = Scenario.card_in_hand(engine, engine.hero(), "Charm")
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, charm))
	Scenario.choose_mode(engine, 0)

	assert_eq(engine.cancel_cast(), "")

	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Charm"), -1)
	assert_true(engine.pending_decision() is PriorityDecision)
	assert_true(engine.game_state().stack.is_empty())


func test_the_chosen_mode_is_in_both_players_views() -> void:
	var engine: MmEngine = _engine(true)

	Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Charm"), 1,
		[MmReference.to_object(_glory(engine))])

	assert_eq(_stack_view(engine, engine.hero()).chosen_mode, 1)
	assert_eq(_stack_view(engine, engine.villain()).chosen_mode, 1, "CR 700.2: the mode is announced.")


func test_a_simulation_copy_keeps_the_chosen_mode() -> void:
	var engine: MmEngine = _engine(true)
	Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Charm"), 1,
		[MmReference.to_object(_glory(engine))])

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(7))
	Scenario.resolve_stack(copy)

	assert_eq(Scenario.names(copy, copy.villain().graveyard), ["Glory"], "The copy resolves the mode the original chose.")


func test_a_spell_that_is_not_modal_has_no_chosen_mode() -> void:
	var engine: MmEngine = _engine(true)

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Disenchant"), [MmReference.to_object(_glory(engine))])

	assert_eq(_stack_view(engine, engine.hero()).chosen_mode, SpellAbility.NO_MODE)


## The Hero's Bears and the Villain's Ogre (and its enchantment Glory, if
## [param with_enchantment]), in the Hero's postcombat main with Charm and Disenchant in hand.
func _engine(with_enchantment: bool) -> MmEngine:
	var villain: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	if with_enchantment:
		villain.append(Scenario.enchantment("Glory", []))
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bears", 2, 2)], villain,
		[Scenario.free_charm("Charm"), Scenario.free_disenchant("Disenchant")])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, MmTurn.Step.POSTCOMBAT_MAIN)
	return engine


func _bears(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Bears")


func _ogre(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.villain().id, "Ogre")


func _glory(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.villain().id, "Glory")


## [param player]'s view of the top of the stack.
func _stack_view(engine: MmEngine, player: MmPlayer) -> MmObjectView:
	return engine.view_for(player).stack.back()


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found
