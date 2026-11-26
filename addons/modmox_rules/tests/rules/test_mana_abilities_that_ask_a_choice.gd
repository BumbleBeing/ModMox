extends GutTest
## A mana ability whose cost asks a choice (CR 605.3a, 601.2h, engine ADR 0105), as Jaspera
## Sentinel's "{T}, Tap an untapped creature you control: Add one mana of any color." It is
## offered once for each color (ADR 0072), and once one is chosen the player picks which
## creature to tap; then it is paid and resolves at once, without the stack, at priority or
## in the middle of paying for a spell. Its own {T} pays once (CR 107.5), so it never taps
## itself for the second cost, and a creature with summoning sickness may be tapped for it
## (CR 302.6). Sentinel is a 1/2 costing {0} with that ability; Bear a 2/2 and Elf a 1/1
## with "{T}: Add {W}", each costing {0}; Growth an instant costing {G} and Twin one
## costing {W}{G}, each "You gain 1 life".

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const GREEN := MmMana.Type.GREEN
const WHITE := MmMana.Type.WHITE


func test_activating_it_asks_which_other_untapped_creature_to_tap() -> void:
	var engine: MmEngine = _hero_main([Scenario.sentinel(), _bear()])
	var sentinel: int = _named(engine, "Sentinel")
	var bear: int = _named(engine, "Bear")

	assert_eq(Scenario.activate_for(engine, sentinel, GREEN), "")

	var pick: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(pick, "CR 601.2h: the creature to tap is chosen as it is activated.")
	assert_eq(pick.candidate_ids, [bear] as Array[int], "CR 107.5: its own {T} pays once.")
	assert_eq([pick.count, pick.purpose, pick.is_for_mana_ability], [1, ChoosePermanentsDecision.Purpose.TAP, true])
	assert_eq(pick.stack_object_id, sentinel, "Nothing is on the stack: it names its source.")
	assert_true(engine.is_casting(), "It can be taken back until it is paid.")


func test_once_the_creature_is_chosen_both_tap_and_the_mana_is_added_without_the_stack() -> void:
	# CR 605.3a: it resolves at once, and the player keeps priority.
	var engine: MmEngine = _hero_main([Scenario.sentinel(), _bear()])
	var sentinel: int = _named(engine, "Sentinel")
	var bear: int = _named(engine, "Bear")
	Scenario.activate_for(engine, sentinel, GREEN)

	assert_eq(engine.submit([bear]), "")

	assert_true(_is_tapped(engine, sentinel))
	assert_true(_is_tapped(engine, bear))
	assert_eq(_pool(engine), [GREEN] as Array[MmMana.Type])
	assert_true(engine.game_state().stack.is_empty())
	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_false(engine.is_casting())


func test_it_is_not_offered_without_another_untapped_creature() -> void:
	var engine: MmEngine = _hero_main([Scenario.sentinel()])

	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(Scenario.colors_offered(decision.actions, _named(engine, "Sentinel")), [] as Array[int])


func test_a_creature_with_summoning_sickness_may_be_tapped_for_it() -> void:
	# CR 302.6: tapping it for the cost is not its {T}.
	var engine: MmEngine = _hero_main([Scenario.sentinel()], [Scenario.creature("Late", 1, 1)])
	assert_eq(Scenario.cast_and_resolve(engine, "Late"), "")
	var late: int = _named(engine, "Late")

	assert_eq(Scenario.activate_for(engine, _named(engine, "Sentinel"), WHITE), "")

	assert_eq((engine.pending_decision() as ChoosePermanentsDecision).candidate_ids, [late] as Array[int])
	assert_eq(engine.submit([late]), "")
	assert_eq(_pool(engine), [WHITE] as Array[MmMana.Type])


func test_it_pays_for_a_spell_once_the_creature_is_chosen() -> void:
	var engine: MmEngine = _hero_main([Scenario.sentinel(), _bear()], [_growth()])
	var sentinel: int = _named(engine, "Sentinel")
	var bear: int = _named(engine, "Bear")
	assert_eq(_begin_cast(engine, "Growth"), "")

	assert_eq(Scenario.pay_for(engine, sentinel, GREEN), "")
	assert_true(engine.pending_decision() is ChoosePermanentsDecision, "CR 605.3a: in the middle of paying.")
	assert_eq(engine.submit([bear]), "")

	assert_true(_is_tapped(engine, bear))
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Growth"] as Array[String])
	assert_eq(_pool(engine), [] as Array[MmMana.Type], "The green paid for Growth.")
	assert_true(engine.pending_decision() is PriorityDecision)


