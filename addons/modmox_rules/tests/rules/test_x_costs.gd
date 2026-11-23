extends GutTest
## {X} in a mana cost (CR 107.3, ADR 0076): its caster chooses X as it is cast (CR 601.2b),
## after any mode and before any target, from 0 up to the most they could pay. The spell then
## costs X more for each {X} (CR 601.2f). Its mana value counts X on the stack and 0
## everywhere else (CR 202.3e), and "X" in its text is the X chosen (ChosenXValue).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_casting_it_asks_for_x_from_zero_to_the_most_its_caster_could_pay() -> void:
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	var bounty: int = Scenario.card_in_hand(engine, engine.hero(), "Bounty")

	assert_eq(_begin_cast(engine, bounty), "")

	var asked: ChooseXDecision = engine.pending_decision() as ChooseXDecision
	assert_not_null(asked, "CR 601.2b: X is announced as it is cast.")
	assert_eq(asked.player_id, engine.hero().id)
	assert_eq(asked.most, 6, "Two Mana Birds make six.")
	assert_eq(engine.game_state().object(asked.stack_object_id).zone(), engine.game_state().stack, "CR 601.2a: on the stack first.")


func test_the_x_chosen_is_paid_and_read_by_its_effect() -> void:
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	var bounty: int = Scenario.card_in_hand(engine, engine.hero(), "Bounty")
	var life: int = engine.hero().life
	assert_eq(_begin_cast(engine, bounty), "")

	assert_eq(Scenario.choose_cast_x(engine, 4), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying)
	assert_eq(paying.remaining_generic, 4, "CR 601.2f: it costs X more.")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 4)


func test_x_of_zero_costs_nothing_more() -> void:
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	var bounty: int = Scenario.card_in_hand(engine, engine.hero(), "Bounty")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_with_x(engine, bounty, 0), "")

	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life)
	assert_false(engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")).is_tapped)


func test_x_is_chosen_before_targets() -> void:
	# CR 601.2b-c.
	var engine: MmEngine = _hero_main([Scenario.x_blast()])
	var blast: int = Scenario.card_in_hand(engine, engine.hero(), "Blast")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(_begin_cast(engine, blast), "")
	assert_true(engine.pending_decision() is ChooseXDecision)
	assert_eq(Scenario.choose_cast_x(engine, 3), "")
	assert_true(engine.pending_decision() is ChooseTargetDecision, "Targets come after X.")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(ogre)), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanents_named(engine, engine.villain().id, "Ogre"), [] as Array[int], "3 damage kills a 3/3.")


func test_a_cost_without_x_asks_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.sorcery("Plain", Scenario.mana_cost(1), [], [Scenario.gain_life(1, Scenario.you())])])
	var plain: int = Scenario.card_in_hand(engine, engine.hero(), "Plain")

	assert_eq(_begin_cast(engine, plain), "")

	assert_false(engine.pending_decision() is ChooseXDecision)


