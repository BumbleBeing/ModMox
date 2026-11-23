extends GutTest
## Adventurer cards (CR 715): a creature card with a second set of characteristics, its
## Adventure, an instant or sorcery. It may be cast as either from the hand; cast as its
## Adventure, the spell has only the Adventure's characteristics and, if it resolves, is
## exiled on an adventure, from where its owner may cast it as the creature (engine ADR 0078).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_its_hand_offers_casting_it_as_the_creature_then_as_its_adventure() -> void:
	var engine: MmEngine = _hero_main()
	var guide: int = Scenario.card_in_hand(engine, engine.hero(), "Guide")

	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var creature: int = Scenario.cast_index_as(decision, guide, false)
	assert_ne(creature, -1, "CR 715.3: it may be cast as the creature.")
	assert_eq(Scenario.cast_index_as(decision, guide, true), creature + 1, "ADR 0012: then as its Adventure.")


func test_in_hand_it_has_the_creatures_characteristics_and_carries_its_adventures() -> void:
	var engine: MmEngine = _hero_main()

	var seen: MmCharacteristics = engine.game_state().characteristics_of(
		engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Guide")))

	assert_eq([seen.name, seen.card_types, seen.power], ["Guide", [CardType.CREATURE], 1], "CR 715.4")
	assert_not_null(seen.adventure)
	assert_eq([seen.adventure.name, seen.adventure.card_types, seen.adventure.subtypes], ["Gift", [CardType.SORCERY], ["Adventure"]])


func test_each_way_costs_its_own_halfs_mana_cost() -> void:
	var white: MmManaCost = Scenario.mana_cost(0, [MmMana.Type.WHITE])
	var engine: MmEngine = _hero_main(Scenario.adventurer(white, Scenario.mana_cost(1, [MmMana.Type.WHITE])))
	var guide: MmGameObject = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Guide"))

	assert_eq(CastProcedure.mana_to_pay(engine.game_state(), engine.hero().id, guide).describe(), "{W}")
	assert_eq(CastProcedure.mana_to_pay(engine.game_state(), engine.hero().id, guide, true).describe(), "{1}{W}",
		"CR 715.3a: cast as its Adventure, it has only the Adventure's characteristics.")


func test_cast_as_its_adventure_the_spell_is_the_adventure_alone() -> void:
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear)), "")

	var spell: MmGameObject = engine.game_state().stack.objects()[0]
	var seen: MmCharacteristics = engine.game_state().characteristics_of(spell)
	assert_eq([seen.name, seen.card_types, seen.subtypes], ["Gift", [CardType.SORCERY], ["Adventure"]], "CR 715.3b")
	assert_false(seen.has_ability(FlyingAbility))
	assert_true(spell.is_adventure_spell)


func test_its_adventure_resolves_and_the_card_is_exiled_on_an_adventure() -> void:
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))

	assert_eq(Scenario.resolve_stack(engine), "")

	var bear_now: MmCharacteristics = engine.game_state().characteristics_of(engine.game_state().object(bear))
	assert_eq([bear_now.power, bear_now.toughness], [4, 3], "Gift resolved.")
	var exiled: Array[MmGameObject] = engine.game_state().exile.objects()
	assert_eq(exiled.size(), 1, "CR 715.3d: exiled instead of put into the graveyard.")
	assert_true(exiled[0].is_on_adventure)
	assert_eq(engine.game_state().characteristics_of(exiled[0]).name, "Guide", "CR 715.4: the creature again.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard), [] as Array[String])


func test_on_an_adventure_it_is_offered_as_the_creature_only_and_enters_as_one() -> void:
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))
	Scenario.resolve_stack(engine)
	var exiled: int = engine.game_state().exile.objects()[0].id

	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_ne(Scenario.cast_index_as(decision, exiled, false), -1, "CR 715.3d: its owner may cast it from exile.")
	assert_eq(Scenario.cast_index_as(decision, exiled, true), -1, "Not as an Adventure again.")
	assert_eq(Scenario.cast(engine, exiled), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var guide: int = Scenario.permanent_named(engine, engine.hero().id, "Guide")
	assert_ne(guide, -1)
	assert_true(engine.game_state().characteristics_of(engine.game_state().object(guide)).has_ability(FlyingAbility))
	assert_eq(engine.game_state().exile.size(), 0)


func test_cast_as_the_creature_from_the_hand_it_enters_as_the_creature() -> void:
	var engine: MmEngine = _hero_main()

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide")), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Guide"), -1)
	assert_eq(engine.game_state().exile.size(), 0)


func test_its_adventure_countered_goes_to_the_graveyard() -> void:
	var engine: MmEngine = _hero_main()
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))
	var spell: int = engine.game_state().stack.objects()[0].id

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Nope"), [MmReference.to_object(spell)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.game_state().exile.size(), 0, "CR 715.3d: only one that resolves is exiled.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard).count("Guide"), 1, "CR 715.4: the creature's name there.")


func test_the_players_views_show_its_adventure_and_that_it_is_on_one() -> void:
	var engine: MmEngine = _hero_main()
	var in_hand: MmObjectView = _view_of(engine.view_for(engine.hero()).hand, Scenario.card_in_hand(engine, engine.hero(), "Guide"))
	assert_not_null(in_hand.adventure)
	assert_eq([in_hand.adventure.name, in_hand.adventure.subtypes], ["Gift", ["Adventure"]])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear))
	assert_true(engine.view_for(engine.villain()).stack[0].is_adventure_spell, "Both players see how it was cast.")
	Scenario.resolve_stack(engine)

	var exiled: MmObjectView = engine.view_for(engine.villain()).exiles[engine.hero().id][0] as MmObjectView

	assert_true(exiled.is_on_adventure)
	assert_eq(exiled.name, "Guide")


func test_a_modification_changes_only_the_creature() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = Scenario.adventurer(Scenario.mana_cost(0, [MmMana.Type.WHITE]), Scenario.mana_cost(1, [MmMana.Type.WHITE]))
	var add_one: AddManaCostModification = AddManaCostModification.new()
	add_one.cost = Scenario.mana_cost(1)
	var rename: ChangeNameModification = ChangeNameModification.new()
	rename.new_name = "Guide Prime"
	run_card.modifications = [add_one, rename]

	var printed: MmCharacteristics = MmCharacteristics.printed(run_card.flatten())

	assert_eq([printed.name, printed.mana_cost.describe()], ["Guide Prime", "{1}{W}"])
	assert_eq([printed.adventure.name, printed.adventure.mana_cost.describe()], ["Gift", "{1}{W}"],
		"A Mod changes the front half only.")


## The Hero in their main phase on Game Turn 3 with Bear, a 2/2, on the battlefield, holding
## [param held] (Guide unless given) and Nope, an instant costing {0}: "Counter target spell."
func _hero_main(held: MmCardDefinition = null) -> MmEngine:
	var bear: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	var extras: Array[MmCardDefinition] = [Scenario.adventurer() if held == null else held, Scenario.free_counter("Nope")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(bear, no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, bear, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _view_of(views: Array[MmObjectView], object_id: int) -> MmObjectView:
	for view: MmObjectView in views:
		if view.id == object_id:
			return view
	return null
