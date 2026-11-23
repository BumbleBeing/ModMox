extends GutTest
## Adventurer cards (CR 715, engine ADR 0078): the AI times casting a card as its Adventure by
## the Adventure's own effects, and casts the creature from exile once it is on an adventure.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_its_adventure_is_timed_as_a_combat_trick_and_its_creature_as_a_creature() -> void:
	var engine: MmEngine = _hero_main()
	var guide: int = Scenario.card_in_hand(engine, engine.hero(), "Guide")
	var world: MmGameState = engine.game_state()

	var as_adventure: AiTiming.Tag = AiTiming.tag_of_action(world, CastSpellAction.new(guide, true))
	var as_creature: AiTiming.Tag = AiTiming.tag_of_action(world, CastSpellAction.new(guide))

	assert_eq(as_adventure, AiTiming.Tag.COMBAT_TRICK, "Gift's +2/+1 until end of turn.")
	assert_ne(as_creature, AiTiming.Tag.COMBAT_TRICK)
	assert_eq(AiTiming.effects_of_action(world, CastSpellAction.new(guide)), [] as Array[MmEffect], "A creature only enters.")


func test_it_casts_the_creature_from_exile_once_it_is_on_an_adventure() -> void:
	var engine: MmEngine = _hero_main(true)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_adventure(engine, Scenario.card_in_hand(engine, engine.hero(), "Guide"), MmReference.to_object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var exiled: int = engine.game_state().exile.objects()[0].id
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var cast: CastSpellAction = _first_cast(engine, agent)

	assert_not_null(cast, "A free 1/1 flier is worth casting.")
	if cast != null:
		assert_eq([cast.object_id, cast.as_adventure], [exiled, false])


## Lets [param agent] answer the Hero's priority, playing a land first if it wants, until it
## casts something, returned unsubmitted, or does anything else (null).
func _first_cast(engine: MmEngine, agent: AiAgent) -> CastSpellAction:
	while engine.pending_decision() is PriorityDecision and engine.pending_decision().player_id == engine.hero().id:
		var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
		var answer: int = AiScenario.ask(engine, agent)
		var action: MmAction = priority.actions[answer] if answer >= 0 and answer < priority.actions.size() else null
		if action is CastSpellAction:
			return action as CastSpellAction
		if not action is PlayLandAction:
			return null
		assert_eq(engine.submit(answer), "")
	return null


## The Hero in their main phase on Game Turn 3 with Bear, a 2/2, on the battlefield,
## holding Guide (Scenario.adventurer()). With [param is_only_guide] their deck has one Guide
## and the rest Bears and Plains, so no other Guide is in hand to be cast instead.
func _hero_main(is_only_guide: bool = false) -> MmEngine:
	var bear: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	var extras: Array[MmCardDefinition] = [Scenario.adventurer()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(bear, no_cards, extras)
	if is_only_guide:
		var deck: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Plains"), 27)
		deck.append_array(Scenario.copies(bear[0], 12))
		deck.append(extras[0])
		setup = Scenario.setup_with(deck, Scenario.cycled(no_cards))
	var engine: MmEngine = Scenario.permanents_ready_with(setup, bear, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
