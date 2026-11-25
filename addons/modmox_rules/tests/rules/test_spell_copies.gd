extends GutTest
## Copying a spell (CR 707.10): "copy this spell", as Sage of the Skies says, puts a copy of
## the spell onto the stack, owned and controlled by the player who copied it. A copy is a
## spell with no card. It isn't cast, so nothing that waits for a cast sees it. A copy of a
## permanent spell becomes a token as it resolves (CR 608.3f, 707.10f, 111.13), which is not
## "created". A copy anywhere but the stack ceases to exist (CR 704.5e).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_sage_cast_second_becomes_two_sages_one_of_them_a_token() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.sage()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Sage"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var sages: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Sage")
	assert_eq(sages.size(), 2)
	var token: MmGameObject = engine.game_state().object(sages[0])
	var card: MmGameObject = engine.game_state().object(sages[1])
	assert_true(token.is_token, "The copy resolved first, into a token.")
	assert_false(token.is_copy, "CR 608.3f: no longer a copy of a spell.")
	assert_eq(token.card_id, MmGameObject.NO_CARD)
	assert_true(card.is_card())
	assert_true(Scenario.now(engine, token.id).has_ability(FlyingAbility), "It has the spell's characteristics.")
	assert_eq(Scenario.pt(engine, token.id), [2, 3])
	assert_true(engine.game_state().is_summoning_sick(token))
	assert_eq(Scenario.events_of(engine, TokenCreatedEvent).size(), 0, "CR 111.13: the token is not created.")


func test_the_copy_goes_on_the_stack_above_the_spell_and_is_not_cast() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.sage()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Sage")), "")

	assert_eq(_resolve_top(engine), "", "Its cast trigger resolves.")

	var stack: Array[MmGameObject] = engine.game_state().stack.objects()
	assert_eq(stack.size(), 2)
	var copy: MmGameObject = stack[1]
	assert_true(copy.is_copy)
	assert_true(copy.is_card_or_copy(), "A spell, not an ability.")
	assert_false(copy.is_card())
	assert_eq([copy.owner_id, copy.controller_id], [engine.hero().id, engine.hero().id], "CR 707.10.")
	assert_eq(Scenario.now(engine, copy.id).name, "Sage")
	assert_eq(engine.hero().spells_cast_this_turn, 2, "CR 707.10: a copy isn't cast.")
	assert_eq(Scenario.events_of(engine, SpellCastEvent).size(), 2)
	assert_eq(Scenario.events_of(engine, SpellCopiedEvent).size(), 1)


func test_a_cast_trigger_does_not_see_the_copy() -> void:
	var watcher: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(
		Scenario.casts(Scenario.of_type(MmCardTypes.CardType.CREATURE), MmTrigger.Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([watcher], [_gift(), Scenario.sage()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Sage")), "")
	assert_eq(Scenario.resolve_stack(engine), "", "The two triggers are ordered, then all resolves.")

	assert_eq(engine.hero().life, life + 1, "Only the card was cast.")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sage").size(), 2)


func test_its_own_cast_trigger_does_not_trigger_for_the_copy() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.sage()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Sage"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 1, "The card's cast only.")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sage").size(), 2, "Not three.")


func test_a_countered_copy_ceases_to_exist() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.sage(), Scenario.free_counter("Negate")])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Sage")), "")
	assert_eq(_resolve_top(engine), "")
	var copy: int = engine.game_state().stack.objects().back().id

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Negate"), [MmReference.to_object(copy)]), "")
	assert_eq(_resolve_top(engine), "")

	assert_eq(Scenario.names(engine, engine.hero().graveyard).has("Sage"), false, "CR 704.5e.")
	assert_eq(Scenario.events_of(engine, CopyCeasedEvent).size(), 1)
	assert_eq(engine.game_state().stack.size(), 1, "The card is still to resolve.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sage").size(), 1)


func test_a_copy_of_an_instant_resolves_and_ceases_to_exist() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.free_twin()])
	var life: int = engine.hero().life
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")
	var gift: int = engine.game_state().stack.objects().back().id

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Twin"), [MmReference.to_object(gift)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 2, "The copy and the Gift each gained 1.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard).count("Gift"), 1, "Only the card.")
	assert_eq(Scenario.events_of(engine, CopyCeasedEvent).size(), 1)


func test_a_copy_keeps_the_spells_targets() -> void:
	# CR 707.10: the copy copies the choices made as the spell was cast, its targets included.
	var engine: MmEngine = _hero_main([], [Scenario.free_shock("Shock", 2), Scenario.free_twin()])
	var life: int = engine.villain().life
	var at_villain: Array[MmReference] = [MmReference.to_player(engine.villain().id)]
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), at_villain), "")
	var shock: int = engine.game_state().stack.objects().back().id

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Twin"), [MmReference.to_object(shock)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.villain().life, life - 4)


func test_nothing_is_copied_once_the_spell_has_left_the_stack() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.sage(), Scenario.free_counter("Negate")])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Sage")), "")
	var sage: int = engine.game_state().stack.objects()[0].id

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Negate"), [MmReference.to_object(sage)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sage"), [] as Array[int])
	assert_eq(Scenario.events_of(engine, SpellCopiedEvent).size(), 0)


func test_a_copy_of_the_state_keeps_the_copy_and_replays_are_exact() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var hand: Array[MmCardDefinition] = [_gift(), Scenario.sage()]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, hand)
	var original: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.cast_and_resolve(original, "Gift"), "")
	assert_eq(Scenario.cast(original, Scenario.card_in_hand(original, original.hero(), "Sage")), "")
	assert_eq(_resolve_top(original), "")
	var copy_id: int = original.game_state().stack.objects().back().id

	var state: MmGameState = original.game_state().duplicate_state()

	assert_eq(state.fingerprint(), original.game_state().fingerprint())
	assert_true(state.object(copy_id).is_copy)
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_both_players_see_a_copy_for_what_it_is() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), Scenario.sage()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Sage")), "")
	assert_eq(_resolve_top(engine), "")
	var copy_id: int = engine.game_state().stack.objects().back().id

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = null
		for item: MmObjectView in engine.view_for(viewer).stack:
			if item.id == copy_id:
				seen = item
		assert_not_null(seen)
		assert_true(seen.is_copy)
		assert_eq(seen.token_definition.name, "Sage", "Made from the card's definition.")


# --- Helpers ---------------------------------------------------------------------------


func _gift(card_name: String = "Gift") -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


## Both players pass, so the top of the stack resolves.
func _resolve_top(engine: MmEngine) -> String:
	var error: String = Scenario.pass_priority(engine)
	return error if error != "" else Scenario.pass_priority(engine)


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
