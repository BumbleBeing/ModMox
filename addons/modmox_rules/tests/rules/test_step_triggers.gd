extends GutTest
## CR 603: "at the beginning of" triggers wait until a player would receive priority, then
## go on the stack (CR 603.3). CR 603.4: an intervening "if" is checked when it triggers and
## again on resolution.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_a_your_upkeep_trigger_goes_on_the_stack_and_resolves() -> void:
	var chime: MmCardDefinition = _chime(Whose.YOU, Scenario.you())
	var engine: MmEngine = _hero_casts_on_turn_one(chime)
	var chime_id: int = Scenario.permanent_named(engine, engine.hero().id, "Chime")

	Scenario.play_until_step(engine, 2, Step.UPKEEP)
	assert_eq(engine.game_state().stack.size(), 0, "Not on the opponent's upkeep.")
	Scenario.play_until_step(engine, 3, Step.UPKEEP)

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].controller_id, engine.hero().id, "CR 603.3a: its source's controller controls it.")
	assert_eq(stacked[0].source_object_id, chime_id)
	assert_eq(stacked[0].source_card_id, engine.game_state().object(chime_id).card_id, "A105: it knows its card.")
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id)
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, 21)


func test_an_each_players_upkeep_trigger_reaches_that_player() -> void:
	var chime: MmCardDefinition = _chime(Whose.ANY, TriggeringPlayerSelection.new())
	var engine: MmEngine = _hero_casts_on_turn_one(chime)

	Scenario.play_until_step(engine, 2, Step.UPKEEP)
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 21, "That player: the one whose upkeep it is.")
	assert_eq(engine.hero().life, 20)


func test_an_each_opponents_upkeep_trigger_ignores_your_own() -> void:
	var chime: MmCardDefinition = _chime(Whose.OPPONENT, TriggeringPlayerSelection.new())
	var engine: MmEngine = _hero_casts_on_turn_one(chime)

	Scenario.play_until_game_turn(engine, 4)

	assert_eq(engine.villain().life, 21)
	assert_eq(engine.hero().life, 20)


func test_a_draw_step_trigger_draws_after_the_normal_draw() -> void:
	var engine: MmEngine = _hero_casts_on_turn_one(_mine())

	Scenario.play_until_step(engine, 2, Step.DRAW)

	assert_eq(engine.villain().hand.size(), 8, "The normal draw happened first.")
	assert_eq(Scenario.stacked_abilities(engine).size(), 1)
	Scenario.resolve_stack(engine)
	assert_eq(engine.villain().hand.size(), 9)


func test_an_intervening_if_that_is_false_keeps_the_ability_from_triggering() -> void:
	var engine: MmEngine = _hero_casts_on_turn_one(_mine())
	var mine: int = Scenario.permanent_named(engine, engine.hero().id, "Mine")
	Scenario.play_until_step(engine, 2, Step.UPKEEP)
	Scenario.pass_priority(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mine))

	Scenario.pass_until_step(engine, Step.DRAW)

	assert_true(engine.game_state().object(mine).is_tapped)
	assert_eq(Scenario.stacked_abilities(engine).size(), 0)
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)


func test_an_intervening_if_that_becomes_false_makes_the_ability_do_nothing() -> void:
	var engine: MmEngine = _hero_casts_on_turn_one(_mine())
	var mine: int = Scenario.permanent_named(engine, engine.hero().id, "Mine")
	Scenario.play_until_step(engine, 2, Step.DRAW)
	Scenario.pass_priority(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mine))

	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().hand.size(), 8, "CR 603.4: rechecked on resolution.")
	assert_eq(engine.game_state().stack.size(), 0, "It still left the stack.")


func test_ivory_tower_style_life_gain_counts_cards_in_hand_minus_four() -> void:
	var engine: MmEngine = _hero_casts_on_turn_one(_tower())

	Scenario.play_until_step(engine, 3, Step.UPKEEP)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 22, "Six cards in hand, minus 4.")


func test_a_negative_amount_of_life_gains_nothing() -> void:
	var cards: Array[MmCardDefinition] = Scenario.copies(_tower(), 40)
	var setup: MmEncounterSetup = Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))
	setup.hero.opening_hand_size = 3
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Tower")

	Scenario.play_until_step(engine, 3, Step.UPKEEP)
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 20, "CR 107.1b: 2 cards minus 4 is treated as 0.")
	assert_eq(Scenario.events_of(engine, LifeGainedEvent).size(), 0)


## "At the beginning of [whose] upkeep, [gainer] gains 1 life."
func _chime(whose: Whose, gainer: MmSelection) -> MmCardDefinition:
	return Scenario.artifact("Chime", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, whose), [Scenario.gain_life(1, gainer)])])


## "{T}: Add {C}. At the beginning of each player's draw step, if this is untapped, that
## player draws a card."
func _mine() -> MmCardDefinition:
	var draw: MmEffect = Scenario.draw_cards(1, TriggeringPlayerSelection.new())
	var ability: TriggeredAbility = Scenario.triggered(Scenario.at_step(Step.DRAW, Whose.ANY), [draw], [],
		Scenario.condition(SourceSelection.new(), Scenario.untapped()))
	return Scenario.artifact("Mine", [Scenario.tap_for_mana(MmMana.Type.COLORLESS, 1), ability])


## "At the beginning of your upkeep, you gain X life, where X is the number of cards in your
## hand minus 4."
func _tower() -> MmCardDefinition:
	var hand: HandSizeValue = HandSizeValue.new()
	hand.players = Scenario.you()
	var minus_four: DifferenceValue = DifferenceValue.new()
	minus_four.minuend = hand
	minus_four.subtrahend = Scenario.constant(4)
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = minus_four
	gain.players = Scenario.you()
	return Scenario.artifact("Tower", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU), [gain])])


func _hero_casts_on_turn_one(card: MmCardDefinition) -> MmEngine:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(card, 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.cast_and_resolve(engine, card.name), "")
	return engine
