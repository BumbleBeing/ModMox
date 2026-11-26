extends GutTest
## CR 613: continuous effects apply in layers, and within a layer in timestamp order.
## CR 611.2c: an effect from a resolved spell locks in what it affects; CR 611.3a: a static
## ability's effect applies to whatever matches right now. CR 613.6: an effect that started
## applying keeps applying in later layers even if its ability is removed.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const MINUS := MmCounter.Kind.MINUS_ONE_MINUS_ONE


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


func test_a_conditional_static_ability_applies_only_while_its_condition_is_true() -> void:
	var engine: MmEngine = _hero_main([_squire()], [], [Scenario.free_counters("Grow", PLUS, 2),
		Scenario.free_counters("Swell", PLUS, 1), Scenario.free_counters("Wither", MINUS, 1)])
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	Scenario.cast_and_resolve(engine, "Grow", [_object(squire)])
	assert_false(Scenario.now(engine, squire).has_ability(FlyingAbility), "Two counters: the condition is false.")

	Scenario.cast_and_resolve(engine, "Swell", [_object(squire)])

	assert_true(Scenario.now(engine, squire).has_ability(FlyingAbility), "CR 611.3a: three counters, so it applies now.")
	Scenario.cast_and_resolve(engine, "Wither", [_object(squire)])
	assert_eq(Scenario.counters_on(engine, squire, PLUS), 2, "CR 704.5q took one away.")
	assert_false(Scenario.now(engine, squire).has_ability(FlyingAbility), "False again, so it stops applying.")


func test_a_type_changing_effect_adds_a_subtype_and_keeps_the_others() -> void:
	var knighted: MmCardDefinition = Scenario.creature("Squire", 1, 1, [Scenario.continuous_static([
		Scenario.add_subtypes(["Knight"], SourceSelection.new())])])
	knighted.subtypes = ["Cat", "Scout"]
	var already: MmCardDefinition = _knight()
	already.abilities = [Scenario.continuous_static([Scenario.add_subtypes(["Knight"], SourceSelection.new())])]
	var engine: MmEngine = _hero_main([knighted, already], [], [])
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	var knight: int = Scenario.permanent_named(engine, engine.hero().id, "Knight")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, squire)

	var subtypes: Array[String] = Scenario.now(engine, squire).subtypes

	assert_eq(subtypes, ["Cat", "Scout", "Knight"] as Array[String], "CR 205.1b: in addition to its other types.")
	assert_true(Scenario.has_subtype("Knight").matches(engine.game_state(), _object(squire), context))
	assert_eq(Scenario.now(engine, knight).subtypes, ["Knight"] as Array[String], "Never twice.")
	assert_eq(MmCharacteristics.printed(knighted).subtypes, ["Cat", "Scout"] as Array[String], "The definition is untouched.")


