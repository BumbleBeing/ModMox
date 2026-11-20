extends GutTest
## Exiling until a permanent leaves the battlefield (CR 610.3, ADR 0065): Leyline Binding's
## "When this enchantment enters, exile target nonland permanent an opponent controls until
## this enchantment leaves the battlefield." The return is part of the same effect, not a
## triggered ability: the card comes back in the batch right after its source leaves, with
## nothing on the stack. If the source has already left when the exile would happen, nothing
## is exiled (CR 610.3c). The Binding costs {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const Reason := ZoneChangeEvent.Reason


func test_it_exiles_the_target_and_remembers_it_returns() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_binding("Binding")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	_bind(engine, "Binding", ogre)

	var exiled: Array[int] = Scenario.exiled_by_owner(engine, engine.villain())
	assert_eq(exiled.size(), 1)
	var card: MmGameObject = engine.game_state().object(exiled[0])
	assert_eq(card.exiled_with_object_id, Scenario.permanent_named(engine, engine.hero().id, "Binding"),
		"It is held by the Binding, as a linked exile is, so the screen tucks it.")
	assert_true(card.returns_when_exiler_leaves)


func test_its_target_is_only_a_nonland_permanent_an_opponent_controls() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_ogre()], [Scenario.free_binding("Binding")])

	assert_eq(Scenario.cast_and_resolve(engine, "Binding"), "")

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	assert_eq(decision.candidates.size(), 1)
	assert_eq(decision.candidates[0].id, Scenario.permanent_named(engine, engine.villain().id, "Ogre"))


func test_when_it_leaves_the_card_returns_at_once_with_nothing_on_the_stack() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_binding("Binding"), Scenario.free_disenchant("Disenchant")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	_bind(engine, "Binding", ogre)
	var exiled: int = Scenario.exiled_by_owner(engine, engine.villain())[0]

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_binding(engine)]), "")

	assert_true(engine.game_state().stack.is_empty(), "CR 610.3: the return is no triggered ability.")
	var returned: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_ne(returned, -1, "The Ogre is back before anyone has priority.")
	assert_true(returned != ogre and returned != exiled, "ADR 0008: a new object each time it moves.")
	var back: MmGameObject = engine.game_state().object(returned)
	assert_eq(back.controller_id, engine.villain().id, "Under its owner's control.")
	assert_false(back.is_tapped)
	assert_eq(back.controlled_since_game_turn, engine.game_state().game_turn, "CR 302.6: it has summoning sickness.")
	assert_false(back.returns_when_exiler_leaves)
	assert_eq(Scenario.exiled_by_owner(engine, engine.villain()).size(), 0)


func test_the_return_is_the_batch_right_after_the_one_it_left_in() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_binding("Binding"), Scenario.free_disenchant("Disenchant")])
	_bind(engine, "Binding", Scenario.permanent_named(engine, engine.villain().id, "Ogre"))
	var binding: int = _binding(engine).id

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_binding(engine)]), "")

	var left: ZoneChangeEvent = null
	var returned: ZoneChangeEvent = null
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		var move: ZoneChangeEvent = event as ZoneChangeEvent
		if move.object_id == binding:
			left = move
		elif move.reason == Reason.RETURN_TO_BATTLEFIELD:
			returned = move
	assert_not_null(left)
	assert_not_null(returned)
	assert_eq(returned.batch, left.batch + 1, "Immediately after, and not with it.")
	assert_eq([returned.from_zone_kind, returned.to_zone_kind], [MmZone.Kind.EXILE, MmZone.Kind.BATTLEFIELD])


func test_a_returned_creatures_enters_trigger_fires_and_so_does_the_leaving_trigger() -> void:
	var herald: MmCardDefinition = Scenario.creature("Herald", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(2, Scenario.you())])])
	var binding: MmCardDefinition = Scenario.free_binding("Binding")
	binding.abilities.append(Scenario.triggered(Scenario.leaves(IsSourceFilter.new()), [Scenario.gain_life(3, Scenario.you())]))
	var engine: MmEngine = _hero_main([], [herald], [binding, Scenario.free_disenchant("Disenchant")])
	_bind(engine, "Binding", Scenario.permanent_named(engine, engine.villain().id, "Herald"))
	var villain_life: int = engine.villain().life
	var hero_life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_binding(engine)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.villain().life, villain_life + 2, "It entered the battlefield, so its own trigger fired.")
	assert_eq(engine.hero().life, hero_life + 3, "CR 603.10a: the Binding's leaving trigger looked back.")