func test_an_x_above_the_most_or_not_a_number_is_refused() -> void:
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	assert_eq(_begin_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bounty")), "")

	assert_ne(engine.submit(7), "")
	assert_ne(engine.submit(-1), "")
	assert_ne(engine.submit("two"), "")
	assert_true(engine.pending_decision() is ChooseXDecision, "Nothing changed.")


func test_its_mana_value_counts_x_on_the_stack_and_zero_elsewhere() -> void:
	# CR 202.3e.
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	var bounty: int = Scenario.card_in_hand(engine, engine.hero(), "Bounty")
	assert_eq(Scenario.now(engine, bounty).mana_value(), 0, "In the hand X is 0.")
	assert_eq(_begin_cast(engine, bounty), "")
	var spell: int = (engine.pending_decision() as ChooseXDecision).stack_object_id

	assert_eq(Scenario.choose_cast_x(engine, 3), "")

	assert_eq(Scenario.now(engine, spell).mana_value(), 3)
	assert_eq(engine.game_state().object(spell).chosen_x, 3)


func test_canceling_while_paying_rewinds_the_whole_cast() -> void:
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	var bounty: int = Scenario.card_in_hand(engine, engine.hero(), "Bounty")
	var before: String = engine.fingerprint()
	assert_eq(_begin_cast(engine, bounty), "")
	assert_eq(Scenario.choose_cast_x(engine, 2), "")

	assert_eq(engine.cancel_cast(), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is PriorityDecision)


func test_a_copy_made_while_paying_carries_on_alike() -> void:
	var engine: MmEngine = _hero_main([Scenario.x_gain()])
	var life: int = engine.hero().life
	assert_eq(_begin_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bounty")), "")
	assert_eq(Scenario.choose_cast_x(engine, 5), "")
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)

	for running: MmEngine in [engine, copy]:
		assert_eq(Scenario.auto_pay(running), "")
		assert_eq(Scenario.resolve_stack(running), "")

	assert_eq(copy.hero().life, life + 5)
	assert_eq(engine.hero().life, life + 5)


func test_replaying_the_decision_log_gives_the_same_game() -> void:
	# ADR 0010: the X chosen is a plain int in the decision log.
	var setup: MmEncounterSetup = _setup([Scenario.x_gain()])
	var engine: MmEngine = _ready_with(setup, [Scenario.x_gain()])
	assert_eq(Scenario.cast_with_x(engine, Scenario.card_in_hand(engine, engine.hero(), "Bounty"), 3), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_the_x_chosen_is_part_of_the_fingerprint() -> void:
	var one: MmEngine = _hero_main([Scenario.x_gain()])
	var two: MmEngine = _hero_main([Scenario.x_gain()])
	for running: MmEngine in [one, two]:
		assert_eq(_begin_cast(running, Scenario.card_in_hand(running, running.hero(), "Bounty")), "")

	Scenario.choose_cast_x(one, 1)
	Scenario.choose_cast_x(two, 2)

	assert_ne(one.fingerprint(), two.fingerprint())


func test_chosen_x_is_zero_for_anything_not_cast_with_an_x() -> void:
	var context: MmEffectContext = MmEffectContext.new(1, 0)

	assert_eq(Scenario.chosen_x().evaluate(null, null), 0, "A static ability's Filter may be asked with no context.")
	assert_eq(Scenario.chosen_x().evaluate(null, context), 0)


func test_a_cost_with_x_is_saved_and_describes_itself() -> void:
	var cost: MmManaCost = Scenario.x_cost(0, [MmMana.Type.WHITE])
	var path: String = "user://test_x_cost.tres"
	assert_eq(ResourceSaver.save(cost, path), OK)

	var loaded: MmManaCost = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmManaCost

	assert_eq(loaded.x_count, 1)
	assert_eq(loaded.describe(), "{X}{W}")
	assert_eq(loaded.mana_value(), 1, "CR 202.3e: X is 0 off the stack.")
	assert_eq(Scenario.x_cost(2).describe(), "{X}{2}")
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## Submits the cast of [param object_id] and stops at its first choice.
func _begin_cast(engine: MmEngine, object_id: int) -> String:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	if decision == null:
		return "Not a priority decision."
	var index: int = Scenario.cast_index(decision, object_id)
	return "Cannot be cast." if index == -1 else engine.submit(index)


func _birds() -> Array[MmCardDefinition]:
	return [Scenario.mana_bird("Mana Bird"), Scenario.mana_bird("Mana Bird")]


func _setup(hand: Array[MmCardDefinition]) -> MmEncounterSetup:
	return Scenario.combat_setup(_birds(), [Scenario.creature("Ogre", 3, 3)], hand)


func _ready_with(setup: MmEncounterSetup, hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, _birds(), [Scenario.creature("Ogre", 3, 3)], hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## Two Mana Birds and [param hand] for the Hero, an Ogre for the Villain, in the Hero's main
## phase of Game Turn 3.
func _hero_main(hand: Array[MmCardDefinition]) -> MmEngine:
	return _ready_with(_setup(hand), hand)
