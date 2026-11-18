extends GutTest
## The legend rule (CR 704.5j): a player who controls two or more legendary permanents with
## the same name chooses one, and the rest are put into their owners' graveyards, as a
## state-based action performed with all the others (CR 704.3, ADR 0051).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_second_copy_of_a_legend_asks_its_controller_which_to_keep() -> void:
	var engine: MmEngine = _legend_in_play_and_in_hand([Scenario.legend()])
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Legend")

	Scenario.cast_and_resolve(engine, "Legend")

	var decision: ChooseLegendToKeepDecision = engine.pending_decision() as ChooseLegendToKeepDecision
	assert_not_null(decision, "CR 704.5j: the legend rule asks.")
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.legend_name, "Legend")
	assert_eq(decision.candidate_ids, Scenario.permanents_named(engine, engine.hero().id, "Legend"))
	assert_eq(decision.candidate_ids.size(), 2)
	assert_eq(decision.candidate_ids[0], first, "In ID order.")


func test_keeping_the_first_puts_the_new_copy_into_its_owners_graveyard() -> void:
	var engine: MmEngine = _legend_in_play_and_in_hand([Scenario.legend()])
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Legend")
	Scenario.cast_and_resolve(engine, "Legend")

	assert_eq(Scenario.keep_legend(engine, first), "")

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Legend"), [first])
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Legend"])
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.LEGEND_RULE)
	assert_true(engine.pending_decision() is PriorityDecision)


func test_keeping_the_new_copy_puts_the_first_into_the_graveyard() -> void:
	var engine: MmEngine = _legend_in_play_and_in_hand([Scenario.legend()])
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Legend")
	Scenario.cast_and_resolve(engine, "Legend")
	var newer: int = (engine.pending_decision() as ChooseLegendToKeepDecision).candidate_ids[1]

	Scenario.keep_legend(engine, newer)

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Legend"), [newer])
	assert_null(engine.game_state().object(first))


func test_three_copies_keep_one_and_the_other_two_go_together() -> void:
	var spirit: MmCardDefinition = _legendary_token("Spirit")
	var engine: MmEngine = _main_ready([], [Scenario.free_tokens("Haunt", spirit, 3)])

	Scenario.cast_and_resolve(engine, "Haunt")

	var decision: ChooseLegendToKeepDecision = engine.pending_decision() as ChooseLegendToKeepDecision
	assert_eq(decision.candidate_ids.size(), 3)
	var moves_before: int = Scenario.events_of(engine, ZoneChangeEvent).size()
	Scenario.keep_legend(engine, decision.candidate_ids[1])
	assert_eq(Scenario.tokens_on_battlefield(engine), [decision.candidate_ids[1]])
	var moved: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent).slice(moves_before)
	assert_eq(moved.size(), 2)
	assert_eq(moved[0].batch, moved[1].batch, "CR 704.3: at once.")


func test_each_name_is_chosen_for_and_everything_goes_in_one_batch_after_the_last_choice() -> void:
	var spirit: MmCardDefinition = _legendary_token("Spirit")
	var bird: MmCardDefinition = _legendary_token("Bird")
	var twins: MmCardDefinition = Scenario.instant("Twins", Scenario.mana_cost(0), [],
		[Scenario.create_tokens(spirit, 2), Scenario.create_tokens(bird, 2)])
	var engine: MmEngine = _main_ready([], [twins])
	Scenario.cast_and_resolve(engine, "Twins")
	var spirits: ChooseLegendToKeepDecision = engine.pending_decision() as ChooseLegendToKeepDecision
	assert_eq(spirits.legend_name, "Spirit Token", "The group with the lowest ID first.")

	Scenario.keep_legend(engine, spirits.candidate_ids[0])

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 4, "Nothing moves until every choice is made.")
	var birds: ChooseLegendToKeepDecision = engine.pending_decision() as ChooseLegendToKeepDecision
	assert_eq(birds.legend_name, "Bird Token")
	Scenario.keep_legend(engine, birds.candidate_ids[1])
	assert_eq(Scenario.tokens_on_battlefield(engine), [spirits.candidate_ids[0], birds.candidate_ids[1]])


func test_a_copy_taken_between_two_choices_remembers_the_first() -> void:
	var spirit: MmCardDefinition = _legendary_token("Spirit")
	var bird: MmCardDefinition = _legendary_token("Bird")
	var twins: MmCardDefinition = Scenario.instant("Twins", Scenario.mana_cost(0), [],
		[Scenario.create_tokens(spirit, 2), Scenario.create_tokens(bird, 2)])
	var engine: MmEngine = _main_ready([], [twins])
	Scenario.cast_and_resolve(engine, "Twins")
	var kept_spirit: int = (engine.pending_decision() as ChooseLegendToKeepDecision).candidate_ids[1]
	Scenario.keep_legend(engine, kept_spirit)

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(5))

	assert_true(copy.pending_decision() is ChooseLegendToKeepDecision)
	var kept_bird: int = (copy.pending_decision() as ChooseLegendToKeepDecision).candidate_ids[0]
	assert_eq(Scenario.keep_legend(copy, kept_bird), "")
	assert_eq(Scenario.tokens_on_battlefield(copy), [kept_spirit, kept_bird])


func test_legends_with_different_names_stay() -> void:
	var engine: MmEngine = _legend_in_play_and_in_hand([Scenario.legend("Other Legend")])

	Scenario.cast_and_resolve(engine, "Other Legend")

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Other Legend").size(), 1)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Legend").size(), 1)


