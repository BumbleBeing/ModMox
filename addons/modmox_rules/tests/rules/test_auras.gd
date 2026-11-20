extends GutTest
## Auras (CR 303.4): an Aura spell targets what its enchant ability says it may enchant
## (CR 303.4a, 702.5), does not resolve if that target is gone (CR 608.3b), and enters
## attached to it. An Aura attached to an illegal object, or to one that is gone, is put
## into its owner's graveyard (CR 704.5m). "Enchanted land" is what the Aura is attached to.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_an_aura_is_cast_targeting_a_land_and_enters_attached_to_it() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.aura()])
	var forest: int = _fetch_forest(engine)
	var aura: int = Scenario.card_in_hand(engine, engine.hero(), "Aura")

	assert_eq(Scenario.cast(engine, aura, [_object(forest)]), "")
	var on_stack: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])
	assert_true(on_stack.targets[0].equals(_object(forest)), "CR 303.4a: the Aura spell targets the land.")
	assert_eq(Scenario.resolve_stack(engine), "")

	var entered: int = Scenario.permanent_named(engine, engine.hero().id, "Aura")
	assert_ne(entered, -1)
	assert_eq(Scenario.attached_to(engine, entered), forest)
	for player: MmPlayer in [engine.hero(), engine.villain()]:
		assert_eq(_seen(engine.view_for(player), entered).attached_to_object_id, forest)


func test_an_aura_may_enchant_an_opponents_permanent() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.creature("Ogre", 3, 3)], [Scenario.aura("Aura", _creature())])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [_object(ogre)]), "")

	var entered: int = Scenario.permanent_named(engine, engine.hero().id, "Aura")
	assert_eq(Scenario.attached_to(engine, entered), ogre, "The Hero controls the Aura on the Villain's creature.")


func test_an_aura_may_target_only_what_it_may_enchant() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [], [Scenario.aura()])
	var forest: int = _fetch_forest(engine)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var aura: int = Scenario.card_in_hand(engine, engine.hero(), "Aura")

	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, aura)), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	assert_true(_has(decision.candidates, forest))
	assert_false(_has(decision.candidates, bear), "Enchant land: a creature is not a candidate.")
	for candidate: MmReference in decision.candidates:
		assert_true(candidate.is_object(), "No player is a candidate.")


func test_an_aura_with_nothing_it_may_enchant_cannot_be_cast() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.aura("Aura", _creature())])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Aura")))


func test_an_aura_whose_target_is_gone_does_not_resolve_and_goes_to_the_graveyard() -> void:
	# CR 608.3b: an Aura spell whose target is illegal is put into its owner's graveyard.
	var drawing: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.draw_cards(1, Scenario.you())])
	var engine: MmEngine = _hero_main([], [], [Scenario.aura("Aura", null, [drawing]), Scenario.free_uproot()])
	var forest: int = _fetch_forest(engine)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Aura"), [_object(forest)]), "")
	var hand_before: int = engine.hero().hand.size()

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Uproot"), [_object(forest)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Aura"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Aura"), -1)
	assert_eq(engine.hero().hand.size(), hand_before, "Uproot went, the Forest came back, and the Aura never entered to draw.")


