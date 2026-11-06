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


func _engine_with_one_forest() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.play_first_land(engine)
	return engine
