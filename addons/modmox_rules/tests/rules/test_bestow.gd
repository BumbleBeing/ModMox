extends GutTest
## Bestow (CR 702.103, engine ADR 0089): a card with "Bestow [cost]" may be cast from the hand
## for that cost as an Aura spell with enchant creature, which is no creature. It resolves
## attached to its target, or as an enchantment creature if that target is gone; once it
## becomes unattached it is an enchantment creature again, still on the battlefield. Naiads
## are 2/2 Enchantment Creature — Nymphs with "Bestow {0}", flying and "Enchanted creature
## gets +2/+2 and has flying"; Elves tap for {W}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_the_hand_offers_it_both_as_a_creature_and_bestowed() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.naiad()])
	var naiad: int = Scenario.card_in_hand(engine, engine.hero(), "Naiad")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_ne(Scenario.cast_index_bestowed(decision, naiad, false), -1)
	assert_ne(Scenario.cast_index_bestowed(decision, naiad), -1, "CR 702.103a: bestowed, offered after it.")
	assert_true(Scenario.cast_index_bestowed(decision, naiad) > Scenario.cast_index_bestowed(decision, naiad, false))


func test_with_no_creature_to_enchant_it_is_offered_only_as_a_creature() -> void:
	var none: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main(none, [Scenario.naiad()])
	var naiad: int = Scenario.card_in_hand(engine, engine.hero(), "Naiad")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_ne(Scenario.cast_index_bestowed(decision, naiad, false), -1)
	assert_eq(Scenario.cast_index_bestowed(decision, naiad), -1, "CR 601.2c: an Aura spell needs its target.")


func test_bestowed_on_the_stack_it_is_an_aura_spell_that_is_no_creature() -> void:
	# CR 702.103b: it becomes an Aura enchantment with enchant creature and loses the
	# creature type and its creature subtypes. Its mana value is still its mana cost's.
	var engine: MmEngine = _hero_main([_bear(), Scenario.elf()], [Scenario.naiad("Naiad", Scenario.mana_cost(1))])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "")

	var spell: MmCharacteristics = Scenario.now(engine, Scenario.stack_ids(engine)[0])
	assert_eq(spell.card_types, [CardType.ENCHANTMENT] as Array[CardType])
	assert_true(spell.has_subtype("Aura"))
	assert_false(spell.has_subtype("Nymph"))
	assert_true(spell.has_ability(EnchantAbility))
	assert_eq(spell.mana_value(), 1)


func test_it_resolves_attached_and_enchanted_creature_gets_its_bonus() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.naiad()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var naiad: int = Scenario.permanent_named(engine, engine.hero().id, "Naiad")
	assert_eq(Scenario.attached_to(engine, naiad), bear)
	assert_false(Scenario.now(engine, naiad).has_card_type(CardType.CREATURE), "A bestowed Aura is no creature.")
	assert_true(Scenario.now(engine, naiad).has_subtype("Aura"))
	assert_eq(Scenario.pt(engine, bear), [4, 4])
	assert_true(Scenario.now(engine, bear).has_ability(FlyingAbility))


func test_it_costs_its_bestow_cost_rather_than_its_mana_cost() -> void:
	var naiad: MmCardDefinition = Scenario.naiad("Naiad", Scenario.mana_cost(1), Scenario.mana_cost(2))
	var engine: MmEngine = _hero_main([_bear(), Scenario.elf(), Scenario.elf()], [naiad])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var card: int = Scenario.card_in_hand(engine, engine.hero(), "Naiad")

	assert_eq(engine.submit(Scenario.cast_index_bestowed(engine.pending_decision() as PriorityDecision, card)), "")
	assert_eq(Scenario.choose_target(engine, _object(bear)), "")

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq(payment.remaining_generic, 2, "CR 118.9: an alternative cost, paid instead of {1}.")


func test_cost_reductions_take_mana_off_its_bestow_cost() -> void:
	var discount: MmCardDefinition = Scenario.creature("Discount", 1, 1, [Scenario.spells_cost_less(1, 0)])
	var naiad: MmCardDefinition = Scenario.naiad("Naiad", Scenario.mana_cost(1), Scenario.mana_cost(2))
	var engine: MmEngine = _hero_main([discount, _bear(), Scenario.elf()], [naiad])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "",
		"CR 601.2f: {1} less takes {2} to {1}, which the one Elf pays.")


func test_if_its_target_is_gone_it_resolves_as_an_enchantment_creature() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.naiad(), Scenario.free_bounce("Bounce")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var naiad: int = Scenario.permanent_named(engine, engine.hero().id, "Naiad")
	assert_ne(naiad, -1, "CR 702.103e: it ceases to be bestowed and resolves as an enchantment creature spell.")
	assert_eq(Scenario.attached_to(engine, naiad), 0)
	assert_true(Scenario.now(engine, naiad).has_card_type(CardType.CREATURE))
	assert_true(Scenario.now(engine, naiad).has_subtype("Nymph"))
	assert_eq(Scenario.pt(engine, naiad), [2, 2])


func test_once_the_creature_it_enchants_leaves_it_stays_on_the_battlefield_as_a_creature() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.naiad(), Scenario.free_bounce("Bounce")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var naiad: int = Scenario.permanent_named(engine, engine.hero().id, "Naiad")

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [_object(bear)]), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Naiad"), naiad,
		"CR 702.103f: it becomes unattached and ceases to be bestowed, the same object, not put into a graveyard.")
	assert_eq(Scenario.attached_to(engine, naiad), 0)
	assert_true(Scenario.now(engine, naiad).has_card_type(CardType.CREATURE))
	assert_false(Scenario.now(engine, naiad).has_subtype("Aura"))
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Naiad"), -1)


func test_a_bestowed_aura_entering_is_no_creature_entering() -> void:
	var watcher: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(
		Scenario.enters(Scenario.of_type(CardType.CREATURE)), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([_bear(), watcher], [Scenario.naiad()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life, "It entered as an Aura.")


func test_a_copy_and_a_replay_keep_it_bestowed() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.naiad()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_bestowed(engine, Scenario.card_in_hand(engine, engine.hero(), "Naiad"), _object(bear)), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_true(Scenario.now(copy, Scenario.stack_ids(copy)[0]).has_subtype("Aura"))
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_bestow.tres"
	assert_eq(ResourceSaver.save(Scenario.naiad("Naiad", null, Scenario.mana_cost(4, [MmMana.Type.BLUE])), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var bestow: BestowAbility = loaded.abilities[0] as BestowAbility
	assert_eq([bestow.mana_cost.generic, bestow.mana_cost.symbols], [4, [MmMana.Type.BLUE]])
	DirAccess.remove_absolute(path)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, none, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, none, hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
