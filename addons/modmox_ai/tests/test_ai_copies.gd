extends GutTest
## A spell whose own cast trigger waits for another spell this turn, as Sage of the Skies's
## "When you cast this spell, if you've cast another spell this turn, copy this spell" does
## (engine ADR 0083): the Agent weighs another play followed by it, so it casts the other
## spell first and gets the copy.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_it_casts_another_spell_first_so_sage_is_copied() -> void:
	var engine: MmEngine = _hero_main()
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var first: int = _first_play(engine, agent)

	assert_eq(AiScenario.cast_name(engine, first), "Pup", "Cast alone first, Sage would never be copied.")
	assert_eq(engine.submit(first), "")
	_let_the_agent_play(engine, agent)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sage").size(), 2, "The card and its copy.")
	assert_eq(Scenario.events_of(engine, SpellCopiedEvent).size(), 1)


## The Hero in their main phase on Game Turn 3, holding the deck's one Sage (Scenario.sage())
## and a Pup, a free 1/1; the rest of the deck is Pups and Plains, so no other Sage is in hand.
func _hero_main() -> MmEngine:
	var pup: MmCardDefinition = Scenario.creature("Pup", 1, 1)
	var sage: MmCardDefinition = Scenario.sage()
	var deck: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Plains"), 27)
	deck.append_array(Scenario.copies(pup, 12))
	deck.append(sage)
	var no_cards: Array[MmCardDefinition] = []
	var hand: Array[MmCardDefinition] = [sage, pup]
	var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled(no_cards))
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, hand, no_cards, 3,
		MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


## [param agent]'s first answer to the Hero's priority that is not a land play, unsubmitted;
## any land it plays first is played.
func _first_play(engine: MmEngine, agent: AiAgent) -> int:
	var answer: int = AiScenario.ask(engine, agent)
	while AiScenario.action_at(engine, answer) is PlayLandAction:
		assert_eq(engine.submit(answer), "")
		answer = AiScenario.ask(engine, agent)
	return answer


## Lets [param agent] answer every Hero decision until the Hero's main phase ends.
func _let_the_agent_play(engine: MmEngine, agent: AiAgent) -> void:
	for attempt: int in 40:
		if engine.game_state().step != MmTurn.Step.PRECOMBAT_MAIN:
			return
		var pending: MmPendingDecision = engine.pending_decision()
		if pending == null or pending.player_id != engine.hero().id:
			assert_eq(Scenario.pass_priority(engine), "")
			continue
		assert_eq(AiScenario.let_answer(engine, agent), "")
