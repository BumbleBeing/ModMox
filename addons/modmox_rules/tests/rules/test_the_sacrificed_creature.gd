extends GutTest
## "The sacrificed creature", and "that creature" after a sacrifice (engine ADR 0098): what
## the spell or ability sacrificed, as a cost or by an earlier effect of its own, seen as it
## last existed on the battlefield (CR 608.2h). Poacher is a 2/4 costing {0} with Bushmeat
## Poacher's ability at {0}: "{0}, {T}, Sacrifice another creature: You gain life equal to
## the sacrificed creature's toughness. Draw a card." Disciple is a 2/1 costing {0} with
## Disciple of Bolas's: "When this creature enters, sacrifice another creature. You gain X
## life and draw X cards, where X is that creature's power."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_a_creature_sacrificed_as_a_cost_gives_its_toughness_in_life() -> void:
	var engine: MmEngine = _hero_main([Scenario.poacher(), Scenario.creature("Wall", 1, 3)], [])
	var life: int = engine.hero().life
	var hand: int = engine.hero().hand.size()

	assert_eq(_activate_poacher(engine, "Wall"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Wall"), -1, "The Wall was sacrificed.")
	assert_eq(engine.hero().life, life + 3)
	assert_eq(engine.hero().hand.size(), hand + 1, "And draw a card.")


func test_the_toughness_is_the_creatures_as_it_last_existed() -> void:
	# CR 608.2h: a pump until end of turn counts, though the card in the graveyard is a 1/3.
	var engine: MmEngine = _hero_main([Scenario.poacher(), Scenario.creature("Wall", 1, 3)], [_pump(0, 2)])
	var life: int = engine.hero().life
	var wall: int = Scenario.permanent_named(engine, engine.hero().id, "Wall")
	assert_eq(Scenario.cast_and_resolve(engine, "Pump", [MmReference.to_object(wall)]), "")

	assert_eq(_activate_poacher(engine, "Wall"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 5)


func test_a_copy_of_the_game_state_keeps_what_was_sacrificed_for_an_ability_on_the_stack() -> void:
	var engine: MmEngine = _hero_main([Scenario.poacher(), Scenario.creature("Wall", 1, 3)], [])
	var wall: int = Scenario.permanent_named(engine, engine.hero().id, "Wall")
	assert_eq(_activate_poacher(engine, "Wall"), "")

	var copy: MmGameState = engine.game_state().duplicate_state()

	var ability: MmGameObject = copy.object(Scenario.stack_ids(engine)[0])
	assert_eq(ability.sacrificed_object_ids, [wall] as Array[int])


func test_a_creature_sacrificed_by_an_effect_gives_its_power_in_life_and_cards() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Brute", 3, 1)], [Scenario.disciple()])
	var life: int = engine.hero().life
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Disciple"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Brute"), -1, "The Brute was sacrificed.")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Disciple"), -1, "Not the Disciple itself.")
	assert_eq(engine.hero().life, life + 3)
	assert_eq(engine.hero().hand.size(), hand - 1 + 3, "The Disciple left the hand; three cards came.")


func test_the_power_is_the_creatures_as_it_last_existed() -> void:
	# CR 608.2h.
	var engine: MmEngine = _hero_main([Scenario.creature("Brute", 3, 1)], [_pump(2, 0), Scenario.disciple()])
	var life: int = engine.hero().life
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	assert_eq(Scenario.cast_and_resolve(engine, "Pump", [MmReference.to_object(brute)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Disciple"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 5)


func test_a_sacrificed_token_still_counts() -> void:
	# CR 704.5d: a token in a graveyard ceases to exist; its last-known information remains.
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Tokens", Scenario.cat()), Scenario.disciple()])
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Tokens"), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Disciple"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0, "The Cat was sacrificed.")
	assert_eq(engine.hero().life, life + 1)


func test_with_no_other_creature_nothing_is_sacrificed_and_nothing_is_gained() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.disciple()])
	var life: int = engine.hero().life
	var hand: int = engine.hero().hand.size()

	assert_eq(Scenario.cast_and_resolve(engine, "Disciple"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Disciple"), -1)
	assert_eq(engine.hero().life, life)
	assert_eq(engine.hero().hand.size(), hand - 1)


func test_a_creature_that_sacrifices_itself_deals_damage_equal_to_its_power_as_it_last_existed() -> void:
	# Heartfire Immolator's "Sacrifice this creature: It deals damage equal to its power"
	# (CR 608.2h): the pump counts, though the card in the graveyard is a 2/2.
	var engine: MmEngine = _hero_main([Scenario.immolator(), Scenario.creature("Wall", 0, 4)], [_pump(2, 0)])
	var immolator: int = Scenario.permanent_named(engine, engine.hero().id, "Immolator")
	var wall: int = Scenario.permanent_named(engine, engine.hero().id, "Wall")
	assert_eq(Scenario.cast_and_resolve(engine, "Pump", [MmReference.to_object(immolator)]), "")

	assert_eq(Scenario.activate(engine, immolator, [MmReference.to_object(wall)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Immolator"), -1, "It sacrificed itself.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Wall"), -1, "4 damage destroyed the 0/4.")


func test_a_creature_that_sacrifices_itself_is_kept_on_its_ability_on_the_stack() -> void:
	var engine: MmEngine = _hero_main([Scenario.immolator(), Scenario.creature("Wall", 0, 4)], [])
	var immolator: int = Scenario.permanent_named(engine, engine.hero().id, "Immolator")
	var wall: int = Scenario.permanent_named(engine, engine.hero().id, "Wall")

	assert_eq(Scenario.activate(engine, immolator, [MmReference.to_object(wall)]), "")

	var ability: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])
	assert_eq(ability.sacrificed_object_ids, [immolator] as Array[int])


func test_nothing_sacrificed_selects_nothing() -> void:
	var engine: MmEngine = _hero_main([], [])

	var found: Array[MmReference] = Scenario.sacrificed().select(engine.game_state(), MmEffectContext.new(engine.hero().id, 0))

	assert_eq(found.size(), 0)


## Activates the Poacher, sacrificing the creature named [param card_name] for it.
func _activate_poacher(engine: MmEngine, card_name: String) -> String:
	var poacher: int = Scenario.permanent_named(engine, engine.hero().id, "Poacher")
	var sacrificed: int = Scenario.permanent_named(engine, engine.hero().id, card_name)
	var error: String = Scenario.activate(engine, poacher)
	if error != "":
		return error
	if not engine.pending_decision() is ChoosePermanentsDecision:
		return "No sacrifice was asked."
	return engine.submit([sacrificed])


## An instant costing {0}: "Target creature gets +[param power]/+[param toughness] until end
## of turn."
func _pump(power: int, toughness: int) -> MmCardDefinition:
	return Scenario.instant("Pump", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.until_end_of_turn(Scenario.modify_pt(power, toughness, Scenario.targeted(0)))])


## The Hero in their main phase of Game Turn 3 with [param creatures] cast on Game Turn 1,
## holding [param hero_extras]; the Villain has nothing.
func _hero_main(creatures: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(creatures, NO_CARDS, hero_extras),
		creatures, NO_CARDS, hero_extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
