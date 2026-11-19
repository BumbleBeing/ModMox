extends GutTest
## "Exile target card from a graveyard. If it is a permanent card, put a +1/+1 counter on
## this creature", after Lion Sash: ExileEffect exiles a card from a graveyard as well as a
## permanent (CR 701.13a), a card leaving a graveyard keeps what it last looked like
## (CR 608.2h), and "If [condition], [effect]" is an IfEffect (CR 608.2c).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason
const Kind := MmCounter.Kind


func test_it_exiles_a_permanent_card_from_its_controllers_graveyard_and_gets_a_counter() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)
	var bear: int = Scenario.card_in_graveyard(engine, hero, "Bear")

	assert_eq(_exile_and_resolve(engine, bear), "")

	assert_eq(Scenario.card_in_graveyard(engine, hero, "Bear"), -1)
	assert_eq(_exiled_names(engine, hero), ["Bear"] as Array[String])
	var exiled: Array[ZoneChangeEvent] = _moves_with(engine, Reason.EXILE)
	assert_eq(exiled.size(), 1)
	assert_eq(exiled[0].from_zone_kind, MmZone.Kind.GRAVEYARD)
	assert_eq(Scenario.counters_on(engine, _scavenger(engine), Kind.PLUS_ONE_PLUS_ONE), 1)


func test_it_exiles_a_card_from_the_other_players_graveyard_into_its_owners_exile() -> void:
	var engine: MmEngine = _engine()
	var villain: MmPlayer = engine.villain()
	_fill_graveyards(engine)

	assert_eq(_exile_and_resolve(engine, Scenario.card_in_graveyard(engine, villain, "Ogre")), "")

	assert_eq(_exiled_names(engine, villain), ["Ogre"] as Array[String])
	assert_eq(Scenario.counters_on(engine, _scavenger(engine), Kind.PLUS_ONE_PLUS_ONE), 1)


func test_an_instant_card_is_exiled_and_gives_no_counter() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)

	assert_eq(_exile_and_resolve(engine, Scenario.card_in_graveyard(engine, hero, "Shock")), "")

	assert_eq(_exiled_names(engine, hero), ["Shock"] as Array[String])
	assert_eq(Scenario.counters_on(engine, _scavenger(engine), Kind.PLUS_ONE_PLUS_ONE), 0, "A Shock is not a permanent card.")


func test_a_card_exiled_from_a_graveyard_keeps_what_it_last_looked_like() -> void:
	# CR 608.2h: "it" is the card as it last existed in the graveyard.
	var engine: MmEngine = _engine()
	_fill_graveyards(engine)
	var bear: int = Scenario.card_in_graveyard(engine, engine.hero(), "Bear")

	_exile_and_resolve(engine, bear)

	var state: MmGameState = engine.game_state()
	assert_null(state.object(bear), "ADR 0008: it is a new object in exile.")
	assert_not_null(state.object_or_last_known(bear))
	assert_true(state.characteristics_of(state.object_or_last_known(bear)).has_card_type(MmCardTypes.CardType.CREATURE))


func test_with_its_target_gone_from_the_graveyard_nothing_is_exiled_and_no_counter_is_put() -> void:
	# CR 608.2b.
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)
	var bear: MmReference = MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))
	assert_eq(Scenario.activate(engine, _scavenger(engine), [bear]), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Raise"), [bear]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_moves_with(engine, Reason.EXILE).size(), 0)
	assert_eq(Scenario.counters_on(engine, _scavenger(engine), Kind.PLUS_ONE_PLUS_ONE), 0)


func test_a_card_it_exiles_is_not_linked_to_it() -> void:
	# ExileEffect.links_to_source is off, so nothing remembers the Scavenger exiled it.
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)

	_exile_and_resolve(engine, Scenario.card_in_graveyard(engine, hero, "Bear"))

	assert_eq(engine.game_state().object(Scenario.exiled_by_owner(engine, hero)[0]).exiled_with_object_id, 0)
	assert_eq(engine.view_for(hero).exiles[hero.id][0].exiled_with_object_id, 0)


func test_an_exile_that_links_to_its_source_still_remembers_it() -> void:
	# The default, as Oblivion Ring's: CR 607.2a.
	var effect: ExileEffect = Scenario.exile(Scenario.targeted(0))

	assert_true(effect.links_to_source)


func test_an_if_effect_does_nothing_when_its_condition_does_not_hold() -> void:
	var engine: MmEngine = _engine()
	var never: SelectionMatchesCondition = SelectionMatchesCondition.new()
	never.selection = YouSelection.new()
	never.filter = Scenario.permanent_card()
	var effect: IfEffect = Scenario.if_then(never, Scenario.put_counters(Kind.PLUS_ONE_PLUS_ONE, 1, SourceSelection.new()))
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, _scavenger(engine))

	assert_eq(effect.numbers(engine.game_state(), context), [0] as Array[int])
	assert_eq(effect.next_batch(engine.game_state(), context, 0, [0] as Array[int]).size(), 0)


func test_a_permanent_card_is_an_artifact_creature_enchantment_or_land_card() -> void:
	# CR 110.4a.
	var engine: MmEngine = _engine()
	_fill_graveyards(engine)
	var state: MmGameState = engine.game_state()
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var filter: IsPermanentFilter = Scenario.permanent_card()

	assert_true(filter.matches(state, MmReference.to_object(Scenario.card_in_graveyard(engine, engine.hero(), "Bear")), context))
	assert_false(filter.matches(state, MmReference.to_object(Scenario.card_in_graveyard(engine, engine.hero(), "Shock")), context))
	assert_false(filter.matches(state, MmReference.to_player(engine.hero().id), context))


func _exile_and_resolve(engine: MmEngine, card_id: int) -> String:
	var error: String = Scenario.activate(engine, _scavenger(engine), [MmReference.to_object(card_id)])
	return error if error != "" else Scenario.resolve_stack(engine)


func _exiled_names(engine: MmEngine, owner: MmPlayer) -> Array[String]:
	var found: Array[String] = []
	for id: int in Scenario.exiled_by_owner(engine, owner):
		found.append(engine.game_state().characteristics_of(engine.game_state().object(id)).name)
	return found


func _scavenger(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Scavenger")


## Puts the Hero's Bear and a Shock (and a Doom) into the Hero's graveyard and the Villain's
## Ogre into the Villain's.
func _fill_graveyards(engine: MmEngine) -> void:
	var hero: MmPlayer = engine.hero()
	var villain: MmPlayer = engine.villain()
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Bear"))])
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, villain.id, "Ogre"))])
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(villain.id)])


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found


## The Hero's main phase on Game Turn 3, with a Scavenger and a Bear on their battlefield
## and an Ogre on the Villain's, the Hero holding a free Raise, Dooms and a Shock.
func _engine() -> MmEngine:
	var hero_cards: Array[MmCardDefinition] = [Scenario.scavenger(), Scenario.creature("Bear", 2, 2),
		Scenario.free_raise("Raise"), Scenario.free_destroy("Doom"), Scenario.free_shock("Shock", 2)]
	var combat: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(hero_cards), Scenario.cycled([Scenario.creature("Ogre", 2, 2)]))
	var engine: MmEngine = Scenario.find_engine(combat, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Scavenger") != "" or Scenario.cast_and_resolve(running, "Bear") != "":
			return false
		if Scenario.play_until_step(running, 2, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Ogre") != "":
			return false
		if Scenario.play_until_step(running, 3, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.has("Raise") and held.count("Doom") >= 2 and held.has("Shock"))
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