func test_an_aura_whose_land_leaves_goes_to_its_owners_graveyard() -> void:
	# CR 704.5m.
	var engine: MmEngine = _hero_main([], [], [Scenario.aura(), Scenario.free_uproot()])
	var forest: int = _fetch_forest(engine)
	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [_object(forest)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Uproot", [_object(forest)]), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Aura"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Aura"), -1)
	var binned: Array[ZoneChangeEvent] = []
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		if (event as ZoneChangeEvent).reason == ZoneChangeEvent.Reason.UNATTACHED_AURA:
			binned.append(event as ZoneChangeEvent)
	assert_eq(binned.size(), 1)


func test_an_aura_on_a_creature_that_gains_protection_from_it_goes_to_the_graveyard() -> void:
	# CR 702.16d, 704.5m: not unattached, as an Equipment would be.
	var ward: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Ward", Scenario.gain_abilities(
		[Scenario.protection_from(Scenario.of_type(CardType.ENCHANTMENT))], Scenario.targeted(0)))
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [], [Scenario.aura("Aura", _creature()), ward])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [_object(bear)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Ward", [_object(bear)]), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Aura"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Aura"), -1)


func test_enchanted_land_has_what_the_aura_gives_until_the_aura_goes() -> void:
	var swamp: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Swamp"], Scenario.attached())])
	var engine: MmEngine = _hero_main([], [], [Scenario.aura("Aura", null, [swamp]), Scenario.free_disenchant("Disenchant")])
	var forest: int = _fetch_forest(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [_object(forest)]), "")

	assert_eq(_subtypes(engine, forest), ["Forest", "Swamp"])
	var aura: int = Scenario.permanent_named(engine, engine.hero().id, "Aura")
	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_object(aura)]), "")
	assert_eq(_subtypes(engine, forest), ["Forest"])


func test_an_auras_enters_ability_finds_the_land_it_entered_attached_to() -> void:
	# CR 303.4a: it is attached as it enters, so "enchanted land" is there for its trigger.
	var tapping: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.tap(Scenario.attached())])
	var engine: MmEngine = _hero_main([], [], [Scenario.aura("Aura", null, [tapping])])
	var forest: int = _fetch_forest(engine)
	assert_false(engine.game_state().object(forest).is_tapped)

	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [_object(forest)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(engine.game_state().object(forest).is_tapped)


func test_an_aura_is_not_an_equipment_and_an_equipment_still_only_falls_off() -> void:
	# CR 704.5n beside 704.5m: the Equipment stays, the Aura goes.
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), Scenario.sword("Sword")], [],
		[Scenario.aura("Aura", _creature()), Scenario.free_bounce("Bounce")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	assert_eq(Scenario.equip_and_resolve(engine, sword, bear), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [_object(bear)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [_object(bear)]), "")

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sword"), [sword])
	assert_eq(Scenario.attached_to(engine, sword), 0)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Aura"), -1)


func test_a_copy_of_the_state_keeps_the_aura_attached_and_replays_are_exact() -> void:
	var extras: Array[MmCardDefinition] = [Scenario.aura("Aura", _creature())]
	var hero_cards: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	var bear: int = Scenario.permanent_named(original, original.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(original, "Aura", [_object(bear)]), "")
	var aura: int = Scenario.permanent_named(original, original.hero().id, "Aura")

	var copy: MmGameState = original.game_state().duplicate_state()

	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_eq(copy.object(aura).attached_to_object_id, bear)
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


func _fetch_forest(engine: MmEngine) -> int:
	assert_eq(Scenario.fetch_lands(engine, ["Forest"]), "")
	return Scenario.permanent_named(engine, engine.hero().id, "Forest")


func _creature() -> HasCardTypeFilter:
	return Scenario.of_type(CardType.CREATURE)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _has(candidates: Array[MmReference], object_id: int) -> bool:
	for candidate: MmReference in candidates:
		if candidate.equals(_object(object_id)):
			return true
	return false


func _subtypes(engine: MmEngine, object_id: int) -> Array[String]:
	var subtypes: Array[String] = []
	subtypes.assign(engine.game_state().characteristics_of(engine.game_state().object(object_id)).subtypes)
	return subtypes


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null


## Stops in the Hero's precombat main phase of Game Turn 3 with [param hero_permanents] and
## [param villain_permanents] in play, a Land Fetch and [param hero_extras] in hand, and a
## Forest in the Hero's library for the fetch.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var in_hand: Array[MmCardDefinition] = [Scenario.free_land_fetch()]
	in_hand.append_array(hero_extras)
	var lands: Array[MmCardDefinition] = [Scenario.basic_land("Forest")]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, in_hand + lands)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, in_hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
