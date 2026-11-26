extends GutTest
## The condition "if you gained life this turn" (engine ADR 0082's addendum): true while the
## controller of the spell or ability that asks has gained life this turn, from an effect
## or from lifelink damage (CR 119.3, 120.3f). Gaining no life is no life gain (CR 119.9).
## Apprentice is a 2/2 costing {0} with Poisoner's Apprentice's ability: "When this creature
## enters, target creature an opponent controls gets -4/-4 until end of turn if you gained
## life this turn." Its "if" is asked as the ability resolves, so it triggers and targets
## either way (CR 608.2c), unlike an intervening "if" (CR 603.4).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_with_no_life_gained_it_triggers_and_targets_but_does_nothing() -> void:
	var engine: MmEngine = _hero_main([Scenario.apprentice()])
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Their Bear")
	var triggered_before: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()

	assert_eq(Scenario.cast_and_resolve(engine, "Apprentice"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered_before + 1, "It triggered.")
	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Their Bear"), bear, "The Bear lives.")
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_after_gaining_life_its_target_gets_minus_four() -> void:
	var engine: MmEngine = _hero_main([_gift(Scenario.you()), Scenario.apprentice()])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Apprentice"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Their Bear"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Their Bear"), -1)


func test_lifelink_damage_is_life_gained() -> void:
	# CR 120.3f.
	var shock: MmCardDefinition = Scenario.free_shock("Lifelink Shock", 2)
	shock.abilities.append(LifelinkAbility.new())
	var engine: MmEngine = _hero_main([shock])
	assert_false(_gained(engine, engine.hero()))

	assert_eq(Scenario.cast_and_resolve(engine, "Lifelink Shock", [MmReference.to_player(engine.villain().id)]), "")

	assert_true(_gained(engine, engine.hero()))
	assert_eq(engine.hero().life_gained_this_turn, 2)


func test_an_opponent_gaining_life_is_not_you_gaining_life() -> void:
	var engine: MmEngine = _hero_main([_gift(EachOpponentSelection.new())])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_true(_gained(engine, engine.villain()))
	assert_false(_gained(engine, engine.hero()))


func test_gaining_no_life_is_no_life_gain() -> void:
	var nothing: MmCardDefinition = Scenario.instant("Nothing", Scenario.mana_cost(0), [], [Scenario.gain_life(0, Scenario.you())])
	var engine: MmEngine = _hero_main([nothing])

	assert_eq(Scenario.cast_and_resolve(engine, "Nothing"), "")

	assert_false(_gained(engine, engine.hero()))


func test_a_new_turn_forgets_the_life_gained() -> void:
	var engine: MmEngine = _hero_main([_gift(Scenario.you())])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_true(_gained(engine, engine.hero()))

	assert_eq(Scenario.play_until_step(engine, 4, Step.UPKEEP), "")

	assert_false(_gained(engine, engine.hero()))


func test_a_copy_of_the_game_state_keeps_the_life_gained() -> void:
	var engine: MmEngine = _hero_main([_gift(Scenario.you())])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	var copy: MmGameState = engine.game_state().duplicate_state()

	assert_eq(copy.player(engine.hero().id).life_gained_this_turn, 3)


## An instant costing {0}: "[param players] gain 3 life."
func _gift(players: MmSelection) -> MmCardDefinition:
	return Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(3, players)])


## Whether "you gained life this turn" holds for [param player].
func _gained(engine: MmEngine, player: MmPlayer) -> bool:
	return Scenario.gained_life_this_turn().is_true(engine.game_state(), MmEffectContext.new(player.id, 0))


## The Hero in their main phase of Game Turn 3 holding [param hero_extras], the Villain
## with a 2/2 Their Bear cast on Game Turn 2.
func _hero_main(hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var bears: Array[MmCardDefinition] = [Scenario.creature("Their Bear", 2, 2)]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(NO_CARDS, bears, hero_extras), NO_CARDS,
		bears, hero_extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
