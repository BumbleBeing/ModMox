extends GutTest
## Cost reductions (CR 601.2f, 118.7, ADR 0050): a spell's total cost is its mana cost, or
## an alternative cost, less what its cost reductions take off, fixed as the cast begins.
## Affinity for Cats (CR 702.41a) takes {1} off for each Cat its caster controls. Mousers
## are 1/1 Cats, "{T}: Add {W}", and Elves "{T}: Add {W}" that are not Cats, so every mana
## the Hero has is white and comes from a creature.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const FixedCostReduction := preload("res://addons/modmox_rules/tests/support/fixed_cost_reduction.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_affinity_takes_one_generic_mana_off_for_each_cat_you_control() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser(), Scenario.elf()], [claws])
	var spell: int = Scenario.card_in_hand(engine, engine.hero(), "Claws")

	assert_true(Scenario.offers_cast(engine, spell), "CR 702.41a: two Cats make {3}{W}{W} cost {1}{W}{W}.")
	assert_eq(Scenario.cast(engine, spell), "")

	assert_eq(_tapped(engine), 3)
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 21)


func test_the_payment_asks_only_for_the_reduced_cost() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser(), Scenario.elf()], [claws])

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Claws")))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [1, [W, W]])


func test_with_too_few_cats_it_is_not_offered() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))

	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.elf(), Scenario.elf()], [claws])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Claws")),
		"One Cat leaves {2}{W}{W}, and three sources cannot pay it.")


func test_generic_mana_never_goes_below_zero_and_colored_mana_is_still_owed() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(1, [W, W]))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser(), Scenario.elf()], [claws])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Claws")), "")

	assert_eq(_tapped(engine), 2, "CR 118.7a: two Cats take {1} off {1}{W}{W}, and {W}{W} is left.")


func test_only_cats_on_the_battlefield_that_you_control_count() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(2, [W, W]))
	var hero_permanents: Array[MmCardDefinition] = [Scenario.elf(), Scenario.elf(), Scenario.elf()]

	var engine: MmEngine = _hero_main(hero_permanents, [claws, Scenario.mouser("Kitten")],
		[Scenario.mouser(), Scenario.mouser()])

	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Kitten"), -1)
	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Claws")),
		"CR 702.41a: the opponent's Cats, a Cat in hand and Elves count for nothing.")


func test_a_tapped_cat_still_counts() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser(), Scenario.elf()], [claws])
	assert_eq(Scenario.activate(engine, Scenario.permanents_named(engine, engine.hero().id, "Mouser")[0]), "")
	assert_eq(engine.hero().mana_pool().size(), 1)

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Claws")), "",
		"Affinity counts the Cats you control, tapped or not.")

	assert_eq(_tapped(engine), 3)
	assert_true(engine.hero().mana_pool().is_empty())


func test_its_mana_value_is_unchanged() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser(), Scenario.elf()], [claws])
	var spell: int = Scenario.card_in_hand(engine, engine.hero(), "Claws")
	assert_eq(Scenario.now(engine, spell).mana_value(), 5)

	Scenario.cast(engine, spell)

	assert_eq(Scenario.now(engine, Scenario.stack_ids(engine)[0]).mana_value(), 5, "CR 202.3: from its mana cost alone.")


func test_two_instances_of_affinity_each_take_their_amount_off() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))
	claws.abilities.push_front(Scenario.affinity(Scenario.has_subtype("Cat")))

	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.elf(), Scenario.elf()], [claws])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Claws")), "",
		"CR 702.41b: one Cat counted twice makes it {1}{W}{W}.")
	assert_eq(_tapped(engine), 3)


func test_a_flashback_cost_is_reduced_too() -> void:
	var echo: MmCardDefinition = Scenario.flashback_sorcery("Echo", [], [Scenario.gain_life(1, Scenario.you())],
		Scenario.flashback(Scenario.mana_cost(2, [W])))
	echo.abilities.append(Scenario.affinity(Scenario.has_subtype("Cat")))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser()], [echo])
	assert_eq(Scenario.cast_and_resolve(engine, "Echo"), "")
	var in_graveyard: int = Scenario.card_in_graveyard(engine, engine.hero(), "Echo")

	assert_eq(Scenario.cast(engine, in_graveyard), "")

	assert_eq(_tapped(engine), 1, "CR 601.2f: an alternative cost is reduced as a mana cost is, {2}{W} to {W}.")


func test_a_colored_reduction_takes_off_a_colored_symbol() -> void:
	var holy: MmCardDefinition = Scenario.instant("Holy", Scenario.mana_cost(1, [W, W]), [], [Scenario.gain_life(1, Scenario.you())])
	holy.abilities.push_front(_fixed(Scenario.mana_cost(0, [W])))

	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [holy])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Holy")), "",
		"CR 118.7b: {W} off {1}{W}{W} leaves {1}{W}.")
	assert_eq(_tapped(engine), 2)


func test_a_colored_reduction_the_cost_cannot_use_comes_off_generic_mana() -> void:
	var holy: MmCardDefinition = Scenario.instant("Holy", Scenario.mana_cost(2, [W]), [], [Scenario.gain_life(1, Scenario.you())])
	holy.abilities.push_front(_fixed(Scenario.mana_cost(0, [MmMana.Type.BLUE, MmMana.Type.BLUE])))

	var engine: MmEngine = _hero_main([Scenario.elf()], [holy])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Holy")), "",
		"CR 118.7b: {U}{U} off {2}{W}, which needs no blue, leaves {W}.")


func test_a_cost_reduced_to_nothing_is_cast_for_nothing() -> void:
	var holy: MmCardDefinition = Scenario.instant("Holy", Scenario.mana_cost(1, [W]), [], [Scenario.gain_life(1, Scenario.you())])
	holy.abilities.push_front(_fixed(Scenario.mana_cost(1, [W, W])))

	var engine: MmEngine = _hero_main([Scenario.elf()], [holy])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Holy")), "")
	assert_eq(_tapped(engine), 0, "CR 118.7: reduced to nothing, it costs {0}.")


func test_a_copy_and_a_replay_pay_the_reduced_cost() -> void:
	var claws: MmCardDefinition = Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [W, W]))
	var engine: MmEngine = _hero_main([Scenario.mouser(), Scenario.mouser(), Scenario.elf()], [claws])
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Claws")))
	engine.submit(0)

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq((copy.pending_decision() as PayManaDecision).remaining_generic
		+ (copy.pending_decision() as PayManaDecision).remaining_symbols.size(), 2)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


## A cost reduction that always takes [param amount] off.
func _fixed(amount: MmManaCost) -> CostReductionAbility:
	var ability: FixedCostReduction = FixedCostReduction.new()
	ability.amount = amount
	return ability


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## How many of the Hero's permanents are tapped.
func _tapped(engine: MmEngine) -> int:
	var tapped: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == engine.hero().id and permanent.is_tapped:
			tapped += 1
	return tapped
