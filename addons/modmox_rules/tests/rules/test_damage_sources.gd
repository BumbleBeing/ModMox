extends GutTest
## "[source] deals [amount] damage to [recipients]": the damage comes from the spell or
## ability's own source unless the effect names another, such as "it" for the creature
## whose entering triggered the ability. That source deals it, so its lifelink applies
## (CR 702.15b), and one that has left the battlefield deals it as it last existed
## (CR 608.2h).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_each_creature_that_enters_deals_the_damage_itself() -> void:
	var engine: MmEngine = Scenario.combat_ready([_eruptor(), _leech()], [])
	assert_not_null(engine, "No seed gave the needed hands.")

	assert_eq(engine.villain().life, 18, "The Eruptor's own entering, then the Leech's.")
	assert_eq(engine.hero().life, 21, "Only the Leech has lifelink.")


func test_a_creature_that_left_before_the_trigger_resolved_still_deals_it_as_it_last_existed() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var hero_creatures: Array[MmCardDefinition] = [_eruptor()]
	var extras: Array[MmCardDefinition] = [_leech(), Scenario.exile_spell("Exile")]
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, no_creatures, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, no_creatures, extras, no_creatures, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	var villain_life: int = engine.villain().life
	assert_eq(Scenario.cast_and_resolve(engine, "Leech"), "")
	var leech: int = Scenario.permanent_named(engine, engine.hero().id, "Leech")
	assert_eq(Scenario.stack_ids(engine).size(), 1, "Its trigger waits on the stack.")

	assert_eq(Scenario.cast_and_resolve(engine, "Exile", [MmReference.to_object(leech)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Leech"), -1, "Exiled before the trigger resolved.")
	assert_eq(engine.villain().life, villain_life - 1)
	assert_eq(engine.hero().life, 21, "Its lifelink as it last existed.")


## A 1/1 with "Whenever a creature you control enters, it deals 1 damage to each opponent."
func _eruptor() -> MmCardDefinition:
	var ping: DealDamageEffect = Scenario.deal_damage(1, EachOpponentSelection.new())
	ping.source = TriggeringObjectSelection.new()
	var trigger: ZoneChangeTrigger = Scenario.enters(Scenario.creature_you_control())
	return Scenario.creature("Eruptor", 1, 1, [Scenario.triggered(trigger, [ping])])


## A 1/1 with lifelink.
func _leech() -> MmCardDefinition:
	return Scenario.creature("Leech", 1, 1, [LifelinkAbility.new()])
