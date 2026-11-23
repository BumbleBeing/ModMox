extends GutTest
## "As long as there are seven or more cards in your graveyard" (threshold, as on Most
## Decrepit Old Bird): a ValueAtLeastCondition over CardsInZoneValue, which counts the cards
## in its controller's graveyard as they are now (engine ADR 0080).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_with_six_cards_in_your_graveyard_it_is_a_one_one_and_with_seven_a_two_two() -> void:
	var engine: MmEngine = _bird_ready()
	var bird: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Old Bird"))

	assert_eq(Scenario.cast_and_resolve(engine, "Mill Five"), "")
	assert_eq(engine.hero().graveyard.size(), 6, "Five milled, then the spell.")
	assert_eq(_pt(engine, bird), [1, 1])

	assert_eq(Scenario.cast_and_resolve(engine, "Mill None"), "")
	assert_eq(engine.hero().graveyard.size(), 7)
	assert_eq(_pt(engine, bird), [2, 2], "Threshold.")


func test_cards_in_an_opponents_graveyard_do_not_count() -> void:
	var engine: MmEngine = _bird_ready()
	var bird: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Old Bird"))

	assert_eq(Scenario.cast_and_resolve(engine, "Opponent Mill"), "")

	assert_gte(engine.villain().graveyard.size(), 9)
	assert_eq(_pt(engine, bird), [1, 1])


func test_the_value_counts_whose_graveyard_it_is_told() -> void:
	var engine: MmEngine = _bird_ready()
	Scenario.cast_and_resolve(engine, "Opponent Mill")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)

	assert_eq(Scenario.cards_in_graveyard().evaluate(engine.game_state(), context), 1)
	var theirs: int = engine.villain().graveyard.size()
	assert_eq(Scenario.cards_in_graveyard(MmTrigger.Whose.OPPONENT).evaluate(engine.game_state(), context), theirs,
		"Nine milled, and any the Villain discarded at cleanup.")
	assert_true(Scenario.at_least(Scenario.cards_in_graveyard(MmTrigger.Whose.OPPONENT), theirs).is_true(engine.game_state(), context))
	assert_false(Scenario.at_least(Scenario.cards_in_graveyard(MmTrigger.Whose.OPPONENT), theirs + 1).is_true(engine.game_state(), context))
	assert_false(Scenario.at_least(Scenario.cards_in_graveyard(), 2).is_true(engine.game_state(), context))


## The Hero in their main phase on Game Turn 3 with Old Bird on the battlefield, holding
## Mill Five, Mill None and Opponent Mill (each opponent mills nine).
func _bird_ready() -> MmEngine:
	var bird: Array[MmCardDefinition] = [Scenario.threshold_bird()]
	var extras: Array[MmCardDefinition] = [Scenario.free_mill("Mill Five", 5), Scenario.free_mill("Mill None", 0),
		Scenario.free_mill("Opponent Mill", 9, true)]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(bird, no_cards, extras), bird, no_cards,
		extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _pt(engine: MmEngine, permanent: MmGameObject) -> Array[int]:
	var seen: MmCharacteristics = engine.game_state().characteristics_of(permanent)
	return [seen.power, seen.toughness]
