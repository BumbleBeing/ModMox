extends GutTest
## "As this land enters, you may pay 2 life. If you don't, it enters tapped." (CR 614.1c,
## 614.12), as on Temple Garden. Played, its controller is asked a ChooseYesOrNoDecision
## with an entry cost before it moves, while it is still in the hand, and the zone change
## carries the answer (ADR 0052). Paying life is losing it, and only a player with at least
## that much life can pay (CR 119.4). Entering any other way, nothing is asked and it enters
## tapped, as if the cost were declined (ADR 0001: no card can do that yet).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Reason := ZoneChangeEvent.Reason
const SHOCK := "Shock Forest Plains"
const YES := ChooseYesOrNoDecision.Choice.YES
const NO := ChooseYesOrNoDecision.Choice.NO


func test_playing_it_asks_its_controller_before_it_enters() -> void:
	var engine: MmEngine = _hero_main()
	var hero: MmPlayer = engine.hero()
	var in_hand: int = Scenario.card_in_hand(engine, hero, SHOCK)

	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, in_hand)), "")

	var asked: ChooseYesOrNoDecision = engine.pending_decision() as ChooseYesOrNoDecision
	assert_not_null(asked, "CR 614.12: asked before it enters.")
	assert_eq(asked.player_id, hero.id)
	assert_eq(asked.entering_object_id, in_hand)
	assert_true(asked.entry_cost is PayLifeCost)
	assert_eq((asked.entry_cost as PayLifeCost).amount, 2)
	assert_null(asked.cost, "Nothing to pay in mana.")
	assert_eq(asked.stack_object_id, 0, "Nothing on the stack asks it.")
	assert_eq(engine.game_state().object(in_hand).zone(), hero.hand, "It waits in the hand while asked.")
	assert_eq(Scenario.permanent_named(engine, hero.id, SHOCK), -1)


func test_paying_2_life_has_it_enter_untapped() -> void:
	var engine: MmEngine = _hero_main()
	var hero: MmPlayer = engine.hero()
	var life: int = hero.life
	_play_shock(engine)

	assert_eq(engine.submit(YES), "")

	var land: int = Scenario.permanent_named(engine, hero.id, SHOCK)
	assert_false(engine.game_state().object(land).is_tapped)
	assert_eq(hero.life, life - 2, "CR 119.4: paying life is losing it.")
	var log: Array[MmEvent] = engine.event_log()
	var lost_at: int = log.find(Scenario.events_of(engine, LifeLostEvent).back())
	var moved_at: int = log.find(_played(engine))
	assert_true(lost_at != -1 and lost_at < moved_at, "The life is paid as it enters, before the move.")
	assert_false(_played(engine).tapped_on_arrival)
	assert_true(_played(engine).entry_cost_paid)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, land), -1, "Its mana is there this turn.")


func test_not_paying_has_it_enter_tapped() -> void:
	var engine: MmEngine = _hero_main()
	var hero: MmPlayer = engine.hero()
	var life: int = hero.life
	_play_shock(engine)

	assert_eq(engine.submit(NO), "")

	var land: int = Scenario.permanent_named(engine, hero.id, SHOCK)
	assert_true(engine.game_state().object(land).is_tapped, "CR 614.1c")
	assert_eq(hero.life, life)
	assert_true(_played(engine).tapped_on_arrival)
	assert_eq(Scenario.events_of(engine, LifeLostEvent).size(), 0)


func test_after_answering_the_player_keeps_priority_with_no_land_play_left() -> void:
	var engine: MmEngine = _hero_main()
	var hero: MmPlayer = engine.hero()
	_play_shock(engine)

	assert_eq(engine.submit(YES), "")

	var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_not_null(priority, "CR 305.1: playing a land is a special action, and the player keeps priority.")
	assert_eq(priority.player_id, hero.id)
	assert_eq(priority.actions.filter(func(action: MmAction) -> bool: return action is PlayLandAction).size(), 0,
		"One land play a turn, used by this one.")


