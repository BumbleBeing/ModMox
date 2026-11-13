class_name Reminders
extends RefCounted
## The Reminder for each keyword a card has (13h, ADR 0033). Card Faces leave reminder text
## off (ADR 0023); the Inspector lists these instead. A new keyword gets its sentence here
## in the same change as its Keyword Icon: a test fails for an icon with no Reminder.

## What each keyword means, by the file name of its Keyword Icon. No mana or tap symbols:
## these are drawn by plain labels.
const TEXTS: Dictionary[String, String] = {
	"flying": "It can be blocked only by creatures with flying or reach.",
	"reach": "It can block creatures with flying.",
	"vigilance": "Attacking doesn't cause it to tap.",
	"haste": "It can attack and tap for a cost the turn it comes under your control.",
	"deathtouch": "Any amount of damage it deals to a creature is enough to destroy that creature.",
	"defender": "It can't attack.",
	"first_strike": "It deals combat damage before creatures without first strike.",
	"double_strike": "It deals both first-strike and regular combat damage.",
	"trample": "It can deal excess combat damage to the player it is attacking.",
	"indestructible": "Damage and effects that say \"destroy\" don't destroy it.",
	"protection": "It can't be blocked, targeted, dealt damage or enchanted by anything of that kind.",
}


## One Reminder for each keyword among [param abilities], in the order of their Keyword
## Chips (A222), a keyword it has twice once.
static func of(abilities: Array[MmAbility]) -> Array[Reminder]:
	var reminders: Array[Reminder] = []
	for chip: KeywordChip in KeywordChips.chips_for(abilities):
		if not TEXTS.has(chip.icon):
			continue
		var reminder: Reminder = Reminder.new()
		reminder.icon = chip.icon
		reminder.keyword = _keyword(chip, abilities)
		reminder.text = TEXTS[chip.icon]
		reminders.append(reminder)
	return reminders


## The keyword [param chip] stands for, in the card's own words.
static func _keyword(chip: KeywordChip, abilities: Array[MmAbility]) -> String:
	for ability: MmAbility in abilities:
		var chips: Array[KeywordChip] = KeywordChips.chips_for([ability] as Array[MmAbility])
		if chips.size() == 1 and chips[0].icon == chip.icon and chips[0].has_protection_color == chip.has_protection_color \
				and chips[0].protection_color == chip.protection_color:
			return AbilityText.of_ability(ability, "it").trim_suffix(".")
	return chip.icon.capitalize()
