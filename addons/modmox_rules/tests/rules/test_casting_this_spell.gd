extends GutTest
## "When you cast this spell, if you've cast another spell this turn, ..." (CR 601.2i,
## 603.4), as Sage of the Skies says. A trigger that can't trigger from the battlefield works
## wherever it can (CR 113.6k), so the spell's own cast trigger works while it is on the
## stack, and goes on the stack above it. The intervening "if" counts the controller's other
## spells cast this turn, not the spell itself.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_it_triggers_from_the_stack_as_the_spell_becomes_cast() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), _bird()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bird")), "")

	var stack: Array[MmGameObject] = engine.game_state().stack.objects()
	assert_eq(stack.size(), 2, "The spell, and its trigger above it.")
	assert_true(stack[1].ability is TriggeredAbility)
	assert_eq(stack[1].source_object_id, stack[0].id, "Its source is the spell on the stack.")
	assert_eq(stack[1].controller_id, engine.hero().id)
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, 22, "The Gift's 1, then the Bird's own trigger's 1.")


func test_as_the_first_spell_of_the_turn_it_does_not_trigger() -> void:
	var engine: MmEngine = _hero_main([], [_bird()])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bird")), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0, "CR 603.4: no other spell this turn.")


func test_the_other_players_spells_do_not_count() -> void:
	var engine: MmEngine = _hero_main([], [_bird()], [_gift("Their Gift")])
	assert_eq(Scenario.pass_priority(engine), "", "The Villain may cast in the Hero's main phase.")
	assert_eq(Scenario.cast_and_resolve(engine, "Their Gift"), "")
	assert_eq(engine.villain().spells_cast_this_turn, 1)
	assert_true((engine.pending_decision() as PriorityDecision).player_id == engine.hero().id)

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bird")), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0, "\"You've cast\": the Hero's spells only.")


func test_on_the_battlefield_it_never_triggers() -> void:
	var engine: MmEngine = _hero_main([_bird()], [_gift(), _gift("Second Gift")])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Second Gift"), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0, "A permanent is never cast.")


func test_another_spell_cast_this_turn_still_counts_once_it_has_resolved() -> void:
	var engine: MmEngine = _hero_main([], [_gift(), _bird()])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.game_state().stack.size(), 0)

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bird")), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 1)


# --- Helpers ---------------------------------------------------------------------------


func _gift(card_name: String = "Gift") -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


## A 1/1 costing {0}: "When you cast this spell, if you've cast another spell this turn, you
## gain 1 life."
func _bird() -> MmCardDefinition:
	return Scenario.creature("Bird", 1, 1, [Scenario.triggered(Scenario.cast_this_spell(),
		[Scenario.gain_life(1, Scenario.you())], [], CastAnotherSpellThisTurnCondition.new())])


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_hand: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hand, villain_hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hand, villain_hand, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
