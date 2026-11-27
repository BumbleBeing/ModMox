class_name SatchelEntries
extends RefCounted
## What each page of the Satchel lists (milestone 24, game glossary): one entry for each kind
## of Item held, with how many. Armor is sorted by Armor Slot, Helm, Cuirass, Greaves, and then
## by name; Mods and Potions rarest first and then by name; with no headings. Every word comes
## from what the Item is: an Armor's from its Starting Conditions, a Mod's from ModText, a
## Potion's from its abilities, never by hand.

## The Satchel's pages, in the order of their tabs. It always opens on Armor.
enum Page { ARMOR, MODS, POTIONS }

const PAGES: Array[Page] = [Page.ARMOR, Page.MODS, Page.POTIONS]
const PAGE_NAMES: Dictionary[Page, String] = { Page.ARMOR: "Armor", Page.MODS: "Mods", Page.POTIONS: "Potions" }
## What a page with nothing on it reads.
const EMPTY_WORDS: Dictionary[Page, String] = {
	Page.ARMOR: "No Armor held.", Page.MODS: "No Mods held.", Page.POTIONS: "No Potions held.",
}
## A Potion's type line, as the Inspector writes it: "Rare Potion".
const POTION_TYPE: String = "%s Potion"


## The entries of [param page] for what [param run] holds, in their order.
static func of(run: Run, page: Page) -> Array[SatchelEntry]:
	match page:
		Page.ARMOR:
			return armor_of(run.held_armor)
		Page.MODS:
			return mods_of(run.held_mods)
	return potions_of(run.held_potions)


static func armor_of(held: HeldArmor) -> Array[SatchelEntry]:
	var entries: Array[SatchelEntry] = []
	for armor: Armor in held.kinds():
		var entry: SatchelEntry = SatchelEntry.new()
		entry.armor = armor
		entry.name = armor.name
		entry.count = held.count_of(armor)
		entry.type_line = Armor.slot_name(armor.slot)
		entry.lines = StartingConditionText.lines_of(armor.starting_conditions)
		entry.is_worn = held.is_worn(armor)
		entries.append(entry)
	entries.sort_custom(func(a: SatchelEntry, b: SatchelEntry) -> bool:
		if a.armor.slot != b.armor.slot:
			return a.armor.slot < b.armor.slot
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return entries


static func mods_of(held: HeldMods) -> Array[SatchelEntry]:
	var entries: Array[SatchelEntry] = []
	for mod: Mod in held.kinds():
		var entry: SatchelEntry = SatchelEntry.new()
		entry.mod = mod
		entry.name = mod.name
		entry.count = held.count_of(mod)
		entry.type_line = ModText.type_line_of(mod)
		entry.lines = [ModText.of(mod)] as Array[String]
		entries.append(entry)
	entries.sort_custom(func(a: SatchelEntry, b: SatchelEntry) -> bool:
		return _rarest_first(a.mod.rarity, b.mod.rarity, a, b))
	return entries


static func potions_of(held: HeldPotions) -> Array[SatchelEntry]:
	var entries: Array[SatchelEntry] = []
	for potion: MmCardDefinition in held.kinds():
		var entry: SatchelEntry = SatchelEntry.new()
		entry.potion = potion
		entry.name = potion.name
		entry.count = held.count_of(potion)
		entry.type_line = POTION_TYPE % Inspector.RARITY_NAMES[potion.rarity]
		entry.lines = AbilityText.lines_of(potion.abilities, AbilityText.POTION_NOUN)
		entries.append(entry)
	entries.sort_custom(func(a: SatchelEntry, b: SatchelEntry) -> bool:
		return _rarest_first(a.potion.rarity, b.potion.rarity, a, b))
	return entries


## Whether [param a], of [param rarity_a], goes before [param b]: the rarer first, and of
## one Rarity, by name.
static func _rarest_first(rarity_a: int, rarity_b: int, a: SatchelEntry, b: SatchelEntry) -> bool:
	if rarity_a != rarity_b:
		return rarity_a > rarity_b
	return a.name.naturalnocasecmp_to(b.name) < 0
