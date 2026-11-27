extends GutTest
## Milestone 23: the Armor the Hero holds, and what is Worn in each Armor Slot (game ADR 0106).
## Putting an Armor on fills its own slot in place of whatever was Worn there, which stays
## held; taking it off empties the slot.

const ArmorSample := preload("res://tests/support/armor_sample.gd")
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"
const FOLDER: String = "user://test_held_armor/"

var _helm: Armor = ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
var _other_helm: Armor = ArmorSample.armor("Gravewatch Helm", Armor.Slot.HELM, [ArmorSample.mulligans(1)])
var _cuirass: Armor = ArmorSample.armor("Seer's Cuirass", Armor.Slot.CUIRASS, [ArmorSample.life(2)])
var _greaves: Armor = ArmorSample.armor("Thornwalker Greaves", Armor.Slot.GREAVES, [ArmorSample.life(1)])


func after_each() -> void:
	if DirAccess.dir_exists_absolute(FOLDER):
		for file: String in DirAccess.get_files_at(FOLDER):
			DirAccess.remove_absolute(FOLDER + file)
		DirAccess.remove_absolute(FOLDER)


## A3: putting on an Armor fills its Armor Slot.
func test_putting_on_an_armor_fills_its_slot() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_helm)

	assert_true(held.put_on(_helm))

	assert_eq(held.worn_in(Armor.Slot.HELM), _helm)
	assert_true(held.is_worn(_helm))


## A3: putting on an Armor takes off whatever was Worn in its slot, which is still held.
func test_putting_on_an_armor_replaces_what_was_worn_in_its_slot_which_stays_held() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_helm)
	held.add(_other_helm)
	held.put_on(_helm)

	assert_true(held.put_on(_other_helm))

	assert_eq(held.worn_in(Armor.Slot.HELM), _other_helm)
	assert_false(held.is_worn(_helm))
	assert_eq(held.kinds(), [_helm, _other_helm] as Array[Armor])
	assert_eq(held.count_of(_helm), 1)


## A3: putting on an Armor changes nothing else in the run. A run is compared by what it
## saves, and only Armor with a file can be saved.
func test_putting_on_an_armor_changes_nothing_else_in_the_run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var helm: Armor = _saved(_helm, "helm")
	var cuirass: Armor = _saved(_cuirass, "cuirass")
	var run: Run = Run.debug(5, load(KITTY_KEEP) as StageDefinition)
	run.held_armor.add(helm)
	run.held_armor.add(cuirass)
	run.held_armor.put_on(cuirass)
	var before: Dictionary = run.to_data()
	before.erase("held_armor")

	run.held_armor.put_on(helm)

	var after: Dictionary = run.to_data()
	after.erase("held_armor")
	assert_eq(after, before)
	assert_eq(run.held_armor.worn_in(Armor.Slot.CUIRASS), cuirass, "The other slots keep what they hold.")
	assert_eq(run.held_armor.worn_in(Armor.Slot.HELM), helm)


## A4: taking off an Armor empties its slot, and it is still held.
func test_taking_off_an_armor_empties_its_slot_and_it_is_still_held() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_cuirass)
	held.put_on(_cuirass)

	assert_true(held.take_off(Armor.Slot.CUIRASS))

	assert_null(held.worn_in(Armor.Slot.CUIRASS))
	assert_false(held.is_worn(_cuirass))
	assert_eq(held.count_of(_cuirass), 1)


## A4: taking off from an empty slot changes nothing and says so.
func test_taking_off_from_an_empty_slot_changes_nothing() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_cuirass)

	assert_false(held.take_off(Armor.Slot.CUIRASS))

	assert_eq(held.worn(), [] as Array[Armor])


## A5: an Armor goes only in its own slot.
func test_an_armor_goes_only_in_its_own_slot() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_cuirass)

	held.put_on(_cuirass)

	assert_null(held.worn_in(Armor.Slot.HELM))
	assert_eq(held.worn_in(Armor.Slot.CUIRASS), _cuirass)
	assert_null(held.worn_in(Armor.Slot.GREAVES))


## A5: an Armor not held cannot be put on.
func test_an_armor_not_held_cannot_be_put_on() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_helm)

	assert_false(held.put_on(_cuirass))

	assert_eq(held.worn(), [] as Array[Armor])


## The same Armor held twice is one kind with a count of two.
func test_the_same_armor_held_twice_is_one_kind_with_a_count_of_two() -> void:
	var held: HeldArmor = HeldArmor.new()

	held.add(_helm)
	held.add(_helm)

	assert_eq(held.kinds(), [_helm] as Array[Armor])
	assert_eq(held.count_of(_helm), 2)


## T4 (milestone 24, the Satchel): with two of one Armor held and one Worn, two are still held,
## and taking it off leaves two.
func test_two_held_and_one_worn_are_still_two_held() -> void:
	var held: HeldArmor = HeldArmor.new()
	held.add(_helm)
	held.add(_helm)

	held.put_on(_helm)

	assert_eq(held.count_of(_helm), 2)
	assert_eq(held.kinds(), [_helm] as Array[Armor])
	assert_true(held.is_worn(_helm))
	held.take_off(Armor.Slot.HELM)
	assert_eq(held.count_of(_helm), 2)


## What is Worn is listed Helm, then Cuirass, then Greaves, whatever order it was put on in,
## and so are its Starting Conditions, each Armor's in the order authored.
func test_what_is_worn_and_its_starting_conditions_go_helm_cuirass_greaves() -> void:
	var held: HeldArmor = HeldArmor.new()
	for armor: Armor in [_greaves, _cuirass, _helm]:
		held.add(armor)
		held.put_on(armor)

	assert_eq(held.worn(), [_helm, _cuirass, _greaves] as Array[Armor])
	assert_eq(held.starting_conditions(), [_helm.starting_conditions[0], _cuirass.starting_conditions[0],
		_greaves.starting_conditions[0]] as Array[StartingCondition])


func _saved(armor: Armor, file_name: String) -> Armor:
	assert_eq(ResourceSaver.save(armor, FOLDER + file_name + ".tres"), OK)
	return load(FOLDER + file_name + ".tres") as Armor
