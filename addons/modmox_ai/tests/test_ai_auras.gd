extends GutTest
## Auras (engine ADR 0064): an Aura spell is cast when simulation says it is worth it, as any
## permanent is, and every Aura so far helps what it enchants, so it is aimed at its own
## permanents. The Board Evaluator values an enchanted land as any land, so a land's new
## types score the same on either side: without that rule its own land would be a coin flip.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_a_land_aura_is_aimed_at_its_own_land_at_every_level() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		var engine: MmEngine = _lands_ready([])
		engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _aura_in_hand(engine)))
		var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
		assert_true(_has_villain_land(engine, decision), "The Villain's land could be enchanted too.")

		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

		assert_eq(engine.game_state().object(target.id).controller_id, engine.hero().id)


func test_a_cheap_agent_aims_its_aura_at_an_untapped_land() -> void:
	var tapper: MmCardDefinition = Scenario.instant("Tapper", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(CardType.LAND))], [Scenario.tap(Scenario.targeted(0))])
	var engine: MmEngine = _lands_ready([tapper])
	var forests: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Forest")
	assert_eq(Scenario.cast_and_resolve(engine, "Tapper", [MmReference.to_object(forests[0])]), "")
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, _aura_in_hand(engine)))

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, forests[1], "What the Aura gives the untapped Forest can be used this turn.")


func test_an_aura_that_draws_a_card_as_it_enters_is_cast_in_the_main_phase() -> void:
	var engine: MmEngine = _lands_ready([])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Presence")


func test_a_land_made_every_basic_land_type_pays_for_a_spell_of_another_color() -> void:
	# CR 305.7 (engine ADR 0018): once the Forest is a Plains too, it taps for {W}.
	var squire: MmCardDefinition = Scenario.creature("Squire", 2, 2, [], Scenario.mana_cost(0, [MmMana.Type.WHITE]))
	var engine: MmEngine = _lands_ready([squire], _every_type_presence())
	var forest: int = Scenario.permanents_named(engine, engine.hero().id, "Forest")[0]
	assert_eq(Scenario.cast_and_resolve(engine, "Presence", [MmReference.to_object(forest)]), "")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: int = AiScenario.ask(engine, agent)
	assert_eq(AiScenario.cast_name(engine, play), "Squire", "Its only white mana is the enchanted Forest.")
	assert_eq(engine.submit(play), "")
	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")

	var cast: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])
	assert_eq(engine.game_state().characteristics_of(cast).name, "Squire")
	assert_true(engine.game_state().object(forest).is_tapped)


## Nylea's Presence as an Aura costing {0}, without its draw: "Enchant land. Enchanted land
## is every basic land type in addition to its other types."
func _every_type_presence() -> MmCardDefinition:
	return Scenario.aura("Presence", null, [Scenario.continuous_static([Scenario.every_basic_land_type(Scenario.attached())])])


## Nylea's Presence as an Aura costing {0}: "Enchant land. When this Aura enters, draw a
## card. Enchanted land is a Swamp in addition to its other types."
func _presence() -> MmCardDefinition:
	var drawing: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.draw_cards(1, Scenario.you())])
	var swamp: ContinuousStaticAbility = Scenario.continuous_static([Scenario.add_subtypes(["Swamp"], Scenario.attached())])
	return Scenario.aura("Presence", null, [drawing, swamp])


func _aura_in_hand(engine: MmEngine) -> int:
	return Scenario.card_in_hand(engine, engine.hero(), "Presence")


func _has_villain_land(engine: MmEngine, decision: ChooseTargetDecision) -> bool:
	for candidate: MmReference in decision.candidates:
		if candidate.is_object() and engine.game_state().object(candidate.id).controller_id == engine.villain().id:
			return true
	return false


## The Hero's precombat main phase of Game Turn 3, each player having played a Forest each
## turn, with Presence ([param presence] if given) and [param extras] in the Hero's hand.
func _lands_ready(extras: Array[MmCardDefinition], presence: MmCardDefinition = null) -> MmEngine:
	var forest: MmCardDefinition = Scenario.basic_land("Forest")
	var hero_cards: Array[MmCardDefinition] = [forest, forest, presence if presence != null else _presence()]
	hero_cards.append_array(extras)
	var villain_cards: Array[MmCardDefinition] = [forest, Scenario.creature("Ogre", 3, 3, [], Scenario.mana_cost(9))]
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(hero_cards), Scenario.cycled(villain_cards))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 3, 2, "Presence"):
			return false
		for extra: MmCardDefinition in extras:
			if Scenario.card_in_hand(running, running.hero(), extra.name) == -1:
				return false
		return not Scenario.permanents_named(running, running.villain().id, "Forest").is_empty())
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
