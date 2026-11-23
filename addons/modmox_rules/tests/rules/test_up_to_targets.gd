extends GutTest
## "Up to N target [things]" (CR 115.1d, 601.2c): one word "target" that chooses any number
## of different objects from none to N (CR 115.3), the effect applying to each one chosen.
## Choosing none is always possible, so it never keeps a spell from being cast or a trigger
## from going on the stack, and a spell that chose none resolves (CR 608.2b).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const PLUS: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_two_chosen_creatures_each_get_a_counter() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [], [Scenario.free_gird()])
	var bears: int = _hero_permanent(engine, "Bears")
	var lions: int = _hero_permanent(engine, "Lions")

	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_ref(bears), _ref(lions)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, bears, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, lions, PLUS), 1)


func test_one_chosen_creature_gets_a_counter() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [], [Scenario.free_gird()])
	var bears: int = _hero_permanent(engine, "Bears")
	var lions: int = _hero_permanent(engine, "Lions")

	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_ref(lions)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, bears, PLUS), 0)
	assert_eq(Scenario.counters_on(engine, lions, PLUS), 1)


func test_choosing_no_targets_resolves_and_does_nothing() -> void:
	var engine: MmEngine = _hero_main([_bears()], [], [Scenario.free_gird()])
	var bears: int = _hero_permanent(engine, "Bears")

	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), []), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, bears, PLUS), 0)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.RESOLVED,
		"CR 608.2b: it is not targeting anything, so it is not kept from resolving.")


func test_it_can_be_cast_with_nothing_to_target_once_choosing_none_is_confirmed() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_gird()])
	var gird: int = _hand(engine, "Gird")
	assert_true(Scenario.offers_cast(engine, gird), "CR 601.2c: none is a legal number of targets.")

	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, gird)), "")

	var choice: ChooseTargetsDecision = engine.pending_decision() as ChooseTargetsDecision
	assert_not_null(choice, "A spell's caster still confirms choosing none, and may cancel instead.")
	assert_eq(choice.candidates.size(), 0)
	assert_eq(Scenario.choose_targets(engine, []), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.stack_ids(engine).size(), 1)
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.RESOLVED)


func test_a_cast_with_nothing_to_target_can_be_canceled_at_its_choice() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_gird()])
	var gird: int = _hand(engine, "Gird")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, gird)), "")
	assert_true(engine.pending_decision() is ChooseTargetsDecision)

	assert_eq(engine.cancel_cast(), "")

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_true(Scenario.offers_cast(engine, _hand(engine, "Gird")), "CR 728: back in the hand, as before the cast.")


func test_the_choice_offers_every_creature_and_says_how_many() -> void:
	var engine: MmEngine = _hero_main([_bears()], [_bears("Ogre")], [Scenario.free_gird()])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(engine.submit(Scenario.cast_index(decision, _hand(engine, "Gird"))), "")

	var choice: ChooseTargetsDecision = engine.pending_decision() as ChooseTargetsDecision
	assert_not_null(choice)
	assert_eq(choice.most, 2)
	assert_eq(choice.target_index, 0)
	assert_eq(choice.candidates.size(), 2, "Either player's creature.")


func test_the_same_creature_cannot_be_chosen_twice_nor_more_than_two() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [_bears("Ogre")], [Scenario.free_gird()])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(engine.submit(Scenario.cast_index(decision, _hand(engine, "Gird"))), "")

	assert_ne(engine.submit([0, 0]), "", "CR 115.3: one word \"target\" can't choose the same object twice.")
	assert_ne(engine.submit([0, 1, 2]), "", "Up to two.")
	assert_ne(engine.submit([3]), "", "Not a candidate.")
	assert_ne(engine.submit(0), "", "A list, not a single choice.")
	assert_eq(engine.submit([2, 0]), "")


