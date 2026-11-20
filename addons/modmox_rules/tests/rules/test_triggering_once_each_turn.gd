extends GutTest
## "This ability triggers only once each turn" (ADR 0054's addendum), on Tocasia's Welcome:
## "Whenever one or more creatures you control with mana value 3 or less enter, draw a card.
## This ability triggers only once each turn." Once a limited ability of an object has
## triggered in a turn, its trigger event does nothing more that turn, even several events at
## once, so triggering for each creature plays as "one or more" does. Its source keeps the
## mark by Game Turn, so a permanent that leaves and returns is a new object that may
## trigger again (ADR 0008). Welcome is an enchantment costing {0} with that ability; every
## creature here costs {0}, so its mana value is 0.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_the_first_creature_to_enter_triggers_it_and_the_second_that_turn_does_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome()], [_bear(), _bear("Second Bear")])
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Bear"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Welcome"), 1)
	assert_eq(engine.hero().hand.size(), hand, "It drew a card for the Bear it cast.")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Bear"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Welcome"), 1, "Only once this turn.")
	assert_eq(engine.hero().hand.size(), hand - 1, "No card for the second.")


func test_creatures_entering_together_trigger_it_once() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome()], [Scenario.free_tokens("Cats", Scenario.cat(), 2)])

	assert_eq(Scenario.cast_and_resolve(engine, "Cats"), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 2)
	assert_eq(Scenario.stacked_abilities(engine).size(), 1, "One trigger for both Cats.")
	assert_eq(_triggers_of(engine, "Welcome"), 1)


func test_it_triggers_again_in_the_next_turn_the_other_players_too() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome()], [_bear(), Scenario.free_tokens("Cats", Scenario.cat())])
	Scenario.cast_and_resolve(engine, "Bear")
	Scenario.resolve_stack(engine)

	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain, as the active player, has it first.
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id)
	assert_eq(Scenario.cast_and_resolve(engine, "Cats"), "")

	assert_eq(_triggers_of(engine, "Welcome"), 2, "Once in the Villain's turn as well.")


func test_a_permanent_its_filter_refuses_does_not_spend_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome()], [Scenario.artifact("Trinket", []), _bear()])

	Scenario.cast_and_resolve(engine, "Trinket")
	Scenario.resolve_stack(engine)
	assert_eq(_triggers_of(engine, "Welcome"), 0, "An artifact is not a creature.")
	Scenario.cast_and_resolve(engine, "Bear")

	assert_eq(_triggers_of(engine, "Welcome"), 1)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.stacked_abilities(engine)[0].triggering_object_id, bear)


func test_a_match_its_intervening_if_refuses_does_not_spend_it() -> void:
	# CR 603.4: an ability whose "if" is false never triggered.
	var engine: MmEngine = _hero_main([_bear_welcome()], [Scenario.elf(), _bear()])

	Scenario.cast_and_resolve(engine, "Elf")
	Scenario.resolve_stack(engine)
	assert_eq(_triggers_of(engine, "Bear Welcome"), 0, "The Elf is not a Bear.")
	Scenario.cast_and_resolve(engine, "Bear")

	assert_eq(_triggers_of(engine, "Bear Welcome"), 1)


func test_a_trigger_that_is_countered_still_spends_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome()], [_bear(), _bear("Second Bear"), Scenario.free_stifle("Stifle")])
	Scenario.cast_and_resolve(engine, "Bear")
	var hand: int = engine.hero().hand.size()

	var stifle: int = Scenario.card_in_hand(engine, engine.hero(), "Stifle")
	assert_eq(Scenario.cast(engine, stifle, [MmReference.to_object(Scenario.stack_ids(engine)[0])]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().hand.size(), hand - 1, "Stifle went, and no card was drawn.")
	Scenario.cast_and_resolve(engine, "Second Bear")
	Scenario.resolve_stack(engine)

	assert_eq(_triggers_of(engine, "Welcome"), 1, "It triggered, so it is Spent.")


func test_two_permanents_with_it_each_trigger_once() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome(), Scenario.welcome("Second Welcome")], [_bear(), _bear("Second Bear")])

	Scenario.cast_and_resolve(engine, "Bear")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Second Bear")
	Scenario.resolve_stack(engine)

	assert_eq(_triggers_of(engine, "Welcome"), 1)
	assert_eq(_triggers_of(engine, "Second Welcome"), 1, "Each is Spent on its own object.")


