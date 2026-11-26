extends GutTest
## Filters combine with AllOf, AnyOf and Not; effects reach players and objects only
## through Selections, so "target" and "each" are a data change (ADR 0014).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_player_filter_with_whose_matches_you_or_an_opponent() -> void:
	# "Target opponent", as Mardu Skullhunter says.
	var engine: MmEngine = _engine_with_one_forest()
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var hero: MmReference = MmReference.to_player(engine.hero().id)
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	var forest: MmReference = MmReference.to_object(state.battlefield.object_ids()[0])
	var opponent: IsPlayerFilter = IsPlayerFilter.new()
	opponent.whose = MmTrigger.Whose.OPPONENT
	var you: IsPlayerFilter = IsPlayerFilter.new()
	you.whose = MmTrigger.Whose.YOU

	assert_true(opponent.matches(state, villain, context))
	assert_false(opponent.matches(state, hero, context))
	assert_false(opponent.matches(state, forest, context))
	assert_true(you.matches(state, hero, context))
	assert_false(you.matches(state, villain, context))
	assert_true(IsPlayerFilter.new().matches(state, villain, context), "Any player, unless told whose.")


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


func test_each_opponent_is_every_player_but_the_controller() -> void:
	var engine: MmEngine = _engine_with_one_forest()
	var state: MmGameState = engine.game_state()
	var each_opponent: EachOpponentSelection = EachOpponentSelection.new()

	var of_hero: Array[MmReference] = each_opponent.select(state, MmEffectContext.new(engine.hero().id, 0))
	var of_villain: Array[MmReference] = each_opponent.select(state, MmEffectContext.new(engine.villain().id, 0))

	assert_eq(of_hero.size(), 1)
	assert_true(of_hero[0].is_player() and of_hero[0].id == engine.villain().id)
	assert_eq(of_villain.size(), 1)
	assert_true(of_villain[0].is_player() and of_villain[0].id == engine.hero().id, "ADR 0005: relative to the controller.")
	assert_false(each_opponent.is_targeted())


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


func test_a_mana_value_filter_may_compare_with_a_value_instead() -> void:
	var engine: MmEngine = _engine_with_mana_values()
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var by_name: Dictionary[String, MmReference] = _library_by_name(engine)
	var three_or_less: ManaValueFilter = Scenario.mana_value_from(Scenario.constant(3))
	var four_or_greater: ManaValueFilter = Scenario.mana_value_from(Scenario.constant(4), ManaValueFilter.Comparison.OR_GREATER)

	assert_true(three_or_less.matches(state, by_name["Three"], context))
	assert_false(three_or_less.matches(state, by_name["Four"], context))
	assert_true(three_or_less.matches(state, by_name["Plains"], context), "A land's mana value is 0.")
	assert_false(three_or_less.matches(state, MmReference.to_player(engine.hero().id), context))
	assert_false(four_or_greater.matches(state, by_name["Three"], context))
	assert_true(four_or_greater.matches(state, by_name["Four"], context))


func test_a_value_given_to_a_mana_value_filter_is_used_instead_of_its_amount() -> void:
	var engine: MmEngine = _engine_with_mana_values()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var filter: ManaValueFilter = Scenario.mana_value_from(Scenario.constant(2))
	filter.amount = 9

	assert_false(filter.matches(engine.game_state(), _library_by_name(engine)["Three"], context), "2, not 9.")


func test_a_mana_value_filter_reads_its_value_each_time_it_is_asked() -> void:
	# The X paid is the X of the ability resolving (ADR 0061), so the same Filter answers
	# differently in two contexts, and with none paid X is 0.
	var engine: MmEngine = _engine_with_mana_values()
	var state: MmGameState = engine.game_state()
	var by_name: Dictionary[String, MmReference] = _library_by_name(engine)
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var x_or_less: ManaValueFilter = Scenario.mana_value_from(Scenario.paid_x())

	assert_false(x_or_less.matches(state, by_name["Three"], context.with_paid_x(2)))
	assert_true(x_or_less.matches(state, by_name["Three"], context.with_paid_x(3)))
	assert_false(x_or_less.matches(state, by_name["Three"], context), "None paid is 0.")
	assert_false(x_or_less.matches(state, by_name["Three"], null), "Nor with no context.")
	assert_true(x_or_less.matches(state, by_name["Plains"], null))


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


