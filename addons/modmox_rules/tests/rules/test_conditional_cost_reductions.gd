extends GutTest
## A cost reduction with a condition (CR 601.2f, 118.7a, engine ADR 0050's addendum):
## Gigastorm Titan's "This spell costs {3} less to cast if you've cast another spell this
## turn." It takes its generic mana off only while the condition is true as the cast begins,
## and the spell is offered only when the cost then to pay can be paid. Titans are 4/4s
## costing {4}{W}; Elves tap for {W}; a Gift is an instant costing {0}, "You gain 1 life."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_as_the_first_spell_of_the_turn_it_costs_its_whole_mana_cost() -> void:
	var engine: MmEngine = _hero_main(5)

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _titan(engine)))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [4, [W]], "No spell cast yet: nothing comes off.")


func test_after_another_spell_it_costs_three_generic_mana_less() -> void:
	var engine: MmEngine = _hero_main(5)
	assert_eq(_cast_gift(engine), "")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _titan(engine)))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [1, [W]], "CR 601.2f: {4}{W} less {3} is {1}{W}.")


func test_two_elves_cast_it_only_once_another_spell_was_cast() -> void:
	var engine: MmEngine = _hero_main(2)

	assert_false(Scenario.offers_cast(engine, _titan(engine)), "{4}{W} is more than two Elves pay.")
	assert_eq(_cast_gift(engine), "")
	assert_true(Scenario.offers_cast(engine, _titan(engine)), "{1}{W} is not.")
	assert_eq(Scenario.cast(engine, _titan(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Titan"), -1)


func test_the_titan_never_counts_as_the_other_spell() -> void:
	# The cost is fixed before the Titan is cast (CR 601.2f, 601.2i), so its own cast never
	# counts toward "another spell", in the hand or on the stack.
	var engine: MmEngine = _hero_main(5)
	var card: MmGameObject = engine.game_state().object(_titan(engine))
	var ability: CostReductionAbility = engine.game_state().characteristics_of(card).abilities[0] as CostReductionAbility

	assert_eq(ability.reduction(engine.game_state(), card, engine.hero().id).generic, 0)
	assert_eq(Scenario.cast(engine, _titan(engine)), "")
	var spell: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])
	assert_eq(ability.reduction(engine.game_state(), spell, engine.hero().id).generic, 0, "Cast now, it is the only spell.")


func test_its_mana_value_is_unchanged() -> void:
	var engine: MmEngine = _hero_main(2)
	assert_eq(_cast_gift(engine), "")

	var card: MmGameObject = engine.game_state().object(_titan(engine))

	assert_eq(engine.game_state().characteristics_of(card).mana_value(), 5, "CR 202.3: only the mana cost counts.")


func test_a_copy_and_a_replay_pay_the_reduced_cost() -> void:
	var engine: MmEngine = _hero_main(2)
	assert_eq(_cast_gift(engine), "")
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _titan(engine)))

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	var payment: PayManaDecision = copy.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [1, [W]])
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func _titan(engine: MmEngine) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), "Titan")


## Casts the Gift and lets it resolve.
func _cast_gift(engine: MmEngine) -> String:
	var error: String = Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift"))
	return error if error != "" else Scenario.resolve_stack(engine)


## The Hero's precombat main phase on Game Turn 3, with [param elves] Elves and a Titan and a
## Gift in hand.
func _hero_main(elves: int) -> MmEngine:
	var none: Array[MmCardDefinition] = []
	var permanents: Array[MmCardDefinition] = []
	for index: int in elves:
		permanents.append(Scenario.elf())
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var hand: Array[MmCardDefinition] = [Scenario.titan(), gift]
	var setup: MmEncounterSetup = Scenario.combat_setup(permanents, none, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, permanents, none, hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
