extends GutTest
## A permanent returned to its owner's hand is a new object there, with nothing it had on
## the battlefield (ADR 0008). CR 608.2d: a choice an effect offers, "return a creature you
## control", is made by the controller of the spell or ability as the effect is applied, not
## as it is put on the stack, and it is not a target (CR 115.10).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Reason := ZoneChangeEvent.Reason
const CardType := MmCardTypes.CardType
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


# --- Returning permanents ----------------------------------------------------------

func test_a_returned_creature_is_a_new_card_in_its_owners_hand_without_counters_or_damage() -> void:
	var engine: MmEngine = _hero_main([_bear()], [],
		[Scenario.free_counters("Grow", PLUS, 1), Scenario.free_shock("Shock", 1), Scenario.free_bounce("Bounce")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Shock", [_object(bear)])

	Scenario.cast_and_resolve(engine, "Bounce", [_object(bear)])

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear").size(), 0)
	var in_hand: int = Scenario.card_in_hand(engine, engine.hero(), "Bear")
	assert_ne(in_hand, -1)
	assert_ne(in_hand, bear, "ADR 0008: a new object.")
	assert_eq(engine.game_state().object(in_hand).counters_of(PLUS), 0)
	assert_eq(engine.game_state().object(in_hand).damage_marked, 0)
	var returned: Array[ZoneChangeEvent] = _moves_with(engine, Reason.RETURN_TO_HAND)
	assert_eq(returned.size(), 1)
	assert_eq([returned[0].object_id, returned[0].from_zone_kind, returned[0].to_zone_kind, returned[0].to_owner_id],
		[bear, MmZone.Kind.BATTLEFIELD, MmZone.Kind.HAND, engine.hero().id])


func test_each_creature_returns_to_its_own_owners_hand_at_once() -> void:
	var sweep: MmCardDefinition = Scenario.instant("Sweep", Scenario.mana_cost(0), [],
		[Scenario.return_to_hand(Scenario.each_creature())])
	var engine: MmEngine = _hero_main([_bear()], [Scenario.creature("Ogre", 3, 3)], [sweep])

	Scenario.cast_and_resolve(engine, "Sweep")

	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1)
	assert_ne(Scenario.card_in_hand(engine, engine.villain(), "Ogre"), -1)
	var returned: Array[ZoneChangeEvent] = _moves_with(engine, Reason.RETURN_TO_HAND)
	assert_eq(returned.size(), 2)
	assert_eq(returned[0].batch, returned[1].batch, "All at once.")


# --- "A creature you control", chosen on resolution -------------------------------

func test_the_creature_is_chosen_as_the_ability_resolves_from_its_controllers_creatures() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.creature("Ogre", 3, 3)], [_lion()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Lion")

	assert_true(engine.pending_decision() is PriorityDecision, "Nothing is chosen as it triggers.")
	assert_eq(Scenario.pass_to_choice(engine), "")
	var decision: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	var lion: int = Scenario.permanent_named(engine, engine.hero().id, "Lion")
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(_ids(decision.candidates), [bear, lion], "Its controller's creatures, itself among them, in ID order.")
	assert_eq(engine.submit(_ids(decision.candidates).find(bear)), "")
	Scenario.resolve_stack(engine)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Lion"), lion)


func test_with_no_other_creature_it_returns_itself() -> void:
	var engine: MmEngine = _hero_main([], [], [_lion()])
	Scenario.cast_and_resolve(engine, "Lion")
	var lion: int = Scenario.permanent_named(engine, engine.hero().id, "Lion")

	assert_eq(Scenario.pass_to_choice(engine), "")

	var decision: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	assert_eq(_ids(decision.candidates), [lion], "Asked even with one candidate, as a target is.")
	assert_eq(engine.submit(0), "")
	Scenario.resolve_stack(engine)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Lion"), -1)


func test_with_nothing_to_choose_nothing_is_asked_and_nothing_returns() -> void:
	var engine: MmEngine = _hero_main([], [], [_lion(), Scenario.free_shock("Shock", 2)])
	Scenario.cast_and_resolve(engine, "Lion")
	var lion: int = Scenario.permanent_named(engine, engine.hero().id, "Lion")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [_object(lion)])

	var choices: int = _resolve_counting_choices(engine)

	assert_eq(choices, 0)
	assert_eq(_moves_with(engine, Reason.RETURN_TO_HAND).size(), 0)
	assert_eq(Scenario.events_of(engine, AbilityLeftStackEvent).size(), 1, "The ability still resolved.")


func test_a_creature_with_protection_from_its_source_can_still_be_chosen() -> void:
	var shielded: MmCardDefinition = Scenario.creature("Bear", 2, 2, [Scenario.protection_from(Scenario.of_type(CardType.CREATURE))])
	var engine: MmEngine = _hero_main([shielded], [], [_lion()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Lion")

	assert_eq(Scenario.pass_to_choice(engine), "")

	var decision: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	assert_true(_ids(decision.candidates).has(bear), "CR 115.10: not a target, so protection does not stop it.")
	assert_eq(engine.submit(_ids(decision.candidates).find(bear)), "")
	Scenario.resolve_stack(engine)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1)


func test_an_illegal_answer_is_refused_and_changes_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [_lion()])
	Scenario.cast_and_resolve(engine, "Lion")
	assert_eq(Scenario.pass_to_choice(engine), "")
	var before: String = engine.fingerprint()

	assert_ne(engine.submit(2), "")
	assert_ne(engine.submit("Bear"), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is ChooseObjectDecision)


func test_a_copy_made_while_choosing_answers_as_the_original_does_and_replays_are_exact() -> void:
	var hero_cards: Array[MmCardDefinition] = [_bear()]
	var extras: Array[MmCardDefinition] = [_lion()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(original, "Lion")
	assert_eq(Scenario.pass_to_choice(original), "")
	var copy: MmEngine = original.simulation_copy(original.hero().id, MmRng.new(1), true)

	assert_true(copy.pending_decision() is ChooseObjectDecision)
	var bear_index: int = _ids((original.pending_decision() as ChooseObjectDecision).candidates).find(
		Scenario.permanent_named(original, original.hero().id, "Bear"))
	assert_eq(original.submit(bear_index), "")
	assert_eq(copy.submit(bear_index), "")

	for engine: MmEngine in [original, copy]:
		Scenario.resolve_stack(engine)
		assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1)
		assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Lion"), -1)
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


## "When this creature enters, return a creature you control to its owner's hand."
func _lion() -> MmCardDefinition:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var a_creature: ChosenSelection = Scenario.chosen(Scenario.all_of([Scenario.of_type(CardType.CREATURE), yours]))
	return Scenario.creature("Lion", 2, 2, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.return_to_hand(a_creature)])])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _ids(references: Array[MmReference]) -> Array[int]:
	var ids: Array[int] = []
	for reference: MmReference in references:
		ids.append(reference.id)
	return ids


## Passes until the stack is empty, answering any choice with its first candidate, and says
## how many choices were asked.
func _resolve_counting_choices(engine: MmEngine) -> int:
	var choices: int = 0
	for _index: int in 100:
		if engine.game_state().stack.is_empty() and engine.pending_decision() is PriorityDecision:
			break
		if engine.pending_decision() is ChooseObjectDecision:
			choices += 1
		engine.submit(Scenario.default_answer(engine.pending_decision()))
	return choices


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
