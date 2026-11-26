extends GutTest
## "As an additional cost to cast this spell, return a permanent you control to its owner's
## hand." (CR 601.2f, 118.8), as Fear of Isolation's: an AdditionalCostAbility of the spell
## with a ReturnPermanentsCost. The cast is offered only while the cost can be paid. Its
## choice is asked once the mana is paid (CR 601.2g-h), so a permanent just tapped for mana
## may be returned, and the permanent stays returned whatever becomes of the spell.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## How many spells had been cast when the Hero's main phase of Game Turn 3 began.
var _casts_before_turn_three: int = 0


func test_it_is_not_offered_with_no_permanent_to_return() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.isolation()], [Scenario.creature("Ogre", 3, 3)])

	var isolation: int = Scenario.card_in_hand(engine, engine.hero(), "Isolation")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, isolation), -1,
		"The Villain's Ogre is not a permanent the Hero controls.")


func test_casting_asks_which_permanent_and_returns_it() -> void:
	var charm: MmCardDefinition = Scenario.enchantment("Charm", [])
	var engine: MmEngine = _hero_main([_bear(), charm], [Scenario.isolation()], [Scenario.creature("Ogre", 3, 3)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var charm_id: int = Scenario.permanent_named(engine, engine.hero().id, "Charm")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Isolation")), "")

	var asked: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(asked, "The cost asks which permanent.")
	assert_eq(asked.purpose, ChoosePermanentsDecision.Purpose.RETURN_TO_HAND)
	assert_eq(asked.count, 1)
	assert_eq(asked.candidate_ids, [bear, charm_id] as Array[int], "Any permanent the Hero controls, and only theirs.")
	assert_eq(engine.submit([bear]), "")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear"), [] as Array[int])
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1, "Returned to its owner's hand.")
	assert_eq(Scenario.events_of(engine, SpellCastEvent).size(), _casts_before_turn_three + 1, "Paid, so it is cast.")


func test_the_choice_comes_after_the_mana_so_a_permanent_tapped_for_it_may_be_returned() -> void:
	var paid: MmCardDefinition = Scenario.isolation("Isolation", Scenario.mana_cost(1))
	var engine: MmEngine = _hero_main([Scenario.mana_bird("Mana Bird", 1)], [paid])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Isolation")), "")

	assert_true(engine.game_state().object(bird).is_tapped, "CR 601.2g: the mana first.")
	var asked: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(asked)
	assert_eq(asked.candidate_ids, [bird] as Array[int])
	assert_eq(engine.submit([bird]), "")
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Mana Bird"), -1)


func test_canceling_at_the_pick_returns_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.isolation()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Isolation")), "")

	assert_eq(engine.cancel_cast(), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Bear"), bear)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Isolation"), -1)


func test_a_countered_spell_leaves_its_cost_paid() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.isolation(), Scenario.free_counter("Negate")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Isolation")), "")
	assert_eq(engine.submit([bear]), "")
	var isolation: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Negate"), [MmReference.to_object(isolation)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Isolation"), -1, "Countered.")
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1, "CR 601.2h: the cost stays paid.")


func test_a_replay_returns_the_same_permanent() -> void:
	var bears: Array[MmCardDefinition] = [_bear(), _bear()]
	var hand: Array[MmCardDefinition] = [Scenario.isolation()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(bears, no_cards, hand)
	var engine: MmEngine = _hero_main_from(setup, bears, hand, no_cards)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Isolation")), "")
	var second: int = Scenario.permanents_named(engine, engine.hero().id, "Bear")[1]
	assert_eq(engine.submit([second]), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_additional_costs.tres"
	assert_eq(ResourceSaver.save(Scenario.isolation(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var additional: AdditionalCostAbility = loaded.abilities[0] as AdditionalCostAbility
	assert_not_null(additional)
	var returning: ReturnPermanentsCost = additional.costs[0] as ReturnPermanentsCost
	assert_eq(returning.count, 1)
	assert_true(returning.filter is ControlledByFilter)
	DirAccess.remove_absolute(path)


# --- Exiling a card from the graveyard (Makeshift Mauler) ---------------------------------


func test_an_exile_cost_is_not_offered_with_no_creature_card_in_the_graveyard() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.mauler()])

	var mauler: int = Scenario.card_in_hand(engine, engine.hero(), "Mauler")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, mauler), -1)


func test_casting_asks_which_card_to_exile_and_exiles_it() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.mauler(), _husk()])
	assert_eq(Scenario.cast_and_resolve(engine, "Husk"), "")
	var husk: int = Scenario.card_in_graveyard(engine, engine.hero(), "Husk")
	assert_ne(husk, -1, "The 0/0 Husk died as it entered.")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mauler")), "")

	var asked: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	assert_not_null(asked, "The cost asks which card, once the mana is paid.")
	assert_eq(asked.purpose, ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD)
	assert_eq(asked.candidates.size(), 1)
	assert_eq(asked.candidates[0].id, husk)
	assert_eq(engine.submit(0), "")
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Husk"), -1)
	assert_eq(Scenario.events_of(engine, SpellCastEvent).size(), _casts_before_turn_three + 2, "Paid, so it is cast.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Mauler"), -1)


func test_canceling_at_the_exile_pick_exiles_nothing() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.mauler(), _husk()])
	assert_eq(Scenario.cast_and_resolve(engine, "Husk"), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mauler")), "")

	assert_eq(engine.cancel_cast(), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Husk"), -1)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Mauler"), -1)


func test_a_replay_exiles_the_same_card() -> void:
	var hand: Array[MmCardDefinition] = [Scenario.mauler(), _husk(), _husk("Second Husk")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, hand)
	var engine: MmEngine = _hero_main_from(setup, no_cards, hand, no_cards)
	assert_eq(Scenario.cast_and_resolve(engine, "Husk"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Husk"), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mauler")), "")
	assert_eq(engine.submit(1), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


# --- Helpers ---------------------------------------------------------------------------


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## A 0/0 creature costing {0}, which dies as it enters and so puts a creature card into its
## owner's graveyard.
func _husk(card_name: String = "Husk") -> MmCardDefinition:
	return Scenario.creature(card_name, 0, 0)


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	return _hero_main_from(setup, hero_permanents, hand, villain_permanents)


func _hero_main_from(setup: MmEncounterSetup, hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	_casts_before_turn_three = Scenario.events_of(engine, SpellCastEvent).size()
	return engine
