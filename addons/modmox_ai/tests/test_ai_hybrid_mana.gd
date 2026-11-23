extends GutTest
## Hybrid mana symbols (CR 107.4e, engine ADR 0077): the AI casts a creature costing
## {1}{B/R} with lands of either color, and its payment planner, which Auto-tap uses for the
## Hero (game ADR 0031), pays the {B/R} with a source of one of its colors before generic.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_it_casts_a_black_red_creature_with_only_mountains_or_only_swamps() -> void:
	for land_name: String in ["Mountain", "Swamp"]:
		var engine: MmEngine = _ready_to_pay([land_name, land_name], [land_name])
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

		var cast: CastSpellAction = _first_spell_cast(engine, agent)

		assert_not_null(cast, "With %ss it casts Cinder Pup." % land_name)
		if cast == null:
			continue
		assert_true(engine.pending_decision() is PayManaDecision, "It is paying for Cinder Pup.")
		_let_the_agent_pay(engine)
		assert_eq(Scenario.names(engine, engine.game_state().stack), ["Cinder Pup"])


func test_the_hybrid_symbol_is_paid_with_the_mountain_before_the_forest_pays_the_generic() -> void:
	var engine: MmEngine = _ready_to_pay(["Forest", "Mountain"])
	var forest: int = Scenario.permanent_named(engine, engine.hero().id, "Forest")
	var mountain: int = Scenario.permanent_named(engine, engine.hero().id, "Mountain")
	var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(engine.submit(Scenario.cast_index(priority, Scenario.card_in_hand(engine, engine.hero(), "Cinder Pup"))), "")

	_let_the_agent_pay(engine)

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Cinder Pup"])
	assert_eq(_tapped_in_order(engine), [mountain, forest], "The color first, then generic.")


## The Hero in their main phase on Game Turn 3 with the lands named [param land_names],
## holding Cinder Pup, a 2/1 creature costing {1}{B/R}. Their deck's lands are those named
## [param deck_lands].
func _ready_to_pay(land_names: Array[String], deck_lands: Array[String] = ["Mountain", "Swamp", "Forest"]) -> MmEngine:
	var pup: MmCardDefinition = Scenario.creature("Cinder Pup", 2, 1, [], Scenario.hybrid_cost(1, [[Type.BLACK, Type.RED]]))
	var extras: Array[MmCardDefinition] = [Scenario.free_land_fetch(), pup]
	var deck: Array[MmCardDefinition] = extras.duplicate()
	for land_name: String in deck_lands:
		deck.append(Scenario.basic_land(land_name))
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, deck)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	if engine == null:
		return null
	assert_eq(Scenario.fetch_lands(engine, land_names), "")
	return engine


## Lets [param agent] answer the Hero's priority, playing a land if it wants one first, until
## it casts a spell, which is returned once submitted, or does something else (null).
func _first_spell_cast(engine: MmEngine, agent: AiAgent) -> CastSpellAction:
	while engine.pending_decision() is PriorityDecision and engine.pending_decision().player_id == engine.hero().id:
		var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
		var answer: int = AiScenario.ask(engine, agent)
		var action: MmAction = priority.actions[answer] if answer >= 0 and answer < priority.actions.size() else null
		if not (action is PlayLandAction or action is CastSpellAction):
			return null
		assert_eq(engine.submit(answer), "")
		if action is CastSpellAction:
			return action as CastSpellAction
	return null


## Lets a Normal Agent pay for what is being cast, as Auto-tap does.
func _let_the_agent_pay(engine: MmEngine) -> void:
	var agent: AiAgent = AiAgent.new()
	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")
		assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN)


## The Hero's permanents tapped since the cast began, in the order they were tapped.
func _tapped_in_order(engine: MmEngine) -> Array[int]:
	var since: int = 0
	var events: Array[MmEvent] = engine.event_log()
	for index: int in events.size():
		if events[index] is ZoneChangeEvent and (events[index] as ZoneChangeEvent).reason == ZoneChangeEvent.Reason.CAST:
			since = index
	var tapped: Array[int] = []
	for index: int in range(since, events.size()):
		var tap: TapEvent = events[index] as TapEvent
		if tap != null:
			tapped.append(tap.object_id)
	return tapped
