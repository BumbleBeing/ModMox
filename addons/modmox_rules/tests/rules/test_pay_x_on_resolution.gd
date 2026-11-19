extends GutTest
## "You may pay {X}. If you do, [effect]." (CR 107.3, 605.3a, 608.2d, ADR 0061): as the
## effect begins its controller chooses X, up to what they could pay, or declines. X is
## paid one PayManaDecision at a time, as a cast's mana is, mana abilities included, and
## then the effect it wraps begins, reading X, as does every later effect of the ability.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_trigger_asks_its_controller_how_much_x_to_pay_as_it_resolves() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])

	assert_eq(_payer_asked(engine), "")

	var asked: ChooseXToPayDecision = engine.pending_decision() as ChooseXToPayDecision
	assert_not_null(asked, "CR 608.2d: asked as the effect begins.")
	assert_eq(asked.player_id, engine.hero().id, "Its controller answers.")
	assert_eq(asked.most, 3, "The Mana Bird makes three: the most X that could be paid.")
	assert_true(engine.game_state().object(asked.stack_object_id).ability is TriggeredAbility)
	assert_true(asked.effect is GainLifeEffect, "What paying does.")


func test_paying_x_asks_for_that_much_mana_and_the_effect_reads_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var life_before: int = engine.hero().life
	assert_eq(_payer_asked(engine), "")

	assert_eq(Scenario.choose_x(engine, 2), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying, "X is paid as a cast's mana is.")
	assert_eq(paying.remaining_generic, 2)
	assert_eq(engine.hero().life, life_before, "Nothing happens until X is paid.")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(engine.hero().life, life_before + 2)
	assert_true(engine.game_state().object(bird).is_tapped, "CR 605.3a: a mana ability pays mid-resolution.")
	assert_eq(engine.hero().mana_pool().size(), 1, "The third mana was not needed and stays.")
	assert_true(engine.game_state().stack.is_empty())


func test_declining_pays_nothing_and_does_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var life_before: int = engine.hero().life
	assert_eq(_payer_asked(engine), "")
	var trigger: int = (engine.pending_decision() as ChooseXToPayDecision).stack_object_id

	assert_eq(engine.submit(ChooseXToPayDecision.DECLINE), "")

	assert_false(engine.pending_decision() is PayManaDecision)
	assert_eq(engine.hero().life, life_before)
	assert_false(engine.game_state().object(bird).is_tapped)
	var left: AbilityLeftStackEvent = _left_stack(engine, trigger)
	assert_not_null(left)
	assert_true(left.did_resolve, "Declining is not failing to resolve.")


func test_a_search_it_wraps_is_asked_once_x_is_paid_and_finds_up_to_x() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], _x_seeker())
	assert_eq(_payer_asked(engine), "")

	assert_eq(Scenario.choose_x(engine, 2), "")
	assert_false(engine.pending_decision() is ChooseCardsInLibraryDecision, "Paid for first.")
	assert_eq(Scenario.auto_pay(engine), "")

	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_not_null(search, "The search it wraps asks its own decision once X is paid.")
	assert_eq(search.most, 2, "It reads the X paid.")


func test_a_search_for_a_card_with_mana_value_x_or_less_offers_only_those_the_x_paid_reaches() -> void:
	# As Taj-Nar Swordsmith: "... search your library for an Equipment card with mana value
	# X or less, put that card onto the battlefield, then shuffle."
	var two: MmCardDefinition = Scenario.creature("Two", 2, 2, [], Scenario.mana_cost(2))
	var four: MmCardDefinition = Scenario.creature("Four", 4, 4, [], Scenario.mana_cost(4))
	var seeking: SearchLibraryEffect = Scenario.search(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE),
		Scenario.mana_value_from(Scenario.paid_x())]), 1, MmZone.Kind.BATTLEFIELD, false)
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], Scenario.x_payer("X Payer", seeking), [two, four])
	assert_eq(_payer_asked(engine), "")

	assert_eq(Scenario.choose_x(engine, 2), "")
	assert_eq(Scenario.auto_pay(engine), "")

	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_not_null(search)
	var offered: Array[String] = []
	for id: int in search.candidate_ids:
		var card: MmCharacteristics = engine.game_state().characteristics_of(engine.game_state().object(id))
		assert_lte(card.mana_value(), 2)
		offered.append(card.name)
	assert_true(offered.has("Two"), "Mana value 2 is X or less.")
	assert_false(offered.has("Four"))