func test_if_it_leaves_before_its_trigger_resolves_nothing_is_exiled() -> void:
	var engine: MmEngine = _hero_main([], [_ogre()], [Scenario.free_binding("Binding"), Scenario.free_disenchant("Disenchant")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(Scenario.cast_and_resolve(engine, "Binding"), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(ogre)), "")

	var disenchant: int = Scenario.card_in_hand(engine, engine.hero(), "Disenchant")
	assert_eq(Scenario.cast(engine, disenchant, [_binding(engine)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Binding"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), ogre, "CR 610.3c: the Ogre never left.")
	assert_eq(Scenario.exiled_by_owner(engine, engine.villain()).size(), 0)


func test_destroyed_along_with_creatures_the_card_returns_after_them() -> void:
	var wrath: MmCardDefinition = Scenario.instant("Wrath", Scenario.mana_cost(0), [],
		[Scenario.destroy(Scenario.each(Scenario.any_of([Scenario.of_type(CardType.ENCHANTMENT), Scenario.of_type(CardType.CREATURE)])))])
	var engine: MmEngine = _hero_main([], [_ogre(), _goblin()], [Scenario.free_binding("Binding"), wrath])
	_bind(engine, "Binding", Scenario.permanent_named(engine, engine.villain().id, "Ogre"))

	assert_eq(Scenario.cast_and_resolve(engine, "Wrath"), "")

	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1, "It was in exile while the Wrath destroyed.")
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Goblin"), -1)


func test_bounced_and_cast_again_it_returns_the_first_card_and_exiles_anew() -> void:
	var bounce: MmCardDefinition = Scenario.instant("Bounce", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.ENCHANTMENT))],
		[Scenario.return_to_hand(Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([], [_ogre(), _goblin()], [Scenario.free_binding("Binding"), bounce])
	_bind(engine, "Binding", Scenario.permanent_named(engine, engine.villain().id, "Ogre"))

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [_binding(engine)]), "")
	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1)
	_bind(engine, "Binding", Scenario.permanent_named(engine, engine.villain().id, "Goblin"))

	var exiled: Array[int] = Scenario.exiled_by_owner(engine, engine.villain())
	assert_eq(exiled.size(), 1)
	assert_eq(Scenario.now(engine, exiled[0]).name, "Goblin")
	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1)


func test_two_bindings_each_return_only_their_own_card() -> void:
	var engine: MmEngine = _hero_main([], [_ogre(), _goblin()],
		[Scenario.free_binding("Binding"), Scenario.free_binding("Cage"), Scenario.free_disenchant("Disenchant")])
	_bind(engine, "Binding", Scenario.permanent_named(engine, engine.villain().id, "Ogre"))
	_bind(engine, "Cage", Scenario.permanent_named(engine, engine.villain().id, "Goblin"))

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_binding(engine)]), "")

	assert_ne(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Goblin"), -1, "The Cage still holds it.")


func test_an_exiled_token_ceases_to_exist_and_never_returns() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_binding("Binding", Scenario.another_nonland_permanent()),
		Scenario.free_tokens("Kittens", Scenario.cat()), Scenario.free_disenchant("Disenchant")])
	assert_eq(Scenario.cast_and_resolve(engine, "Kittens"), "")
	var token: int = Scenario.tokens_on_battlefield(engine)[0]
	_bind(engine, "Binding", token)
	assert_eq(engine.game_state().exile.size(), 0, "CR 704.5d")

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_binding(engine)]), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0, "CR 111.8")


func test_a_copy_and_a_replay_keep_what_returns() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var villain_cards: Array[MmCardDefinition] = [_ogre()]
	var extras: Array[MmCardDefinition] = [Scenario.free_binding("Binding"), Scenario.free_disenchant("Disenchant")]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, villain_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, no_cards, villain_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(original, "No seed gave the needed hands.")
	var before: String = original.game_state().fingerprint()
	_bind(original, "Binding", Scenario.permanent_named(original, original.villain().id, "Ogre"))
	var exiled: int = Scenario.exiled_by_owner(original, original.villain())[0]

	var copy: MmGameState = original.game_state().duplicate_state()
	var unflagged: MmGameState = original.game_state().duplicate_state()
	unflagged.object(exiled).returns_when_exiler_leaves = false

	assert_ne(original.game_state().fingerprint(), before)
	assert_ne(unflagged.fingerprint(), original.game_state().fingerprint(), "The fingerprint tells them apart.")
	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_true(copy.object(exiled).returns_when_exiler_leaves)
	Scenario.cast_and_resolve(original, "Disenchant", [_binding(original)])
	assert_ne(Scenario.permanent_named(original, original.villain().id, "Ogre"), -1)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


# --- Helpers -------------------------------------------------------------------------


## Casts the Binding named [param card_name], aims its trigger at [param target_id] and lets
## everything resolve.
func _bind(engine: MmEngine, card_name: String, target_id: int) -> void:
	assert_eq(Scenario.cast_and_resolve(engine, card_name), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(target_id)), "")
	assert_eq(Scenario.resolve_stack(engine), "")


## The Hero's permanent named "Binding", as a target.
func _binding(engine: MmEngine) -> MmReference:
	return MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Binding"))


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


func _goblin() -> MmCardDefinition:
	return Scenario.creature("Goblin", 1, 1)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
