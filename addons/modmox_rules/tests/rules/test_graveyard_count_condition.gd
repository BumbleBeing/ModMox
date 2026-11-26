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


func test_a_filtered_count_counts_only_the_cards_that_match_each_once() -> void:
	# Chitin Gravestalker's "for each artifact and/or creature card in your graveyard": an
	# artifact creature card is one card, counted once (engine ADR 0080's addendum).
	var held: Array[MmCardDefinition] = [Scenario.creature("Husk", 0, 0), _artifact_creature("Scrap Husk"),
		Scenario.free_mill("Mill None", 0), Scenario.free_mill("Opponent Mill", 9, true)]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, no_cards, held), no_cards,
		no_cards, held, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	var artifact_or_creature: AnyOfFilter = Scenario.any_of([Scenario.of_type(MmCardTypes.CardType.ARTIFACT),
		Scenario.of_type(MmCardTypes.CardType.CREATURE)])
	var counted: CardsInZoneValue = Scenario.cards_in_graveyard(MmTrigger.Whose.YOU, artifact_or_creature)
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)

	for card_name: String in ["Husk", "Scrap Husk", "Mill None", "Opponent Mill"]:
		assert_eq(Scenario.cast_and_resolve(engine, card_name), "")
		assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().graveyard.size(), 4, "Two 0/0s died, and two instants resolved.")
	assert_eq(counted.evaluate(engine.game_state(), context), 2, "The instants are not counted.")
	assert_eq(Scenario.cards_in_graveyard().evaluate(engine.game_state(), context), 4, "No filter counts every card.")
	assert_eq(Scenario.cards_in_graveyard(MmTrigger.Whose.OPPONENT, artifact_or_creature).evaluate(engine.game_state(), context),
		_creatures_in(engine.villain().graveyard, engine), "The opponent's own are theirs alone.")


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


## A 0/0 artifact creature costing {0}, which dies as it enters.
func _artifact_creature(card_name: String) -> MmCardDefinition:
	var husk: MmCardDefinition = Scenario.creature(card_name, 0, 0)
	husk.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	return husk


## How many of [param pile]'s cards are artifacts or creatures.
func _creatures_in(pile: MmZone, engine: MmEngine) -> int:
	var count: int = 0
	for card: MmGameObject in pile.objects():
		var seen: MmCharacteristics = engine.game_state().characteristics_of(card)
		if seen.card_types.has(MmCardTypes.CardType.ARTIFACT) or seen.card_types.has(MmCardTypes.CardType.CREATURE):
			count += 1
	return count