func test_a_target_that_left_is_skipped_and_the_other_still_gets_its_counter() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [], [Scenario.free_gird(), Scenario.free_destroy("Kill")])
	var bears: int = _hero_permanent(engine, "Bears")
	var lions: int = _hero_permanent(engine, "Lions")
	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_ref(bears), _ref(lions)]), "")

	assert_eq(Scenario.cast(engine, _hand(engine, "Kill"), [_ref(bears)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, lions, PLUS), 1)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.RESOLVED)


func test_it_does_not_resolve_when_every_chosen_target_left() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [],
		[Scenario.free_gird(), Scenario.free_destroy("Kill"), Scenario.free_destroy("Slay")])
	var bears: int = _hero_permanent(engine, "Bears")
	var lions: int = _hero_permanent(engine, "Lions")
	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_ref(bears), _ref(lions)]), "")

	assert_eq(Scenario.cast(engine, _hand(engine, "Kill"), [_ref(bears)]), "")
	assert_eq(Scenario.cast(engine, _hand(engine, "Slay"), [_ref(lions)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.DID_NOT_RESOLVE,
		"CR 608.2b: every target it chose is illegal.")


func test_a_requirement_after_one_that_chose_fewer_finds_its_own_target() -> void:
	var split: MmCardDefinition = Scenario.instant("Split", Scenario.mana_cost(0),
		[Scenario.up_to_targets(Scenario.of_type(CardType.CREATURE), 2), Scenario.target_player()],
		[Scenario.put_counters(PLUS, 1, Scenario.targeted(0)), Scenario.gain_life(3, Scenario.targeted(1))])
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [], [split])
	var lions: int = _hero_permanent(engine, "Lions")
	var life: int = engine.hero().life
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(engine.submit(Scenario.cast_index(decision, _hand(engine, "Split"))), "")

	assert_eq(Scenario.choose_targets(engine, [_ref(lions)]), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.hero().id)), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, lions, PLUS), 1)
	assert_eq(engine.hero().life, life + 3, "The second requirement's target is its own, after the first's two places.")


func test_a_requirement_before_one_keeps_its_target() -> void:
	var split: MmCardDefinition = Scenario.instant("Split", Scenario.mana_cost(0),
		[Scenario.target_player(), Scenario.up_to_targets(Scenario.of_type(CardType.CREATURE), 2)],
		[Scenario.gain_life(3, Scenario.targeted(0)), Scenario.put_counters(PLUS, 1, Scenario.targeted(1))])
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [], [split])
	var bears: int = _hero_permanent(engine, "Bears")
	var lions: int = _hero_permanent(engine, "Lions")
	var life: int = engine.hero().life
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(engine.submit(Scenario.cast_index(decision, _hand(engine, "Split"))), "")

	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.hero().id)), "")
	assert_eq(Scenario.choose_targets(engine, [_ref(bears), _ref(lions)]), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 3)
	assert_eq(Scenario.counters_on(engine, bears, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, lions, PLUS), 1)


func test_a_mode_with_up_to_targets_can_be_chosen_with_nothing_to_target() -> void:
	var charm: MmCardDefinition = Scenario.free_modal("Charm", [
		Scenario.ability_mode([Scenario.target(Scenario.of_type(CardType.ENCHANTMENT))], [Scenario.destroy(Scenario.targeted(0))]),
		Scenario.ability_mode([Scenario.up_to_targets(Scenario.of_type(CardType.CREATURE), 2)],
			[Scenario.put_counters(PLUS, 1, Scenario.targeted(0))]),
	])
	var engine: MmEngine = _hero_main([], [], [charm])
	var charm_id: int = _hand(engine, "Charm")

	assert_true(Scenario.offers_cast(engine, charm_id), "CR 700.2a: the second mode's targets can be chosen: none.")


