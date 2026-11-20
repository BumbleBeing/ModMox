extends GutTest
## A land that may be paid for to enter untapped, as Temple Garden is ("As this land enters,
## you may pay 2 life. If you don't, it enters tapped.", engine ADR 0052): the AI pays only
## when the untapped mana lets a spell in its hand be cast this turn and it keeps at least
## AiAgent.MIN_LIFE_AFTER_PAYING life (CHEAP; FULL simulates both, CHEAP's answer the
## default). Choosing which land to play, it counts as entering tapped unless it would be
## paid for, and among lands that let a spell be cast, one that costs no life comes first.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const SHOCK := "Shock Forest Plains"
const YES := ChooseYesOrNoDecision.Choice.YES
const NO := ChooseYesOrNoDecision.Choice.NO


func test_it_pays_when_the_mana_casts_a_spell_this_turn() -> void:
	var engine: MmEngine = _asked(20, [_elf()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(AiScenario.ask(engine, agent), YES, "Its {G} casts the Elf now.")


func test_it_does_not_pay_with_nothing_to_cast() -> void:
	var engine: MmEngine = _asked(20, [_horror()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(AiScenario.ask(engine, agent), NO, "One mana casts nothing in hand.")


func test_it_does_not_pay_when_it_would_keep_less_than_the_least_life() -> void:
	var life: int = AiAgent.MIN_LIFE_AFTER_PAYING + 1
	var engine: MmEngine = _asked(life, [_elf()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(AiScenario.ask(engine, agent), NO, "It would keep %d life." % (life - 2))


func test_it_pays_when_it_keeps_exactly_the_least_life() -> void:
	var engine: MmEngine = _asked(AiAgent.MIN_LIFE_AFTER_PAYING + 2, [_elf()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(AiScenario.ask(engine, agent), YES)


func test_full_does_not_pay_for_mana_it_cannot_spend() -> void:
	var engine: MmEngine = _asked(20, [_horror()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	assert_eq(AiScenario.ask(engine, agent), NO)


func test_a_forest_is_played_before_it_when_either_casts_the_spell() -> void:
	var engine: MmEngine = _main(20, [Scenario.basic_land("Forest"), _elf()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(_land_name(engine, AiScenario.ask(engine, agent)), "Forest", "The Forest costs no life.")


func test_it_is_played_first_tapped_when_no_mana_would_be_spent() -> void:
	var engine: MmEngine = _main(20, [Scenario.basic_land("Forest"), _horror()])
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(_land_name(engine, AiScenario.ask(engine, agent)), SHOCK, "Its mana is not missed this turn.")


## A 1/1 costing {G}.
func _elf() -> MmCardDefinition:
	return Scenario.creature("Elf", 1, 1, [], Scenario.mana_cost(0, [MmMana.Type.GREEN]))


## A 4/4 costing {3}{G}.
func _horror() -> MmCardDefinition:
	return Scenario.creature("Horror", 4, 4, [], Scenario.mana_cost(3, [MmMana.Type.GREEN]))


## _main(), with the Shock Forest Plains played and its question asked.
func _asked(life: int, extras: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = _main(life, extras)
	var in_hand: int = Scenario.card_in_hand(engine, engine.hero(), SHOCK)
	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, in_hand)), "")
	assert_true(engine.pending_decision() is ChooseYesOrNoDecision)
	return engine


## The Hero in their precombat main phase on Game Turn 3 at [param life], with no lands,
## holding a Shock Forest Plains and [param extras].
func _main(life: int, extras: Array[MmCardDefinition]) -> MmEngine:
	var hand: Array[MmCardDefinition] = [Scenario.shock_land("Forest", "Plains")]
	hand.append_array(extras)
	var none: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(none, none, hand)
	setup.hero.starting_life = life
	var engine: MmEngine = Scenario.permanents_ready_with(setup, none, none, hand, none, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


## The name of the land a priority answer plays, or "".
func _land_name(engine: MmEngine, answer: int) -> String:
	var play: PlayLandAction = AiScenario.action_at(engine, answer) as PlayLandAction
	return "" if play == null else engine.game_state().characteristics_of(engine.game_state().object(play.object_id)).name