func test_two_nonlegendary_permanents_with_one_name_stay() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = _main_ready([bear], [bear])

	Scenario.cast_and_resolve(engine, "Bear")

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear").size(), 2)


func test_each_player_may_control_their_own_copy() -> void:
	# CR 704.5j asks about the legends one player controls.
	var no_cards: Array[MmCardDefinition] = []
	var legends: Array[MmCardDefinition] = [Scenario.legend()]
	var setup: MmEncounterSetup = Scenario.combat_setup(legends, legends)

	var engine: MmEngine = Scenario.permanents_ready_with(setup, legends, legends, no_cards, no_cards, 3, Step.PRECOMBAT_MAIN)

	assert_not_null(engine, "Neither player was asked anything.")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Legend").size(), 1)
	assert_eq(Scenario.permanents_named(engine, engine.villain().id, "Legend").size(), 1)


func test_an_indestructible_legend_still_goes() -> void:
	# The legend rule neither destroys nor can be regenerated from (CR 702.12b, 701.19).
	var sturdy: MmCardDefinition = Scenario.legend("Legend", 2, 2, [IndestructibleAbility.new()])
	var engine: MmEngine = _legend_in_play_and_in_hand([sturdy], sturdy)
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Legend")
	Scenario.cast_and_resolve(engine, "Legend")
	var newer: int = (engine.pending_decision() as ChooseLegendToKeepDecision).candidate_ids[1]

	Scenario.keep_legend(engine, newer)

	assert_null(engine.game_state().object(first))
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Legend"])


func test_the_one_put_into_the_graveyard_dies() -> void:
	var mourner: MmCardDefinition = Scenario.creature("Mourner", 1, 1,
		[Scenario.triggered(Scenario.dies(Scenario.of_type(MmCardTypes.CardType.CREATURE)), [Scenario.gain_life(1, Scenario.you())])])
	var legends: Array[MmCardDefinition] = [Scenario.legend(), mourner]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(legends, no_cards, [Scenario.legend()])
	var engine: MmEngine = Scenario.permanents_ready_with(setup, legends, no_cards, [Scenario.legend()], no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.cast_and_resolve(engine, "Legend")
	Scenario.keep_legend(engine, Scenario.permanent_named(engine, engine.hero().id, "Legend"))

	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 21)


func test_it_is_performed_with_the_other_state_based_actions() -> void:
	# Each Legend gives the Hero's other creatures -1/-1, so with two the 2/2 Wisp is 0/0.
	# Were the legend rule performed first, on its own, the Wisp would be a 1/1 and live.
	var shrinking: MmCardDefinition = _shrinking_legend()
	var wisp: MmCardDefinition = Scenario.creature("Wisp", 2, 2)
	var engine: MmEngine = _main_ready([shrinking, wisp], [shrinking])
	Scenario.cast_and_resolve(engine, "Legend")

	Scenario.keep_legend(engine, Scenario.permanent_named(engine, engine.hero().id, "Legend"))

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Wisp"), -1, "CR 704.3: it died at the same time.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard).size(), 2)


func test_an_answer_that_is_not_a_candidate_is_refused() -> void:
	var engine: MmEngine = _legend_in_play_and_in_hand([Scenario.legend()])
	Scenario.cast_and_resolve(engine, "Legend")
	var before: String = engine.fingerprint()

	assert_ne(engine.submit(2), "")
	assert_ne(engine.submit([0]), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is ChooseLegendToKeepDecision)


func test_a_replay_keeps_the_same_legend() -> void:
	var hero_cards: Array[MmCardDefinition] = [Scenario.legend()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards, hero_cards)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, hero_cards, no_cards, 3, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(original, "Legend")
	Scenario.keep_legend(original, (original.pending_decision() as ChooseLegendToKeepDecision).candidate_ids[1])
	Scenario.play_until_game_turn(original, 5)

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_undo_takes_back_the_choice() -> void:
	var engine: MmEngine = _legend_in_play_and_in_hand([Scenario.legend()])
	Scenario.cast_and_resolve(engine, "Legend")
	var asked: String = engine.fingerprint()
	Scenario.keep_legend(engine, Scenario.permanent_named(engine, engine.hero().id, "Legend"))

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), asked)


## The Hero's main phase on Game Turn 3, with a Legend on the battlefield since Game Turn 1
## and [param in_hand] in hand. The Legend on the battlefield is [param on_battlefield].
func _legend_in_play_and_in_hand(in_hand: Array[MmCardDefinition], on_battlefield: MmCardDefinition = null) -> MmEngine:
	var first: Array[MmCardDefinition] = [Scenario.legend() if on_battlefield == null else on_battlefield]
	return _main_ready(first, in_hand)


func _main_ready(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


## A legendary 1/1 [param subtype] creature token, named "[param subtype] Token".
func _legendary_token(subtype: String) -> MmCardDefinition:
	var made: MmCardDefinition = Scenario.token(1, 1, [MmCardTypes.CardColor.WHITE], [subtype])
	made.supertypes = [MmCardTypes.Supertype.LEGENDARY]
	return made


## A legendary 3/3 "Legend": "Other creatures you control get -1/-1."
func _shrinking_legend() -> MmCardDefinition:
	var you_control: ControlledByFilter = ControlledByFilter.new()
	you_control.whose = MmTrigger.Whose.YOU
	var others: MmFilter = Scenario.all_of([you_control, Scenario.is_not(IsSourceFilter.new())])
	return Scenario.legend("Legend", 3, 3,
		[Scenario.continuous_static([Scenario.modify_pt(-1, -1, Scenario.each_creature(others))])])