func test_the_savior_offers_only_your_other_creatures() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [_bears("Ogre")], [Scenario.savior()])

	assert_eq(_cast_savior(engine), "")

	var choice: ChooseTargetsDecision = engine.pending_decision() as ChooseTargetsDecision
	assert_not_null(choice, "The enters trigger asks for its targets.")
	var offered: Array[int] = []
	for candidate: MmReference in choice.candidates:
		offered.append(candidate.id)
	offered.sort()
	var expected: Array[int] = [_hero_permanent(engine, "Bears"), _hero_permanent(engine, "Lions")]
	expected.sort()
	assert_eq(offered, expected, "Not the Savior itself, nor the Villain's Ogre.")


func test_the_saviors_trigger_puts_a_counter_on_each_chosen_creature() -> void:
	var engine: MmEngine = _hero_main([_bears(), _bears("Lions")], [], [Scenario.savior()])
	var bears: int = _hero_permanent(engine, "Bears")
	var lions: int = _hero_permanent(engine, "Lions")
	assert_eq(_cast_savior(engine), "")

	assert_eq(Scenario.choose_targets(engine, [_ref(bears), _ref(lions)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, bears, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, lions, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, _hero_permanent(engine, "Savior"), PLUS), 0)


func test_the_saviors_trigger_goes_on_the_stack_with_nothing_to_target() -> void:
	var engine: MmEngine = _hero_main([], [_bears("Ogre")], [Scenario.savior()])

	assert_eq(_cast_savior(engine), "")

	assert_true(engine.pending_decision() is PriorityDecision, "Nothing to choose, so nothing is asked.")
	assert_eq(Scenario.stacked_abilities(engine).size(), 1, "CR 603.3d does not remove it: none is a legal choice.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_true(engine.game_state().stack.is_empty())


func test_a_spell_choosing_the_heroic_creature_first_triggers_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic(), _bears()], [], [Scenario.free_gird()])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_heroic(engine), _ref(_hero_permanent(engine, "Bears"))]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 2, "The spell and one Heroic trigger.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 5)


func test_a_spell_choosing_the_heroic_creature_second_triggers_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic(), _bears()], [], [Scenario.free_gird()])

	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_ref(_hero_permanent(engine, "Bears")), _heroic(engine)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 2, "TargetsFilter sees every target of the one requirement.")


func test_a_spell_choosing_no_targets_does_not_trigger_heroic() -> void:
	var engine: MmEngine = _hero_main([Scenario.heroic()], [], [Scenario.free_gird()])

	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), []), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1)


func test_copies_and_replays_keep_the_chosen_targets() -> void:
	var setup: MmEncounterSetup = Scenario.combat_setup([_bears(), _bears("Lions")], [], [Scenario.free_gird()])
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [_bears(), _bears("Lions")], [], [Scenario.free_gird()], [],
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	var lions: int = _hero_permanent(engine, "Lions")
	assert_eq(Scenario.cast_up_to(engine, _hand(engine, "Gird"), [_ref(_hero_permanent(engine, "Bears")), _ref(lions)]), "")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_eq(Scenario.resolve_stack(copy), "")

	assert_eq(Scenario.counters_on(copy, lions, PLUS), 1)
	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())
	assert_eq(replayed.fingerprint(), engine.fingerprint())


## The Hero's first main phase of Game Turn 3, with [param hero_permanents] and
## [param villain_permanents] on the battlefield and [param hand] in the Hero's hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hand: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, [], 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## Casts the Savior and passes until it has resolved and its enters trigger is on the stack.
func _cast_savior(engine: MmEngine) -> String:
	var error: String = Scenario.cast(engine, _hand(engine, "Savior"))
	if error == "":
		error = Scenario.pass_priority(engine)
	if error == "":
		error = Scenario.pass_priority(engine)
	return error


func _bears(card_name: String = "Bears") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


func _hand(engine: MmEngine, card_name: String) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), card_name)


func _hero_permanent(engine: MmEngine, card_name: String) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, card_name)


func _heroic(engine: MmEngine) -> MmReference:
	return _ref(_hero_permanent(engine, "Hero"))


func _ref(object_id: int) -> MmReference:
	return MmReference.to_object(object_id)
