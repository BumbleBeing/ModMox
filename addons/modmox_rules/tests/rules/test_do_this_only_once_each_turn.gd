extends GutTest
## Irreverent Gremlin's "Whenever another creature you control with power 2 or less enters,
## you may discard a card. If you do, draw a card. Do this only once each turn." The discard
## is a cost said yes to as it resolves (DiscardCardsCost, CR 701.9a, 118.3), so with no card
## in hand nothing is asked and nothing is drawn. "Do this only once each turn" is spent by a
## yes, not by triggering (engine ADR 0054's second addendum): declining leaves the ability
## for the next creature, and once it is done it triggers no more that turn, nor asks again
## from the stack. Gremlin is a 2/2 costing {0} with that ability; Bear a 2/2 costing {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Choice := ChooseYesOrNoDecision.Choice


func test_yes_discards_the_card_chosen_and_draws_a_card() -> void:
	var engine: MmEngine = _hero_main([_bear("Bear"), _bear("Cub")])
	var hand: int = engine.hero().hand.size()
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	var cub: int = Scenario.card_in_hand(engine, engine.hero(), "Cub")

	assert_eq(_answer_yes_discarding(engine, cub), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Cub"), -1, "The Cub was discarded.")
	assert_eq(engine.hero().hand.size(), hand - 2 + 1, "The Bear was cast and the Cub discarded; a card came.")


func test_once_done_it_triggers_no_more_that_turn() -> void:
	var engine: MmEngine = _hero_main([_bear("Bear"), _bear("Cub"), _bear("Pup")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(_answer_yes_discarding(engine, Scenario.card_in_hand(engine, engine.hero(), "Pup")), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var triggered: int = _gremlin_triggers(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Cub"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_gremlin_triggers(engine), triggered, "Done this turn, it does not trigger for the Cub.")


func test_declining_leaves_it_for_the_next_creature() -> void:
	var engine: MmEngine = _hero_main([_bear("Bear"), _bear("Cub")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")
	assert_eq(engine.submit(Choice.NO), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Cub")), "")

	assert_eq(Scenario.pass_to_yes_or_no(engine), "", "It triggered for the Cub and asks again.")


func test_a_second_trigger_waiting_on_the_stack_does_not_ask_once_it_is_done() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_tokens("Kits", Scenario.cat(), 2), _bear("Cub")])
	var hand: int = engine.hero().hand.size()
	assert_eq(Scenario.cast_and_resolve(engine, "Kits"), "")
	assert_eq(_gremlin_triggers(engine), 2, "Two Cats entered at once.")

	assert_eq(_answer_yes_discarding(engine, Scenario.card_in_hand(engine, engine.hero(), "Cub")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().hand.size(), hand - 1 - 1 + 1, "Kits cast and the Cub discarded; one card came, not two.")
	assert_false(engine.pending_decision() is ChooseYesOrNoDecision)


func test_it_triggers_again_in_a_later_turn() -> void:
	var engine: MmEngine = _hero_main([_bear("Bear"), _bear("Cub"), _bear("Pup")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(_answer_yes_discarding(engine, Scenario.card_in_hand(engine, engine.hero(), "Pup")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Cub")), "")

	assert_eq(Scenario.pass_to_yes_or_no(engine), "", "A new turn: it may be done again.")


func test_with_no_card_in_hand_nothing_is_asked_and_nothing_is_drawn() -> void:
	# Purge, an instant costing {0}, "Discard seven cards", empties the hand in answer to the
	# trigger.
	var purge: MmCardDefinition = Scenario.instant("Purge", Scenario.mana_cost(0), [], [Scenario.discard(7)])
	var engine: MmEngine = _hero_main([_bear("Bear"), purge])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Bear resolves.")
	assert_eq(_gremlin_triggers(engine), 1)

	assert_eq(Scenario.cast_and_resolve(engine, "Purge"), "")
	assert_eq(engine.hero().hand.size(), 0)
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().hand.size(), 0, "CR 118.3: no card to discard, so no card drawn.")


func test_the_discard_is_a_choice_of_the_cards_in_hand() -> void:
	var engine: MmEngine = _hero_main([_bear("Bear"), _bear("Cub"), _bear("Pup")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")

	assert_eq(engine.submit(Choice.YES), "")

	var discard: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(discard, "Yes asks which card to discard.")
	assert_eq(discard.count, 1)
	assert_eq(discard.candidate_ids, engine.hero().hand.object_ids(), "Any card in hand.")


func test_a_copy_and_a_replay_keep_it_done() -> void:
	var setup: MmEncounterSetup = _setup_of([_bear("Bear"), _bear("Cub")])
	var engine: MmEngine = _hero_main_from(setup, [_bear("Bear"), _bear("Cub")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(_answer_yes_discarding(engine, Scenario.card_in_hand(engine, engine.hero(), "Cub")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	var gremlin: int = Scenario.permanent_named(engine, engine.hero().id, "Gremlin")
	assert_true(copy.game_state().object(gremlin).has_triggered_in(0, engine.game_state().game_turn))
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_do_this_only_once_each_turn.tres"
	assert_eq(ResourceSaver.save(Scenario.gremlin(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var looting: MayPayEffect = (loaded.abilities[0] as TriggeredAbility).effects[0] as MayPayEffect
	assert_true(looting.is_once_each_turn)
	assert_eq((looting.cost as DiscardCardsCost).count, 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _bear(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


## Answers the Gremlin's question yes, discarding [param card_id].
func _answer_yes_discarding(engine: MmEngine, card_id: int) -> String:
	var error: String = Scenario.pass_to_yes_or_no(engine)
	if error != "":
		return error
	error = engine.submit(Choice.YES)
	if error != "":
		return error
	if engine.pending_decision() is ChooseCardsToDiscardDecision:
		return engine.submit([card_id])
	return ""


## How many times the Gremlin's ability has triggered.
func _gremlin_triggers(engine: MmEngine) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == "Gremlin":
			count += 1
	return count


func _setup_of(hand: Array[MmCardDefinition]) -> MmEncounterSetup:
	var gremlins: Array[MmCardDefinition] = [Scenario.gremlin()]
	return Scenario.combat_setup(gremlins, [] as Array[MmCardDefinition], hand)


## The Hero in their main phase of Game Turn 3 with the Gremlin cast on Game Turn 1,
## holding [param hand] among other cards.
func _hero_main(hand: Array[MmCardDefinition]) -> MmEngine:
	return _hero_main_from(_setup_of(hand), hand)


func _hero_main_from(setup: MmEncounterSetup, hand: Array[MmCardDefinition]) -> MmEngine:
	var gremlins: Array[MmCardDefinition] = [Scenario.gremlin()]
	var engine: MmEngine = Scenario.permanents_ready_with(setup, gremlins, [] as Array[MmCardDefinition], hand,
		[] as Array[MmCardDefinition], 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
