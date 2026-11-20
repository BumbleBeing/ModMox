extends GutTest
## A cost reduction by a Value (CR 601.2f, 118.7a, ADR 0050): Leyline Binding's "This spell
## costs {1} less to cast for each basic land type among lands you control." It takes that
## much generic mana off the cost as the cast begins, never colored mana, and the spell is
## offered only when the reduced cost can be paid. The Hero's only mana is the lands a
## free_land_fetch() puts onto the battlefield.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_it_costs_one_generic_mana_less_for_each_basic_land_type() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest", "Forest", "Forest"]), "")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _binding(engine)))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [3, [W]], "CR 601.2f: two types take {2} off {5}{W}.")


func test_without_mana_for_the_reduced_cost_it_is_not_offered() -> void:
	var engine: MmEngine = _hero_main()

	assert_eq(Scenario.fetch_lands(engine, ["Forest", "Forest", "Plains"]), "")

	assert_false(Scenario.offers_cast(engine, _binding(engine)), "Two types leave {3}{W}, and three lands cannot pay it.")


func test_with_all_five_basic_land_types_only_the_colored_mana_is_paid() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Island", "Swamp", "Mountain", "Forest"]), "")

	assert_eq(Scenario.cast(engine, _binding(engine)), "")

	assert_eq(_tapped_lands(engine), 1, "CR 118.7a: {5}{W} less five is {W}.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, 21)


func test_only_lands_the_caster_controls_count() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest"]), "")
	var card: MmGameObject = engine.game_state().object(_binding(engine))

	var to_pay: MmManaCost = CastProcedure.mana_to_pay(engine.game_state(), engine.villain().id, card)

	assert_eq(to_pay.generic, 5, "The Hero's lands are not the Villain's.")


func test_its_mana_value_is_unchanged() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest"]), "")

	var card: MmGameObject = engine.game_state().object(_binding(engine))

	assert_eq(engine.game_state().characteristics_of(card).mana_value(), 6, "CR 202.3: only the mana cost counts.")


func test_a_negative_value_takes_nothing_off() -> void:
	var ability: CostReductionAbility = Scenario.cost_reduction(Scenario.constant(-2))
	var engine: MmEngine = _hero_main()
	var card: MmGameObject = engine.game_state().object(_binding(engine))

	var reduced: MmManaCost = ability.reduction(engine.game_state(), card, engine.hero().id)

	assert_eq([reduced.generic, reduced.symbols], [0, []], "CR 107.1b: a negative number is treated as 0.")


func test_a_copy_and_a_replay_pay_the_reduced_cost() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest", "Forest", "Forest"]), "")
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _binding(engine)))
	engine.submit(0)

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	var payment: PayManaDecision = copy.pending_decision() as PayManaDecision
	assert_eq(payment.remaining_generic + payment.remaining_symbols.size(), 3)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func _binding(engine: MmEngine) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), "Binding")


## How many of the Hero's lands are tapped.
func _tapped_lands(engine: MmEngine) -> int:
	var tapped: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == engine.hero().id and permanent.is_tapped \
				and engine.game_state().characteristics_of(permanent).has_card_type(MmCardTypes.CardType.LAND):
			tapped += 1
	return tapped


## Stops in the Hero's precombat main phase of Game Turn 3 with a free_land_fetch() and a
## domain_reduced_instant() in hand. The lands it may find are in the Hero's library: each
## basic, and two more Forests.
func _hero_main() -> MmEngine:
	var in_hand: Array[MmCardDefinition] = [Scenario.free_land_fetch(),
		Scenario.domain_reduced_instant("Binding", Scenario.mana_cost(5, [W]))]
	var lands: Array[MmCardDefinition] = [Scenario.basic_land("Plains"), Scenario.basic_land("Island"),
		Scenario.basic_land("Swamp"), Scenario.basic_land("Mountain"), Scenario.basic_land("Forest"),
		Scenario.basic_land("Forest"), Scenario.basic_land("Forest")]
	var no_cards: Array[MmCardDefinition] = []
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(none, none, in_hand + lands)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, none, none, in_hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
