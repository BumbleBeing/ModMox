extends GutTest
## The Value "the amount of life [players] have gained this turn" (engine ADR 0082's third
## addendum), as Voracious Wurm's "This creature enters with X +1/+1 counters on it, where X
## is the amount of life you've gained this turn." It adds up every life gain of the turn,
## from effects and lifelink damage alike (CR 119.3, 120.3f), from the count each player
## keeps (MmPlayer.life_gained_this_turn), which a new turn clears. Wurm is a 2/2 costing {0}
## with that ability.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_with_no_life_gained_it_enters_with_no_counters() -> void:
	var engine: MmEngine = _hero_main([Scenario.wurm()])

	assert_eq(Scenario.cast_and_resolve(engine, "Wurm"), "")

	var wurm: int = Scenario.permanent_named(engine, engine.hero().id, "Wurm")
	assert_eq(Scenario.counters_on(engine, wurm, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 0)
	assert_eq(Scenario.pt(engine, wurm), [2, 2])


func test_it_enters_with_a_counter_for_each_life_gained_this_turn() -> void:
	var engine: MmEngine = _hero_main([_gift("Gift", 3, Scenario.you()), _gift("Small Gift", 1, Scenario.you()),
		Scenario.wurm()])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Small Gift"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Wurm"), "")

	var wurm: int = Scenario.permanent_named(engine, engine.hero().id, "Wurm")
	assert_eq(Scenario.counters_on(engine, wurm, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 4)
	assert_eq(Scenario.pt(engine, wurm), [6, 6])


func test_lifelink_damage_counts_as_life_gained() -> void:
	# CR 120.3f.
	var shock: MmCardDefinition = Scenario.free_shock("Lifelink Shock", 2)
	shock.abilities.append(LifelinkAbility.new())
	var engine: MmEngine = _hero_main([shock, Scenario.wurm()])

	assert_eq(Scenario.cast_and_resolve(engine, "Lifelink Shock", [MmReference.to_player(engine.villain().id)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Wurm"), "")

	var wurm: int = Scenario.permanent_named(engine, engine.hero().id, "Wurm")
	assert_eq(Scenario.counters_on(engine, wurm, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 2)


func test_an_opponent_gaining_life_is_not_counted() -> void:
	var engine: MmEngine = _hero_main([_gift("Gift", 3, EachOpponentSelection.new())])

	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")

	assert_eq(_amount(engine, engine.hero()), 0)
	assert_eq(_amount(engine, engine.villain()), 3)


func test_a_new_turn_counts_from_none() -> void:
	var engine: MmEngine = _hero_main([_gift("Gift", 3, Scenario.you())])
	assert_eq(Scenario.cast_and_resolve(engine, "Gift"), "")
	assert_eq(_amount(engine, engine.hero()), 3)

	assert_eq(Scenario.play_until_step(engine, 4, Step.UPKEEP), "")

	assert_eq(_amount(engine, engine.hero()), 0)


## An instant costing {0}: "[param players] gain [param amount] life."
func _gift(card_name: String, amount: int, players: MmSelection) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.gain_life(amount, players)])


## "The amount of life you've gained this turn", for [param player].
func _amount(engine: MmEngine, player: MmPlayer) -> int:
	return Scenario.life_gained_this_turn().evaluate(engine.game_state(), MmEffectContext.new(player.id, 0))


## The Hero in their main phase of Game Turn 3 holding [param hero_extras].
func _hero_main(hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(NO_CARDS, NO_CARDS, hero_extras), NO_CARDS,
		NO_CARDS, hero_extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
