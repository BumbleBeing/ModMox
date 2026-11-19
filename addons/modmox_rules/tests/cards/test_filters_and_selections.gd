extends GutTest
## Filters combine with AllOf, AnyOf and Not; effects reach players and objects only
## through Selections, so "target" and "each" are a data change (ADR 0014).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_all_of_any_of_and_not_combine_conditions() -> void:
	var engine: MmEngine = _engine_with_one_forest()
	var state: MmGameState = engine.game_state()
	var forest: MmReference = MmReference.to_object(state.battlefield.object_ids()[0])
	var hero: MmReference = MmReference.to_player(engine.hero().id)
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var land: HasCardTypeFilter = HasCardTypeFilter.new()
	land.card_type = MmCardTypes.CardType.LAND
	var land_or_player: AnyOfFilter = AnyOfFilter.new()
	land_or_player.filters = [land, IsPlayerFilter.new()]
	var not_player: NotFilter = NotFilter.new()
	not_player.filter = IsPlayerFilter.new()
	var untapped_land: MmFilter = Scenario.untapped_land()

	assert_true(land_or_player.matches(state, forest, context))
	assert_true(land_or_player.matches(state, hero, context))
	assert_true(not_player.matches(state, forest, context))
	assert_false(not_player.matches(state, hero, context))
	assert_true(untapped_land.matches(state, forest, context))
	assert_false(untapped_land.matches(state, hero, context))
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, forest.id))
	assert_false(untapped_land.matches(state, forest, context), "Tapped now, so not an untapped land.")


func test_an_effect_targets_only_when_it_uses_a_target_selection() -> void:
	assert_true(Scenario.deal_damage(3, Scenario.targeted(0)).has_targets())
	assert_false(Scenario.deal_damage(3, Scenario.each(IsPlayerFilter.new())).has_targets())
	assert_false(Scenario.deal_damage(3, YouSelection.new()).has_targets())


func test_swapping_target_for_each_turns_a_targeted_spell_into_one_that_hits_everything() -> void:
	# The shape of an "overload" Modification: no target requirements, "each" instead of "target".
	var overloaded: MmCardDefinition = Scenario.bolt()
	var ability: SpellAbility = overloaded.abilities[0] as SpellAbility
	ability.targets = []
	(ability.effects[0] as DealDamageEffect).recipients = Scenario.each(IsPlayerFilter.new())
	var engine: MmEngine = Scenario.find_engine(
		Scenario.setup_with(Scenario.deck_of(Scenario.basic_land("Mountain"), 20, overloaded, 20), Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Bolt"))
	var spell_id: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")

	assert_eq(Scenario.cast(engine, spell_id), "", "No target decision is asked.")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().life, 17)
	assert_eq(engine.villain().life, 17)


func test_a_mana_value_filter_compares_the_total_of_a_cards_mana_cost() -> void:
	# CR 202.3: {2}{W} has mana value 3, and a land has none, so 0.
	var three: MmCardDefinition = Scenario.creature("Three", 2, 2, [], Scenario.mana_cost(2, [MmMana.Type.WHITE]))
	var four: MmCardDefinition = Scenario.creature("Four", 3, 3, [], Scenario.mana_cost(4))
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.cycled([three, four, Scenario.basic_land("Plains")]),
		Scenario.cycled([])))
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var by_name: Dictionary[String, MmReference] = {}
	for card: MmGameObject in engine.hero().library.objects():
		by_name[state.characteristics_of(card).name] = MmReference.to_object(card.id)
	var three_or_less: ManaValueFilter = Scenario.mana_value(3)
	var four_or_greater: ManaValueFilter = Scenario.mana_value(4, ManaValueFilter.Comparison.OR_GREATER)

	assert_true(three_or_less.matches(state, by_name["Three"], context), "In any zone, here a library.")
	assert_false(three_or_less.matches(state, by_name["Four"], context))
	assert_true(three_or_less.matches(state, by_name["Plains"], context))
	assert_false(four_or_greater.matches(state, by_name["Three"], context))
	assert_true(four_or_greater.matches(state, by_name["Four"], context))
	assert_false(three_or_less.matches(state, MmReference.to_player(engine.hero().id), context), "A player has no mana value.")
	assert_true(Scenario.is_not(four_or_greater).matches(state, by_name["Three"], context))