func test_paying_x_of_zero_is_paying() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], _x_seeker())
	assert_eq(_payer_asked(engine), "")
	var shuffles_before: int = _shuffles_of(engine, engine.hero().id)

	assert_eq(Scenario.choose_x(engine, 0), "")

	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	assert_not_null(search, "No mana is asked, and the search still happens.")
	assert_eq(search.most, 0)
	assert_eq(engine.submit([]), "")
	assert_eq(_shuffles_of(engine, engine.hero().id), shuffles_before + 1, "So the library is shuffled.")


func test_declining_a_search_it_wraps_neither_searches_nor_shuffles() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], _x_seeker())
	assert_eq(_payer_asked(engine), "")
	var shuffles_before: int = _shuffles_of(engine, engine.hero().id)

	assert_eq(engine.submit(ChooseXToPayDecision.DECLINE), "")

	assert_false(engine.pending_decision() is ChooseCardsInLibraryDecision)
	assert_eq(_shuffles_of(engine, engine.hero().id), shuffles_before)


func test_with_no_mana_only_declining_or_x_of_zero_may_be_answered() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main(no_creatures)
	assert_eq(_payer_asked(engine), "")
	var asked: ChooseXToPayDecision = engine.pending_decision() as ChooseXToPayDecision

	assert_eq(asked.most, 0)
	assert_ne(Scenario.choose_x(engine, 1), "", "One mana cannot be paid.")
	assert_eq(engine.pending_decision(), asked, "Still asked.")
	assert_eq(Scenario.choose_x(engine, 0), "")


func test_an_answer_above_the_most_or_not_a_number_is_refused() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	assert_eq(_payer_asked(engine), "")
	var asked: MmPendingDecision = engine.pending_decision()

	assert_ne(Scenario.choose_x(engine, 4), "")
	assert_ne(engine.submit(-1), "")
	assert_ne(engine.submit([2]), "")

	assert_eq(engine.pending_decision(), asked, "Still asked.")
	assert_false(engine.game_state().object(bird).is_tapped)


func test_the_mana_in_the_pool_counts_toward_the_most() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], Scenario.x_payer(), [_free_ritual()])

	assert_eq(Scenario.cast_and_resolve(engine, "Ritual"), "")
	assert_eq(_payer_asked(engine), "")

	assert_eq((engine.pending_decision() as ChooseXToPayDecision).most, 5, "Two in the pool and three from the Bird.")


func test_later_effects_of_the_ability_read_the_x_paid() -> void:
	var after: Array[MmEffect] = [Scenario.gain_x_life()]
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], Scenario.x_payer("X Payer", null, after))
	var life_before: int = engine.hero().life
	assert_eq(_payer_asked(engine), "")

	assert_eq(Scenario.choose_x(engine, 3), "")
	assert_eq(Scenario.auto_pay(engine), "")

	assert_eq(engine.hero().life, life_before + 6, "X life, then X life again.")


func test_x_is_zero_for_later_effects_once_declined() -> void:
	var after: Array[MmEffect] = [Scenario.gain_x_life(), Scenario.gain_life(1, Scenario.you())]
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], Scenario.x_payer("X Payer", null, after))
	var life_before: int = engine.hero().life
	assert_eq(_payer_asked(engine), "")

	assert_eq(engine.submit(ChooseXToPayDecision.DECLINE), "")

	assert_eq(engine.hero().life, life_before + 1, "Nothing paid is 0, and the effects after still happen.")


func test_a_copy_made_while_x_is_being_paid_carries_on_alike() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird()])
	assert_eq(_payer_asked(engine), "")
	assert_eq(Scenario.choose_x(engine, 2), "")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)

	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.auto_pay(copy), "")

	assert_eq(copy.hero().life, engine.hero().life)
	assert_eq(copy.hero().mana_pool().size(), engine.hero().mana_pool().size())


