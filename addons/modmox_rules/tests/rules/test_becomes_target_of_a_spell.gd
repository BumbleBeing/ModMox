extends GutTest
## "Whenever this creature becomes the target of a spell", as Bonecrusher Giant says: a
## BecomesTargetTrigger with is_spells_only, which a spell aimed at it triggers, whoever
## controls the spell, and an activated or triggered ability never does (CR 115.1, 112.1).
## "That spell's controller" is the trigger's "that player".

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_opponents_spell_aimed_at_it_deals_its_controller_2_damage() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.free_shock("Zap", 1)], [Scenario.giant()])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")
	var life_before: int = engine.hero().life

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Zap"), [MmReference.to_object(giant)]), "")
	assert_eq(Scenario.stack_ids(engine).size(), 2, "CR 603.3: the trigger goes on the stack once the spell is cast.")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life_before - 2, "The Hero controlled the spell.")


func test_its_controllers_own_spell_aimed_at_it_triggers_it_too() -> void:
	var engine: MmEngine = _hero_main([Scenario.giant()], [_boost()], [])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	var life_before: int = engine.hero().life

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Boost"), [MmReference.to_object(giant)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life_before - 2)


func test_an_ability_aimed_at_it_does_not_trigger_it() -> void:
	var no_hand: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main([Scenario.parcel()], no_hand, [Scenario.giant()])
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")
	var parcel: int = Scenario.permanent_named(engine, engine.hero().id, "Parcel")

	assert_eq(Scenario.activate(engine, parcel, [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1, "Only the Parcel's ability is on the stack.")


func test_ward_is_still_triggered_by_an_ability() -> void:
	var no_hand: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main([Scenario.parcel()], no_hand, [Scenario.warden()])
	var warden: int = Scenario.permanent_named(engine, engine.villain().id, "Warden")
	var parcel: int = Scenario.permanent_named(engine, engine.hero().id, "Parcel")

	assert_eq(Scenario.activate(engine, parcel, [MmReference.to_object(warden)]), "")

	assert_eq(Scenario.stack_ids(engine).size(), 2, "CR 702.21a: ward watches spells and abilities.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_becomes_target_of_a_spell.tres"
	assert_eq(ResourceSaver.save(Scenario.giant(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: BecomesTargetTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as BecomesTargetTrigger
	assert_true(trigger.is_spells_only)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0}: "Target creature gets +1/+1 until end of turn."
func _boost() -> MmCardDefinition:
	return Scenario.instant("Boost", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(0)))])


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
