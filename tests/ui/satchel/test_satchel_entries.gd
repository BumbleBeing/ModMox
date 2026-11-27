extends GutTest
## Milestone 24: what each page of the Satchel lists (game glossary), worked out apart from the
## window. One entry for each kind of Item held, with its count; Armor sorted by Armor Slot and
## then by name, Mods and Potions rarest first and then by name; each with its type line and
## its words, which are never written by hand.

const ArmorSample := preload("res://tests/support/armor_sample.gd")
const BIG_GULP: String = "res://content/potions/big_gulp.tres"
const Page := SatchelEntries.Page

var _run: Run


func before_each() -> void:
	_run = Run.debug(7)
	_run.held_armor = HeldArmor.new()
	_run.held_mods = HeldMods.new()
	_run.held_potions = HeldPotions.new()


## S4: one entry for each kind held, with how many, and the count after its name only when
## more than one is held.
func test_each_kind_held_is_one_entry_with_its_count() -> void:
	var helm: Armor = ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
	_run.held_armor.add(helm)
	_run.held_armor.add(helm)
	var big_gulp: MmCardDefinition = load(BIG_GULP) as MmCardDefinition
	_run.held_potions.add(big_gulp)

	var armor: Array[SatchelEntry] = SatchelEntries.of(_run, Page.ARMOR)
	var potions: Array[SatchelEntry] = SatchelEntries.of(_run, Page.POTIONS)

	assert_eq(armor.size(), 1)
	assert_eq(armor[0].count, 2)
	assert_eq(armor[0].title(), "Lionguard Helm ×2")
	assert_eq(potions.size(), 1)
	assert_eq(potions[0].title(), "Big Gulp")


## S5: Armor is sorted by Armor Slot, Helm, Cuirass, Greaves, and then by name.
func test_armor_is_sorted_by_armor_slot_and_then_by_name() -> void:
	for armor: Armor in [
		ArmorSample.armor("Thornwalker Greaves", Armor.Slot.GREAVES, [ArmorSample.life(1)]),
		ArmorSample.armor("Sunwarden's Cuirass", Armor.Slot.CUIRASS, [ArmorSample.life(3)]),
		ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(2)]),
		ArmorSample.armor("Bloodbound Cuirass", Armor.Slot.CUIRASS, [ArmorSample.life(1)]),
		ArmorSample.armor("Gravewatch Helm", Armor.Slot.HELM, [ArmorSample.mulligans(1)]),
	]:
		_run.held_armor.add(armor)

	assert_eq(_titles(SatchelEntries.of(_run, Page.ARMOR)), [
		"Gravewatch Helm", "Lionguard Helm", "Bloodbound Cuirass", "Sunwarden's Cuirass", "Thornwalker Greaves",
	] as Array[String])


## S5: Mods are sorted rarest first, and then by name.
func test_mods_are_sorted_rarest_first_and_then_by_name() -> void:
	for spec: Array in [["Sharp", Mod.Rarity.UNCOMMON], ["Aversive", Mod.Rarity.UNCOMMON], ["Titanic", Mod.Rarity.MYTHIC],
			["Bulky", Mod.Rarity.COMMON], ["Brazen", Mod.Rarity.RARE], ["Worldbreaker", Mod.Rarity.UNIQUE]]:
		_run.held_mods.add(_mod(spec[0], spec[1]))

	assert_eq(_titles(SatchelEntries.of(_run, Page.MODS)),
		["Worldbreaker", "Titanic", "Brazen", "Aversive", "Sharp", "Bulky"] as Array[String])


## S5: Potions are sorted rarest first, and then by name.
func test_potions_are_sorted_rarest_first_and_then_by_name() -> void:
	_run.held_potions.add(_potion("Mending Draught", MmCardDefinition.Rarity.COMMON))
	_run.held_potions.add(_potion("Seer's Tonic", MmCardDefinition.Rarity.RARE))
	_run.held_potions.add(_potion("Big Gulp", MmCardDefinition.Rarity.COMMON))
	_run.held_potions.add(_potion("Dragon's Breath", MmCardDefinition.Rarity.MYTHIC))

	assert_eq(_titles(SatchelEntries.of(_run, Page.POTIONS)),
		["Dragon's Breath", "Seer's Tonic", "Big Gulp", "Mending Draught"] as Array[String])


## S6: an Armor's type line names its Armor Slot, and its words are its Starting Conditions'.
func test_an_armors_type_line_is_its_slot_and_its_words_its_starting_conditions() -> void:
	_run.held_armor.add(ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM,
		[ArmorSample.life(3), ArmorSample.mulligans(1)]))

	var entry: SatchelEntry = SatchelEntries.of(_run, Page.ARMOR)[0]

	assert_eq(entry.type_line, "Helm")
	assert_eq(entry.lines, ["You start each encounter with 3 more life.",
		"You start each encounter with an extra free mulligan."] as Array[String])


