extends GutTest
## "Whenever you cast a spell during an opponent's turn" (CR 601.2i, 603.2), as Brineborn
## Cutthroat's: a spell-cast trigger with SpellCastTrigger.during_whose_turn, whose turn it
## must be as the spell becomes cast, relative to the ability's controller.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_your_spell_during_an_opponents_turn_triggers_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.cutthroat()], [_gift()])
	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain, as the active player, has it first.

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")

	assert_eq(_triggers_of(engine, "Cutthroat"), 1)


func test_your_spell_during_your_own_turn_does_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.cutthroat()], [_gift()])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")

	assert_eq(_triggers_of(engine, "Cutthroat"), 0)


func test_whose_turn_is_relative_to_the_abilitys_controller() -> void:
	var trigger: SpellCastTrigger = Scenario.during_turn(Scenario.casts(null, Whose.OPPONENT), Whose.YOU)
	var watcher: MmCardDefinition = Scenario.enchantment("Watcher", [Scenario.triggered(trigger, [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([], [_gift(), _gift("Second Gift")], [watcher])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Watcher"), 0, "Game Turn 3 is the Hero's, not the Watcher's controller's.")
	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Second Gift")), "")

	assert_eq(_triggers_of(engine, "Watcher"), 1, "Game Turn 4 is the Villain's.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_spell_cast_during_whose_turn.tres"
	assert_eq(ResourceSaver.save(Scenario.cutthroat(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: SpellCastTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as SpellCastTrigger
	assert_eq(trigger.during_whose_turn, Whose.OPPONENT)
	assert_eq(trigger.whose, Whose.YOU)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "You gain 1 life."
func _gift(card_name: String = "Gift") -> MmCardDefinition:
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
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
