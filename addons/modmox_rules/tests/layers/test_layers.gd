extends GutTest
## CR 613: continuous effects apply in layers, and within a layer in timestamp order.
## CR 611.2c: an effect from a resolved spell locks in what it affects; CR 611.3a: a static
## ability's effect applies to whatever matches right now. CR 613.6: an effect that started
## applying keeps applying in later layers even if its ability is removed.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_setting_power_and_toughness_comes_before_modifying_it_whatever_the_order() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.pump_spell("Pump", 1, 1), _shrink()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Pump", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Shrink", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [1, 2], "Layer 7b sets 0/1, then 7c adds +1/+1.")
	assert_eq([Scenario.now(engine, bear).base_power, Scenario.now(engine, bear).base_toughness], [2, 2])


func test_modifications_add_up() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.pump_spell("Pump", 1, 1), Scenario.pump_spell("Boost", 2, 0)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Pump", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Boost", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [5, 3])


func test_the_later_of_two_setting_effects_wins() -> void:
	var grow: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Grow", Scenario.set_pt(3, 3, Scenario.targeted(0)))
	var engine: MmEngine = _hero_main([_bear()], [], [_shrink(), grow])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Shrink", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [0, 1], "CR 613.7: timestamp order within a layer.")


func test_a_static_ability_applies_to_whatever_matches_right_now() -> void:
	var engine: MmEngine = _hero_main([_captain(), _knight()], [_knight()], [_knight(), Scenario.exile_spell("Banish")])
	var captain: int = Scenario.permanent_named(engine, engine.hero().id, "Captain")
	var heros_knight: int = Scenario.permanent_named(engine, engine.hero().id, "Knight")
	var villains_knight: int = Scenario.permanent_named(engine, engine.villain().id, "Knight")

	assert_eq(Scenario.pt(engine, heros_knight), [3, 3])
	assert_eq(Scenario.pt(engine, villains_knight), [3, 3], "Every Knight, whoever controls it.")
	assert_eq(Scenario.pt(engine, captain), [1, 1], "The Captain is not a Knight.")
	Scenario.cast_and_resolve(engine, "Knight")
	assert_eq(Scenario.pt(engine, Scenario.permanents_named(engine, engine.hero().id, "Knight")[1]), [3, 3], "A new Knight too.")

	Scenario.cast_and_resolve(engine, "Banish", [_object(captain)])

	assert_eq(Scenario.pt(engine, heros_knight), [2, 2], "It ends when its source leaves.")


func test_an_until_end_of_turn_effect_locks_in_what_it_affects_and_ends_in_cleanup() -> void:
	var rally: MmCardDefinition = Scenario.instant("Rally", Scenario.mana_cost(0), [], [Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.each_creature()))])
	var engine: MmEngine = _hero_main([_bear()], [], [rally, _bear()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Rally")
	Scenario.cast_and_resolve(engine, "Bear")
	var new_bear: int = Scenario.permanents_named(engine, engine.hero().id, "Bear")[1]

	assert_eq(Scenario.pt(engine, bear), [3, 3])
	assert_eq(Scenario.pt(engine, new_bear), [2, 2], "CR 611.2c: it arrived after the effect began.")
	Scenario.play_until_game_turn(engine, 4)
	assert_eq(Scenario.pt(engine, bear), [2, 2], "CR 514.2: it ended in cleanup.")
	assert_eq(Scenario.events_of(engine, ContinuousEffectsEndedEvent).size(), 1)
	assert_eq(engine.game_state().continuous_effects.size(), 0)


func test_a_pump_in_response_saves_a_creature_from_lethal_damage() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_shock("Shock", 2), Scenario.pump_spell("Pump", 3, 3)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [_object(bear)])

	Scenario.cast_and_resolve(engine, "Pump", [_object(bear)])
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.damage_on(engine, bear), 2)
	Scenario.play_until_game_turn(engine, 4)

	assert_eq(engine.game_state().object(bear).zone(), engine.game_state().battlefield,
		"Lethal damage is checked against toughness after layers, and both end together in cleanup.")


func test_gaining_flying_dodges_a_ground_blocker() -> void:
	var jump: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Jump", Scenario.gain_abilities([FlyingAbility.new()], Scenario.targeted(0)))
	var engine: MmEngine = _hero_at([_bear()], [Scenario.creature("Goblin", 1, 1)], [jump], Step.BEGINNING_OF_COMBAT)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Jump", [_object(bear)])
	assert_true(Scenario.now(engine, bear).has_ability(FlyingAbility))
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	Scenario.declare_attackers(engine, [bear])

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "The Goblin could not block a flyer.")


func test_losing_all_abilities_removes_keywords_but_not_other_sources_bonuses() -> void:
	var flying_knight: MmCardDefinition = _knight()
	flying_knight.abilities = [FlyingAbility.new()]
	var engine: MmEngine = _hero_main([_captain(), flying_knight], [], [_hush()])
	var knight: int = Scenario.permanent_named(engine, engine.hero().id, "Knight")

	Scenario.cast_and_resolve(engine, "Hush", [_object(knight)])

	assert_false(Scenario.now(engine, knight).has_ability(FlyingAbility))
	assert_eq(Scenario.pt(engine, knight), [3, 3], "The Captain's bonus still applies.")


func test_a_static_ability_removed_in_layer_six_never_starts_in_layer_seven() -> void:
	var engine: MmEngine = _hero_main([_captain(), _knight()], [], [_hush()])
	var captain: int = Scenario.permanent_named(engine, engine.hero().id, "Captain")
	var knight: int = Scenario.permanent_named(engine, engine.hero().id, "Knight")

	Scenario.cast_and_resolve(engine, "Hush", [_object(captain)])

	assert_eq(Scenario.pt(engine, knight), [2, 2])


