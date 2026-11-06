extends GutTest
## CR 704.5a-b: a player at 0 or less life, or who drew from an empty library, loses.
## CR 104.2a: the other player then wins; CR 104.4a: if both lose at once it is a draw.
## CR 104.3a: a player may concede at any time.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Outcome := MmEngine.Outcome


func test_a_player_at_zero_life_loses_and_the_other_player_wins() -> void:
	var engine: MmEngine = _hero_with_bolts(3)

	assert_eq(Scenario.cast_and_resolve(engine, "Bolt", [MmReference.to_player(engine.villain().id)]), "")

	assert_true(engine.is_over())
	assert_eq(engine.outcome(), Outcome.HERO_WON)
	assert_null(engine.pending_decision())
	assert_true(engine.villain().has_lost)
	assert_eq(engine.villain().loss_reason, MmPlayer.LossReason.ZERO_LIFE)
	assert_false(engine.hero().has_lost)
	var lost: Array[MmEvent] = Scenario.events_of(engine, PlayerLostEvent)
	var ended: Array[MmEvent] = Scenario.events_of(engine, EncounterEndedEvent)
	assert_eq(lost.size(), 1)
	assert_eq(ended.size(), 1)
	assert_eq((ended[0] as EncounterEndedEvent).winner_id, engine.hero().id)
	assert_true(engine.event_log().find(lost[0]) < engine.event_log().find(ended[0]))


func test_a_player_below_zero_life_loses() -> void:
	var engine: MmEngine = _hero_with_bolts(2)

	Scenario.cast_and_resolve(engine, "Bolt", [MmReference.to_player(engine.villain().id)])

	assert_eq(engine.villain().life, -1)
	assert_eq(engine.outcome(), Outcome.HERO_WON)


func test_a_player_at_one_life_plays_on() -> void:
	var engine: MmEngine = _hero_with_bolts(4)

	Scenario.cast_and_resolve(engine, "Bolt", [MmReference.to_player(engine.villain().id)])

	assert_false(engine.is_over())
	assert_eq(engine.outcome(), Outcome.IN_PROGRESS)
	assert_true(engine.pending_decision() is PriorityDecision)


func test_combat_damage_can_win_the_encounter() -> void:
	var giant: Array[MmCardDefinition] = [Scenario.creature("Giant", 3, 3)]
	var no_creatures: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(giant, no_creatures)
	setup.villain.starting_life = 3
	var engine: MmEngine = Scenario.combat_ready_with(setup, giant, no_creatures)
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Giant"))

	assert_eq(Scenario.play_until_over(engine), "")

	assert_eq(engine.outcome(), Outcome.HERO_WON)
	assert_eq(engine.game_state().step, Step.COMBAT_DAMAGE)


func test_drawing_from_an_empty_library_loses_once_the_spell_has_resolved() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.free_draw("Recall", 3), 9), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	Scenario.cast_and_resolve(engine, "Recall", [MmReference.to_player(engine.hero().id)])

	assert_eq(engine.hero().hand.size(), 8, "Seven, minus the Recall, plus the two cards that were left.")
	assert_eq(engine.outcome(), Outcome.VILLAIN_WON)
	assert_eq(engine.hero().loss_reason, MmPlayer.LossReason.EMPTY_LIBRARY)
	var failed_draw: int = engine.event_log().find(Scenario.events_of(engine, EmptyLibraryDrawEvent)[0])
	var recall_resolved: int = -1
	for index: int in engine.event_log().size():
		var moved: ZoneChangeEvent = engine.event_log()[index] as ZoneChangeEvent
		if moved != null and moved.reason == ZoneChangeEvent.Reason.RESOLVED:
			recall_resolved = index
	assert_true(failed_draw < recall_resolved, "The spell finished resolving after the failed draw.")
	assert_true(recall_resolved < engine.event_log().find(Scenario.events_of(engine, PlayerLostEvent)[0]))


func test_a_failed_draw_step_draw_loses_before_anyone_gets_priority() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 1, 40, 8))

	assert_eq(Scenario.play_until_over(engine), "")

	assert_eq(engine.outcome(), Outcome.HERO_WON)
	assert_eq(engine.villain().loss_reason, MmPlayer.LossReason.EMPTY_LIBRARY)
	assert_eq(engine.game_state().game_turn, 4)
	assert_eq(engine.game_state().step, Step.DRAW)


func test_a_short_opening_hand_draw_loses_at_the_first_check() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 1, 5, 40))

	assert_eq(Scenario.play_until_over(engine), "")

	assert_eq(engine.outcome(), Outcome.VILLAIN_WON)
	assert_eq(engine.game_state().game_turn, 1)


