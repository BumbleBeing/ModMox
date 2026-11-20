extends GutTest
## "The number of players who control more [permanents] than you", as Oreskos Explorer's X
## counts them: each player who controls strictly more of them than the ability's
## controller. One-on-one it is 0 or 1, and you are never counted.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_opponent_is_counted_when_they_control_more() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre(), _ogre()])

	assert_eq(Scenario.cast_and_resolve(engine, "Envy"), "")

	assert_eq(engine.hero().life, 21)


func test_the_opponent_is_not_counted_when_they_control_as_many() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()])

	assert_eq(Scenario.cast_and_resolve(engine, "Envy"), "")

	assert_eq(engine.hero().life, 20, "Strictly more.")


func test_you_are_never_counted() -> void:
	var engine: MmEngine = _hero_main([_bear(), _bear()], [_ogre()])
	var players: ControlsMoreFilter = Scenario.controls_more(Scenario.of_type(MmCardTypes.CardType.CREATURE))
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)

	assert_eq(Scenario.cast_and_resolve(engine, "Envy"), "")

	assert_eq(engine.hero().life, 20)
	assert_false(players.matches(engine.game_state(), MmReference.to_player(engine.hero().id), context))
	assert_false(players.matches(engine.game_state(), MmReference.to_player(engine.villain().id), context))
	var creature: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_false(players.matches(engine.game_state(), MmReference.to_object(creature), context), "Only players match.")


func test_it_is_counted_as_the_spell_resolves() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre(), _ogre()], [Scenario.free_destroy("Destroy")])
	var envy: int = Scenario.card_in_hand(engine, engine.hero(), "Envy")
	assert_eq(Scenario.cast(engine, envy), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Destroy",
		[MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Ogre"))]), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 20, "One Ogre was left as Envy resolved: as many as the Hero's.")


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 2, 4)


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_envy()]
	extras.append_array(hero_extras)
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
