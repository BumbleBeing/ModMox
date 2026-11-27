extends GutTest
## Milestone 21: what an encounter gives the Run Log (ADR 0074): every answer, the
## Villain's as well as the Hero's, in order, with the words of its decision and, for a
## choice from a list, of the option chosen; then who won, the turns played and both
## players' life.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const FOREST: String = "res://content/cards/alpha/forest.tres"
const BIG_GULP: String = "res://content/potions/big_gulp.tres"


## S7: each answer is recorded with who gave it, its decision's words and the answer; a
## priority answer with how many Actions there were and the words of the one chosen, the
## card's name among them.
func test_every_answer_is_recorded_with_its_words() -> void:
	var setup: MmEncounterSetup = _forests()
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_game_turn(engine, 4, true)

	var record: Dictionary = EncounterPresenter.record_of(setup, engine.decision_log())

	var answers: Array = record["answers"]
	assert_eq(answers.size(), engine.decision_log().size())
	var bys: Dictionary[String, bool] = {}
	var land_plays: int = 0
	for index: int in answers.size():
		var line: Dictionary = answers[index]
		bys[line["by"]] = true
		assert_ne(str(line["decision"]), "", "Answer %d has its decision's words." % index)
		assert_eq(line["answer"], engine.decision_log()[index])
		if str(line.get("chosen", "")).begins_with("play land"):
			land_plays += 1
			assert_string_contains(line["chosen"], "(Forest)")
			assert_gt(int(line["options"]), 1)
	assert_eq(bys.keys(), ["hero", "villain"] if bys.keys()[0] == "hero" else ["villain", "hero"])
	assert_gt(land_plays, 1, "The Forests played are among them.")


## S7: a concession is an answer of its own, and the record says who won, the turns played and
## both players' life.
func test_the_end_is_recorded() -> void:
	var setup: MmEncounterSetup = _forests()
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_game_turn(engine, 3, true)
	engine.concede(engine.villain())

	var record: Dictionary = EncounterPresenter.record_of(setup, engine.decision_log())

	var last: Dictionary = record["answers"][record["answers"].size() - 1]
	assert_eq(last["by"], "villain")
	assert_eq(last["decision"], "concede")
	assert_eq(record["winner"], "hero")
	assert_eq(record["turns"], engine.game_state().game_turn)
	assert_eq(record["hero_life"], engine.hero().life)
	assert_eq(record["villain_life"], engine.villain().life)


## An encounter not over has no winner.
func test_an_encounter_not_over_has_no_winner() -> void:
	var setup: MmEncounterSetup = _forests()
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_game_turn(engine, 2, true)

	assert_eq(EncounterPresenter.record_of(setup, engine.decision_log())["winner"], "")


## P2 (milestone 24): the record names the Hero's Potions used, by their places in the
## setup, so the run can take them out of the Satchel; none used is an empty list.
func test_the_potions_the_hero_used_are_recorded_by_their_places() -> void:
	var big_gulp: MmCardDefinition = load(BIG_GULP) as MmCardDefinition
	var setup: MmEncounterSetup = Scenario.setup_with(
		Scenario.cycled([Scenario.mana_land("Land", MmMana.Type.GREEN, 1), Scenario.creature("Bear", 2, 2)]),
		Scenario.cycled([]))
	setup.hero.potions = [big_gulp, big_gulp] as Array[MmCardDefinition]
	setup.hero.maximum_hand_size = MmPlayerSetup.NO_MAXIMUM_HAND_SIZE
	var engine: MmEngine = Scenario.find_engine(setup, func(found: MmEngine) -> bool:
		return Scenario.keep_all(found) == "" and Scenario.ready_in_main(found, 1, 1, "Bear"))
	assert_eq(EncounterPresenter.record_of(setup, engine.decision_log())["potions_used"], [] as Array[int])
	Scenario.cast_and_resolve(engine, "Bear")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var second: MmObjectView = engine.view_for(engine.hero()).potions[1]
	assert_eq(Scenario.activate(engine, second.id, [MmReference.to_object(bear)]), "")
	Scenario.resolve_stack(engine)

	var record: Dictionary = EncounterPresenter.record_of(setup, engine.decision_log())

	assert_eq(record["potions_used"], [1] as Array[int])


## The presenter records its own encounter from its setup and its decisions, undone ones
## left out.
func test_the_presenter_records_its_own_encounter() -> void:
	var setup: MmEncounterSetup = _forests()
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())

	var record: Dictionary = presenter.record()

	assert_eq(record["answers"], [])
	assert_eq(record["turns"], 0)


func _forests() -> MmEncounterSetup:
	var forest: MmCardDefinition = load(FOREST) as MmCardDefinition
	var cards: Array[MmCardDefinition] = []
	for index: int in 40:
		cards.append(forest)
	return Scenario.setup_with(cards, cards)
