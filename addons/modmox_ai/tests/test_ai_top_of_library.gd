extends GutTest
## Casting from the top of the library (ADR 0054). The Agent sees its own top card while it
## controls a permanent that lets it look, in its view and its World alike, and casts from
## there like from its hand. Of two creatures that cost the same, the one on top is cast,
## since that keeps the other in hand: a FULL Agent by simulation, a CHEAP one by rule.
## Lookout is Assemble the Players as an enchantment costing {0}; Kit a 1/1 costing {W},
## which one Elf pays for.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_casts_the_creature_on_top_and_keeps_the_one_in_hand() -> void:
	var engine: MmEngine = _hero_with_a_kit_on_top_and_in_hand()

	var play: int = AiScenario.ask(engine, AiAgent.new())

	var cast: CastSpellAction = AiScenario.action_at(engine, play) as CastSpellAction
	assert_not_null(cast, "It casts something.")
	assert_eq(cast.object_id, engine.hero().library.top().id, "From the top of its library.")


func test_a_cheap_agent_casts_the_creature_on_top_of_two_that_cost_the_same() -> void:
	var engine: MmEngine = _hero_with_a_kit_on_top_and_in_hand()

	var play: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))

	var cast: CastSpellAction = AiScenario.action_at(engine, play) as CastSpellAction
	assert_not_null(cast)
	assert_eq(cast.object_id, engine.hero().library.top().id)


func test_an_agent_knows_only_its_own_top_card() -> void:
	var engine: MmEngine = _hero_with_a_kit_on_top_and_in_hand()
	var top: int = engine.hero().library.top().card_id

	for rng_seed: int in range(1, 6):
		var mine: MmGameState = engine.simulation_source_for(engine.hero().id).world(MmRng.new(rng_seed))
		assert_eq(mine.player(engine.hero().id).library.top().card_id, top, "Its World keeps the card it sees.")
	assert_null(engine.view_for(engine.villain()).libraries[engine.hero().id][0], "The Villain sees nothing of it.")


## The Hero in their main phase with Lookout and an Elf, a Kit in hand and another on top
## of their library.
func _hero_with_a_kit_on_top_and_in_hand() -> MmEngine:
	var kit: MmCardDefinition = Scenario.creature("Kit", 1, 1, [], Scenario.mana_cost(0, [MmMana.Type.WHITE]))
	var lookout: MmCardDefinition = Scenario.lookout()
	var elf: MmCardDefinition = Scenario.elf()
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([lookout, elf, kit]), Scenario.cycled([]))
	var engine: MmEngine = Scenario.top_ready(setup, [lookout, elf], [kit], ["Kit"])
	assert_not_null(engine, "No seed gave the needed cards.")
	assert_true(Scenario.offers_cast(engine, engine.hero().library.top().id))
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Kit"), -1)
	return engine
