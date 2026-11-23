extends GutTest
## Exalted (CR 702.83a): "Whenever a creature you control attacks alone, that creature gets
## +1/+1 until end of turn." A creature attacks alone when it is the only creature declared
## as an attacker (CR 506.5), and each instance of exalted triggers on its own (CR 702.83b).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_attacking_alone_gets_plus_one_plus_one() -> void:
	var engine: MmEngine = _combat_ready([Scenario.squire(), _bear()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.declare_attackers(engine, [bear]), "")

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_true(stacked[0].ability is ExaltedAbility)
	assert_eq(stacked[0].triggering_object_id, bear, "\"That creature\" is the attacker.")
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, bear), [3, 3])


func test_the_bonus_lasts_until_end_of_turn() -> void:
	var engine: MmEngine = _combat_ready([Scenario.squire(), _bear()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])
	Scenario.resolve_stack(engine)

	Scenario.play_until_step(engine, 4, Step.UPKEEP)

	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_the_exalted_creature_itself_attacking_alone_gets_the_bonus() -> void:
	var engine: MmEngine = _combat_ready([Scenario.squire(), _bear()], [])
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")

	Scenario.declare_attackers(engine, [squire])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.pt(engine, squire), [2, 2])


func test_two_attackers_trigger_nothing() -> void:
	var engine: MmEngine = _combat_ready([Scenario.squire(), _bear()], [])
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.declare_attackers(engine, [squire, bear])

	assert_eq(Scenario.stacked_abilities(engine).size(), 0, "CR 506.5: neither attacks alone.")
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_declaring_no_attackers_triggers_nothing() -> void:
	var engine: MmEngine = _combat_ready([Scenario.squire()], [])

	Scenario.declare_attackers(engine, [])

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)


func test_two_exalted_permanents_each_trigger() -> void:
	# CR 702.83b.
	var engine: MmEngine = _combat_ready([Scenario.squire("Ann"), Scenario.squire("Ben"), _bear()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.declare_attackers(engine, [bear])

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 2)
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, bear), [4, 4])


func test_an_opponents_creature_attacking_alone_triggers_nothing() -> void:
	var engine: MmEngine = _combat_ready([Scenario.squire()], [_bear("Wolf")])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	Scenario.play_until_step(engine, 4, Step.DECLARE_ATTACKERS)
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")

	Scenario.declare_attackers(engine, [wolf])

	assert_eq(Scenario.stacked_abilities(engine).size(), 0, "Only a creature you control.")
	assert_eq(Scenario.pt(engine, wolf), [2, 2])


func test_a_token_entering_attacking_beside_a_lone_attacker_takes_nothing_away() -> void:
	# CR 506.5: the Bear was the only creature declared as an attacker; the Cat never was.
	var engine: MmEngine = _combat_ready([Scenario.squire(), _bear()], [], [Scenario.free_ambush()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Ambush"), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 1)
	assert_eq(Scenario.pt(engine, bear), [3, 3])


func test_exalted_is_saved_with_its_card() -> void:
	var path: String = "user://test_exalted.tres"
	assert_eq(ResourceSaver.save(Scenario.squire(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var exalted: ExaltedAbility = loaded.abilities[0] as ExaltedAbility
	assert_not_null(exalted)
	assert_true((exalted.trigger as AttackersDeclaredTrigger).alone)
	assert_eq(exalted.effects.size(), 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _bear(card_name: String = "Bear") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


func _combat_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
