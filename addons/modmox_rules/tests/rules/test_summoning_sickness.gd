extends GutTest
## CR 302.6: a creature can attack, or pay {T} in a cost, only if its controller has
## controlled it continuously since their most recent turn began.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_that_entered_this_turn_cannot_attack() -> void:
	var engine: MmEngine = _hero_with_bear_on_turn_one()

	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)

	assert_false(engine.pending_decision() is DeclareAttackersDecision, "Nothing can attack, so nobody is asked.")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_true(engine.game_state().is_summoning_sick(engine.game_state().object(bear)))


func test_a_creature_can_attack_on_its_controllers_next_turn() -> void:
	var engine: MmEngine = _hero_with_bear_on_turn_one()

	Scenario.play_until_step(engine, 3, Step.DECLARE_ATTACKERS)

	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var decision: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision
	assert_not_null(decision)
	assert_eq(decision.candidate_ids, [bear])
	assert_false(engine.game_state().is_summoning_sick(engine.game_state().object(bear)))


func test_a_summoning_sick_creature_cannot_pay_a_tap_cost() -> void:
	var elf: MmCardDefinition = Scenario.creature("Elf", 1, 1, [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)])
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(elf, 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Elf")
	var elf_id: int = Scenario.permanent_named(engine, engine.hero().id, "Elf")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, elf_id), -1)

	Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, elf_id), -1)


func test_a_noncreature_permanent_can_pay_a_tap_cost_the_turn_it_enters() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.basic_land("Forest"), 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	var forest: int = Scenario.play_first_land(engine)

	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, forest), -1)


func test_a_creature_that_entered_on_the_opponents_turn_is_ready_on_its_controllers_turn() -> void:
	var sprite: MmCardDefinition = Scenario.creature("Sprite", 1, 1, [FlashAbility.new()])
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.vanilla("Card"), 40), Scenario.copies(sprite, 40)))
	Scenario.play_until_step(engine, 1, Step.END)
	Scenario.pass_priority(engine)
	Scenario.cast_and_resolve(engine, "Sprite")
	var sprite_id: int = Scenario.permanent_named(engine, engine.villain().id, "Sprite")
	assert_true(engine.game_state().is_summoning_sick(engine.game_state().object(sprite_id)),
		"Still sick on the opponent's turn.")

	Scenario.play_until_step(engine, 2, Step.DECLARE_ATTACKERS)

	assert_false(engine.game_state().is_summoning_sick(engine.game_state().object(sprite_id)))
	var decision: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision
	assert_not_null(decision)
	assert_true(decision.candidate_ids.has(sprite_id))


func _hero_with_bear_on_turn_one() -> MmEngine:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.creature("Bear", 2, 2), 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	assert_eq(Scenario.cast_and_resolve(engine, "Bear"), "")
	return engine
