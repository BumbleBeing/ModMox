extends GutTest
## "When this creature enters, put target card from an opponent's graveyard on the bottom of
## their library", after Landscaper Colos: PutOnBottomOfLibraryEffect puts a card from a
## graveyard under every card of its owner's library, where it is a new object (ADR 0008).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason


func test_it_puts_the_target_from_the_opponents_graveyard_into_their_library() -> void:
	var engine: MmEngine = _engine()
	var villain: MmPlayer = engine.villain()
	var ogre: int = _kill_ogre(engine)

	assert_eq(_colos_aimed_at(engine, ogre), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.card_in_graveyard(engine, villain, "Ogre"), -1)
	var moved: Array[ZoneChangeEvent] = _moves_with(engine, Reason.PUT_ON_BOTTOM)
	assert_eq(moved.size(), 1)
	assert_eq(moved[0].from_zone_kind, MmZone.Kind.GRAVEYARD)
	assert_eq(moved[0].to_zone_kind, MmZone.Kind.LIBRARY)
	assert_eq(moved[0].to_owner_id, villain.id, "Its owner's library.")


func test_it_goes_under_every_card_already_in_the_library() -> void:
	var engine: MmEngine = _engine()
	var villain: MmPlayer = engine.villain()
	var ogre: int = _kill_ogre(engine)
	var top: String = Scenario.top_name(engine, villain)
	var size: int = villain.library.size()

	assert_eq(_colos_aimed_at(engine, ogre), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(villain.library.size(), size + 1)
	assert_eq(Scenario.top_name(engine, villain), top, "The next card drawn is not it.")
	var bottom: MmGameObject = villain.library.objects()[villain.library.size() - 1]
	assert_eq(engine.game_state().characteristics_of(bottom).name, "Ogre")


func test_the_card_is_a_new_object_in_the_library_and_keeps_what_it_last_looked_like() -> void:
	# ADR 0008, CR 608.2h.
	var engine: MmEngine = _engine()
	var ogre: int = _kill_ogre(engine)

	assert_eq(_colos_aimed_at(engine, ogre), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var state: MmGameState = engine.game_state()
	assert_null(state.object(ogre))
	assert_not_null(state.object_or_last_known(ogre))
	assert_true(state.characteristics_of(state.object_or_last_known(ogre)).has_card_type(MmCardTypes.CardType.CREATURE))


func test_with_its_target_gone_from_the_graveyard_nothing_is_put_into_the_library() -> void:
	# CR 608.2b.
	var engine: MmEngine = _engine()
	var villain: MmPlayer = engine.villain()
	var ogre: int = _kill_ogre(engine)
	var size: int = villain.library.size()
	assert_eq(_colos_aimed_at(engine, ogre), "")

	assert_eq(Scenario.activate(engine, _scavenger(engine), [MmReference.to_object(ogre)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.exiled_by_owner(engine, villain).size(), 1, "The Scavenger exiled it first.")
	assert_eq(_moves_with(engine, Reason.PUT_ON_BOTTOM).size(), 0)
	assert_eq(villain.library.size(), size)


func test_a_selected_permanent_stays_on_the_battlefield() -> void:
	# Later: a permanent put on the bottom of its owner's library, once a card says so.
	var engine: MmEngine = _engine()
	var effect: PutOnBottomOfLibraryEffect = Scenario.put_on_bottom(Scenario.each(Scenario.of_type(MmCardTypes.CardType.CREATURE)))
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, _scavenger(engine))

	assert_eq(effect.next_batch(engine.game_state(), context, 0, effect.numbers(engine.game_state(), context)).size(), 0)


func test_it_uses_its_selection_as_a_target_when_given_one() -> void:
	assert_true(Scenario.put_on_bottom(Scenario.targeted(0)).has_targets())
	assert_false(Scenario.put_on_bottom(Scenario.each(Scenario.of_type(MmCardTypes.CardType.CREATURE))).has_targets())


## Casts the Hero's Colos and aims its "enters" trigger at [param card_id].
func _colos_aimed_at(engine: MmEngine, card_id: int) -> String:
	var error: String = Scenario.cast_and_resolve(engine, "Colos")
	return error if error != "" else Scenario.choose_target(engine, MmReference.to_object(card_id))


## Destroys the Villain's Ogre, and returns the card it leaves in their graveyard.
func _kill_ogre(engine: MmEngine) -> int:
	var villain: MmPlayer = engine.villain()
	var ogre: MmReference = MmReference.to_object(Scenario.permanent_named(engine, villain.id, "Ogre"))
	assert_eq(Scenario.cast_and_resolve(engine, "Doom", [ogre]), "")
	return Scenario.card_in_graveyard(engine, villain, "Ogre")


func _scavenger(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Scavenger")


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found


## The Hero's main phase on Game Turn 3, with a Scavenger on their battlefield and an Ogre
## on the Villain's, the Hero holding a Colos and a free Doom.
func _engine() -> MmEngine:
	var hero_cards: Array[MmCardDefinition] = [Scenario.scavenger(), Scenario.colos(),
		Scenario.free_destroy("Doom")]
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(hero_cards), Scenario.cycled([Scenario.creature("Ogre", 2, 2)]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Scavenger") != "":
			return false
		if Scenario.play_until_step(running, 2, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Ogre") != "":
			return false
		if Scenario.play_until_step(running, 3, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.has("Colos") and held.has("Doom"))
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
