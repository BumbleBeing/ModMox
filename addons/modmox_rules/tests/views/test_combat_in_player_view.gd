extends GutTest
## Combat is public: both players see power and toughness, marked damage, summoning
## sickness, who attacks and blocks, and which combat damage step it is.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_shows_its_power_toughness_and_summoning_sickness() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 3)], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [])
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Bear")
	var new_bear: int = Scenario.permanents_named(engine, engine.hero().id, "Bear")[1]

	var view: MmPlayerView = engine.view_for(engine.villain())

	var old_view: MmObjectView = _object(view, bear)
	assert_true(old_view.is_creature)
	assert_eq(old_view.power, 2)
	assert_eq(old_view.toughness, 3)
	assert_false(old_view.is_summoning_sick)
	assert_true(_object(view, new_bear).is_summoning_sick)


func test_attackers_blockers_and_damage_are_visible_to_both_players() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 4)], [Scenario.creature("Ogre", 3, 3)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, bear]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_true(_object(view, bear).is_attacking)
		assert_true(_object(view, bear).is_blocked)
		assert_false(_object(view, ogre).is_attacking)
		assert_eq(_object(view, ogre).blocking_ids, [bear])
		assert_eq(_object(view, bear).damage_marked, 3)
		assert_eq(_object(view, ogre).damage_marked, 2)
		assert_false(view.is_first_strike_damage_step)


func test_the_view_says_when_it_is_the_first_strike_damage_step() -> void:
	var archer: MmCardDefinition = Scenario.creature("Archer", 1, 2, [FirstStrikeAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([archer], [])
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Archer"))

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_true(engine.view_for(engine.hero()).is_first_strike_damage_step)


func _object(view: MmPlayerView, object_id: int) -> MmObjectView:
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null
