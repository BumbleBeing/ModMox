extends RefCounted
## Shared helpers for AI tests. Builds on the engine's Scenario helpers.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


## An authored Alpha card.
static func alpha(file_name: String) -> MmCardDefinition:
	return load("res://content/cards/alpha/%s.tres" % file_name) as MmCardDefinition


## A free copy of an authored Alpha card.
static func free_alpha(file_name: String) -> MmCardDefinition:
	return Scenario.free_copy(alpha(file_name))


## [param agent]'s answer to the decision pending in [param engine].
static func ask(engine: MmEngine, agent: AiAgent) -> Variant:
	var decision: MmPendingDecision = engine.pending_decision()
	return agent.answer(decision, engine.view_for(engine.game_state().player(decision.player_id)),
		engine.simulation_source_for(decision.player_id))


## Submits [param agent]'s answer to the pending decision. Returns the rejection, or "".
static func let_answer(engine: MmEngine, agent: AiAgent) -> String:
	return engine.submit(ask(engine, agent))


## The action at [param index] of the pending priority decision, or null.
static func action_at(engine: MmEngine, index: int) -> MmAction:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	return null if decision == null else decision.actions[index]


## The name of the card a priority answer casts, or "" if it casts nothing.
static func cast_name(engine: MmEngine, index: int) -> String:
	var cast: CastSpellAction = action_at(engine, index) as CastSpellAction
	return "" if cast == null else engine.game_state().characteristics_of(engine.game_state().object(cast.object_id)).name


## Each player's creatures (free copies) on the battlefield, stopped at the first decision
## of [param step] on Game Turn 3, the Hero's second turn, with each player holding their
## extras. Each extra must cost {0} or be a land.
static func ready_with(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = [], villain_extras: Array[MmCardDefinition] = [],
		step: MmTurn.Step = MmTurn.Step.PRECOMBAT_MAIN, villain_life: int = 20) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures, hero_extras, villain_extras)
	setup.villain.starting_life = villain_life
	return Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hero_extras, villain_extras, 3, step)


## Answers with the default test answers until [param engine]'s pending decision belongs to
## [param player_id] and is of [param kind].
static func pass_to(engine: MmEngine, player_id: int, kind: Script) -> String:
	return Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var pending: MmPendingDecision = running.pending_decision()
		return pending != null and pending.player_id == player_id and pending.get_script() == kind)


## The object a target answer chose.
static func chosen_target(engine: MmEngine, answer: int) -> MmReference:
	return (engine.pending_decision() as ChooseTargetDecision).candidates[answer]
