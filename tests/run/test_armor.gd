extends GutTest
## Milestone 23: an Armor (game ADR 0106) holds Starting Conditions that change how the Hero
## starts each encounter while it is Worn, and do nothing while it is only held. Its shape
## is checked as a Mod's is.

const ArmorSample := preload("res://tests/support/armor_sample.gd")
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"


## A1: more life on a Worn Armor raises the Hero's starting life.
func test_more_life_on_a_worn_armor_raises_the_heros_starting_life() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(3)]))

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(setup.starting_life, 23)


## A1: an extra free mulligan on a Worn Armor gives the Hero one.
func test_an_extra_free_mulligan_on_a_worn_armor_gives_the_hero_one() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Seer's Cuirass", Armor.Slot.CUIRASS, [ArmorSample.mulligans(1)]))

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(setup.free_mulligans, 1)


## A1: one fewer card on a Worn Armor makes the opening hand six, and only the opening hand.
func test_one_fewer_card_on_a_worn_armor_makes_the_opening_hand_six() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Heavy Greaves", Armor.Slot.GREAVES, [ArmorSample.fewer_cards(1)]))

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(setup.opening_hand_size, 6)
	assert_eq(setup.maximum_hand_size, 7, "Only the opening hand is smaller.")


## A1: an Emblem on a Worn Armor is the Hero's, after the Emblems the run holds.
func test_an_emblem_on_a_worn_armor_comes_after_the_runs_own() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Seer's Cuirass", Armor.Slot.CUIRASS, [ArmorSample.emblem(ArmorSample.DIVINERS_BOON)]))

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(_names(setup.emblems), ["Playtest Bolt", "Diviner's Boon"])


## A2: an Armor held but not Worn changes nothing.
func test_an_armor_held_but_not_worn_changes_nothing() -> void:
	var run: Run = _run()
	run.held_armor.add(ArmorSample.armor("Everything Helm", Armor.Slot.HELM, [ArmorSample.life(3),
		ArmorSample.mulligans(1), ArmorSample.fewer_cards(1), ArmorSample.emblem(ArmorSample.DIVINERS_BOON)]))

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(setup.starting_life, 20)
	assert_eq(setup.free_mulligans, 0)
	assert_eq(setup.opening_hand_size, 7)
	assert_eq(_names(setup.emblems), ["Playtest Bolt"])


## A6: Armor Worn in every slot adds up, its Emblems in slot order whatever order the Armor
## was put on in.
func test_worn_armor_in_every_slot_adds_up_with_emblems_in_slot_order() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Stormstride Greaves", Armor.Slot.GREAVES,
		[ArmorSample.life(2), ArmorSample.emblem(ArmorSample.ELECTROMANCERS_BOON)]))
	_wear(run, ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(3)]))
	_wear(run, ArmorSample.armor("Seer's Cuirass", Armor.Slot.CUIRASS,
		[ArmorSample.emblem(ArmorSample.DIVINERS_BOON), ArmorSample.mulligans(1)]))

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(setup.starting_life, 25)
	assert_eq(setup.free_mulligans, 1)
	assert_eq(_names(setup.emblems), ["Playtest Bolt", "Diviner's Boon", "Electromancer's Boon"])


## A6: starting life never falls below 1.
func test_starting_life_never_falls_below_one() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Gravewatch Helm", Armor.Slot.HELM, [ArmorSample.life(-15)]))
	_wear(run, ArmorSample.armor("Bloodbound Cuirass", Armor.Slot.CUIRASS, [ArmorSample.life(-10)]))

	assert_eq(run.hero_setup().starting_life, 1)


## A6: life is held in bounds only once every Starting Condition is applied, so a loss before
## a gain comes to what the sum says.
func test_a_loss_and_a_gain_of_life_come_to_their_sum_whatever_their_order() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Gravewatch Helm", Armor.Slot.HELM, [ArmorSample.life(-25)]))
	_wear(run, ArmorSample.armor("Thornwalker Greaves", Armor.Slot.GREAVES, [ArmorSample.life(10)]))

	assert_eq(run.hero_setup().starting_life, 5)


