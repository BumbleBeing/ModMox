extends GutTest
## A cost reduction on an activated ability (CR 602.2b, 601.2f, 118.7a, ADR 0050): Jodah's
## Codex's "{5}, {T}: Draw a card. This ability costs {1} less to activate for each basic
## land type among lands you control." The generic mana it takes off is fixed as the
## activation begins, and the ability is offered only when the reduced cost can be paid.
## The Hero's only mana is the lands a free_land_fetch() puts onto the battlefield.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_it_costs_one_generic_mana_less_for_each_basic_land_type() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex()], [])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest", "Forest"]), "")

	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _codex(engine)))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [3, []], "CR 602.2b: two types take {2} off {5}.")


func test_lands_tapped_to_pay_it_still_count() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex()], [])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest", "Forest"]), "")
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.activate(engine, _codex(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_tapped_lands(engine), 3, "The cost was fixed at {3} as the activation began.")
	assert_eq(engine.hero().hand.size(), hand + 1)


func test_without_mana_for_the_reduced_cost_it_is_not_offered() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex()], [])

	assert_eq(Scenario.fetch_lands(engine, ["Forest", "Forest", "Forest"]), "")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _codex(engine)), -1,
		"One type leaves {4}, and three lands cannot pay it.")


func test_with_all_five_basic_land_types_only_the_tap_is_paid() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex()], [])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Island", "Swamp", "Mountain", "Forest"]), "")
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.activate(engine, _codex(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_tapped_lands(engine), 0, "CR 118.7a: {5} less five is {0}.")
	assert_true(engine.game_state().object(_codex(engine)).is_tapped)
	assert_eq(engine.hero().hand.size(), hand + 1)


func test_only_lands_its_controller_controls_count() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.codex()])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest"]), "")
	var villains: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.villain().id, "Codex"))
	var ability: ActivatedAbility = engine.game_state().characteristics_of(villains).abilities[0] as ActivatedAbility

	var to_pay: MmManaCost = ability.mana_to_pay(engine.game_state(), villains)

	assert_eq(to_pay.generic, 5, "The Hero's lands are not the Villain's.")


func test_the_reduction_never_takes_off_colored_mana() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex(Scenario.mana_cost(1, [W]))], [])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest"]), "")

	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _codex(engine)))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [0, [W]], "CR 118.7a: generic mana only.")


func test_an_ability_with_no_reduction_costs_its_printed_mana() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex(null, false)], [])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Island", "Swamp", "Mountain", "Forest"]), "")

	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _codex(engine)))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq(payment.remaining_generic, 5)


func test_a_copy_and_a_replay_pay_the_reduced_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.codex()], [])
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest", "Forest"]), "")
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _codex(engine)))
	engine.submit(0)

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq((copy.pending_decision() as PayManaDecision).remaining_generic, 2)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func _codex(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Codex")


## How many of the Hero's lands are tapped.
func _tapped_lands(engine: MmEngine) -> int:
	var tapped: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == engine.hero().id and permanent.is_tapped \
				and engine.game_state().characteristics_of(permanent).has_card_type(MmCardTypes.CardType.LAND):
			tapped += 1
	return tapped


## Stops in the Hero's precombat main phase of Game Turn 3 with [param hero_permanents] and
## [param villain_permanents] in play and a free_land_fetch() in hand. The lands it may find
## are in the Hero's library: each basic, and two more Forests.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition]) -> MmEngine:
	var fetch: Array[MmCardDefinition] = [Scenario.free_land_fetch()]
	var lands: Array[MmCardDefinition] = [Scenario.basic_land("Plains"), Scenario.basic_land("Island"),
		Scenario.basic_land("Swamp"), Scenario.basic_land("Mountain"), Scenario.basic_land("Forest"),
		Scenario.basic_land("Forest"), Scenario.basic_land("Forest")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, fetch + lands)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, fetch, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
