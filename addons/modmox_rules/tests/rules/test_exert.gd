extends GutTest
## Exert as part of a cost (CR 701.43): Pride Sovereign's "{W}, {T}, Exert this creature: ...".
## An exerted permanent won't untap during the next untap step of the player who exerted it,
## and that untap step uses the exertion up, whether or not the permanent was tapped then.
## The Hero's Exerter is cast in Game Turn 1, so the Hero's untap steps are in odd Game Turns.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_paying_it_taps_and_exerts_the_source_and_the_ability_resolves() -> void:
	var engine: MmEngine = _hero_main()
	var life: int = engine.hero().life

	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var exerter: MmGameObject = engine.game_state().object(_exerter(engine))
	assert_true(exerter.is_tapped)
	assert_eq(exerter.exerted_by_player_id, engine.hero().id)
	assert_eq(engine.hero().life, life + 1)


func test_it_stays_tapped_through_its_controllers_next_untap_step_and_untaps_in_the_one_after() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")
	var exerter: MmGameObject = engine.game_state().object(_exerter(engine))
	assert_eq(exerter.exerted_by_player_id, engine.hero().id, "The Villain's untap step does not use it up.")
	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	assert_true(exerter.is_tapped, "CR 701.43: it won't untap during its controller's next untap step.")
	assert_eq(exerter.exerted_by_player_id, MmGameState.NO_PLAYER, "That untap step used it up.")
	assert_eq(Scenario.play_until_step(engine, 7, Step.PRECOMBAT_MAIN), "")
	assert_false(exerter.is_tapped)


func test_exerted_in_the_other_players_end_step_it_skips_the_very_next_untap_step() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.play_until_step(engine, 4, Step.END), "")
	assert_eq(_pass_to_hero(engine), "")

	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	var exerter: MmGameObject = engine.game_state().object(_exerter(engine))
	assert_true(exerter.is_tapped)
	assert_eq(Scenario.play_until_step(engine, 7, Step.PRECOMBAT_MAIN), "")
	assert_false(exerter.is_tapped)


func test_untapped_at_that_untap_step_the_exertion_is_used_up_anyway() -> void:
	var engine: MmEngine = _hero_main(false)
	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var exerter: MmGameObject = engine.game_state().object(_exerter(engine))
	assert_false(exerter.is_tapped, "Exerting does not tap.")

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")

	assert_eq(exerter.exerted_by_player_id, MmGameState.NO_PLAYER)


func test_exerted_twice_before_that_untap_step_it_still_skips_only_one() -> void:
	var engine: MmEngine = _hero_main(false)
	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.activate(engine, _exerter(engine)), "", "CR 701.43b: an exerted permanent may be exerted again.")
	assert_eq(Scenario.resolve_stack(engine), "")
	engine.game_state().perform(TapEvent.new(_exerter(engine)))  # As some other effect would.

	assert_eq(Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN), "")
	var exerter: MmGameObject = engine.game_state().object(_exerter(engine))
	assert_true(exerter.is_tapped)
	assert_eq(Scenario.play_until_step(engine, 7, Step.PRECOMBAT_MAIN), "")
	assert_false(exerter.is_tapped)


func test_both_players_see_that_it_is_exerted() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = _seen(engine.view_for(player), _exerter(engine))
		assert_not_null(seen)
		assert_true(seen.is_exerted, "Exerting is public.")


func test_a_copy_and_a_replay_keep_the_exertion() -> void:
	var engine: MmEngine = _hero_main()
	assert_eq(Scenario.activate(engine, _exerter(engine)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(copy.game_state().object(_exerter(engine)).exerted_by_player_id, engine.hero().id)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


## A 1/1 with "{T}, Exert this creature: You gain 1 life.", or without the {T} when
## [param taps] is false.
func _exerter_definition(taps: bool) -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	if taps:
		ability.costs.append(TapCost.new())
	ability.costs.append(ExertCost.new())
	ability.effects = [Scenario.gain_life(1, Scenario.you())]
	return Scenario.creature("Exerter", 1, 1, [ability])


## Stops in the Hero's precombat main phase of Game Turn 3 with an Exerter in play that
## has been there since Game Turn 1.
func _hero_main(taps: bool = true) -> MmEngine:
	var exerter: Array[MmCardDefinition] = [_exerter_definition(taps)]
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(exerter, none)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, exerter, none, none, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _exerter(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Exerter")


## Passes priority until the Hero holds it.
func _pass_to_hero(engine: MmEngine) -> String:
	while (engine.pending_decision() as PriorityDecision).player_id != engine.hero().id:
		var error: String = Scenario.pass_priority(engine)
		if error != "":
			return error
	return ""


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null
