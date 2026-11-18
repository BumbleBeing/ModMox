extends GutTest
## Costs that are not mana, paid once the mana is (CR 601.2h): "Pay N life" (CR 119.4) and
## "Tap N untapped creatures you control", whose creatures the payer picks. Both can be
## part of a flashback cost or an activated ability's. A creature with summoning sickness
## may be tapped for a cost that is not its own {T} (CR 302.6).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_paying_life_is_losing_it() -> void:
	var engine: MmEngine = _hero_main([], [_analysis()])
	var analysis: int = _in_graveyard(engine, "Analysis")

	assert_eq(Scenario.cast(engine, analysis), "")

	assert_eq(engine.hero().life, 17, "CR 119.4")
	var lost: Array[MmEvent] = Scenario.events_of(engine, LifeLostEvent)
	assert_eq((lost.back() as LifeLostEvent).amount, 3, "Paying life is losing life, not damage.")


func test_life_can_be_paid_only_while_you_have_that_much() -> void:
	var engine: MmEngine = _hero_main([], [_analysis()], 2)
	assert_false(Scenario.offers_cast(engine, _in_graveyard(engine, "Analysis")), "CR 119.4: 2 life cannot pay 3.")


func test_paying_all_your_life_loses_the_encounter() -> void:
	var engine: MmEngine = _hero_main([], [_analysis()], 3)
	var analysis: int = _in_graveyard(engine, "Analysis")
	assert_true(Scenario.offers_cast(engine, analysis), "CR 119.4: 3 life can pay 3.")

	Scenario.cast(engine, analysis)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().life, 0)
	assert_true(engine.hero().has_lost, "CR 704.5a")


func test_an_activated_ability_can_cost_life() -> void:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [Scenario.pay_life(2)]
	ability.effects = [Scenario.draw_cards(1, Scenario.you())]
	var engine: MmEngine = _hero_main([Scenario.artifact("Altar", [ability])], [])
	var held: int = engine.hero().hand.size()

	Scenario.activate(engine, Scenario.permanent_named(engine, engine.hero().id, "Altar"))
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 18)
	assert_eq(engine.hero().hand.size(), held + 1)


func test_tapping_creatures_asks_which_and_taps_exactly_those() -> void:
	var engine: MmEngine = _hero_main(_four_bears(), [_project()])
	var project: int = _in_graveyard(engine, "Project")
	var bears: Array[int] = _bears(engine)

	Scenario.cast(engine, project)

	var decision: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(decision, "The cost asks which creatures.")
	assert_eq(decision.count, 3)
	assert_eq(decision.candidate_ids, bears, "Every untapped creature you control, in ID order.")
	assert_eq(engine.submit([bears[0], bears[2], bears[3]]), "")
	assert_eq(_tapped(engine, bears), [true, false, true, true])
	assert_eq(Scenario.stack_ids(engine).size(), 1, "Paid, so it is cast.")


func test_it_is_offered_only_with_enough_untapped_creatures() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), Scenario.creature("Bear", 2, 2)], [_project()])
	assert_false(Scenario.offers_cast(engine, _in_graveyard(engine, "Project")), "Two creatures cannot pay for three.")


func test_a_creature_with_summoning_sickness_can_be_tapped_for_it() -> void:
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 1)
	var bears: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2), Scenario.creature("Bear", 2, 2)]
	var engine: MmEngine = _hero_main(bears, [_project(), cub])
	var project: int = _in_graveyard(engine, "Project")
	Scenario.cast_and_resolve(engine, "Cub")
	var fresh: int = Scenario.permanent_named(engine, engine.hero().id, "Cub")
	assert_true(engine.game_state().is_summoning_sick(engine.game_state().object(fresh)))

	assert_true(Scenario.offers_cast(engine, project), "CR 302.6 forbids only its own {T}.")
	Scenario.cast(engine, project)

	assert_true((engine.pending_decision() as ChoosePermanentsDecision).candidate_ids.has(fresh))


func test_an_illegal_pick_is_refused_and_changes_nothing() -> void:
	var engine: MmEngine = _hero_main(_four_bears(), [_project()], 20, [Scenario.creature("Wolf", 2, 2)])
	Scenario.cast(engine, _in_graveyard(engine, "Project"))
	var bears: Array[int] = _bears(engine)
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([bears[0], bears[1]]), "", "Too few.")
	assert_ne(engine.submit([bears[0], bears[1], bears[1]]), "", "One twice.")
	assert_ne(engine.submit([bears[0], bears[1], wolf]), "", "Not one you control.")
	assert_ne(engine.submit(0), "", "Not a list.")

	assert_eq(engine.fingerprint(), before)


func test_canceling_at_the_pick_taps_nothing() -> void:
	var engine: MmEngine = _hero_main(_four_bears(), [_project()])
	var project: int = _in_graveyard(engine, "Project")
	Scenario.cast(engine, project)

	assert_eq(engine.cancel_cast(), "")

	assert_eq(_tapped(engine, _bears(engine)), [false, false, false, false])
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Project"), project)


func test_a_replay_taps_the_same_creatures() -> void:
	var setup: MmEncounterSetup = Scenario.combat_setup(_four_bears(), [], [_project()])
	var engine: MmEngine = _hero_main_from(setup, _four_bears(), [_project()], [])
	Scenario.cast(engine, _in_graveyard(engine, "Project"))
	var bears: Array[int] = _bears(engine)
	engine.submit([bears[1], bears[2], bears[3]])

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_eq(_tapped(replayed, bears), [false, true, true, true])


## A sorcery costing {0}: "Draw a card. Flashback—Pay 3 life" (no mana).
func _analysis() -> MmCardDefinition:
	var costs: Array[MmCost] = [Scenario.pay_life(3)]
	return Scenario.flashback_sorcery("Analysis", [], [Scenario.draw_cards(1, Scenario.you())], Scenario.flashback(null, costs))


## A sorcery costing {0}: "You gain 1 life. Flashback—Tap three untapped creatures you
## control."
func _project() -> MmCardDefinition:
	var costs: Array[MmCost] = [Scenario.tap_creatures(3)]
	return Scenario.flashback_sorcery("Project", [], [Scenario.gain_life(1, Scenario.you())], Scenario.flashback(null, costs))


func _four_bears() -> Array[MmCardDefinition]:
	var bears: Array[MmCardDefinition] = []
	for index: int in 4:
		bears.append(Scenario.creature("Bear", 2, 2))
	return bears


func _bears(engine: MmEngine) -> Array[int]:
	return Scenario.permanents_named(engine, engine.hero().id, "Bear")


func _tapped(engine: MmEngine, ids: Array[int]) -> Array[bool]:
	var tapped: Array[bool] = []
	for id: int in ids:
		tapped.append(engine.game_state().object(id).is_tapped)
	return tapped


## Casts [param card_name] from the hand, lets it resolve and returns it in the graveyard.
func _in_graveyard(engine: MmEngine, card_name: String) -> int:
	assert_eq(Scenario.cast_and_resolve(engine, card_name), "")
	Scenario.resolve_stack(engine)
	return Scenario.card_in_graveyard(engine, engine.hero(), card_name)


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition], hero_life: int = 20,
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	setup.hero.starting_life = hero_life
	return _hero_main_from(setup, hero_permanents, hero_extras, villain_permanents)


func _hero_main_from(setup: MmEncounterSetup, hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
