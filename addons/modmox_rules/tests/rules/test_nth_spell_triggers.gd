extends GutTest
## "Whenever you cast your second spell each turn" (CR 601.2i, 603.2), as Clarion Spirit's:
## a spell-cast trigger with SpellCastTrigger.nth_each_turn. Each player's spells cast this
## turn are counted on the player as each becomes cast, whether or not the ability's source
## was on the battlefield then, and the count starts again as each turn begins.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_the_second_spell_triggers_it_and_the_first_and_third_do_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.clarion()], [_gift("Gift"), _gift("Second Gift"), _gift("Third Gift")])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Clarion"), 0, "The first spell.")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Clarion"), 1)
	assert_eq(Scenario.cast_and_resolve(engine, "Third Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Clarion"), 1, "The second only.")
	assert_eq(engine.hero().spells_cast_this_turn, 3)


func test_a_spell_cast_before_it_was_on_the_battlefield_counts() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.clarion(), _gift("Gift")])

	assert_eq(Scenario.cast_and_resolve(engine, "Clarion"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(_triggers_of(engine, "Clarion"), 1, "Clarion itself was the first spell this turn.")


func test_the_count_starts_again_each_turn() -> void:
	var engine: MmEngine = _hero_main([Scenario.clarion()], [_gift("Gift"), _gift("Second Gift"), _gift("Third Gift")])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain, as the active player, has it first.
	assert_eq(engine.hero().spells_cast_this_turn, 0)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Second Gift")), "")
	assert_eq(_triggers_of(engine, "Clarion"), 0, "The first spell of Game Turn 4.")
	# CR 117.3c: the Hero has priority again once their spell is cast.
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Third Gift")), "")

	assert_eq(_triggers_of(engine, "Clarion"), 1)


func test_whose_counts_the_casters_own_spells() -> void:
	var theirs: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(Scenario.nth_spell(2, Whose.OPPONENT),
		[Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([], [_gift("Gift"), _gift("Second Gift")], [Scenario.clarion(), theirs])
	# The Villain's own two permanents, cast on Game Turn 2, may have triggered their Clarion.
	var clarion_before: int = _triggers_of(engine, "Clarion")

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Clarion"), clarion_before, "The Villain's Clarion waits for the Villain's spells.")
	assert_eq(_triggers_of(engine, "Watcher"), 1, "The Hero is the Villain's opponent.")


func test_copies_and_replays_keep_the_count() -> void:
	var engine: MmEngine = _hero_main([Scenario.clarion()], [_gift("Gift"), _gift("Second Gift")])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_eq(copy.hero().spells_cast_this_turn, 1)
	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(Scenario.cast_and_resolve(copy, "Second Gift"), "")
	assert_eq(_triggers_of(copy, "Clarion"), 1, "The copy's second spell is its second.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_nth_spell_triggers.tres"
	assert_eq(ResourceSaver.save(Scenario.clarion(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: SpellCastTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as SpellCastTrigger
	assert_eq(trigger.nth_each_turn, 2)
	assert_eq(trigger.whose, Whose.YOU)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "You gain 1 life."
func _gift(card_name: String) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


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