func test_a_power_filter_compares_a_creatures_power_in_any_zone() -> void:
	# CR 208.1: only a creature has power, so nothing else is "with power 2 or less".
	var cub: MmCardDefinition = Scenario.creature("Cub", 2, 2)
	var brute: MmCardDefinition = Scenario.creature("Brute", 3, 3)
	var shifter: MmCardDefinition = Scenario.creature("Shifter", 0, 0)
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = Scenario.constant(5)
	defining.toughness = Scenario.constant(5)
	shifter.abilities = [defining]
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.cycled([cub, brute, shifter, Scenario.basic_land("Plains")]),
		Scenario.cycled([])))
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var by_name: Dictionary[String, MmReference] = {}
	for card: MmGameObject in engine.hero().library.objects():
		by_name[state.characteristics_of(card).name] = MmReference.to_object(card.id)
	var two_or_less: PowerFilter = Scenario.power(2)
	var three_or_greater: PowerFilter = Scenario.power(3, PowerFilter.Comparison.OR_GREATER)

	assert_true(two_or_less.matches(state, by_name["Cub"], context), "In any zone, here a library.")
	assert_false(two_or_less.matches(state, by_name["Brute"], context))
	assert_true(three_or_greater.matches(state, by_name["Brute"], context))
	assert_false(three_or_greater.matches(state, by_name["Cub"], context))
	assert_false(two_or_less.matches(state, by_name["Plains"], context), "A land has no power.")
	assert_false(two_or_less.matches(state, by_name["Shifter"], context), "CR 604.3: its power is 5 in every zone.")
	assert_true(three_or_greater.matches(state, by_name["Shifter"], context))
	assert_false(two_or_less.matches(state, MmReference.to_player(engine.hero().id), context), "A player has no power.")


func test_a_toughness_filter_compares_a_creatures_toughness_in_any_zone() -> void:
	# CR 208.1: only a creature has toughness, so nothing else is "with toughness 4 or greater".
	var wall: MmCardDefinition = Scenario.creature("Wall", 2, 4)
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 2)
	var glass: MmCardDefinition = Scenario.creature("Glass", 5, 1)
	var shifter: MmCardDefinition = Scenario.creature("Shifter", 0, 0)
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = Scenario.constant(5)
	defining.toughness = Scenario.constant(5)
	shifter.abilities = [defining]
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.cycled([wall, cub, glass, shifter, Scenario.basic_land("Plains")]), Scenario.cycled([])))
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var by_name: Dictionary[String, MmReference] = {}
	for card: MmGameObject in engine.hero().library.objects():
		by_name[state.characteristics_of(card).name] = MmReference.to_object(card.id)
	var two_or_less: ToughnessFilter = Scenario.toughness(2)
	var four_or_greater: ToughnessFilter = Scenario.toughness(4, ToughnessFilter.Comparison.OR_GREATER)

	assert_true(two_or_less.matches(state, by_name["Cub"], context), "In any zone, here a library.")
	assert_false(two_or_less.matches(state, by_name["Wall"], context))
	assert_true(four_or_greater.matches(state, by_name["Wall"], context))
	assert_false(four_or_greater.matches(state, by_name["Cub"], context))
	assert_false(four_or_greater.matches(state, by_name["Glass"], context), "Its power is 5, but its toughness 1.")
	assert_true(two_or_less.matches(state, by_name["Glass"], context))
	assert_false(two_or_less.matches(state, by_name["Plains"], context), "A land has no toughness.")
	assert_true(four_or_greater.matches(state, by_name["Shifter"], context), "CR 604.3: its toughness is 5 in every zone.")
	assert_false(two_or_less.matches(state, MmReference.to_player(engine.hero().id), context), "A player has no toughness.")
	assert_true(Scenario.is_not(four_or_greater).matches(state, by_name["Cub"], context))


func _engine_with_one_forest() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.play_first_land(engine)
	return engine
