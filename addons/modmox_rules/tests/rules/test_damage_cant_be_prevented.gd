extends GutTest
## "Damage can't be prevented this turn" (CR 615.12), as Stomp says: a
## DamageCantBePreventedEffect marks the Game Turn it resolves in, and until that turn ends
## no prevention effect prevents any damage, protection's included (CR 702.16e). A shield it
## stops is not used up (CR 615.12).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _hero_main() last started from, for a replay.
var _last_setup: MmEncounterSetup = null


func test_a_shield_prevents_nothing_and_is_not_used_up() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_shield("Shield", 3), Scenario.free_stomp("Stomp", 2)])
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	assert_eq(Scenario.cast_and_resolve(engine, "Shield", [villain]), "")
	var life_before: int = engine.villain().life

	assert_eq(Scenario.cast_and_resolve(engine, "Stomp", [villain]), "")

	assert_eq(engine.villain().life, life_before - 2)
	assert_eq(Scenario.prevented(engine), [])
	assert_eq(engine.game_state().replacement_effects.size(), 1)
	assert_eq(engine.game_state().replacement_effects[0].remaining, 3, "CR 615.12: a shield is not reduced.")


func test_a_prevention_effect_made_afterward_prevents_nothing_either() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_stomp("Stomp", 1), Scenario.free_shield("Shield", 3),
		Scenario.free_shock("Shock", 2)])
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	assert_eq(Scenario.cast_and_resolve(engine, "Stomp", [villain]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Shield", [villain]), "")
	var life_before: int = engine.villain().life

	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [villain]), "")

	assert_eq(engine.villain().life, life_before - 2, "It lasts the turn, not only for the spell's own damage.")


func test_protection_prevents_no_combat_damage_that_turn() -> void:
	var wall: MmCardDefinition = Scenario.creature("Wall", 0, 5, [Scenario.protection_from(Scenario.of_type(MmCardTypes.CardType.CREATURE))])
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Ogre", 3, 3)], [wall], [Scenario.free_stomp("Stomp", 1)])
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	var walled: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	Scenario.declare_attackers(engine, [ogre])
	assert_eq(Scenario.cast_and_resolve(engine, "Stomp", [MmReference.to_player(engine.villain().id)]), "")
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[walled, ogre]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, walled), 3, "CR 702.16e: protection's prevention prevents nothing.")


func test_damage_can_be_prevented_again_once_the_turn_ends() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_stomp("Stomp", 1)])
	assert_eq(Scenario.cast_and_resolve(engine, "Stomp", [MmReference.to_player(engine.villain().id)]), "")
	assert_false(engine.game_state().can_damage_be_prevented())

	Scenario.play_until_step(engine, 4, Step.UPKEEP)

	assert_true(engine.game_state().can_damage_be_prevented())


func test_copies_and_replays_keep_the_mark() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_stomp("Stomp", 1)])
	var setup: MmEncounterSetup = _last_setup
	assert_eq(Scenario.cast_and_resolve(engine, "Stomp", [MmReference.to_player(engine.villain().id)]), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_false(copy.game_state().can_damage_be_prevented())
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_damage_cant_be_prevented.tres"
	assert_eq(ResourceSaver.save(Scenario.free_stomp("Stomp", 2), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	assert_true((loaded.abilities[0] as SpellAbility).effects[0] is DamageCantBePreventedEffect)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## The Hero in their first main phase of Game Turn 3, holding [param hand].
func _hero_main(hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, hand)
	_last_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
