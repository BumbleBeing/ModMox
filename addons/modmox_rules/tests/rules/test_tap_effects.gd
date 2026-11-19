extends GutTest
## "Tap [selection]" (CR 701.26a): each selected permanent becomes tapped. Only an untapped
## permanent can be tapped, so one already tapped is left as it is, with no event.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_tapping_target_creature_taps_it_and_the_view_shows_it() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_tap("Snare")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_and_resolve(engine, "Snare", [_object(ogre)]), "")

	assert_true(engine.game_state().object(ogre).is_tapped)
	assert_eq(_taps_of(engine, ogre), 1)
	assert_true(_view_of(engine.view_for(engine.hero()), ogre).is_tapped, "The other player sees it tapped too.")


func test_tapping_an_already_tapped_creature_performs_no_tap() -> void:
	# CR 701.26a: only untapped permanents can be tapped.
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_tap("Snare"), Scenario.free_tap("Snare Again")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.cast_and_resolve(engine, "Snare", [_object(ogre)])

	assert_eq(Scenario.cast_and_resolve(engine, "Snare Again", [_object(ogre)]), "")

	assert_true(engine.game_state().object(ogre).is_tapped)
	assert_eq(_taps_of(engine, ogre), 1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Snare Again"), -1, "It still resolved.")


func test_a_spell_whose_target_is_gone_taps_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_tap("Snare"), Scenario.free_bounce("Bounce")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Snare"), [_object(ogre)])

	Scenario.cast_and_resolve(engine, "Bounce", [_object(ogre)])
	Scenario.resolve_stack(engine)

	assert_eq(_taps_of(engine, ogre), 0, "CR 608.2b.")


func test_a_creature_tapped_before_combat_cannot_block() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre(), _ogre()], [Scenario.free_tap("Snare")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogres: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Ogre")
	Scenario.cast_and_resolve(engine, "Snare", [_object(ogres[0])])
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	Scenario.declare_attackers(engine, [bear])

	assert_eq(Scenario.pass_to_blockers(engine), "")

	assert_eq((engine.pending_decision() as DeclareBlockersDecision).candidate_blocker_ids, [ogres[1]])


func test_a_tapped_creature_untaps_in_its_controllers_untap_step() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_tap("Snare")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.cast_and_resolve(engine, "Snare", [_object(ogre)])

	Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN)

	assert_false(engine.game_state().object(ogre).is_tapped)


func test_tapping_each_creature_taps_every_one_at_once() -> void:
	var theirs: ControlledByFilter = ControlledByFilter.new()
	theirs.whose = MmTrigger.Whose.OPPONENT
	var sleep: MmCardDefinition = Scenario.instant("Sleep", Scenario.mana_cost(0), [],
		[Scenario.tap(Scenario.each_creature(theirs))])
	var engine: MmEngine = _hero_main([_bear()], [_ogre(), _ogre()], [sleep])
	var ogres: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Ogre")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Sleep")

	assert_true(engine.game_state().object(ogres[0]).is_tapped)
	assert_true(engine.game_state().object(ogres[1]).is_tapped)
	assert_false(engine.game_state().object(bear).is_tapped, "Only the opponent's creatures.")
	assert_eq(_taps_of(engine, ogres[0]) + _taps_of(engine, ogres[1]), 2)


func test_a_tap_effect_reaches_what_it_taps_through_its_selection() -> void:
	var effect: TapEffect = Scenario.tap(Scenario.targeted(0))

	assert_eq(effect.selections().size(), 1)
	assert_true(effect.selections()[0] is TargetSelection)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


## How many times [param object_id] became tapped.
func _taps_of(engine: MmEngine, object_id: int) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, TapEvent):
		if (event as TapEvent).object_id == object_id:
			count += 1
	return count


func _view_of(view: MmPlayerView, object_id: int) -> MmObjectView:
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
