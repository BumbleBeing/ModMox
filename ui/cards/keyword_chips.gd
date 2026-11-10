class_name KeywordChips
extends RefCounted
## Which keyword chips a Battlefield Face shows, how big they are, and how many fit. Chips
## run along the bottom of the art from the left toward the P/T box; when they run out of
## room, the last one that fits becomes "+N" for every keyword not shown.

## Chips are whole multiples of this, so the user's pixel icons stay crisp.
const PIXEL_STEP: float = 16.0
## A chip is at most this much of the face's height.
const MOST_OF_HEIGHT: float = 0.2
const GAP: float = 0.12


## The chips for [param abilities], in the fixed keyword order (A222). Flash is left out:
## it no longer matters once a card is on the battlefield.
static func chips_for(abilities: Array[MmAbility]) -> Array[KeywordChip]:
	var order: Array[Script] = [
		FlyingAbility, ReachAbility, VigilanceAbility, HasteAbility, DeathtouchAbility,
		DefenderAbility, FirstStrikeAbility, DoubleStrikeAbility, TrampleAbility,
		IndestructibleAbility, ProtectionAbility,
	]
	var letters: Array[String] = ["F", "R", "V", "H", "DT", "DF", "FS", "DS", "T", "I", "P"]
	var chips: Array[KeywordChip] = []
	for index: int in order.size():
		for ability: MmAbility in abilities:
			if not is_instance_of(ability, order[index]):
				continue
			var chip: KeywordChip = KeywordChip.new()
			chip.letters = letters[index]
			var protection: ProtectionAbility = ability as ProtectionAbility
			if protection != null and protection.from is HasColorFilter:
				chip.has_protection_color = true
				chip.protection_color = (protection.from as HasColorFilter).color
			chips.append(chip)
	return chips


## The largest whole multiple of 16 px that still leaves room for two chips in
## [param room] pixels, so a keyword and a "+N" always fit.
static func chip_size(face_height: float, room: float) -> float:
	var largest: float = minf(face_height * MOST_OF_HEIGHT, room / (2.0 + 3.0 * GAP))
	return maxf(PIXEL_STEP, floorf(largest / PIXEL_STEP) * PIXEL_STEP)


static func gap(chip: float) -> float:
	return maxf(2.0, chip * GAP)


## How many chips of [param chip] pixels fit in [param room], with a gap before each and
## after the last.
static func fit_count(chip: float, room: float) -> int:
	return maxi(1, floori((room - gap(chip)) / (chip + gap(chip))))


## The chips to draw when [param fit] fit: all of them, or the first fit - 1 and a "+N".
static func shown(chips: Array[KeywordChip], fit: int) -> Array[KeywordChip]:
	if chips.size() <= fit:
		return chips
	var result: Array[KeywordChip] = chips.slice(0, fit - 1)
	var more: KeywordChip = KeywordChip.new()
	more.letters = "+%d" % (chips.size() - (fit - 1))
	result.append(more)
	return result
