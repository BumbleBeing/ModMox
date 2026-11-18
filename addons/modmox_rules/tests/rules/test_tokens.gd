extends GutTest
## CR 111: tokens. A token is a permanent that is not a card, made by an effect from a Token
## Definition. It is owned and controlled by the player who created it (CR 111.2), and it
## ceases to exist once it is anywhere but the battlefield, as a state-based action
## (CR 704.5d), after any "dies" ability has seen it go to the graveyard.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const WHITE := MmCardTypes.CardColor.WHITE


func test_a_spell_creates_a_token_under_its_controllers_control() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_tokens("Kitten", Scenario.cat())])

	Scenario.cast_and_resolve(engine, "Kitten")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 1)
	var made: MmGameObject = engine.game_state().object(tokens[0])
	assert_eq([made.owner_id, made.controller_id], [engine.hero().id, engine.hero().id], "CR 111.2.")
	assert_false(made.is_tapped)
	assert_true(engine.game_state().is_summoning_sick(made), "CR 302.6.")
	assert_eq(made.card_id, MmGameObject.NO_CARD, "CR 111.1: a token is not a card.")
	var created: Array[MmEvent] = Scenario.events_of(engine, TokenCreatedEvent)
	assert_eq(created.size(), 1)
	assert_eq((created[0] as TokenCreatedEvent).new_object_id, made.id)


func test_create_two_makes_two_tokens_at_once() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_tokens("Litter", Scenario.cat(), 2)])

	Scenario.cast_and_resolve(engine, "Litter")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 2)
	assert_ne(tokens[0], tokens[1])
	var created: Array[MmEvent] = Scenario.events_of(engine, TokenCreatedEvent)
	assert_eq(created[0].batch, created[1].batch, "All at once.")


func test_a_token_has_its_definitions_characteristics_and_color() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_tokens("Kitten", Scenario.cat())])

	Scenario.cast_and_resolve(engine, "Kitten")

	var cat: MmCharacteristics = Scenario.now(engine, Scenario.tokens_on_battlefield(engine)[0])
	assert_eq(cat.name, "Cat Token", "CR 111.4.")
	assert_eq(cat.card_types, [CardType.CREATURE])
	assert_eq(cat.subtypes, ["Cat"])
	assert_eq(cat.colors, [WHITE], "CR 204: its color is given by the effect, not a mana cost.")
	assert_null(cat.mana_cost)
	assert_eq([cat.power, cat.toughness], [1, 1])


func test_a_color_indicator_adds_to_the_colors_of_a_mana_cost() -> void:
	var definition: MmCardDefinition = Scenario.creature("Hybrid", 1, 1, [], Scenario.mana_cost(1, [MmMana.Type.RED]))
	definition.color_indicator = [MmCardTypes.CardColor.GREEN, WHITE]

	var printed: MmCharacteristics = MmCharacteristics.printed(definition)

	assert_eq(printed.colors, [WHITE, MmCardTypes.CardColor.RED, MmCardTypes.CardColor.GREEN], "In WUBRG order.")


func test_a_creature_that_enters_creates_a_token() -> void:
	var parent: MmCardDefinition = Scenario.creature("Parent", 2, 2,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(Scenario.cat())])])
	var engine: MmEngine = _hero_main([], [], [parent])

	Scenario.cast_and_resolve(engine, "Parent")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1)


func test_another_permanents_enters_ability_sees_a_token_arrive() -> void:
	var greeter: MmCardDefinition = Scenario.creature("Greeter", 0, 4,
		[Scenario.triggered(Scenario.enters(Scenario.of_type(CardType.CREATURE)), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([greeter], [], [Scenario.free_tokens("Litter", Scenario.cat(), 2)])
	var life: int = engine.hero().life

	Scenario.cast_and_resolve(engine, "Litter")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 2, "CR 603.6a: each token enters the battlefield.")


func test_a_tokens_own_enters_ability_triggers() -> void:
	var gain: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(3, Scenario.you())])
	var engine: MmEngine = _hero_main([], [],
		[Scenario.free_tokens("Bless", Scenario.token(1, 1, [WHITE], ["Spirit"], [gain]))])
	var life: int = engine.hero().life

	Scenario.cast_and_resolve(engine, "Bless")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 3)


func test_a_token_that_dies_is_seen_dying_and_then_ceases_to_exist() -> void:
	var mourner: MmCardDefinition = Scenario.creature("Mourner", 0, 4,
		[Scenario.triggered(Scenario.dies(Scenario.of_type(CardType.CREATURE)), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([mourner], [],
		[Scenario.free_tokens("Kitten", Scenario.cat()), Scenario.free_destroy("Murder")])
	Scenario.cast_and_resolve(engine, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	var life: int = engine.hero().life

	Scenario.cast_and_resolve(engine, "Murder", [MmReference.to_object(cat)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1, "It went to the graveyard, so it died (CR 111.7).")
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Kitten", "Murder"], "The token is gone (CR 704.5d).")
	var ceased: Array[MmEvent] = Scenario.events_of(engine, TokenCeasedEvent)
	assert_eq(ceased.size(), 1)
	assert_null(engine.game_state().object((ceased[0] as TokenCeasedEvent).object_id))


func test_a_token_that_is_exiled_ceases_to_exist() -> void:
	var engine: MmEngine = _hero_main([], [],
		[Scenario.free_tokens("Kitten", Scenario.cat()), Scenario.exile_spell("Banish")])
	Scenario.cast_and_resolve(engine, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]

	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(cat)])

	assert_eq(engine.game_state().exile.size(), 0)
	assert_eq(Scenario.events_of(engine, TokenCeasedEvent).size(), 1)


func test_a_token_returned_to_hand_ceases_to_exist() -> void:
	var engine: MmEngine = _hero_main([], [],
		[Scenario.free_tokens("Kitten", Scenario.cat()), Scenario.free_bounce("Bounce")])
	Scenario.cast_and_resolve(engine, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	var hand_before: int = engine.hero().hand.size()

	Scenario.cast_and_resolve(engine, "Bounce", [MmReference.to_object(cat)])

	assert_eq(engine.hero().hand.size(), hand_before - 1, "Bounce left the hand and nothing came back.")
	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0)


func test_a_token_is_no_run_card_and_both_players_see_it_is_a_token() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_tokens("Kitten", Scenario.cat())])

	Scenario.cast_and_resolve(engine, "Kitten")

	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_null(engine.game_state().run_card_of(engine.game_state().object(cat)))
	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = _seen(engine.view_for(viewer), cat)
		assert_true(seen.is_token)
		assert_eq(seen.token_definition.name, "Cat Token")
		assert_eq(seen.card_id, MmGameObject.NO_CARD)


func test_a_copy_of_the_state_keeps_its_tokens_and_replays_are_exact() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var extras: Array[MmCardDefinition] = [Scenario.free_tokens("Kitten", Scenario.cat())]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(original, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(original)[0]

	var copy: MmGameState = original.game_state().duplicate_state()

	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_true(copy.object(cat).is_token)
	assert_eq(copy.characteristics_of(copy.object(cat)).name, "Cat Token")
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_a_token_and_a_card_alike_have_different_fingerprints() -> void:
	var as_token: MmEngine = _hero_main([], [], [Scenario.free_tokens("Kitten", Scenario.cat())])
	Scenario.cast_and_resolve(as_token, "Kitten")
	var copy: MmGameState = as_token.game_state().duplicate_state()
	var before: String = copy.fingerprint()

	copy.object(Scenario.tokens_on_battlefield(as_token)[0]).is_token = false

	assert_ne(copy.fingerprint(), before)


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
