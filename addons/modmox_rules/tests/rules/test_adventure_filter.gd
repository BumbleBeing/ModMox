extends GutTest
## "A creature spell that has an Adventure" (CR 715.2), as Edgewall Innkeeper's "Whenever you
## cast a creature spell that has an Adventure, draw a card." An Adventurer card has an
## Adventure wherever it is, and cast as the creature it is a creature spell that has one; a
## spell cast as its Adventure has only the Adventure's characteristics (CR 715.3b), so it
## has none. Innkeeper is a 1/1 costing {0} with that ability; Guide is an Adventurer card
## whose Adventure is Gift, and Plain a 2/2 with no Adventure, each costing {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_casting_an_adventurer_as_the_creature_draws_a_card() -> void:
	var engine: MmEngine = _hero_main()
	var hand_before: int = engine.hero().hand.size()

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().hand.size(), hand_before, "Guide left the hand and a card was drawn.")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Guide"), -1)


func test_casting_it_as_its_adventure_draws_nothing() -> void:
	# CR 715.3b: the spell is the sorcery Gift alone, not a creature spell with an Adventure.
	var engine: MmEngine = _hero_main()
	var hand_before: int = engine.hero().hand.size()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"),
		MmReference.to_object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().hand.size(), hand_before - 1)


func test_casting_a_creature_with_no_adventure_draws_nothing() -> void:
	var engine: MmEngine = _hero_main()
	var hand_before: int = engine.hero().hand.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Plain"), "")

	assert_eq(engine.hero().hand.size(), hand_before - 1)


func test_casting_it_from_exile_on_an_adventure_draws_a_card() -> void:
	# CR 715.3d: cast from exile it is the creature, an Adventurer card still.
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))
	Scenario.resolve_stack(engine)
	var hand_before: int = engine.hero().hand.size()

	assert_eq(Scenario.cast(engine, engine.game_state().exile.objects()[0].id), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().hand.size(), hand_before + 1)
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Guide"), -1)


func test_an_adventurer_card_has_an_adventure_in_the_hand_and_on_the_battlefield() -> void:
	var engine: MmEngine = _hero_main()
	var filter: HasAdventureFilter = HasAdventureFilter.new()
	var in_hand: int = Scenario.card_in_hand(engine, engine.hero(), "Guide")

	assert_true(_matches(engine, filter, in_hand))
	assert_false(_matches(engine, filter, Scenario.card_in_hand(engine, engine.hero(), "Plain")))
	assert_false(_matches(engine, filter, Scenario.permanent_named(engine, engine.hero().id, "Bear")))

	assert_eq(Scenario.cast(engine, in_hand), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_true(_matches(engine, filter, Scenario.permanent_named(engine, engine.hero().id, "Guide")))


func test_a_player_has_no_adventure() -> void:
	var engine: MmEngine = _hero_main()

	assert_false(HasAdventureFilter.new().matches(engine.game_state(), MmReference.to_player(engine.hero().id),
		MmEffectContext.new(engine.hero().id, 0)))


func _matches(engine: MmEngine, filter: MmFilter, object_id: int) -> bool:
	return filter.matches(engine.game_state(), MmReference.to_object(object_id), MmEffectContext.new(engine.hero().id, object_id))


## The Hero's main phase on Game Turn 3 with Bear and Innkeeper in play, holding Guide and
## Plain.
func _hero_main() -> MmEngine:
	var creatures: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2), Scenario.innkeeper()]
	var extras: Array[MmCardDefinition] = [Scenario.adventurer(), Scenario.creature("Plain", 2, 2)]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(creatures, no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, creatures, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
