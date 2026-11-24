extends GutTest
## "Create a token that's a copy of [selection]" (CR 707.2), as Oltec Matterweaver's "Create
## a token that's a copy of target artifact token you control": the token gets the copied
## object's copiable values, the characteristics its definition gives it (a token's Token
## Definition, CR 111.3), and nothing else: no counters, no damage, no tapped state and no
## continuous effect (CR 707.2). It is a new object (ADR 0008).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const WHITE := MmCardTypes.CardColor.WHITE


func test_the_copy_is_a_new_token_with_the_same_characteristics() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Kitten", Scenario.cat()), _mirror()])
	Scenario.cast_and_resolve(engine, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.cast_and_resolve(engine, "Mirror", [MmReference.to_object(cat)]), "")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 2)
	var made: MmGameObject = engine.game_state().object(tokens[1])
	var copy: MmCharacteristics = Scenario.now(engine, made.id)
	assert_eq(copy.name, "Cat Token")
	assert_eq(copy.subtypes, ["Cat"])
	assert_eq(copy.colors, [WHITE])
	assert_eq([copy.power, copy.toughness], [1, 1])
	assert_true(made.is_token)
	assert_eq(made.card_id, MmGameObject.NO_CARD, "CR 111.1: a token is not a card.")
	assert_eq(made.controller_id, engine.hero().id)
	assert_true(engine.game_state().is_summoning_sick(made), "CR 302.6: a new object.")


func test_only_copiable_values_are_copied() -> void:
	# CR 707.2: not its counters, its tapped state or the effects that change it.
	var growth: MmCardDefinition = Scenario.instant("Growth", Scenario.mana_cost(0), [_target_creature()],
		[Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.targeted(0))])
	var pump: MmCardDefinition = Scenario.instant("Pump", Scenario.mana_cost(0), [_target_creature()],
		[Scenario.until_end_of_turn(Scenario.modify_pt(2, 2, Scenario.targeted(0)))])
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Kitten", Scenario.cat()), growth, pump,
		Scenario.free_tap("Trip"), _mirror()])
	Scenario.cast_and_resolve(engine, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	var at_cat: Array[MmReference] = [MmReference.to_object(cat)]
	for card_name: String in ["Growth", "Pump", "Trip"]:
		assert_eq(Scenario.cast_and_resolve(engine, card_name, at_cat), "")
	assert_eq(Scenario.pt(engine, cat), [4, 4])

	assert_eq(Scenario.cast_and_resolve(engine, "Mirror", at_cat), "")

	var made: int = Scenario.tokens_on_battlefield(engine)[1]
	assert_eq(Scenario.pt(engine, made), [1, 1])
	assert_eq(Scenario.counters_on(engine, made, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 0)
	assert_false(engine.game_state().object(made).is_tapped)
	assert_eq(Scenario.pt(engine, cat), [4, 4], "The original is left as it was.")


func test_the_copys_own_enters_ability_triggers() -> void:
	var greeting: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.gain_life(1, Scenario.you())])
	var cleric: MmCardDefinition = Scenario.token(1, 1, [WHITE], ["Cleric"], [greeting])
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Ordain", cleric), _mirror()])
	Scenario.cast_and_resolve(engine, "Ordain")
	Scenario.resolve_stack(engine)
	var life: int = engine.hero().life
	var original: int = Scenario.tokens_on_battlefield(engine)[0]

	Scenario.cast_and_resolve(engine, "Mirror", [MmReference.to_object(original)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1, "CR 603.6a: the copy enters, and its ability sees it.")


func test_a_copy_of_each_object_found() -> void:
	var copy: CreateTokenCopyEffect = CreateTokenCopyEffect.new()
	copy.selection = Scenario.each_creature(IsTokenFilter.new())
	var multiply: MmCardDefinition = Scenario.instant("Multiply", Scenario.mana_cost(0), [], [copy])
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Litter", Scenario.cat(), 2), multiply])
	Scenario.cast_and_resolve(engine, "Litter")

	assert_eq(Scenario.cast_and_resolve(engine, "Multiply"), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 4)
	var created: Array[MmEvent] = Scenario.events_of(engine, TokenCreatedEvent)
	assert_eq(created[2].batch, created[3].batch, "All at once.")


func test_nothing_is_created_when_the_target_is_gone() -> void:
	# CR 608.2b: its only target is illegal, so it doesn't resolve.
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Kitten", Scenario.cat()), _mirror(),
		Scenario.free_destroy("Doom")])
	Scenario.cast_and_resolve(engine, "Kitten")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]
	var at_cat: Array[MmReference] = [MmReference.to_object(cat)]
	var player: MmPlayer = engine.hero()
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, player, "Mirror"), at_cat), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, player, "Doom"), at_cat), "")

	Scenario.resolve_stack(engine)

	assert_eq(Scenario.tokens_on_battlefield(engine), [] as Array[int])
	assert_eq(Scenario.events_of(engine, TokenCreatedEvent).size(), 1, "Only the Kitten's Cat.")


func test_a_copy_of_a_card_is_a_token_with_its_characteristics() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var copy: CreateTokenCopyEffect = CreateTokenCopyEffect.new()
	copy.selection = Scenario.targeted(0)
	var clone: MmCardDefinition = Scenario.instant("Clone", Scenario.mana_cost(0), [_target_creature()], [copy])
	var engine: MmEngine = _hero_main([bear], [clone])
	var original: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Clone", [MmReference.to_object(original)]), "")

	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 1)
	assert_eq(Scenario.now(engine, tokens[0]).name, "Bear")
	assert_eq(Scenario.pt(engine, tokens[0]), [2, 2])


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "Create a token that's a copy of target token."
func _mirror() -> MmCardDefinition:
	var copy: CreateTokenCopyEffect = CreateTokenCopyEffect.new()
	copy.selection = Scenario.targeted(0)
	return Scenario.instant("Mirror", Scenario.mana_cost(0), [Scenario.target(IsTokenFilter.new())], [copy])


func _target_creature() -> TargetRequirement:
	return Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
