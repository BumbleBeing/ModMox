extends GutTest
## ADR 0015 and ADR 0010 applied to triggers: ordering and target choices can be undone,
## pending triggers survive copies of the state, and replays reproduce triggers exactly.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_ordering_triggers_can_be_undone() -> void:
	var engine: MmEngine = _engine_at([_gain("First"), _gain("Second")])
	var before: String = engine.fingerprint()
	engine.submit([1, 0])

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is OrderTriggersDecision)


func test_choosing_a_triggers_target_can_be_undone() -> void:
	var sniper: MmCardDefinition = Scenario.artifact("Sniper", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU),
		[Scenario.deal_damage(1, Scenario.targeted(0))], [Scenario.any_target()])])
	var engine: MmEngine = _engine_at([sniper])
	var before: String = engine.fingerprint()
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.hero().id)), "")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 19)


func test_a_copy_of_the_state_keeps_pending_triggers_and_last_known_information() -> void:
	var engine: MmEngine = _engine_at([_gain("First"), _gain("Second")])
	var original: MmGameState = engine.game_state()

	var copy: MmGameState = original.duplicate_state()

	assert_eq(copy.pending_triggers.size(), 2)
	assert_eq(copy.fingerprint(), original.fingerprint())


func test_replaying_turns_with_triggers_reproduces_the_state_exactly() -> void:
	var hero_cards: Array[MmCardDefinition] = [_gain("First"), _gain("Second")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, no_cards, no_cards, 3, Step.UPKEEP)
	original.submit([1, 0])
	Scenario.play_until_game_turn(original, 6)

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	assert_eq(original.hero().life, 24)


## "At the beginning of your upkeep, you gain 1 life."
func _gain(card_name: String) -> MmCardDefinition:
	return Scenario.artifact(card_name, [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])


func _engine_at(hero_cards: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, no_cards, no_cards, 3, Step.UPKEEP)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
