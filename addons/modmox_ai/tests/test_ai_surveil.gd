extends GutTest
## What the Agent does with a surveil (engine ADR 0068): it keeps a land while it has fewer
## than six counting those it controls, those in its hand and those kept above it, and a
## spell it could cast with one more land than that; it graveyards the rest. Lands it keeps
## go on top while it is short of lands, then spells, cheapest first. A FULL Agent answers as
## a CHEAP one does: one-step simulation sees neither the library's top nor the graveyard.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_land_is_graveyarded_when_it_has_lands_enough() -> void:
	var engine: MmEngine = _surveilling(1, ["Forest"], Scenario.copies(Scenario.basic_land("Forest"), 6), 6)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: Array = AiScenario.ask(engine, cheap)

	assert_eq(answer, [_top_ids(engine, 1), []], "Six lands between the battlefield and the hand.")
	assert_eq(engine.submit(answer), "")


func test_a_land_is_kept_when_it_is_short_of_lands() -> void:
	var engine: MmEngine = _surveilling(1, ["Forest"], [_wurm(), _bear(), Scenario.basic_land("Forest")], 1, 3)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: Array = AiScenario.ask(engine, cheap)

	assert_eq(answer, [[], _top_ids(engine, 1)])
	assert_eq(cheap.explain(), AiAgent.Reason.LAND_COUNT)


func test_a_spell_it_could_soon_cast_is_kept_and_one_it_could_not_is_graveyarded() -> void:
	var bear_on_top: MmEngine = _surveilling(1, ["Bear"], [_wurm(), _bear(), Scenario.basic_land("Forest")], 1, 3)
	var wurm_on_top: MmEngine = _surveilling(1, ["Wurm"], [_wurm(), _bear(), Scenario.basic_land("Forest")], 1, 3)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(AiScenario.ask(bear_on_top, cheap), [[], _top_ids(bear_on_top, 1)], "Bear costs 2.")
	assert_eq(AiScenario.ask(wurm_on_top, cheap), [_top_ids(wurm_on_top, 1), []], "Wurm costs 6, far beyond its lands.")


func test_short_of_lands_it_puts_a_land_above_a_spell() -> void:
	var engine: MmEngine = _surveilling(2, ["Bear", "Forest"], [_wurm(), _bear(), Scenario.basic_land("Forest")], 1, 3)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)
	var top: Array[int] = _top_ids(engine, 2)

	var answer: Array = AiScenario.ask(engine, cheap)

	assert_eq(answer, [[], [top[1], top[0]]], "The Forest first, then the Bear.")
	assert_eq(engine.submit(answer), "")


func test_a_full_agent_answers_as_a_cheap_one_does() -> void:
	var engine: MmEngine = _surveilling(2, ["Bear", "Forest"], [_wurm(), _bear(), Scenario.basic_land("Forest")], 1, 3)
	var full: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(AiScenario.ask(engine, full), AiScenario.ask(engine, cheap))


func test_wary_thespian_is_cast_when_its_mana_is_there() -> void:
	var thespian: MmCardDefinition = Scenario.thespian("Thespian")
	thespian.mana_cost = Scenario.mana_cost(1, [MmMana.Type.GREEN])
	var cards: Array[MmCardDefinition] = Scenario.cycled([thespian, Scenario.basic_land("Forest"), Scenario.basic_land("Forest")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 3, 2, "Thespian"))
	assert_not_null(engine)
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	assert_eq(AiScenario.cast_name(engine, AiScenario.ask(engine, easy)), "Thespian")


## A 2/2 costing {1}{G}.
func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(1, [MmMana.Type.GREEN]))


## A 6/4 costing {4}{G}{G}.
func _wurm() -> MmCardDefinition:
	return Scenario.creature("Wurm", 6, 4, [], Scenario.mana_cost(4, [MmMana.Type.GREEN, MmMana.Type.GREEN]))


## The Hero on Game Turn 1, having cast a Thespian ("When this creature enters or dies,
## surveil [param amount].") for {0} with its surveil asked, the top of their library
## named [param tops], and between the battlefield and their hand at least
## [param least_lands] and at most [param most_lands] lands. Their deck cycles through a
## Thespian and [param others].
func _surveilling(amount: int, tops: Array[String], others: Array[MmCardDefinition], least_lands: int,
		most_lands: int = 40) -> MmEngine:
	var cards: Array[MmCardDefinition] = [Scenario.thespian("Thespian", amount)]
	cards.append_array(others)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(Scenario.cycled(cards), Scenario.cycled([])),
		func(running: MmEngine) -> bool:
			if not Scenario.ready_in_main(running, 1, 0, "Thespian"):
				return false
			var lands: int = _lands_of(running)
			if lands < least_lands or lands > most_lands:
				return false
			var library: Array[MmGameObject] = running.hero().library.objects()
			for index: int in tops.size():
				if running.game_state().characteristics_of(library[index]).name != tops[index]:
					return false
			return true, 2000)
	assert_not_null(engine, "No seed gave the needed hand and library.")
	assert_eq(Scenario.cast_and_resolve(engine, "Thespian"), "")
	assert_eq(Scenario.pass_to_surveil(engine), "")
	return engine


## The lands the Hero controls and holds.
func _lands_of(engine: MmEngine) -> int:
	var lands: int = 0
	for card: MmGameObject in engine.hero().hand.objects() + engine.game_state().battlefield.objects():
		var is_mine: bool = card.zone().kind == MmZone.Kind.HAND or card.controller_id == engine.hero().id
		if is_mine and engine.game_state().characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
			lands += 1
	return lands


func _top_ids(engine: MmEngine, count: int) -> Array[int]:
	return (engine.pending_decision() as SurveilDecision).card_ids.slice(0, count)
