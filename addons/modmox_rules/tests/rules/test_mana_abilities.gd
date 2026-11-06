extends GutTest
## CR 605: mana abilities resolve immediately without using the stack, and the player keeps
## priority. CR 305.6: basic land types grant their mana ability.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_a_basic_land_gets_its_mana_ability_from_its_subtype() -> void:
	var engine: MmEngine = _forests_vs_forests()
	var forest: MmGameObject = engine.hero().library.objects()[0]

	var abilities: Array[MmAbility] = engine.game_state().characteristics_of(forest).abilities

	assert_eq(forest.definition.abilities.size(), 0, "The Forest has no written abilities.")
	assert_eq(abilities.size(), 1)
	assert_true(abilities[0] is ActivatedAbility and (abilities[0] as ActivatedAbility).is_mana_ability())


func test_each_basic_land_type_makes_its_own_color() -> void:
	var expected: Dictionary[String, Type] = {
		"Plains": Type.WHITE, "Island": Type.BLUE, "Swamp": Type.BLACK, "Mountain": Type.RED, "Forest": Type.GREEN,
	}
	for land_type: String in expected:
		var engine: MmEngine = MmEngine.start(Scenario.setup_with(
			Scenario.copies(Scenario.basic_land(land_type), 10), Scenario.copies(Scenario.vanilla("Card"), 10)))
		var land: MmGameObject = engine.hero().library.objects()[0]
		var ability: ActivatedAbility = engine.game_state().characteristics_of(land).abilities[0] as ActivatedAbility
		assert_eq((ability.effects[0] as AddManaEffect).mana_type, expected[land_type], land_type)


func test_a_land_with_two_basic_land_types_has_both_mana_abilities() -> void:
	var dual: MmCardDefinition = Scenario.basic_land("Forest")
	dual.subtypes = ["Forest", "Mountain"]
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(dual, 10), Scenario.copies(Scenario.vanilla("Card"), 10)))

	var land: MmGameObject = engine.hero().library.objects()[0]

	assert_eq(engine.game_state().characteristics_of(land).abilities.size(), 2)


func test_tapping_a_forest_adds_one_green_mana_from_that_forest() -> void:
	var engine: MmEngine = _forests_vs_forests()
	var forest: int = _hero_forest_in_main(engine)

	assert_eq(engine.submit(Scenario.activate_index(_priority(engine), forest)), "")

	assert_true(engine.game_state().object(forest).is_tapped)
	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 1)
	assert_eq(pool[0].type, Type.GREEN)
	assert_eq(pool[0].source_object_id, forest)
	assert_true(_logged(engine, TapEvent))
	assert_true(_logged(engine, ManaAddedEvent))


func test_a_mana_ability_keeps_priority_and_does_not_use_the_stack() -> void:
	var engine: MmEngine = _forests_vs_forests()
	var forest: int = _hero_forest_in_main(engine)

	engine.submit(Scenario.activate_index(_priority(engine), forest))

	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_eq(engine.game_state().stack.size(), 0)


func test_a_tapped_lands_mana_ability_is_not_offered() -> void:
	var engine: MmEngine = _forests_vs_forests()
	var forest: int = _hero_forest_in_main(engine)

	engine.submit(Scenario.activate_index(_priority(engine), forest))

	assert_eq(Scenario.activate_index(_priority(engine), forest), -1)


func test_mana_abilities_are_offered_on_the_opponents_turn() -> void:
	var engine: MmEngine = _forests_vs_forests()
	var forest: int = _hero_forest_in_main(engine)
	assert_eq(Scenario.play_until_step(engine, 2, Step.UPKEEP), "")

	engine.submit(Scenario.pass_index(_priority(engine)))

	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_ne(Scenario.activate_index(_priority(engine), forest), -1)


func test_taking_an_action_resets_the_passes_needed_to_end_a_step() -> void:
	# CR 117.4: the step ends only when all players pass in succession.
	var engine: MmEngine = _forests_vs_forests()
	var forest: int = _hero_forest_in_main(engine)
	Scenario.play_until_step(engine, 2, Step.UPKEEP)
	engine.submit(Scenario.pass_index(_priority(engine)))  # The Villain passes.

	engine.submit(Scenario.activate_index(_priority(engine), forest))  # The Hero acts...
	engine.submit(Scenario.pass_index(_priority(engine)))  # ...then passes.

	assert_eq(engine.game_state().step, Step.UPKEEP, "The Villain must pass again after the Hero acted.")
	assert_eq(engine.pending_decision().player_id, engine.villain().id)


func test_a_written_mana_ability_can_add_several_mana() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(Scenario.mana_land("Ruby Spring", Type.RED, 2), 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var land: int = Scenario.play_first_land(engine)

	engine.submit(Scenario.activate_index(_priority(engine), land))

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 2)
	for mana: MmMana in pool:
		assert_eq(mana.type, Type.RED)


func test_an_ability_that_targets_is_not_offered_as_a_mana_ability() -> void:
	# Until the stack exists (milestone 5), only mana abilities can be activated.
	var land_definition: MmCardDefinition = Scenario.mana_land("Odd Spring", Type.RED, 1)
	(land_definition.abilities[0] as ActivatedAbility).effects.append(preload("res://addons/modmox_rules/tests/support/targeted_test_effect.gd").new())
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(land_definition, 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	var land: int = Scenario.play_first_land(engine)

	assert_eq(Scenario.activate_index(_priority(engine), land), -1)


## Plays the Hero's first land in their first main phase and returns its object ID.
func _hero_forest_in_main(engine: MmEngine) -> int:
	assert_eq(Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN), "")
	var forest: int = Scenario.play_first_land(engine)
	assert_ne(forest, -1)
	return forest


func _forests_vs_forests() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	return MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))


func _priority(engine: MmEngine) -> PriorityDecision:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_not_null(decision, "Expected a priority decision.")
	return decision


func _logged(engine: MmEngine, event_script: Script) -> bool:
	for event: MmEvent in engine.event_log():
		if is_instance_of(event, event_script):
			return true
	return false
