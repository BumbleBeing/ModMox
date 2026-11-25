extends GutTest
## "Whenever you draw your second card each turn" (CR 121.1, 603.2), as Faerie Vandal's: a
## CardDrawnTrigger with nth_each_turn. Each player's cards drawn this turn are counted on
## the player as each is drawn, one at a time (CR 121.2), whether or not the ability's source
## was on the battlefield then, and the count starts again as each turn begins.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_the_draw_steps_card_is_the_first_and_the_second_card_triggers_it_and_the_third_does_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.vandal()], [_draw_one("Peek"), _draw_one("Second Peek")])
	assert_eq(engine.hero().cards_drawn_this_turn, 1, "CR 504.1: the card of the Hero's draw step.")
	assert_eq(_triggers_of(engine, "Vandal"), 0)

	_cast_at_hero(engine, "Peek")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Vandal"), 1, "The second card this turn.")
	_cast_at_hero(engine, "Second Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Vandal"), 1, "The second only.")
	assert_eq(engine.hero().cards_drawn_this_turn, 3)


func test_two_cards_drawn_by_one_effect_trigger_it_once_on_the_second() -> void:
	var engine: MmEngine = _hero_main([Scenario.vandal()], [Scenario.free_draw("Insight", 2)])
	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain, as the active player, has it first.
	assert_eq(engine.hero().cards_drawn_this_turn, 0, "Nothing drawn yet on the Villain's turn.")

	_cast_at_hero(engine, "Insight")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Vandal"), 1, "CR 121.2: each card is drawn on its own, so the second triggers it.")
	assert_eq(engine.hero().cards_drawn_this_turn, 2)


func test_a_card_drawn_before_it_was_on_the_battlefield_counts() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.vandal(), _draw_one("Peek")])

	assert_eq(Scenario.cast_and_resolve(engine, "Vandal"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	_cast_at_hero(engine, "Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Vandal"), 1, "The draw step's card, drawn before Vandal arrived, was the first.")


func test_the_count_starts_again_each_turn() -> void:
	var engine: MmEngine = _hero_main([Scenario.vandal()], [_draw_one("Peek"), _draw_one("Second Peek")])

	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)
	assert_eq(engine.hero().cards_drawn_this_turn, 0)
	_cast_at_hero(engine, "Peek")
	# CR 117.3c: the Hero has priority again once their spell is cast.
	_cast_at_hero(engine, "Second Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Vandal"), 1, "The second card the Hero drew on Game Turn 4.")


func test_whose_counts_the_drawers_own_cards() -> void:
	var theirs: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(Scenario.draws(2, Whose.OPPONENT),
		[Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([], [_draw_one("Peek")], [Scenario.vandal(), theirs])
	var vandal_before: int = _triggers_of(engine, "Vandal")

	_cast_at_hero(engine, "Peek")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Vandal"), vandal_before, "The Villain's Vandal waits for the Villain's cards.")
	assert_eq(_triggers_of(engine, "Watcher"), 1, "The Hero is the Villain's opponent.")


func test_copies_and_replays_keep_the_count() -> void:
	var engine: MmEngine = _hero_main([Scenario.vandal()], [_draw_one("Peek")])

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(copy.hero().cards_drawn_this_turn, 1)
	assert_eq(replayed.fingerprint(), engine.fingerprint())
	_cast_at_hero(copy, "Peek")
	assert_eq(Scenario.resolve_stack(copy), "")
	assert_eq(_triggers_of(copy, "Vandal"), 1, "The copy's second card is its second.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_nth_card_drawn_triggers.tres"
	assert_eq(ResourceSaver.save(Scenario.vandal(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: CardDrawnTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as CardDrawnTrigger
	assert_eq(trigger.nth_each_turn, 2)
	assert_eq(trigger.whose, Whose.YOU)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "Target player draws a card."
func _draw_one(card_name: String) -> MmCardDefinition:
	return Scenario.free_draw(card_name, 1)


## Casts the Hero's [param card_name] at the Hero, while the Hero has priority.
func _cast_at_hero(engine: MmEngine, card_name: String) -> void:
	var card: int = Scenario.card_in_hand(engine, engine.hero(), card_name)
	assert_eq(Scenario.cast(engine, card, [MmReference.to_player(engine.hero().id)]), "")


## How many times an ability of a permanent named [param card_name] has triggered.
func _triggers_of(engine: MmEngine, card_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == card_name:
			count += 1
	return count


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	_setup = setup
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