func test_a_toughness_filter_may_compare_with_a_value_instead_of_its_amount() -> void:
	var wall: MmCardDefinition = Scenario.creature("Wall", 2, 4)
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 2)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.cycled([wall, cub, Scenario.basic_land("Plains")]), Scenario.cycled([])))
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var by_name: Dictionary[String, MmReference] = {}
	for card: MmGameObject in engine.hero().library.objects():
		by_name[state.characteristics_of(card).name] = MmReference.to_object(card.id)
	var two_or_less: ToughnessFilter = Scenario.toughness_from(Scenario.constant(2))
	two_or_less.amount = 9
	var less_than_four: NotFilter = Scenario.is_not(
		Scenario.toughness_from(Scenario.constant(4), ToughnessFilter.Comparison.OR_GREATER))

	assert_true(two_or_less.matches(state, by_name["Cub"], context))
	assert_false(two_or_less.matches(state, by_name["Wall"], context), "2, not 9.")
	assert_false(two_or_less.matches(state, by_name["Plains"], context), "A land has no toughness.")
	assert_false(two_or_less.matches(state, MmReference.to_player(engine.hero().id), context))
	assert_true(less_than_four.matches(state, by_name["Cub"], context), "Less than 4 is not 4 or greater.")
	assert_false(less_than_four.matches(state, by_name["Wall"], context))


func test_a_power_filter_may_compare_with_a_value_instead_of_its_amount() -> void:
	var brute: MmCardDefinition = Scenario.creature("Brute", 4, 2)
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 2)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.cycled([brute, cub, Scenario.basic_land("Plains")]), Scenario.cycled([])))
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var by_name: Dictionary[String, MmReference] = {}
	for card: MmGameObject in engine.hero().library.objects():
		by_name[state.characteristics_of(card).name] = MmReference.to_object(card.id)
	var two_or_less: PowerFilter = Scenario.power_from(Scenario.constant(2))
	two_or_less.amount = 9
	var three_or_greater: PowerFilter = Scenario.power_from(Scenario.constant(3), PowerFilter.Comparison.OR_GREATER)

	assert_true(two_or_less.matches(state, by_name["Cub"], context))
	assert_false(two_or_less.matches(state, by_name["Brute"], context), "2, not 9.")
	assert_true(three_or_greater.matches(state, by_name["Brute"], context))
	assert_false(three_or_greater.matches(state, by_name["Cub"], context))
	assert_false(two_or_less.matches(state, by_name["Plains"], context), "A land has no power.")
	assert_false(two_or_less.matches(state, MmReference.to_player(engine.hero().id), context))


## A Hero whose library holds a creature with mana value 3, one with 4, and a Plains.
func _engine_with_mana_values() -> MmEngine:
	var three: MmCardDefinition = Scenario.creature("Three", 2, 2, [], Scenario.mana_cost(2, [MmMana.Type.WHITE]))
	var four: MmCardDefinition = Scenario.creature("Four", 3, 3, [], Scenario.mana_cost(4))
	return MmEngine.start(Scenario.setup_with(Scenario.cycled([three, four, Scenario.basic_land("Plains")]),
		Scenario.cycled([])))


func _library_by_name(engine: MmEngine) -> Dictionary[String, MmReference]:
	var by_name: Dictionary[String, MmReference] = {}
	for card: MmGameObject in engine.hero().library.objects():
		by_name[engine.game_state().characteristics_of(card).name] = MmReference.to_object(card.id)
	return by_name


func _engine_with_one_forest() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.play_first_land(engine)
	return engine
