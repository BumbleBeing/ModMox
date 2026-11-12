extends GutTest
## Timing Tags are derived from what a card does (A164), and the Board Evaluator reads
## characteristics as they are now (A162, A179).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Tag := AiTiming.Tag


func test_timing_tags_come_from_each_cards_effects() -> void:
	var expected: Dictionary[String, Tag] = {
		"giant_growth": Tag.COMBAT_TRICK, "fog": Tag.COMBAT_TRICK, "lightning_bolt": Tag.REMOVAL,
		"terror": Tag.REMOVAL, "shatter": Tag.REMOVAL, "ancestral_recall": Tag.NONE, "dark_ritual": Tag.NONE,
	}
	for file_name: String in expected:
		var spell: SpellAbility = AiScenario.alpha(file_name).abilities[0] as SpellAbility
		assert_eq(AiTiming.tag_of_effects(spell.effects), expected[file_name], file_name)
	var abilities: Dictionary[String, Tag] = {
		"shivan_dragon": Tag.COMBAT_TRICK, "uthden_troll": Tag.COMBAT_TRICK, "samite_healer": Tag.COMBAT_TRICK,
		"goblin_balloon_brigade": Tag.EVASION, "prodigal_sorcerer": Tag.REMOVAL,
	}
	for file_name: String in abilities:
		var card: MmCardDefinition = AiScenario.alpha(file_name)
		var activated: ActivatedAbility = card.abilities.back() as ActivatedAbility
		assert_eq(AiTiming.tag_of_effects(activated.effects), abilities[file_name], file_name)


func test_a_modified_card_gets_the_tag_of_what_it_now_does() -> void:
	# ADR 0002: a Modification that swaps Giant Growth's pump for damage makes it removal.
	var changed: MmCardDefinition = AiScenario.alpha("giant_growth").duplicate(true)
	(changed.abilities[0] as SpellAbility).effects = [Scenario.deal_damage(3, Scenario.targeted(0))]

	assert_eq(AiTiming.tag_of_effects((changed.abilities[0] as SpellAbility).effects), Tag.REMOVAL)


func test_the_evaluator_counts_a_pump_until_end_of_turn() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("savannah_lions")], [],
		[Scenario.pump_spell("Pump", 1, 1)])
	assert_not_null(engine)
	var lions: int = Scenario.permanent_named(engine, engine.hero().id, "Savannah Lions")
	var before: int = AiBoardEvaluator.creature_value(engine.game_state(), engine.game_state().object(lions))

	Scenario.cast_and_resolve(engine, "Pump", [MmReference.to_object(lions)])

	assert_eq(AiBoardEvaluator.creature_value(engine.game_state(), engine.game_state().object(lions)), before + 25,
		"+1/+1 is worth 15 + 10.")


func test_flying_is_worth_ten_per_point_of_power() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("serra_angel"), AiScenario.free_alpha("hill_giant")], [])
	assert_not_null(engine)
	var state: MmGameState = engine.game_state()

	var angel: int = AiBoardEvaluator.creature_value(state, state.object(Scenario.permanent_named(engine, engine.hero().id, "Serra Angel")))

	# 80 + 15 x 4 + 10 x 4 + 5 x 0 (a free copy), flying 10 x 4, vigilance 5 x 8.
	assert_eq(angel, 80 + 60 + 40 + 0 + 40 + 40)


func test_a_creature_that_cannot_attack_yet_is_worth_less() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("hill_giant")], [],
		[AiScenario.free_alpha("hill_giant")])
	assert_not_null(engine)
	Scenario.cast_and_resolve(engine, "Hill Giant")
	var giants: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Hill Giant")
	var state: MmGameState = engine.game_state()
	var profile: AiProfile = AiProfile.new()

	var ready: int = AiBoardEvaluator.permanent_value(state, state.object(giants[0]), profile)
	var sick: int = AiBoardEvaluator.permanent_value(state, state.object(giants[1]), profile)

	assert_eq(sick, ready * profile.summoning_sick_percent / 100)
	assert_lt(sick, ready)


func test_a_card_in_hand_is_worth_more_the_more_it_costs() -> void:
	var engine: MmEngine = MmEngine.start(_setup())
	Scenario.keep_all(engine)
	var state: MmGameState = engine.game_state()
	var profile: AiProfile = AiProfile.new()
	assert_eq(engine.hero().hand.size(), 7)

	for card: MmGameObject in engine.hero().hand.objects():
		var characteristics: MmCharacteristics = state.characteristics_of(card)
		var expected: int = 5 if characteristics.has_card_type(MmCardTypes.CardType.LAND) else 5 + 10 * characteristics.mana_value()
		assert_eq(AiBoardEvaluator.hand_card_value(state, card, profile), expected, characteristics.name)


func test_winning_and_losing_dwarf_everything_else() -> void:
	var engine: MmEngine = MmEngine.start(_setup())
	engine.concede(engine.villain())

	assert_eq(AiBoardEvaluator.score(engine.game_state(), engine.hero().id, AiProfile.new()), AiBoardEvaluator.WIN)
	assert_eq(AiBoardEvaluator.score(engine.game_state(), engine.villain().id, AiProfile.new()), -AiBoardEvaluator.WIN)


func _setup() -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = load("res://content/decks/red_green.tres") as MmPlayerSetup
	setup.villain = load("res://content/decks/white_black.tres") as MmPlayerSetup
	return setup
