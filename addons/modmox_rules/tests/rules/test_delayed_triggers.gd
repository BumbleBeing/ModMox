extends GutTest
## Delayed triggered abilities (CR 603.7), as Harried Dronesmith makes one: "create a 1/1
## colorless Thopter artifact creature token with flying. It gains haste until end of turn.
## Sacrifice it at the beginning of your next end step." The delayed ability is created as
## the effect happens, is bound to the token its ability created ("it"), triggers the next
## time your end step begins, and then is gone (engine ADR 0103). A Fleeting is an instant
## costing {0} that does what Dronesmith's ability does, so it can be cast in any step.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_created_token_gains_haste_and_may_attack_the_turn_it_is_created() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.dronesmith()], [])
	assert_not_null(engine, "No seed gave the needed hand.")
	var thopters: Array[int] = Scenario.tokens_on_battlefield(engine)

	var attack: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision

	assert_eq(thopters.size(), 1, "One Thopter from this turn's beginning of combat; Game Turn 1's is gone.")
	assert_not_null(attack)
	assert_true(Scenario.now(engine, thopters[0]).has_ability(HasteAbility), "\"It\" is the token just created.")
	assert_true(attack.candidate_ids.has(thopters[0]), "With haste it may attack the turn it arrives.")


func test_the_token_is_sacrificed_as_this_turns_end_step_begins() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.dronesmith()], [])
	assert_not_null(engine, "No seed gave the needed hand.")
	var thopter: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(Scenario.play_until_step(engine, 3, Step.POSTCOMBAT_MAIN), "")
	assert_eq(Scenario.tokens_on_battlefield(engine), [thopter], "Still there after combat.")

	assert_eq(Scenario.play_until_step(engine, 3, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine), [] as Array[int])
	assert_true(_sacrificed(engine, thopter), "CR 701.21a: sacrificed, not destroyed.")


func test_haste_ends_with_the_turn_it_was_given_in() -> void:
	var engine: MmEngine = _fleeting_ready(3, Step.PRECOMBAT_MAIN, [Scenario.free_tokens("Maker", Scenario.thopter())])
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var fleeting: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.cast_and_resolve(engine, "Maker"), "")
	var made: int = Scenario.tokens_on_battlefield(engine)[1]

	assert_true(Scenario.now(engine, fleeting).has_ability(HasteAbility))
	assert_false(Scenario.now(engine, made).has_ability(HasteAbility), "Only the token its own ability created.")