func test_replaying_the_decision_log_gives_the_same_game() -> void:
	# ADR 0010: the X chosen is a plain int in the decision log.
	var setup: MmEncounterSetup = _setup([Scenario.mana_bird()], Scenario.x_payer())
	var engine: MmEngine = _engine_ready(setup, [Scenario.mana_bird()], Scenario.x_payer())
	assert_eq(_payer_asked(engine), "")
	assert_eq(Scenario.choose_x(engine, 2), "")
	assert_eq(Scenario.auto_pay(engine), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_reaches_what_it_affects_through_the_effect_it_wraps() -> void:
	var tap: TapEffect = Scenario.tap(Scenario.targeted(0))
	var paying: MayPayXEffect = Scenario.pay_x(tap)

	assert_eq(paying.selections(), tap.selections())
	assert_true(paying.has_targets())
	assert_false(paying.adds_mana())


func test_paid_x_is_zero_in_a_context_with_none_paid() -> void:
	var context: MmEffectContext = MmEffectContext.new(1, 0)

	assert_eq(context.paid_x, MmEffectContext.NONE_PAID)
	assert_eq(Scenario.paid_x().evaluate(null, context), 0)
	assert_eq(Scenario.paid_x().evaluate(null, null), 0, "A static ability's Filter may be asked with no context.")
	assert_eq(Scenario.paid_x().evaluate(null, context.with_paid_x(4)), 4)
	assert_eq(context.with_paid_x(4).with_choice(0, null).paid_x, 4, "A choice keeps the X paid.")


## Casts the Hero's X Payer and passes until how much X to pay is asked.
func _payer_asked(engine: MmEngine) -> String:
	var error: String = Scenario.cast_and_resolve(engine, "X Payer")
	return error if error != "" else Scenario.pass_to_x_choice(engine)


## "When this creature enters, you may pay {X}. If you do, search your library for up to X
## creature cards, reveal them, put them into your hand, then shuffle."
func _x_seeker() -> MmCardDefinition:
	var seeking: SearchLibraryEffect = Scenario.search(Scenario.of_type(MmCardTypes.CardType.CREATURE))
	seeking.amount = Scenario.paid_x()
	return Scenario.x_payer("X Payer", seeking)


## An instant costing {0}: "Add {W}{W}."
func _free_ritual() -> MmCardDefinition:
	return Scenario.instant("Ritual", Scenario.mana_cost(0), [], [Scenario.add_mana(MmMana.Type.WHITE, 2)])


func _left_stack(engine: MmEngine, object_id: int) -> AbilityLeftStackEvent:
	for event: MmEvent in Scenario.events_of(engine, AbilityLeftStackEvent):
		if (event as AbilityLeftStackEvent).object_id == object_id:
			return event as AbilityLeftStackEvent
	return null


func _shuffles_of(engine: MmEngine, player_id: int) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, ShuffleEvent):
		var shuffle: ShuffleEvent = event as ShuffleEvent
		if shuffle.zone_kind == MmZone.Kind.LIBRARY and shuffle.owner_id == player_id:
			count += 1
	return count


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


## The Hero's [param hero_creatures] and the Villain's Ogre on the battlefield, in the
## Hero's main phase of Game Turn 3 with [param payer] (an X Payer unless given) and
## [param more] in hand.
func _hero_main(hero_creatures: Array[MmCardDefinition], payer: MmCardDefinition = null,
		more: Array[MmCardDefinition] = []) -> MmEngine:
	var paying: MmCardDefinition = payer if payer != null else Scenario.x_payer()
	return _engine_ready(_setup(hero_creatures, paying, more), hero_creatures, paying, more)


func _setup(hero_creatures: Array[MmCardDefinition], payer: MmCardDefinition,
		more: Array[MmCardDefinition] = []) -> MmEncounterSetup:
	var extras: Array[MmCardDefinition] = [payer]
	extras.append_array(more)
	var hero_cards: Array[MmCardDefinition] = hero_creatures.duplicate()
	if hero_cards.is_empty():
		hero_cards.append(Scenario.creature("Bear", 2, 2))  # Never cast: the deck is not only X Payers.
	return Scenario.combat_setup(hero_cards, [_ogre()], extras)


func _engine_ready(setup: MmEncounterSetup, hero_creatures: Array[MmCardDefinition], payer: MmCardDefinition,
		more: Array[MmCardDefinition] = []) -> MmEngine:
	var extras: Array[MmCardDefinition] = [payer]
	extras.append_array(more)
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, [_ogre()], extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