func test_both_players_losing_at_once_is_a_draw() -> void:
	var setup: MmEncounterSetup = Scenario.setup_with(
		Scenario.copies(Scenario.damage_each_player("Plague", 3), 40), Scenario.copies(Scenario.vanilla("Card"), 40))
	setup.hero.starting_life = 3
	setup.villain.starting_life = 3
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	Scenario.cast_and_resolve(engine, "Plague")

	assert_eq(engine.outcome(), Outcome.DRAW)
	assert_true(engine.hero().has_lost)
	assert_true(engine.villain().has_lost)
	assert_eq((Scenario.events_of(engine, EncounterEndedEvent)[0] as EncounterEndedEvent).winner_id, MmGameState.NO_PLAYER)


func test_nothing_can_be_answered_or_undone_after_the_encounter_ends() -> void:
	var engine: MmEngine = _hero_with_bolts(3)
	Scenario.cast_and_resolve(engine, "Bolt", [MmReference.to_player(engine.villain().id)])
	var after: String = engine.fingerprint()

	assert_ne(engine.submit(0), "")
	assert_false(engine.can_undo())
	assert_ne(engine.undo(), "")
	assert_ne(engine.concede(engine.hero()), "")

	assert_eq(engine.fingerprint(), after)


func test_both_views_show_the_outcome() -> void:
	var engine: MmEngine = _hero_with_bolts(3)
	Scenario.cast_and_resolve(engine, "Bolt", [MmReference.to_player(engine.villain().id)])

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_true(view.is_over)
		assert_eq(view.winner_id, engine.hero().id)
		assert_eq(view.loss_reasons, {engine.villain().id: MmPlayer.LossReason.ZERO_LIFE})


func test_replaying_a_finished_encounter_reproduces_it() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.HERO_STARTS, 5, 40, 8)
	var original: MmEngine = MmEngine.start(setup)
	Scenario.play_until_over(original)

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	assert_eq(replayed.outcome(), original.outcome())


func test_a_copy_of_the_state_keeps_a_failed_draw_and_the_outcome() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	var state: MmGameState = engine.game_state().duplicate_state()
	state.perform(EmptyLibraryDrawEvent.new(engine.hero().id))
	state.perform(PlayerLostEvent.new(engine.villain().id, MmPlayer.LossReason.CONCEDED))
	state.perform(EncounterEndedEvent.new(engine.hero().id))

	var copy: MmGameState = state.duplicate_state()

	assert_true(copy.player(engine.hero().id).has_drawn_from_empty_library)
	assert_true(copy.player(engine.villain().id).has_lost)
	assert_true(copy.is_over)
	assert_eq(copy.winner_id, engine.hero().id)
	assert_eq(copy.fingerprint(), state.fingerprint())
	assert_ne(copy.fingerprint(), engine.game_state().fingerprint())


# --- Conceding ---------------------------------------------------------------------------


func test_a_player_may_concede_during_the_other_players_decision() -> void:
	var engine: MmEngine = _hero_with_bolts(20)
	Scenario.pass_priority(engine)
	assert_eq(engine.pending_decision().player_id, engine.villain().id)

	assert_eq(engine.concede(engine.hero()), "")

	assert_eq(engine.outcome(), Outcome.VILLAIN_WON)
	assert_eq(engine.hero().loss_reason, MmPlayer.LossReason.CONCEDED)
	assert_null(engine.pending_decision())
	assert_eq(engine.decision_log().back(), ["concede", engine.hero().id])
	assert_false(engine.can_undo(), "Conceding is final.")


func test_replaying_a_concession_ends_the_same_way() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.HERO_STARTS, 3)
	var original: MmEngine = MmEngine.start(setup)
	Scenario.play_until_game_turn(original, 2)
	original.concede(original.villain())

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.outcome(), Outcome.HERO_WON)
	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_a_concession_is_never_mistaken_for_an_answer() -> void:
	var engine: MmEngine = _hero_with_bolts(20)

	assert_ne(engine.submit(["concede", engine.hero().id]), "")

	assert_false(engine.is_over())


## The Hero in their first main phase with a hand of {0} Bolts, against a Villain on
## [param villain_life] life.
func _hero_with_bolts(villain_life: int) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.setup_with(
		Scenario.copies(Scenario.free_shock("Bolt", 3), 40), Scenario.copies(Scenario.vanilla("Card"), 40))
	setup.villain.starting_life = villain_life
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	return engine
