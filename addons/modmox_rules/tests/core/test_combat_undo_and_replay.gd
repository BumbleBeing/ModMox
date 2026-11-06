extends GutTest
## ADR 0015 and ADR 0010 applied to combat: combat choices can be undone until the other
## player decides, copies of the state keep combat and damage, and replays reproduce a
## combat exactly.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_declaring_attackers_can_be_undone() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_bear()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var before: String = engine.fingerprint()
	Scenario.declare_attackers(engine, [bear])

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is DeclareAttackersDecision)
	assert_false(engine.game_state().object(bear).is_tapped)
	assert_false(engine.game_state().combat.is_attacking(bear))


func test_attacks_cannot_be_undone_once_the_defender_has_a_decision() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_bear()])
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Bear"))

	Scenario.pass_priority(engine)

	assert_false(engine.can_undo())


func test_a_damage_division_can_be_undone() -> void:
	var engine: MmEngine = Scenario.combat_ready([_sturdy("Ogre", 3)], [_sturdy("Bear", 2), _sturdy("Bear", 2)])
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	var bears: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [ogre])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bears[0], ogre], [bears[1], ogre]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	var before: String = engine.fingerprint()
	engine.submit([3, 0])

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is DivideCombatDamageDecision)
	assert_eq(engine.submit([0, 3]), "")
	assert_eq(Scenario.damage_on(engine, bears[1]), 3)


func test_a_copy_of_the_state_keeps_combat_damage_and_summoning_sickness() -> void:
	var engine: MmEngine = Scenario.combat_ready([_sturdy("Bear", 2)], [_sturdy("Ogre", 3)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	var original: MmGameState = engine.game_state()

	var copy: MmGameState = original.duplicate_state()

	assert_eq(copy.fingerprint(), original.fingerprint())
	assert_eq(copy.object(bear).damage_marked, 3)
	assert_eq(copy.object(ogre).damage_marked, 2)
	assert_true(copy.combat.is_attacking(bear))
	assert_eq(copy.combat.blockers_of(copy, bear), [ogre])
	assert_eq(copy.object(bear).controlled_since_game_turn, 1)
	assert_eq(copy.player(engine.villain().id).latest_turn_game_turn, 2)
	copy.perform(CombatEndedEvent.new())
	assert_true(original.combat.is_attacking(bear), "Changing the copy leaves the original alone.")


func test_the_fingerprint_sees_marked_damage() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_ogre()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	var copy: MmGameState = engine.game_state().duplicate_state()

	copy.perform(DamageEvent.new(ogre, MmReference.to_object(ogre), 1))

	assert_ne(copy.fingerprint(), engine.game_state().fingerprint())


func test_replaying_a_combat_reproduces_the_state_exactly() -> void:
	var hero_creatures: Array[MmCardDefinition] = [_ogre()]
	var villain_creatures: Array[MmCardDefinition] = [_bear(), _bear()]
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures)
	var original: MmEngine = Scenario.combat_ready_with(setup, hero_creatures, villain_creatures)
	var ogre: int = Scenario.permanent_named(original, original.hero().id, "Ogre")
	var bears: Array[int] = Scenario.permanents_named(original, original.villain().id, "Bear")
	Scenario.declare_attackers(original, [ogre])
	Scenario.pass_to_blockers(original)
	Scenario.declare_blockers(original, [[bears[0], ogre], [bears[1], ogre]])
	Scenario.pass_until_step(original, Step.COMBAT_DAMAGE)
	original.submit([1, 2])
	Scenario.play_until_game_turn(original, 4)

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


## A creature that survives any damage in these tests.
func _sturdy(card_name: String, power: int) -> MmCardDefinition:
	return Scenario.creature(card_name, power, 10)