func test_with_less_life_than_the_cost_nothing_is_asked_and_it_enters_tapped() -> void:
	var engine: MmEngine = _hero_main(1)
	var hero: MmPlayer = engine.hero()
	assert_eq(hero.life, 1)

	_play_shock(engine)

	assert_true(engine.pending_decision() is PriorityDecision, "CR 119.4: 1 life can't pay 2.")
	assert_true(engine.game_state().object(Scenario.permanent_named(engine, hero.id, SHOCK)).is_tapped)
	assert_eq(hero.life, 1)


func test_with_exactly_the_cost_in_life_it_may_be_paid_and_the_player_loses() -> void:
	var engine: MmEngine = _hero_main(2)
	var hero: MmPlayer = engine.hero()
	_play_shock(engine)
	assert_true(engine.pending_decision() is ChooseYesOrNoDecision, "CR 119.4: 2 life can pay 2.")

	assert_eq(engine.submit(YES), "")

	assert_eq(hero.life, 0)
	assert_true(engine.is_over(), "CR 704.5a")
	assert_eq(engine.game_state().winner_id, engine.villain().id)


func test_an_answer_that_is_not_yes_or_no_is_refused() -> void:
	var engine: MmEngine = _hero_main()
	_play_shock(engine)

	assert_ne(engine.submit(2), "")

	assert_true(engine.pending_decision() is ChooseYesOrNoDecision)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, SHOCK), -1)


func test_a_copy_made_while_asked_answers_as_the_original_does() -> void:
	# A FULL Agent copies the encounter while the question waits.
	for answer: int in [YES, NO]:
		var engine: MmEngine = _hero_main()
		_play_shock(engine)
		var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

		assert_eq(copy.submit(answer), "")

		var land: int = Scenario.permanent_named(copy, copy.hero().id, SHOCK)
		assert_eq(copy.game_state().object(land).is_tapped, answer == NO)
		assert_eq(copy.hero().life, engine.hero().life - (2 if answer == YES else 0))
		assert_true(engine.pending_decision() is ChooseYesOrNoDecision, "The original still waits.")


func test_undo_takes_back_the_land_play() -> void:
	var engine: MmEngine = _hero_main()
	var hero: MmPlayer = engine.hero()
	_play_shock(engine)

	assert_eq(engine.undo(), "")

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_ne(Scenario.card_in_hand(engine, hero, SHOCK), -1)


func test_found_by_a_search_it_enters_tapped_and_nothing_is_asked() -> void:
	var engine: MmEngine = _hero_main(20, [Scenario.free_land_fetch()])
	var hero: MmPlayer = engine.hero()
	var life: int = hero.life

	assert_eq(Scenario.fetch_lands(engine, [SHOCK]), "")

	assert_true(engine.game_state().object(Scenario.permanent_named(engine, hero.id, SHOCK)).is_tapped,
		"Later: ask it however it enters, once a card can put one onto the battlefield.")
	assert_eq(hero.life, life)


func test_autoplay_declines_the_cost() -> void:
	var engine: MmEngine = _hero_main()
	_play_shock(engine)

	assert_eq(Scenario.default_answer(engine.pending_decision()), NO)


func _play_shock(engine: MmEngine) -> void:
	var in_hand: int = Scenario.card_in_hand(engine, engine.hero(), SHOCK)
	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, in_hand)), "")


func _played(engine: MmEngine) -> ZoneChangeEvent:
	var found: ZoneChangeEvent = null
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == Reason.PLAY_LAND:
			found = moved
	return found


## Stops in the Hero's precombat main phase of Game Turn 3 at [param life] life, with no
## land played this turn and a Shock Forest Plains and [param hero_extras] in hand. The
## Hero's library holds another Shock Forest Plains.
func _hero_main(life: int = 20, hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var in_hand: Array[MmCardDefinition] = [Scenario.shock_land("Forest", "Plains")]
	in_hand.append_array(hero_extras)
	var none: Array[MmCardDefinition] = []
	var deck: Array[MmCardDefinition] = in_hand.duplicate()
	deck.append(Scenario.shock_land("Forest", "Plains"))
	var setup: MmEncounterSetup = Scenario.combat_setup(none, none, deck)
	setup.hero.starting_life = life
	var engine: MmEngine = Scenario.permanents_ready_with(setup, none, none, in_hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
