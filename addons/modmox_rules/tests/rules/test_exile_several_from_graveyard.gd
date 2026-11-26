extends GutTest
## "Exile three cards from your graveyard" (CR 701.13a), as Kessig Wolfrider's cost: an
## ExileFromGraveyardCost with a count. It can be paid only while the payer's graveyard
## holds that many matching cards, and its choice is asked once for each card, each card
## exiled as it is chosen (CR 601.2h), so each pick is among the cards still there.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_it_is_not_offered_while_the_graveyard_holds_fewer_cards() -> void:
	var engine: MmEngine = _hero_main([], [_mauler(), _husk("Husk A"), _husk("Husk B")])
	assert_eq(Scenario.cast_and_resolve(engine, "Husk A"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Husk B"), "")

	var mauler: int = Scenario.card_in_hand(engine, engine.hero(), "Mauler")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, mauler), -1)


func test_it_asks_once_for_each_card_and_exiles_each_as_it_is_chosen() -> void:
	var engine: MmEngine = _hero_main([], [_mauler(), _husk("Husk A"), _husk("Husk B"), _husk("Husk C")])
	for husk: String in ["Husk A", "Husk B", "Husk C"]:
		assert_eq(Scenario.cast_and_resolve(engine, husk), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mauler")), "")

	var sizes: Array[int] = []
	var before: Array[int] = []
	for pick: int in 3:
		var asked: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
		assert_not_null(asked, "Pick %d is asked." % pick)
		if asked == null:
			return
		assert_eq(asked.purpose, ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD)
		sizes.append(asked.candidates.size())
		before.append(asked.exiled_before)
		assert_eq(asked.exile_count, 3)
		assert_eq(engine.submit(0), "")

	assert_eq(sizes, [3, 2, 1] as Array[int], "Each card is exiled as it is chosen.")
	assert_eq(before, [0, 1, 2] as Array[int])
	for husk: String in ["Husk A", "Husk B", "Husk C"]:
		assert_ne(Scenario.card_in_exile(engine, engine.hero(), husk), -1, husk + " is exiled.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Mauler"), -1, "Paid, so it was cast.")


func test_canceling_at_the_second_pick_puts_the_first_card_back() -> void:
	var engine: MmEngine = _hero_main([], [_mauler(), _husk("Husk A"), _husk("Husk B"), _husk("Husk C")])
	for husk: String in ["Husk A", "Husk B", "Husk C"]:
		assert_eq(Scenario.cast_and_resolve(engine, husk), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mauler")), "")
	assert_eq(engine.submit(0), "")

	assert_eq(engine.cancel_cast(), "")

	for husk: String in ["Husk A", "Husk B", "Husk C"]:
		assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), husk), -1, husk + " is back in the graveyard.")
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Mauler"), -1)


func test_an_activated_ability_with_it_is_paid_the_same_way() -> void:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, YouSelection.new())]
	var costs: Array[MmCost] = [Scenario.exile_from_graveyard(null, 2)]
	var rider: MmCardDefinition = Scenario.creature("Rider", 1, 2, [Scenario.activated(Scenario.mana_cost(0), costs, gain)])
	var engine: MmEngine = _hero_main([rider], [_husk("Husk A"), _husk("Husk B")])
	var rider_id: int = Scenario.permanent_named(engine, engine.hero().id, "Rider")
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, rider_id), -1,
		"Nothing in the graveyard yet.")
	assert_eq(Scenario.cast_and_resolve(engine, "Husk A"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Husk B"), "")
	var life: int = engine.hero().life

	assert_eq(Scenario.activate(engine, rider_id), "")
	assert_eq(engine.submit(0), "")
	assert_eq(engine.submit(0), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1)
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Husk A"), -1)
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Husk B"), -1)


func test_a_replay_exiles_the_same_cards() -> void:
	var hand: Array[MmCardDefinition] = [_mauler(), _husk("Husk A"), _husk("Husk B"), _husk("Husk C"), _husk("Husk D")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	for husk: String in ["Husk A", "Husk B", "Husk C", "Husk D"]:
		assert_eq(Scenario.cast_and_resolve(engine, husk), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mauler")), "")
	for pick: int in [3, 0, 1]:
		assert_eq(engine.submit(pick), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


# --- Helpers ---------------------------------------------------------------------------


## A 4/5 costing {0} with "As an additional cost to cast this spell, exile three creature
## cards from your graveyard."
func _mauler() -> MmCardDefinition:
	var costs: Array[MmCost] = [Scenario.exile_from_graveyard(null, 3)]
	return Scenario.creature("Mauler", 4, 5, [Scenario.additional_cost(costs)])


## A 0/0 creature costing {0}, which dies as it enters and so puts a creature card into its
## owner's graveyard.
func _husk(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 0, 0)


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand].
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
