extends GutTest
## "[selection] doesn't untap during its controller's next untap step" (CR 502.3), as Niblis
## of Frost's trigger says after "tap target creature an opponent controls": the next untap
## step of whoever controls the permanent then leaves it tapped and uses the effect up,
## whether or not it was tapped. The other player's untap step does not. A zone change leaves
## it behind with the old object (ADR 0008). The Villain's Ogre is cast in Game Turn 2, so the
## Villain's untap steps are in even Game Turns and the Hero's in odd ones.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_it_stays_tapped_through_its_controllers_next_untap_step_and_untaps_in_the_one_after() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_frost()])

	assert_eq(Scenario.cast_and_resolve(engine, "Frost", [MmReference.to_object(_ogre(engine))]), "")

	var ogre: MmGameObject = engine.game_state().object(_ogre(engine))
	assert_true(ogre.is_tapped)
	assert_true(ogre.skips_next_untap)
	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")
	assert_true(ogre.is_tapped, "CR 502.3: it doesn't untap during its controller's next untap step.")
	assert_false(ogre.skips_next_untap, "That untap step used it up.")
	assert_eq(Scenario.play_until_step(engine, 6, Step.PRECOMBAT_MAIN), "")
	assert_false(ogre.is_tapped)


func test_the_other_players_untap_step_does_not_use_it_up() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_frost()], [_bear()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Frost", [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")
	var frozen: MmGameObject = engine.game_state().object(bear)
	assert_true(frozen.skips_next_untap, "The Villain's untap step is not its controller's.")
	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_true(frozen.is_tapped)
	assert_false(frozen.skips_next_untap)


func test_untapped_at_that_untap_step_it_is_used_up_anyway() -> void:
	var still: MmCardDefinition = Scenario.instant("Still", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [Scenario.doesnt_untap(Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([still])
	assert_eq(Scenario.cast_and_resolve(engine, "Still", [MmReference.to_object(_ogre(engine))]), "")
	var ogre: MmGameObject = engine.game_state().object(_ogre(engine))
	assert_false(ogre.is_tapped, "It taps nothing itself.")

	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")

	assert_false(ogre.skips_next_untap)


func test_a_zone_change_leaves_it_behind() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_frost(), Scenario.free_bounce("Bounce")])
	assert_eq(Scenario.cast_and_resolve(engine, "Frost", [MmReference.to_object(_ogre(engine))]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [MmReference.to_object(_ogre(engine))]), "")

	var returned: int = Scenario.card_in_hand(engine, engine.villain(), "Ogre")
	assert_ne(returned, -1)
	assert_false(engine.game_state().object(returned).skips_next_untap, "ADR 0008: a new object.")


func test_both_players_see_that_it_wont_untap() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_frost()])

	assert_eq(Scenario.cast_and_resolve(engine, "Frost", [MmReference.to_object(_ogre(engine))]), "")

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = _seen(engine.view_for(player), _ogre(engine))
		assert_not_null(seen)
		assert_true(seen.skips_next_untap, "It is public.")


func test_a_copy_and_a_replay_keep_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_frost()])
	assert_eq(Scenario.cast_and_resolve(engine, "Frost", [MmReference.to_object(_ogre(engine))]), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_true(copy.game_state().object(_ogre(engine)).skips_next_untap)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_doesnt_untap.tres"
	assert_eq(ResourceSaver.save(Scenario.free_frost(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var frozen: DoesntUntapEffect = (loaded.abilities[0] as SpellAbility).effects[1] as DoesntUntapEffect
	assert_not_null(frozen)
	assert_true(frozen.selection is TargetSelection)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## Stops in the Hero's precombat main phase of Game Turn 3 holding [param hand], with
## [param hero_permanents] cast in Game Turn 1 and the Villain's Ogre in Game Turn 2.
func _hero_main(hand: Array[MmCardDefinition], hero_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var ogre: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, ogre, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, ogre, hand,
		[] as Array[MmCardDefinition], 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _ogre(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.villain().id, "Ogre")


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null
