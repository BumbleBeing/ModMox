extends GutTest
## "Untap [selection]" (CR 701.26b): each selected permanent becomes untapped. Only a tapped
## permanent can be untapped, so one already untapped is left as it is, with no event.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_untapping_target_creature_untaps_it_and_the_view_shows_it() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_tap("Snare"), Scenario.free_untap("Wake")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(Scenario.cast_and_resolve(engine, "Snare", [_object(ogre)]), "")
	var before: int = _untaps_of(engine, ogre)

	assert_eq(Scenario.cast_and_resolve(engine, "Wake", [_object(ogre)]), "")

	assert_false(engine.game_state().object(ogre).is_tapped)
	assert_eq(_untaps_of(engine, ogre) - before, 1)
	assert_false(_view_of(engine.view_for(engine.hero()), ogre).is_tapped, "The other player sees it untapped too.")


func test_untapping_an_untapped_creature_performs_no_untap() -> void:
	# CR 701.26b: only tapped permanents can be untapped.
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_untap("Wake")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	var before: int = _untaps_of(engine, ogre)

	assert_eq(Scenario.cast_and_resolve(engine, "Wake", [_object(ogre)]), "")

	assert_false(engine.game_state().object(ogre).is_tapped)
	assert_eq(_untaps_of(engine, ogre), before)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Wake"), -1, "It still resolved.")


func test_a_spell_whose_target_is_gone_untaps_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()],
		[Scenario.free_tap("Snare"), Scenario.free_untap("Wake"), Scenario.free_bounce("Bounce")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.cast_and_resolve(engine, "Snare", [_object(ogre)])
	var before: int = _untaps_of(engine, ogre)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Wake"), [_object(ogre)])

	Scenario.cast_and_resolve(engine, "Bounce", [_object(ogre)])
	Scenario.resolve_stack(engine)

	assert_eq(_untaps_of(engine, ogre), before, "CR 608.2b.")


func test_a_creature_untapped_after_paying_its_tap_cost_can_pay_it_again() -> void:
	var engine: MmEngine = _hero_main([Scenario.elf()], [_ogre()], [Scenario.free_untap("Wake")])
	var elf: int = Scenario.permanent_named(engine, engine.hero().id, "Elf")
	assert_eq(Scenario.activate(engine, elf), "")
	assert_true(engine.game_state().object(elf).is_tapped)

	assert_eq(Scenario.cast_and_resolve(engine, "Wake", [_object(elf)]), "")

	assert_eq(Scenario.activate(engine, elf), "", "Untapped, its {T} can be paid again.")
	assert_eq(engine.hero().mana_pool().size(), 2)


func test_untapping_each_creature_untaps_every_tapped_one_at_once() -> void:
	var theirs: ControlledByFilter = ControlledByFilter.new()
	theirs.whose = MmTrigger.Whose.OPPONENT
	var sleep: MmCardDefinition = Scenario.instant("Sleep", Scenario.mana_cost(0), [],
		[Scenario.tap(Scenario.each_creature(theirs))])
	var dawn: MmCardDefinition = Scenario.instant("Dawn", Scenario.mana_cost(0), [],
		[Scenario.untap(Scenario.each_creature(theirs))])
	var engine: MmEngine = _hero_main([_bear()], [_ogre(), _ogre()], [sleep, dawn])
	var ogres: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Ogre")
	Scenario.cast_and_resolve(engine, "Sleep")
	var before: int = _untaps_of(engine, ogres[0]) + _untaps_of(engine, ogres[1])

	assert_eq(Scenario.cast_and_resolve(engine, "Dawn"), "")

	assert_false(engine.game_state().object(ogres[0]).is_tapped)
	assert_false(engine.game_state().object(ogres[1]).is_tapped)
	assert_eq(_untaps_of(engine, ogres[0]) + _untaps_of(engine, ogres[1]) - before, 2)


func test_an_untap_effect_reaches_what_it_untaps_through_its_selection() -> void:
	var effect: UntapEffect = Scenario.untap(Scenario.targeted(0))

	assert_eq(effect.selections().size(), 1)
	assert_true(effect.selections()[0] is TargetSelection)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


## How many times [param object_id] became untapped.
func _untaps_of(engine: MmEngine, object_id: int) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, UntapEvent):
		if (event as UntapEvent).object_id == object_id:
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