func test_an_effect_that_started_in_layer_six_keeps_applying_in_layer_seven() -> void:
	var lord: MmCardDefinition = Scenario.creature("Lord", 1, 1, [Scenario.continuous_static([
		Scenario.gain_abilities([FlyingAbility.new()], Scenario.each_creature(Scenario.has_subtype("Knight"))),
		Scenario.modify_pt(1, 1, Scenario.each_creature(Scenario.has_subtype("Knight")))])])
	var engine: MmEngine = _hero_main([lord, _knight()], [], [_hush()])
	var lord_id: int = Scenario.permanent_named(engine, engine.hero().id, "Lord")
	var knight: int = Scenario.permanent_named(engine, engine.hero().id, "Knight")

	Scenario.cast_and_resolve(engine, "Hush", [_object(lord_id)])

	assert_true(Scenario.now(engine, knight).has_ability(FlyingAbility), "The Lord's effect applied before Hush's.")
	assert_eq(Scenario.pt(engine, knight), [3, 3], "CR 613.6: having started, it continues in layer 7c.")


func test_a_filter_in_layer_seven_sees_abilities_granted_in_layer_six() -> void:
	var with_flying: HasAbilityFilter = HasAbilityFilter.new()
	with_flying.ability_kind = FlyingAbility
	var sky_captain: MmCardDefinition = Scenario.artifact("Sky Banner", [Scenario.continuous_static([
		Scenario.modify_pt(1, 1, Scenario.each_creature(with_flying))])])
	var jump: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Jump", Scenario.gain_abilities([FlyingAbility.new()], Scenario.targeted(0)))
	var engine: MmEngine = _hero_main([sky_captain, _bear()], [], [jump])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.pt(engine, bear), [2, 2])

	Scenario.cast_and_resolve(engine, "Jump", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [3, 3])


func test_a_characteristic_defining_ability_works_everywhere_and_prints_as_a_star() -> void:
	var wall: MmCardDefinition = Scenario.creature("Wall", 0, 4)
	wall.subtypes = ["Wall"]
	var engine: MmEngine = _hero_main([_warlord(), _bear(), wall], [_bear()], [_warlord()])
	var warlord: int = Scenario.permanent_named(engine, engine.hero().id, "Warlord")
	var in_hand: MmGameObject = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Warlord"))

	assert_eq(Scenario.pt(engine, warlord), [2, 2], "Itself and the Bear; not the Wall, not the Villain's Bear.")
	var from_hand: MmCharacteristics = engine.game_state().characteristics_of(in_hand)
	assert_eq([from_hand.power, from_hand.toughness], [2, 2], "CR 604.3: it works in every zone.")
	var printed: MmCharacteristics = MmCharacteristics.printed(_warlord())
	assert_true(printed.is_power_variable)
	assert_true(printed.is_toughness_variable)
	assert_false(MmCharacteristics.printed(_bear()).is_power_variable)


func test_last_known_information_keeps_the_pumped_power() -> void:
	var power: PowerValue = PowerValue.new()
	power.selection = TriggeringObjectSelection.new()
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = power
	gain.players = Scenario.you()
	var mourner: MmCardDefinition = Scenario.artifact("Mourner", [Scenario.triggered(Scenario.dies(Scenario.of_type(CardType.CREATURE)), [gain])])
	var engine: MmEngine = _hero_main([mourner, _bear()], [], [Scenario.pump_spell("Pump", 3, 0), Scenario.free_shock("Shock", 2)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Pump", [_object(bear)])

	Scenario.cast_and_resolve(engine, "Shock", [_object(bear)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 25, "It died as a 5/2.")


func test_a_copy_of_the_state_agrees_and_replays_are_exact() -> void:
	var hero_cards: Array[MmCardDefinition] = [_captain(), _bear()]
	var villain_cards: Array[MmCardDefinition] = [_knight()]
	var extras: Array[MmCardDefinition] = [Scenario.pump_spell("Pump", 1, 1)]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, villain_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, villain_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	var bear: int = Scenario.permanent_named(original, original.hero().id, "Bear")
	Scenario.cast_and_resolve(original, "Pump", [_object(bear)])

	var copy: MmGameState = original.game_state().duplicate_state()
	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_eq(copy.characteristics_of(copy.object(bear)).power, 3)
	assert_eq(copy.continuous_effects.size(), 1)
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _knight() -> MmCardDefinition:
	var knight: MmCardDefinition = Scenario.creature("Knight", 2, 2)
	knight.subtypes = ["Knight"]
	return knight


## "Knights get +1/+1."
func _captain() -> MmCardDefinition:
	return Scenario.creature("Captain", 1, 1, [Scenario.continuous_static([
		Scenario.modify_pt(1, 1, Scenario.each_creature(Scenario.has_subtype("Knight")))])])


## "Target creature has base power and toughness 0/1 until end of turn."
func _shrink() -> MmCardDefinition:
	return Scenario.creature_spell_until_end_of_turn("Shrink", Scenario.set_pt(0, 1, Scenario.targeted(0)))


## "Target creature loses all abilities until end of turn."
func _hush() -> MmCardDefinition:
	return Scenario.creature_spell_until_end_of_turn("Hush", Scenario.lose_all_abilities(Scenario.targeted(0)))


## */*: "This creature's power and toughness are each equal to the number of non-Wall
## creatures you control."
func _warlord() -> MmCardDefinition:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each_creature(Scenario.all_of([mine, Scenario.is_not(Scenario.has_subtype("Wall"))]))
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = count
	defining.toughness = count
	return Scenario.creature("Warlord", 0, 0, [defining])


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	return _hero_at(hero_permanents, villain_permanents, hero_extras, Step.PRECOMBAT_MAIN)


func _hero_at(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition], step: Step) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3, step)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
