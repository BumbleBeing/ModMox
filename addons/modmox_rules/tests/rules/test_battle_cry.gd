extends GutTest
## Battle cry (CR 702.91a): "Whenever this creature attacks, each other attacking creature
## gets +1/+0 until end of turn." Each instance triggers on its own (CR 702.91b).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_each_other_attacking_creature_gets_plus_one_plus_zero() -> void:
	var engine: MmEngine = _combat_ready([_crier(), _bear("Ann"), _bear("Ben")], [])
	var crier: int = Scenario.permanent_named(engine, engine.hero().id, "Crier")
	var ann: int = Scenario.permanent_named(engine, engine.hero().id, "Ann")
	var ben: int = Scenario.permanent_named(engine, engine.hero().id, "Ben")

	assert_eq(Scenario.declare_attackers(engine, [crier, ann, ben]), "")

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_true(stacked[0].ability is BattleCryAbility)
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, ann), [3, 2])
	assert_eq(Scenario.pt(engine, ben), [3, 2])
	assert_eq(Scenario.pt(engine, crier), [2, 1], "\"Each other\": not the creature with battle cry.")


func test_a_creature_that_stays_home_gets_nothing() -> void:
	var engine: MmEngine = _combat_ready([_crier(), _bear("Ann"), _bear("Ben")], [])
	var crier: int = Scenario.permanent_named(engine, engine.hero().id, "Crier")
	var ann: int = Scenario.permanent_named(engine, engine.hero().id, "Ann")
	var ben: int = Scenario.permanent_named(engine, engine.hero().id, "Ben")

	Scenario.declare_attackers(engine, [crier, ann])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.pt(engine, ann), [3, 2])
	assert_eq(Scenario.pt(engine, ben), [2, 2], "Only an attacking creature.")


func test_the_bonus_lasts_until_end_of_turn() -> void:
	var engine: MmEngine = _combat_ready([_crier(), _bear()], [])
	var crier: int = Scenario.permanent_named(engine, engine.hero().id, "Crier")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [crier, bear])
	Scenario.resolve_stack(engine)

	Scenario.play_until_step(engine, 4, Step.UPKEEP)

	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_attacking_alone_gives_nothing() -> void:
	var engine: MmEngine = _combat_ready([_crier(), _bear()], [])
	var crier: int = Scenario.permanent_named(engine, engine.hero().id, "Crier")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.declare_attackers(engine, [crier])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 1, "It still triggers.")
	assert_eq(Scenario.pt(engine, crier), [2, 1])
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_a_creature_with_battle_cry_that_does_not_attack_triggers_nothing() -> void:
	var engine: MmEngine = _combat_ready([_crier(), _bear()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.declare_attackers(engine, [bear])

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_two_battle_cries_each_give_the_other_and_a_third_attacker_both() -> void:
	# CR 702.91b.
	var engine: MmEngine = _combat_ready([_crier("Ann"), _crier("Ben"), _bear()], [])
	var ann: int = Scenario.permanent_named(engine, engine.hero().id, "Ann")
	var ben: int = Scenario.permanent_named(engine, engine.hero().id, "Ben")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.declare_attackers(engine, [ann, ben, bear])

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 2)
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.pt(engine, ann), [3, 1])
	assert_eq(Scenario.pt(engine, ben), [3, 1])
	assert_eq(Scenario.pt(engine, bear), [4, 2])


func test_a_token_entering_attacking_after_it_resolves_gets_nothing() -> void:
	# CR 611.2c: what the effect affects is fixed as it resolves.
	var engine: MmEngine = _combat_ready([_crier(), _bear()], [], [Scenario.free_ambush()])
	var crier: int = Scenario.permanent_named(engine, engine.hero().id, "Crier")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [crier, bear])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Ambush"), "")

	var cats: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(cats.size(), 1)
	assert_eq(Scenario.pt(engine, cats[0]), [1, 1])
	assert_eq(Scenario.pt(engine, bear), [3, 2])


func test_battle_cry_is_saved_with_its_card() -> void:
	var path: String = "user://test_battle_cry.tres"
	assert_eq(ResourceSaver.save(_crier(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var battle_cry: BattleCryAbility = loaded.abilities[0] as BattleCryAbility
	assert_not_null(battle_cry)
	assert_true(battle_cry.trigger is AttackersDeclaredTrigger)
	assert_eq(battle_cry.effects.size(), 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A 2/1 costing {0} with battle cry, as Sanguine Evangelist is.
func _crier(card_name: String = "Crier") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 1, [BattleCryAbility.new()])


func _bear(card_name: String = "Bear") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


func _combat_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