## A6: the opening hand never falls below 0.
func test_the_opening_hand_never_falls_below_zero() -> void:
	var run: Run = _run()
	_wear(run, ArmorSample.armor("Heavy Helm", Armor.Slot.HELM, [ArmorSample.fewer_cards(5)]))
	_wear(run, ArmorSample.armor("Heavy Cuirass", Armor.Slot.CUIRASS, [ArmorSample.fewer_cards(4)]))

	assert_eq(run.hero_setup().opening_hand_size, 0)


## A7: a well-shaped Armor has no problems.
func test_a_well_shaped_armor_has_no_problems() -> void:
	var armor: Armor = ArmorSample.armor("Seer's Cuirass", Armor.Slot.CUIRASS,
		[ArmorSample.emblem(ArmorSample.DIVINERS_BOON), ArmorSample.life(-2)])

	assert_eq(armor.problems(), [] as Array[String])


## A7: the shape check rejects an Armor with no name.
func test_the_shape_check_rejects_an_armor_with_no_name() -> void:
	var armor: Armor = ArmorSample.armor("", Armor.Slot.HELM, [ArmorSample.life(3)])

	assert_eq(armor.problems(), ["An Armor needs a name."] as Array[String])


## A7: the shape check rejects an Armor with no Starting Conditions.
func test_the_shape_check_rejects_an_armor_with_no_starting_conditions() -> void:
	var armor: Armor = ArmorSample.armor("Empty Helm", Armor.Slot.HELM, [])

	assert_eq(armor.problems(), ["An Armor needs at least one Starting Condition."] as Array[String])


## A7: the shape check rejects an Armor with no Armor Icon, and one whose icon is not 32 × 32.
func test_the_shape_check_rejects_an_armor_with_no_icon_or_one_of_another_size() -> void:
	var armor: Armor = ArmorSample.armor("Bare Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
	armor.icon = null
	var large: Armor = ArmorSample.armor("Large Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
	large.icon = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))

	assert_eq(armor.problems(), ["An Armor needs an Armor Icon."] as Array[String])
	assert_eq(large.problems(), ["An Armor Icon is 32 × 32."] as Array[String])


## A7: the shape check rejects an Armor with no price.
func test_the_shape_check_rejects_an_armor_with_no_price() -> void:
	var armor: Armor = ArmorSample.armor("Free Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
	armor.price = 0

	assert_eq(armor.problems(), ["An Armor needs a price."] as Array[String])


## A7: the shape check rejects a Starting Condition of nothing: an amount of zero, or an
## Emblem Starting Condition with no Emblem.
func test_the_shape_check_rejects_a_starting_condition_of_nothing() -> void:
	var no_emblem: EmblemStartingCondition = EmblemStartingCondition.new()
	for condition: StartingCondition in [ArmorSample.life(0), ArmorSample.mulligans(0), ArmorSample.fewer_cards(0),
			no_emblem]:
		var armor: Armor = ArmorSample.armor("Hollow Helm", Armor.Slot.HELM, [condition])

		assert_eq(armor.problems().size(), 1, condition.get_script().get_global_name())


## A7: a smaller opening hand and extra free mulligans are counted up, never down.
func test_the_shape_check_rejects_a_negative_hand_or_mulligan_count() -> void:
	for condition: StartingCondition in [ArmorSample.mulligans(-1), ArmorSample.fewer_cards(-1)]:
		var armor: Armor = ArmorSample.armor("Backward Helm", Armor.Slot.HELM, [condition])

		assert_eq(armor.problems().size(), 1, condition.get_script().get_global_name())


## The Armor Slots are named as the Satchel's type line names them.
func test_each_armor_slot_has_its_name() -> void:
	assert_eq(Armor.slot_name(Armor.Slot.HELM), "Helm")
	assert_eq(Armor.slot_name(Armor.Slot.CUIRASS), "Cuirass")
	assert_eq(Armor.slot_name(Armor.Slot.GREAVES), "Greaves")


func _run() -> Run:
	return Run.debug(5, load(KITTY_KEEP) as StageDefinition)


func _wear(run: Run, armor: Armor) -> void:
	run.held_armor.add(armor)
	assert_true(run.held_armor.put_on(armor))


func _names(emblems: Array[MmCardDefinition]) -> Array[String]:
	var names: Array[String] = []
	for emblem: MmCardDefinition in emblems:
		names.append(emblem.name)
	return names
