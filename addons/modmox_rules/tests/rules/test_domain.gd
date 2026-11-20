extends GutTest
## Domain (CR 207.2c): "the number of basic land types among lands you control" is a
## BasicLandTypeCountValue, as in Gaea's Might. Each of Plains, Island, Swamp, Mountain and
## Forest is counted once, from the lands' current characteristics, whether or not the land
## is basic (CR 205.3i).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_with_no_lands_domain_is_zero() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_land_fetch()])

	assert_eq(_hero_domain(engine), 0)


func test_each_basic_land_type_is_counted_once() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_land_fetch()])

	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Plains", "Island"]), "")

	assert_eq(_hero_domain(engine), 2, "Two Plains are one basic land type.")


func test_a_nonbasic_land_counts_each_basic_land_type_it_has() -> void:
	# CR 205.3i: a Plains Island is not basic, but it has both types.
	var engine: MmEngine = _hero_main([], [], [Scenario.free_land_fetch()])

	assert_eq(Scenario.fetch_lands(engine, ["Plains Island"]), "")

	assert_eq(_hero_domain(engine), 2)


func test_a_land_with_no_basic_land_types_adds_nothing() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_land_fetch()])

	assert_eq(Scenario.fetch_lands(engine, ["Vault", "Forest"]), "")

	assert_eq(_hero_domain(engine), 1)


func test_only_lands_you_control_are_counted() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_land_fetch()])

	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Island"]), "")

	var villains: MmEffectContext = MmEffectContext.new(engine.villain().id, 0)
	assert_eq(Scenario.domain().evaluate(engine.game_state(), villains), 0, "The Hero's lands are not the Villain's.")
	assert_eq(_hero_domain(engine), 2)


func test_a_basic_land_type_an_effect_gives_is_counted() -> void:
	# Layer 4 (CR 613.1d): Domain reads the lands' current types.
	var engine: MmEngine = _hero_main([_swamp_maker()], [], [Scenario.free_land_fetch()])

	assert_eq(Scenario.fetch_lands(engine, ["Plains"]), "")

	assert_eq(_hero_domain(engine), 2, "A Plains that is also a Swamp.")


func test_all_five_basic_land_types_make_five_and_no_more() -> void:
	var engine: MmEngine = _hero_main([], [], [Scenario.free_land_fetch()])

	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Island", "Swamp", "Mountain", "Forest", "Plains Island"]), "")

	assert_eq(_hero_domain(engine), 5)


func test_a_pump_by_domain_is_fixed_as_it_resolves() -> void:
	# CR 608.2h: "+X/+X until end of turn" works X out once.
	var engine: MmEngine = _hero_main([_bear()], [],
		[Scenario.free_land_fetch(), Scenario.free_land_fetch("Late Fetch"), _might()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest"]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Might", [_object(bear)]), "")

	assert_eq(Scenario.pt(engine, bear), [4, 4])
	assert_eq(Scenario.fetch_lands(engine, ["Island"], "Late Fetch"), "")
	assert_eq(Scenario.pt(engine, bear), [4, 4], "A land arriving later does not change X.")


func test_a_characteristic_defining_ability_by_domain_follows_the_lands() -> void:
	# CR 604.3, 613.4a: worked out in layer 7a, after layer 4 gave the Plains its Swamp type.
	var engine: MmEngine = _hero_main([_brawler(), _swamp_maker()], [], [Scenario.free_land_fetch()])
	var brawler: int = Scenario.permanent_named(engine, engine.hero().id, "Brawler")
	assert_eq(Scenario.pt(engine, brawler), [0, 3])

	assert_eq(Scenario.fetch_lands(engine, ["Plains"]), "")

	assert_eq(Scenario.pt(engine, brawler), [2, 3])


func test_damage_of_one_plus_domain_is_worked_out_as_it_resolves() -> void:
	# Artillery Blast's "X damage, where X is 1 plus [Domain]".
	var engine: MmEngine = _hero_main([], [Scenario.creature("Ogre", 3, 3)], [Scenario.free_land_fetch(), _blast()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Mountain"]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Blast", [_object(ogre)]), "")

	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Ogre"), -1, "3 damage killed the 3/3.")


