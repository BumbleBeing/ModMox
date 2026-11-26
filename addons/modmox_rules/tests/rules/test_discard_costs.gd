extends GutTest
## "Discard a card" as part of an activated ability's cost (DiscardCardsCost, CR 701.9a,
## 118), as a Blood token's "{1}, {T}, Discard a card, Sacrifice this token: Draw a card."
## (CR 111.10g). CastProcedure asks which card as it asks an ability's other costs, before
## the mana (CR 601.2h), and only when there is a choice: a hand of exactly that many cards
## is discarded whole. The ability is offered only while the hand holds enough cards
## (CR 118.3). Vial is an artifact costing {0} with "{1}, Discard a card: Draw a card.", and
## the Mana Bird pays its {1}; Pit is an artifact costing {0} with "{0}: Discard a card.",
## which empties a hand.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_card_to_discard_is_asked_and_discarded_as_it_is_paid() -> void:
	var engine: MmEngine = _hero_main()
	var hand: Array[int] = engine.hero().hand.object_ids()
	assert_gt(hand.size(), 1, "A choice of which card.")

	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _vial(engine))), "")

	var discard: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(discard, "CR 601.2h: which card to discard.")
	assert_eq(discard.count, 1)
	assert_eq(discard.candidate_ids, hand, "Any card in hand.")
	var graveyard: int = engine.hero().graveyard.size()
	assert_eq(engine.submit([hand[1]]), "")
	assert_false(engine.hero().hand.object_ids().has(hand[1]), "Discarded as it is paid.")
	assert_eq(engine.hero().hand.size(), hand.size() - 1, "That card alone.")
	assert_eq(engine.hero().graveyard.size(), graveyard + 1)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.DISCARD)
	assert_true(engine.pending_decision() is PayManaDecision, "Then the mana.")

	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.stack_ids(engine).size(), 1, "Paid, so it is activated.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().hand.size(), hand.size(), "One discarded, one drawn.")


func test_an_illegal_pick_is_refused_and_changes_nothing() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _vial(engine))), "")
	var hand: Array[int] = engine.hero().hand.object_ids()
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([] as Array[int]), "", "Too few.")
	assert_ne(engine.submit([hand[0], hand[1]]), "", "Too many.")
	assert_ne(engine.submit([_vial(engine)]), "", "Not a card in hand.")
	assert_ne(engine.submit(0), "", "Not a list.")

	assert_eq(engine.fingerprint(), before)


func test_canceling_at_the_pick_discards_nothing() -> void:
	var engine: MmEngine = _hero_main()
	var hand: Array[int] = engine.hero().hand.object_ids()
	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _vial(engine))), "")

	assert_eq(engine.cancel_cast(), "")

	assert_eq(engine.hero().hand.object_ids(), hand)


func test_a_hand_of_one_card_is_discarded_without_a_question() -> void:
	var engine: MmEngine = _hero_main()
	_discard_down_to(engine, 1)
	var graveyard: int = engine.hero().graveyard.size()

	assert_eq(Scenario.activate(engine, _vial(engine)), "")

	assert_eq(engine.hero().hand.size(), 0, "Its one card, unasked.")
	assert_eq(engine.hero().graveyard.size(), graveyard + 1)
	assert_eq(Scenario.stack_ids(engine).size(), 1)


func test_it_is_offered_only_while_the_hand_holds_a_card() -> void:
	var engine: MmEngine = _hero_main()
	_discard_down_to(engine, 1)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _vial(engine)), -1)

	_discard_down_to(engine, 0)

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _vial(engine)), -1,
		"CR 118.3: an empty hand cannot pay.")


func test_a_replay_discards_the_same_card() -> void:
	var setup: MmEncounterSetup = _setup()
	var engine: MmEngine = _hero_main_from(setup)
	var hand: Array[int] = engine.hero().hand.object_ids()
	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, _vial(engine))), "")
	assert_eq(engine.submit([hand[1]]), "")
	assert_eq(Scenario.auto_pay(engine), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(replayed.hero().hand.object_ids(), engine.hero().hand.object_ids())
	assert_false(replayed.hero().hand.object_ids().has(hand[1]))


## Activates the Pit until the Hero holds [param count] cards.
func _discard_down_to(engine: MmEngine, count: int) -> void:
	var pit: int = Scenario.permanent_named(engine, engine.hero().id, "Pit")
	while engine.hero().hand.size() > count:
		assert_eq(Scenario.activate(engine, pit), "")
		assert_eq(Scenario.resolve_stack(engine), "")


func _vial(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Vial")


func _permanents() -> Array[MmCardDefinition]:
	var drawing: ActivatedAbility = ActivatedAbility.new()
	drawing.mana_cost = Scenario.mana_cost(1)
	drawing.costs = [Scenario.discard_cards_cost()]
	drawing.effects = [Scenario.draw_cards(1, Scenario.you())]
	var discarding: ActivatedAbility = ActivatedAbility.new()
	discarding.effects = [Scenario.discard(1, Scenario.you())]
	return [Scenario.artifact("Vial", [drawing]), Scenario.artifact("Pit", [discarding]), Scenario.mana_bird()]


func _setup() -> MmEncounterSetup:
	return Scenario.combat_setup(_permanents(), [] as Array[MmCardDefinition], [] as Array[MmCardDefinition])


## The Hero in their main phase of Game Turn 3 with the Vial, the Pit and the Bird cast on
## Game Turn 1.
func _hero_main() -> MmEngine:
	return _hero_main_from(_setup())


func _hero_main_from(setup: MmEncounterSetup) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, _permanents(), no_cards, no_cards, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
