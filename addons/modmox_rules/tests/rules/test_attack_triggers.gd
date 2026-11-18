extends GutTest
## "Whenever one or more creatures [whose] control attack": triggers once as attackers are
## declared, however many attack (CR 508.1, 603.2c), and never when none do. "The number of
## attacking creatures" is counted as the ability resolves (CR 608.2h).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_three_attackers_trigger_it_once_and_gain_three_life() -> void:
	var engine: MmEngine = _combat_ready([_banner(Whose.YOU), _bear("Ant"), _bear("Bee"), _bear("Cat")], [])

	Scenario.declare_attackers(engine, _hero_creatures(engine))

	assert_eq(Scenario.stacked_abilities(engine).size(), 1, "CR 603.2c: one event, one trigger.")
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 23)


func test_declaring_no_attackers_triggers_nothing() -> void:
	var engine: MmEngine = _combat_ready([_banner(Whose.YOU), _bear("Ant")], [])

	Scenario.declare_attackers(engine, [])

	assert_eq(Scenario.stacked_abilities(engine).size(), 0)
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)


func test_an_opponents_attack_triggers_only_an_ability_watching_opponents() -> void:
	var engine: MmEngine = _combat_ready([_banner(Whose.YOU), _gain_on_attack("Horn", Whose.OPPONENT)], [_bear("Wolf")])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	Scenario.play_until_step(engine, 4, Step.DECLARE_ATTACKERS)

	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.villain().id, "Wolf")])

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].source_name, "Horn")


func test_the_attackers_are_counted_as_it_resolves() -> void:
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 2)
	var engine: MmEngine = _combat_ready([_banner(Whose.YOU), _bear("Ant"), _bear("Bee")], [], [shock])
	var ant: int = Scenario.permanent_named(engine, engine.hero().id, "Ant")
	Scenario.declare_attackers(engine, _hero_creatures(engine))

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(ant)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 21, "CR 608.2h: Ant died before the ability resolved.")


func test_attacking_matches_only_creatures_that_are_attacking() -> void:
	var engine: MmEngine = _combat_ready([_bear("Ant"), _bear("Bee")], [_bear("Wolf")])
	var ant: int = Scenario.permanent_named(engine, engine.hero().id, "Ant")
	var bee: int = Scenario.permanent_named(engine, engine.hero().id, "Bee")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, ant)
	assert_false(IsAttackingFilter.new().matches(engine.game_state(), MmReference.to_object(ant), context),
		"Nothing attacks before attackers are declared.")

	Scenario.declare_attackers(engine, [ant])

	var filter: IsAttackingFilter = IsAttackingFilter.new()
	assert_true(filter.matches(engine.game_state(), MmReference.to_object(ant), context))
	assert_false(filter.matches(engine.game_state(), MmReference.to_object(bee), context))
	assert_false(filter.matches(engine.game_state(), MmReference.to_player(engine.hero().id), context))


## Path of Bravery's second ability, on an artifact costing {0}: "Whenever one or more
## creatures [whose] control attack, you gain life equal to the number of attacking
## creatures."
func _banner(whose: Whose) -> MmCardDefinition:
	return _gain_on_attack("Banner", whose)


func _gain_on_attack(card_name: String, whose: Whose) -> MmCardDefinition:
	var trigger: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	trigger.whose = whose
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each_creature(IsAttackingFilter.new())
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = count
	gain.players = Scenario.you()
	return Scenario.artifact(card_name, [Scenario.triggered(trigger, [gain])])


func _bear(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


func _combat_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _hero_creatures(engine: MmEngine) -> Array[int]:
	var found: Array[int] = []
	for game_object: MmGameObject in engine.game_state().battlefield.objects():
		if game_object.controller_id == engine.hero().id and game_object.definition.card_types.has(MmCardTypes.CardType.CREATURE):
			found.append(game_object.id)
	return found
