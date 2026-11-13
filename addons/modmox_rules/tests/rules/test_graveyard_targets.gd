extends GutTest
## A target requirement can ask for cards in graveyards (ADR 0014): "target creature card
## in your graveyard". CR 115.1: a card in a graveyard is a target only when the text says
## so. The first card to use it returns its target to its owner's hand.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason


func test_the_legal_targets_are_the_creature_cards_in_its_casters_graveyard() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, hero, "Raise")))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	assert_eq(decision.candidates.size(), 1, "Not the Shock, not the Villain's Ogre, and nothing on the battlefield.")
	assert_true(decision.candidates[0].is_object())
	assert_eq(decision.candidates[0].id, Scenario.card_in_graveyard(engine, hero, "Bear"))


func test_it_cannot_be_cast_without_a_creature_card_in_its_casters_graveyard() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	var villain: MmPlayer = engine.villain()

	assert_false(_offers(engine, "Raise"), "CR 601.2c: both graveyards are empty.")
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(villain.id)])
	assert_false(_offers(engine, "Raise"), "A Shock is not a creature card.")
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, villain.id, "Ogre"))])
	assert_false(_offers(engine, "Raise"), "The Ogre is in the Villain's graveyard.")
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Bear"))])
	assert_true(_offers(engine, "Raise"))


func test_an_unfiltered_requirement_offers_every_card_in_both_graveyards() -> void:
	var engine: MmEngine = _engine()
	_fill_graveyards(engine)
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)

	var legal: Array[MmReference] = Scenario.target_graveyard_card().legal_targets(engine.game_state(), context)

	var offered: Array[int] = []
	for candidate: MmReference in legal:
		assert_true(candidate.is_object(), "Never a player.")
		offered.append(candidate.id)
	var expected: Array[int] = engine.hero().graveyard.object_ids()
	expected.append_array(engine.villain().graveyard.object_ids())
	assert_eq(offered, expected, "Players in ID order, each graveyard in its own order.")
	assert_eq(offered.size(), 5, "Two Dooms, the Bear and the Shock, then the Ogre.")


func test_the_card_returns_to_its_owners_hand() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)
	var bear: int = Scenario.card_in_graveyard(engine, hero, "Bear")
	var held: int = Scenario.names(engine, hero.hand).count("Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Raise", [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.names(engine, hero.hand).count("Bear"), held + 1)
	assert_eq(Scenario.card_in_graveyard(engine, hero, "Bear"), -1)
	var returned: Array[ZoneChangeEvent] = _moves_with(engine, Reason.RETURN_TO_HAND)
	assert_eq(returned.size(), 1)
	assert_eq(returned[0].object_id, bear)
	assert_eq(returned[0].from_zone_kind, MmZone.Kind.GRAVEYARD)
	assert_eq(returned[0].to_zone_kind, MmZone.Kind.HAND)
	assert_eq(returned[0].to_owner_id, hero.id)


func test_it_does_not_resolve_if_its_target_left_the_graveyard_first() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)
	var bear: MmReference = MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Raise"), [bear])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Raise"), [bear]), "")
	Scenario.resolve_stack(engine)

	assert_eq(_moves_with(engine, Reason.RETURN_TO_HAND).size(), 1)
	assert_eq(_moves_with(engine, Reason.DID_NOT_RESOLVE).size(), 1, "CR 608.2b: the Bear in hand is a new object.")


func test_a_permanent_is_never_a_legal_graveyard_target() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	var spec: TargetSpec = Scenario.target_graveyard_card()
	var context: MmEffectContext = MmEffectContext.new(hero.id, 0)
	var bear: MmReference = MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Bear"))

	assert_false(spec.is_still_legal(engine.game_state(), bear, context), "It is on the battlefield.")
	assert_false(spec.is_still_legal(engine.game_state(), MmReference.to_player(hero.id), context))
	Scenario.cast_and_resolve(engine, "Doom", [bear])
	var dead: MmReference = MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))
	assert_true(spec.is_still_legal(engine.game_state(), dead, context))
	assert_false(Scenario.any_target().is_still_legal(engine.game_state(), dead, context), "And a card there is no permanent.")


func test_a_card_with_protection_can_still_be_targeted_in_a_graveyard() -> void:
	var warded: MmCardDefinition = Scenario.creature("Bear", 2, 2,
		[Scenario.protection_from(Scenario.has_subtype("Rite"))])
	var rite: MmCardDefinition = Scenario.free_raise("Raise")
	rite.subtypes = ["Rite"]
	var engine: MmEngine = _engine(warded, rite)
	var hero: MmPlayer = engine.hero()
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Bear"))])
	var bear: int = Scenario.card_in_graveyard(engine, hero, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Raise", [MmReference.to_object(bear)]), "",
		"CR 113.6: protection works only on the battlefield.")

	assert_eq(_moves_with(engine, Reason.RETURN_TO_HAND).size(), 1)


func test_only_a_card_in_a_graveyard_is_returned() -> void:
	var sweep: MmCardDefinition = Scenario.instant("Raise", Scenario.mana_cost(0), [],
		[Scenario.return_to_hand(Scenario.each_creature())])
	var engine: MmEngine = _engine(null, sweep)
	var hero: MmPlayer = engine.hero()

	Scenario.cast_and_resolve(engine, "Raise")

	assert_eq(Scenario.permanents_named(engine, hero.id, "Bear").size(), 1, "A permanent stays where it is, for now.")
	assert_eq(_moves_with(engine, Reason.RETURN_TO_HAND).size(), 0)


func test_returning_a_card_can_be_undone_while_it_is_on_the_stack_only() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_fill_graveyards(engine)
	var bear: int = Scenario.card_in_graveyard(engine, hero, "Bear")
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Raise"), [MmReference.to_object(bear)])

	assert_eq(engine.undo(), "")

	assert_eq(Scenario.card_in_graveyard(engine, hero, "Bear"), bear, "The same object, still in the graveyard.")


## Puts the Hero's Bear, a Shock and two Dooms into the Hero's graveyard and the Villain's
## Ogre into the Villain's.
func _fill_graveyards(engine: MmEngine) -> void:
	var hero: MmPlayer = engine.hero()
	var villain: MmPlayer = engine.villain()
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Bear"))])
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(Scenario.permanent_named(engine, villain.id, "Ogre"))])
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(villain.id)])


func _offers(engine: MmEngine, card_name: String) -> bool:
	return Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), card_name))


## The Hero's main phase on Game Turn 3, with a Bear on their battlefield and an Ogre on
## the Villain's, the Hero holding free Raises ("return target creature card from your
## graveyard to your hand"), Dooms ("destroy target creature") and a Shock.
func _engine(bear: MmCardDefinition = null, raise: MmCardDefinition = null) -> MmEngine:
	var hero_creature: MmCardDefinition = Scenario.creature("Bear", 2, 2) if bear == null else bear
	var raise_card: MmCardDefinition = Scenario.free_raise("Raise") if raise == null else raise
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 2, 2)
	var hero_cards: Array[MmCardDefinition] = [hero_creature, raise_card, Scenario.free_destroy("Doom"), Scenario.free_shock("Shock", 2)]
	var combat: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(hero_cards), Scenario.cycled([ogre]))
	return Scenario.find_engine(combat, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Bear") != "":
			return false
		if Scenario.play_until_step(running, 2, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.cast_and_resolve(running, "Ogre") != "":
			return false
		if Scenario.play_until_step(running, 3, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.count("Raise") >= 2 and held.count("Doom") >= 2 and held.has("Shock"))


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found
