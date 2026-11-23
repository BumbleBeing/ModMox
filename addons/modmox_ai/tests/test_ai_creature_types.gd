extends GutTest
## Choosing a creature type as a permanent enters (CR 614.12, ADR 0052). Of the 377 types,
## only those of the Agent's own creatures are worth anything to it: a FULL Agent simulates
## the best MOST_TYPES_SIMULATED of them, a CHEAP one takes the best. Neither knows any card's
## name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_names_the_type_most_of_its_creatures_share() -> void:
	var engine: MmEngine = _choosing([Scenario.mouser(), Scenario.mouser("Tabby"), Scenario.typed_creature("Elf", 1, 1, ["Elf"])])
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq(_named(engine, answer), "Cat")
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)


func test_a_cheap_agent_names_the_type_most_of_its_creatures_share() -> void:
	var engine: MmEngine = _choosing([Scenario.typed_creature("Elf", 1, 1, ["Elf"]), Scenario.mouser(), Scenario.mouser("Tabby")])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_named(engine, answer), "Cat")
	assert_eq(engine.submit(answer), "")


func test_with_no_creatures_in_play_it_names_the_type_of_the_creature_cards_it_owns() -> void:
	var engine: MmEngine = _choosing([], [Scenario.mouser()])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_named(engine, answer), "Cat")


func test_with_no_creature_anywhere_it_simulates_nothing() -> void:
	var engine: MmEngine = _choosing([])
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq(answer, 0)
	assert_eq(easy.explain(), AiAgent.Reason.ONLY_CHOICE)
	assert_eq(easy.rollout_count(), 0)


func test_a_full_agent_simulates_at_most_three_types() -> void:
	var creatures: Array[MmCardDefinition] = []
	for subtype: String in ["Bear", "Cat", "Elf", "Goblin", "Wolf"]:
		creatures.append(Scenario.typed_creature("A " + subtype, 1, 1, [subtype]))
	var engine: MmEngine = _choosing(creatures)
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	AiScenario.ask(engine, easy)

	assert_eq(easy.explain_detail().split(", ").size(), AiAgent.MOST_TYPES_SIMULATED)


func test_a_changeling_counts_toward_every_type() -> void:
	# CR 702.73a: with a Wolf beside it, its controller controls two Wolves and one of
	# everything else, its printed Shapeshifter included.
	var engine: MmEngine = _choosing([Scenario.changeling(), Scenario.typed_creature("Wolf", 1, 1, ["Wolf"])])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_named(engine, answer), "Wolf")


## The Hero has [param creatures] on the battlefield and [param extras] in hand, and has just
## cast a Rally, whose type is asked.
func _choosing(creatures: Array[MmCardDefinition], extras: Array[MmCardDefinition] = []) -> MmEngine:
	var hand: Array[MmCardDefinition] = [Scenario.rally()]
	hand.append_array(extras)
	var engine: MmEngine = AiScenario.ready_with(creatures, [], hand)
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.cast_and_resolve(engine, "Rally")
	assert_true(engine.pending_decision() is ChooseCreatureTypeDecision)
	return engine


func _named(engine: MmEngine, answer: int) -> String:
	return (engine.pending_decision() as ChooseCreatureTypeDecision).creature_types[answer]