func test_one_that_leaves_and_returns_is_a_new_object_that_may_trigger_again() -> void:
	# ADR 0008: the mark was on the object that left.
	var engine: MmEngine = _hero_main([Scenario.welcome()], [_bear(), _bear("Second Bear"), _unwelcome()])
	var welcome: int = Scenario.permanent_named(engine, engine.hero().id, "Welcome")
	Scenario.cast_and_resolve(engine, "Bear")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Unwelcome", [MmReference.to_object(welcome)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Welcome"), "")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Welcome"), welcome)
	Scenario.cast_and_resolve(engine, "Second Bear")

	assert_eq(_triggers_of(engine, "Welcome"), 2)


func test_a_leaves_the_battlefield_trigger_whose_source_leaves_with_the_others_triggers_once() -> void:
	# CR 603.10a: it looks back, and sees both other creatures die beside it.
	var engine: MmEngine = _hero_main([_opportunist(), _bear(), _bear("Second Bear")], [_wrath()])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Wrath"), "")
	assert_eq(_triggers_of(engine, "Opportunist"), 1)
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1)


func test_the_views_copies_and_replays_know_it_has_triggered_this_turn() -> void:
	var engine: MmEngine = _hero_main([Scenario.welcome()], [_bear()])
	var welcome: int = Scenario.permanent_named(engine, engine.hero().id, "Welcome")
	assert_eq(_welcome_view(engine, engine.view_for(engine.hero())).triggered_this_turn.size(), 0)
	Scenario.cast_and_resolve(engine, "Bear")
	Scenario.resolve_stack(engine)

	var mine: MmObjectView = _welcome_view(engine, engine.view_for(engine.hero()))
	var theirs: MmObjectView = _welcome_view(engine, engine.view_for(engine.villain()))
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(mine.triggered_this_turn, [0] as Array[int])
	assert_eq(theirs.triggered_this_turn, [0] as Array[int], "Public, like the permanent.")
	assert_true(copy.game_state().object(welcome).has_triggered_in(0, copy.game_state().game_turn))
	assert_eq(replayed.fingerprint(), engine.fingerprint())
	Scenario.play_until_game_turn(engine, 4)
	assert_eq(_welcome_view(engine, engine.view_for(engine.hero())).triggered_this_turn.size(), 0, "Not this turn.")


## A 2/2 creature costing {0}.
func _bear(card_name: String = "Bear") -> MmCardDefinition:
	return Scenario.typed_creature(card_name, 2, 2, ["Bear"])


## An enchantment costing {0}: "Whenever a creature you control enters, if that creature is
## a Bear, draw a card. This ability triggers only once each turn."
func _bear_welcome() -> MmCardDefinition:
	var is_bear: SelectionMatchesCondition = Scenario.condition(TriggeringObjectSelection.new(), Scenario.has_subtype("Bear"))
	var ability: TriggeredAbility = Scenario.triggered(Scenario.enters(Scenario.of_type(CardType.CREATURE), MmTrigger.Whose.YOU),
		[Scenario.draw_cards(1, Scenario.you())], [], is_bear)
	return Scenario.enchantment("Bear Welcome", [Scenario.once_each_turn(ability)])


## Morbid Opportunist's ability on a 2/2 costing {0}, gaining 1 life: "Whenever one or more
## other creatures die, you gain 1 life. This ability triggers only once each turn."
func _opportunist() -> MmCardDefinition:
	var others: AllOfFilter = Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.is_not(IsSourceFilter.new())])
	var ability: TriggeredAbility = Scenario.triggered(Scenario.dies(others), [Scenario.gain_life(1, Scenario.you())])
	return Scenario.creature("Opportunist", 2, 2, [Scenario.once_each_turn(ability)])


## An instant costing {0}: "Return target enchantment to its owner's hand."
func _unwelcome() -> MmCardDefinition:
	return Scenario.instant("Unwelcome", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.ENCHANTMENT))],
		[Scenario.return_to_hand(Scenario.targeted(0))])


## An instant costing {0}: "Destroy all creatures."
func _wrath() -> MmCardDefinition:
	return Scenario.instant("Wrath", Scenario.mana_cost(0), [], [Scenario.destroy(Scenario.each_creature())])


## How many times an ability of a permanent named [param card_name] has triggered.
func _triggers_of(engine: MmEngine, card_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == card_name:
			count += 1
	return count


## The Hero's Welcome as [param view] shows it.
func _welcome_view(engine: MmEngine, view: MmPlayerView) -> MmObjectView:
	var welcome: int = Scenario.permanent_named(engine, engine.hero().id, "Welcome")
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == welcome:
			return permanent
	return null


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand].
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