func test_it_pays_a_cost_said_yes_to_as_a_spell_resolves() -> void:
	# ADR 0076's addendum: "you may pay {G}" is paid one step at a time, as a cast's mana is.
	var offer: MmCardDefinition = Scenario.instant("Offer", Scenario.mana_cost(0), [],
		[Scenario.may_pay_mana(Scenario.mana_cost(0, [GREEN]), Scenario.gain_life(3, Scenario.you()))])
	var engine: MmEngine = _hero_main([Scenario.sentinel(), _bear()], [offer])
	var bear: int = _named(engine, "Bear")
	var life: int = engine.hero().life
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Offer")), "")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")

	assert_eq(Scenario.pay_for(engine, _named(engine, "Sentinel"), GREEN), "")
	assert_true(engine.pending_decision() is ChoosePermanentsDecision)
	assert_eq(engine.submit([bear]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_is_tapped(engine, bear))
	assert_eq(engine.hero().life, life + 3)


func test_a_cost_it_could_pay_only_by_tapping_a_mana_source_it_also_needs_cannot_be_cast() -> void:
	# The Elf makes {W} or is tapped for the Sentinel's green, never both.
	var engine: MmEngine = _hero_main([Scenario.sentinel(), Scenario.elf()], [_twin(), _growth()])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Twin")))
	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Growth")),
		"The Sentinel may tap the Elf for green.")


func test_with_another_creature_to_tap_both_pay() -> void:
	var engine: MmEngine = _hero_main([Scenario.sentinel(), Scenario.elf(), _bear()], [_twin()])
	var bear: int = _named(engine, "Bear")
	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Twin")))
	assert_eq(_begin_cast(engine, "Twin"), "")

	assert_eq(Scenario.pay_for(engine, _named(engine, "Sentinel"), GREEN), "")
	assert_eq(engine.submit([bear]), "")
	assert_eq(Scenario.auto_pay(engine), "")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Twin"] as Array[String])
	assert_true(_is_tapped(engine, _named(engine, "Elf")))


func test_canceling_the_choice_puts_everything_back() -> void:
	var engine: MmEngine = _hero_main([Scenario.sentinel(), _bear()])
	var sentinel: int = _named(engine, "Sentinel")
	Scenario.activate_for(engine, sentinel, GREEN)

	assert_eq(engine.cancel_cast(), "")

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_false(_is_tapped(engine, sentinel))
	assert_eq(_pool(engine), [] as Array[MmMana.Type])


func test_a_copy_made_during_the_choice_finishes_it_alike() -> void:
	var engine: MmEngine = _hero_main([Scenario.sentinel(), _bear()], [_growth()])
	var sentinel: int = _named(engine, "Sentinel")
	var bear: int = _named(engine, "Bear")
	_begin_cast(engine, "Growth")
	Scenario.pay_for(engine, sentinel, GREEN)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)

	assert_true(copy.pending_decision() is ChoosePermanentsDecision, "The copy waits for the choice too.")

	assert_eq(copy.submit([bear]), "")

	assert_true(_is_tapped(copy, bear))
	assert_eq(Scenario.names(copy, copy.game_state().stack), ["Growth"] as Array[String])
	assert_false(_is_tapped(engine, bear), "The original still waits.")
	assert_eq(engine.submit([bear]), "")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Growth"] as Array[String])


func test_a_replay_through_the_choice_is_exact() -> void:
	var hero_permanents: Array[MmCardDefinition] = [Scenario.sentinel(), _bear()]
	var extras: Array[MmCardDefinition] = [_growth()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	_begin_cast(engine, "Growth")
	Scenario.pay_for(engine, _named(engine, "Sentinel"), GREEN)
	engine.submit([_named(engine, "Bear")])

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _growth() -> MmCardDefinition:
	return Scenario.instant("Growth", Scenario.mana_cost(0, [GREEN]), [], [Scenario.gain_life(1, Scenario.you())])


func _twin() -> MmCardDefinition:
	return Scenario.instant("Twin", Scenario.mana_cost(0, [WHITE, GREEN]), [], [Scenario.gain_life(1, Scenario.you())])


## Casts the card named [param card_name] from the Hero's hand and stops at its payment.
func _begin_cast(engine: MmEngine, card_name: String) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	return engine.submit(Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), card_name)))


func _named(engine: MmEngine, card_name: String) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, card_name)


func _is_tapped(engine: MmEngine, object_id: int) -> bool:
	return engine.game_state().object(object_id).is_tapped


func _pool(engine: MmEngine) -> Array[MmMana.Type]:
	var types: Array[MmMana.Type] = []
	for unit: MmMana in engine.hero().mana_pool():
		types.append(unit.type)
	return types


## The Hero's main phase on Game Turn 3 with [param permanents] in play and [param extras]
## in hand, and no lands.
func _hero_main(permanents: Array[MmCardDefinition], extras: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(permanents, no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, permanents, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