func test_toughness_less_than_domain_is_read_as_the_counters_are_put() -> void:
	# Zar Ojanen's "a +1/+1 counter on each creature you control with toughness less than
	# [Domain]", here with Domain 3: only the 1/1.
	var engine: MmEngine = _scion_ready(["Plains", "Island", "Swamp"])

	assert_eq(Scenario.cast_and_resolve(engine, "Tap", [_object(_mine(engine, "Scion"))]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_plus_ones(engine, engine.hero().id, "Cub"), 1)
	assert_eq(_plus_ones(engine, engine.hero().id, "Brawler"), 0, "Toughness 3 is not less than 3.")
	assert_eq(_plus_ones(engine, engine.hero().id, "Scion"), 0)
	assert_eq(_plus_ones(engine, engine.villain().id, "Bear"), 0, "Only creatures its controller controls.")


func test_with_all_five_basic_land_types_toughness_four_is_less() -> void:
	var engine: MmEngine = _scion_ready(["Plains", "Island", "Swamp", "Mountain", "Forest"])

	assert_eq(Scenario.cast_and_resolve(engine, "Tap", [_object(_mine(engine, "Scion"))]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_plus_ones(engine, engine.hero().id, "Cub"), 1)
	assert_eq(_plus_ones(engine, engine.hero().id, "Brawler"), 1)
	assert_eq(_plus_ones(engine, engine.hero().id, "Scion"), 1, "The 4/4 counts itself.")


## A Scion, a 1/1 Cub and a 0/3 Brawler for the Hero, a Bear for the Villain, then the
## Hero fetches [param land_names] and holds a free Tap.
func _scion_ready(land_names: Array[String]) -> MmEngine:
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 1)
	var wall: MmCardDefinition = Scenario.creature("Brawler", 0, 3)
	var engine: MmEngine = _hero_main([Scenario.scion(), cub, wall], [_bear()],
		[Scenario.free_land_fetch(), Scenario.free_tap("Tap")])
	assert_eq(Scenario.fetch_lands(engine, land_names), "")
	return engine


func _mine(engine: MmEngine, card_name: String) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, card_name)


func _plus_ones(engine: MmEngine, player_id: int, card_name: String) -> int:
	return Scenario.counters_on(engine, Scenario.permanent_named(engine, player_id, card_name), MmCounter.Kind.PLUS_ONE_PLUS_ONE)


func _hero_domain(engine: MmEngine) -> int:
	return Scenario.domain().evaluate(engine.game_state(), MmEffectContext.new(engine.hero().id, 0))


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## A */3 creature costing {0}: "This creature's power is equal to [Domain]."
func _brawler() -> MmCardDefinition:
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = Scenario.domain()
	return Scenario.creature("Brawler", 0, 3, [defining])


## An enchantment costing {0}: "Lands you control are Swamps in addition to their other types."
func _swamp_maker() -> MmCardDefinition:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var lands: EachSelection = Scenario.each(Scenario.all_of([Scenario.of_type(CardType.LAND), mine]))
	return Scenario.enchantment("Swamp Maker", [Scenario.continuous_static([Scenario.add_subtypes(["Swamp"], lands)])])


## Gaea's Might as an instant costing {0}: "Target creature gets +X/+X until end of turn,
## where X is [Domain]."
func _might() -> MmCardDefinition:
	var pump: ModifyPowerToughnessContinuousEffect = Scenario.modify_pt(0, 0, Scenario.targeted(0))
	pump.power = Scenario.domain()
	pump.toughness = Scenario.domain()
	return Scenario.creature_spell_until_end_of_turn("Might", pump)


## Artillery Blast as an instant costing {0}, aimed at any creature: "Blast deals X damage
## to target creature, where X is 1 plus [Domain]."
func _blast() -> MmCardDefinition:
	var damage: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	damage.amount = Scenario.sum([Scenario.constant(1), Scenario.domain()])
	return Scenario.instant("Blast", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.CREATURE))], [damage])


## Stops in the Hero's precombat main phase of Game Turn 3 with [param hero_permanents] and
## [param villain_permanents] in play and [param hero_extras] in hand. Every land a
## free_land_fetch() may find is in the Hero's library: each basic, a Plains Island and a
## Vault with no land types.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var lands: Array[MmCardDefinition] = [Scenario.basic_land("Plains"), Scenario.basic_land("Island"),
		Scenario.basic_land("Swamp"), Scenario.basic_land("Mountain"), Scenario.basic_land("Forest"),
		Scenario.dual_land("Plains", "Island"), Scenario.mana_land("Vault", MmMana.Type.COLORLESS, 2)]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras + lands)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