## S6: a Mod's type line names its Rarity and the card types it accepts, and its words are
## ModText's.
func test_a_mods_type_line_and_words_are_mod_texts() -> void:
	var violent: Mod = load("res://content/mods/violent.tres") as Mod
	_run.held_mods.add(violent)

	var entry: SatchelEntry = SatchelEntries.of(_run, Page.MODS)[0]

	assert_eq(entry.type_line, ModText.type_line_of(violent))
	assert_eq(entry.type_line, "Mythic Creature Mod")
	assert_eq(entry.lines, [ModText.of(violent)] as Array[String])


## S6: a Potion's type line is its Rarity and "Potion", and its words are its rules text.
func test_a_potions_type_line_is_its_rarity_and_potion() -> void:
	var big_gulp: MmCardDefinition = load(BIG_GULP) as MmCardDefinition
	_run.held_potions.add(big_gulp)

	var entry: SatchelEntry = SatchelEntries.of(_run, Page.POTIONS)[0]

	assert_eq(entry.type_line, "Common Potion")
	assert_eq(entry.lines, AbilityText.lines_of(big_gulp.abilities, AbilityText.POTION_NOUN))
	assert_false(entry.lines.is_empty())
	assert_false(entry.lines[0].contains("["), entry.lines[0])


## S7: an empty page says so.
func test_an_empty_page_says_nothing_is_held() -> void:
	assert_eq(SatchelEntries.of(_run, Page.ARMOR), [] as Array[SatchelEntry])
	assert_eq(SatchelEntries.EMPTY_WORDS[Page.ARMOR], "No Armor held.")
	assert_eq(SatchelEntries.EMPTY_WORDS[Page.MODS], "No Mods held.")
	assert_eq(SatchelEntries.EMPTY_WORDS[Page.POTIONS], "No Potions held.")


## The tabs' names, in their order.
func test_the_pages_are_armor_mods_and_potions() -> void:
	assert_eq(SatchelEntries.PAGES, [Page.ARMOR, Page.MODS, Page.POTIONS] as Array[SatchelEntries.Page])
	assert_eq(SatchelEntries.PAGE_NAMES[Page.ARMOR], "Armor")
	assert_eq(SatchelEntries.PAGE_NAMES[Page.MODS], "Mods")
	assert_eq(SatchelEntries.PAGE_NAMES[Page.POTIONS], "Potions")


## S9: an entry says whether its Armor is Worn, and only an Armor's takes a click.
func test_an_entry_knows_whether_it_is_worn_and_whether_it_takes_a_click() -> void:
	var helm: Armor = ArmorSample.armor("Lionguard Helm", Armor.Slot.HELM, [ArmorSample.life(3)])
	var other: Armor = ArmorSample.armor("Gravewatch Helm", Armor.Slot.HELM, [ArmorSample.life(1)])
	_run.held_armor.add(helm)
	_run.held_armor.add(other)
	_run.held_armor.put_on(helm)
	_run.held_mods.add(load("res://content/mods/violent.tres") as Mod)
	_run.held_potions.add(load(BIG_GULP) as MmCardDefinition)

	var armor: Array[SatchelEntry] = SatchelEntries.of(_run, Page.ARMOR)

	assert_eq(_titles(armor), ["Gravewatch Helm", "Lionguard Helm"] as Array[String])
	assert_false(armor[0].is_worn)
	assert_true(armor[1].is_worn)
	assert_true(armor[0].takes_clicks())
	assert_false(SatchelEntries.of(_run, Page.MODS)[0].takes_clicks())
	assert_false(SatchelEntries.of(_run, Page.POTIONS)[0].takes_clicks())


func _titles(entries: Array[SatchelEntry]) -> Array[String]:
	var found: Array[String] = []
	for entry: SatchelEntry in entries:
		found.append(entry.title())
	return found


func _mod(mod_name: String, rarity: Mod.Rarity) -> Mod:
	var mod: Mod = (load("res://content/mods/violent.tres") as Mod).duplicate() as Mod
	mod.name = mod_name
	mod.rarity = rarity
	return mod


func _potion(potion_name: String, rarity: MmCardDefinition.Rarity) -> MmCardDefinition:
	var potion: MmCardDefinition = (load(BIG_GULP) as MmCardDefinition).duplicate() as MmCardDefinition
	potion.name = potion_name
	potion.rarity = rarity
	return potion
