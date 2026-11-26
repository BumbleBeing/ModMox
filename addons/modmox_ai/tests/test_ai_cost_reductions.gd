extends GutTest
## The Agent casts what a cost reduction lets it afford (ADR 0050): what it may cast comes
## from the engine's legal actions, which pay the reduced cost, so it needs no rule of its own.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE


func test_a_pump_with_affinity_is_cast_for_its_reduced_cost_to_win_a_fight() -> void:
	var claws: MmCardDefinition = Scenario.instant("Claws", Scenario.mana_cost(2, [W, W]), [],
		[Scenario.until_end_of_turn(Scenario.modify_pt(2, 2, Scenario.each_creature(ControlledByFilter.new())))])
	claws.abilities.push_front(Scenario.affinity(Scenario.has_subtype("Cat")))
	var engine: MmEngine = AiScenario.ready_with([_lion(), _lion(), Scenario.elf(), Scenario.elf()],
		[AiScenario.free_alpha("hill_giant")], [claws], [], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	var cats: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Lion")
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
	engine.submit([cats[0]])
	Scenario.pass_to_blockers(engine)
	engine.submit([[giant, cats[0]]])
	AiScenario.pass_to(engine, engine.hero().id, PriorityDecision)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Claws", "Two Elves pay {W}{W}, all {2}{W}{W} costs with two Cats.")


func test_an_untapped_land_is_played_when_its_mana_casts_a_spell_at_its_reduced_cost() -> void:
	# The Hero controls an Island and a Mountain, so the Horror's {3}{B} costs {1}{B}: the
	# Swamp's mana casts it this turn, though its printed cost would still be out of reach.
	var horror: MmCardDefinition = Scenario.creature("Horror", 4, 4, [], Scenario.mana_cost(3, [MmMana.Type.BLACK]))
	horror.abilities.push_front(Scenario.cost_reduction(Scenario.domain()))
	var hand: Array[MmCardDefinition] = [Scenario.free_land_fetch(), Scenario.tapped_dual_land("Plains", "Forest"),
		Scenario.basic_land("Swamp"), horror]
	var library: Array[MmCardDefinition] = [Scenario.basic_land("Island"), Scenario.basic_land("Mountain")]
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(none, none, hand + library)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, none, none, hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.fetch_lands(engine, ["Island", "Mountain"]), "")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: PlayLandAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent)) as PlayLandAction

	assert_not_null(play)
	assert_eq(engine.game_state().characteristics_of(engine.game_state().object(play.object_id)).name, "Swamp")


func test_a_second_spell_made_cheaper_by_a_permanent_is_cast_with_the_mana_left() -> void:
	# Engine ADR 0050's addendum: the Ringer makes the second spell each turn cost {1} less,
	# so the one Elf left after the first Footman pays another's {1}{W} as {W}.
	var footman: MmCardDefinition = Scenario.creature("Footman", 2, 2, [], Scenario.mana_cost(1, [W]))
	var engine: MmEngine = AiScenario.ready_with([Scenario.ringer(), Scenario.elf(), Scenario.elf(), Scenario.elf()],
		[], [footman])
	assert_not_null(engine)
	assert_eq(Scenario.cast_and_resolve(engine, "Footman"), "")
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Footman"), -1, "The cycled deck dealt more than one.")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Footman")


func test_a_spell_cheaper_once_another_was_cast_is_cast_with_the_mana_left() -> void:
	# Engine ADR 0050's addendum: after a Footman, the Titan's {4}{W} costs {1}{W}, which the
	# two Elves left pay.
	var footman: MmCardDefinition = Scenario.creature("Footman", 2, 2, [], Scenario.mana_cost(0, [W]))
	var engine: MmEngine = AiScenario.ready_with([Scenario.elf(), Scenario.elf(), Scenario.elf()], [],
		[footman, Scenario.titan()])
	assert_not_null(engine)
	assert_eq(Scenario.cast_and_resolve(engine, "Footman"), "")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Titan")


## A 2/2 Cat costing {0}.
func _lion() -> MmCardDefinition:
	var lion: MmCardDefinition = Scenario.creature("Lion", 2, 2)
	lion.subtypes = ["Cat"]
	return lion
