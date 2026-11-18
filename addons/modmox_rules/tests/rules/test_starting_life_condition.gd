extends GutTest
## "As long as your life total is greater than or equal to your starting life total": a
## condition on the controller's life against the life they began the encounter with
## (CR 103.4), asked of the game as it is right now (CR 611.3a).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_at_your_starting_life_creatures_you_control_get_the_bonus() -> void:
	var engine: MmEngine = _hero_main(_setup([]), [])

	assert_eq(Scenario.pt(engine, _hero_bear(engine)), [3, 3])
	assert_eq(Scenario.pt(engine, Scenario.permanent_named(engine, engine.villain().id, "Wolf")), [2, 2],
		"Only creatures its controller controls.")


func test_below_your_starting_life_the_bonus_stops_and_returns_once_life_is_regained() -> void:
	var extras: Array[MmCardDefinition] = [Scenario.free_shock("Shock", 1), _free_heal()]
	var engine: MmEngine = _hero_main(_setup(extras), extras)
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.hero().id)])
	assert_eq(engine.hero().life, 19)
	assert_eq(Scenario.pt(engine, _hero_bear(engine)), [2, 2], "19 is less than 20.")

	Scenario.cast_and_resolve(engine, "Heal")

	assert_eq(Scenario.pt(engine, _hero_bear(engine)), [3, 3], "CR 611.3a: back to 20, so it applies again.")


func test_above_your_starting_life_the_bonus_still_applies() -> void:
	var extras: Array[MmCardDefinition] = [_free_heal()]
	var engine: MmEngine = _hero_main(_setup(extras), extras)

	Scenario.cast_and_resolve(engine, "Heal")

	assert_eq(engine.hero().life, 21)
	assert_eq(Scenario.pt(engine, _hero_bear(engine)), [3, 3])


func test_it_compares_with_the_players_own_starting_life() -> void:
	var extras: Array[MmCardDefinition] = [Scenario.free_shock("Shock", 1)]
	var setup: MmEncounterSetup = _setup(extras)
	setup.hero.starting_life = 25
	var engine: MmEngine = _hero_main(setup, extras)
	assert_eq(Scenario.pt(engine, _hero_bear(engine)), [3, 3], "25 of 25.")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.hero().id)])

	assert_eq(Scenario.pt(engine, _hero_bear(engine)), [2, 2], "24 is more than 20 but less than 25.")


func test_a_simulation_copy_keeps_each_players_starting_life() -> void:
	var extras: Array[MmCardDefinition] = [Scenario.free_shock("Shock", 1)]
	var setup: MmEncounterSetup = _setup(extras)
	setup.hero.starting_life = 25
	var engine: MmEngine = _hero_main(setup, extras)

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_eq(copy.hero().starting_life, 25)
	assert_eq(Scenario.pt(copy, _hero_bear(copy)), [3, 3])


## Path of Bravery's first ability, on an artifact costing {0}: "As long as your life total
## is greater than or equal to your starting life total, creatures you control get +1/+1."
func _banner() -> MmCardDefinition:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	return Scenario.artifact("Banner", [Scenario.continuous_static(
		[Scenario.modify_pt(1, 1, Scenario.each_creature(mine))], LifeAtLeastStartingCondition.new())])


## An instant costing {0}: "You gain 1 life."
func _free_heal() -> MmCardDefinition:
	return Scenario.instant("Heal", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])


func _hero_permanents() -> Array[MmCardDefinition]:
	return [_banner(), Scenario.creature("Bear", 2, 2)]


func _villain_permanents() -> Array[MmCardDefinition]:
	return [Scenario.creature("Wolf", 2, 2)]


func _setup(extras: Array[MmCardDefinition]) -> MmEncounterSetup:
	return Scenario.combat_setup(_hero_permanents(), _villain_permanents(), extras)


func _hero_main(setup: MmEncounterSetup, extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, _hero_permanents(), _villain_permanents(),
		extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _hero_bear(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Bear")
