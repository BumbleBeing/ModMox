extends GutTest
## What the Agent finds with a search (ADR 0057): always as many cards as it may. A CHEAP
## Agent finds the basic land of the color its hand most lacks; a FULL Agent simulates one
## card of each name it could find.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_cheap_agent_finds_the_basic_land_its_hand_lacks() -> void:
	var engine: MmEngine = _searching_with_white_in_hand()
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var found: Array = AiScenario.ask(engine, cheap)

	assert_eq(found.size(), 1)
	assert_eq(engine.game_state().characteristics_of(engine.game_state().object(found[0])).name, "Plains",
		"Its Knight costs {W}{W}, and it controls only Forests.")
	assert_eq(engine.submit(found), "")


func test_a_full_agent_finds_one_card_and_says_it_compared_them() -> void:
	var engine: MmEngine = _searching_with_white_in_hand()
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var found: Array = AiScenario.ask(engine, easy)

	assert_eq(found.size(), 1, "As many as it may.")
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)
	assert_eq(engine.submit(found), "")


func test_with_nothing_to_find_the_agent_finds_nothing() -> void:
	var plains_only: SearchLibraryEffect = Scenario.search(Scenario.all_of([Scenario.basic_land_card(), Scenario.has_subtype("Island")]))
	var engine: MmEngine = _searching_with_white_in_hand(plains_only)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var found: Array = AiScenario.ask(engine, cheap)

	assert_eq(found, [])
	assert_eq(cheap.explain(), AiAgent.Reason.ONLY_CHOICE)


## The Hero searching with a Seek in their first main phase, holding a Knight costing
## {W}{W}, having played a Forest, with Forests and Plains in their library.
func _searching_with_white_in_hand(effect: SearchLibraryEffect = null) -> MmEngine:
	var knight: MmCardDefinition = Scenario.creature("Knight", 2, 2)
	knight.mana_cost = Scenario.mana_cost(0, [MmMana.Type.WHITE, MmMana.Type.WHITE])
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.free_seek("Seek", effect), Scenario.basic_land("Forest"), knight,
		Scenario.basic_land("Forest"), Scenario.basic_land("Plains")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 1, "Seek") or Scenario.card_in_hand(running, running.hero(), "Knight") == -1:
			return false
		for permanent: MmGameObject in running.game_state().battlefield.objects():
			if permanent.controller_id == running.hero().id and running.game_state().characteristics_of(permanent).name != "Forest":
				return false
		return true)
	assert_not_null(engine)
	assert_eq(Scenario.cast_to_search(engine), "")
	return engine
