extends GutTest
## An alternative cost (CR 118.9, engine ADR 0093): Zahid, Djinn of the Lamp's "You may pay
## {3}{U} and tap an untapped artifact you control rather than pay this spell's mana cost."
## Its card is offered a second cast from the hand, after the first, for that cost: the
## permanents it taps are chosen before the mana is paid, cost reductions take mana off it
## as they do off a mana cost, and the spell's mana value is still its mana cost's. Djinns
## are 5/6 fliers costing {4}{W}{W} with "{3}{W} and tap an untapped artifact you control";
## Elves tap for {W}; a Lamp is an artifact costing {0} that does nothing.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_the_hand_offers_it_for_its_mana_cost_and_then_for_its_alternative_cost() -> void:
	var engine: MmEngine = _hero_main(_elves(6, [_lamp()]))
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_ne(Scenario.cast_index_alternative(decision, _djinn(engine), false), -1)
	assert_ne(Scenario.cast_index_alternative(decision, _djinn(engine)), -1, "CR 118.9: offered after it.")
	assert_true(Scenario.cast_index_alternative(decision, _djinn(engine))
		> Scenario.cast_index_alternative(decision, _djinn(engine), false))


func test_without_an_untapped_artifact_only_its_mana_cost_is_offered() -> void:
	var engine: MmEngine = _hero_main(_elves(6))
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_ne(Scenario.cast_index_alternative(decision, _djinn(engine), false), -1)
	assert_eq(Scenario.cast_index_alternative(decision, _djinn(engine)), -1, "CR 601.2h: it can't be paid.")


func test_with_too_little_mana_for_its_mana_cost_only_the_alternative_is_offered() -> void:
	var engine: MmEngine = _hero_main(_elves(4, [_lamp()]))
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(Scenario.cast_index_alternative(decision, _djinn(engine), false), -1, "Four Elves can't pay {4}{W}{W}.")
	assert_ne(Scenario.cast_index_alternative(decision, _djinn(engine)), -1, "They pay {3}{W}.")


func test_cast_for_its_alternative_cost_it_taps_the_artifact_then_pays_its_mana() -> void:
	var engine: MmEngine = _hero_main(_elves(4, [_lamp()]))
	var lamp: int = Scenario.permanent_named(engine, engine.hero().id, "Lamp")

	assert_eq(engine.submit(Scenario.cast_index_alternative(engine.pending_decision() as PriorityDecision, _djinn(engine))), "")
	var tapping: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(tapping, "The artifact is chosen before the mana is paid.")
	assert_eq(tapping.candidate_ids, [lamp] as Array[int])
	assert_eq(engine.submit([lamp]), "")
	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [3, [W]], "CR 118.9: paid instead of {4}{W}{W}.")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Djinn"), -1)
	assert_true(engine.game_state().object(lamp).is_tapped)


func test_its_mana_value_is_its_mana_costs() -> void:
	var engine: MmEngine = _hero_main(_elves(4, [_lamp()]))

	assert_eq(_cast_alternative(engine), "")

	assert_eq(Scenario.now(engine, Scenario.stack_ids(engine)[0]).mana_value(), 6, "CR 118.9c, 202.3.")


func test_cost_reductions_take_mana_off_its_alternative_cost() -> void:
	var discount: MmCardDefinition = Scenario.creature("Discount", 1, 1, [Scenario.spells_cost_less(1, 0)])
	var engine: MmEngine = _hero_main(_elves(3, [_lamp(), discount]))

	assert_eq(_cast_alternative(engine), "", "CR 601.2f: {1} less takes {3}{W} to {2}{W}, which three Elves pay.")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Djinn"), -1)


func test_an_artifact_that_just_came_under_your_control_may_be_tapped_for_it() -> void:
	# CR 302.6: only a {T} cost needs a creature to have been controlled since the turn
	# began, so an artifact creature cast this turn may be tapped.
	var servo: MmCardDefinition = Scenario.creature("Servo", 1, 1)
	servo.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	var engine: MmEngine = _hero_main(_elves(4), [servo])
	assert_eq(Scenario.cast_and_resolve(engine, "Servo"), "")
	var servo_id: int = Scenario.permanent_named(engine, engine.hero().id, "Servo")

	assert_eq(_cast_alternative(engine), "")

	assert_true(engine.game_state().object(servo_id).is_tapped)


func test_a_copy_and_a_replay_keep_paying_the_alternative_cost() -> void:
	var engine: MmEngine = _hero_main(_elves(4, [_lamp()]))
	engine.submit(Scenario.cast_index_alternative(engine.pending_decision() as PriorityDecision, _djinn(engine)))
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Lamp")])

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	var payment: PayManaDecision = copy.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [3, [W]])
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func _djinn(engine: MmEngine) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), "Djinn")


## Casts the Djinn for its alternative cost, tapping the first artifact it may, and pays
## automatically.
func _cast_alternative(engine: MmEngine) -> String:
	var index: int = Scenario.cast_index_alternative(engine.pending_decision() as PriorityDecision, _djinn(engine))
	if index == -1:
		return "The Djinn cannot be cast for its alternative cost."
	var error: String = engine.submit(index)
	var tapping: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	if error == "" and tapping != null:
		error = engine.submit([tapping.candidate_ids[0]])
	return error if error != "" else Scenario.auto_pay(engine)


## [param count] Elves, then [param more].
func _elves(count: int, more: Array[MmCardDefinition] = []) -> Array[MmCardDefinition]:
	var elves: Array[MmCardDefinition] = []
	for index: int in count:
		elves.append(Scenario.elf())
	elves.append_array(more)
	return elves


func _lamp() -> MmCardDefinition:
	return Scenario.artifact("Lamp", [])


## The Hero's precombat main phase on Game Turn 3 with [param hero_permanents], and a Djinn
## and [param more_hand] in hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], more_hand: Array[MmCardDefinition] = []) -> MmEngine:
	var none: Array[MmCardDefinition] = []
	var hand: Array[MmCardDefinition] = [Scenario.djinn()]
	hand.append_array(more_hand)
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, none, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, none, hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
