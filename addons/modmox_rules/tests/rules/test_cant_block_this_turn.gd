extends GutTest
## "[selection] can't block this turn" (CR 509.1a), as Arena Athlete's Heroic says of
## "target creature an opponent controls": a restriction on its controller's declaration of
## blockers for the rest of the turn, kept on the permanent as the Game Turn it can't block
## in. It is a rule, not an ability (CantBlockAbility), so losing all abilities does not lift
## it. A zone change leaves it behind with the old object (ADR 0008). Scare is an instant
## costing {0}: "Target creature can't block this turn."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _scared() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_it_cant_be_declared_as_a_blocker_this_turn() -> void:
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3)])

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "The Ogre was the only blocker, and can't block.")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	assert_eq(engine.villain().life, 18, "The Bear was not blocked.")


func test_another_creature_can_still_block() -> void:
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3), Scenario.creature("Wall", 0, 4)])
	var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")

	assert_eq(Scenario.pass_to_blockers(engine), "")

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_false(decision.blockable_by_blocker.has(_ogre(engine)), "CR 509.1a: the Ogre can't block.")
	assert_eq(decision.blockable_by_blocker[wall], [_bear(engine)])
	assert_ne(engine.submit([[_ogre(engine), _bear(engine)]]), "", "A block by the Ogre is refused.")


func test_it_can_block_in_a_later_turn() -> void:
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3)])
	assert_eq(Scenario.play_until_step(engine, 5, Step.DECLARE_ATTACKERS), "")
	assert_eq(Scenario.declare_attackers(engine, [_bear(engine)]), "")

	assert_eq(Scenario.pass_to_blockers(engine), "")

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.blockable_by_blocker[_ogre(engine)], [_bear(engine)], "\"This turn\" was Game Turn 3.")


func test_losing_all_abilities_does_not_lift_it() -> void:
	# It is a rule of the turn, not an ability the creature gained.
	var hush: MmCardDefinition = Scenario.instant("Hush", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.until_end_of_turn(Scenario.lose_all_abilities(Scenario.targeted(0)))])
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3)], [hush])

	assert_eq(Scenario.cast_and_resolve(engine, "Hush", [MmReference.to_object(_ogre(engine))]), "")
	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "The Ogre still can't block.")


func test_a_zone_change_leaves_it_behind() -> void:
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3)], [Scenario.free_bounce("Bounce")])

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [MmReference.to_object(_ogre(engine))]), "")

	var returned: int = Scenario.card_in_hand(engine, engine.villain(), "Ogre")
	assert_ne(returned, -1)
	assert_eq(engine.game_state().object(returned).cant_block_in_game_turn, 0, "ADR 0008: a new object.")


func test_both_players_see_that_it_cant_block() -> void:
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3)])

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = _seen(engine.view_for(player), _ogre(engine))
		assert_not_null(seen)
		assert_true(seen.cant_block_this_turn, "It is public.")


func test_a_copy_and_a_replay_keep_it() -> void:
	var engine: MmEngine = _scared([Scenario.creature("Ogre", 3, 3)])

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(copy.game_state().object(_ogre(engine)).cant_block_in_game_turn, 3)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_cant_block_this_turn.tres"
	assert_eq(ResourceSaver.save(Scenario.free_scare(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var scare: CantBlockThisTurnEffect = (loaded.abilities[0] as SpellAbility).effects[0] as CantBlockThisTurnEffect
	assert_not_null(scare)
	assert_true(scare.selection is TargetSelection)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## The Hero's Bear attacking in Game Turn 3, the Villain's [param villain_creatures] cast in
## Game Turn 2, and a Scare resolved on the Villain's Ogre in the declare attackers step;
## the Hero holds [param hand] too.
func _scared(villain_creatures: Array[MmCardDefinition], hand: Array[MmCardDefinition] = []) -> MmEngine:
	var all_hand: Array[MmCardDefinition] = [Scenario.free_scare()]
	all_hand.append_array(hand)
	var bears: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	_setup = Scenario.combat_setup(bears, villain_creatures, all_hand)
	var engine: MmEngine = Scenario.combat_ready_with(_setup, bears, villain_creatures, all_hand)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.declare_attackers(engine, [_bear(engine)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Scare", [MmReference.to_object(_ogre(engine))]), "")
	return engine


func _bear(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Bear")


func _ogre(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.villain().id, "Ogre")


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null
