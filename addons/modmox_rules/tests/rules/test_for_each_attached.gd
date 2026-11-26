extends GutTest
## "This creature gets +2/+0 for each Equipment attached to it" (Goblin Gaveleer): a
## ModifyPowerToughnessContinuousEffect whose power is a ProductValue of the count of
## Equipment matching IsAttachedToFilter of this creature (CR 301.5, 613.4c).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_it_gets_two_power_for_each_equipment_attached_to_it() -> void:
	var engine: MmEngine = _hero_main([_gaveleer(), Scenario.sword("Sword", 0), Scenario.sword("Axe", 0)], [])
	var gaveleer: int = Scenario.permanent_named(engine, engine.hero().id, "Gaveleer")
	assert_eq(Scenario.pt(engine, gaveleer), [1, 1], "Nothing attached.")

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), gaveleer)
	assert_eq(Scenario.pt(engine, gaveleer), [3, 1])

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Axe"), gaveleer)
	assert_eq(Scenario.pt(engine, gaveleer), [5, 1])


func test_equipment_on_another_creature_and_an_aura_on_it_do_not_count() -> void:
	var aura: MmCardDefinition = Scenario.aura("Aura", Scenario.of_type(CardType.CREATURE))
	var engine: MmEngine = _hero_main([_gaveleer(), Scenario.creature("Bear", 2, 2), Scenario.sword("Sword", 0)], [aura])
	var gaveleer: int = Scenario.permanent_named(engine, engine.hero().id, "Gaveleer")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), bear)
	assert_eq(Scenario.cast_and_resolve(engine, "Aura", [MmReference.to_object(gaveleer)]), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Aura"), -1, "The Aura is on it.")
	assert_eq(Scenario.pt(engine, gaveleer), [1, 1], "Only Equipment attached to it counts.")


func test_moving_the_equipment_off_takes_the_bonus_away() -> void:
	var engine: MmEngine = _hero_main([_gaveleer(), Scenario.creature("Bear", 2, 2), Scenario.sword("Sword", 0)], [])
	var gaveleer: int = Scenario.permanent_named(engine, engine.hero().id, "Gaveleer")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, gaveleer)

	Scenario.equip_and_resolve(engine, sword, bear)

	assert_eq(Scenario.pt(engine, gaveleer), [1, 1])


func test_a_product_value_is_its_factor_times_its_value() -> void:
	var product: ProductValue = ProductValue.new()
	product.factor = 2
	product.value = Scenario.constant(3)

	assert_eq(product.evaluate(null, null), 6)


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_for_each_attached.tres"
	assert_eq(ResourceSaver.save(_gaveleer(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var pump: ModifyPowerToughnessContinuousEffect = (loaded.abilities[0] as ContinuousStaticAbility).effects[0] \
		as ModifyPowerToughnessContinuousEffect
	assert_eq((pump.power as ProductValue).factor, 2)
	var counted: EachSelection = (pump.power as ProductValue).value.get("selection") as EachSelection
	assert_true((counted.filter as AllOfFilter).filters[1] is IsAttachedToFilter)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A 1/1 costing {0} with "This creature gets +2/+0 for each Equipment attached to it."
func _gaveleer() -> MmCardDefinition:
	var to_it: IsAttachedToFilter = IsAttachedToFilter.new()
	to_it.selection = SourceSelection.new()
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each(Scenario.all_of([Scenario.has_subtype("Equipment"), to_it]))
	var twice: ProductValue = ProductValue.new()
	twice.factor = 2
	twice.value = count
	var pump: ModifyPowerToughnessContinuousEffect = Scenario.modify_pt(0, 0, SourceSelection.new())
	pump.power = twice
	return Scenario.creature("Gaveleer", 1, 1, [Scenario.continuous_static([pump])])


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