func test_it_triggers_only_once_so_a_later_token_stays() -> void:
	var engine: MmEngine = _fleeting_ready(3, Step.PRECOMBAT_MAIN, [Scenario.free_tokens("Maker", Scenario.thopter())])
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var fleeting: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(Scenario.play_until_step(engine, 3, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_true(_sacrificed(engine, fleeting), "Sacrificed in this end step.")

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Maker"), "")
	var made: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(Scenario.play_until_step(engine, 5, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine), made, "CR 603.7c: it triggered once and is gone.")
	assert_eq(_delayed_triggers_of(engine, "Fleeting"), 1)


func test_created_during_your_end_step_it_waits_for_your_next_turns_end_step() -> void:
	# CR 603.7c: "your next end step" is the next to begin, and this one has begun already.
	var engine: MmEngine = _fleeting_ready(3, Step.END)
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var thopter: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.play_until_step(engine, 4, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.tokens_on_battlefield(engine), [thopter], "Not the opponent's end step.")
	assert_eq(Scenario.play_until_step(engine, 5, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_sacrificed(engine, thopter))


func test_created_in_an_opponents_turn_it_waits_for_your_next_end_step() -> void:
	var engine: MmEngine = _fleeting_ready(4, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.pass_priority(engine), "", "The Villain has priority first in their own turn.")
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var thopter: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.play_until_step(engine, 4, Step.CLEANUP), "")
	assert_eq(Scenario.tokens_on_battlefield(engine), [thopter], "The Villain's end step is not yours.")
	assert_eq(Scenario.play_until_step(engine, 5, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_sacrificed(engine, thopter))


func test_a_token_that_has_left_leaves_nothing_else_to_sacrifice() -> void:
	# ADR 0008: the token that left is gone, and "it" never becomes another permanent.
	var engine: MmEngine = _fleeting_ready(3, Step.PRECOMBAT_MAIN,
		[Scenario.free_tokens("Maker", Scenario.thopter()), Scenario.exile_spell("Banish")])
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var fleeting: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(Scenario.cast_and_resolve(engine, "Maker"), "")
	var made: int = Scenario.tokens_on_battlefield(engine)[1]
	assert_eq(Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(fleeting)]), "")

	assert_eq(Scenario.play_until_step(engine, 3, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine), [made])
	assert_eq(_delayed_triggers_of(engine, "Fleeting"), 1, "It still triggers, and does nothing.")


func test_the_token_is_sacrificed_after_the_creature_that_made_it_has_left() -> void:
	# CR 603.7: a delayed triggered ability is the game's, not its source's, once created.
	var engine: MmEngine = Scenario.combat_ready([Scenario.dronesmith()], [], [Scenario.exile_spell("Banish")])
	assert_not_null(engine, "No seed gave the needed hand.")
	var thopter: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(Scenario.play_until_step(engine, 3, Step.POSTCOMBAT_MAIN), "")
	var dronesmith: int = Scenario.permanent_named(engine, engine.hero().id, "Dronesmith")
	assert_eq(Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(dronesmith)]), "")

	assert_eq(Scenario.play_until_step(engine, 3, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_sacrificed(engine, thopter))


func test_indestructible_does_not_stop_the_sacrifice() -> void:
	var sturdy: Array[MmAbility] = [IndestructibleAbility.new()]
	var engine: MmEngine = _fleeting_ready(3, Step.PRECOMBAT_MAIN, [], Scenario.thopter(sturdy))
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var thopter: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.play_until_step(engine, 3, Step.END), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(_sacrificed(engine, thopter), "CR 701.21a: sacrificing is not destruction.")


func test_a_simulation_copy_keeps_the_delayed_trigger() -> void:
	var engine: MmEngine = _fleeting_ready(3, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var thopter: int = Scenario.tokens_on_battlefield(engine)[0]

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	assert_eq(Scenario.play_until_step(copy, 3, Step.END), "")
	assert_eq(Scenario.resolve_stack(copy), "")

	assert_true(_sacrificed(copy, thopter))
	assert_eq(Scenario.tokens_on_battlefield(engine), [thopter], "The real game is untouched.")


func test_the_delayed_trigger_is_part_of_the_state_fingerprint() -> void:
	var engine: MmEngine = _fleeting_ready(3, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.cast_and_resolve(engine, "Fleeting"), "")
	var state: MmGameState = engine.game_state()

	var without: MmGameState = state.duplicate_state()
	without.delayed_triggers.clear()

	assert_eq(state.duplicate_state().fingerprint(), state.fingerprint(), "A copy keeps it.")
	assert_ne(without.fingerprint(), state.fingerprint())


## An engine in [param step] of Game Turn [param game_turn] where the Hero holds a Fleeting
## of [param made] and [param extras].
func _fleeting_ready(game_turn: int, step: MmTurn.Step, extras: Array[MmCardDefinition] = [],
		made: MmCardDefinition = null) -> MmEngine:
	var hand: Array[MmCardDefinition] = [Scenario.free_fleeting("Fleeting", made)]
	hand.append_array(extras)
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, no_cards, hand),
		no_cards, no_cards, hand, no_cards, game_turn, step)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


## Whether the permanent [param object_id] was sacrificed.
func _sacrificed(engine: MmEngine, object_id: int) -> bool:
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		var move: ZoneChangeEvent = event as ZoneChangeEvent
		if move.object_id == object_id and move.reason == ZoneChangeEvent.Reason.SACRIFICE:
			return true
	return false


## How many delayed triggers of [param source_name] have triggered.
func _delayed_triggers_of(engine: MmEngine, source_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == source_name:
			count += 1
	return count
