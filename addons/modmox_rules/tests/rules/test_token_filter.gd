extends GutTest
## IsTokenFilter: a token (CR 111.1), and wrapped in a NotFilter "nontoken", as in "whenever
## a nontoken Cat creature you control enters". A token that has left the battlefield is
## still seen as a token, by the object it was.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_it_matches_a_token_and_not_a_card() -> void:
	var engine: MmEngine = _hero_main([_cat_card("Lion")], [], [Scenario.free_tokens("Kitten", Scenario.cat())])
	Scenario.cast_and_resolve(engine, "Kitten")
	var state: MmGameState = engine.game_state()
	var token: MmReference = MmReference.to_object(Scenario.tokens_on_battlefield(engine)[0])
	var card: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Lion"))

	var is_token: IsTokenFilter = IsTokenFilter.new()
	var nontoken: NotFilter = Scenario.is_not(IsTokenFilter.new())

	assert_true(is_token.matches(state, token, null))
	assert_false(is_token.matches(state, card, null))
	assert_false(nontoken.matches(state, token, null))
	assert_true(nontoken.matches(state, card, null), "Nontoken.")


func test_it_never_matches_a_player() -> void:
	var engine: MmEngine = _hero_main([], [], [])

	assert_false(IsTokenFilter.new().matches(engine.game_state(), MmReference.to_player(engine.hero().id), null))


func test_a_dies_ability_sees_a_dying_token_as_a_token() -> void:
	var mourner: MmCardDefinition = Scenario.creature("Mourner", 0, 4,
		[Scenario.triggered(Scenario.dies(IsTokenFilter.new()), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([mourner], [],
		[Scenario.free_tokens("Kitten", Scenario.cat()), Scenario.free_destroy("Murder")])
	Scenario.cast_and_resolve(engine, "Kitten")
	var life: int = engine.hero().life

	Scenario.cast_and_resolve(engine, "Murder", [MmReference.to_object(Scenario.tokens_on_battlefield(engine)[0])])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1, "CR 603.10a: it is seen as it was on the battlefield, a token.")


func test_a_nontoken_cat_entering_makes_a_cat_and_the_cat_token_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([], [], [_pride(), _cat_card("Lion")])
	var hero_id: int = engine.hero().id

	Scenario.cast_and_resolve(engine, "Pride")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1, "Its own arrival, as a nontoken Cat; not its token's.")
	Scenario.cast_and_resolve(engine, "Lion")
	Scenario.resolve_stack(engine)
	var tokens: Array[int] = Scenario.tokens_on_battlefield(engine)
	assert_eq(tokens.size(), 2, "The Lion made one more, and neither token made another.")
	for cat: int in tokens:
		assert_eq([Scenario.now(engine, cat).power, Scenario.now(engine, cat).toughness], [2, 2], "Other Cats get +1/+1.")
	var pride: MmCharacteristics = Scenario.now(engine, Scenario.permanent_named(engine, hero_id, "Pride"))
	assert_eq([pride.power, pride.toughness], [2, 2], "Not itself.")


func test_a_cat_token_entering_alone_makes_no_cat() -> void:
	var engine: MmEngine = _hero_main([_pride()], [], [Scenario.free_tokens("Kitten", Scenario.cat())])
	var before: int = Scenario.tokens_on_battlefield(engine).size()

	Scenario.cast_and_resolve(engine, "Kitten")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), before + 1, "Only the Kitten's own Cat.")


## A 2/2 Cat: "Other Cats you control get +1/+1. Whenever a nontoken Cat creature you
## control enters, create a 1/1 white Cat creature token."
func _pride() -> MmCardDefinition:
	var other_cats: MmFilter = Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.has_subtype("Cat"),
		_yours(), Scenario.is_not(IsSourceFilter.new())])
	var anthem: ContinuousStaticAbility = Scenario.continuous_static([Scenario.modify_pt(1, 1, Scenario.each(other_cats))])
	var nontoken_cat: MmFilter = Scenario.all_of([Scenario.of_type(CardType.CREATURE), Scenario.has_subtype("Cat"),
		Scenario.is_not(IsTokenFilter.new())])
	var maker: TriggeredAbility = Scenario.triggered(Scenario.enters(nontoken_cat, MmTrigger.Whose.YOU),
		[Scenario.create_tokens(Scenario.cat())])
	var pride: MmCardDefinition = _cat_card("Pride", 2, 2)
	pride.abilities = [anthem, maker]
	return pride


func _yours() -> ControlledByFilter:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	return mine


func _cat_card(card_name: String, power: int = 1, toughness: int = 1) -> MmCardDefinition:
	var cat: MmCardDefinition = Scenario.creature(card_name, power, toughness)
	cat.subtypes = ["Cat"]
	return cat


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
