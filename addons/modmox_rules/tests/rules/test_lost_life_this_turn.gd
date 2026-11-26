extends GutTest
## The condition "if an opponent lost life this turn" (engine ADR 0082's second addendum):
## true while a player it names, relative to the controller of the spell or ability that
## asks, has lost life this turn, from damage (CR 120.3a), an effect or a cost of paying life
## (CR 119.3, 119.4). Losing no life is no life loss. Whisperer is a 4/2 costing {0} after
## Bat Whisperer: "When this creature enters, if an opponent lost life this turn, you gain 1
## life." Its "if" is an intervening one (CR 603.4), so with no life lost it never triggers.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose
const NO_CARDS: Array[MmCardDefinition] = []


func test_with_no_life_lost_it_never_triggers() -> void:
	var engine: MmEngine = _hero_main([Scenario.whisperer()])
	var triggered_before: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Whisperer"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered_before, "It never triggered.")
	assert_eq(engine.hero().life, life)


func test_after_damage_to_an_opponent_it_triggers_and_resolves() -> void:
	# CR 120.3a: damage to a player makes them lose that much life.
	var engine: MmEngine = _hero_main([Scenario.free_shock("Shock", 2), Scenario.whisperer()])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.villain().id)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Whisperer"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.villain().life_lost_this_turn, 2)
	assert_eq(engine.hero().life, life + 1, "Whisperer's ability resolved.")


func test_combat_damage_is_life_lost() -> void:
	# CR 510.2, 120.3a.
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 2)], [])
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Bear")]), "")

	assert_eq(Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN), "")

	assert_eq(engine.villain().life_lost_this_turn, 2)
	assert_true(_lost(engine, engine.hero(), Whose.OPPONENT))


func test_an_effect_and_paying_life_are_life_lost() -> void:
	# CR 119.3, 119.4: paying life is losing it.
	var drain: MmCardDefinition = Scenario.instant("Drain", Scenario.mana_cost(0), [], [Scenario.lose_life(1, EachOpponentSelection.new())])
	var payment: MmCardDefinition = Scenario.instant("Payment", Scenario.mana_cost(0), [], [Scenario.gain_life(0, Scenario.you())])
	payment.abilities.append(Scenario.additional_cost([Scenario.pay_life(3)]))
	var engine: MmEngine = _hero_main([drain, payment])

	assert_eq(Scenario.cast_and_resolve(engine, "Drain"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Payment"), "")

	assert_eq(engine.villain().life_lost_this_turn, 1)
	assert_eq(engine.hero().life_lost_this_turn, 3)
	assert_true(_lost(engine, engine.hero(), Whose.YOU), "\"You lost life this turn\" holds for the payer.")


func test_your_own_life_lost_is_not_an_opponents() -> void:
	var engine: MmEngine = _hero_main([Scenario.instant("Toll", Scenario.mana_cost(0), [], [Scenario.lose_life(2, Scenario.you())])])

	assert_eq(Scenario.cast_and_resolve(engine, "Toll"), "")

	assert_true(_lost(engine, engine.hero(), Whose.YOU))
	assert_false(_lost(engine, engine.hero(), Whose.OPPONENT))
	assert_true(_lost(engine, engine.villain(), Whose.OPPONENT), "To the Villain, the Hero is an opponent.")


func test_losing_no_life_is_no_life_loss() -> void:
	var engine: MmEngine = _hero_main([Scenario.instant("Nothing", Scenario.mana_cost(0), [],
		[Scenario.lose_life(0, EachOpponentSelection.new())])])

	assert_eq(Scenario.cast_and_resolve(engine, "Nothing"), "")

	assert_false(_lost(engine, engine.hero(), Whose.OPPONENT))


func test_a_new_turn_forgets_the_life_lost() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_shock("Shock", 2)])
	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.villain().id)]), "")
	assert_true(_lost(engine, engine.hero(), Whose.OPPONENT))

	assert_eq(Scenario.play_until_step(engine, 4, Step.UPKEEP), "")

	assert_false(_lost(engine, engine.hero(), Whose.OPPONENT))
	assert_eq(engine.villain().life_lost_this_turn, 0)


func test_a_copy_of_the_game_state_keeps_the_life_lost() -> void:
	var engine: MmEngine = _hero_main([Scenario.free_shock("Shock", 2)])
	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.villain().id)]), "")

	var copy: MmGameState = engine.game_state().duplicate_state()

	assert_eq(copy.player(engine.villain().id).life_lost_this_turn, 2)


## Whether "[param whose] lost life this turn" holds for [param player].
func _lost(engine: MmEngine, player: MmPlayer, whose: Whose) -> bool:
	return Scenario.lost_life_this_turn(whose).is_true(engine.game_state(), MmEffectContext.new(player.id, 0))


## The Hero in their main phase of Game Turn 3 with a 2/2 Bear cast on Game Turn 1, holding
## [param hero_extras]; the Villain has nothing.
func _hero_main(hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var bears: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2)]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(bears, NO_CARDS, hero_extras), bears,
		NO_CARDS, hero_extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