func test_becoming_a_creature_type_replaces_its_creature_types_and_keeps_the_rest() -> void:
	# CR 205.1a: the new creature types replace its creature types, and only those.
	var druid: MmCardDefinition = Scenario.typed_creature("Druid", 1, 1, ["Human", "Druid"])
	var engine: MmEngine = _hero_main([druid, Scenario.sash()], [], [Scenario.free_moonrise("Moon"), Scenario.free_moonrise("Rise")])
	var human: int = Scenario.permanent_named(engine, engine.hero().id, "Druid")
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Sash")

	assert_eq(Scenario.cast_and_resolve(engine, "Moon", [_object(human)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Rise", [_object(sash)]), "")

	assert_eq(Scenario.now(engine, human).subtypes, ["Werewolf"] as Array[String])
	assert_eq(Scenario.now(engine, human).card_types, [CardType.CREATURE] as Array[CardType])
	assert_eq(Scenario.now(engine, sash).subtypes, ["Equipment", "Werewolf"] as Array[String],
		"An artifact type is not a creature type, so it stays.")
	assert_eq(Scenario.now(engine, sash).card_types, [CardType.ARTIFACT, CardType.CREATURE] as Array[CardType])


func test_a_creature_type_added_later_is_added_on_top_and_one_added_earlier_is_replaced() -> void:
	# CR 613.7: within layer 4, in timestamp order.
	var knighted: MmCardDefinition = Scenario.typed_creature_with("Squire", 1, 1, ["Human"], [Scenario.continuous_static([
		Scenario.add_subtypes(["Knight"], SourceSelection.new())])])
	var dubbing: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Dub", Scenario.add_subtypes(["Knight"], Scenario.targeted(0)))
	var bear: MmCardDefinition = Scenario.typed_creature("Bear", 2, 2, ["Bear"])
	var engine: MmEngine = _hero_main([knighted, bear], [], [Scenario.free_moonrise("Moon"), Scenario.free_moonrise("Rise"), dubbing])
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	var bear_id: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Moon", [_object(squire)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Rise", [_object(bear_id)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Dub", [_object(bear_id)]), "")

	assert_eq(Scenario.now(engine, squire).subtypes, ["Werewolf"] as Array[String], "The Squire's own Knight came first.")
	assert_eq(Scenario.now(engine, bear_id).subtypes, ["Werewolf", "Knight"] as Array[String], "Dub came after.")


func test_a_changeling_that_becomes_a_werewolf_is_a_werewolf_only() -> void:
	# CR 613.3: changeling applies first in layer 4, and the later effect replaces every type it gave.
	var engine: MmEngine = _hero_main([Scenario.changeling()], [], [Scenario.free_moonrise()])
	var changeling: int = Scenario.permanent_named(engine, engine.hero().id, "Changeling")

	assert_eq(Scenario.cast_and_resolve(engine, "Moonrise", [_object(changeling)]), "")

	assert_true(Scenario.now(engine, changeling).has_subtype("Werewolf"))
	assert_false(Scenario.now(engine, changeling).has_subtype("Elf"))
	assert_false(Scenario.now(engine, changeling).has_subtype("Shapeshifter"))


func test_it_lasts_after_the_turn_ends() -> void:
	# CR 611.2a: an effect with no duration lasts.
	var druid: MmCardDefinition = Scenario.typed_creature("Druid", 1, 1, ["Human", "Druid"])
	var engine: MmEngine = _hero_main([druid], [], [Scenario.free_moonrise()])
	var human: int = Scenario.permanent_named(engine, engine.hero().id, "Druid")
	assert_eq(Scenario.cast_and_resolve(engine, "Moonrise", [_object(human)]), "")

	assert_eq(Scenario.play_until_game_turn(engine, 5), "")

	assert_eq(Scenario.now(engine, human).subtypes, ["Werewolf"] as Array[String])


func test_a_filter_in_layer_six_sees_a_subtype_added_in_layer_four() -> void:
	var knighted: MmCardDefinition = Scenario.creature("Squire", 1, 1, [Scenario.continuous_static([
		Scenario.add_subtypes(["Knight"], SourceSelection.new())])])
	var lord: MmCardDefinition = Scenario.creature("Lord", 1, 1, [Scenario.continuous_static([
		Scenario.gain_abilities([FlyingAbility.new()], Scenario.each_creature(Scenario.has_subtype("Knight")))])])
	var engine: MmEngine = _hero_main([lord, _captain()], [], [knighted])

	Scenario.cast_and_resolve(engine, "Squire")

	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	assert_true(Scenario.now(engine, squire).has_ability(FlyingAbility),
		"CR 613.1d: layer 4 applies before layer 6, whatever the timestamps.")
	assert_eq(Scenario.pt(engine, squire), [2, 2], "The Captain's Knights get +1/+1 in layer 7c.")


func test_a_land_that_gains_every_basic_land_type_gains_their_mana_abilities() -> void:
	# CR 305.7: the mana abilities come with the types, not only with printed ones.
	var dawn: MmCardDefinition = Scenario.instant("Dawn", Scenario.mana_cost(0, [MmMana.Type.WHITE]), [],
		[Scenario.gain_life(1, Scenario.you())])
	var forest_card: MmCardDefinition = Scenario.basic_land("Forest")
	var engine: MmEngine = _land_main(forest_card, [_presence(), dawn])
	var forest: int = _fetch(engine, "Forest")

	assert_eq(Scenario.cast_and_resolve(engine, "Presence", [_object(forest)]), "")

	assert_eq(Scenario.now(engine, forest).subtypes, ["Forest", "Plains", "Island", "Swamp", "Mountain"] as Array[String],
		"In addition to its other types.")
	assert_eq(_mana_made(engine, forest), [MmMana.Type.GREEN, MmMana.Type.WHITE, MmMana.Type.BLUE, MmMana.Type.BLACK,
		MmMana.Type.RED] as Array[MmMana.Type])
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Dawn"), "", "The Forest taps for {W}.")
	assert_eq(engine.hero().life, life + 1)
	assert_true(engine.game_state().object(forest).is_tapped)
	assert_eq(MmCharacteristics.printed(forest_card).abilities.size(), 1, "The definition is untouched.")


func test_a_land_keeps_its_own_mana_abilities_and_gains_only_the_types_it_lacked() -> void:
	var ruins: MmCardDefinition = Scenario.mana_land("Ruins", MmMana.Type.COLORLESS, 1)
	ruins.subtypes = ["Plains", "Island"]
	var engine: MmEngine = _land_main(ruins, [_presence()])
	var land: int = _fetch(engine, "Ruins")

	assert_eq(Scenario.cast_and_resolve(engine, "Presence", [_object(land)]), "")

	assert_eq(_mana_made(engine, land), [MmMana.Type.COLORLESS, MmMana.Type.WHITE, MmMana.Type.BLUE,
		MmMana.Type.BLACK, MmMana.Type.RED, MmMana.Type.GREEN] as Array[MmMana.Type],
		"Its written ability keeps its index, and no type's ability comes twice.")


func test_a_land_loses_the_gained_mana_abilities_when_its_types_go() -> void:
	var engine: MmEngine = _land_main(Scenario.basic_land("Forest"), [_presence(), Scenario.free_disenchant("Disenchant")])
	var forest: int = _fetch(engine, "Forest")
	assert_eq(Scenario.cast_and_resolve(engine, "Presence", [_object(forest)]), "")
	var presence: int = Scenario.permanent_named(engine, engine.hero().id, "Presence")

	assert_eq(Scenario.cast_and_resolve(engine, "Disenchant", [_object(presence)]), "")

	assert_eq(Scenario.now(engine, forest).subtypes, ["Forest"] as Array[String])
	assert_eq(_mana_made(engine, forest), [MmMana.Type.GREEN] as Array[MmMana.Type])


func test_losing_all_abilities_in_layer_six_takes_the_gained_mana_abilities_too() -> void:
	# CR 613.1d before 613.1f: the abilities come in layer 4, so layer 6 removes them.
	var hush: MmCardDefinition = Scenario.instant("Hush", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.LAND))],
		[Scenario.until_end_of_turn(Scenario.lose_all_abilities(Scenario.targeted(0)))])
	var engine: MmEngine = _land_main(Scenario.basic_land("Forest"), [_presence(), hush])
	var forest: int = _fetch(engine, "Forest")
	assert_eq(Scenario.cast_and_resolve(engine, "Presence", [_object(forest)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Hush", [_object(forest)]), "")

	assert_eq(_mana_made(engine, forest), [] as Array[MmMana.Type])
	assert_eq(Scenario.now(engine, forest).subtypes.size(), 5, "It keeps its types.")


func test_domain_counts_the_types_a_land_gained() -> void:
	var engine: MmEngine = _land_main(Scenario.basic_land("Forest"), [_presence()])
	var forest: int = _fetch(engine, "Forest")

	assert_eq(Scenario.cast_and_resolve(engine, "Presence", [_object(forest)]), "")

	assert_eq(Scenario.domain().evaluate(engine.game_state(), MmEffectContext.new(engine.hero().id, forest)), 5)


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


func test_a_characteristic_defining_ability_in_a_graveyard_counting_permanents_ends() -> void:
	# The layers are worked out for the battlefield and the command zone only (ADR 0018). A
	# Warlord in the graveyard counts creatures on the battlefield; were the graveyard among
	# the objects the layers work out, asking its characteristics would work them out again
	# from inside, without end.
	var engine: MmEngine = _hero_main([_warlord(), _bear()], [], [Scenario.free_destroy("Doom")])
	var warlord: int = Scenario.permanent_named(engine, engine.hero().id, "Warlord")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Doom", [_object(warlord)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var dead: MmGameObject = engine.game_state().object(Scenario.card_in_graveyard(engine, engine.hero(), "Warlord"))
	var in_graveyard: MmCharacteristics = engine.game_state().characteristics_of(dead)
	assert_eq([in_graveyard.power, in_graveyard.toughness], [1, 1], "CR 604.3: the Bear alone.")
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_a_power_defining_ability_keeps_the_printed_toughness() -> void:
	# CR 604.3: a */3 defines its power alone, in every zone.
	var engine: MmEngine = _hero_main([_strider(), _bear()], [_bear()], [_strider()])
	var strider: int = Scenario.permanent_named(engine, engine.hero().id, "Strider")
	var in_hand: MmGameObject = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Strider"))

	assert_eq(Scenario.pt(engine, strider), [2, 3], "Itself and the Bear; the toughness is printed.")
	var from_hand: MmCharacteristics = engine.game_state().characteristics_of(in_hand)
	assert_eq([from_hand.power, from_hand.toughness], [2, 3])
	var printed: MmCharacteristics = MmCharacteristics.printed(_strider())
	assert_true(printed.is_power_variable, "It prints */3.")
	assert_false(printed.is_toughness_variable)


func test_a_toughness_defining_ability_keeps_the_printed_power() -> void:
	var engine: MmEngine = _hero_main([_sprawler(), _bear()], [], [])
	var sprawler: int = Scenario.permanent_named(engine, engine.hero().id, "Sprawler")

	assert_eq(Scenario.pt(engine, sprawler), [1, 2])
	var printed: MmCharacteristics = MmCharacteristics.printed(_sprawler())
	assert_false(printed.is_power_variable, "It prints 1/*.")
	assert_true(printed.is_toughness_variable)


func test_a_power_defining_ability_is_modified_and_set_by_later_layers() -> void:
	var engine: MmEngine = _hero_main([_strider()], [], [Scenario.pump_spell("Pump", 2, 2),
			Scenario.creature_spell_until_end_of_turn("Shrink", Scenario.set_pt(1, 1, Scenario.targeted(0)))])
	var strider: int = Scenario.permanent_named(engine, engine.hero().id, "Strider")
	assert_eq(Scenario.pt(engine, strider), [1, 3])

	Scenario.cast_and_resolve(engine, "Pump", [_object(strider)])
	assert_eq(Scenario.pt(engine, strider), [3, 5], "Layer 7c on top of 7a and the printed toughness.")

	Scenario.cast_and_resolve(engine, "Shrink", [_object(strider)])
	assert_eq(Scenario.pt(engine, strider), [3, 3], "Layer 7b sets both, then 7c adds +2/+2.")


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


func test_last_known_information_keeps_the_pumped_toughness() -> void:
	var toughness: ToughnessValue = ToughnessValue.new()
	toughness.selection = TriggeringObjectSelection.new()
	var gain: GainLifeEffect = GainLifeEffect.new()
	gain.amount = toughness
	gain.players = Scenario.you()
	var mourner: MmCardDefinition = Scenario.artifact("Mourner", [Scenario.triggered(Scenario.dies(Scenario.of_type(CardType.CREATURE)), [gain])])
	var engine: MmEngine = _hero_main([mourner, _bear()], [], [Scenario.pump_spell("Pump", 0, 3), Scenario.free_destroy("Doom")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Pump", [_object(bear)])

	Scenario.cast_and_resolve(engine, "Doom", [_object(bear)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 25, "It died as a 2/5.")


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


## "As long as this creature has three or more +1/+1 counters on it, it has flying."
func _squire() -> MmCardDefinition:
	return Scenario.creature("Squire", 1, 1, [Scenario.continuous_static(
		[Scenario.gain_abilities([FlyingAbility.new()], SourceSelection.new())],
		Scenario.condition(SourceSelection.new(), Scenario.has_counters(PLUS, 3)))])


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


## */3: "This creature's power is equal to the number of creatures you control."
func _strider() -> MmCardDefinition:
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = _creatures_you_control()
	return Scenario.creature("Strider", 0, 3, [defining])


## 1/*: "This creature's toughness is equal to the number of creatures you control."
func _sprawler() -> MmCardDefinition:
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.toughness = _creatures_you_control()
	return Scenario.creature("Sprawler", 1, 0, [defining])


## Nylea's Presence as an Aura costing {0}, without its draw: "Enchant land. Enchanted land
## is every basic land type in addition to its other types."
func _presence() -> MmCardDefinition:
	return Scenario.aura("Presence", null, [Scenario.continuous_static([Scenario.every_basic_land_type(Scenario.attached())])])


## The types of mana the mana abilities of [param object_id] add, in ability order.
func _mana_made(engine: MmEngine, object_id: int) -> Array[MmMana.Type]:
	var made: Array[MmMana.Type] = []
	for ability: MmAbility in Scenario.now(engine, object_id).abilities:
		var activated: ActivatedAbility = ability as ActivatedAbility
		if activated == null:
			continue
		for effect: MmEffect in activated.effects:
			if effect is AddManaEffect:
				made.append((effect as AddManaEffect).mana_type)
	return made


## Puts the land card named [param land_name] from the Hero's library onto the battlefield.
func _fetch(engine: MmEngine, land_name: String) -> int:
	assert_eq(Scenario.fetch_lands(engine, [land_name]), "")
	return Scenario.permanent_named(engine, engine.hero().id, land_name)


## Stops in the Hero's precombat main phase of Game Turn 3 with a Land Fetch and
## [param hero_extras] in hand, and [param land] in the Hero's library for the fetch.
func _land_main(land: MmCardDefinition, hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var in_hand: Array[MmCardDefinition] = [Scenario.free_land_fetch()]
	in_hand.append_array(hero_extras)
	var no_cards: Array[MmCardDefinition] = []
	var deck: Array[MmCardDefinition] = in_hand.duplicate()
	deck.append(land)
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, deck)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, in_hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _creatures_you_control() -> CountValue:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each_creature(mine)
	return count


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
