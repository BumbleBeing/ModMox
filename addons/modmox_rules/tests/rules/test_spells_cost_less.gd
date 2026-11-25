extends GutTest
## A permanent's reduction of its controller's spells (CR 601.2f, 118.7, engine ADR 0050's
## addendum): "The second spell you cast each turn costs {1} less to cast", as Highspire
## Bell-Ringer says. Ringers are 1/4s with it; Elves tap for {W}, so every mana the Hero has
## comes from a creature, and Gifts are instants costing {1}, "You gain 1 life".

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE


func test_the_second_spell_you_cast_each_turn_costs_one_less() -> void:
	var engine: MmEngine = _hero_main([Scenario.ringer(), Scenario.elf()], [_gift("Gift"), _gift("Second Gift")])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(_tapped(engine), 1)
	var second: int = Scenario.card_in_hand(engine, engine.hero(), "Second Gift")

	assert_true(Scenario.offers_cast(engine, second), "With its only Elf tapped, {1} less leaves nothing to pay.")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Gift"), "")

	assert_eq(_tapped(engine), 1)
	assert_eq(engine.hero().life, 22)


func test_the_first_and_third_spells_cost_their_whole_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.ringer(), Scenario.elf(), Scenario.elf()],
		[_gift("Gift"), _gift("Second Gift"), _gift("Third Gift")])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(_tapped(engine), 1, "The first is not reduced.")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Gift"), "")
	assert_eq(_tapped(engine), 1)
	assert_eq(Scenario.cast_and_resolve(engine, "Third Gift"), "")

	assert_eq(_tapped(engine), 2, "Nor is the third.")


func test_the_spell_it_reduces_counts_spells_cast_before_it_was_on_the_battlefield() -> void:
	# The Ringer itself is the second spell, so the Gift cast after it is the third.
	var engine: MmEngine = _hero_main([Scenario.elf()], [_gift("Gift"), _gift("Second Gift"), Scenario.ringer()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Ringer"), "")

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Second Gift")))


func test_the_opponents_second_spell_costs_its_whole_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf()], [_gift("Gift"), _gift("Second Gift")], [Scenario.ringer()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Second Gift")),
		"Only its controller's spells cost less.")


func test_the_payment_asks_only_for_the_reduced_cost() -> void:
	var engine: MmEngine = _hero_main([Scenario.ringer(), Scenario.elf(), Scenario.elf()],
		[Scenario.instant("Gift", Scenario.mana_cost(0), [], []), _gift("Big Gift", Scenario.mana_cost(2, [W]))])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Big Gift")))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq([payment.remaining_generic, payment.remaining_symbols], [1, [W]])


func test_two_instances_each_take_their_amount_off() -> void:
	var engine: MmEngine = _hero_main([Scenario.ringer(), Scenario.ringer("Second Ringer"), Scenario.elf()],
		[_gift("Gift"), _gift("Big Gift", Scenario.mana_cost(2))])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Big Gift"), "", "Two Ringers take {2} off {2}.")

	assert_eq(_tapped(engine), 1)


func test_it_takes_off_generic_mana_only_and_colored_mana_is_still_owed() -> void:
	var engine: MmEngine = _hero_main([Scenario.ringer(), Scenario.elf()],
		[Scenario.instant("Gift", Scenario.mana_cost(0), [], []), _gift("White Gift", Scenario.mana_cost(0, [W]))])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(Scenario.cast_and_resolve(engine, "White Gift"), "")

	assert_eq(_tapped(engine), 1, "CR 118.7a: {1} less takes nothing off {W}.")


func test_a_flashback_cost_is_reduced_too() -> void:
	var echo: MmCardDefinition = Scenario.flashback_sorcery("Echo", [], [Scenario.gain_life(1, Scenario.you())],
		Scenario.flashback(Scenario.mana_cost(1, [W])))
	var engine: MmEngine = _hero_main([Scenario.ringer(), Scenario.elf(), Scenario.elf()], [echo])
	assert_eq(Scenario.cast_and_resolve(engine, "Echo"), "")
	var in_graveyard: int = Scenario.card_in_graveyard(engine, engine.hero(), "Echo")

	assert_eq(Scenario.cast(engine, in_graveyard), "")

	assert_eq(_tapped(engine), 1, "CR 601.2f: an alternative cost is reduced as a mana cost is, {1}{W} to {W}.")


func test_with_no_nth_every_spell_you_cast_costs_less() -> void:
	var discount: MmCardDefinition = Scenario.creature("Discount", 1, 1, [Scenario.spells_cost_less(1, 0)])
	var engine: MmEngine = _hero_main([discount, Scenario.elf()], [_gift("Gift"), _gift("Second Gift")])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Gift"), "")

	assert_eq(_tapped(engine), 0)


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_spells_cost_less.tres"
	assert_eq(ResourceSaver.save(Scenario.ringer(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var ability: SpellsCostLessAbility = loaded.abilities[0] as SpellsCostLessAbility
	assert_eq([ability.amount, ability.nth_each_turn], [1, 2])
	DirAccess.remove_absolute(path)


## An instant costing [param cost], {1} unless another is given: "You gain 1 life."
func _gift(card_name: String, cost: MmManaCost = null) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(1) if cost == null else cost, [],
		[Scenario.gain_life(1, Scenario.you())])


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
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
